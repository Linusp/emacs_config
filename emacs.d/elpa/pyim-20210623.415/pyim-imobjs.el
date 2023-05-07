;;; pyim-imobjs.el --- imobjs for pyim.        -*- lexical-binding: t; -*-

;; * Header
;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Feng Shu <tumashu@163.com>
;; Maintainer: Feng Shu <tumashu@163.com>
;; URL: https://github.com/tumashu/pyim
;; Keywords: convenience, Chinese, pinyin, input-method

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
;; * 代码                                                           :code:
(require 'cl-lib)
(require 'pyim-common)
(require 'pyim-pinyin)

(defgroup pyim-imobjs nil
  "Imobjs lib for pyim."
  :group 'pyim)

(defvar pyim-imobjs nil
  "Imobj (Input method object) 组成的 list.

imobj 在 pyim 里面的概念，类似与编译器里面的语法树，
它代表 pyim 输入的字符串 entered 解析得到的一个结构化对象，
以全拼输入法的为例：

1. entered: nihaoma
2. imobj: ((\"n\" \"i\" \"n\" \"i\") (\"h\" \"ao\" \"h\" \"ao\") (\"m\" \"a\" \"m\" \"a\"))

而 imobjs 是 imobj 组成的一个列表，因为有模糊音等概念的存在，一个
entered 需要以多种方式或者多步骤解析，得到多种可能的 imobj, 这些
imobj 组合构成在一起，构成了 imobjs 这个概念。比如：

1. entered: guafeng (设置了模糊音 en -> eng)
2. imobj-1: ((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"en\" \"f\" \"eng\"))
3. imobj-2: ((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"eng\" \"f\" \"eng\"))
4. imobjs:  (((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"en\" \"f\" \"eng\"))
             ((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"eng\" \"f\" \"eng\")))

这个变量用来保存解析得到的 imobjs。

解析完成之后，pyim 会为每一个 imobj 创建对应 code 字符串, 然后在词库
中搜索 code 字符串来得到所需要的词条，最后使用特定的方式将得到的
词条组合成一个候选词列表：`pyim-candidates' 并通过 pyim-page 相关
功能来显示选词框，供用户选择词条，比如：

1. imobj: ((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"en\" \"f\" \"en\"))
2. code: gua-fen

从上面的说明可以看出，imobj 本身也是有结构的：

1. imobj: ((\"g\" \"ua\" \"g\" \"ua\") (\"f\" \"en\" \"f\" \"en\"))

我们将 (\"g\" \"ua\" \"g\" \"ua\") 这些子结构，叫做 imelem (IM element), *大
多数情况下*, 一个 imelem 能够代表一个汉字，这个概念在编辑 entered
的时候，非常有用。

另外要注意的是，不同的输入法， imelem 的内部结构是不一样的，比如：
1. quanping:  (\"g\" \"ua\" \"g\" \"ua\")
2. shuangpin: (\"h\" \"ao\" \"h\" \"c\")
3. wubi:      (\"aaaa\")")

(pyim-register-local-variables '(pyim-imobjs))

(defun pyim-imobjs-create (entered &optional scheme-name)
  "按照 SCHEME-NAME 对应的输入法方案，从 ENTERED 字符串中创建一个
或者多个 imobj 组成的列表，不同的输入法，imobj 的结构也是不一样的。"
  (let ((class (pyim-scheme-get-option scheme-name :class)))
    (when class
      (funcall (intern (format "pyim-imobjs-create:%S" class))
               entered scheme-name))))

(defun pyim-imobjs-create:quanpin (entered &optional _)
  "从用户输入的字符串 ENTERED 创建一个输入法内部对象列表: imobjs.

这个 imobjs 可能包含一个 imobj, 也可能包含多个，每个 imobj 都包含
声母和韵母的相关信息，比如：

    (pyim-imobjs-create:quanpin \"woaimeinv\" 'quanpin)

结果为:

    (((\"w\" \"o\" \"w\" \"o\") (\"\" \"ai\" \"\" \"ai\") (\"m\" \"ei\" \"m\" \"ei\") (\"n\" \"v\" \"n\" \"v\")))

如果字符串无法正确处理，则返回 nil, 比如：

   (pyim-imobjs-create \"ua\" 'quanpin)

全拼输入法的 imelem 是四个字符串组成的 list, 类似：

  (\"w\" \"o\" \"w\" \"o\")

代表：

  (声母1, 韵母1, 声母2, 韵母2)

声母1和声母2一般用来生成 code 字符串，用于词库中寻找词条。声母2和
韵母2一般用来反向构建 entered 字符串，用于“多次选择生成词条”这个
功能。

大多数情况，声母1 = 声母2, 韵母1 = 韵母2, 只有在使用模糊音的时候，
才可能出现不一致的情况。"
  (when (and entered (string< "" entered))
    (let* ((str-list (remove "" (split-string entered "'")))
           (n (length str-list))
           output)
      (dotimes (i n)
        (let* ((str (nth i str-list))
               (x (pyim-pinyin-split str)))
          (if (not x)
              (setq output nil)
            (when (> i 0)
              ;; 将强制分割符号附加到封分割符后面的声母开头，
              ;; 类似： ("'n" "i" "'n" "i"), 用于 `pyim-page-preview-create' 函数,
              ;; 和多次选词之后的，用户手动输入的分隔符的保护。
              (setf (nth 0 (car x))
                    (concat "'" (nth 0 (car x))))
              (setf (nth 2 (car x))
                    (concat "'" (nth 2 (car x)))))
            (setq output (append output x)))))
      (when output
        (pyim-imobjs-find-fuzzy:quanpin (list output))))))

;; "nihc" -> (((\"n\" \"i\" \"n\" \"i\") (\"h\" \"ao\" \"h\" \"c\")))
(defun pyim-imobjs-create:shuangpin (entered &optional scheme-name)
  (let ((keymaps (pyim-scheme-get-option scheme-name :keymaps))
        (list (string-to-list (replace-regexp-in-string "-" "" entered)))
        results)
    (while list
      (let* ((sp-sm (pop list))
             (sp-ym (pop list))
             (sp-sm (when sp-sm (char-to-string sp-sm)))
             (sp-ym (when sp-ym (char-to-string sp-ym)))
             (sm (nth 1 (assoc sp-sm keymaps)))
             (ym (or (cdr (cdr (assoc sp-ym keymaps))) (list "")))
             one-word-pinyins)

        (dolist (x ym)
          (let* ((y (concat sp-sm (or sp-ym " ")))
                 (z (cadr (assoc y keymaps)))
                 (py (if z (list "" z sp-sm sp-ym) (list sm x sp-sm sp-ym))))
            (unless (string-match-p pyim-pinyin-shuangpin-invalid-pinyin-regexp
                                    (concat (nth 0 py) (nth 1 py)))
              (push py one-word-pinyins))))

        (when (and one-word-pinyins (> (length one-word-pinyins) 0))
          (push one-word-pinyins results))))
    (pyim-imobjs-find-fuzzy:quanpin
     (pyim-permutate-list (nreverse results)))))

(defun pyim-imobjs-create:xingma (entered &optional scheme-name)
  (let ((n (pyim-scheme-get-option scheme-name :code-split-length)))
    (let (output)
      (mapc (lambda (x)
              (while (not (string-empty-p x))
                (if (< (length x) n)
                    (progn
                      (push x output)
                      (setq x ""))
                  (push (substring x 0 n) output)
                  (setq x (substring x n)))))
            (split-string entered "'"))
      (list (nreverse output)))))

(defun pyim-imobjs-find-fuzzy:quanpin (imobjs)
  "用于处理模糊音的函数。"
  (let (fuzzy-imobjs result1 result2)
    (dolist (imobj imobjs)
      (setq fuzzy-imobjs
            (pyim-permutate-list
             (mapcar #'pyim-pinyin-find-fuzzy imobj)))
      (push (car fuzzy-imobjs) result1)
      (setq result2 (append result2 (cdr fuzzy-imobjs))))
    (append result1 result2)))

;; * Footer
(provide 'pyim-imobjs)

;;; pyim-imobjs.el ends here
