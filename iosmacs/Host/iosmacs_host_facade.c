#include "iosmacs_host_facade.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#define IOSMACS_TERMINAL_BUFFER_SIZE (1024 * 1024)
#define IOSMACS_LIFECYCLE_STATE_SIZE 128

__attribute__((weak)) int iosmacs_swift_url_retrieve(const char *url,
                                                     int32_t timeout_ms,
                                                     int32_t *status_code,
                                                     unsigned char **body,
                                                     size_t *body_length,
                                                     char **headers,
                                                     char **error_message,
                                                     char **final_url) {
    (void)url;
    (void)timeout_ms;
    if (status_code != NULL) {
        *status_code = 0;
    }
    if (body != NULL) {
        *body = NULL;
    }
    if (body_length != NULL) {
        *body_length = 0;
    }
    if (headers != NULL) {
        *headers = NULL;
    }
    if (error_message != NULL) {
        *error_message = strdup("iosmacs Swift URLSession bridge is unavailable");
    }
    if (final_url != NULL) {
        *final_url = NULL;
    }
    errno = ENOSYS;
    return -1;
}

typedef struct iosmacs_ring_buffer {
    uint8_t bytes[IOSMACS_TERMINAL_BUFFER_SIZE];
    size_t head;
    size_t tail;
    size_t count;
} iosmacs_ring_buffer;

static iosmacs_ring_buffer input_ring;
static iosmacs_ring_buffer output_ring;
static pthread_mutex_t terminal_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t terminal_cond = PTHREAD_COND_INITIALIZER;
static char lifecycle_state[IOSMACS_LIFECYCLE_STATE_SIZE] = "iosmacs: initialized";
static int32_t terminal_cols = 80;
static int32_t terminal_rows = 24;
static uint64_t input_generation;
static uint64_t output_generation;
static uint64_t resize_generation;
static int direct_tty_mode;
static int stdio_redirected_to_terminal;
static int noted_tty_fds[16];
static size_t noted_tty_fd_count;
static int auto_xterm_replies = -1;
static char csi_query[64];
static size_t csi_query_len;
static char osc_query[128];
static size_t osc_query_len;
static enum {
    QUERY_STATE_GROUND,
    QUERY_STATE_ESC,
    QUERY_STATE_CSI,
    QUERY_STATE_OSC,
    QUERY_STATE_OSC_ESC
} query_state;

static void terminal_debug_log_bytes(const char *label, const uint8_t *bytes, size_t count) {
    const char *path = getenv("IOSMACS_WEB_TERMINAL_DEBUG_MARKER");
    if (path == NULL || path[0] == '\0' || label == NULL) {
        return;
    }

    int fd = (int)syscall(SYS_open, path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) {
        return;
    }
    char line[512];
    int offset = snprintf(line, sizeof(line), "terminal %s count=%zu bytes=", label, count);
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

static void terminal_debug_log_message(const char *prefix, const char *message) {
    const char *path = getenv("IOSMACS_WEB_TERMINAL_DEBUG_MARKER");
    if (path == NULL || path[0] == '\0' || prefix == NULL || message == NULL) {
        return;
    }

    int fd = (int)syscall(SYS_open, path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) {
        return;
    }
    char line[512];
    int length = snprintf(line, sizeof(line), "%s %s\n", prefix, message);
    if (length > 0) {
        syscall(SYS_write, fd, line, (size_t)length < sizeof(line) ? (size_t)length : sizeof(line));
    }
    syscall(SYS_close, fd);
}

static void terminal_debug_log_format(const char *prefix, const char *format, ...) {
    char message[384];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    terminal_debug_log_message(prefix, message);
}

static void ring_reset(iosmacs_ring_buffer *ring) {
    ring->head = 0;
    ring->tail = 0;
    ring->count = 0;
}

static size_t ring_write(iosmacs_ring_buffer *ring, const uint8_t *bytes, size_t count) {
    size_t written = 0;
    while (written < count && ring->count < IOSMACS_TERMINAL_BUFFER_SIZE) {
        ring->bytes[ring->tail] = bytes[written];
        ring->tail = (ring->tail + 1) % IOSMACS_TERMINAL_BUFFER_SIZE;
        ring->count++;
        written++;
    }
    return written;
}

static size_t ring_read(iosmacs_ring_buffer *ring, uint8_t *buffer, size_t capacity) {
    size_t read_count = 0;
    while (read_count < capacity && ring->count > 0) {
        buffer[read_count] = ring->bytes[ring->head];
        ring->head = (ring->head + 1) % IOSMACS_TERMINAL_BUFFER_SIZE;
        ring->count--;
        read_count++;
    }
    return read_count;
}

static void terminal_note_tty_fd_locked(int fd) {
    if (fd < 0) {
        return;
    }
    for (size_t i = 0; i < noted_tty_fd_count; i++) {
        if (noted_tty_fds[i] == fd) {
            return;
        }
    }
    if (noted_tty_fd_count < sizeof(noted_tty_fds) / sizeof(noted_tty_fds[0])) {
        noted_tty_fds[noted_tty_fd_count++] = fd;
    }
}

static void terminal_enable_direct_mode_locked(void) {
    if (!direct_tty_mode) {
        direct_tty_mode = 1;
        iosmacs_os_set_lifecycle_state("iosmacs: direct tty facade active");
    }
}

static void terminal_make_timeout(struct timespec *deadline, int timeout_ms) {
    clock_gettime(CLOCK_REALTIME, deadline);
    deadline->tv_sec += timeout_ms / 1000;
    deadline->tv_nsec += (long)(timeout_ms % 1000) * 1000000L;
    if (deadline->tv_nsec >= 1000000000L) {
        deadline->tv_sec += 1;
        deadline->tv_nsec -= 1000000000L;
    }
}

static bool terminal_auto_xterm_replies_enabled(void) {
    if (auto_xterm_replies < 0) {
        const char *value = getenv("IOSMACS_TERMINAL_AUTO_XTERM_REPLIES");
        auto_xterm_replies = value != NULL && strcmp(value, "0") != 0;
    }
    return auto_xterm_replies != 0;
}

static void terminal_push_reply_locked(const char *reply) {
    if (direct_tty_mode) {
        return;
    }
    if (ring_write(&input_ring, (const uint8_t *)reply, strlen(reply)) > 0) {
        input_generation++;
        pthread_cond_broadcast(&terminal_cond);
    }
}

static bool terminal_query_is_final_byte(uint8_t byte) {
    return byte >= 0x40 && byte <= 0x7e;
}

static void terminal_handle_csi_query_locked(char final_byte) {
    csi_query[csi_query_len] = '\0';
    if (final_byte == 'c') {
        if (strcmp(csi_query, ">") == 0 || strcmp(csi_query, ">0") == 0) {
            terminal_push_reply_locked("\033[>0;276;0c");
        } else if (csi_query_len == 0 || strcmp(csi_query, "0") == 0) {
            terminal_push_reply_locked("\033[?65;1;2;6;21;22;17;28c");
        }
    } else if (final_byte == 'n') {
        if (strcmp(csi_query, "5") == 0) {
            terminal_push_reply_locked("\033[0n");
        } else if (strcmp(csi_query, "6") == 0) {
            terminal_push_reply_locked("\033[1;1R");
        } else if (strcmp(csi_query, "?6") == 0) {
            terminal_push_reply_locked("\033[?1;1;1R");
        }
    } else if (final_byte == 't') {
        if (strcmp(csi_query, "18") == 0) {
            char reply[32];
            snprintf(reply, sizeof(reply), "\033[8;%d;%dt", terminal_rows, terminal_cols);
            terminal_push_reply_locked(reply);
        }
    }
}

static bool terminal_osc_query_matches(const char *prefix) {
    size_t prefix_len = strlen(prefix);
    return strncmp(osc_query, prefix, prefix_len) == 0
        && osc_query[prefix_len] == '?'
        && osc_query[prefix_len + 1] == '\0';
}

static void terminal_handle_osc_query_locked(void) {
    osc_query[osc_query_len] = '\0';
    if (terminal_osc_query_matches("10;")) {
        terminal_push_reply_locked("\033]10;rgb:ffff/ffff/ffff\033\\");
    } else if (terminal_osc_query_matches("11;")) {
        terminal_push_reply_locked("\033]11;rgb:0000/0000/0000\033\\");
    } else if (terminal_osc_query_matches("12;")) {
        terminal_push_reply_locked("\033]12;rgb:ffff/ffff/ffff\033\\");
    } else if (strncmp(osc_query, "4;", 2) == 0) {
        char *query = strstr(osc_query + 2, ";?");
        if (query != NULL && query[2] == '\0') {
            *query = '\0';
            char reply[80];
            snprintf(reply, sizeof(reply), "\033]4;%s;rgb:0000/0000/0000\033\\", osc_query + 2);
            terminal_push_reply_locked(reply);
        }
    }
}

static void terminal_observe_output_locked(const uint8_t *bytes, size_t count) {
    if (!terminal_auto_xterm_replies_enabled()) {
        return;
    }

    for (size_t i = 0; i < count; i++) {
        uint8_t byte = bytes[i];
        switch (query_state) {
        case QUERY_STATE_GROUND:
            query_state = byte == 0x1b ? QUERY_STATE_ESC : QUERY_STATE_GROUND;
            break;
        case QUERY_STATE_ESC:
            if (byte == '[') {
                csi_query_len = 0;
                query_state = QUERY_STATE_CSI;
            } else if (byte == ']') {
                osc_query_len = 0;
                query_state = QUERY_STATE_OSC;
            } else {
                query_state = byte == 0x1b ? QUERY_STATE_ESC : QUERY_STATE_GROUND;
            }
            break;
        case QUERY_STATE_CSI:
            if (terminal_query_is_final_byte(byte)) {
                terminal_handle_csi_query_locked((char)byte);
                query_state = QUERY_STATE_GROUND;
            } else if (csi_query_len + 1 < sizeof(csi_query)) {
                csi_query[csi_query_len++] = (char)byte;
            } else {
                query_state = QUERY_STATE_GROUND;
            }
            break;
        case QUERY_STATE_OSC:
            if (byte == 0x07) {
                terminal_handle_osc_query_locked();
                query_state = QUERY_STATE_GROUND;
            } else if (byte == 0x1b) {
                query_state = QUERY_STATE_OSC_ESC;
            } else if (osc_query_len + 1 < sizeof(osc_query)) {
                osc_query[osc_query_len++] = (char)byte;
            } else {
                query_state = QUERY_STATE_GROUND;
            }
            break;
        case QUERY_STATE_OSC_ESC:
            if (byte == '\\') {
                terminal_handle_osc_query_locked();
            }
            query_state = QUERY_STATE_GROUND;
            break;
        }
    }
}

const char *iosmacs_os_lifecycle_state(void) {
    return lifecycle_state;
}

void iosmacs_os_set_lifecycle_state(const char *state) {
    if (state == NULL) {
        return;
    }
    strlcpy(lifecycle_state, state, sizeof(lifecycle_state));
}

void iosmacs_os_terminal_reset(void) {
    pthread_mutex_lock(&terminal_mutex);
    ring_reset(&input_ring);
    ring_reset(&output_ring);
    input_generation++;
    output_generation++;
    resize_generation++;
    direct_tty_mode = 1;
    query_state = QUERY_STATE_GROUND;
    csi_query_len = 0;
    osc_query_len = 0;
    pthread_cond_broadcast(&terminal_cond);
    pthread_mutex_unlock(&terminal_mutex);
}

void iosmacs_os_terminal_resize(int32_t cols, int32_t rows) {
    bool changed = false;
    pthread_mutex_lock(&terminal_mutex);
    if (cols > 0) {
        changed = terminal_cols != cols;
        terminal_cols = cols;
    }
    if (rows > 0) {
        changed = changed || terminal_rows != rows;
        terminal_rows = rows;
    }
    if (changed) {
        resize_generation++;
        pthread_cond_broadcast(&terminal_cond);
        raise(SIGWINCH);
    }
    pthread_mutex_unlock(&terminal_mutex);
}

int32_t iosmacs_os_terminal_cols(void) {
    pthread_mutex_lock(&terminal_mutex);
    int32_t cols = terminal_cols;
    pthread_mutex_unlock(&terminal_mutex);
    return cols;
}

int32_t iosmacs_os_terminal_rows(void) {
    pthread_mutex_lock(&terminal_mutex);
    int32_t rows = terminal_rows;
    pthread_mutex_unlock(&terminal_mutex);
    return rows;
}

ssize_t iosmacs_os_terminal_read(uint8_t *buffer, size_t capacity) {
    if (buffer == NULL && capacity > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    ssize_t count = (ssize_t)ring_read(&input_ring, buffer, capacity);
    pthread_mutex_unlock(&terminal_mutex);
    return count;
}

ssize_t iosmacs_os_terminal_write(const uint8_t *bytes, size_t count) {
    if (bytes == NULL && count > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    terminal_observe_output_locked(bytes, count);
    ssize_t written = (ssize_t)ring_write(&output_ring, bytes, count);
    if (written > 0) {
        output_generation++;
        pthread_cond_broadcast(&terminal_cond);
    }
    pthread_mutex_unlock(&terminal_mutex);
    if (written > 0) {
        terminal_debug_log_bytes("write-output", bytes, (size_t)written);
    }
    return written;
}

ssize_t iosmacs_os_terminal_push_input(const uint8_t *bytes, size_t count) {
    if (bytes == NULL && count > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    ssize_t written = (ssize_t)ring_write(&input_ring, bytes, count);
    if (written > 0 || count == 0) {
        input_generation++;
        pthread_cond_broadcast(&terminal_cond);
    }
    pthread_mutex_unlock(&terminal_mutex);
    terminal_debug_log_bytes("push-input", bytes, count);
#ifdef SIGIO
    if (written > 0) {
        raise(SIGIO);
    }
#endif
    return written;
}

void iosmacs_os_terminal_note_input_signal(size_t count) {
    pthread_mutex_lock(&terminal_mutex);
    input_generation++;
    pthread_cond_broadcast(&terminal_cond);
    pthread_mutex_unlock(&terminal_mutex);
    terminal_debug_log_format("terminal", "input-signal count=%zu", count);
#ifdef SIGIO
    if (count > 0) {
        raise(SIGIO);
    }
#endif
}

ssize_t iosmacs_os_terminal_drain_output(uint8_t *buffer, size_t capacity) {
    if (buffer == NULL && capacity > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    ssize_t count = (ssize_t)ring_read(&output_ring, buffer, capacity);
    pthread_mutex_unlock(&terminal_mutex);
    if (count > 0) {
        terminal_debug_log_bytes("drain-output", buffer, (size_t)count);
    }
    return count;
}

int iosmacs_os_terminal_wait_for_output(int timeout_ms) {
    int result = IOSMACS_HOST_WAIT_TIMEOUT;
    pthread_mutex_lock(&terminal_mutex);
    uint64_t seen_output = output_generation;
    while (output_ring.count == 0 && seen_output == output_generation) {
        if (timeout_ms < 0) {
            pthread_cond_wait(&terminal_cond, &terminal_mutex);
        } else {
            struct timespec deadline;
            terminal_make_timeout(&deadline, timeout_ms);
            int wait_result = pthread_cond_timedwait(&terminal_cond, &terminal_mutex, &deadline);
            if (wait_result == ETIMEDOUT) {
                break;
            }
        }
    }
    if (output_ring.count > 0 || seen_output != output_generation) {
        result = IOSMACS_HOST_WAIT_OUTPUT;
    }
    pthread_mutex_unlock(&terminal_mutex);
    return result;
}

int iosmacs_os_terminal_wait_for_input(int timeout_ms) {
    int result = IOSMACS_HOST_WAIT_TIMEOUT;
    pthread_mutex_lock(&terminal_mutex);
    terminal_enable_direct_mode_locked();
    uint64_t seen_input = input_generation;
    uint64_t seen_resize = resize_generation;
    size_t initial_input_count = input_ring.count;
    terminal_debug_log_format(
        "terminal",
        "wait-enter timeout=%d ring=%zu input_gen=%llu resize_gen=%llu",
        timeout_ms,
        initial_input_count,
        (unsigned long long)input_generation,
        (unsigned long long)resize_generation
    );
    while (input_ring.count == 0
           && seen_input == input_generation
           && seen_resize == resize_generation) {
        if (timeout_ms < 0) {
            pthread_cond_wait(&terminal_cond, &terminal_mutex);
        } else {
            struct timespec deadline;
            terminal_make_timeout(&deadline, timeout_ms);
            int wait_result = pthread_cond_timedwait(&terminal_cond, &terminal_mutex, &deadline);
            if (wait_result == ETIMEDOUT) {
                break;
            }
        }
    }
    if (input_ring.count > 0 || seen_input != input_generation) {
        result = IOSMACS_HOST_WAIT_INPUT;
    } else if (seen_resize != resize_generation) {
        result = IOSMACS_HOST_WAIT_RESIZE;
    }
    terminal_debug_log_format(
        "terminal",
        "wait-exit result=%d ring=%zu input_gen=%llu resize_gen=%llu",
        result,
        input_ring.count,
        (unsigned long long)input_generation,
        (unsigned long long)resize_generation
    );
    pthread_mutex_unlock(&terminal_mutex);
    return result;
}

int iosmacs_os_terminal_read_byte(void) {
    uint8_t byte = 0;
    pthread_mutex_lock(&terminal_mutex);
    terminal_enable_direct_mode_locked();
    size_t count = ring_read(&input_ring, &byte, 1);
    size_t remaining = input_ring.count;
    pthread_mutex_unlock(&terminal_mutex);
    if (count == 1) {
        terminal_debug_log_format("terminal", "read-byte byte=%02x remaining=%zu", byte, remaining);
    } else {
        terminal_debug_log_message("terminal", "read-byte empty");
    }
    return count == 1 ? (int)byte : -1;
}

int iosmacs_os_terminal_input_available(void) {
    pthread_mutex_lock(&terminal_mutex);
    int available = input_ring.count > 0 ? 1 : 0;
    size_t count = input_ring.count;
    pthread_mutex_unlock(&terminal_mutex);
    terminal_debug_log_format("terminal", "input-available result=%d ring=%zu", available, count);
    return available;
}

int iosmacs_os_terminal_flush_output(void) {
    return 0;
}

void iosmacs_os_terminal_note_tty_fd(int fd) {
    pthread_mutex_lock(&terminal_mutex);
    terminal_note_tty_fd_locked(fd);
    pthread_mutex_unlock(&terminal_mutex);
}

void iosmacs_os_terminal_note_stdio_redirected(void) {
    pthread_mutex_lock(&terminal_mutex);
    stdio_redirected_to_terminal = 1;
    terminal_note_tty_fd_locked(STDIN_FILENO);
    terminal_note_tty_fd_locked(STDOUT_FILENO);
    terminal_note_tty_fd_locked(STDERR_FILENO);
    pthread_mutex_unlock(&terminal_mutex);
}

int iosmacs_os_terminal_is_tty_fd(int fd) {
    pthread_mutex_lock(&terminal_mutex);
    int is_tty = 0;
    if (direct_tty_mode) {
        if (stdio_redirected_to_terminal && fd >= STDIN_FILENO && fd <= STDERR_FILENO) {
            is_tty = 1;
        }
        for (size_t i = 0; !is_tty && i < noted_tty_fd_count; i++) {
            if (noted_tty_fds[i] == fd) {
                is_tty = 1;
            }
        }
    }
    pthread_mutex_unlock(&terminal_mutex);
    return is_tty;
}

int iosmacs_os_terminal_direct_mode_enabled(void) {
    pthread_mutex_lock(&terminal_mutex);
    int enabled = direct_tty_mode;
    pthread_mutex_unlock(&terminal_mutex);
    return enabled;
}

int iosmacs_host_wait_for_input(int timeout_ms) {
    terminal_debug_log_format("host", "wait-enter timeout=%d", timeout_ms);
    iosmacs_os_terminal_flush_output();
    int result = iosmacs_os_terminal_wait_for_input(timeout_ms);
    terminal_debug_log_format("host", "wait-exit result=%d", result);
    return result;
}

int iosmacs_host_terminal_read_byte(void) {
    return iosmacs_os_terminal_read_byte();
}

int iosmacs_host_terminal_input_available(void) {
    return iosmacs_os_terminal_input_available();
}

int iosmacs_host_flush_terminal_output(void) {
    return iosmacs_os_terminal_flush_output();
}

int iosmacs_host_is_tty_fd(int fd) {
    return iosmacs_os_terminal_is_tty_fd(fd);
}

void iosmacs_host_trace_event(const char *message) {
    terminal_debug_log_message("emacs", message);
}

int iosmacs_host_url_retrieve(const char *url,
                              int timeout_ms,
                              int *status_code,
                              char **headers,
                              unsigned char **body,
                              size_t *body_length,
                              char **error_message,
                              char **final_url) {
    if (url == NULL || status_code == NULL || headers == NULL || body == NULL
        || body_length == NULL || error_message == NULL || final_url == NULL) {
        errno = EINVAL;
        return -1;
    }
    *status_code = 0;
    *headers = NULL;
    *body = NULL;
    *body_length = 0;
    *error_message = NULL;
    *final_url = NULL;
    if (iosmacs_swift_url_retrieve == NULL) {
        *error_message = strdup("iosmacs Swift URLSession bridge is unavailable");
        errno = ENOSYS;
        return -1;
    }

    int32_t swift_status_code = 0;
    int result = iosmacs_swift_url_retrieve(
        url,
        (int32_t)timeout_ms,
        &swift_status_code,
        body,
        body_length,
        headers,
        error_message,
        final_url
    );
    *status_code = (int)swift_status_code;
    return result;
}

void iosmacs_host_free(void *pointer) {
    free(pointer);
}

int iosmacs_os_open(const char *path, int flags, int mode) {
    return open(path, flags, (mode_t)mode);
}

ssize_t iosmacs_os_read(int fd, void *buffer, size_t count) {
    return read(fd, buffer, count);
}

ssize_t iosmacs_os_write(int fd, const void *buffer, size_t count) {
    return write(fd, buffer, count);
}

int iosmacs_os_stat(const char *path, struct stat *st) {
    return stat(path, st);
}

int iosmacs_os_readdir_unavailable(const char *path) {
    (void)path;
    errno = ENOSYS;
    return -1;
}

int iosmacs_os_process_unavailable(const char *operation) {
    (void)operation;
    errno = ENOSYS;
    return -1;
}
