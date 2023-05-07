;;; pyim.el --- A Chinese input method support quanpin, shuangpin, wubi, cangjie and rime.        -*- lexical-binding: t; -*-

;; * Header
;; Copyright (C) 2015-2021 Free Software Foundation, Inc.

;; Author: Ye Wenbin <wenbinye@163.com>
;;         Feng Shu <tumashu@163.com>
;; Maintainer: Feng Shu <tumashu@163.com>
;; URL: https://github.com/tumashu/pyim
;; Version: 3.8.2
;; Keywords: convenience, Chinese, pinyin, input-method
;; Package-Requires: ((emacs "24.4") (async "1.6") (xr "1.13"))

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

;; * 核心代码                                                           :code:
;; ** require + defcustom + defvar
(require 'subr-x)
(require 'cl-lib)
(require 'help-mode)
(require 'pyim-common)
(require 'pyim-scheme)
(require 'pyim-page)
(require 'pyim-process)
(require 'pyim-cstring)

(defgroup pyim nil
  "Pyim is a Chinese input method support quanpin, shuangpin, wubi and cangjie."
  :group 'leim)

(define-obsolete-variable-alias 'pyim-page-select-finish-hook 'pyim-select-finish-hook "4.0")
(defcustom pyim-select-finish-hook nil
  "Pyim 选词完成时运行的 hook."
  :type 'hook)

(defcustom pyim-convert-string-at-point-hook nil
  "Hook of `pyim-convert-string-at-point'.

这个 hook 运行时机：
1. 获取并删除光标处 code 字符串之后。
2. code 转换得到的中文字符串插入之前。

Tip: 用户也可以利用 `pyim-outcome-trigger-function-default' 函数
来构建适合自己的 hook 函数。"
  :type 'hook)

(define-obsolete-variable-alias 'pyim-page-select-word-by-number 'pyim-select-word-by-number "4.0")
(defcustom pyim-select-word-by-number t
  "使用数字键来选择词条.

如果设置为 nil, 将直接输入数字，适用于使用数字做为
编码的输入法。"
  :type 'boolean)

;;;###autoload
(defvar pyim-titles '("PYIM " "PYIM-EN " "PYIM-AU ") "Pyim 在 mode-line 中显示的名称.")

(defvar pyim-load-hook nil)
(defvar pyim-active-hook nil)
(defvar pyim-inactive-hook nil)

(defvar pyim-mode-map
  (let ((map (make-sparse-keymap))
        (i ?\ ))
    (while (< i 127)
      (define-key map (char-to-string i) #'pyim-self-insert-command)
      (setq i (1+ i)))
    (setq i 128)
    (while (< i 256)
      (define-key map (vector i) #'pyim-self-insert-command)
      (setq i (1+ i)))
    (dolist (i (number-sequence ?0 ?9))
      (define-key map (char-to-string i) #'pyim-select-word-by-number))
    (define-key map " " #'pyim-select-word)
    (define-key map (kbd "C-SPC") #'pyim-select-word-simple)
    (define-key map [backspace] #'pyim-delete-backward-char)
    (define-key map [delete] #'pyim-delete-forward-char)
    (define-key map "\C-d" #'pyim-delete-forward-char)
    (define-key map [M-backspace] #'pyim-delete-backward-imelem)
    (define-key map [M-delete] #'pyim-delete-forward-imelem)
    (define-key map [C-backspace] #'pyim-delete-backward-imelem)
    (define-key map [C-delete] #'pyim-delete-forward-imelem)
    (define-key map [?\t]      #'pyim-toggle-assistant-scheme)
    (define-key map (kbd "TAB") #'pyim-toggle-assistant-scheme)
    (define-key map "\177" #'pyim-delete-backward-char)
    (define-key map "\C-f" #'pyim-forward-point)
    (define-key map "\C-b" #'pyim-backward-point)
    (define-key map "\M-f" #'pyim-forward-imelem)
    (define-key map "\M-b" #'pyim-backward-imelem)
    (define-key map "\C-e" #'pyim-end-of-line)
    (define-key map "\C-a" #'pyim-beginning-of-line)
    (define-key map "=" #'pyim-page-next-page)
    (define-key map "-" #'pyim-page-previous-page)
    (define-key map "\C-n" #'pyim-page-next-word)
    (define-key map "\C-p" #'pyim-page-previous-word)
    (define-key map "\M-n" #'pyim-page-next-page)
    (define-key map "\M-p" #'pyim-page-previous-page)
    (define-key map "\C-m" #'pyim-quit-no-clear)
    (define-key map [return] #'pyim-quit-no-clear)
    (define-key map "\C-c" #'pyim-quit-clear)
    (define-key map "\C-g" #'pyim-quit-clear)
    map)
  "Pyim 的 Keymap.")

(pyim-register-local-variables
 '(input-method-function
   inactivate-current-input-method-function
   describe-current-input-method-function))

;; ** pyim 输入法定义
(defun pyim-input-method (key)
  "得到需要插入到 buffer 的字符串, 并将其插入到待输入 buffer.

这个函数会处理用户输入的字符，并最终的得到需要插入 buffer 的字符
串。这个字符串会被分解为 event list, 通过 emacs 低层函数
`read-event' 来将这些 list 插入到 *待输入buffer*。"
  (if (or buffer-read-only
          overriding-terminal-local-map
          overriding-local-map)
      (list key)
    ;; (message "call with key: %S" key-or-string)
    (pyim-process-init-ui)
    (with-silent-modifications
      (unwind-protect
          (let ((input-string (pyim-input-method-1 key)))
            ;; (message "input-string: %s" input-string)
            (when (and (stringp input-string)
                       (> (length input-string) 0))
              (if input-method-exit-on-first-char
                  (list (aref input-string 0))
                (mapcar #'identity input-string))))
        (pyim-process-terminate)))))

(defun pyim-input-method-1 (key)
  "`pyim-input-method-1' 是 `pyim-input-method' 内部使用的函数。

这个函数比较复杂，作许多低层工作，但它的一个重要流程是：

1. 使用函数 `read-key-sequence' 得到 key-sequence
2. 使用函数 `lookup-key' 查询 `pyim-mode-map' 中，与上述 key-sequence 对应
   的命令。
3. 如果查询得到的命令是 self-insert-command 时，调用这个函数。
4. 这个函数最终会返回需要插入到 buffer 的字符串。

这个部份的代码涉及许多 emacs 低层函数，相对复杂，不容易理解，有兴
趣的朋友可以参考：
1. `quail-input-method' 相关函数。
2. elisp 手册相关章节:
   1. Invoking the Input Method
   2. Input Methods
   3. Miscellaneous Event Input Features
   4. Reading One Event"
  ;; Check the possibility of translating KEY.
  ;; If KEY is nil, we can anyway start translation.
  (if (or (integerp key) (null key))
      ;; OK, we can start translation.
      (let* ((echo-keystrokes 0)
             (help-char nil)
             (overriding-terminal-local-map pyim-mode-map)
             ;; (generated-events nil)
             (input-method-function nil)
             ;; Quail package 用这个变量来控制是否在 buffer 中
             ;; 插入 preview string, pyim *强制* 将其设置为 nil
             (input-method-use-echo-area nil)
             (modified-p (buffer-modified-p))
             last-command-event last-command this-command)

        (setq pyim-process-translating t)
        (pyim-process-cleanup-input-output)

        (when key
          (pyim-add-unread-command-events key))

        (while pyim-process-translating
          (set-buffer-modified-p modified-p)
          (let* ((keyseq (read-key-sequence nil nil nil t))
                 (cmd (lookup-key pyim-mode-map keyseq)))
            ;; (message "key: %s, cmd:%s\nlcmd: %s, lcmdv: %s, tcmd: %s"
            ;;          key cmd last-command last-command-event this-command)
            (if (if key
                    (commandp cmd)
                  (pyim-process-self-insert-command-p cmd))
                (progn
                  ;; (message "keyseq: %s" keyseq)
                  (setq last-command-event (aref keyseq (1- (length keyseq)))
                        last-command this-command
                        this-command cmd)
                  (setq key t)
                  (condition-case-unless-debug err
                      (call-interactively cmd)
                    (error (message "pyim 出现错误: %S , 开启 debug-on-error 后可以了解详细情况。" err)
                           (beep))))
              ;; KEYSEQ is not defined in the translation keymap.
              ;; Let's return the event(s) to the caller.
              (pyim-add-unread-command-events (this-single-command-raw-keys) t)
              ;; (message "unread-command-events: %s" unread-command-events)
              (pyim-process-terminate))))
        ;; (message "return: %s" (pyim-process-get-outcome))
        (pyim-process-get-outcome nil t))
    ;; Since KEY doesn't start any translation, just return it.
    ;; But translate KEY if necessary.
    (char-to-string key)))

;; ** Pyim 输入法注册
;;;###autoload
(register-input-method "pyim" "euc-cn" 'pyim-active (nth 0 pyim-titles))

;; ** PYim 输入法启动功能
;;;###autoload
(defun pyim-active (_name &optional _active-func)
  "pyim 启动函数.

pyim 是使用 `pyim-active' 来启动输入法，这个命令主要做如下工作：
1. 重置所有的 local 变量。
2. 创建汉字到拼音和拼音到汉字的 hash table。
3. 创建词库缓存 dcache.
4. 运行 hook： `pyim-load-hook'。
5. 将 `pyim-dcache-save-caches' 命令添加到 `kill-emacs-hook' , emacs 关闭
之前将用户选择过的词生成的缓存和词频缓存保存到文件，供以后使用。
6. 设定变量：
   1. `input-method-function'
   2. `deactivate-current-input-method-function'
7. 运行 `pyim-active-hook'

pyim 使用函数 `pyim-active' 启动输入法的时候，会将变量
`input-method-function' 设置为 `pyim-input-method' ，这个变量会影
响 `read-event' 的行为。

当输入字符时，`read-event' 会被调用，`read-event' 调用的过程中，
会执行 `pyim-input-method' 这个函数。"
  (interactive)

  ;; 初始化 dcache.
  (pyim-process-init-dcaches)

  ;; 启动或者重启的时候，退出辅助输入法。
  (setq pyim-assistant-scheme-enable nil)

  (run-hooks 'pyim-load-hook)
  ;; Make sure personal or other dcache are saved to file before kill emacs.
  (add-hook 'kill-emacs-hook
            (lambda ()
              (pyim-process-save-dcaches t)))
  (setq input-method-function #'pyim-input-method)
  (setq deactivate-current-input-method-function #'pyim-inactivate)
  ;; (setq describe-current-input-method-function 'pyim-help)
  ;; If we are in minibuffer, turn off the current input method
  ;; before exiting.
  (when (eq (selected-window) (minibuffer-window))
    (add-hook 'minibuffer-exit-hook #'pyim-exit-from-minibuffer))
  (run-hooks 'pyim-active-hook)
  nil)

;; ** pyim 从 minibuffer 退出功能
(declare-function quail-exit-from-minibuffer "quail" ())

(defun pyim-exit-from-minibuffer ()
  "Pyim 从 minibuffer 退出."
  (quail-exit-from-minibuffer)
  (when (<= (minibuffer-depth) 1)
    (remove-hook 'minibuffer-exit-hook 'pyim-exit-from-minibuffer)))

;; ** pyim 重启功能
(defun pyim-restart ()
  "重启 pyim，不建议用于编程环境.

这个函数用于重启 pyim，其过程和 `pyim-active' 类似，只是在输入法重
启之前，询问用户，是否保存个人词频信息。"
  (interactive)
  (let ((save-personal-dcache
         (yes-or-no-p "重启 pyim 前，需要保存个人词频信息吗？ ")))
    (pyim-restart-1 save-personal-dcache)))

(defun pyim-restart-1 (&optional save-personal-dcache _refresh-common-dcache)
  "重启 pyim，用于编程环境.

当 SAVE-PERSONAL-DCACHE 是 non-nil 时，保存个人词库文件。

REFRESH-COMMON-DCACHE 已经废弃，不要再使用了。"
  (pyim-process-save-dcaches save-personal-dcache)
  (pyim-process-init-dcaches :force))

;; ** 键盘输入处理功能
(defun pyim-self-insert-command ()
  "Pyim 默认的 self-insert-command."
  (interactive "*")
  (setq pyim-candidates-last pyim-candidates)
  (cond
   ((pyim-process-input-chinese-p)
    (pyim-process-with-entered-buffer
      ;; 一定要注意，point 可能不在 point-min, 或者 point-max. 因为用
      ;; 户可能通过命令移动了 entered 中的 point。
      (insert (char-to-string last-command-event)))
    (pyim-process-run))
   ((pyim-process-get-candidates)
    (pyim-process-outcome-handle 'candidate-and-last-char)
    (pyim-process-terminate))
   (t
    (pyim-process-outcome-handle 'last-char)
    (pyim-process-terminate))))

(cl-pushnew 'pyim-self-insert-command pyim-process-self-insert-commands)

;; ** 加词功能
(defun pyim-create-word-at-point (&optional number silent)
  "将光标前字符数为 NUMBER 的中文字符串添加到个人词库中，当
SILENT 设置为 t 是，不显示提醒信息。"
  (let ((string (pyim-cstring-at-point (or number 2)))
        output)
    (when string
      (setq output (pyim-process-create-word string))
      (unless silent
        (message "将词条: %S 加入 personal 缓冲。" output)))))

(defun pyim-create-2cchar-word-at-point ()
  "将光标前2个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 2))

(defun pyim-create-3cchar-word-at-point ()
  "将光标前3个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 3))

(defun pyim-create-4cchar-word-at-point ()
  "将光标前4个中文字符组成的字符串加入个人词库。"
  (interactive)
  (pyim-create-word-at-point 4))

(defun pyim-create-word-from-selection ()
  "Add the selected text as a Chinese word into the personal dictionary."
  (interactive)
  (when (region-active-p)
    (let ((string (buffer-substring-no-properties (region-beginning) (region-end)))
          output)
      (if (> (length string) 6)
          (error "词条太长")
        (if (not (string-match-p "^\\cc+\\'" string))
            (error "不是纯中文字符串")
          (setq output (pyim-process-create-word string))
          (message "将词条: %S 插入 personal file。" output))))))

;; ** 导入词条功能
(defun pyim-import (file &optional merge-method)
  "从 FILE 中导入词条以及词条对应的词频信息。

MERGE-METHOD 是一个函数，这个函数需要两个数字参数，代表
词条在词频缓存中的词频和待导入文件中的词频，函数返回值做为合并后的词频使用，
默认方式是：取两个词频的最大值。"
  (interactive "F导入词条相关信息文件: ")
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-unix))
      (insert-file-contents file))
    (goto-char (point-min))
    (forward-line 1)
    (while (not (eobp))
      (let* ((content (pyim-dline-parse))
             (word (car content))
             (count (string-to-number
                     (or (car (cdr content)) "0"))))
        (pyim-process-create-word
         word nil
         (lambda (x)
           (funcall (or merge-method #'max)
                    (or x 0)
                    count))))
      (forward-line 1)))
  ;; 保存一下用户选择过的词生成的缓存和词频缓存，
  ;; 因为使用 async 机制更新 dcache 时，需要从 dcache 文件
  ;; 中读取变量值, 然后再对用户选择过的词生成的缓存排序，如果没
  ;; 有这一步骤，导入的词条就会被覆盖。
  (pyim-process-save-dcaches t)
  ;; 更新相关的 dcache
  (pyim-process-update-personal-words)

  (message "pyim: 词条相关信息导入完成！"))

;; ** 删词功能
(defun pyim-delete-words-in-file (file)
  "从个人词库缓存中批量删除 FILE 文件中列出的词条.

FILE 的格式与 `pyim-dcache-export' 生成的文件格式相同，
另外这个命令也可以识别没有词频的行，比如：

   ;;; -*- coding: utf-8-unix -*-
   词条1
   词条2"
  (interactive "F记录待删词条的文件: ")
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-unix))
      (insert-file-contents file))
    (goto-char (point-min))
    (forward-line 1)
    (while (not (eobp))
      (let ((word (car (pyim-dline-parse))))
        (when (and word (not (pyim-string-match-p "\\CC" word)))
          (pyim-process-delete-word word)))
      (forward-line 1)))
  (message "pyim: 批量删词完成！"))

(defun pyim-delete-last-word ()
  "从个人词库中删除最新创建的词条。"
  (interactive)
  (when pyim-process-last-created-word
    (pyim-process-delete-word pyim-process-last-created-word)
    (message "pyim: 从个人词库中删除词条 “%s” !" pyim-process-last-created-word)))

(defun pyim-delete-word-at-point (&optional number silent)
  "将光标前字符数为 NUMBER 的中文字符串从个人词库中删除
当 SILENT 设置为 t 是，不显示提醒信息。"
  (let ((string (pyim-cstring-at-point (or number 2))))
    (when string
      (pyim-process-delete-word string)
      (unless silent
        (message "词条: \"%s\" 已经从个人词库缓冲中删除。" string)))))

(defun pyim-delete-word ()
  "将高亮选择的词条从个人词库中删除。"
  (interactive)
  (if mark-active
      (let ((string (buffer-substring-no-properties
                     (region-beginning) (region-end))))
        (when (and (< (length string) 6)
                   (> (length string) 0))
          (pyim-process-delete-word string)
          (message "将词条: %S 从 personal 缓冲中删除。" string)))
    (message "请首先高亮选择需要删除的词条。")))

;; ** 选词功能
(define-obsolete-function-alias 'pyim-page-select-word-simple 'pyim-select-word-simple "4.0")
(defun pyim-select-word-simple ()
  "从选词框中选择当前词条.
这个函数与 `pyim-select-word' 的区别是：
这个函数不会将选择的词条加入个人词库，主要的使用场景是：
当用户需要输入一个生僻字时，输入包含该字的一个词条，
然后再删除不需要的字，由于这个词条不是常用词条，所以
不需要保存到个人词库。"
  (interactive)
  (if (null (pyim-process-get-candidates))
      (pyim-process-outcome-handle 'last-char)
    (pyim-process-outcome-handle 'candidate))
  (pyim-process-terminate))

(define-obsolete-function-alias 'pyim-page-select-word 'pyim-select-word "4.0")
(defun pyim-select-word ()
  "从选词框中选择当前词条，然后删除该词条对应拼音。"
  (interactive)
  (pyim-process-create-code-criteria)
  (if (null (pyim-process-get-candidates))  ; 如果没有选项，输入空格
      (progn
        (pyim-process-outcome-handle 'last-char)
        (pyim-process-terminate))
    (let* ((class (pyim-scheme-get-option (pyim-scheme-name) :class))
           (func (intern (format "pyim-select-word:%S" class))))
      (if (and class (functionp func))
          (funcall func)
        (call-interactively #'pyim-select-word:pinyin)))))

(defun pyim-select-word:pinyin ()
  "从选词框中选择当前词条，然后删除该词条对应拼音。"
  (interactive)
  (pyim-process-outcome-handle 'candidate)
  (let* ((imobj (car (pyim-process-get-imobjs)))
         (length-selected-word
          ;; 获取 *这一次* 选择词条的长度， 在“多次选择词条才能上屏”的情况下，
          ;; 一定要和 output 的概念作区别。
          ;; 比如： xiaolifeidao
          ;; 第一次选择：小李， output = 小李
          ;; 第二次选择：飞，   output = 小李飞
          ;; 第三次选择：刀，   output = 小李飞刀
          (- (length (pyim-process-get-outcome))
             (length (pyim-process-get-outcome 1))))
         ;; pyim-imobjs 包含 *pyim-entered-buffer* 里面光标前面的字符
         ;; 串，通过与 selected-word 做比较，获取光标前未转换的字符串。
         ;; to-be-translated.
         (to-be-translated (mapconcat #'identity
                                      (mapcar
                                       (lambda (w)
                                         (concat (nth 2 w) (nth 3 w)))
                                       (nthcdr length-selected-word imobj))
                                      "")))
    ;; 大体来说，entered 字符串可以分解为三个部分：

    ;; 1. 光标前字符串
    ;;    1. 光标前已经转换的字符串
    ;;    2. 光标前还没有转换的字符串。
    ;; 2. 光标后字符串

    ;; 下面对 entered 字符串的大体思路是：截取已经转换的字符串，把未转
    ;; 换的字符串和光标后的字符串合并后下一轮递归的处理。

    ;; 比如：entered 为 xiaolifeidao, 本次选择 “小李” 之后，需要将
    ;; entered 截断，“小李” 这个词条长度为2, 就将 entered从头开始缩减
    ;; 2 个 imelem 对应的字符，变成 feidao, 为下一次选择 “飞” 做准备。

    ;; 注意事项： 这里有一个假设前提是： 一个 imelem 对应一个汉字，
    ;; 在全拼输入法中，这个假设大多数情况是成立的，但在型码输入法
    ;; 中，比如五笔输入法，就不成立，好在型码输入法一般不需要多次
    ;; 选择。
    (if (or (< length-selected-word (length imobj)) ;是否有未转换的光标前字符串
            (> (length (pyim-process-get-entered 'point-after)) 0)) ;是否有光标后字符串
        (progn
          (pyim-process-with-entered-buffer
            ;; 把光标前已转换的 entered 字符串, 从 entered字符串里面剪
            ;; 掉，保留未转换的字符串和光标之后的字符串。
            (delete-region (point-min) (point))
            (insert to-be-translated)
            ;; 为下一次选词作准备，一般情况下词库里面的词条不会超过20
            ;; 个汉字，所以这里光标向前移动不超过20个 imelem. 从而让下
            ;; 一轮处理时的“光标前字符串”比较长，这种方式可能比逐字选
            ;; 择更加好用。
            (goto-char (pyim-process-next-imelem-position 20 t 1)))
          (pyim-process-run))
      ;; pyim 词频调整策略：
      ;; 1. 如果一个词条是用户在输入过程中，自己新建的词条，那么就将这个词条
      ;;    添加到个人词库的后面（不放置前面是为了减少误输词条的影响）。
      ;; 2. 如果输入的词条，先前已经在候选词列表中，就自动将其放到第一位。
      ;;    这样的话，一个新词要输入两遍之后才可能出现在第一位。
      ;; 3. pyim 在启动的时候，会使用词频信息，对个人词库作一次排序。
      ;;    用作 pyim 下一次使用。
      (if (member (pyim-process-get-outcome) (pyim-process-get-candidates))
          (pyim-process-create-word (pyim-process-get-outcome) t)
        (pyim-process-create-word (pyim-process-get-outcome)))

      (pyim-process-terminate)
      ;; pyim 使用这个 hook 来处理联想词。
      (run-hooks 'pyim-select-finish-hook))))

(defun pyim-select-word:xingma ()
  "从选词框中选择当前词条，然后删除该词条对应编码。"
  (interactive)
  (pyim-process-outcome-handle 'candidate)
  (if (pyim-process-with-entered-buffer
        (and (> (point) 1)
             (< (point) (point-max))))
      (progn
        (pyim-process-with-entered-buffer
          ;; 把本次已经选择的词条对应的子 entered, 从 entered
          ;; 字符串里面剪掉。
          (delete-region (point-min) (point)))
        (pyim-process-run))
    ;; 型码输入法，只考虑将词条保存到个人词库，用于调整词频，单字不保存。
    (when (> (length (pyim-process-get-outcome)) 1)
      (if (member (pyim-process-get-outcome) (pyim-process-get-candidates))
          (pyim-process-create-word (pyim-process-get-outcome) t)
        (pyim-process-create-word (pyim-process-get-outcome))))
    (pyim-process-terminate)
    ;; pyim 使用这个 hook 来处理联想词。
    (run-hooks 'pyim-select-finish-hook)))

(define-obsolete-function-alias 'pyim-page-select-word-by-number 'pyim-select-word-by-number "4.0")
(defun pyim-select-word-by-number (&optional n)
  "使用数字编号来选择对应的词条。"
  (interactive)
  (if (or pyim-select-word-by-number n)
      (if (null (pyim-process-get-candidates))
          (progn
            (pyim-process-outcome-handle 'last-char)
            (pyim-process-terminate))
        (let ((index (if (numberp n)
                         (- n 1)
                       (- last-command-event ?1)))
              (end (pyim-page-end)))
          (if (= index -1) (setq index 9) nil)
          (if (> (+ index (pyim-page-start)) end)
              (pyim-page-refresh)
            (pyim-process-set-candidate-position
             (+ (pyim-page-start) index))
            (pyim-select-word))))
    ;; 有些输入法使用数字键编码，这种情况下，数字键就
    ;; 不能用来选词了。
    (call-interactively #'pyim-self-insert-command)))

;; ** 取消当前输入功能
(defun pyim-quit-clear ()
  "取消当前输入的命令."
  (interactive)
  (pyim-process-outcome-handle "")
  (pyim-process-terminate))

;; ** 字母上屏功能
(defun pyim-quit-no-clear ()
  "字母上屏命令."
  (interactive)
  (pyim-process-outcome-handle 'pyim-entered)
  (pyim-process-terminate))

;; ** 取消激活功能
(defun pyim-inactivate ()
  "取消 pyim 的激活状态."
  (interactive)
  (pyim-kill-local-variables)
  (run-hooks 'pyim-inactive-hook))

;; ** 中英文输入模式切换
(defun pyim-toggle-input-ascii ()
  "pyim 切换中英文输入模式。同时调整标点符号样式。"
  (interactive)
  (setq pyim-process-input-ascii
        (not pyim-process-input-ascii)))

;; ** 主辅输入法切换功能
(defun pyim-toggle-assistant-scheme ()
  "临时切换到辅助输入法.

这个功能一般用于五笔等形码输入法，在忘记编码的时候临时用拼音输入
中文。"
  (interactive)
  (if (= (length (pyim-process-get-entered 'point-before)) 0)
      (progn
        (pyim-process-outcome-handle 'last-char)
        (pyim-process-terminate))
    (setq pyim-assistant-scheme-enable
          (not pyim-assistant-scheme-enable))
    (pyim-process-run)))

;; ** PYIM 输入操作命令
(define-obsolete-function-alias 'pyim-entered-delete-backward-char 'pyim-delete-backward-char "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-forward-char 'pyim-delete-forward-char "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-forward-char 'pyim-delete-forward-char "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-backward-imelem 'pyim-delete-backward-imelem "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-forward-imelem 'pyim-delete-forward-imelem "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-backward-imelem 'pyim-delete-backward-imelem "4.0")
(define-obsolete-function-alias 'pyim-entered-delete-backward-char 'pyim-delete-backward-char "4.0")
(define-obsolete-function-alias 'pyim-entered-forward-point 'pyim-forward-point "4.0")
(define-obsolete-function-alias 'pyim-entered-backward-point 'pyim-backward-point "4.0")
(define-obsolete-function-alias 'pyim-entered-forward-imelem 'pyim-forward-imelem "4.0")
(define-obsolete-function-alias 'pyim-entered-backward-imelem 'pyim-backward-imelem "4.0")
(define-obsolete-function-alias 'pyim-entered-end-of-line 'pyim-end-of-line "4.0")

(defun pyim-forward-point ()
  "光标前移"
  (interactive)
  (pyim-process-with-entered-buffer
    (ignore-errors
      (forward-char)))
  (pyim-process-run t))

(defun pyim-backward-point ()
  "光标后移"
  (interactive)
  (pyim-process-with-entered-buffer
    (ignore-errors
      (backward-char)))
  (pyim-process-run t))

(defun pyim-backward-imelem (&optional search-forward)
  "光标向后移动一个 imelem 对应的字符串

在全拼输入法中，就是向前移动一个拼音"
  (interactive)
  (let ((position (pyim-process-next-imelem-position 1 search-forward)))
    (pyim-process-with-entered-buffer
      (goto-char position))
    (pyim-process-run t)))

(defun pyim-forward-imelem ()
  "光标向前移动一个 imelem 对应的字符串"
  (interactive)
  (pyim-backward-imelem t))

(defun pyim-end-of-line ()
  "光标移至行尾"
  (interactive)
  (pyim-process-with-entered-buffer
    (end-of-line))
  (pyim-process-run t))

(defun pyim-beginning-of-line ()
  "光标移至行首"
  (interactive)
  (pyim-process-with-entered-buffer
    (beginning-of-line))
  (pyim-process-run t))

(defun pyim-delete-backward-char (&optional n)
  "向后删除1个字符"
  (interactive)
  (pyim-process-with-entered-buffer
    (ignore-errors
      (delete-char (- 0 (or n 1)))))
  (if (> (length (pyim-process-get-entered 'point-before)) 0)
      (pyim-process-run t)
    (pyim-process-outcome-handle "")
    (pyim-process-terminate)))

(defun pyim-delete-forward-char ()
  "向前删除1个字符"
  (interactive)
  (pyim-delete-backward-char -1))

(defun pyim-delete-backward-imelem (&optional search-forward)
  "向后删除一个 imelem 对应的字符串"
  (interactive)
  (let ((position (pyim-process-next-imelem-position 1 search-forward)))
    (pyim-process-with-entered-buffer
      (delete-region (point) position))
    (pyim-process-run t)))

(defun pyim-delete-forward-imelem ()
  "向前删除一个 imelem 对应的字符串"
  (interactive)
  (pyim-delete-backward-imelem t))

;; ** 金手指功能
;;;###autoload
(defun pyim-convert-string-at-point (&optional return-cregexp)
  "将光标前的用户输入的字符串转换为中文.

如果 RETURN-CREGEXP 为真, pyim 会把用户输入的字符串当作
拼音，依照这个拼音来构建一个 regexp, 用户可以用这个 regexp
搜索拼音对应的汉字。"
  (interactive "P")
  (unless (equal input-method-function 'pyim-input-method)
    (activate-input-method 'pyim))
  (if return-cregexp
      (pyim-cregexp-convert-at-point t)
    (let* ((case-fold-search nil)
           (scheme-name (pyim-scheme-name))
           (first-chars (pyim-scheme-get-option scheme-name :first-chars))
           (rest-chars (pyim-scheme-get-option scheme-name :rest-chars))
           (string (if mark-active
                       (buffer-substring-no-properties
                        (region-beginning) (region-end))
                     (buffer-substring (point) (line-beginning-position))))
           (str-before-1 (pyim-char-before-to-string 0))
           (str-before-2 (pyim-char-before-to-string 1))
           (str-before-3 (pyim-char-before-to-string 2))
           code length)
      (cond
       ;; 如果用户已经选择词条，就将此词条添加到个人词库。
       ((region-active-p)
        (pyim-create-word-from-selection)
        (deactivate-mark))
       ;; 删除用户自定义词条。比如：在一个中文字符串后输入 2-，运行此命令可以将
       ;; 光标前两个中文字符组成的字符串，从个人词库删除。
       ((and (eq (char-before) ?-)
             (pyim-string-match-p "[0-9]" str-before-2)
             (pyim-string-match-p "\\cc" str-before-3))
        (delete-char -2)
        (pyim-delete-word-at-point
         (string-to-number str-before-2)))
       ;; 输入"-"然后运行此命令，可以快速删除最近一次创建的词条。
       ((and (eq (char-before) ?-)
             (pyim-string-match-p "\\cc" str-before-2))
        (delete-char -1)
        (pyim-delete-last-word))
       ;; 快速保存用户自定义词条。比如：在一个中文字符串后输入 2，运行此命令可以
       ;; 将光标前两个中文字符组成的字符串，保存到个人词库。
       ((and (member (char-before) (number-sequence ?2 ?9))
             (pyim-string-match-p "\\cc" str-before-2))
        (delete-char -1)
        (pyim-create-word-at-point
         (string-to-number str-before-1)))
       ;; 金手指功能
       ((string-match
         ;; 创建一个 regexp, 用于提取出光标处一个适合
         ;; 转换的字符串。
         (format "[%s]+ *$"
                 (cl-delete-duplicates
                  (concat first-chars rest-chars "'-")))
         string)
        (setq code
              ;; 一些编程语言使用单引号 ' 做为字符串的标记，这里需要特殊处理。
              (replace-regexp-in-string
               "^[-']" ""
               (match-string 0 string)))
        (setq length (length code))
        (setq code (replace-regexp-in-string " +" "" code))
        (when mark-active
          (delete-region
           (region-beginning) (region-end)))
        (when (and (not mark-active) (> length 0))
          (delete-char (- 0 length)))
        (run-hooks 'pyim-convert-string-at-point-hook)
        (when (> length 0)
          (pyim-add-unread-command-events code)
          (setq pyim-process-force-input-chinese t)))
       ;; 当光标前的一个字符是标点符号时，半角/全角切换。
       ((pyim-string-match-p "[[:punct:]：－]" (pyim-char-before-to-string 0))
        (call-interactively 'pyim-punctuation-translate-at-point))
       (t (message "Pyim: pyim-convert-string-at-point do noting."))))))

;; ** 编码反查功能
(defun pyim-search-word-code ()
  "选择词条，然后反查它的 code。"
  (interactive)
  (when (region-active-p)
    (let* ((string (buffer-substring-no-properties (region-beginning) (region-end)))
           codes)
      (if (not (string-match-p "^\\cc+\\'" string))
          (error "PYIM: 不是纯中文字符串。")
        (setq codes (pyim-cstring-to-codes string pyim-default-scheme))
        (if codes
            (message "PYIM (%S): %S -> %S" pyim-default-scheme string codes)
          (message "PYIM: 没有找到 %S 对应的编码。" string)))
      (deactivate-mark))))

;; ** pyim 中文字符串工具
(require 'pyim-cstring)

;; ** pyim 中文 regexp 工具
(require 'pyim-cregexp)

;; ** pyim 探针
(require 'pyim-probe)

;; ** Evil hack
(defun pyim-hack-deactivate-input-method (orig_func)
  (let ((deactivate-current-input-method-function
         (or deactivate-current-input-method-function #'ignore)))
    (funcall orig_func)))

(with-eval-after-load
    (advice-add 'deactivate-input-method :around #'pyim-hack-deactivate-input-method))


;; * Footer
(provide 'pyim)

;;; pyim.el ends here
