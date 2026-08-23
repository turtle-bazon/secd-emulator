;;;; secd-emulator.asd — SECD machine emulator: VM + websocket web server
(defsystem "secd-emulator"
  :version "0.1.0"
  :author "turtle-bazon"
  :license "GPL3"
  :depends-on ("clack" "websocket-driver" "clack-handler-wookie" "yason" "bordeaux-threads" "clingon" "babel" "cl-base64"
               "flexi-streams" "uiop")
  :components
  ((:module "src/vm"
    :components ((:file "package")
                 (:file "values" :depends-on ("package"))
                 (:file "machine" :depends-on ("values"))
                 (:file "primitives" :depends-on ("machine"))))
   (:module "src/web"
    :depends-on ("src/vm")
    :components ((:file "package")
                 (:file "assets" :depends-on ("package"))
                 (:file "device-catalog" :depends-on ("package"))
                 (:file "server" :depends-on ("package" "assets"))))))

(defsystem "secd-emulator/executable"
  :build-operation "program-op"
  :build-pathname "build/secd-emulator"
  :entry-point "secd-emulator.web::main"
  :depends-on ("secd-emulator"))
