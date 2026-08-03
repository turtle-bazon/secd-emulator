;;;; nrepl-server.lisp — nREPL server for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3
;;;;
;;;; nREPL server for debugging the emulator from a REPL.
;;;; Connect with: (cl-nrepl:connect :port 7888)

(in-package #:secd-emulator)

;;; nREPL server state
(defvar *nrepl-server* nil
  "The nREPL server instance.")

(defvar *nrepl-port* 7888
  "Default nREPL port.")

;;; Start nREPL server
(defun start-nrepl (&optional (port *nrepl-port*))
  "Start nREPL server on specified port."
  (when *nrepl-server*
    (format t "nREPL server already running on port ~A~%" *nrepl-port*)
    (return-from start-nrepl *nrepl-server*))
  
  (setf *nrepl-server* 
        (nrepl:start-server :port port))
  
  (format t "nREPL server started on port ~A~%" port)
  (format t "Connect with: (cl-nrepl:connect :port ~A)~%" port)
  
  *nrepl-server*)

;;; Stop nREPL server
(defun stop-nrepl ()
  "Stop the nREPL server."
  (when *nrepl-server*
    (nrepl:stop-server *nrepl-server*)
    (setf *nrepl-server* nil)
    (format t "nREPL server stopped~%")))

;;; nREPL evaluation context
(defvar *emulator* nil
  "Current emulator instance for nREPL evaluation.")

(defun setup-nrepl-context ()
  "Set up evaluation context for nREPL."
  (setf *emulator* (make-emulator))
  (format t "Emulator created for nREPL context~%"))

;;; Exported functions for nREPL evaluation
(defun status ()
  "Show emulator status."
  (if *emulator*
      (format t "Emulator: ~A~%" 
              (if (emulator-running *emulator*) "running" "stopped"))
      (format t "No emulator loaded~%")))

(defun load-bytecode (file)
  "Load bytecode file into emulator."
  (format t "Loading ~A...~%" file)
  ;; TODO: Implement
  (format t "Not implemented yet~%"))

(defun run ()
  "Run the emulator."
  (if *emulator*
      (progn
        (format t "Running...~%")
        ;; TODO: Implement
        (format t "Not implemented yet~%"))
      (format t "No emulator loaded~%")))

(defun step ()
  "Single step the emulator."
  (if *emulator*
      (progn
        ;; TODO: Implement
        (format t "Not implemented yet~%"))
      (format t "No emulator loaded~%")))

(defun reset ()
  "Reset the emulator."
  (if *emulator*
      (progn
        (emulator-reset *emulator*)
        (format t "Emulator reset~%"))
      (format t "No emulator loaded~%")))

(defun show-registers ()
  "Show SECD registers."
  (if *emulator*
      (progn
        (format t "S: ~A~%" (emulator-stack *emulator*))
        (format t "E: ~A~%" (emulator-environment *emulator*))
        (format t "C: ~A~%" (emulator-control *emulator*))
        (format t "D: ~A~%" (emulator-dump *emulator*)))
      (format t "No emulator loaded~%")))

(defun show-memory (&optional (start 0) (end 10))
  "Show memory contents."
  (if *emulator*
      (progn
        ;; TODO: Implement memory display
        (format t "Not implemented yet~%"))
      (format t "No emulator loaded~%")))

(defun gc ()
  "Run garbage collection."
  (if *emulator*
      (progn
        ;; TODO: Implement GC
        (format t "Not implemented yet~%"))
      (format t "No emulator loaded~%")))