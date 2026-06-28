#ifndef IOSMACS_EMACS_CORE_H
#define IOSMACS_EMACS_CORE_H

#include <stdbool.h>

bool iosmacs_emacs_core_link_available(void);
const char *iosmacs_emacs_core_entry_symbol_name(void);
bool iosmacs_emacs_core_start(const char *lisp_dir,
                              const char *etc_dir,
                              const char *exec_dir,
                              const char *dump_file,
                              const char *workspace_root);
bool iosmacs_emacs_core_is_running(void);
int iosmacs_emacs_core_exit_status(void);

#endif
