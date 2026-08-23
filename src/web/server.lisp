;;;; server.lisp — Clack/Wookie app: static UI + WebSocket emulator protocol
(in-package #:secd-emulator.web)

(defvar *sessions* (make-hash-table :test 'equal)) ; ws -> session plist
(defvar *device-cache* nil)
(defun find-repo-root ()
  "Walk up from the system source dir until a sibling 'secd-machine/' exists."
  (let ((dir (asdf:system-source-directory :secd-emulator)))
    (loop for i from 0 below 6
          for candidate = dir then (uiop:pathname-parent-directory-pathname candidate)
          when (uiop:directory-exists-p
                (merge-pathnames "../secd-machine/targets/" candidate))
            return (uiop:ensure-directory-pathname candidate)
          finally (return (uiop:getcwd)))))

(defparameter *base-dir* (find-repo-root))

(defun resolve-dir (p)
  "Truename-resolve so no '..' components survive."
  (uiop:ensure-directory-pathname
   (or (ignore-errors (truename p)) p)))

(defparameter *targets-dir*
  (resolve-dir (merge-pathnames "../secd-machine/targets/" *base-dir*)))
(defparameter *www-dir*
  (resolve-dir (merge-pathnames "www/" *base-dir*)))

;;; ------------------------- device catalog --------------------------------
(defun load-device-catalog ()
  "Merge chips/*.json under boards/*.json exactly like write-target-metadata."
  (let ((chips (make-hash-table :test 'equal))
        (boards '()))
    (dolist (f (uiop:directory-files (merge-pathnames "chips/" *targets-dir*) "*.json"))
      (let ((d (yason:parse (uiop:read-file-string f))))
        (setf (gethash (gethash "chip" d) chips) d)))
    (dolist (f (uiop:directory-files (merge-pathnames "boards/" *targets-dir*) "*.json"))
      (push (yason:parse (uiop:read-file-string f)) boards))
    (setf *device-cache*
          (loop for b in (nreverse boards)
                for base = (gethash (gethash "chip" b) chips)
                when base
                  collect (progn
                            ;; chip defaults underneath, board overrides on top
                            (maphash (lambda (k v)
                                       (unless (gethash k b)
                                         (setf (gethash k b) v)))
                                     base)
                            b)))))

(defun device-summary (b)
  `(("name" . ,(gethash "name" b))
    ("board" . ,(gethash "board" b))
    ("chip"  . ,(gethash "chip" b))
    ("description" . ,(gethash "description" b))))

;;; ------------------------------ sessions ---------------------------------
(defun write-json-alist (stream obj)
  "Encode an association list as a JSON object. Nested alists become
nested objects, proper lists become arrays."
  (labels ((write-value (v)
             (typecase v
               (cons
                (if (consp (car v))
                    (write-json-alist stream v)
                    (progn
                      (yason:with-array ()
                        (dolist (x v)
                          (if (and (consp x) (consp (car x)))
                              (write-json-alist stream x)
                              (yason:encode x stream)))))))
               (t (yason:encode v stream)))))
    (yason:with-output (stream)
      (yason:with-object ()
        (dolist (pair obj)
          (yason:encode-object-element (car pair) nil)
          ;; encode-object-element writes key + ':'? it writes key then
          ;; delegates value encoding; use manual approach below instead.
          )))))

(defun alist-json (obj)
  (with-output-to-string (s)
    (write-char #\{ s)
    (let ((first t))
      (labels ((enc-val (v)
                 (cond ((and (consp v) (consp (car v)))
                        (write-string (alist-json v) s))
                       ((consp v)
                        (write-char #\[ s)
                        (let ((f2 t))
                          (dolist (x v)
                            (unless f2 (write-char #\, s))
                            (setf f2 nil)
                            (enc-val x)))
                        (write-char #\] s))
                       ((integerp v) (format s "~D" v))
                       ((stringp v) (yason:encode v s)) ; quoted string
                       (t (yason:encode v s)))))
        (dolist (pair obj)
          (unless first (write-char #\, s))
          (setf first nil)
          (yason:encode (car pair) s)   ; key as JSON string
          (write-char #\: s)
          (enc-val (cdr pair)))))
    (write-char #\} s)))
 
(defun ws-send (session obj)
  (let ((ws (getf session :ws)))
    (when (and ws (eq (websocket-driver:ready-state ws) :open))
      (websocket-driver:send-text ws (alist-json obj)))))

;;; --------------------------- protocol dispatch ----------------------------
(defun handle-message (session raw)
  (labels ((jstr (msg key) (cdr (assoc key msg :test #'string=))))
    (let* ((msg (yason:parse raw))
           (cmd (jstr msg "cmd"))
           (vm  (getf session :vm)))
      (case (intern (string-upcase cmd) :keyword)
        (:devices
         (ws-send session `(("type" . "devices")
                            ("list" . ,(mapcar #'device-summary *device-cache*)))))
        (:select (select-device! session (jstr msg "name")))
        (:load
         (when vm
           (let ((bytes (cl-base64:base64-string-to-usb8-array
                         (jstr msg "bytecode-b64"))))
             (ws-send session `(("type" . "loaded")
                                ("result" . ,(string (vm:load-bytecode vm bytes))))))))
        (:run
         (when vm
           (bt:make-thread
            (lambda ()
              (loop until (vm:halted-p vm) do (vm:step-once vm))
              (ws-send session `(("type" . "halted")
                                 ("steps" . ,(vm:machine-steps vm))
                                 ("error" . ,(vm:machine-error-code vm))))))))
        (:step
         (when vm
           (dotimes (i (max 1 (or (ignore-errors (floor (parse-integer (jstr msg "n"))) 1))))
             (unless (vm:halted-p vm) (vm:step-once vm)))))
        (:reset
         (when vm (vm:reset-machine vm))
         (ws-send session '(("type" . "reset"))))
        (:console-in
         (when vm
           (loop for ch across (jstr msg "text")
                 do (vm:machine-console-in-push vm (char-code ch)))))))))

;;; ------------------------------ clack app ---------------------------------
(defun make-app ()
  (lambda (env)
    (cond
      ((equal (getf env :path-info) "/socket")
       (let ((ws (websocket-driver:make-server env))
             (session (list :ws nil :id (format nil "~A" (getf env :request-uri)))))
         (websocket-driver:on
          :open ws
          (lambda ()
            (setf (getf session :ws) ws)
            (setf (gethash ws *sessions*) session)
            (ws-send session '(("type" . "hello")))))
         (websocket-driver:on
          :message ws
          (lambda (raw)
            (ignore-errors (handle-message session raw))))
         (websocket-driver:on
          :close ws
          (lambda (&rest _) (declare (ignore _)) (remhash ws *sessions*)))
         (lambda (responder)
           (declare (ignore responder))
           (websocket-driver:start-connection ws))))
      (t
       (let ((path (getf env :path-info)))
         (labels ((read-bin (p)
                    (with-open-file (f p :element-type '(unsigned-byte 8))
                      (let ((b (make-array (file-length f)
                                           :element-type '(unsigned-byte 8))))
                        (read-sequence b f) b)))
                  (serve (p ctype)
                    `(200 (:content-type ,ctype)
                          ,(read-bin p))))
           (cond
             ((member path '("/" "/index.html") :test #'equal)
              (serve (merge-pathnames "index.html" *www-dir*)
                     "text/html; charset=utf-8"))
             ((and (> (length path) 1)
                   (probe-file (merge-pathnames (subseq path 1) *www-dir*)))
              (let ((p (merge-pathnames (subseq path 1) *www-dir*)))
                (serve p
                       (cond ((search ".js" path) "application/javascript")
                             ((search ".css" path) "text/css")
                             (t "application/octet-stream")))))
             (t '(404 (:content-type "text/plain") ("not found"))))))))))

;;; ------------------------------ entry -------------------------------------
(defvar *acceptor* nil)

(defun main (&key (port 8899) (address "127.0.0.1"))
  (load-device-catalog)
  (format t "~&Devices (~A): ~{~A~^, ~}~%"
          *targets-dir*
          (mapcar (lambda (b) (gethash "name" b)) *device-cache*))
  (setf *acceptor*
        (clack:clackup (make-app)
                       :server :wookie
                       :address address
                       :port port
                       :use-thread nil))
  (format t "~&Wookie listening on http://~A:~A (ws://~A:~A/socket)~%"
          address port address port)
  *acceptor*)

(defun start-server (&key (port 8899) (address "127.0.0.1"))
  (bt:make-thread (lambda () (main :port port :address address))))
