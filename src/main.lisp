;;;; main.lisp — Main entry point for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(in-package #:secd-emulator)

;;; Command line interface
(defun main ()
  "Main entry point for secd-emulator."
  (format t "secd-emulator v~A~%" 
          (asdf:component-version (asdf:find-system :secd-emulator)))
  ;; TODO: Implement CLI
  (format t "Usage: secd-emulator [options] bytecode-file~%")
  (format t "Options:~%")
  (format t "  --target <target>  Target platform (rp2040, esp32)~%")
  (format t "  --heap <size>      Heap size in bytes~%")
  (format t "  --stack <size>     Stack size in bytes~%")
  (format t "  --debug            Enable debugger~%")
  (format t "  --trace            Enable instruction tracing~%")
  (format t "  --nrepl            Start nREPL server~%")
  (format t "  --nrepl-port <p>   nREPL port (default: 7888)~%")
  (format t "  --help             Show this help~%"))

;;; Run emulator
(defun run (bytecode-file &key (target :rp2040) (debug nil) (trace nil))
  "Run a bytecode file on the emulator."
  (let* ((emulator (make-emulator))
         (debugger (when debug (make-debugger emulator))))
    ;; Load bytecode
    (format t "Loading ~A...~%" bytecode-file)
    ;; TODO: Load bytecode file
    ;; Run
    (when debug
      (debugger-start debugger))
    (emulator-run emulator nil)))

;;; Start with nREPL
(defun start (&key (port 7888) (bytecode nil))
  "Start emulator with nREPL server."
  (setup-nrepl-context)
  (start-nrepl port)
  (when bytecode
    (load-bytecode bytecode))
  (format t "Ready. Use (status) to check emulator state.~%"))
