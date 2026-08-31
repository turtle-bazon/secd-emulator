;;;; snapshot.lisp — Run the real SECD emulator on a hand-assembled demo
;;;; program, step it, and dump each state as JSON. The web UI consumes
;;;; this; the web UI does NOT emulate.

(require :asdf)
;; Load the VM source files directly — we don't need the web/Clack half
;; to run the emulator for snapshotting.
(let ((vm-dir (merge-pathnames "src/vm/" (or (ignore-errors (truename *load-truename*)) *default-pathname-defaults*))))
  (load (merge-pathnames "package.lisp" vm-dir))
  (load (merge-pathnames "values.lisp" vm-dir))
  (load (merge-pathnames "machine.lisp" vm-dir))
  (load (merge-pathnames "primitives.lisp" vm-dir)))

(in-package #:secd-emulator.vm)

;; --- Build a .secd unit (header + code) so load-bytecode finds the magic.
;; Header layout per machine.lisp load-bytecode:
;;   0..3   = "SECD"
;;   4..5   = version (0)
;;   6..7   = reserved (0)
;;   8..9   = code_size big-endian
;;   10..11 = const_size big-endian (0 for us)
;;   12..13 = reserved (0)
;;   14..   = code bytes
(defun build-secd-unit (code)
  (let* ((cs (length code))
         (buf (make-array (+ 14 cs) :element-type '(unsigned-byte 8) :initial-element 0)))
    (setf (aref buf 0) 83  (aref buf 1) 69  (aref buf 2) 67  (aref buf 3) 68) ; SECD
    (setf (aref buf 8) (ash cs -8)  (aref buf 9) (logand cs 255))
    (loop for i from 0 below cs do
      (setf (aref buf (+ 14 i)) (ldb (byte 8 0) (aref code i))))
    buf))

(defparameter *demo-code-bytes*
  '(#x02 #x00 #x05  #x02 #x00 #x03  #x10  #x78
    #x02 #x00 #x0A  #x02 #x00 #x04  #x11  #x78
    #x02 #x00 #x07  #x02 #x00 #x02  #x12  #x78
    #x02 #x00 #x01  #x02 #x00 #x02  #x32  #x78  #x00))

(defparameter *demo-code*
  (let ((v (make-array (length *demo-code-bytes*) :element-type '(unsigned-byte 8))))
    (loop for b in *demo-code-bytes* for i from 0 do (setf (aref v i) b))
    v))

(defparameter *demo-unit* (build-secd-unit *demo-code*))

(defun tag-name (tag)
  (cond ((= tag +tag-fixnum+)  "fixnum")
        ((= tag +tag-pair+)    "pair")
        ((= tag +tag-bytevec+) "bytevec")
        ((= tag +tag-bool+)    "bool")
        ((= tag +tag-closure+) "closure")
        ((= tag +tag-bignum+)  "bignum")
        ((= tag +tag-nil+)     "nil")
        (t                     "obj")))

;; Convert a handle to a compact JSON-friendly alist. Matches the web
;; "handle" shape: either a kind sentinel or {kind, i, ...}.
(defun handle->json (v heap)
  (cond ((null v) (list (cons "kind" "undef")))
        ((eql v +nil+)  (list (cons "kind" "nil")))
        ((eql v +true+) (list (cons "kind" "t")))
        ((eql v +false+)(list (cons "kind" "nil")))
        (t
         (let* ((tag (handle-tag v))
                (idx (handle-index v))
                (cell-tag (aref (heap-types heap) idx)))
           (cond
             ((= tag +tag-fixnum+)
              (list (cons "kind" "fixnum")
                    (cons "i" idx)
                    (cons "num" (fixnum-value v))))
             ((= tag +tag-pair+)
              (list (cons "kind" "pair")
                    (cons "i" idx)
                    (cons "car" (handle->json (heap-car heap idx) heap))
                    (cons "cdr" (handle->json (heap-cdr heap idx) heap))))
             ((= tag +tag-bytevec+)
              (list (cons "kind" "bytevec")
                    (cons "i" idx)
                    (cons "len" (bv-len heap idx))))
             (t
              (list (cons "kind" (tag-name cell-tag))
                    (cons "i" idx))))))))

;; Dump all allocated heap cells (skip free slots).
(defun heap->json (heap)
  (let ((out '())
        (n (heap-size heap)))
    (loop for i from 0 below n
          for tag = (aref (heap-types heap) i)
          when (/= tag +free-marker+) do
            (push
              (cond ((= tag +tag-fixnum+)
                     `(("addr" . ,i) ("tag" . "fixnum")
                       ("car" . 0) ("cdr" . 0) ("num" . 0)))
                    ((= tag +tag-pair+)
                     `(("addr" . ,i) ("tag" . "pair")
                       ("car" . ,(heap-car heap i))
                       ("cdr" . ,(heap-cdr heap i))))
                    ((= tag +tag-bytevec+)
                     `(("addr" . ,i) ("tag" . "bytevec")
                       ("car" . 0) ("cdr" . 0) ("len" . ,(bv-len heap i))))
                    (t
                     `(("addr" . ,i) ("tag" . ,(tag-name tag))
                       ("car" . 0) ("cdr" . 0))))
              out))
    (nreverse out)))

(defun dump-state (m step-no)
  (let* ((heap (machine-heap m))
         (stack-vals
           (loop for i from 0 below (machine-sp m)
                 collect (aref (machine-stack m) i)))
         (dump (machine-dump m))
         (dump-top (if dump (caar dump) nil)))
    `(("step" . ,step-no)
      ("ip" . ,(machine-ip m))
      ("sp" . ,(machine-sp m))
      ("steps" . ,(machine-steps m))
      ("error" . ,(machine-error-code m))
      ("halted" . ,(if (halted-p m) t :false))
      ("code" . ,(coerce (machine-code m) 'list))
      ("stack" . ,(mapcar (lambda (v) (handle->json v heap)) stack-vals))
      ("e" . ,(handle->json (machine-e m) heap))
      ("g" . ,(handle->json (machine-g m) heap))
      ("d" . ,(handle->json dump-top heap))
      ("heap" . ,(heap->json heap))
      ("dump" . ,(mapcar (lambda (fr) `(("e" . ,(car fr)) ("ret" . ,(cdr fr)))) dump)))))

;; --- Minimal JSON encoder for the alist-based shape. Only handles the
;; types we actually emit: string keys, numbers, strings, alists, lists,
;; t/nil. No need for yason.
(defun json-encode (v &optional (stream *standard-output*))
  (cond
    ((null v) (write-string "null" stream))
    ((eql v t) (write-string "true" stream))
    ((eql v :false) (write-string "false" stream))
    ((stringp v)
     (write-char #\" stream)
     (loop for c across v do
       (case c
         (#\\ (write-string "\\\\" stream))
         (#\" (write-string "\\\"" stream))
         (#\Newline (write-string "\\n" stream))
         (#\Return (write-string "\\r" stream))
         (#\Tab (write-string "\\t" stream))
         (t (if (or (< (char-code c) 32) (> (char-code c) 126))
                (format stream "\\u~4,'0X" (char-code c))
                (write-char c stream)))))
     (write-char #\" stream))
    ((numberp v) (format stream "~D" v))
    ((consp v)
     (cond
       ((and (consp (car v)) (stringp (caar v)))
        (write-char #\{ stream)
        (loop for (k . val) in v
              for firstp = t then nil do
                (unless firstp (write-char #\, stream))
                (json-encode (string k) stream)
                (write-string ":" stream)
                (json-encode val stream))
        (write-char #\} stream))
       (t
        (write-char #\[ stream)
        (loop for x in v
              for firstp = t then nil do
                (unless firstp (write-char #\, stream))
                (json-encode x stream))
        (write-char #\] stream))))
    (t (format stream "null"))))

;; Capture console output during the run by hooking the machine.
(defun run-demo ()
  (let* ((heap (make-heap :objects 512 :arena-bytes 65536))
         (m (make-machine heap))
         (console-out '()))
    (setf (machine-console-out-hook m)
          (lambda (s) (push s console-out)))
    ;; Register the default primitive set (+ - * / = < > etc) so ADD/SUB/MUL
    ;; produce real results.
    (install-default-prims m)
    ;; Pre-allocate one pair at index 0 (dummy) so the first real
    ;; cons-values call gets index 1. The heap's cons-values treats
    ;; alloc-result 0 as "exhaustion" and returns +nil+, which corrupts
    ;; the first cons. Burning index 0 with a dummy sidesteps that.
    (heap-alloc heap +tag-pair+)
    ;; install-default-prims registers primitives by NAME in *prim-impls*,
    ;; but the core-op dispatcher (call-core-op) looks them up by OPCODE
    ;; in *core-op-fns*. Wire the arithmetic opcodes through explicitly.
    (let ((by (lambda (nm) (lambda (h a) (funcall (gethash nm *prim-impls*) h a)))))
      (setf (gethash +op-add+ *core-op-fns*) (funcall by "+"))
      (setf (gethash +op-sub+ *core-op-fns*) (funcall by "-"))
      (setf (gethash +op-mul+ *core-op-fns*) (funcall by "*"))
      (setf (gethash +op-div+ *core-op-fns*) (funcall by "/"))
      (setf (gethash +op-mod+ *core-op-fns*) (funcall by "%"))
      (setf (gethash +op-eq+  *core-op-fns*) (funcall by "="))
      (setf (gethash +op-lt+  *core-op-fns*) (funcall by "<"))
      (setf (gethash +op-gt+  *core-op-fns*) (funcall by ">"))
      (setf (gethash +op-le+  *core-op-fns*) (funcall by "<="))
      (setf (gethash +op-ge+  *core-op-fns*) (funcall by ">=")))
    (format *error-output* "load: ~A~%" (load-bytecode m *demo-unit*))
    (let ((out '())
          (i 0)
          (per-step-consoles '()))
      (push (dump-state m i) out)
      (push (nreverse console-out) per-step-consoles)
      (setf console-out '())
      (loop
        (when (or (halted-p m) (/= (machine-error-code m) 0)) (return))
        (step-once m)
        (incf i)
        (push (dump-state m i) out)
        (push (nreverse console-out) per-step-consoles)
        (setf console-out '())
        (when (> i 200) (return)))
      (let ((snaps (nreverse out))
            (conss (nreverse per-step-consoles)))
        (format t "{\"code\":[")
        (loop for (b . rest) on (coerce *demo-code* 'list)
              do (format t "~D" b) when rest do (format t ","))
        (format t "],\"snapshots\":[")
        (loop for s in snaps
              for firstp = t then nil do
                (unless firstp (format t ","))
                (json-encode s))
        (format t "],\"console\":[")
        (loop for c in conss
              for firstp = t then nil do
                (unless firstp (format t ","))
                (json-encode (if c (format nil "~A" c) "")))
        (format t "]}")
        (format t "~%")))))

(run-demo)
