;;;; assets.lisp — static assets + device catalog embedded into the image.
;;;;
;;;; IMPORTANT: every value is computed by a FULLY SELF-CONTAINED #. reader
;;;; form (read-time evaluation cannot see defuns from this file). The
;;;; binary therefore ships without external files. A live catalog override
;;;; still exists via SECD_TARGETS_DIR / --targets (see server.lisp).

(in-package #:secd-emulator.web)

(defparameter *asset-index-html*
  '#.(or (ignore-errors
          (uiop:read-file-string
           (uiop:merge-pathnames* "../../www/index.html"
                                  *compile-file-truename*)))
       "<html><body><h1>SECD Emulator</h1><p>Frontend not built. Run:
cd frontend && npm install && npx shadow-cljs release app</p></body></html>"))

(defparameter *asset-js-main*
  '#.(or (ignore-errors
          (uiop:read-file-string
           (uiop:merge-pathnames* "../../www/js/main.js"
                                  *compile-file-truename*)))
       "console.error('frontend js not built');"))

(defparameter *embedded-chips*
  '#.(let ((base (uiop:pathname-parent-directory-pathname   ; <common-lisp>/
                  (uiop:pathname-parent-directory-pathname  ; <repo>/
                   (uiop:pathname-parent-directory-pathname ; src/web/
                    *compile-file-truename*)))))
       (loop for f in (sort (directory (merge-pathnames
                                        "secd-machine/targets/chips/*.json"
                                        base))
                            #'string< :key #'namestring)
             collect (cons (pathname-name f)
                           (uiop:read-file-string f))))
  "alist: chip-name -> JSON text (captured at build time)")

(defparameter *embedded-boards*
  '#.(let ((base (uiop:pathname-parent-directory-pathname
                  (uiop:pathname-parent-directory-pathname
                   (uiop:pathname-parent-directory-pathname
                    *compile-file-truename*)))))
       (loop for f in (sort (directory (merge-pathnames
                                        "secd-machine/targets/boards/*.json"
                                        base))
                            #'string< :key #'namestring)
             collect (cons (pathname-name f)
                           (uiop:read-file-string f))))
  "alist: board-name -> JSON text (captured at build time)")
