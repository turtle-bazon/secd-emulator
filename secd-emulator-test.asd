;;;; secd-emulator/test.asd — Test system definition for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(asdf:defsystem #:secd-emulator/test
  :description "Tests for secd-emulator"
  :author "Your Name"
  :license "GPL3"
  :version "0.0.1.0"
  :depends-on (#:secd-emulator
               #:fiveam)
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "emulator-tests")
                             (:file "memory-tests")))))
