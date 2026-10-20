#!/bin/bash
set -e
cd "$(dirname "$0")/.."
sudo tools/venv/bin/python tools/mtkclient/mtk.py da seccfg unlock --preloader backup/brom-dumps/preloader_dm100.bin
