(push #p"/home/turtle/scm-controlled/common-lisp/" ql:*local-project-directories*)
(ql:quickload :secd-emulator :silent t)
(in-package :secd-emulator.web)
(%run :port 8899 :address "0.0.0.0")
