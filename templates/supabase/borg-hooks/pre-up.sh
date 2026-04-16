#!/usr/bin/env bash
# Start the Supabase local stack before the drone comes up, so the external
# network `supabase_network_<project>` exists when compose tries to attach to it.
#
# Runs on the HOST — drone.zsh invokes this hook from `drone up` before calling
# `docker compose up -d`. Do NOT try to run this from inside the drone; it needs
# direct access to the host Docker daemon.
#
# Entry point: this hook is the *only* supported way to bring the stack up.
# Running `docker compose up` directly will fail because the external network
# doesn't exist yet.

set -euo pipefail

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$project_root"

if ! command -v supabase >/dev/null 2>&1; then
    echo "✗ supabase CLI not found on PATH" >&2
    echo "  Install: brew install supabase/tap/supabase" >&2
    exit 1
fi

# Idempotent: if already running, `supabase start` is a ~2s no-op that
# just prints the status block. Safe to call on every `drone up`.
supabase start
