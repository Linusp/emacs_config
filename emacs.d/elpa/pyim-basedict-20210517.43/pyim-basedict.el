;;; pyim-basedict.el --- The default pinyin dict of pyim  -*- lexical-binding: t; -*-

;; * Header
;; Copyright (C) 2015-2021 Free Software Foundation, Inc.

;; Author: Feng Shu <tumashu@163.com>
;; URL: https://github.com/tumashu/pyim-basedict
;; Version: 0.5.0
;; Keywords: convenience, Chinese, pinyin, input-method, complete

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
;; * pyim-basedict README                         :README:doc:

;; ** 简介
;; pyim-basedict 是 pyim 输入法的默认词库，词库数据来源为 libpinyin 项目。

;;  https://github.com/libpinyin/libpinyin/releases (Data files we need is in release tarball)

;; 注意：这个词库的词条量大概在 10 万左右，是一个 *比较小* 的词库，只能确保 pyim
;; 可以正常工作，如果用户想让 pyim 更加顺手，需要添加其它附加词库，具体添加词库的
;; 方式可以参考 pyim 的 README.

;; ** 安装和使用
;; 1. M-x package-install RET pyim-basedict RET
;; 2. 在 Emacs 配置文件中（比如: "~/.emacs"）添加如下代码：
;;    #+BEGIN_EXAMPLE
;;    (pyim-basedict-enable)
;;    #+END_EXAMPLE

;;; Code:
;; * 代码                                                               :code:
(defvar pyim-basedict-libpinyin-tarball-url
  "https://github.com/libpinyin/libpinyin/releases/download/2.6.0/libpinyin-2.6.0.tar.gz"
  "The source of libpinyin data.")

(defvar pyim-basedict-libpinyin-datadir nil
  "The directory of libpinyin data.
The developers of pyim-basedict should download libpinyin release
tarball and extract data/* to this directory.")

(defvar pyim-basedict-libpinyin-data-files
  (list "society.table"
        "life.table"
        "people.table"
        "culture.table"
        "economy.table"
        "technology.table"
        "science.table"
        "nature.table"
        "history.table"
        "art.table"
        "sport.table"
        "geology.table"
        "merged.table"
        "opengram.table"
        "gb_char.table"
        "gbk_char.table")
  "Libpinyin data files")

(defvar pyim-basedict-libpinyin-count-info nil
  "The count info of libpinyin.")

(declare-function 'pyim-extra-dicts-add-dict "pyim")

;;;###autoload
(defun pyim-basedict-enable ()
  "Add basedict to pyim."
  (interactive)
  (let* ((file (expand-file-name "pyim-basedict.pyim"
                                 (file-name-directory
                                  (locate-library "pyim-basedict.el")))))
    (when (file-exists-p file)
      ;; FIXME: If `pyim-basedict-enable' is called early enough, pyim
      ;; won't be loaded yet and this (featurep 'pyim) will return nil.
      ;; Maybe we should just (require 'pyim) and call
      ;; `pyim-extra-dicts-add-dict' unconditionally, or maybe we should
      ;; use `with-eval-after-load'.
      (if (featurep 'pyim)
          (pyim-extra-dicts-add-dict
           `(;; Make Indent beautiful :-)
             :name "Basedict-elpa"
             :file ,file
             :coding utf-8-unix
             :dict-type pinyin-dict
             :elpa t))
        (message "pyim 没有安装，pyim-basedict 启用失败。")))))

(declare-function 'pyim-dline-parse "pyim")

(defun pyim-basedict-generate-count-info ()
  "从 libpinyin data 文件中获取词条的 count 信息。"
  (interactive)
  (let* ((dir pyim-basedict-libpinyin-datadir)
         (count-info (make-hash-table :test #'equal))
         (file (expand-file-name "interpolation2.text" dir)))
    (unless (and pyim-basedict-libpinyin-count-info
                 (> (hash-table-count pyim-basedict-libpinyin-count-info) 60000))
      (when (and dir (file-directory-p dir))
        (with-temp-buffer
          (when (file-exists-p file)
            (insert-file-contents file)
            (while (not (eobp))
              (let ((contents (pyim-dline-parse)))
                (when (= (length contents) 5)
                  (puthash (nth 2 contents)
                           (or (ignore-errors (string-to-number (nth 4 contents))) 0)
                           count-info))
                (forward-line 1)))
            (setq pyim-basedict-libpinyin-count-info count-info)))))))

(defun pyim-basedict-cchar< (a b)
  "如果汉字或者词条 A 的使用频率大于 B 的使用频率时，返回 t."
  (> (or (ignore-errors (gethash a pyim-basedict-libpinyin-count-info)) 0)
     (or (ignore-errors (gethash b pyim-basedict-libpinyin-count-info)) 0)))

(defun pyim-basedict-build-file ()
  "使用 libpinyin 自带的 data 文件创建 pyim-basedict.pyim."
  (interactive)
  (pyim-basedict-generate-count-info)
  (let ((dir pyim-basedict-libpinyin-datadir)
        (hash-table (make-hash-table :test #'equal))
        (count-info (make-hash-table :test #'equal)))
    (if (not (and dir (file-directory-p dir)))
        (message "Warn: `pyim-basedict-libpinyin-datadir' is not a directory.")
      (with-temp-buffer
        (dolist (filename pyim-basedict-libpinyin-data-files)
          (when (file-exists-p (expand-file-name filename dir))
            (insert-file-contents (expand-file-name filename dir))
            (goto-char (point-max))))
        (goto-char (point-min))
        (while (not (eobp))
          (let* ((contents (pyim-dline-parse))
                 (code (replace-regexp-in-string
                        "'" "-"
                        (car contents)))
                 (word (cadr contents)))
            (puthash code (push word (gethash code hash-table))
                     hash-table))
          (forward-line 1)))
      (with-temp-buffer
        (maphash
         (lambda (key value)
           (setq value (sort (delete-dups (reverse value)) #'pyim-basedict-cchar<))
           (insert (format "%s %s\n" key (mapconcat #'identity value " "))))
         hash-table)
        (sort-lines nil (point-min) (point-max))
        (goto-char (point-min))
        (insert ";; -*- coding: utf-8 -*--\n")
        (insert (format ";; Convert from data of %S with the help of `pyim-basedict-build-file'.\n"
                        pyim-basedict-libpinyin-tarball-url))
        (write-file "pyim-basedict.pyim" t)))))

;; * Footer
(provide 'pyim-basedict)

;;; pyim-basedict.el ends here
