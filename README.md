# secd-emulator

Web-based emulator for the SECD Machine (see ../secd-machine/doc/specification.md).

- **Backend**: Common Lisp. Wookie (via Clack) serves the UI and a WebSocket
  endpoint `/socket`; `websocket-driver` handles the WS framing. A faithful
  CL implementation of the VM (`src/vm/`) executes `.secd` bytecode compiled
  by `secd-lisp`.
- **Frontend**: ClojureScript + Reagent (scaffolded under `frontend/`, built
  with shadow-cljs; a dependency-free JS client lives in `www/index.html`
  meanwhile).

## Run

    sbcl --load run-server.lisp          # quickload + start on 127.0.0.1:8899

Open http://127.0.0.1:8899 — pick a device, load a `.secd` file, Run.
Console output streams back over the WebSocket; GPIO/I²C/UART HAL calls
surface as events.

## Protocol (JSON)

Client → server: `{cmd: devices|select|load|run|step|reset|console-in, ...}`
Server → client: `{type: hello|devices|selected|loaded|console|hal|halted|reset|error}`

## Status

- VM core: full ISA incl. LDCW/BIGNUM wide integers; host-tested against
  compiler output (hello/factorial).
- Primitives: universal core + %bn-* + GPIO/UART/I²C sims (event-emitting);
  USB/HID stubbed.
