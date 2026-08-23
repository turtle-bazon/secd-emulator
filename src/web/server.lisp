;;;; server.lisp — Clack/Wookie app: static UI + WebSocket emulator protocol
(in-package #:secd-emulator.web)

(defvar *sessions* (make-hash-table :test 'equal)) ; ws -> session plist
(defvar *device-cache* nil)
(defun find-repo-root ()
  "Walk up from the system source dir until a sibling 'secd-machine/'
directory exists; returns that sibling's parent (repo root). Never
produces '..' components — this box's TRUENAME rejects them."
  (let ((dir (asdf:system-source-directory :secd-emulator)))
    (loop for i from 0 below 8
          for cand = dir then (uiop:pathname-parent-directory-pathname cand)
          for parent = (uiop:pathname-parent-directory-pathname cand)
          for tgt = (merge-pathnames "secd-machine/targets/" parent)
          when (uiop:directory-exists-p tgt)
            return (uiop:ensure-directory-pathname
                    (or (ignore-errors (truename parent)) parent))
          finally (return (uiop:ensure-directory-pathname (uiop:getcwd))))))

(defparameter *base-dir* (find-repo-root))

(defun simplify-path (p)
  "Lexically remove '..' components (this box's TRUENAME rejects them)."
  (let* ((path (uiop:ensure-directory-pathname p))
         (parts (append (pathname-directory path) '(:back)))
         (stack '()))
    (dolist (x parts)
      (cond ((eq x :absolute) (push :absolute stack))
            ((eq x :back) (when (and stack (not (eq (first stack) :absolute)))
                            (pop stack)))
            ((member x '(:relative :wild-inferiors)) nil)
            (t (push x stack))))
    (make-pathname :directory (nreverse stack)
                   :name (pathname-name path) :type (pathname-type path))))

(defun resolve-dir (p)
  (let ((clean (simplify-path p)))
    (uiop:ensure-directory-pathname
     (or (ignore-errors (truename clean)) clean))))

(defparameter *targets-dir*
  (resolve-dir (merge-pathnames "../secd-machine/targets/" *base-dir*)))
(defparameter *www-dir*
  (resolve-dir (merge-pathnames "www/" *base-dir*)))

;;; ------------------------- device catalog --------------------------------
(defparameter *targets-override* nil
  "Set via SECD_TARGETS_DIR env or --targets; when set, the catalog is
loaded live from this directory instead of the embedded snapshot.")

(defun load-catalog-from-dir (dir)
  (let ((chips (make-hash-table :test 'equal))
        (boards nil))
    (dolist (f (uiop:directory-files (merge-pathnames "chips/" dir) #P"*.json"))
      (let ((d (yason:parse (uiop:read-file-string f))))
        (setf (gethash (gethash "chip" d) chips) d)))
    (dolist (f (uiop:directory-files (merge-pathnames "boards/" dir) #P"*.json"))
      (push (yason:parse (uiop:read-file-string f)) boards))
    (when boards
      (loop for b in (nreverse boards)
            for base = (gethash (gethash "chip" b) chips)
            when base
              collect (progn
                        (maphash (lambda (k v)
                                   (unless (gethash k b) (setf (gethash k b) v)))
                                 base)
                        b)))))

(defun parse-json-text (text)
  (yason:parse text))

(defun embedded-catalog ()
  (let ((chips (make-hash-table :test 'equal))
        (boards nil))
    (dolist (pair *embedded-chips*)
      (let ((d (parse-json-text (cdr pair))))
        (setf (gethash (gethash "chip" d) chips) d
              (gethash "name" d) (car pair))))
    (dolist (pair *embedded-boards*)
      (let ((d (parse-json-text (cdr pair))))
        (setf (gethash "name" d) (car pair))
        (push d boards)))
    (when boards
      (loop for b in (nreverse boards)
            for base = (gethash (gethash "chip" b) chips)
            when base
              collect (progn
                        (maphash (lambda (k v)
                                   (unless (gethash k b) (setf (gethash k b) v)))
                                 base)
                        b)))))

(defun load-device-catalog ()
  "Embedded snapshot by default. Explicit SECD_TARGETS_DIR / --targets
switches to a live directory (an installed or separate secd-machine)."
  (let* ((env (uiop:getenv "SECD_TARGETS_DIR"))
         (dir (or *targets-override*
                  (and env (uiop:ensure-directory-pathname env)))))
    (if dir
        (or (load-catalog-from-dir dir)
            (progn
              (format *error-output*
                      "~%; warning: no boards found under ~A; using embedded catalog~%"
                      dir)
              (embedded-catalog)))
        (embedded-catalog))))

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
  (labels ((jstr (msg key)
             (if (hash-table-p msg)
                 (gethash key msg)
                 (cdr (assoc key msg :test #'string=)))))
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
         (flet ((serve (content ctype)
                  `(200 (:content-type ,ctype) (,content))))
           (cond
             ((member path '("/" "/index.html") :test #'equal)
              (serve *asset-index-html* "text/html; charset=utf-8"))
             ((equal path "/js/main.js")
              (serve *asset-js-main* "application/javascript"))
             (t '(404 (:content-type "text/plain") ("not found"))))))))))

;;; ------------------------------ entry -------------------------------------
(defvar *acceptor* nil)

(defun %run (&key (port 8899) (address "127.0.0.1"))
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

(defun make-options ()
  (list
   (clingon:make-option :integer
                        :short-name #\p
                        :long-name "port"
                        :description "TCP port to listen on;"
                        :initial-value 8899
                        :key :port)
   (clingon:make-option :string
                        :short-name #\a
                        :long-name "address"
                        :description "Address to bind;"
                        :initial-value "127.0.0.1"
                        :key :address)
   (clingon:make-option :string
                        :long-name "targets"
                        :description "Device catalog directory (overrides embedded);"
                        :key :targets)))

(defun main-handler (cmd)
  (handler-case
      (let ((port (clingon:getopt cmd :port))
            (address (clingon:getopt cmd :address))
            (targets (clingon:getopt cmd :targets)))
        (when targets
          (setf *targets-override*
                (uiop:ensure-directory-pathname targets)))
        (%run :port port :address address))
    (error (e)
      (format *error-output* "~A~%" e)
      (clingon:exit 255))))

(defun make-command ()
  (clingon:make-command
   :name "secd-emulator"
   :description "SECD machine emulator web server (WebSocket protocol)."
   :version (asdf:component-version (asdf:find-system :secd-emulator))
   :options (make-options)
   :handler #'main-handler))

(defun main ()
  (if (null (uiop:command-line-arguments))
      (progn
        (format t "Usage: secd-emulator [--port N] [--address ADDR]
          [--targets DIR]~%Try --help.~%")
        (clingon:exit 0))
      (clingon:run (make-command))))
