;;;; Minimal Clack + Wookie + websocket-driver echo server.
;;;;
;;;; Run: CLACK_BACKEND=wookie sbcl --no-sysinit --no-userinit \
;;;;      --non-interactive --load echo.lisp
;;;;
;;;; Or set CLACK_BACKEND=hunchentoot to use Hunchentoot instead.

(load "~/quicklisp/setup.lisp")
(ql:quickload '(:clack :clack-handler-wookie :websocket-driver) :silent t)

(defpackage #:echo (:use #:cl) (:export #:main))
(in-package #:echo)

(defun app (env)
  (cond
    ((string= "/secd" (getf env :request-uri))
     (let ((ws (websocket-driver:make-server env)))
       (websocket-driver:on :message ws
         (lambda (msg) (websocket-driver:send ws (format nil "echo: ~A" msg))))
       (lambda (responder)
         (declare (ignore responder))
         (websocket-driver:start-connection ws))))
    (t '(200 (:content-type "text/html; charset=utf-8")
             ("<html><body><script>
                const ws = new WebSocket('ws://' + location.host + '/secd');
                ws.onmessage = (e) => document.body.appendChild(
                  Object.assign(document.createElement('pre'),
                                {textContent: e.data}));
                const i = document.createElement('input');
                const b = document.createElement('button');
                b.textContent = 'send';
                b.onclick = () => ws.send(i.value);
                document.body.append(i, b);
              </script></body></html>")))))

(defun main (&rest args)
  (declare (ignore args))
  (let ((backend (or (uiop:getenv "CLACK_BACKEND") "wookie")))
    (format t "starting echo on 0.0.0.0:8899 (backend=~A)...~%" backend)
    (clack:clackup #'app
                   :server (intern (string-upcase backend) :keyword)
                   :address "0.0.0.0" :port 8899
                   :use-thread nil :debug nil)))

(main)
