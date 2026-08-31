#!/usr/bin/env python3
"""Wrap raw secd-lisp bytecode in our emulator's .secd format.
secd-lisp emits raw code bytes (what the C firmware expects). Our
emulator expects a 14-byte SECD header + code + 2-byte 0xB1C5 trailer.
Usage: wrap-secd.py <input.secd> <output.secd>
"""
import sys, struct

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: wrap-secd.py <in.secd> <out.secd>")
    with open(sys.argv[1], "rb") as f:
        code = f.read()
    cs = len(code)
    hdr = bytearray(14)
    hdr[0:4] = b"SECD"
    hdr[4] = 1
    hdr[8:10] = struct.pack(">H", cs)
    with open(sys.argv[2], "wb") as f:
        f.write(bytes(hdr))
        f.write(code)
        f.write(b"\xC5\xB1")
    print(f"wrapped {sys.argv[1]} ({cs}B) -> {sys.argv[2]}")
