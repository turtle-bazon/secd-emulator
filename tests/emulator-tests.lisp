;;;; emulator-tests.lisp — Tests for emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(in-package #:secd-emulator/test)

(def-suite emulator-tests
  :description "Tests for the emulator")

(in-suite emulator-tests)

(test make-emulator
  (let ((emulator (secd-emulator:make-emulator)))
    (is (not (null emulator)))
    (is (null (secd-emulator:emulator-error emulator)))))

(test emulator-reset
  (let ((emulator (secd-emulator:make-emulator)))
    (secd-emulator:emulator-reset emulator)
    (is (null (secd-emulator:emulator-error emulator)))))
