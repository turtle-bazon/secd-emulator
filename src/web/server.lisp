;;;; server.lisp — SECD emulator: echo template base
;;;; Step 1: prove WS dispatch works
;;;; Step 2: add devices reply
;;;; Step 3: add VM

(ql:quickload '(:clack :clack-handler-wookie :websocket-driver
                :com.inuoe.jzon :babel :cl-base64) :silent t)

(defpackage #:secd-emulator.web
  (:use #:cl)
  (:local-nicknames (#:jzon #:com.inuoe.jzon)))

(in-package #:secd-emulator.web)

(defvar *acceptor* nil)
(defvar *device-cache* nil)
(defvar *ws* nil)

(defvar *device-catalog-json*
  "[{\"name\":\"blue-pill\",\"board\":\"Blue Pill\",\"chip\":\"stm32f103\"}]")

(defun load-device-catalog ()
  (coerce (jzon:parse *device-catalog-json*) 'list))

;;; ---- STEP 1: just echo + hello (prove dispatch works) ----

(defun make-app ()
  (lambda (env)
    (format *error-output* "~%APP-CALLED path=~S~%" (getf env :path-info))
    (if (equal (getf env :path-info) "/socket")
        ;; --- WebSocket branch ---
        (let ((ws (make-server env)))
          (setf *ws* ws)
          (on :open ws
              (lambda ()
                (format *error-output* "~%WS OPEN~%")
                (send-text ws "{\"type\":\"hello\"}")))
          (on :message ws
              (lambda (raw)
                (format *error-output* "~%WS MSG: ~S~%" raw)
                ;; Echo back — proves bidirectional works
                (send-text ws raw)))
          (on :close ws
              (lambda (&rest args)
                (declare (ignore args))))
          (lambda (responder)
            (declare (ignore responder))
            (format *error-output* "~%WS RESPONDER~%")
            (start-connection ws))))
        ;; --- HTTP branch ---
        '(200 (:content-type "text/html; charset=utf-8")
          ("<html><body><h1>SECD Emulator</h1>
<p>WS: ws://host:8899/socket</p>
<script>
let ws = new WebSocket('ws://' + location.host + '/socket');
ws.onopen = () => { ws.send('{\"cmd\":\"devices\"}'); };
ws.onmessage = e => document.body.innerHTML += '<pre>' + e.data + '</pre>';
</script></body></html>"))))

;;; ---- entry ----

(defun start-server ()
  (setf *device-cache* (load-device-catalog))
  (format t "~&Devices: ~{~A~^, ~}~%"
          (mapcar (lambda (b) (gethash "name" b)) *device-cache*))
  (setf *acceptor*
        (clack:clackup (make-app)
                       :server :wookie
                       :address "0.0.0.0"
                       :port 8899
                       :use-thread nil
                       :debug nil))
  (format t "~&Listening on 0.0.0.0:8899~%"))

(defun main ()
  (start-server))

