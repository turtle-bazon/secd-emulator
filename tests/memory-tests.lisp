;;;; memory-tests.lisp — Tests for memory
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(in-package #:secd-emulator/test)

(def-suite memory-tests
  :description "Tests for memory")

(in-suite memory-tests)

(test make-memory
  (let ((memory (secd-emulator:make-memory :size 1000)))
    (is (not (null memory)))
    (is (= (secd-emulator:memory-size memory) 1000))))
