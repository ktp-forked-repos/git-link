;;; git-link.el --- Create URLs to a buffer's location in its GitHub/Bitbucket/Gitorious/... repository

;; Author: Skye Shaw <skye.shaw@gmail.com>
;; Version: 0.0.2

;;; Commentary:

;; Create a URL representing the current buffer's location in its GitHub/Bitbucket/... repository at
;; the current line number or active region. The URL will be added to the kill ring.
;;
;; With a prefix argument prompt for the remote's name. Defaults to "origin".

(defvar git-link-default-remote "origin" "Name of the remote branch to link to")

(defvar git-link-remote-alist
  '(("github.com"    git-link-github)
    ("bitbucket.com" git-link-bitbucket)
    ("gitorious.org" git-link-gitorious))
  "Maps remote hostnames to a function capable of creating the appropriate URL")

;; Matches traditional URL and scp style
;; This probably wont work for git remotes that aren't services
(defconst git-link-remote-regex "\\([-.[:word:]]+\\)[:/]\\([^/]+/[^/]+?\\)\\(?:\\.git\\)?$")

(defun git-link-chomp (s)
  (if (string-match "\\(\r?\n\\)+$" s)
      (replace-match "" t t s)
    s))

(defun git-link-exec (cmd)
  (shell-command-to-string (format "%s 2>%s" cmd null-device)))

(defun git-link-last-commit ()
  (git-link-exec "git --no-pager log -n 1 --pretty=format:%H"))

(defun git-link-current-branch ()
  (let ((branch (git-link-exec "git symbolic-ref HEAD")))
      (if (string-match "/\\([^/]+?\\)$" branch)
          (match-string 1 branch))))

(defun git-link-repo-root ()
  (git-link-chomp (git-link-exec "git rev-parse --show-toplevel")))

(defun git-link-remote-url (name)
  (git-link-chomp (git-link-exec (format "git config --get remote.%s.url" name))))

(defun git-link-relative-filename ()
  (let* ((filename (buffer-file-name))
         (dir      (git-link-repo-root)))
    (if (and dir buffer-file-name)
        (substring filename (1+ (length dir))))))

(defun git-link-remote-host (remote-name)
  (let ((url (git-link-remote-url remote-name)))
    (if (string-match git-link-remote-regex url)
        (match-string 1 url))))

(defun git-link-remote-dir (remote-name)
  (let ((url (git-link-remote-url remote-name)))
    (if (string-match git-link-remote-regex url)
        (match-string 2 url))))

(defun git-link-github (hostname dirname filename branch commit start end)
  (format "https://github.com/%s/tree/%s/%s#%s"
	  dirname
	  (or branch commit)
	  filename
	  (if (and start end)
	      (apply 'format "L%s-L%s"
		     (mapcar 'line-number-at-pos (list start end)))
	    (format "L%s" start))))

;; https://gitorious.org/USER/REPO/source/COMMIT-SHA:lib/DllAvCore.h#L6
(defun git-link-gitorious ())
; https://bitbucket.org/USER/REPO/src/933ffcd60cb600d3c39a8505623717d9e806b4e7/Gemfile?at=branch-name&#cl-13
(defun git-link-bitbucket ())

(defun git-link (&optional prompt?)
  "Create a URL representing the current buffer's location in its GitHub/Bitbucket/Gitorious/... 
repository at  the current line number or active region. The URL will be added to the kill ring.

 With a prefix argument prompt for the remote's name. Defaults to \"origin\"."

  (interactive "P")
  (let* ((remote-name (if prompt? (read-string "Remote: " nil nil git-link-default-remote)
                        git-link-default-remote))
         (remote-host (git-link-remote-host remote-name))
         (filename    (git-link-relative-filename))
         (branch      (git-link-current-branch))
         (commit      (git-link-last-commit))
         (handler     (nth 1 (assoc remote-host git-link-remote-alist)))
         (lines       (if (region-active-p)		;; instead of mark-active?
                          (list (region-beginning) (region-end))
                        (list (line-number-at-pos)))))

    (cond ((null filename)
           (message "Buffer has no file"))
          ((null remote-host)
           (message "Unknown remote '%s'" remote-name))
          ((and (null commit) (null branch))
           (message "Not on a branch, and repo does not have commits"))
          ;; functionp???
          ((null handler)
           (message "No handler for %s" remote-host))
          ;; null ret val
          ((kill-new
            (funcall handler
                     remote-host
		     (git-link-remote-dir remote-name)
                     filename
                     branch
                     commit
                     (nth 0 lines)
                     (nth 1 lines)))))))
