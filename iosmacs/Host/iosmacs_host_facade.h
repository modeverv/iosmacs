#ifndef IOSMACS_HOST_FACADE_H
#define IOSMACS_HOST_FACADE_H

#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *iosmacs_os_lifecycle_state(void);
void iosmacs_os_set_lifecycle_state(const char *state);

void iosmacs_os_terminal_reset(void);
void iosmacs_os_terminal_resize(int32_t cols, int32_t rows);
int32_t iosmacs_os_terminal_cols(void);
int32_t iosmacs_os_terminal_rows(void);
ssize_t iosmacs_os_terminal_read(uint8_t *buffer, size_t capacity);
ssize_t iosmacs_os_terminal_write(const uint8_t *bytes, size_t count);
ssize_t iosmacs_os_terminal_push_input(const uint8_t *bytes, size_t count);
ssize_t iosmacs_os_terminal_drain_output(uint8_t *buffer, size_t capacity);

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
