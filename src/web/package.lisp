;;;; package.lisp — web server
(defpackage #:secd-emulator.web
  (:use #:cl)
  (:import-from #:flexi-streams #:flexi-stream-stream)
  (:local-nicknames (#:vm #:secd-emulator.vm))
  (:import-from #:secd-emulator.vm
                #:make-heap #:make-machine #:machine-heap
                #:load-bytecode #:step-once #:halted-p #:reset-machine
                #:install-default-prims #:register-device-prims
                #:machine-console-out-hook #:machine-hal-event-hook
                #:machine-console-in-push #:machine-steps #:machine-ip
                #:machine-error-code #:machine-running)
  (:import-from #:websocket-driver
                #:make-server #:on #:start-connection
                #:send-text #:ready-state)
  (:export #:main #:start-server))

(in-package #:secd-emulator.web)
