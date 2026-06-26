#include "iosmacs_emacs_core.h"

#include "iosmacs_host_facade.h"
#include "iosmacs_terminal_shim.h"

#include <TargetConditionals.h>
#include <dirent.h>
#include <locale.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#if TARGET_OS_SIMULATOR
#if IOSMACS_EMACS_CORE_ENTRY_OPTIONAL
static int (*volatile iosmacs_emacs_entry_ref)(int, char **) = NULL;
#else
extern int iosmacs_emacs_main(int argc, char **argv);
static int (*volatile iosmacs_emacs_entry_ref)(int, char **) = iosmacs_emacs_main;
#endif
static pthread_mutex_t emacs_core_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_t emacs_core_thread;
static bool emacs_core_started;
static bool emacs_core_running;
static int emacs_core_exit_status_value = -1;
static const size_t emacs_core_stack_size = 16 * 1024 * 1024;

typedef struct iosmacs_emacs_start_context {
    char *lisp_dir;
    char *etc_dir;
    char *exec_dir;
    char *dump_file;
    char *workspace_root;
} iosmacs_emacs_start_context;

static char *copy_c_string(const char *value) {
    if (value == NULL) {
        return NULL;
    }
    return strdup(value);
}

static char *copy_parent_dir(const char *path) {
    if (path == NULL) {
        return NULL;
    }
    char *parent = strdup(path);
    if (parent == NULL) {
        return NULL;
    }
    char *slash = strrchr(parent, '/');
    if (slash == NULL || slash == parent) {
        free(parent);
        return NULL;
    }
    *slash = '\0';
    return parent;
}

static void free_start_context(iosmacs_emacs_start_context *context) {
    if (context == NULL) {
        return;
    }
    free(context->lisp_dir);
    free(context->etc_dir);
    free(context->exec_dir);
    free(context->dump_file);
    free(context->workspace_root);
    free(context);
}

static void set_lisp_load_path(const char *physical_lisp_dir, const char *logical_lisp_dir) {
    if (physical_lisp_dir == NULL || logical_lisp_dir == NULL) {
        return;
    }

    size_t count = 0;
    size_t capacity = 32;
    char **dirs = calloc(capacity, sizeof(*dirs));
    if (dirs == NULL) {
        setenv("EMACSLOADPATH", logical_lisp_dir, 1);
        return;
    }

    DIR *dir = opendir(physical_lisp_dir);
    if (dir != NULL) {
        struct dirent *entry = NULL;
        while ((entry = readdir(dir)) != NULL) {
            if (entry->d_name[0] == '.') {
                continue;
            }

            int physical_length = snprintf(NULL, 0, "%s/%s", physical_lisp_dir, entry->d_name);
            int logical_length = snprintf(NULL, 0, "%s/%s", logical_lisp_dir, entry->d_name);
            if (physical_length <= 0 || logical_length <= 0) {
                continue;
            }
            char *physical_path = malloc((size_t)physical_length + 1);
            char *logical_path = malloc((size_t)logical_length + 1);
            if (physical_path == NULL || logical_path == NULL) {
                free(physical_path);
                free(logical_path);
                continue;
            }
            snprintf(physical_path, (size_t)physical_length + 1, "%s/%s", physical_lisp_dir, entry->d_name);
            snprintf(logical_path, (size_t)logical_length + 1, "%s/%s", logical_lisp_dir, entry->d_name);

            struct stat st;
            if (stat(physical_path, &st) == 0 && S_ISDIR(st.st_mode)) {
                if (count == capacity) {
                    size_t next_capacity = capacity * 2;
                    char **next_dirs = realloc(dirs, next_capacity * sizeof(*next_dirs));
                    if (next_dirs == NULL) {
                        free(physical_path);
                        free(logical_path);
                        continue;
                    }
                    dirs = next_dirs;
                    capacity = next_capacity;
                }
                dirs[count++] = logical_path;
            } else {
                free(logical_path);
            }
            free(physical_path);
        }
        closedir(dir);
    }

    for (size_t i = 0; i < count; i++) {
        for (size_t j = i + 1; j < count; j++) {
            if (strcmp(dirs[i], dirs[j]) > 0) {
                char *tmp = dirs[i];
                dirs[i] = dirs[j];
                dirs[j] = tmp;
            }
        }
    }

    size_t length = strlen(logical_lisp_dir) + 1;
    for (size_t i = 0; i < count; i++) {
        length += 1 + strlen(dirs[i]);
    }
    char *load_path = malloc(length);
    if (load_path == NULL) {
        setenv("EMACSLOADPATH", logical_lisp_dir, 1);
        for (size_t i = 0; i < count; i++) {
            free(dirs[i]);
        }
        free(dirs);
        return;
    }
    snprintf(load_path, length, "%s", logical_lisp_dir);
    for (size_t i = 0; i < count; i++) {
        strlcat(load_path, ":", length);
        strlcat(load_path, dirs[i], length);
        free(dirs[i]);
    }
    free(dirs);

    setenv("EMACSLOADPATH", load_path, 1);
    free(load_path);
}

static char *copy_lisp_string_literal(const char *value) {
    size_t length = 2;
    for (const char *p = value; p != NULL && *p != '\0'; p++) {
        if (*p == '\\' || *p == '"') {
            length++;
        }
        length++;
    }

    char *quoted = malloc(length + 1);
    if (quoted == NULL) {
        return NULL;
    }

    char *out = quoted;
    *out++ = '"';
    for (const char *p = value; p != NULL && *p != '\0'; p++) {
        if (*p == '\\' || *p == '"') {
            *out++ = '\\';
        }
        *out++ = *p;
    }
    *out++ = '"';
    *out = '\0';
    return quoted;
}

static char *copy_app_smoke_eval_form(void) {
    const char *marker = getenv("IOSMACS_APP_SMOKE_MARKER");
    if (marker == NULL || marker[0] == '\0') {
        return NULL;
    }

    const char *expect = getenv("IOSMACS_APP_SMOKE_EXPECT");
    if (expect == NULL || expect[0] == '\0') {
        expect = "abc";
    }

    char *quoted_marker = copy_lisp_string_literal(marker);
    char *quoted_expect = copy_lisp_string_literal(expect);
    if (quoted_marker == NULL || quoted_expect == NULL) {
        free(quoted_marker);
        free(quoted_expect);
        return NULL;
    }

    const char *format =
        "(progn "
        "(defun iosmacs-app-smoke-write (text) "
        "(write-region (concat (format \"iosmacs-app-smoke:%%S\\n\" text) "
        "\"iosmacs-app-smoke-ok\\n\") nil %s nil nil) "
        "(princ (format \"iosmacs-app-smoke:%%S\\n\" text) 'external-debugging-output)) "
        "(defun iosmacs-app-smoke-check () "
        "(let ((text (save-current-buffer (set-buffer \"*scratch*\") (buffer-string)))) "
        "(if (string-match-p %s text) "
        "(progn "
        "(iosmacs-app-smoke-write text) "
        "(remove-hook 'post-command-hook 'iosmacs-app-smoke-check))))) "
        "(add-hook 'post-command-hook 'iosmacs-app-smoke-check) "
        "(run-at-time 8 1 "
        "(lambda () "
        "(let ((text (save-current-buffer (set-buffer \"*scratch*\") (buffer-string)))) "
        "(when (string-match-p %s text) "
        "(iosmacs-app-smoke-write text))))))";
    int length = snprintf(NULL, 0, format, quoted_marker, quoted_expect, quoted_expect);
    if (length < 0) {
        free(quoted_marker);
        free(quoted_expect);
        return NULL;
    }

    char *eval_form = malloc((size_t)length + 1);
    if (eval_form != NULL) {
        snprintf(eval_form, (size_t)length + 1, format, quoted_marker, quoted_expect, quoted_expect);
    }
    free(quoted_marker);
    free(quoted_expect);
    return eval_form;
}

static char *copy_app_file_smoke_eval_form(void) {
    const char *marker = getenv("IOSMACS_APP_FILE_SMOKE_MARKER");
    if (marker == NULL || marker[0] == '\0') {
        return NULL;
    }

    char *quoted_marker = copy_lisp_string_literal(marker);
    if (quoted_marker == NULL) {
        return NULL;
    }

    const char *format =
        "(progn "
        "(run-at-time 3 nil "
        "(lambda () "
        "(condition-case err "
        "(let* ((dir \"/home/user/notes/\") "
        "(file (concat dir \"iosmacs-file-smoke.txt\")) "
        "(text \"iosmacs-file-smoke\\n\")) "
        "(require 'ls-lisp) "
        "(setq ls-lisp-use-insert-directory-program nil "
        "insert-directory-program nil "
        "dired-use-ls-dired nil) "
        "(require 'dired) "
        "(require 'dired-aux) "
        "(make-directory dir t) "
        "(find-file file) "
        "(erase-buffer) "
        "(insert text) "
        "(save-buffer) "
        "(kill-buffer (current-buffer)) "
        "(find-file file) "
        "(unless (string-match-p \"iosmacs-file-smoke\" (buffer-string)) "
        "(error \"reloaded file did not contain smoke text\")) "
        "(let ((dired-buffer (dired-noselect dir))) "
        "(with-current-buffer dired-buffer "
        "(goto-char (point-min)) "
        "(unless (search-forward \"iosmacs-file-smoke.txt\" nil t) "
        "(error \"dired did not list smoke file\")))) "
        "(write-region \"iosmacs-app-file-smoke-ok\\n\" nil %s nil nil) "
        "(princ \"iosmacs-app-file-smoke-ok\\n\" 'external-debugging-output)) "
        "(error "
        "(write-region (format \"iosmacs-app-file-smoke-error:%%S\\n\" err) nil %s nil nil) "
        "(princ (format \"iosmacs-app-file-smoke-error:%%S\\n\" err) "
        "'external-debugging-output))))))";
    int length = snprintf(NULL, 0, format, quoted_marker, quoted_marker);
    if (length < 0) {
        free(quoted_marker);
        return NULL;
    }

    char *eval_form = malloc((size_t)length + 1);
    if (eval_form != NULL) {
        snprintf(eval_form, (size_t)length + 1, format, quoted_marker, quoted_marker);
    }
    free(quoted_marker);
    return eval_form;
}

static char *copy_app_color_smoke_eval_form(void) {
    const char *marker = getenv("IOSMACS_APP_COLOR_SMOKE_MARKER");
    if (marker == NULL || marker[0] == '\0') {
        return NULL;
    }

    char *quoted_marker = copy_lisp_string_literal(marker);
    if (quoted_marker == NULL) {
        return NULL;
    }

    const char *format =
        "(progn "
        "(run-at-time 4 nil "
        "(lambda () "
        "(send-string-to-terminal "
        "\"\\033[38;5;196mred256 \\033[38;5;46mgreen256 "
        "\\033[38;5;21mblue256 \\033[48;5;226m bg256 \\033[0m\\n\") "
        "(write-region \"iosmacs-app-color-smoke-ok\\n\" nil %s nil nil) "
        "(princ \"iosmacs-app-color-smoke-ok\\n\" 'external-debugging-output))))";
    int length = snprintf(NULL, 0, format, quoted_marker);
    if (length < 0) {
        free(quoted_marker);
        return NULL;
    }

    char *eval_form = malloc((size_t)length + 1);
    if (eval_form != NULL) {
        snprintf(eval_form, (size_t)length + 1, format, quoted_marker);
    }
    free(quoted_marker);
    return eval_form;
}

static char *copy_app_custom_eval_form(void) {
    const char *form = getenv("IOSMACS_APP_ELISP");
    if (form == NULL || form[0] == '\0') {
        return NULL;
    }
    return strdup(form);
}

static char *copy_runtime_eval_form(void) {
    const char *form =
        "(progn "
        "(setq default-directory \"/home/user/\" "
        "command-line-default-directory \"/home/user/\" "
        "create-lockfiles nil) "
        "(defun iosmacs-ensure-bundled-lisp-load-path () "
        "(let ((dir (getenv \"IOSMACS_LISP_DIR\"))) "
        "(when (and dir (file-directory-p dir)) "
        "(add-to-list 'load-path dir t) "
        "(dolist (child (directory-files dir t \"\\\\`[^.]\")) "
        "(when (file-directory-p child) "
        "(add-to-list 'load-path child t)))))) "
        "(iosmacs-ensure-bundled-lisp-load-path) "
        "(add-hook 'emacs-startup-hook #'iosmacs-ensure-bundled-lisp-load-path) "
        "(defun iosmacs-disable-extended-command-predicate () "
        "(when (boundp 'read-extended-command-predicate) "
        "(setq read-extended-command-predicate nil))) "
        "(iosmacs-disable-extended-command-predicate) "
        "(add-hook 'after-init-hook #'iosmacs-disable-extended-command-predicate) "
        "(add-hook 'emacs-startup-hook #'iosmacs-disable-extended-command-predicate) "
        "(defun iosmacs-reload-bundled-loaddefs () "
        "(dolist (name '(\"loaddefs\" \"cus-load\" \"finder-inf\")) "
        "(condition-case err "
        "(load name nil t) "
        "(error (princ (format \"iosmacs-loaddefs-load-error:%S\\n\" err) "
        "'external-debugging-output))))) "
        "(iosmacs-reload-bundled-loaddefs) "
        "(add-hook 'emacs-startup-hook #'iosmacs-reload-bundled-loaddefs) "
        "(defun iosmacs-force-utf8-terminal () "
        "(set-language-environment \"UTF-8\") "
        "(prefer-coding-system 'utf-8-unix) "
        "(setq locale-coding-system 'utf-8-unix "
        "default-enable-multibyte-characters t) "
        "(set-keyboard-coding-system 'utf-8-unix) "
        "(set-terminal-coding-system 'utf-8-unix) "
        "(ignore-errors (set-input-meta-mode 8))) "
        "(iosmacs-force-utf8-terminal) "
        "(add-hook 'emacs-startup-hook #'iosmacs-force-utf8-terminal) "
        "(run-at-time 2 nil #'iosmacs-force-utf8-terminal) "
        "(defun iosmacs-force-terminal-edit-keys () "
        "(global-set-key (kbd \"DEL\") #'delete-backward-char) "
        "(global-set-key (kbd \"<backspace>\") #'delete-backward-char) "
        "(global-set-key (kbd \"<deletechar>\") #'delete-forward-char)) "
        "(iosmacs-force-terminal-edit-keys) "
        "(add-hook 'emacs-startup-hook #'iosmacs-force-terminal-edit-keys) "
        "(defun iosmacs-force-dired-without-ls () "
        "(require 'ls-lisp) "
        "(setq ls-lisp-use-insert-directory-program nil "
        "insert-directory-program nil "
        "dired-use-ls-dired nil) "
        "(when (fboundp 'files--use-insert-directory-program-p) "
        "(advice-add 'files--use-insert-directory-program-p :override "
        "(lambda () nil)))) "
        "(iosmacs-force-dired-without-ls) "
        "(add-hook 'emacs-startup-hook #'iosmacs-force-dired-without-ls) "
        "(with-eval-after-load 'dired "
        "(iosmacs-force-dired-without-ls)) "
        "(with-eval-after-load 'dired-aux "
        "(iosmacs-force-dired-without-ls)) "
        "(defun iosmacs-force-grep-without-processes () "
        "(condition-case err "
        "(require 'iosmacs-grep) "
        "(error "
        "(princ (format \"iosmacs-grep-load-error:%S\\n\" err) "
        "'external-debugging-output)))) "
        "(iosmacs-force-grep-without-processes) "
        "(add-hook 'emacs-startup-hook #'iosmacs-force-grep-without-processes) "
        "(with-eval-after-load 'grep "
        "(iosmacs-force-grep-without-processes)) "
        "(with-eval-after-load 'xref "
        "(iosmacs-force-grep-without-processes)) "
        "(defun iosmacs-url-retrieve-synchronously (url &optional _silent _inhibit-cookies timeout) "
        "\"Retrieve URL through iOS URLSession and return a response buffer.\" "
        "(let* ((timeout-ms (round (* 1000 (or timeout 10)))) "
        "(result (iosmacs-url-retrieve-internal url timeout-ms)) "
        "(status (nth 0 result)) "
        "(headers (nth 1 result)) "
        "(body (nth 2 result)) "
        "(error-message (nth 3 result)) "
        "(final-url (nth 4 result))) "
        "(when error-message "
        "(error \"iosmacs URLSession bridge failed for %s: %s\" url error-message)) "
        "(let ((buffer (generate-new-buffer (format \" *iosmacs-url-%s*\" final-url)))) "
        "(with-current-buffer buffer "
        "(set-buffer-multibyte nil) "
        "(setq-local url-current-object url "
        "url-http-response-status status "
        "iosmacs-urlsession-response t) "
        "(insert headers) "
        "(unless (string-suffix-p \"\\r\\n\" headers) "
        "(insert \"\\r\\n\")) "
        "(insert \"\\r\\n\") "
        "(insert body) "
        "(goto-char (point-min))) "
        "buffer))) "
        "(defun iosmacs-urlsession-url-retrieve-synchronously (orig url &optional silent inhibit-cookies timeout) "
        "(if (and (stringp url) (string-prefix-p \"https://\" url)) "
        "(iosmacs-url-retrieve-synchronously url silent inhibit-cookies timeout) "
        "(funcall orig url silent inhibit-cookies timeout))) "
        "(defun iosmacs-url-retrieve (url callback &optional cbargs silent inhibit-cookies) "
        "\"Retrieve URL through iOS URLSession and invoke CALLBACK like `url-retrieve'.\" "
        "(let ((buffer (iosmacs-url-retrieve-synchronously url silent inhibit-cookies 30))) "
        "(with-current-buffer buffer "
        "(apply callback nil cbargs)) "
        "buffer)) "
        "(defun iosmacs-urlsession-url-retrieve (orig url callback &optional cbargs silent inhibit-cookies) "
        "(if (and (stringp url) (string-prefix-p \"https://\" url)) "
        "(iosmacs-url-retrieve url callback cbargs silent inhibit-cookies) "
        "(funcall orig url callback cbargs silent inhibit-cookies))) "
        "(defun iosmacs-urlsession-url-insert (orig buffer &optional beg end inhibit-decode) "
        "(if (not (and (local-variable-p 'iosmacs-urlsession-response buffer) "
        "(buffer-local-value 'iosmacs-urlsession-response buffer))) "
        "(funcall orig buffer beg end inhibit-decode) "
        "(let ((target (current-buffer)) "
        "(inserted 0)) "
        "(with-current-buffer buffer "
        "(save-excursion "
        "(goto-char (point-min)) "
        "(unless (or (search-forward \"\\r\\n\\r\\n\" nil t) "
        "(search-forward \"\\n\\n\" nil t)) "
        "(error \"iosmacs URLSession response has no header terminator\")) "
        "(let* ((body-start (point)) "
        "(from (+ body-start (or beg 0))) "
        "(to (if end (min (+ body-start end) (point-max)) (point-max)))) "
        "(setq inserted (max 0 (- to from))) "
        "(with-current-buffer target "
        "(insert-buffer-substring buffer from to))))) "
        "(list inserted nil)))) "
        "(setq package-menu-async nil "
        "package-check-signature nil) "
        "(with-eval-after-load 'url "
        "(advice-add 'url-retrieve-synchronously :around #'iosmacs-urlsession-url-retrieve-synchronously) "
        "(advice-add 'url-retrieve :around #'iosmacs-urlsession-url-retrieve)) "
        "(with-eval-after-load 'url-handlers "
        "(advice-add 'url-insert :around #'iosmacs-urlsession-url-insert)))";
    return strdup(form);
}

static void *emacs_core_thread_main(void *arg) {
    iosmacs_emacs_start_context *context = (iosmacs_emacs_start_context *)arg;
    static const char logical_lisp_dir[] = "/system/lisp";
    static const char logical_etc_dir[] = "/system/etc";
    static const char logical_exec_dir[] = "/system/lib-src";
    bool app_smoke_enabled = getenv("IOSMACS_APP_SMOKE_MARKER") != NULL
        || getenv("IOSMACS_APP_FILE_SMOKE_MARKER") != NULL
        || getenv("IOSMACS_APP_COLOR_SMOKE_MARKER") != NULL;
    char *system_root = copy_parent_dir(context->lisp_dir);

    iosmacs_terminal_shim_enable();
    int mirror_fd = app_smoke_enabled ? dup(STDERR_FILENO) : -1;
    iosmacs_terminal_shim_set_mirror_fd(mirror_fd);
    if (iosmacs_terminal_shim_attach_stdio() != 0) {
        iosmacs_os_set_lifecycle_state("iosmacs: fake tty attach failed");
        pthread_mutex_lock(&emacs_core_mutex);
        emacs_core_exit_status_value = 125;
        emacs_core_running = false;
        pthread_mutex_unlock(&emacs_core_mutex);
        free(system_root);
        free_start_context(context);
        return NULL;
    }
    if (system_root != NULL) {
        setenv("IOSMACS_SYSTEM_ROOT", system_root, 1);
    }
    set_lisp_load_path(context->lisp_dir, logical_lisp_dir);
    setenv("IOSMACS_LISP_DIR", logical_lisp_dir, 1);
    if (context->etc_dir != NULL) {
        setenv("EMACSDATA", logical_etc_dir, 1);
        setenv("EMACSDOC", logical_etc_dir, 1);
    }
    if (context->exec_dir != NULL) {
        setenv("EMACSPATH", logical_exec_dir, 1);
    }
    if (context->workspace_root != NULL) {
        setenv("IOSMACS_WORKSPACE_ROOT", context->workspace_root, 1);
        setenv("HOME", "/home/user", 1);
        setenv("USER", "user", 1);
        setenv("LOGNAME", "user", 1);
        chdir("/home/user");
    }
    setenv("LANG", "en_US.UTF-8", 1);
    setenv("LC_CTYPE", "en_US.UTF-8", 1);
    setlocale(LC_ALL, "");
    setenv("TERM", "xterm-256color", 1);
    setenv(
        "TERMCAP",
        "xterm-256color:co#80:li#24:Co#16777216:"
        "cl=\\E[H\\E[2J:cm=\\E[%i%d;%dH:"
        "up=\\E[A:do=\\E[B:nd=\\E[C:le=\\b:bs:"
        "ku=\\E[A:kd=\\E[B:kr=\\E[C:kl=\\E[D:kh=\\E[H:@7=\\E[F:kD=\\E[3~:"
        "ks=\\E[?1h\\E=:ke=\\E[?1l\\E>:"
        "vi=\\E[?25l:ve=\\E[?25h:vs=\\E[?25h:"
        "ti=\\E[?1049h:te=\\E[?1049l:"
        "so=\\E[7m:se=\\E[27m:us=\\E[4m:ue=\\E[24m:"
        "md=\\E[1m:mr=\\E[7m:me=\\E[0m:"
        "AF=\\E[38;5;%dm:AB=\\E[48;5;%dm:op=\\E[39;49m:",
        1
    );
    setenv("IOSMACS_TERMINAL_AUTO_XTERM_REPLIES", "1", 1);
    setenv("IOSMACS_NW_SKIP_GC", "1", 1);
    setenv("IOSMACS_PDMP_FALLBACK_CHARPROP", "1", 1);
    if (app_smoke_enabled) {
        setenv("IOSMACS_NW_DEBUG_ERROR", "1", 1);
    }
    iosmacs_os_set_lifecycle_state("iosmacs: GNU Emacs -nw running");

    char *runtime_eval_form = copy_runtime_eval_form();
    char *app_smoke_eval_form = copy_app_smoke_eval_form();
    char *app_file_smoke_eval_form = copy_app_file_smoke_eval_form();
    char *app_color_smoke_eval_form = copy_app_color_smoke_eval_form();
    char *app_custom_eval_form = copy_app_custom_eval_form();
    char *argv[19];
    int argc = 0;
    argv[argc++] = "temacs";
    if (context->dump_file != NULL) {
        argv[argc++] = "--dump-file";
        argv[argc++] = context->dump_file;
    }
    argv[argc++] = "--quick";
    argv[argc++] = "--no-site-file";
    argv[argc++] = "--no-site-lisp";
    argv[argc++] = "--no-splash";
    argv[argc++] = "-nw";
    if (runtime_eval_form != NULL) {
        argv[argc++] = "--eval";
        argv[argc++] = runtime_eval_form;
    }
    if (app_smoke_eval_form != NULL) {
        argv[argc++] = "--eval";
        argv[argc++] = app_smoke_eval_form;
    }
    if (app_file_smoke_eval_form != NULL) {
        argv[argc++] = "--eval";
        argv[argc++] = app_file_smoke_eval_form;
    }
    if (app_color_smoke_eval_form != NULL) {
        argv[argc++] = "--eval";
        argv[argc++] = app_color_smoke_eval_form;
    }
    if (app_custom_eval_form != NULL) {
        argv[argc++] = "--eval";
        argv[argc++] = app_custom_eval_form;
    }
    argv[argc] = NULL;
    int status = iosmacs_emacs_entry_ref(argc, argv);
    free(runtime_eval_form);
    free(app_smoke_eval_form);
    free(app_file_smoke_eval_form);
    free(app_color_smoke_eval_form);
    free(app_custom_eval_form);

    pthread_mutex_lock(&emacs_core_mutex);
    emacs_core_exit_status_value = status;
    emacs_core_running = false;
    pthread_mutex_unlock(&emacs_core_mutex);
    iosmacs_os_set_lifecycle_state("iosmacs: GNU Emacs exited");
    free(system_root);
    free_start_context(context);
    return NULL;
}
#endif

bool iosmacs_emacs_core_link_available(void) {
#if TARGET_OS_SIMULATOR
    return iosmacs_emacs_entry_ref != 0;
#else
    return false;
#endif
}

const char *iosmacs_emacs_core_entry_symbol_name(void) {
#if TARGET_OS_SIMULATOR
    return "iosmacs_emacs_main";
#else
    return "iosmacs_emacs_main unavailable for this platform build";
#endif
}

bool iosmacs_emacs_core_start(const char *lisp_dir,
                              const char *etc_dir,
                              const char *exec_dir,
                              const char *dump_file,
                              const char *workspace_root) {
#if TARGET_OS_SIMULATOR
    if (iosmacs_emacs_entry_ref == NULL) {
        iosmacs_os_set_lifecycle_state("iosmacs: GNU Emacs entry is not linked");
        return false;
    }

    pthread_mutex_lock(&emacs_core_mutex);
    if (emacs_core_started) {
        bool running = emacs_core_running;
        pthread_mutex_unlock(&emacs_core_mutex);
        return running;
    }

    iosmacs_emacs_start_context *context = calloc(1, sizeof(*context));
    if (context == NULL) {
        pthread_mutex_unlock(&emacs_core_mutex);
        return false;
    }
    context->lisp_dir = copy_c_string(lisp_dir);
    context->etc_dir = copy_c_string(etc_dir);
    context->exec_dir = copy_c_string(exec_dir);
    context->dump_file = copy_c_string(dump_file);
    context->workspace_root = copy_c_string(workspace_root);

    emacs_core_started = true;
    emacs_core_running = true;
    emacs_core_exit_status_value = -1;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, emacs_core_stack_size);
    int result = pthread_create(&emacs_core_thread, &attr, emacs_core_thread_main, context);
    pthread_attr_destroy(&attr);
    if (result != 0) {
        emacs_core_started = false;
        emacs_core_running = false;
        free_start_context(context);
        pthread_mutex_unlock(&emacs_core_mutex);
        return false;
    }
    pthread_detach(emacs_core_thread);
    pthread_mutex_unlock(&emacs_core_mutex);
    return true;
#else
    (void)lisp_dir;
    (void)etc_dir;
    (void)exec_dir;
    (void)dump_file;
    (void)workspace_root;
    return false;
#endif
}

bool iosmacs_emacs_core_is_running(void) {
#if TARGET_OS_SIMULATOR
    pthread_mutex_lock(&emacs_core_mutex);
    bool running = emacs_core_running;
    pthread_mutex_unlock(&emacs_core_mutex);
    return running;
#else
    return false;
#endif
}

int iosmacs_emacs_core_exit_status(void) {
#if TARGET_OS_SIMULATOR
    pthread_mutex_lock(&emacs_core_mutex);
    int status = emacs_core_exit_status_value;
    pthread_mutex_unlock(&emacs_core_mutex);
    return status;
#else
    return -1;
#endif
}
