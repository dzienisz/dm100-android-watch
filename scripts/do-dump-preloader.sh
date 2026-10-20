#!/bin/bash
# Read-only: asks the chip for its own preloader (needed so later steps can set up the watch's RAM).
# Run it, THEN plug in the fully powered-off watch with no buttons held. Needs sudo on macOS
# (macOS reserves the watch's HID-class USB interface; without sudo you get "Access denied").
set -e
cd "$(dirname "$0")/.."
mkdir -p backup/brom-dumps
sudo tools/venv/bin/python tools/mtkclient/mtk.py dumppreloader --filename backup/brom-dumps/preloader_dm100.bin
