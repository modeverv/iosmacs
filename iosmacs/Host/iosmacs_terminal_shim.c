#include "iosmacs_terminal_shim.h"

#include "iosmacs_host_facade.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
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

static int open_fake_tty(void);

static const char *translate_workspace_path(const char *path, char *buffer, size_t buffer_size) {
    static const char logical_home[] = "/home/user";
    const char *workspace_root = getenv("IOSMACS_WORKSPACE_ROOT");
    size_t logical_len = sizeof(logical_home) - 1;
    size_t root_len;

    if (path == NULL || workspace_root == NULL || workspace_root[0] == '\0') {
        return path;
    }
    if (strncmp(path, logical_home, logical_len) != 0) {
        return path;
    }
    if (path[logical_len] != '\0' && path[logical_len] != '/') {
        return path;
    }

    root_len = strlen(workspace_root);
    if (root_len + strlen(path + logical_len) + 1 > buffer_size) {
        errno = ENAMETOOLONG;
        return NULL;
    }

    memcpy(buffer, workspace_root, root_len);
    strcpy(buffer + root_len, path + logical_len);
    return buffer;
}

static int is_iosmacs_tty_fd(int fd) {
    return (fake_tty_fd >= 0 && fd == fake_tty_fd)
        || (stdio_redirected && fd >= STDIN_FILENO && fd <= STDERR_FILENO);
}

static void *output_pump_main(void *arg) {
    uint8_t buffer[4096];
    (void)arg;

    for (;;) {
        ssize_t count = read(fake_peer_fd, buffer, sizeof(buffer));
        if (count <= 0) {
            break;
        }
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
        ssize_t count = iosmacs_os_terminal_read(buffer, sizeof(buffer));
        if (count > 0) {
            ssize_t ignored = write(fake_peer_fd, buffer, (size_t)count);
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
    if (dup2(fd, STDERR_FILENO) < 0) {
        return -1;
    }
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
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

    memset(term, 0, sizeof(*term));
    term->c_iflag = ICRNL | IXON;
    term->c_oflag = OPOST | ONLCR;
    term->c_cflag = CREAD | CS8;
    term->c_lflag = ISIG | ICANON | ECHO | IEXTEN;
    term->c_cc[VINTR] = 3;
    term->c_cc[VQUIT] = 28;
    term->c_cc[VERASE] = 127;
    term->c_cc[VKILL] = 21;
    term->c_cc[VEOF] = 4;
    term->c_cc[VMIN] = 1;
    term->c_cc[VTIME] = 0;
    return 0;
}

int tcsetattr(int fd, int optional_actions, const struct termios *term) {
    (void)optional_actions;
    (void)term;
    if (!shim_enabled || !is_iosmacs_tty_fd(fd)) {
        errno = ENOTTY;
        return -1;
    }
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
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) != 0) {
        return -1;
    }

    fake_tty_fd = fds[0];
    fake_peer_fd = fds[1];
    iosmacs_os_set_lifecycle_state("iosmacs: fake tty opened");
    if (mirror_fd >= 0) {
        syscall(SYS_write, mirror_fd, opened_marker, sizeof(opened_marker) - 1);
    }
    pthread_create(&output_thread, NULL, output_pump_main, NULL);
    pthread_create(&input_thread, NULL, input_pump_main, NULL);
    return fake_tty_fd;
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
    actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_open, actual_path, flags, mode);
}

int access(const char *path, int mode) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_access, actual_path, mode);
}

int faccessat(int fd, const char *path, int mode, int flags) {
    char translated[PATH_MAX];
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
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_mkdir, actual_path, mode);
}

int mkdirat(int fd, const char *path, mode_t mode) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_mkdirat, fd, actual_path, mode);
}

int rmdir(const char *path) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_rmdir, actual_path);
}

int unlink(const char *path) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_unlink, actual_path);
}

int unlinkat(int fd, const char *path, int flags) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_unlinkat, fd, actual_path, flags);
}

int rename(const char *old_path, const char *new_path) {
    char translated_old[PATH_MAX];
    char translated_new[PATH_MAX];
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
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_chmod, actual_path, mode);
}

int fchmodat(int fd, const char *path, mode_t mode, int flags) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_fchmodat, fd, actual_path, mode, flags);
}

int chown(const char *path, uid_t owner, gid_t group) {
    char translated[PATH_MAX];
    const char *actual_path = translate_workspace_path(path, translated, sizeof(translated));
    if (actual_path == NULL) {
        return -1;
    }
    return (int)syscall(SYS_chown, actual_path, owner, group);
}

int fchownat(int fd, const char *path, uid_t owner, gid_t group, int flags) {
    char translated[PATH_MAX];
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
