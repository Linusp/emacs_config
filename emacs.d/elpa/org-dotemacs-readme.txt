 Commentary: 

 Bitcoin donations gratefully accepted: 1Ph9srQBspJCDS9CnGUyWJPTrU4ydX9Aa3

 Keeping your emacs config in an org file makes it easier for you to keep your .emacs under control,
 and avoid DotEmacsBankruptcy.
 With your config code stored in an org file you can easily edit the structure and keep notes.
 Note: it can also be used for organizing other elisp config files such as .gnus.el and .ercrc.el.
 
 This library allows you to load elisp code from an org file on emacs startup.
 You can also limit the code that is loaded to certain tagged headers using an org tag match,
 and specify dependencies between code blocks.
 Using tag matches you can also reuse the same org file for different emacs setups by specifying different
 tag matches for each setup, or load parts of the file on demand.
 
 Commands/Usage 
 
 The main command is `org-dotemacs-load-default' which loads your default org-dotemacs file (~/.dotemacs.org)
 and prompts for a tag match to specify which code blocks to load. 
 In this way you can load bits of config code when you need them.
 
 You can also put this command in your InitFile (see Installation below) to load the code on startup.
 To change the default org file use the `org-dotemacs-default-file' option.
 If you want to load a different org file from your default one, use `org-dotemacs-load-file'.
 
 For faster loading you may prefer to keep your config code in a separate elisp file, and just update this file now and again
 by exporting the code from the org file.
 Use the `org-dotemacs-load-file' command for this and specify a target elisp file when prompted.
 
 Structure of the org file 
 
 The elisp code should be contained in emacs-lisp code blocks, e.g:
 
 #+BEGIN_SRC emacs-lisp
 (setq line-number-mode t)
 (setq column-number-mode t)
 (setq frame-title-format "%b")
 (set-background-color "Black")
 (set-foreground-color "White")
 (set-cursor-color "White")
 #+END_SRC
 
 Ideally you should have each code block under a separate org subtree, then you can use properties to
 name the blocks and define dependencies, and tags and todo states to specify which blocks
 should be loaded (see below). You can specify that certain blocks are loaded only when certain conditions hold
 by customizing `org-dotemacs-conditional-tags'. By default operating system tags (linux, windows, mac, hurd, freebsd,
 unix) are set to only load when the corresponding operating system is being used (as reported by the `system-type' variable).
 So for example, any blocks tagged with "linux" will only be loaded if `system-type' is eq to 'gnu/linux.
 These conditional tags are overridden by any tag-match supplied to the command line.
 
 I prefer to keep all my code block subtrees under a single header, and use other headers for keeping notes,
 defining buffer-wide properties, etc. This way I can get a nice column view of the code blocks
 (see the columns view section below).
 
  Block dependencies 
 
 You can enforce dependencies between code blocks by defining NAME & DEPENDS properties for the subtrees containing the
 blocks (preferred). The NAME property should contain the name of the block, and the DEPENDS property should contain a space
 separated list of block names that this block depends on.
 These properties will be applied to all code blocks in the subtree (see "Properties and Columns" in the org manual for
 more details).
 
 The NAME property can be overridden on a per block basis by adding a :name header arg to a block, and dependencies can be
 augmented by adding a :depends header arg (see "Header arguments" in the org manual).
 However it is recommended to keep a separate subtree for each code block and use properties for defining headers and names
 since then you can get a column view of the dependencies (see below).
 
 A block will not be loaded until all of its dependencies have been loaded.
 
  Tags and TODO states 
 
 You can tag your subtrees and use tag matches to specify which blocks to evaluate in calls to `org-dotemacs-load-file'
 and `org-dotemacs-load-default'. See "Matching tags and properties" in the org manual for more information on tag matches.
 
 Also, by default any blocks in a subtree marked with a todo state of BROKEN will not be evaluated.
 You can specify which TODO states to include/exclude for evaluation by customizing the `org-dotemacs-include-todo' and
 `org-dotemacs-exclude-todo' options.
 
 To add the BROKEN state to the list of todo states for the file you need to add buffer-wide todo states by adding a line
 like this somewhere in your org file (see "Per file keywords" in the org manual).
 
 #+TODO: BROKEN CHECK TODO
 
  Columns View 
 
 If you use properties for defining names and dependencies then you can get a nice column view of your code subtrees
 with the following columns view specification:
 
 #+COLUMNS: %35ITEM %15NAME %35DEPENDS %15TAGS %TODO
 
 This can be placed anywhere in your dotemacs org file.
 Then if you press C-c C-x C-c on the toplevel header for your code blocks you'll get a column view that allows you
 to easily change the names, dependencies, tags and todo states.
 
  Error handling 
 
 Error handling can be controlled by customizing `org-dotemacs-error-handling' or by setting the error-handling
 command line option when starting emacs.
 By default code blocks with unmet dependencies or errors are skipped over as soon as an error is encountered,
 but you can also specify that org-dotemacs should halt or try to reload the blocks.
 In the latter case each time a new block is successfully loaded, any unsuccessful blocks will be retried.
 
  Command line options 
 
 org-dotemacs.el will look for two command line options when loaded: error-handling (for setting the value of
 `org-dotemacs-error-handling') and tag-match (for specifying which headers to load).
 For example if you enter the following at the command line:
 
        emacs --error-handling retry --tag-match "settings-mouse"
 
 Then only code blocks tagged "settings" but not "mouse" will be loaded, and org-dotemacs will try to reload any
 blocks that have errors. If no tag-match is specified on the command line then `org-dotemacs-conditional-tags'
 will be used to determine which blocks can be loaded by default.
 
  Installation 
 
 Put org-dotemacs.el in a directory in your load-path, e.g. ~/.emacs.d/
 You can add a directory to your load-path with the following line in ~/.emacs
 (add-to-list 'load-path (expand-file-name "~/elisp"))
 where ~/elisp is the directory you want to add 
 (you don't need to do this for ~/.emacs.d - it's added by default).
 
 Then make sure you have an ~/.dotemacs.org file and add the following lines to
 the end of your .emacs file:
 
 (load-file "~/.emacs.d/org-dotemacs.el")
 (let (find-file-hook) (org-dotemacs-load-default))
 
 or if you want to just load code blocks matching a tag match:
 
 (load-file "~/.emacs.d/org-dotemacs.el")
 (let (find-file-hook) (org-dotemacs-load-default "<TAG-MATCH>"))
 
 To load a different org file either customize `org-dotemacs-default-file' or use the
 `org-dotemacs-load-file' function, e.g:
 
 (load-file "~/.emacs.d/org-dotemacs.el")
 (let (find-file-hook) (org-dotemacs-load-file "<TAG-MATCH>" "~/.emacs.d/my_emacs_config.org"))
 


 Customize:

 `org-dotemacs-conditional-tags' : A list of tags/regexps and corresponding conditions for loading blocks.
 `org-dotemacs-default-file' : The default org file containing the code blocks to load when `org-dotemacs-load-file' is called.
 `org-dotemacs-error-handling' : Indicates how errors should be handled by `org-dotemacs-load-blocks'.
 `org-dotemacs-include-todo' : A regular expression matching TODO states to be included.
 `org-dotemacs-exclude-todo' : A regular expression matching TODO states to be excluded.

 All of the above can customized by:
      M-x customize-group RET org-dotemacs RET


 Change log:
 4-May-2013      
    Last-Updated: 2013-04-27 20:19:18 (Joe Bloggs)
        
	
 2013/04/27
      * First released.
 

 Acknowledgements:

 


 TODO

 Option to show prominent warning message if some blocks didn't load (e.g. in large font in dedicated buffer after startup)
 Option to show full backtrace on error?

 Require
(eval-when-compile (require 'cl))
(require 'org)

