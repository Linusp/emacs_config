;;; org-dotemacs-autoloads.el --- automatically extracted autoloads
;;
;;; Code:
(add-to-list 'load-path (directory-file-name (or (file-name-directory #$) (car load-path))))

;;;### (autoloads nil "org-dotemacs" "org-dotemacs.el" (22640 64579
;;;;;;  839499 284000))
;;; Generated autoloads from org-dotemacs.el

(unless (functionp 'topological-sort) (cl-defun topological-sort (graph &key (test 'eql)) "Returns a list of packages to install in order.\n  Graph is an association list whose keys are objects and whose\nvalues are lists of objects on which the corresponding key depends.\nTest is used to compare elements, and should be a suitable test for\nhash-tables.  Topological-sort returns two values.  The first is a\nlist of objects sorted toplogically.  The second is a boolean\nindicating whether all of the objects in the input graph are present\nin the topological ordering (i.e., the first value)." (let* ((entries (make-hash-table :test test)) (entry (lambda (v) "Return the entry for vertex.  Each entry is a cons whose\n              car is the number of outstanding dependencies of vertex\n              and whose cdr is a list of dependants of vertex." (or (gethash v entries) (puthash v (cons 0 'nil) entries))))) (dolist (gvertex graph) (destructuring-bind (vertex &rest dependencies) gvertex (let ((ventry (funcall entry vertex))) (dolist (dependency dependencies) (let ((dentry (funcall entry dependency))) (unless (funcall test dependency vertex) (incf (car ventry)) (push vertex (cdr dentry)))))))) (let ((L 'nil) (S (loop for entry being each hash-value of entries using (hash-key vertex) when (zerop (car entry)) collect vertex))) (do* nil ((endp S)) (let* ((v (pop S)) (ventry (funcall entry v))) (remhash v entries) (dolist (dependant (cdr ventry) (push v L)) (when (zerop (decf (car (funcall entry dependant)))) (push dependant S))))) (let ((all-sorted-p (zerop (hash-table-count entries)))) (values (nreverse L) all-sorted-p (unless all-sorted-p entries)))))))

(autoload 'org-dotemacs-default-match "org-dotemacs" "\
Returns the default tag match string based on items in `org-dotemacs-conditional-tags' (which see).

\(fn)" nil nil)

(autoload 'org-dotemacs-extract-subtrees "org-dotemacs" "\
Extract subtrees in current org-mode buffer that match tag MATCH.
MATCH should be a tag match as detailed in the org manual.
If EXCLUDE-TODO-STATE is non-nil then subtrees with todo states matching this regexp will be
excluding, and if INCLUDE-TODO-STATE is non-nil then only subtrees with todo states matching
this regexp will be included.
The copied subtrees will be placed in a new buffer which is returned by this function.
If called interactively MATCH is prompted from the user, and the new buffer containing
the copied subtrees will be visited.

\(fn MATCH &optional (EXCLUDE-TODO-STATE org-dotemacs-exclude-todo) (INCLUDE-TODO-STATE org-dotemacs-include-todo))" t nil)

(autoload 'org-dotemacs-load-blocks "org-dotemacs" "\
Load the emacs-lisp code blocks in FILE matching tag MATCH.
Save the blocks to TARGET-FILE if it is non-nil.
See the definition of `org-dotemacs-error-handling' for an explanation of the ERROR-HANDLING
argument which uses `org-dotemacs-error-handling' for its default value.

\(fn FILE MATCH &optional TARGET-FILE (ERROR-HANDLING org-dotemacs-error-handling))" nil nil)

(autoload 'org-dotemacs-load-file "org-dotemacs" "\
Load the elisp code from code blocks in org FILE under headers matching tag MATCH.
Tag matches supplied at the command line get priority over those supplied by the MATCH argument,
and if both of these are nil then `org-dotemacs-default-match' will be used to create a tag match.
If you need to override the command line tag-match set `org-dotemacs-tag-match' to nil.
If TARGET-FILE is supplied it should be a filename to save the elisp code to, but it should
not be any of the default config files .emacs, .emacs.el, .emacs.elc or init.el
 (the function will halt with an error in those cases). If TARGET-FILE is newer than FILE then
TARGET-FILE will be loaded and FILE will not be processed. Otherwise TARGET-FILE will be overwritten
by the code blocks in FILE.
The optional argument ERROR-HANDLING determines how errors are handled and takes default value
`org-dotemacs-error-handling' (which see).

\(fn &optional MATCH (FILE org-dotemacs-default-file) TARGET-FILE (ERROR-HANDLING org-dotemacs-error-handling))" t nil)

(autoload 'org-dotemacs-load-default "org-dotemacs" "\
Load code from `org-dotemacs-default-file' matching tag MATCH.
Unlike `org-dotemacs-load-file' the user is not prompted for the location of any files,
and no code is saved.

\(fn &optional MATCH)" t nil)

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; End:
;;; org-dotemacs-autoloads.el ends here
