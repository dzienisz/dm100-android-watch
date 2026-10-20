#!/bin/bash
set -e
cd "$(dirname "$0")/.."
sudo tools/venv/bin/python tools/mtkclient/mtk.py "w" boot backup/magisk/boot_magisk_patched.img --preloader backup/brom-dumps/preloader_dm100.bin
