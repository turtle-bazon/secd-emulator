;;;; debugger.lisp — Debugger for emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(in-package #:secd-emulator)

;;; Debugger state
(defstruct debugger
  emulator
  breakpoints
  stepping
  running)

;;; Create debugger
(defun make-debugger (emulator)
  "Create a new debugger for the emulator."
  (make-debugger :emulator emulator
                 :breakpoints nil
                 :stepping nil
                 :running nil))

;;; Start debugger
(defun debugger-start (debugger)
  "Start the debugger."
  (setf (debugger-running debugger) t)
  (format t "[Debugger] Started~%"))

;;; Stop debugger
(defun debugger-stop (debugger)
  "Stop the debugger."
  (setf (debugger-running debugger) nil)
  (format t "[Debugger] Stopped~%"))

;;; Set breakpoint
(defun debugger-breakpoint (debugger address)
  "Set a breakpoint at the specified address."
  (push address (debugger-breakpoints debugger))
  (format t "[Debugger] Breakpoint set at ~A~%" address))

;;; Single step
(defun debugger-step (debugger)
  "Execute a single instruction."
  (emulator-step (debugger-emulator debugger))
  (format t "[Debugger] Step~%"))
