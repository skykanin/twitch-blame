;;; twitch-blame.el --- Interactive feedback from twitch chat -*- lexical-binding: t -*-
;;
;; Copyright (C) 2021 Skykain
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;; This file is not part of GNU Emacs.
;;
;; Author: Skykanin <https://github.com/skykanin>
;; Maintainer: Skykanin <3789764+skykanin@users.noreply.github.com>
;; Created: July 22, 2021
;; Modified: July 22, 2021
;; Version: 0.0.1
;; Keywords: twitch, chat, blame, comment
;; Homepage: https://github.com/skykanin/twitch-blame
;; Package-Requires: ((emacs "24.3"))
;;
;;; Commentary:
;;
;;  Twitch-blame lets twitch chatters interact with your live coding session
;;  by integrating twitch chat comments directly into your editor through
;;  overlays on a given line.
;;
;;; Code:

(require 'erc)
(cursor-sensor-mode)

(define-fringe-bitmap
  'twitch-blame
  [252]
  nil
  nil
  '(center repeated))

(defgroup twitch-blame nil
  "The customisation group for the twitch-blame plugin."
  :group 'applications)

(defface twitch-fringe-face
  '((t :foreground "#800080"))
  "Face for the Twitch fringe icon."
  :group 'basic-faces)

(defvar twitch-blames
  (make-hash-table :test #'equal)
  "Hash table containing all twitch blame entries.")

(defvar current-buffer nil
  "Stores the current buffer. Used to determine where to make overlays.")

(defun pushhash (line-number comment hashmap)
  "Update HASHMAP by pushing new COMMENT onto existing overlay property.
Overlay is found by looking up the LINE-NUMBER key in the HASHMAP."
  (if-let (overlay (gethash line-number hashmap))
   (let ((comments (overlay-get overlay 'comments)))
     (when (not (member comment comments))
       (delete-overlay overlay)
       (puthash line-number (indicate-blame-comment line-number (cons comment comments)) hashmap)))
   (puthash line-number (indicate-blame-comment line-number (list comment)) hashmap)))

(defun make-overlay-at (line-number)
  "Creat an overlay at given LINE-NUMBER."
  (save-excursion
    (goto-char (point-min))
    (forward-line (- line-number 1))
    (beginning-of-line)
    (make-overlay (point) (progn (end-of-line) (point)))))

(defun display-comments (comments)
  "Display all the COMMENTS as a message."
  (message "%s"
    (mapconcat
       (lambda (msg)
         (let* ((author (plist-get msg :author))
                (author-styled (propertize author 'face '(:foreground "#800080")))
                (comment (plist-get msg :comment)))
           (format "%s - %s" author-styled comment)))
       comments
       "; ")))

(defun trigger-message-display (overlay _1 _2 dir)
  "Display comments from OVERLAY when DIR is entered."
  (when (eq dir 'entered)
    (display-comments (overlay-get overlay 'comments))))

(defun indicate-blame-comment (line-number comments)
  "Indicate COMMENTS on a given LINE-NUMBER by displaying a bar on the left fringe.
Return created overlay."
  (let* ((overlay (make-overlay-at line-number))
         (trigger-msg (lambda (window prev-pos dir) (trigger-message-display overlay window prev-pos dir))))
    (overlay-put overlay 'before-string
          (propertize "x" 'display '(left-fringe twitch-blame twitch-fringe-face)))
    (overlay-put overlay 'twitch-overlay t)
    (overlay-put overlay 'comments comments)
    (overlay-put overlay 'cursor-sensor-functions (list trigger-msg))
    overlay))

(defun line-number-at-point (pos &optional counter)
  "Return the line-number for a given POS and an optional accumulator COUNTER."
  (unless counter (setq counter 1))
  (if (eq pos (point-min))
   counter
   (save-excursion
     (beginning-of-line)
     (forward-line -1)
     (line-number-at-point (point) (+ 1 counter)))))

(defun clear-blame ()
  "Delete twitch blame indicator at current position."
  (interactive)
  (let* ((pt (point))
         (line-number (line-number-at-point pt)))
    (remove-overlays pt pt 'twitch-overlay t)
    (remhash line-number twitch-blames)))

(defun clear-all-blames ()
  "Delete all twitch blame indicators in current buffer."
  (interactive)
  (remove-overlays (point-min) (point-max) 'twitch-overlay t)
  (setq twitch-blames (make-hash-table :test #'equal)))

(defcustom twitch-irc-address '("irc.chat.twitch.tv" . 6667)
  "The twitch irc address and port number.
Default value set to '(\"irc.chat.twitch.tv\" . 6667)"
  :type 'association
  :group 'twitch-blame)

(defcustom twitch-channel-name nil
  "The twitch channel to read messages from."
  :type 'string
  :group 'twitch-blame)

(defcustom twitch-nick nil
  "The twitch nickname to connect to the channel with."
  :type 'string
  :group 'twitch-blame)

(defcustom twitch-token nil
  "The twitch oauth token required to connect to the channel."
  :type 'string
  :group 'twitch-blame)

(defun irc-connected-p ()
  "Check if erc is connected to a server. Return first server buffer."
  (when (boundp 'erc-server-process)
   (catch 'running
     (dolist (buffer (buffer-list))
       (when (buffer-local-value 'erc-server-process buffer)
        (throw 'running buffer))))))

(defun connect-to-irc ()
  "Connect to the twitch channel irc chat."
  (when (not twitch-channel-name)
    (message "The %s variable hasn't been set" 'twitch-channel-name))
  (when (not twitch-nick)
    (message "The %s variable hasn't been set" 'twitch-nick))
  (when (not twitch-token)
    (message "The %s variable hasn't been set" 'twitch-token))
  (save-window-excursion
    (let ((buffer (erc :server (car twitch-irc-address) :port (cdr twitch-irc-address)
                    :nick (downcase twitch-nick)
                    :password (format "oauth:%s" twitch-token))))
      ;; TODO: See https://github.com/skykanin/twitch-blame/issues/1
      (with-current-buffer buffer
       (run-at-time 3 nil #'erc-join-channel twitch-channel-name)))))

(defun parse-command-string (msg)
  "Parse command MSG into its three components author, line and comment."
  (let ((regexp (rx "<" (group (one-or-more nonl)) ">"
                    space "!line" space (group (one-or-more digit))
                    space
                    (group (one-or-more nonl)))))
    (when (string-match regexp msg)
      (list :author (match-string 1 msg)
            :line (string-to-number (match-string 2 msg))
            :comment (let* ((comment (match-string 3 msg))
                            (last-char (substring comment -1)))
                       (substring comment 0
                         (when (string= last-char "]") -9)))))))

(defun add-blame-comment (start end _)
  "Add new blame entry from changed START to END region."
  (pcase (parse-command-string (buffer-substring-no-properties start end))
    (`(:author ,author :line ,n :comment ,comment)
     (save-window-excursion
       (switch-to-buffer current-buffer)
       (pushhash n `(:author ,author :comment ,comment) twitch-blames)))))

;;;###autoload
(define-minor-mode twitch-blame-mode
  "Let twitch chat blame your code live."
  :lighter "twitch blame"
  :keymap nil
  (setq current-buffer (buffer-name))
  (setq twitch-blames (make-hash-table :test #'equal))
  (add-hook 'erc-nickserv-identified-hook 'irc-connect-channel)
  (connect-to-irc)
  (add-hook 'after-change-functions #'add-blame-comment))

(provide 'twitch-blame)
;;; twitch-blame.el ends here
