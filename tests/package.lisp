;;;; package.lisp — Test package definitions for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(defpackage #:secd-emulator/test
  (:use #:cl #:fiveam #:secd-emulator)
  (:export
   #:run-tests))
