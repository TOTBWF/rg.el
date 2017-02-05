;;; rg.el-test.el --- rg.el: Tests

;; Copyright (C) 2017 David Landell <david.landell@sunnyhill.email>
;;
;; Author: David Landell <david.landell@sunnyhill.email>
;; Homepage: https://github.com/davja/rg.el

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;; 02110-1301, USA.

;;; Commentary:

;;; Code:


;; Unit tests

(ert-deftest rg-unit-test/case-expand-template ()
"Test that rg-expand-template handles case settings correctly."
  (let ((template "<F> <C> <R>"))
    (let ((case-fold-search t))
      (should (s-matches? (rg-regexp-anywhere "-i") (rg-expand-template template "foo")))
      (should-not (s-matches? (rg-regexp-anywhere "-i") (rg-expand-template template "fOo"))))
    (let ((case-fold-search nil))
      (should-not (s-matches? (rg-regexp-anywhere "-i") (rg-expand-template template "foo")))
      (should-not (s-matches? (rg-regexp-anywhere "-i") (rg-expand-template template "Foo"))))))

(ert-deftest rg-unit-test/build-template ()
"Test rg-build-template template expansion."
  (let* ((rg-command "rg")
        (rg-custom-type-aliases nil)
        (notype-template (rg-build-template))
        (type-template (rg-build-template t))
        (custom-template (rg-build-template t "glob")))
    (should (s-matches? (rg-regexp-anywhere-but-last "<C>") notype-template))
    (should (s-matches? (rg-regexp-last "<R>") notype-template))
    (should-not (s-matches? (rg-regexp-anywhere-but-last "--type <F>") notype-template))
    (should-not (s-matches? (rg-regexp-anywhere-but-last "--type-add 'custom:") notype-template))

    (should (s-matches? (rg-regexp-anywhere-but-last "--type <F>") type-template))
    (should-not (s-matches? (rg-regexp-anywhere-but-last "--type-add 'custom:") type-template))

    (should (s-matches? (rg-regexp-anywhere-but-last "--type-add 'custom: *glob'") custom-template))
    (should (s-matches? (rg-regexp-anywhere-but-last "--type <F>") custom-template))))


(ert-deftest rg-unit-test/toggle-command-flag ()
"Test `rg-toggle-command-flag'."
  (let ((testflag "--foo")
        (compilation-arguments (list (concat "rg --bar searchstring"))))
    (rg-toggle-command-flag testflag)
    (should (s-matches? (rg-regexp-anywhere testflag) (car compilation-arguments)))
    (rg-toggle-command-flag testflag)
    (should-not (s-matches? (rg-regexp-anywhere testflag) (car compilation-arguments)))))

(ert-deftest rg-unit-test/rerun-change-regexp ()
"Test result of `rg-rerun-change-regexp'."
  (let ((rg-last-search '("regexp" "elisp" "/tmp/test"))
        (result))
    (noflet ((rg (regexp files dir) (setq result (list regexp files dir)))
             (rg-read-regexp (&rest _) "new-regexp"))
            (rg-rerun-change-regexp)
            (should (cl-every 'equal '("new-regexp" "elisp" "/tmp/test") result)))))

(ert-deftest rg-unit-test/read-regexp-correct-read-func ()
"Test that `rg-read-regexp' choose the correct read function depending
on emacs version."
  (let (called prompt-result)
    (noflet ((read-string (pr default &rest _)
                          (setq called 'read-string)
                          (setq prompt-result pr))
             (read-regexp (pr &rest _)
                          (setq called 'read-regexp)
                          (setq prompt-result pr)))
            (rg-read-regexp "Search for" "foo" 'bar)
            (if (and (<= emacs-major-version 24)
                     (<= emacs-minor-version 2))
                (progn
                  (should (eq called 'read-string))
                  (should (equal prompt-result "Search for (default \"foo\"): ")))
              (progn
                (should (eq called 'read-regexp))
                (should (equal prompt-result "Search for")))))))

(ert-deftest rg-unit-test/rerun-change-files ()
"Test result of `rg-rerun-change-files'."
  (let ((rg-last-search '("regexp" "elisp" "/tmp/test"))
        (result))
    (noflet ((rg (regexp files dir) (setq result (list regexp files dir)))
             (completing-read (&rest _) "cpp"))
            (rg-rerun-change-files)
            (should (cl-every 'equal '("regexp" "cpp" "/tmp/test") result)))))

(ert-deftest rg-unit-test/rerun-change-dir ()
"Test result of `rg-rerun-change-dir'."
  (let ((rg-last-search '("regexp" "elisp" "/tmp/test"))
        (result))
    (noflet ((rg (regexp files dir) (setq result (list regexp files dir)))
             (read-directory-name (&rest _) "/tmp/new"))
            (rg-rerun-change-dir)
            (should (cl-every 'equal '("regexp" "elisp" "/tmp/new") result)))))


;; Integration tests

(ert-deftest rg-integration-test/read-files-default-alias () :tags '(need-rg)
"Test that rg-read-files detects the current file and selects matching alias."
  (let (prompt)
    (noflet ((completing-read (pr &rest args) (setq prompt pr)))
            (find-file "test/data/foo.el")
            (rg-read-files "foo")
            (should (s-matches? "\[elisp\]" prompt))
            (find-file "test/data/foo.baz")
            (rg-read-files "foo")
            (should-not (s-matches? "\[.*\]" prompt))
            (let ((rg-custom-type-aliases '(("test" . "*.baz"))))
              (find-file "test/data/foo.baz")
              (rg-read-files "foo")
              (should (s-matches? "\[test\]" prompt))))))

(ert-deftest rg-integration-test/search-alias-builtin () :tags '(need-rg)
"Test that rg builtin aliases works."
  (let ((case-fold-search t))
    (rg "hello" "elisp" (concat default-directory "test/data"))
    (with-current-buffer "*rg*"
      (should (rg-wait-for-search-result))
      (let ((bufstr (buffer-substring-no-properties (point-min) (point-max))))
        (should (= 3 (s-count-matches "foo.el.*hello" bufstr)))
        (should (= 3 (s-count-matches "bar.el.*hello" bufstr)))
        (should (= 0 (s-count-matches "foo.baz.*hello" bufstr)))
        (should (= 0 (s-count-matches "bar.baz.*hello" bufstr)))))))

(ert-deftest rg-integration-test/search-alias-custom () :tags '(need-rg)
"Test that aliases defined in rg-custom-type-aliases works if explicitly selected."
  (let ((case-fold-search t)
        (rg-custom-type-aliases '(("test" . "*.baz"))))
    (rg "hello" "test" (concat default-directory "test/data"))
    (with-current-buffer "*rg*"
      (should (rg-wait-for-search-result))
      (let ((bufstr (buffer-substring-no-properties (point-min) (point-max))))
        (should (= 0 (s-count-matches "foo.el.*hello" bufstr)))
        (should (= 0 (s-count-matches "bar.el.*hello" bufstr)))
        (should (= 3 (s-count-matches "foo.baz.*hello" bufstr)))
        (should (= 3 (s-count-matches "bar.baz.*hello" bufstr)))))))

(ert-deftest rg-integration-test/search-alias-all-custom () :tags '(need-rg)
"Test that aliases defined in rg-custom-type-aliases works if
  implicitly selected via '--type all'."
(let ((case-fold-search t)
        (rg-custom-type-aliases '(("test" . "*.baz"))))
    (rg "hello" "all" (concat default-directory "test/data"))
    (with-current-buffer "*rg*"
      (should (rg-wait-for-search-result))
      (let ((bufstr (buffer-substring-no-properties (point-min) (point-max))))
        (should (= 3 (s-count-matches "foo.el.*hello" bufstr)))
        (should (= 3 (s-count-matches "bar.el.*hello" bufstr)))
        (should (= 3 (s-count-matches "foo.baz.*hello" bufstr)))
        (should (= 3 (s-count-matches "bar.baz.*hello" bufstr)))))))

(ert-deftest rg-integration-test/search-no-alias() :tags '(need-rg)
"Test that custom file pattern that is not an alias works."
  (let ((case-fold-search t))
    (rg "hello" "*.baz" (concat default-directory "test/data"))
    (with-current-buffer "*rg*"
      (should (rg-wait-for-search-result))
      (let ((bufstr (buffer-substring-no-properties (point-min) (point-max))))
        (should (= 0 (s-count-matches "foo.el.*hello" bufstr)))
        (should (= 0 (s-count-matches "bar.el.*hello" bufstr)))
        (should (= 3 (s-count-matches "foo.baz.*hello" bufstr)))
        (should (= 3 (s-count-matches "bar.baz.*hello" bufstr)))))))

(ert-deftest rg-integration-test/search-uppercase-regexp () :tags '(need-rg)
"Test that uppercase search triggers case sensitive search."
  (let ((case-fold-search t))
    (rg "Hello" "all" (concat default-directory "test/data"))
    (with-current-buffer "*rg*"
      (should (rg-wait-for-search-result))
      (let ((bufstr (buffer-substring-no-properties (point-min) (point-max))))
        (should (= 1 (s-count-matches "foo.el.*hello" bufstr)))
        (should (= 1 (s-count-matches "bar.el.*hello" bufstr)))))))

(ert-deftest rg-integration-test/search-case-sensitive-regexp () :tags '(need-rg)
"Test explicit case sensitive search."
  (let ((case-fold-search nil))
    (rg "hello" "all" (concat default-directory "test/data")))
  (with-current-buffer "*rg*"
    (should (rg-wait-for-search-result))
    (let ((case-fold-search t)
          (bufstr (buffer-substring-no-properties (point-min) (point-max))))
      (should (= 1 (s-count-matches "foo.el.*hello" bufstr)))
      (should (= 1 (s-count-matches "bar.el.*hello" bufstr))))))

(provide 'rg.el-test)

;;; rg.el-test.el ends here