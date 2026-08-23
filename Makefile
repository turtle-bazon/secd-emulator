# secd-emulator Makefile
LISP ?= sbcl

.PHONY: all build frontend test clean

all: build

# Compile the Reagent frontend into www/js/main.js (needed for a useful UI;
# index.html itself is always embedded).
frontend:
	cd frontend && npm install && npx shadow-cljs release app

# Standalone binary: assets + device catalog are baked in at compile time.
build:
	$(LISP) --non-interactive --load build.lisp

clean:
	rm -rf build frontend/node_modules www/js .shadow-cljs
