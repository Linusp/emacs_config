;;; py-autopep8-autoloads.el --- automatically extracted autoloads  -*- lexical-binding: t -*-
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "py-autopep8" "py-autopep8.el" (0 0 0 0))
;;; Generated autoloads from py-autopep8.el

(autoload 'py-autopep8-buffer "py-autopep8" "\
Use the \"autopep8\" tool to reformat the current buffer.
Return non-nil when a the buffer was modified." t nil)

(autoload 'py-autopep8-region "py-autopep8" "\
Use the \"autopep8\" tool to reformat whole lines in the region (BEG, END).
Return non-nil when a the buffer was modified.

\(fn BEG END)" t nil)

(autoload 'py-autopep8-mode "py-autopep8" "\
Py-autopep8 minor mode.

This is a minor mode.  If called interactively, toggle the
`Py-Autopep8 mode' mode.  If the prefix argument is positive, enable
the mode, and if it is zero or negative, disable the mode.

If called from Lisp, toggle the mode if ARG is `toggle'.  Enable the
mode if ARG is nil, omitted, or is a positive number.  Disable the
mode if ARG is a negative number.

To check whether the minor mode is enabled in the current buffer,
evaluate `py-autopep8-mode'.

The mode's hook is called both when the mode is enabled and when it is
disabled.

\(fn &optional ARG)" t nil)

(register-definition-prefixes "py-autopep8" '("py-autopep8-"))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; py-autopep8-autoloads.el ends here
