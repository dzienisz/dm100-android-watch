#!/bin/bash
# Run mtkclient from the local venv (tools/ is git-ignored).
# Setup: see docs/04-root-research.md ("Setting up mtkclient on macOS").
# Usage: scripts/mtk.sh printgpt        (read-only: prints the partition table)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/venv/bin/python" "$ROOT/tools/mtkclient/mtk.py" "$@"
