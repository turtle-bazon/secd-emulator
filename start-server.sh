#!/bin/bash
cd /home/turtle/scm-controlled/common-lisp/secd-emulator
exec ./build/secd-emulator --port 8899 --address 0.0.0.0
