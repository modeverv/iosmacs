#ifndef IOSMACS_HOST_FACADE_H
#define IOSMACS_HOST_FACADE_H

#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define IOSMACS_HOST_WAIT_TIMEOUT 0
#define IOSMACS_HOST_WAIT_INPUT 1
#define IOSMACS_HOST_WAIT_RESIZE 2
#define IOSMACS_HOST_WAIT_UNAVAILABLE -1

const char *iosmacs_os_lifecycle_state(void);
void iosmacs_os_set_lifecycle_state(const char *state);

void iosmacs_os_terminal_reset(void);
void iosmacs_os_terminal_resize(int32_t cols, int32_t rows);
int32_t iosmacs_os_terminal_cols(void);
int32_t iosmacs_os_terminal_rows(void);
ssize_t iosmacs_os_terminal_read(uint8_t *buffer, size_t capacity);
ssize_t iosmacs_os_terminal_write(const uint8_t *bytes, size_t count);
ssize_t iosmacs_os_terminal_push_input(const uint8_t *bytes, size_t count);
void iosmacs_os_terminal_note_input_signal(size_t count);
ssize_t iosmacs_os_terminal_drain_output(uint8_t *buffer, size_t capacity);
int iosmacs_os_terminal_wait_for_input(int timeout_ms);
int iosmacs_os_terminal_read_byte(void);
int iosmacs_os_terminal_input_available(void);
int iosmacs_os_terminal_flush_output(void);
void iosmacs_os_terminal_note_tty_fd(int fd);
void iosmacs_os_terminal_note_stdio_redirected(void);
int iosmacs_os_terminal_is_tty_fd(int fd);
int iosmacs_os_terminal_direct_mode_enabled(void);

int iosmacs_host_wait_for_input(int timeout_ms);
int iosmacs_host_terminal_read_byte(void);
int iosmacs_host_terminal_input_available(void);
int iosmacs_host_flush_terminal_output(void);
int iosmacs_host_is_tty_fd(int fd);
void iosmacs_host_trace_event(const char *message);
int iosmacs_host_url_retrieve(const char *url,
                              int timeout_ms,
                              int *status_code,
                              char **headers,
                              unsigned char **body,
                              size_t *body_length,
                              char **error_message,
                              char **final_url);
void iosmacs_host_free(void *pointer);

int iosmacs_os_open(const char *path, int flags, int mode);
ssize_t iosmacs_os_read(int fd, void *buffer, size_t count);
ssize_t iosmacs_os_write(int fd, const void *buffer, size_t count);
int iosmacs_os_stat(const char *path, struct stat *st);
int iosmacs_os_readdir_unavailable(const char *path);
int iosmacs_os_process_unavailable(const char *operation);

#ifdef __cplusplus
}
#endif

#endif
