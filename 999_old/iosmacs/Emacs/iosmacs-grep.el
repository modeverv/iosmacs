;;; iosmacs-grep.el --- process-free grep for iosmacs -*- lexical-binding: t; -*-

;;; Commentary:
;; iOS app builds cannot rely on subprocesses for grep/find/xargs.  This file
;; keeps the usual Emacs grep entry points on an Elisp-only file scanner.

;;; Code:

(require 'cl-lib)
(require 'grep)
(require 'xref)

(defvar iosmacs-grep-max-file-bytes (* 8 1024 1024)
  "Maximum file size searched by `iosmacs-grep'.")

(defun iosmacs-grep--split-patterns (patterns)
  (cond
   ((null patterns) nil)
   ((listp patterns) patterns)
   ((stringp patterns)
    (let ((expanded (or (cdr (assoc patterns grep-files-aliases)) patterns)))
      (split-string expanded "[ \t\n]+" t)))
   (t nil)))

(defun iosmacs-grep--wildcard-match-p (patterns file)
  (let ((name (file-name-nondirectory file))
        (patterns (iosmacs-grep--split-patterns patterns)))
    (or (null patterns)
        (member "all" patterns)
        (cl-some (lambda (pattern)
                   (string-match-p (wildcard-to-regexp pattern) name))
                 patterns))))

(defun iosmacs-grep--ignored-file-p (file ignores)
  (let ((name (file-name-nondirectory file)))
    (cl-some (lambda (pattern)
               (string-match-p (wildcard-to-regexp pattern) name))
             (iosmacs-grep--split-patterns ignores))))

(defun iosmacs-grep--ignored-directory-p (dir)
  (let ((name (file-name-nondirectory (directory-file-name dir))))
    (cl-some (lambda (ignore)
               (cond
                ((stringp ignore) (string= ignore name))
                ((consp ignore) (and (funcall (car ignore) dir)
                                     (string= (cdr ignore) name)))))
             grep-find-ignored-directories)))

(defun iosmacs-grep--file-readable-p (file)
  (and (file-regular-p file)
       (file-readable-p file)
       (not (file-symlink-p file))
       (let ((attrs (file-attributes file)))
         (or (null iosmacs-grep-max-file-bytes)
             (<= (file-attribute-size attrs) iosmacs-grep-max-file-bytes)))))

(defun iosmacs-grep--collect-files (dir patterns recursive ignores)
  (let ((result nil))
    (dolist (file (ignore-errors (directory-files dir t "\\`[^.]")))
      (cond
       ((and recursive
             (file-directory-p file)
             (not (file-symlink-p file))
             (not (iosmacs-grep--ignored-directory-p file)))
        (setq result
              (nconc result
                     (iosmacs-grep--collect-files file patterns recursive ignores))))
       ((and (iosmacs-grep--file-readable-p file)
             (iosmacs-grep--wildcard-match-p patterns file)
             (not (iosmacs-grep--ignored-file-p file ignores)))
        (push file result))))
    (nreverse result)))

(defun iosmacs-grep--scan-file (regexp file)
  (let ((case-fold-search (read-regexp-case-fold-search regexp))
        (hits nil))
    (with-temp-buffer
      (condition-case nil
          (progn
            (insert-file-contents file)
            (goto-char (point-min))
            (let ((line 1))
              (while (not (eobp))
                (let ((start (point))
                      (end (line-end-position)))
                  (when (save-excursion
                          (goto-char start)
                          (re-search-forward regexp end t))
                    (push (list file line
                                (buffer-substring-no-properties start end))
                          hits)))
                (forward-line 1)
                (setq line (1+ line)))))
        (error nil)))
    (nreverse hits)))

(defun iosmacs-grep--scan-files (regexp files)
  (let ((hits nil))
    (dolist (file files)
      (setq hits (nconc hits (iosmacs-grep--scan-file regexp file))))
    hits))

(defun iosmacs-grep--insert-hits (hits)
  (dolist (hit hits)
    (insert (format "%s:%d:%s\n" (file-relative-name (nth 0 hit))
                    (nth 1 hit)
                    (nth 2 hit)))))

(defun iosmacs-grep--show (regexp files dir title)
  (grep--save-buffers)
  (let ((buffer (get-buffer-create "*grep*"))
        (default-directory (file-name-as-directory (expand-file-name dir))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq default-directory default-directory)
        (grep-mode)
        (let ((inhibit-read-only t))
          (insert title "\n")
          (iosmacs-grep--insert-hits (iosmacs-grep--scan-files regexp files))
          (insert "iosmacs grep finished\n"))))
    (setq grep-last-buffer buffer
          next-error-last-buffer buffer)
    (pop-to-buffer buffer)))

(defun iosmacs-grep-lgrep (regexp &optional files dir _confirm)
  "Process-free replacement for `lgrep'."
  (interactive
   (let* ((regexp (grep-read-regexp))
          (files (grep-read-files regexp))
          (dir (read-directory-name "In directory: " nil default-directory t)))
     (list regexp files dir current-prefix-arg)))
  (let* ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
         (ignores (grep-find-ignored-files dir))
         (files-found (iosmacs-grep--collect-files dir files nil ignores)))
    (iosmacs-grep--show
     regexp files-found dir
     (format "iosmacs lgrep: %s in %s" regexp (or files "all")))))

(defun iosmacs-grep-rgrep (regexp &optional files dir _confirm)
  "Process-free replacement for `rgrep'."
  (interactive
   (let* ((regexp (grep-read-regexp))
          (files (grep-read-files regexp))
          (dir (read-directory-name "Base directory: " nil default-directory t)))
     (list regexp files dir current-prefix-arg)))
  (let* ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
         (ignores (grep-find-ignored-files dir))
         (files-found (iosmacs-grep--collect-files dir files t ignores)))
    (iosmacs-grep--show
     regexp files-found dir
     (format "iosmacs rgrep: %s in %s" regexp (or files "all")))))

(defun iosmacs-grep-grep (command-args)
  "Process-free replacement for `grep'.
This accepts plain REGEXP input directly; complex shell pipelines should use
`lgrep' or `rgrep' on iosmacs."
  (interactive (list (read-regexp "Search for" 'grep-tag-default
                                  'grep-regexp-history)))
  (let ((regexp (if (string-match "\\`[[:alnum:]_./-]*grep\\_>" command-args)
                    (car (last (split-string command-args "[ \t]+" t)))
                  command-args)))
    (iosmacs-grep-rgrep regexp "all" default-directory nil)))

(defun iosmacs-grep-find (command-args)
  "Process-free replacement for `grep-find'."
  (interactive (list (read-regexp "Search for" 'grep-tag-default
                                  'grep-regexp-history)))
  (iosmacs-grep-grep command-args))

(defun iosmacs-grep--xrefs-from-hits (hits)
  (mapcar (lambda (hit)
            (xref-make (nth 2 hit)
                       (xref-make-file-location (nth 0 hit) (nth 1 hit) 0)))
          hits))

(defun iosmacs-grep-xref-matches-in-files (regexp files)
  "Process-free replacement for `xref-matches-in-files'."
  (iosmacs-grep--xrefs-from-hits
   (iosmacs-grep--scan-files regexp files)))

(defun iosmacs-grep-xref-matches-in-directory (regexp files dir ignores)
  "Process-free replacement for `xref-matches-in-directory'."
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (files-found (iosmacs-grep--collect-files dir files t ignores)))
    (iosmacs-grep--xrefs-from-hits
     (iosmacs-grep--scan-files regexp files-found))))

(defun iosmacs-grep-enable ()
  "Route grep-like Emacs features through process-free Elisp."
  (setq grep-program "iosmacs-elisp-grep"
        grep-command "iosmacs-elisp-grep "
        grep-template "iosmacs-elisp-grep <R> <F>"
        grep-find-command "iosmacs-elisp-rgrep "
        grep-find-template "iosmacs-elisp-rgrep <R> <F>"
        grep-use-null-device nil
        grep-use-null-filename-separator nil
        grep-highlight-matches nil
        xref-search-program 'grep)
  (advice-add 'grep :override #'iosmacs-grep-grep)
  (advice-add 'grep-find :override #'iosmacs-grep-find)
  (advice-add 'find-grep :override #'iosmacs-grep-find)
  (advice-add 'lgrep :override #'iosmacs-grep-lgrep)
  (advice-add 'rgrep :override #'iosmacs-grep-rgrep)
  (advice-add 'xref-matches-in-files :override
              #'iosmacs-grep-xref-matches-in-files)
  (advice-add 'xref-matches-in-directory :override
              #'iosmacs-grep-xref-matches-in-directory))

(iosmacs-grep-enable)

(provide 'iosmacs-grep)

;;; iosmacs-grep.el ends here
