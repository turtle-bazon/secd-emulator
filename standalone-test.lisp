;;;; standalone-test.lisp — run directly: sbcl --load standalone-test.lisp
;;;; Minimal HTTP API test, no project packages needed.

(ql:quickload '(:clack :clack-handler-wookie) :silent t)

(defpackage #:secd-standalone
  (:use #:cl))

(in-package #:secd-standalone)

(defvar *devices*
  '("blue-pill" "stamp-s3a" "black-pill-f401"
    "esp32c3-supermini" "esp32s3-devkit" "lolin-s3-mini"
    "lolin-s2-mini" "rp2040-pico" "rp2040-zero"
    "rp2350-zero" "rp2350-beetle" "seeed-xiao-samd21"))

(defun app ()
  (lambda (env)
    (let ((method (getf env :request-method))
          (path (getf env :path-info)))
      (cond
        ((and (eq method :get)
              (string= path "/api/devices"))
         (let ((json
                 (with-output-to-string (s)
                   (write-char #\[ s)
                   (loop for d in *devices*
                         for i from 1
                         do (unless (= i 1) (write-char #\, s))
                            (format s "{\"name\":\"~A\"}" d))
                   (write-char #\] s))))
           (list 200 (list :content-type "application/json")
                 (list json))))
        ((and (eq method :get)
              (member path '("/" "/index.html") :test #'string=))
         (list 200 (list :content-type "text/html; charset=utf-8")
               (list "<html><body><h1>SECD Emulator</h1><button onclick=\"fetch('/api/devices').then(r=>r.text()).then(t=>document.body.innerHTML+='<pre>'+t+'</pre>')\">Load Devices</button><pre id='out'></pre></body></html>")))
        (t
         (list 404 nil '("not found")))))))

(format t "~&Starting on 0.0.0.0:8899...~%")
(clack:clackup (app)
               :server :wookie
               :address "0.0.0.0"
               :port 8899
               :use-thread nil
               :debug nil)
