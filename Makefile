# secd-emulator Makefile
LISP ?= sbcl

.PHONY: all build frontend snapshots web test clean

all: build

# Compile the Reagent frontend into www/js/main.js (needed for a useful UI;
# index.html itself is always embedded).
frontend:
	cd frontend && npm install && npx shadow-cljs release app

# Generate snapshots.json by running the real SECD VM on a hand-assembled
# demo program (5+3, 10-4, 7*2, CONS 1 2, four PRNs, STOP). Output is the
# raw JSON the web UI consumes for its offline/demo mode.
snapshots:
	@sbcl --no-sysinit --no-userinit --non-interactive --load snapshot.lisp \
	  | sed -n '/^{/,/^}$$/p' > snapshots.json

# Rebuild www/index.html from the template with snapshots.json inlined.
# Depends on snapshots so a single `make web` produces a self-contained UI.
web: snapshots
	node build-ui.js

# Standalone binary: assets + device catalog are baked in at compile time.
build:
	@touch src/web/assets.lisp   # re-capture embedded www/* + catalog snapshot
	$(LISP) --non-interactive --load build.lisp

# Dev: run the dev server. Mirrors focus's `make dev` which runs
# `build/focus`. Here the binary is `build/secd-emulator`; if it exists
# we exec it, otherwise we start via SBCL (no rebuild) for fast iteration.
# Foreground: Ctrl-C kills the server cleanly.
dev:
	@if [ -x build/secd-emulator ]; then \
	  exec build/secd-emulator; \
	else \
	  exec $(LISP) --non-interactive --load dev.lisp; \
	fi

clean:
	rm -rf build frontend/node_modules www/js .shadow-cljs snapshots.json
