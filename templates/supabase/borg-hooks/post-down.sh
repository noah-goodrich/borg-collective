#!/usr/bin/env bash
# Volumes persist by default — your database state survives a full
# `drone down`/`drone up` cycle. Use `supabase stop --no-backup` from the
# host manually if you want a clean slate.

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"

if ! command -v supabase >/dev/null 2>&1; then
    echo "⚠ supabase CLI not found — nothing to stop" >&2
    exit 0
fi

supabase stop
