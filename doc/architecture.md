# SECD Emulator Architecture

## Overview

The secd-emulator is a Common Lisp application that simulates the SECD machine with MCU constraints. It provides:

- **Emulation engine** — Execute SECD bytecode with constraints
- **nREPL server** — Debug from any Common Lisp REPL
- **WebSocket server** — (planned) For GUI client

## Project Structure

```
secd-emulator/
├── secd-emulator.asd      # System definition
├── LICENSE                 # GPL3
├── src/
│   ├── package.lisp       # Package definitions
│   ├── emulator.lisp      # Core emulation engine
│   ├── memory.lisp        # Memory simulation
│   ├── io.lisp            # I/O simulation (GPIO, UART)
│   ├── debugger.lisp      # Debugger (breakpoints, stepping)
│   ├── nrepl-server.lisp  # nREPL server for self-debugging
│   └── main.lisp          # CLI and entry points
├── tests/
│   ├── package.lisp       # Test package
│   ├── emulator-tests.lisp
│   └── memory-tests.lisp
└── doc/
    └── architecture.md    # This file
```

## Current Implementation

### nREPL Server

The nREPL server allows debugging the emulator from any Common Lisp REPL.

**Starting nREPL:**

```lisp
;; Load the system
(asdf:load-system :secd-emulator)

;; Start emulator with nREPL
(secd-emulator:start :port 7888)

;; Or start nREPL separately
(secd-emulator:start-nrepl 7888)
```

**Connecting from another REPL:**

```lisp
;; Connect to nREPL
(cl-nrepl:connect :port 7888)

;; Now you can call emulator functions
(status)
(show-registers)
(show-memory 0 10)
(reset)
```

**Available functions in nREPL:**

```lisp
(status)           ; Show emulator status
(show-registers)   ; Show SECD registers
(show-memory start end)  ; Show memory contents
(reset)            ; Reset emulator
(run)              ; Run emulator
(step)             ; Single step
(gc)               ; Run garbage collection
```

## Planned Features

### WebSocket Server

Will be added later for GUI client communication.

**Dependencies (to be added):**
- `clack` — HTTP server
- `websocket-driver` — WebSocket support

**API (planned):**

```json
// Connect
{"type": "connect"}

// Step
{"type": "step"}

// Run
{"type": "run", "breakpoints": [100, 200]}

// Get state
{"type": "get-state"}

// Response
{"type": "state", "registers": {...}, "memory": [...]}
```

### GUI Client

Will be developed separately, connecting via WebSocket.

Features (planned):
- Visual register viewer
- Memory inspector
- Breakpoint management
- Step-by-step execution
- Serial console
- GPIO visualization

## Configuration

### Target Platforms

The emulator simulates different MCU targets with their constraints:

**RP2040:**
- Heap: 200KB
- Stack: 16KB
- Symbols: 256
- Features: GPIO, UART, SPI, I2C, ADC, PWM

**ESP32:**
- Heap: 400KB
- Stack: 32KB
- Symbols: 512
- Features: GPIO, UART, WiFi, BLE

### Command Line Options

```
secd-emulator [options] bytecode-file

Options:
  --target <target>    Target platform (rp2040, esp32)
  --heap <size>        Heap size in bytes
  --stack <size>       Stack size in bytes
  --debug              Enable debugger
  --trace              Enable instruction tracing
  --nrepl              Start nREPL server
  --nrepl-port <p>     nREPL port (default: 7888)
  --help               Show this help
```

## Debugging Workflow

### 1. Start emulator with nREPL

```bash
sbcl --load secd-emulator.asd --eval '(asdf:load-system :secd-emulator)' \
     --eval '(secd-emulator:start :port 7888)'
```

### 2. Connect from another REPL

```lisp
(cl-nrepl:connect :port 7888)
```

### 3. Debug

```lisp
;; Load bytecode
(load-bytecode "firmware.secd")

;; Check status
(status)

;; Run
(run)

;; Or step through
(step)
(step)
(step)

;; Check registers
(show-registers)

;; Inspect memory
(show-memory 0 20)
```

### 4. Set breakpoints (when implemented)

```lisp
(breakpoint 100)   ; Set breakpoint at address 100
(breakpoint 200)   ; Set another breakpoint
(run)              ; Run until breakpoint
```

## Future: WebSocket Communication

When WebSocket is added, the GUI will communicate via JSON messages:

```lisp
;; Server will handle these messages:
{"type": "step"}
{"type": "run"}
{"type": "get-registers"}
{"type": "get-memory", "start": 0, "end": 100}
{"type": "set-breakpoint", "address": 100}
{"type": "continue"}
{"type": "stop"}
```

## Testing

Run tests:

```lisp
(asdf:test-system :secd-emulator)
```

Or in REPL:

```lisp
(fiveam:run! :secd-emulator/test)
```
