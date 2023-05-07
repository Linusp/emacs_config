;;; pyim-preview.el --- pinyin tools for pyim.        -*- lexical-binding: t; -*-

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
(require 'pyim-magic)

(defgroup pyim-preview nil
  "Preview libs for pyim."
  :group 'pyim)

(defface pyim-preview-face '((t (:underline t)))
  "设置光标处预览字符串的 face.")

(defvar pyim-preview-overlay nil
  "用于保存光标处预览字符串的 overlay.")

(pyim-register-local-variables '(pyim-preview-overlay))

;; ** 待输入字符串预览
(defun pyim-preview-setup-overlay ()
  "设置 pyim 光标处实时预览功能所需要的 overlay.

这个函数会在 `pyim-input-method' 中调用，用于创建 overlay ，并将
其保存到 `pyim-preview-overlay' 变量，overlay 的 face 属性设置为
`pyim-preview-face' ，用户可以使用这个变量来自定义 face"
  (let ((pos (point)))
    (if (overlayp pyim-preview-overlay)
        (move-overlay pyim-preview-overlay pos pos)
      (setq pyim-preview-overlay (make-overlay pos pos))
      (if input-method-highlight-flag
          (overlay-put pyim-preview-overlay 'face 'pyim-preview-face)))))

(defun pyim-preview-delete-overlay ()
  "删除 pyim 光标处实时预览功能所需要的 overlay.

这个函数会在 `pyim-input-method' 中调用，用于删除
`pyim-preview-overlay' 中保存的 overlay。"
  (if (and (overlayp pyim-preview-overlay) (overlay-start pyim-preview-overlay))
      (delete-overlay pyim-preview-overlay)))

(defun pyim-preview-refresh ()
  "刷新光标处预览.

pyim 会使用 Emacs overlay 机制在 *待输入buffer* 光标处高亮显示一
个预览字符串，让用户可以查看将要输入的字符串，这个函数用于更新这
个字符串的内容。"
  (let* ((class (pyim-scheme-get-option (pyim-scheme-name) :class))
         (candidates pyim-candidates)
         (pos (1- (min pyim-candidate-position (length candidates))))
         (preview
          (concat (pyim-outcome-get)
                  (pyim-candidate-parse (nth pos candidates)))))
    (when (memq class '(quanpin))
      (let ((rest (mapconcat
                   (lambda (py)
                     (concat (nth 0 py) (nth 1 py)))
                   (nthcdr (length preview) (car pyim-imobjs))
                   "'")))
        (when (string< "" rest)
          (setq preview (concat preview rest)))))
    (setq preview (pyim-magic-convert preview))
    ;; Delete old preview string.
    (pyim-preview-delete-string)
    ;; Insert new preview string.
    (insert preview)
    ;; Highlight new preview string.
    (move-overlay pyim-preview-overlay
                  (overlay-start pyim-preview-overlay) (point))))

(defun pyim-preview-delete-string ()
  "删除已经插入 buffer 的 preview 预览字符串。"
  (if (overlay-start pyim-preview-overlay)
      (delete-region (overlay-start pyim-preview-overlay)
                     (overlay-end pyim-preview-overlay))))


;; * Footer
(provide 'pyim-preview)

;;; pyim-preview.el ends here
