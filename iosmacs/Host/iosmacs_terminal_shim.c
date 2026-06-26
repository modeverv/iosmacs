#include "iosmacs_terminal_shim.h"

#include "iosmacs_host_facade.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <termios.h>
#include <unistd.h>

#if defined(__clang__)
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif

static int shim_enabled;
static int fake_tty_fd = -1;
static int fake_peer_fd = -1;
static int mirror_fd = -1;
static int stdio_redirected;
static pthread_t output_thread;
static pthread_t input_thread;
static const char opened_marker[] = "iosmacs-nw-opened-tty\n";
static struct termios fake_tty_termios;
static int fake_tty_termios_initialized;

static int open_fake_tty(void);
static int open_pty_pair(int *tty_fd, int *peer_fd);
static void apply_termios_to_fd(int fd, int optional_actions, const struct termios *term);

static void init_fake_tty_termios(void) {
    if (fake_tty_termios_initialized) {
        return;
    }

    memset(&fake_tty_termios, 0, sizeof(fake_tty_termios));
    fake_tty_termios.c_iflag = 0;
    fake_tty_termios.c_oflag = 0;
    fake_tty_termios.c_cflag = CREAD | CS8;
    fake_tty_termios.c_lflag = 0;
    fake_tty_termios.c_cc[VINTR] = 3;
    fake_tty_termios.c_cc[VQUIT] = 28;
    fake_tty_termios.c_cc[VERASE] = 127;
    fake_tty_termios.c_cc[VKILL] = 21;
    fake_tty_termios.c_cc[VEOF] = 4;
    fake_tty_termios.c_cc[VMIN] = 1;
    fake_tty_termios.c_cc[VTIME] = 0;
    fake_tty_termios_initialized = 1;
}

static void shim_debug_log_bytes(const char *label, const uint8_t *bytes, size_t count) {
    const char *path = getenv("IOSMACS_WEB_TERMINAL_DEBUG_MARKER");
    if (path == NULL || path[0] == '\0' || label == NULL) {
        return;
    }

    int fd = (int)syscall(SYS_open, path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) {
        return;
    }
    char line[512];
    int offset = snprintf(line, sizeof(line), "shim %s count=%zu bytes=", label, count);
    size_t limit = count < 32 ? count : 32;
    for (size_t i = 0; i < limit && offset > 0 && (size_t)offset < sizeof(line); i++) {
        offset += snprintf(line + offset, sizeof(line) - (size_t)offset, "%s%02x", i == 0 ? "" : " ", bytes[i]);
    }
    if (count > limit && offset > 0 && (size_t)offset < sizeof(line)) {
        offset += snprintf(line + offset, sizeof(line) - (size_t)offset, " ...");
    }
    if (offset > 0 && (size_t)offset < sizeof(line)) {
        offset += snprintf(line + offset, sizeof(line) - (size_t)offset, "\n");
    }
    if (offset > 0) {
        syscall(SYS_write, fd, line, (size_t)offset < sizeof(line) ? (size_t)offset : sizeof(line));
    }
    syscall(SYS_close, fd);
}

static const char *translate_prefixed_path(const char *path,
                                           const char *logical_prefix,
                                           const char *physical_prefix,
                                           char *buffer,
                                           size_t buffer_size) {
    size_t logical_len;
    size_t physical_len;

    if (path == NULL || logical_prefix == NULL || physical_prefix == NULL || physical_prefix[0] == '\0') {
        return NULL;
    }

    logical_len = strlen(logical_prefix);
    if (strncmp(path, logical_prefix, logical_len) != 0) {
        return NULL;
    }
    if (path[logical_len] != '\0' && path[logical_len] != '/') {
        return NULL;
    }

    physical_len = strlen(physical_prefix);
    if (physical_len + strlen(path + logical_len) + 1 > buffer_size) {
        errno = ENAMETOOLONG;
        return NULL;
    }

    memcpy(buffer, physical_prefix, physical_len);
    strcpy(buffer + physical_len, path + logical_len);
    return buffer;
}

static bool path_has_prefix(const char *path, const char *prefix) {
    size_t prefix_len;
    if (path == NULL || prefix == NULL) {
        return false;
    }
    prefix_len = strlen(prefix);
    return strncmp(path, prefix, prefix_len) == 0
        && (path[prefix_len] == '\0' || path[prefix_len] == '/');
}

static bool is_system_path(const char *path) {
    return path_has_prefix(path, "/system");
}

static const char *translate_system_path(const char *path, char *buffer, size_t buffer_size) {
    static const char logical_system[] = "/system";
    const char *system_root = getenv("IOSMACS_SYSTEM_ROOT");
    const char *mapped = translate_prefixed_path(path, logical_system, system_root, buffer, buffer_size);
    if (mapped != NULL) {
        return mapped;
    }
    return path;
}

static const char *translate_workspace_path(const char *path, char *buffer, size_t buffer_size) {
    static const char logical_home[] = "/home/user";
    const char *workspace_root = getenv("IOSMACS_WORKSPACE_ROOT");
    const char *mapped;

    if (path == NULL) {
        return path;
    }
    mapped = translate_prefixed_path(path, logical_home, workspace_root, buffer, buffer_size);
    if (mapped != NULL) {
        return mapped;
    }
    return translate_system_path(path, buffer, buffer_size);
}

static int reject_read_only_system_path(const char *path) {
    if (is_system_path(path)) {
        errno = EROFS;
        return 1;
    }
    return 0;
}

static int open_flags_write_to_path(int flags) {
    return (flags & O_CREAT) != 0
        || (flags & O_TRUNC) != 0
        || (flags & O_APPEND) != 0
        || (flags & O_ACCMODE) == O_WRONLY
        || (flags & O_ACCMODE) == O_RDWR;
}

static int is_iosmacs_tty_fd(int fd) {
    return (fake_tty_fd >= 0 && fd == fake_tty_fd)
        || (stdio_redirected && fd >= STDIN_FILENO && fd <= STDOUT_FILENO);
}

static void *output_pump_main(void *arg) {
    uint8_t buffer[4096];
    (void)arg;

    for (;;) {
        ssize_t count = read(fake_peer_fd, buffer, sizeof(buffer));
        if (count < 0 && errno == EINTR) {
            continue;
        }
        if (count <= 0) {
            break;
        }
        shim_debug_log_bytes("output-pump-read", buffer, (size_t)count);
        iosmacs_os_terminal_write(buffer, (size_t)count);
        if (mirror_fd >= 0) {
            syscall(SYS_write, mirror_fd, buffer, (size_t)count);
        }
    }

    return 0;
}

static void *input_pump_main(void *arg) {
    uint8_t buffer[1024];
    (void)arg;

    for (;;) {
        if (iosmacs_os_terminal_direct_mode_enabled()) {
            usleep(10000);
            continue;
        }
        ssize_t count = iosmacs_os_terminal_read(buffer, sizeof(buffer));
        if (count > 0) {
            ssize_t ignored;
            do {
                ignored = write(fake_peer_fd, buffer, (size_t)count);
            } while (ignored < 0 && errno == EINTR);
            shim_debug_log_bytes("input-pump-write", buffer, (size_t)count);
#ifdef SIGIO
            raise(SIGIO);
#endif
            (void)ignored;
        } else {
            usleep(10000);
        }
    }

    return 0;
}

void iosmacs_terminal_shim_enable(void) {
    shim_enabled = 1;
}

void iosmacs_terminal_shim_set_mirror_fd(int fd) {
    mirror_fd = fd;
}

bool iosmacs_terminal_shim_is_open(void) {
    return fake_tty_fd >= 0;
}

ssize_t iosmacs_terminal_shim_push_input(const uint8_t *bytes, size_t count) {
    if (bytes == NULL && count > 0) {
        errno = EINVAL;
        return -1;
    }

    ssize_t written = iosmacs_os_terminal_push_input(bytes, count);
    if (written > 0) {
        shim_debug_log_bytes("direct-input-ring-write", bytes, (size_t)written);
    }
    return written;
}

int iosmacs_terminal_shim_attach_stdio(void) {
    int fd = open_fake_tty();
    if (fd < 0) {
        return -1;
    }
    if (dup2(fd, STDIN_FILENO) < 0) {
        return -1;
    }
    if (dup2(fd, STDOUT_FILENO) < 0) {
        return -1;
    }
    iosmacs_os_terminal_note_tty_fd(fd);
    iosmacs_os_terminal_note_stdio_redirected();
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);
    stdio_redirected = 1;
    return 0;
}

int isatty(int fd) {
    if (shim_enabled && is_iosmacs_tty_fd(fd)) {
        return 1;
    }
    errno = ENOTTY;
    return 0;
}

int rpl_isatty(int fd) {
    return isatty(fd);
}

int tcgetattr(int fd, struct termios *term) {
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    if (term == NULL) {
        errno = EINVAL;
        return -1;
    }

    init_fake_tty_termios();
    *term = fake_tty_termios;
    return 0;
}

int tcsetattr(int fd, int optional_actions, const struct termios *term) {
    (void)optional_actions;
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    if (term == NULL) {
        errno = EINVAL;
        return -1;
    }

    fake_tty_termios = *term;
    fake_tty_termios_initialized = 1;
    apply_termios_to_fd(fd, optional_actions, term);
    return 0;
}

int tcflow(int fd, int action) {
    (void)action;
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    return 0;
}

int tcdrain(int fd) {
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    return 0;
}

int tcflush(int fd, int queue_selector) {
    (void)queue_selector;
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    return 0;
}

pid_t tcgetpgrp(int fd) {
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    return getpgrp();
}

int tcsetpgrp(int fd, pid_t pgrp) {
    (void)pgrp;
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
    return 0;
}

int ioctl(int fd, unsigned long request, ...) {
    va_list ap;
    void *arg;

    va_start(ap, request);
    arg = va_arg(ap, void *);
    va_end(ap);

    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        return (int)syscall(SYS_ioctl, fd, request, arg);
    }

    if (request == TIOCGWINSZ && arg != NULL) {
        struct winsize *ws = (struct winsize *)arg;
        memset(ws, 0, sizeof(*ws));
        ws->ws_col = (unsigned short)iosmacs_os_terminal_cols();
        ws->ws_row = (unsigned short)iosmacs_os_terminal_rows();
        return 0;
    }
    if (request == TIOCSWINSZ) {
        return 0;
    }
#ifdef TIOCOUTQ
    if (request == TIOCOUTQ && arg != NULL) {
        *(int *)arg = 0;
        return 0;
    }
#endif
#ifdef FIONREAD
    if (request == FIONREAD && arg != NULL) {
        if (syscall(SYS_ioctl, fd, request, arg) == 0) {
            return 0;
        }
        *(int *)arg = 0;
        return 0;
    }
#endif
#ifdef TIOCNOTTY
    if (request == TIOCNOTTY) {
        return 0;
    }
#endif

    errno = ENOTTY;
    return -1;
}

static int open_fake_tty(void) {
    int fds[2];

    if (fake_tty_fd >= 0) {
        return fake_tty_fd;
    }
    if (open_pty_pair(&fake_tty_fd, &fake_peer_fd) != 0) {
        if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) != 0) {
            return -1;
        }
        fake_tty_fd = fds[0];
        fake_peer_fd = fds[1];
    }

    iosmacs_os_set_lifecycle_state("iosmacs: fake tty opened");
    iosmacs_os_terminal_note_tty_fd(fake_tty_fd);
    if (mirror_fd >= 0) {
        syscall(SYS_write, mirror_fd, opened_marker, sizeof(opened_marker) - 1);
    }
    pthread_create(&output_thread, NULL, output_pump_main, NULL);
    pthread_create(&input_thread, NULL, input_pump_main, NULL);
    return fake_tty_fd;
}

static int open_pty_pair(int *tty_fd, int *peer_fd) {
    int master_fd = posix_openpt(O_RDWR | O_NOCTTY);
    if (master_fd < 0) {
        return -1;
    }
    if (grantpt(master_fd) != 0 || unlockpt(master_fd) != 0) {
        close(master_fd);
        return -1;
    }

    char *slave_name = ptsname(master_fd);
    if (slave_name == NULL) {
        close(master_fd);
        return -1;
    }

    int slave_fd = (int)syscall(SYS_open, slave_name, O_RDWR | O_NOCTTY, 0);
    if (slave_fd < 0) {
        close(master_fd);
        return -1;
    }

    init_fake_tty_termios();
    apply_termios_to_fd(slave_fd, TCSANOW, &fake_tty_termios);

    *tty_fd = slave_fd;
    *peer_fd = master_fd;
    return 0;
}

static void apply_termios_to_fd(int fd, int optional_actions, const struct termios *term) {
    unsigned long request = TIOCSETA;
    if (term == NULL || fd < 0) {
        return;
    }
#ifdef TIOCSETAW
    if (optional_actions == TCSADRAIN) {
        request = TIOCSETAW;
    }
#endif
#ifdef TIOCSETAF
    if (optional_actions == TCSAFLUSH) {
        request = TIOCSETAF;
    }
#endif
    syscall(SYS_ioctl, fd, request, term);
}

int openat(int fd, const char *path, int flags, ...) {
    mode_t mode = 0;
    char translated[PATH_MAX];
    const char *actual_path;
    if ((flags & O_CREAT) != 0) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (shim_enabled && path != NULL && strcmp(path, "/dev/tty") == 0) {
        return open_fake_tty();
    }
    if (open_flags_write_to_path(flags) && reject_read_only_system_path(path)) {
        return -1;
    }
    actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_openat, fd, actual_path, flags, mode);
}

int open(const char *path, int flags, ...) {
    mode_t mode = 0;
    char translated[PATH_MAX];
    const char *actual_path;
    if ((flags & O_CREAT) != 0) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (shim_enabled && path != NULL && strcmp(path, "/dev/tty") == 0) {
        return open_fake_tty();
    }
    if (open_flags_write_to_path(flags) && reject_read_only_system_path(path)) {
        return -1;
    }
    actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_open, actual_path, flags, mode);
}

int access(const char *path, int mode) {
    char translated[PATH_MAX];
    if ((mode & W_OK) != 0 && is_system_path(path)) {
        errno = EACCES;
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_access, actual_path, mode);
}

int faccessat(int fd, const char *path, int mode, int flags) {
    char translated[PATH_MAX];
    if ((mode & W_OK) != 0 && is_system_path(path)) {
        errno = EACCES;
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_faccessat, fd, actual_path, mode, flags);
}

int stat(const char *path, struct stat *st) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_stat, actual_path, st);
}

int fstatat(int fd, const char *path, struct stat *st, int flags) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_fstatat64, fd, actual_path, st, flags);
}

int lstat(const char *path, struct stat *st) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_lstat, actual_path, st);
}

int mkdir(const char *path, mode_t mode) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_mkdir, actual_path, mode);
}

int mkdirat(int fd, const char *path, mode_t mode) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_mkdirat, fd, actual_path, mode);
}

int rmdir(const char *path) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_rmdir, actual_path);
}

int unlink(const char *path) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_unlink, actual_path);
}

int unlinkat(int fd, const char *path, int flags) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_unlinkat, fd, actual_path, flags);
}

int rename(const char *old_path, const char *new_path) {
    char translated_old[PATH_MAX];
    char translated_new[PATH_MAX];
    if (reject_read_only_system_path(old_path) || reject_read_only_system_path(new_path)) {
        return -1;
    }
    const char *actual_old = translate_workspace_path(old_path, translated_old, sizeof(translated_old));
    const char *actual_new = translate_workspace_path(new_path, translated_new, sizeof(translated_new));
    if (actual_old == NULL || actual_new == NULL) {
        return -1;
    }
    return (int)syscall(SYS_rename, actual_old, actual_new);
}

int renameat(int old_fd, const char *old_path, int new_fd, const char *new_path) {
    char translated_old[PATH_MAX];
    char translated_new[PATH_MAX];
    if (reject_read_only_system_path(old_path) || reject_read_only_system_path(new_path)) {
        return -1;
    }
    const char *actual_old = translate_workspace_path(old_path, translated_old, sizeof(translated_old));
    const char *actual_new = translate_workspace_path(new_path, translated_new, sizeof(translated_new));
    if (actual_old == NULL || actual_new == NULL) {
        return -1;
    }
    return (int)syscall(SYS_renameat, old_fd, actual_old, new_fd, actual_new);
}

int chdir(const char *path) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_chdir, actual_path);
}

int chmod(const char *path, mode_t mode) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_chmod, actual_path, mode);
}

int fchmodat(int fd, const char *path, mode_t mode, int flags) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_fchmodat, fd, actual_path, mode, flags);
}

int chown(const char *path, uid_t owner, gid_t group) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_chown, actual_path, owner, group);
}

int fchownat(int fd, const char *path, uid_t owner, gid_t group, int flags) {
    char translated[PATH_MAX];
    if (reject_read_only_system_path(path)) {
        return -1;
    }
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_fchownat, fd, actual_path, owner, group, flags);
}

ssize_t readlink(const char *path, char *buffer, size_t buffer_size) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (ssize_t)syscall(SYS_readlink, actual_path, buffer, buffer_size);
}

int symlink(const char *target, const char *link_path) {
    char translated_link[PATH_MAX];
    if (reject_read_only_system_path(link_path)) {
        return -1;
    }
    const char *actual_link = translate_workspace_path(link_path, translated_link, sizeof(translated_link));
    if (actual_link == NULL) {
        return -1;
    }
    return (int)syscall(SYS_symlink, target, actual_link);
}

DIR *opendir(const char *path) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    int fd;
    DIR *dir;
    if (actual_path == NULL) {
        return NULL;
    }
    fd = open(actual_path, O_RDONLY);
    if (fd < 0) {
        return NULL;
    }
    dir = fdopendir(fd);
    if (dir == NULL) {
        close(fd);
    }
    return dir;
}
