#include "iosmacs_host_facade.h"

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define IOSMACS_TERMINAL_BUFFER_SIZE 65536
#define IOSMACS_LIFECYCLE_STATE_SIZE 128

typedef struct iosmacs_ring_buffer {
    uint8_t bytes[IOSMACS_TERMINAL_BUFFER_SIZE];
    size_t head;
    size_t tail;
    size_t count;
} iosmacs_ring_buffer;

static iosmacs_ring_buffer input_ring;
static iosmacs_ring_buffer output_ring;
static pthread_mutex_t terminal_mutex = PTHREAD_MUTEX_INITIALIZER;
static char lifecycle_state[IOSMACS_LIFECYCLE_STATE_SIZE] = "iosmacs: initialized";
static int32_t terminal_cols = 80;
static int32_t terminal_rows = 24;
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

static bool terminal_auto_xterm_replies_enabled(void) {
    if (auto_xterm_replies < 0) {
        const char *value = getenv("IOSMACS_TERMINAL_AUTO_XTERM_REPLIES");
        auto_xterm_replies = value != NULL && strcmp(value, "0") != 0;
    }
    return auto_xterm_replies != 0;
}

static void terminal_push_reply_locked(const char *reply) {
    ring_write(&input_ring, (const uint8_t *)reply, strlen(reply));
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
    query_state = QUERY_STATE_GROUND;
    csi_query_len = 0;
    osc_query_len = 0;
    pthread_mutex_unlock(&terminal_mutex);
}

void iosmacs_os_terminal_resize(int32_t cols, int32_t rows) {
    if (cols > 0) {
        terminal_cols = cols;
    }
    if (rows > 0) {
        terminal_rows = rows;
    }
}

int32_t iosmacs_os_terminal_cols(void) {
    return terminal_cols;
}

int32_t iosmacs_os_terminal_rows(void) {
    return terminal_rows;
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
    pthread_mutex_unlock(&terminal_mutex);
    return written;
}

ssize_t iosmacs_os_terminal_push_input(const uint8_t *bytes, size_t count) {
    if (bytes == NULL && count > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    ssize_t written = (ssize_t)ring_write(&input_ring, bytes, count);
    pthread_mutex_unlock(&terminal_mutex);
    return written;
}

ssize_t iosmacs_os_terminal_drain_output(uint8_t *buffer, size_t capacity) {
    if (buffer == NULL && capacity > 0) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&terminal_mutex);
    ssize_t count = (ssize_t)ring_read(&output_ring, buffer, capacity);
    pthread_mutex_unlock(&terminal_mutex);
    return count;
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
