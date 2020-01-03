;;; flucui-themes-autoloads.el --- automatically extracted autoloads
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "flucui-dark-theme" "flucui-dark-theme.el"
;;;;;;  (0 0 0 0))
;;; Generated autoloads from flucui-dark-theme.el

(if (fboundp 'register-definition-prefixes) (register-definition-prefixes "flucui-dark-theme" '("flucui-dark")))

;;;***

;;;### (autoloads nil "flucui-light-theme" "flucui-light-theme.el"
;;;;;;  (0 0 0 0))
;;; Generated autoloads from flucui-light-theme.el

(if (fboundp 'register-definition-prefixes) (register-definition-prefixes "flucui-light-theme" '("flucui-light")))

;;;***

;;;### (autoloads nil "flucui-themes" "flucui-themes.el" (0 0 0 0))
;;; Generated autoloads from flucui-themes.el

(add-to-list 'custom-theme-load-path (file-name-directory load-file-name))

(autoload 'flucui-themes-load-style "flucui-themes" "\
Load FlucUI theme variant STYLE.

Argument STYLE can be either 'light or 'dark.

\(fn STYLE)" t nil)

(autoload 'flucui-themes-switch-style "flucui-themes" "\
Toggle between the light and dark style of FlucUI theme.

\(fn)" t nil)

(if (fboundp 'register-definition-prefixes) (register-definition-prefixes "flucui-themes" '("flucui-themes-current-style")))

;;;***

;;;### (autoloads nil nil ("flucui-themes-pkg.el") (0 0 0 0))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; flucui-themes-autoloads.el ends here
