#include "iosmacs_emacs_diagnostic.h"

#include "iosmacs_emacs_core.h"
#include "iosmacs_host_facade.h"

#include <stdio.h>
#include <string.h>

static void terminal_puts(const char *text) {
    iosmacs_os_terminal_write((const uint8_t *)text, strlen(text));
}

void iosmacs_emacs_diagnostic_start(void) {
    char banner[512];
    snprintf(
        banner,
        sizeof(banner),
        "\033[2J\033[Hiosmacs diagnostic terminal\r\n"
        "xterm.js is rendering the iOS terminal layer in WKWebView.\r\n"
        "Emacs core link: %s (%s)\r\n"
        "Emacs source: wasmacs/vendor/emacs\r\n"
        "Terminal: %d cols x %d rows\r\n\r\n"
        "*scratch*\r\n"
        ";; real GNU Emacs startup will replace this diagnostic runner\r\n\r\n",
        iosmacs_emacs_core_link_available() ? "available" : "unavailable",
        iosmacs_emacs_core_entry_symbol_name(),
        iosmacs_os_terminal_cols(),
        iosmacs_os_terminal_rows());
    terminal_puts(banner);
    iosmacs_os_set_lifecycle_state("iosmacs: diagnostic terminal ready");
}

void iosmacs_emacs_diagnostic_pump(void) {
    uint8_t buffer[256];
    ssize_t count = iosmacs_os_terminal_read(buffer, sizeof(buffer));
    if (count <= 0) {
        return;
    }

    terminal_puts("\r\ninput bytes:");
    for (ssize_t index = 0; index < count; index++) {
        char encoded[8];
        snprintf(encoded, sizeof(encoded), " %02x", buffer[index]);
        terminal_puts(encoded);
    }
    terminal_puts("\r\n");
    iosmacs_os_terminal_write(buffer, (size_t)count);
    iosmacs_os_set_lifecycle_state("iosmacs: diagnostic input received");
}
