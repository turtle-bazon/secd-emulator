;;;; io.lisp — I/O simulation for emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(in-package #:secd-emulator)

;;; I/O state
(defstruct io
  gpio
  serial-input
  serial-output
  callbacks)

;;; Create I/O
(defun make-io ()
  "Create a new I/O state."
  (make-io :gpio (make-array 30 :element-type '(unsigned-byte 8) :initial-element 0)
           :serial-input (make-array 256 :element-type '(unsigned-byte 8))
           :serial-output (make-array 256 :element-type '(unsigned-byte 8))
           :callbacks nil))

;;; Initialize I/O
(defun io-init (io &optional (baud 115200))
  "Initialize I/O with specified baud rate."
  (format t "[Emulator] I/O initialized at ~A baud~%" baud))

;;; GPIO write
(defun io-gpio-write (io pin value)
  "Write value to GPIO pin."
  (when (and (>= pin 0) (< pin 30))
    (setf (aref (io-gpio io) pin) value)
    (format t "[Emulator] GPIO ~A = ~A~%" pin value)))

;;; GPIO read
(defun io-gpio-read (io pin)
  "Read value from GPIO pin."
  (if (and (>= pin 0) (< pin 30))
      (aref (io-gpio io) pin)
      0))

;;; Serial write
(defun io-serial-write (io byte)
  "Write byte to serial output."
  (vector-push-extend byte (io-serial-output io))
  (format t "~C" (code-char byte)))

;;; Serial read
(defun io-serial-read (io)
  "Read byte from serial input."
  (if (> (length (io-serial-input io)) 0)
      (let ((byte (aref (io-serial-input io) 0)))
        (setf (io-serial-input io) 
              (subseq (io-serial-input io) 1))
        byte)
      0))
