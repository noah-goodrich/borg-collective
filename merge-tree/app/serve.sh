#!/usr/bin/env bash
# Serve the hub story-lens app. Reads BORG_MERGE_TREE_DIR (default ~/.local/state/borg/merge-tree)
# at runtime -- employer data never lives in this repo, never gets committed. Binds 127.0.0.1:8877.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BORG_MERGE_TREE_DIR="${BORG_MERGE_TREE_DIR:-$HOME/.local/state/borg/merge-tree}"

if [ -x "$APP_DIR/.venv/bin/uvicorn" ]; then
    exec "$APP_DIR/.venv/bin/uvicorn" --app-dir "$APP_DIR" app:app --host 127.0.0.1 --port 8877
else
    exec python3 -m uvicorn --app-dir "$APP_DIR" app:app --host 127.0.0.1 --port 8877
fi
