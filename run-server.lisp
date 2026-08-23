(push #p"/home/turtle/scm-controlled/common-lisp/" ql:*local-project-directories*)
(ql:quickload :secd-emulator)
(secd-emulator.web::main :port 8899)
