;;;; secd-emulator.asd — System definition for secd-emulator
;;;;
;;;; Copyright (C) 2026
;;;; License: GPL3

(asdf:defsystem #:secd-emulator
  :description "SECD machine emulator for testing"
  :author "Your Name"
  :license "GPL3"
  :version "0.0.1.0"
  :depends-on (#:iterate
               #:metabang-bind
               #:cl-bazon
               #:alexandria
               #:nrepl)
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "emulator")
                             (:file "memory")
                             (:file "io")
                             (:file "debugger")
                             (:file "nrepl-server")
                             (:file "main")))))
