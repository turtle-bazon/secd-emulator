;;;; build.lisp — produce the standalone binary at build/secd-emulator
(push #p"/home/turtle/scm-controlled/common-lisp/" ql:*local-project-directories*)
(ql:quickload :secd-emulator/executable)
(asdf:make :secd-emulator/executable)
(format t "~%Binary at build/secd-emulator~%")
