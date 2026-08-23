;;;; build.lisp — produce the standalone binary at build/secd-emulator
(push #p"/home/turtle/scm-controlled/common-lisp/" ql:*local-project-directories*)
(ql:quickload "secd-emulator")
(ensure-directories-exist #p"build/secd-emulator")
(asdf:make "secd-emulator/executable")
