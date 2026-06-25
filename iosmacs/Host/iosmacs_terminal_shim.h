#ifndef IOSMACS_TERMINAL_SHIM_H
#define IOSMACS_TERMINAL_SHIM_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

void iosmacs_terminal_shim_enable(void);
void iosmacs_terminal_shim_set_mirror_fd(int fd);
int iosmacs_terminal_shim_attach_stdio(void);
bool iosmacs_terminal_shim_is_open(void);
ssize_t iosmacs_terminal_shim_push_input(const uint8_t *bytes, size_t count);

#ifdef __cplusplus
}
#endif

#endif
