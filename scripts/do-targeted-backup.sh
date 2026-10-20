#!/bin/bash
set -e
cd "$(dirname "$0")/.."
PARTS="nvram,nvdata,proinfo,seccfg,boot,recovery,lk,lk2,para,nvcfg,frp,protect1,protect2"
FILES="backup/brom-dumps/nvram.bin,backup/brom-dumps/nvdata.bin,backup/brom-dumps/proinfo.bin,backup/brom-dumps/seccfg.bin,backup/brom-dumps/boot.bin,backup/brom-dumps/recovery.bin,backup/brom-dumps/lk.bin,backup/brom-dumps/lk2.bin,backup/brom-dumps/para.bin,backup/brom-dumps/nvcfg.bin,backup/brom-dumps/frp.bin,backup/brom-dumps/protect1.bin,backup/brom-dumps/protect2.bin"
sudo tools/venv/bin/python tools/mtkclient/mtk.py "r" "$PARTS" "$FILES" --preloader backup/brom-dumps/preloader_dm100.bin
