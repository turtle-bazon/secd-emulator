;;;; package.lisp — VM packages
(defpackage #:secd-emulator.vm
  (:use #:cl)
  (:export
    ;; values / heap
    #:make-heap
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
    #:machine-steps #:machine-ip #:machine-running
    #:load-bytecode #:reset-machine #:step-once #:halted-p

    ;; primitives
    #:install-default-prims #:register-device-prims
    #:*device-table* #:*prim-impls*))
