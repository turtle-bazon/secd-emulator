;;;; values.lisp — handles, heap, byte-vector table + arena, GC
;;;; Implements doc/specification.md §2-§5.
(in-package #:secd-emulator.vm)

(defconstant +tag-nil+      #x0)
(defconstant +tag-fixnum+   #x1)
(defconstant +tag-pair+     #x2)
(defconstant +tag-symbol+   #x3)
(defconstant +tag-bool+     #x4)
(defconstant +tag-closure+  #x5)
(defconstant +tag-bignum+   #x6)
(defconstant +tag-free+     #x7)
(defconstant +tag-bytevec+  #xA)

(defconstant +type-mask+  #xF000)
(defconstant +index-mask+ #x0FFF)
(defconstant +free-marker+ 255)

;;; Canonical special handles (bit-exact with the C firmware).
(defparameter +nil+   #x0000)
(defparameter +true+  #x8000)
(defparameter +false+ #x9000)

(deftype handle () '(unsigned-byte 16))

(defun mk-handle (tag index) (logior (ash tag 12) index))
(defun handle-tag (v) (ash v -12))
(defun handle-index (v) (logand v #x0FFF))
(defun mk-fixnum (n) (mk-handle +tag-fixnum+ (logand n #x0FFF)))
(defun fixnum-value (v)
  (let ((i (logand v #x0FFF)))
    (if (logbitp 11 i) (- i #x1000) i)))
(defun truthy (v) (and (/= v +nil+) (/= v +false+)))
(defun mk-bool (b) (if b +true+ +false+))

(defstruct (heap (:constructor make-heap%))
  (size       0 :type (integer 1 4095))
  cars                                  ; (simple-array (unsigned-byte 16))
  cdrs
  types                                 ; tag byte or +free-marker+
  omarks                                ; object mark bits
  (next-free 0 :type (integer 0 4095))
  ;; byte-vector descriptor table
  (bv-max 256 :type (integer 1 4096))
  bvkinds                               ; ub8: 0 free, 1 rom, 2 ram
  bvoffs                                ; u32: rom offset / ram offset
  bvlens                                ; u16
  bvmarks                               ; bit-vector per descriptor
  rom-buffers                           ; hash: slot -> bytecode buffer
  (bv-count 0 :type (integer 0 4096))
  arena                                 ; simple UB8 backing RAM vectors
  (arena-fill 0 :type (integer 0 #xFFFFFFFF)))

(defun make-heap (&key (objects 2048) (arena-bytes 262144))
  (let ((size (min objects 4095)))
    (make-heap%
     :size size
     :cars  (make-array size :element-type '(unsigned-byte 16) :initial-element 0)
     :cdrs  (make-array size :element-type '(unsigned-byte 16) :initial-element 0)
     :types (make-array size :element-type '(unsigned-byte 8)
                        :initial-element +free-marker+)
     :omarks (make-array size :element-type 'bit :initial-element 0)
     :bv-max 1024
     :bvkinds (make-array 1024 :element-type '(unsigned-byte 8) :initial-element 0)
     :bvoffs  (make-array 1024 :element-type '(unsigned-byte 32) :initial-element 0)
     :bvlens  (make-array 1024 :element-type '(unsigned-byte 16) :initial-element 0)
     :bvmarks (make-array 1024 :element-type 'bit :initial-element 0)
     :rom-buffers (make-hash-table)
     :arena (make-array arena-bytes :element-type '(unsigned-byte 8)
                                    :initial-element 0))))

(defun heap-car (h i) (aref (heap-cars h) i))
(defun heap-cdr (h i) (aref (heap-cdrs h) i))
(defun set-heap-car (h i v) (setf (aref (heap-cars h) i) v))
(defun set-heap-cdr (h i v) (setf (aref (heap-cdrs h) i) v))

"Allocate an object with TAG; returns index or 0 on exhaustion."
(defun heap-alloc (heap tag)
  (with-slots (types next-free size) heap
    (flet ((scan (from to)
             (loop for i from from below to
                   when (= (aref types i) +free-marker+)
                     do (setf (aref types i) tag
                              next-free (min size (1+ i)))
                     and return i)))
      (or (scan next-free size) (scan 0 size) 0))))

(defun cons-values (heap a d)
  "CONS two handles; NIL handle on exhaustion."
  (let ((i (heap-alloc heap +tag-pair+)))
    (if (zerop i)
        +nil+
        (progn (set-heap-car heap i a)
               (set-heap-cdr heap i d)
               (mk-handle +tag-pair+ i)))))

(defun list-values (heap items)
  "Build a proper list of HANDLES terminated by +nil+."
  (let ((acc +nil+))
    (dolist (it (reverse items) acc)
      (setf acc (cons-values heap it acc)))))

(defun list-iter (heap lst fn)
  "Call FN(handle) for each element of proper list LST."
  (loop for cur = lst then (heap-cdr heap (handle-index cur))
        while (= (handle-tag cur) +tag-pair+)
        do (funcall fn (heap-car heap (handle-index cur)))))

;;; ------------------------- byte vectors ---------------------------------

(defun bv-kind (h s) (aref (heap-bvkinds h) s))
(defun bv-off  (h s) (aref (heap-bvoffs h) s))
(defun bv-len  (h s) (aref (heap-bvlens h) s))

"Allocate a writable (RAM) byte-vector of LEN zero bytes; slot or nil."
(defun bv-alloc (heap len)
  (with-slots (bvkinds bvoffs bvlens bv-count bv-max arena arena-fill) heap
    (when (or (> len (- (length arena) arena-fill))
              (>= bv-count bv-max))
      (return-from bv-alloc nil))
    (let ((slot bv-count))
      (incf bv-count)
      (setf (aref bvkinds slot) 2
            (aref bvoffs  slot) arena-fill
            (aref bvlens  slot) len)
      (fill arena 0 :start arena-fill :end (+ arena-fill len))
      (incf arena-fill len)
      slot)))

"Register a read-only ROM literal living inside BYTECODE at OFFSET."
(defun bv-register-rom (heap bytecode offset len)
  (with-slots (bvkinds bvoffs bvlens bv-count bv-max) heap
    (when (>= bv-count bv-max) (return-from bv-register-rom nil))
    (let ((slot bv-count))
      (incf bv-count)
      (setf (aref bvkinds slot) 1
            (aref bvoffs  slot) offset
            (aref bvlens  slot) len)
      (push bytecode (gethash slot (heap-rom-buffers heap)))
      slot)))

(defun bv-read (heap slot i)
  (if (>= i (bv-len heap slot))
      -1
      (ecase (bv-kind heap slot)
        (1 (aref (gethash slot (heap-rom-buffers heap))
                 (+ (bv-off heap slot) i)))
        (2 (aref (heap-arena heap) (+ (bv-off heap slot) i))))))

(defun bv-write (heap slot i byte)
  (when (and (= (bv-kind heap slot) 2) (< i (bv-len heap slot)))
    (setf (aref (heap-arena heap) (+ (bv-off heap slot) i)) byte)
    t))

(defun bv-copy-out (heap slot ab8)
  "Copy descriptor SLOT contents into simple UB8 vector AB8 (len >= bv-len)."
  (ecase (bv-kind heap slot)
    (1 (replace ab8 (gethash slot (heap-rom-buffers heap))
                :start2 (bv-off heap slot)
                :end2 (+ (bv-off heap slot) (bv-len heap slot))))
    (2 (replace ab8 (heap-arena heap)
                :start2 (bv-off heap slot)
                :end2 (+ (bv-off heap slot) (bv-len heap slot)))))
  ab8)

(defun bv-write-in (heap slot ab8)
  "Overwrite RAM descriptor SLOT from AB8 (must fit)."
  (when (= (bv-kind heap slot) 2)
    (replace (heap-arena heap) ab8 :start1 (bv-off heap slot))))

;;; ------------------------------ GC --------------------------------------

(defun mark-value (heap v)
  (labels ((mark-obj (idx)
             (unless (or (zerop idx) (= 1 (bit (heap-omarks heap) idx)))
               (setf (bit (heap-omarks heap) idx) 1)
               (case (aref (heap-types heap) idx)
                 (#.+tag-pair+
                  (mark-value heap (heap-car heap idx))
                  (mark-value heap (heap-cdr heap idx)))
                 (#.+tag-closure+
                  (mark-value heap (heap-cdr heap idx)))))))
    (case (handle-tag v)
      (#.+tag-pair+    (mark-obj (handle-index v)))
      (#.+tag-closure+ (mark-obj (handle-index v)))
      (#.+tag-bignum+  (mark-obj (handle-index v)))
      (#.+tag-bytevec+
       ;; direct bytevec roots are tracked separately by the machine
       (values)))))

"Mark bytevec SLOT live (used for BIGNUM magnitudes and machine roots)."
(defun mark-bv-slot (heap slot)
  (when (< slot (length (heap-bvmarks heap)))
    (setf (bit (heap-bvmarks heap) slot) 1)))

"Collect garbage given ROOTS (list of handles). Returns freed object count."
(defun heap-gc (heap roots)
  (fill (heap-omarks heap) 0)
  (fill (heap-bvmarks heap) 0)
  ;; pre-mark all ROM slots live (they are permanent)
  (dotimes (s (bv-count heap))
    (when (= (bv-kind heap s) 1) (mark-bv-slot heap s)))
  (dolist (r roots) (mark-value heap r))
  ;; BIGNUMs keep their magnitude alive: second pass after object marking
  (dotimes (i (heap-size heap))
    (when (and (= 1 (bit (heap-omarks heap) i))
               (= +tag-bignum+ (aref (heap-types heap) i)))
      (mark-bv-slot heap (logand (heap-cdr heap i) #x0FFF))))
  ;; sweep objects
  (let ((freed 0))
    (dotimes (i (heap-size heap))
      (when (/= (aref (heap-types heap) i) +free-marker+)
        (if (= 1 (bit (heap-omarks heap) i))
            (setf (bit (heap-omarks heap) i) 0)
            (progn (setf (aref (heap-types heap) i) +free-marker+)
                   (incf freed)))))
    ;; sweep + pack RAM vectors
    (let ((pack 0))
      (dotimes (s (bv-count heap))
        (ecase (bv-kind heap s)
          ((0))
          (1 )                                   ; rom untouched
          (2 (if (= 1 (bit (heap-bvmarks heap) s))
                 (progn
                   (when (/= (bv-off heap s) pack)
                     (replace (heap-arena heap) (heap-arena heap)
                              :start1 pack :end1 (+ pack (bv-len heap s))
                              :start2 (bv-off heap s)))
                     (setf (aref (heap-bvoffs heap) s) pack)
                     (incf pack (bv-len heap s))
                     (setf (bit (heap-bvmarks heap) s) 0))
                 (setf (aref (heap-bvkinds heap) s) 0)))))
      (setf (heap-arena-fill heap) pack))
    freed))
