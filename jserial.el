;;; jserial.el --- Java serial version generator

;; $Revision: 1.8 $
;; $Date: 2000/09/08 12:56:24 $

;; This file is not part of Emacs

;; Author: Phillip Lord<plord@hgmp.mrc.ac.uk>
;; Maintainer: Phillip Lord
;; Keywords: java, tools

;; Copyright (c) 1999 Phillip Lord.

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Status
;;
;; THIS SOFTWARE IS CURRENTLY CONSIDERED TO BE OF BETA OR EVEN ALPHA
;; QUALITY. I MAKE NO CLAIMS THAT IT WILL WORK AS ADVERTISED OR INDEED
;; WORK AT ALL. IT MAY EVEN DAMAGE YOUR JAVA SOURCE, WIPE YOUR HARD
;; DRIVE OR SELL YOUR CHILDREN OFF AS SLAVES. THESE ARNT LIKELY
;; BUT PLEASE TAKE PRECAUATIONS AT THE CURRENT TIME
;; 
;; The software was designed, written and tested on windows95 using 
;; NTEmacs, and a JDE 2.1.6 beta release. Please let me know if you 
;; get it working elsewhere. The current version should be available
;; at http://genetics.ich.ucl.ac.uk/plord

;;; Installation 
;;
;; This software requires the presence of the JDE. (Not for very much 
;; admittedly. But I would think anyone wanting to use this software
;; would also be using the JDE). Install this first (see sunsite.auc.dk/jde)
;;
;; Then place this file in your load path, and the following in your .emacs
;; file
;;
;; (require 'jserial)
;;

;;; Description:
;;
;; This package automatically generates a Java serialver statement by
;; invoking the serialver or other specified program. The package name
;; is gained from the source code. There are two main user commands
;; which are jserial-insert-serial-statement and
;; jserial-update-serial-statement. The first of these inserts a
;; statement into a class which does not already have one. If a
;; statement is found an error will be reported, and the second
;; version must be used. Similiarly the second function will only work
;; when an serialver statement already exists. The package has been
;; coded this way for security. These statements should not be updated
;; accidentally as this has implications for versioning of classes. 


;;; Limitations:
;; 
;; 1) At the moment the user has no choice where the statement goes within
;; the class.
;; 2) Serialver works on the current compiled version of the class. Ensuring
;; that this is the same as the current source, is currently the users problem.
;;

;;; Bugs
;;
;; 1) If errors are reported by serialver they are placed into the buffer!

;;; Acknowledgements;
;;
;; Specifically I would like to acknowledge the (unknowing) assistance
;; of David Ponce http://perso.wanadoo.fr/david.ponce/ whose jpack.el
;; package I have borrowed from judiciously, rather than learning how
;; to use custom from scratch. All errors in the code are mine, not his. 


(require 'jde)

(defconst jserial-version "$Revision: 1.8 $"
  "jserial version number.")

(defconst jserial-package-regexp
  "package .*;.*$"
  "The regexp used to find the java packages statement")

(defconst jserial-serial-regexp
  "static final long serialVersionUID .*;.*$"
  "The regexp used to find the java serial version statement")

(defgroup jserial nil
  "jserial package customisation"
  :group 'tools
  :prefix "jserial-")

(defcustom jserial-load-hook nil 
  "*Hook run when package has been loaded."
  :group 'jserial
  :type 'hook)

(defcustom jserial-serial-comment " //Generated by jserial"
  "*Java line comment appended to the serial statement"
  :group 'jserial
  :type 'string)

(defcustom jserial-serialver-program "serialver"
  "*Program used to calculate serialver statement"
  :group 'jserial
  :type 'string)

(defun jserial-customize()
  "Customisation of the group jserial."
  (interactive)
  (customize-group "jserial"))

(defun jserial-version-number()
  "Returns jserial version number."
  (string-match "[0123456789.]+" jserial-version)
  (match-string 0 jserial-version))

(defun jserial-display-version ()
  "Displays jserial version."
  (interactive)
  (message "Using 'jserial' version %s." (jserial-version-number)))

(defun jserial-insert-serial-statement()
  "Inserts a serial version statement, if one doesnt exists"
  (interactive)
  (save-excursion
    ;;Balk if there is already a serial statement, to avoid over-writing
    (if (jserial-position-point-on-serial-statement)
	(message "SerialVer statement already exists. Update with 'jserial-update-serial-statement'")
      (message "Inserting serialver statement" )
      (let ((serial-statement (jserial-generate-serial-statement)))
	;;if the serial regexp doesnt match the serial-regexp
	;;then there has been an error, so crash out
	
	;;string-match returns the position of the match. By sticking a
	;;space at the beginning a match will return at least 1 (ie true) wheras
	;;a non match will return 0.
	(if (string-match jserial-serial-regexp 
			       (concat " " serial-statement))
	    (progn
	      ;;position appropriately
	      (jserial-position-serial)
	      ;;Now so we can insert the statement
	      (insert serial-statement)
	      ;;find the serial statement. The windows version of serialver prints a CR, which 
	      ;;means the statement will be one line back from where point is. Im not sure that
	      ;;it does this on all platforms, so better to go the long way around
	      (jserial-position-point-on-serial-statement)
	      ;;Now move to the beginning of the line. (Probably not necessary)
	      (beginning-of-line)
	      ;;And kill upto the next ":" which removes the crap from the 
	      ;;beginning. 
	      (zap-to-char 1 ?:)
	      ;;And re-indent
	      (end-of-line)
	      (insert jserial-serial-comment)
	      (indent-according-to-mode)
	      (message "done"))
	  ;;we have had a mess up so instead of incorporating dump to mini-buffer
	  (message "Error running Serialver program: %s" serial-statement))))))

(defun jserial-position-point-on-serial-statement()
  "Postions the point on a preexisting serial statement, or returns 0"
  ;;Start of buffer
  (goto-char(point-min))
  ;;search forward for the serial ver statement. Return success or failure
  (re-search-forward jserial-serial-regexp (point-max) t))

(defun jserial-position-serial()
  "Positions point where the new serial statement should go"
  (interactive)
  (goto-char(point-min))
  ;;Find the first appearance of the "class Blah" line
  (re-search-forward (concat "class[ ]*" 
			     (file-name-sans-extension
			      (file-name-nondirectory (buffer-file-name)))))
  ;;Now find the first {
  (search-forward "{")
  ;;And the next line
  (forward-line))

(defun jserial-generate-serial-statement()
  "Generates the serialver statement"
  (shell-command-to-string
   (concat jserial-serialver-program " "
	   (if jde-compile-option-classpath
	       (jde-build-classpath-arg jde-compile-option-classpath jde-quote-classpath))
 	   (if (not jde-compile-option-classpath)
 	       (jde-build-classpath-arg jde-global-classpath jde-quote-classpath))
 	   " "
	   (jde-wiz-get-package-name)
	   "."
	   (file-name-sans-extension
	    (file-name-nondirectory (buffer-file-name))))))

(defun jserial-update-serial-statement()
  "Updates an existing serialver statement" 
  (interactive)
  (save-excursion
    ;;Find the existing statement
    (if (not (jserial-position-point-on-serial-statement))
	(message "There is no existing serialver statement. User jserial-insert-serial-statement instead" )
      (beginning-of-line)
      ;;And kill it
      (kill-line)
      ;;Now insert a new one
      (jserial-insert-serial-statement))))

;;Keybindings
(define-key jde-mode-map "\C-c\C-v\C-u" 'jserial-update-serial-statement)
(define-key jde-mode-map "\C-c\C-v\C-i" 'jserial-insert-serial-statement)


(provide 'jserial)
(run-hooks 'jserial-load-hook)




;; 
;; Changelog
;; $Log: jserial.el,v $
;; Revision 1.8  2000/09/08 12:56:24  lord
;; Serialver can now take a classpath argument, and jserial can
;; now pass one to it!
;; Thanks to Jason Stell <jstell@intelixinc.com> for pointing this
;; out and providing a patch.
;;
;; Revision 1.7  2000/01/25 14:15:18  lord
;; No real changes..first CVS checkin
;;
;; Revision 1.6  1999-06-19 15:16:31+01  phillip2
;; Removed buggy extra open bracket from beginning of line
;;
;; Revision 1.5  1999-06-16 23:29:33+01  phillip2
;; Now handles major errors from serialver program and crashes out
;;
;; Revision 1.4  1999-06-16 16:10:24+01  phillip2
;; Placed missing URL into comments.
;; Added user feedback to main commands
;; Now uses the "comment" option
;;
;; Revision 1.3  1999-06-15 18:24:21+01  phillip2
;; Fixed a few (fortunately predistribution) bugs
;;
;; Revision 1.2  1999-06-15 18:05:45+01  phillip2
;; First released version
;;
;;
;;
