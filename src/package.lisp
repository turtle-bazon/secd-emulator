;;;; package.lisp — Package definitions for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(defpackage #:secd-emulator
  (:use #:cl #:iterate #:metabang-bind #:alexandria)
  (:export
   ;; Emulator
   #:emulator
   #:make-emulator
   #:emulator-run
   #:emulator-step
   #:emulator-reset
   
   ;; Memory
   #:memory
   #:memory-allocate
   #:memory-read
   #:memory-write
   
   ;; I/O
   #:io-init
   #:io-gpio-write
   #:io-gpio-read
   #:io-serial-write
   #:io-serial-read
   
   ;; Debugger
   #:debugger
   #:debugger-start
   #:debugger-stop
   #:debugger-breakpoint
   #:debugger-step
   
   ;; nREPL
   #:start-nrepl
   #:stop-nrepl
   #:start))
