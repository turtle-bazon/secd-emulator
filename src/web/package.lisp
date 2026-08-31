;;;; package.lisp - web server
(defpackage #:secd-emulator.web
  (:use :cl)
  (:import-from :flexi-streams :flexi-stream-stream)
  (:import-from :secd-emulator.vm
                #:make-heap #:make-machine #:machine-heap
                #:heap-size #:heap-types
                #:heap-alloc
                #:load-bytecode #:step-once #:halted-p #:reset-machine
                #:install-default-prims #:register-device-prims
                #:machine-console-out-hook #:machine-hal-event-hook
                #:machine-console-in-push
                #:machine-steps #:machine-ip #:machine-sp
                #:machine-error-code #:machine-running
                #:machine-stack #:machine-code #:machine-e #:machine-g
                #:heap-car #:heap-cdr
                #:+op-add+ #:+op-sub+ #:+op-mul+ #:+op-div+ #:+op-mod+
                #:+op-eq+  #:+op-lt+  #:+op-gt+
                #:+op-stop+ #:+op-app+ #:+op-call+
                #:+tag-fixnum+ #:+tag-pair+ #:+tag-bytevec+
                #:+tag-bool+ #:+tag-closure+ #:+tag-bignum+ #:+tag-nil+
                #:+nil+ #:+true+ #:+false+
                #:handle-tag #:handle-index #:fixnum-value #:bv-len
                #:*prim-impls* #:*core-op-fns*)
  (:import-from :websocket-driver
                #:make-server #:on #:send #:start-connection)
  (:import-from :bordeaux-threads #:make-thread)
  (:import-from :com.inuoe.jzon #:parse #:stringify)
  (:import-from :cl-base64 #:base64-string-to-usb8-array)
  (:import-from :alexandria #:read-file-into-byte-vector)
  (:export #:main #:start-server))

(in-package #:secd-emulator.web)
