(push #p"/home/turtle/scm-controlled/common-lisp/" ql:*local-project-directories*)
(ql:quickload '(:com.inuoe.jzon :yason :babel :cl-base64) :silent t)
(ql:quickload "secd-emulator")
(asdf:make "secd-emulator/executable")
