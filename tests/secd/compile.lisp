(let ((code (make-array '(0) :element-type '(unsigned-byte 8) :fill-pointer 0 :adjustable t)))
  (defun emit (b) (vector-push-extend b code 16))
  (defun emit-word (v) (emit (ldb (byte 8 8) (logand v #xFFFF))) (emit (ldb (byte 8 0) (logand v #xFFFF))))
  (defun compile-instr (f)
    (cond ((integerp f) (emit f))
          ((symbolp f)
           (case f
             (ADD (emit 16)) (SUB (emit 17)) (MUL (emit 18)) (DIV (emit 19)) (MOD (emit 20)) (NEG (emit 21))
             (EQ (emit 32)) (LT (emit 33)) (GT (emit 34))
             (CAR (emit 48)) (CDR (emit 49)) (CONS (emit 50))
             (PRN (emit 120)) (STOP (emit 0)) (DUP (emit 64))
             (otherwise (error "Unknown instr: ~A" f))))
          ((and (consp f) (symbolp (car f)))
           (let ((op (car f))
                 (args (cdr f)))
             (case op
               (LDC (emit 2) (emit-word (car args)))
               (DUP (emit 64) (emit-word (car args))))))
          (t (error "Unknown instr: ~A" f))))
  (defun compile-program (forms)
    (setf (fill-pointer code) 0)
    (dolist (f forms) (compile-instr f))
    (let ((out (make-array (length code) :element-type '(unsigned-byte 8))))
      (replace out code)
      out))

  ;; Build .secd unit: 14-byte header + code
  ;; Bytes 0-3: "SECD" (83 69 67 68)
  ;; Bytes 4-7: reserved
  ;; Bytes 8-9: cs (code size, lo-hi)
  ;; Bytes 10-11: cn (const size)
  ;; Bytes 12-13: reserved
  ;; Then code
  (defun make-secd-unit (prog)
    (let* ((clen (length prog))
           (header #(83 69 67 68 0 0 0 0 0 0 0 0 0 0))
           (buf (make-array (+ 14 clen) :element-type '(unsigned-byte 8))))
      (replace buf header)
      (setf (aref buf 8) (ldb (byte 8 8) clen)
            (aref buf 9) (ldb (byte 8 0) clen))
      (replace buf prog :start1 14)
      buf))

  (defun write-prog (name forms)
    (let* ((prog (compile-program forms))
           (unit (make-secd-unit prog)))
      (format t "~A unit-len=~A total-bytes=~A~%" name (length prog) (length unit))
      (with-open-file (s (merge-pathnames name "/tmp/test-prog/")
                          :direction :output
                          :element-type '(unsigned-byte 8)
                          :if-exists :supersede)
        (write-sequence unit s))))

  (write-prog "prog1.secd"
              '((LDC 5) (LDC 3) ADD PRN
                (LDC 10) (LDC 4) SUB PRN
                (LDC 8) (LDC 6) MUL PRN
                STOP))
  (write-prog "prog2.secd"
              '((LDC 1) (LDC 2) CONS
                DUP CAR PRN
                CDR PRN
                STOP))
  (write-prog "prog3.secd"
              '((LDC 7) (LDC 3) DIV PRN
                (LDC 10) (LDC 3) MOD PRN
                STOP))
  (write-prog "prog4.secd"
              '((LDC 5) (LDC 3) EQ PRN
                (LDC 5) (LDC 3) LT PRN
                (LDC 3) (LDC 5) GT PRN
                STOP))
  (sb-ext:exit))
