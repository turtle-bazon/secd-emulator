;;;; package.lisp — VM packages
(defpackage #:secd-emulator.vm
  (:use #:cl)
  (:export
    ;; values / heap
    #:make-heap #:heap-size #:heap-types
    #:+tag-nil+ #:+tag-fixnum+ #:+tag-pair+ #:+tag-bool+ #:+tag-closure+
    #:+tag-bignum+ #:+tag-bytevec+
    #:+nil+ #:+true+ #:+false+
    #:mk-fixnum #:fixnum-value #:mk-handle #:handle-tag #:handle-index
    #:heap-alloc #:heap-car #:heap-cdr #:set-heap-car #:set-heap-cdr
    #:cons-values #:list-values #:list-iter #:heap-gc
    #:bv-alloc #:bv-get #:bv-len #:bv-read #:bv-write #:bv-register-rom

    ;; machine
    #:machine #:make-machine #:machine-heap #:machine-error-code
    #:machine-console-in #:machine-console-in-push
    #:machine-console-out-hook #:machine-hal-event-hook
    #:machine-steps #:machine-ip #:machine-running #:machine-sp
    #:machine-stack #:machine-code #:machine-e #:machine-g
    #:load-bytecode #:reset-machine #:step-once #:halted-p

    ;; opcodes
    #:+op-stop+ #:+op-app+ #:+op-call+ #:+op-add+ #:+op-sub+ #:+op-mul+
    #:+op-div+ #:+op-mod+ #:+op-eq+  #:+op-lt+  #:+op-gt+

    ;; primitives
    #:install-default-prims #:register-device-prims
    #:*device-table* #:*prim-impls* #:*core-op-fns*))
