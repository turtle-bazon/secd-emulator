;;;; server.lisp — minimal SECD emulator WS server
(in-package #:secd-emulator.web)

(defvar *acceptor* nil)
(defvar *device-cache* nil)
(defvar *ws* nil)

(defun load-device-catalog ()
  (coerce (yason:parse *device-catalog-json*) 'list))

(defun handle-ws-message (raw)
  (let* ((msg (yason:parse raw))
         (cmd (and (hash-table-p msg) (gethash "cmd" msg))))
    (when (string= cmd "devices")
      (let ((devs
              (with-output-to-string (s)
                (write-char #\[ s)
                (loop for b in *device-cache*
                      for i from 0
                      do (unless (zerop i) (write-char #\, s))
                         (format s "{\"name\":\"~A\",\"board\":\"~A\",\"chip\":\"~A\"}"
                                 (gethash "name" b)
                                 (gethash "board" b)
                                 (gethash "chip" b)))
                (write-char #\] s))))
        (send-text *ws*
          (format nil "{\"type\":\"devices\",\"list\":~A}" devs))))))

(defun make-app ()
  (lambda (env)
    (if (equal (getf env :path-info) "/socket")
        (let ((ws (make-server env)))
          (setf *ws* ws)
          (on :open ws
              (lambda ()
                (send-text ws "{\"type\":\"hello\"}")))
          (on :message ws
              (lambda (raw)
                (handle-ws-message raw)))
          (on :close ws
              (lambda (&rest args) (declare (ignore args))))
          (lambda (responder)
            (declare (ignore responder))
            (start-connection ws)))
        (list 200 '(:content-type "text/html; charset=utf-8")
              (list *asset-index-html*)))))

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
                       :debug nil)))

(defun main ()
  (start-server))
