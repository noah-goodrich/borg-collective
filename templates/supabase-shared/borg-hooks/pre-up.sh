#!/usr/bin/env bash
# Ensure the ALWAYS-ON shared stillpoint Supabase stack is up before the
# drone comes up, so the external network `supabase_network_stillpoint`
# exists when compose tries to attach to it.
#
# Runs on the HOST — drone.zsh invokes this hook from `drone up` before
# calling `docker compose up -d`. Do NOT try to run this from inside the
# drone; it needs direct access to the host Docker daemon.
#
# Unlike the per-project --supabase model, this hook NEVER runs a
# per-project `supabase start`/`supabase init`. The shared stack lives in
# the stillpoint repo and is shared across every project on this machine —
# it is started ONCE (idempotent no-op if already running) and never
# stopped by an individual drone's lifecycle. See post-down.sh.

set -euo pipefail

SHARED_DB_CONTAINER="supabase_db_stillpoint"
STILLPOINT_DIR="${BORG_STILLPOINT_SUPABASE_DIR:-$HOME/dev/stillpoint}"

if ! command -v docker >/dev/null 2>&1; then
    echo "✗ docker not found on PATH" >&2
    exit 1
fi

running="$(docker inspect -f '{{.State.Running}}' "$SHARED_DB_CONTAINER" 2>/dev/null || true)"

if [[ "$running" == "true" ]]; then
    echo "▸ Shared stillpoint Supabase stack already running — no-op" >&2
    exit 0
fi

echo "▸ Shared stillpoint Supabase stack is not running — starting it once..." >&2

if ! command -v supabase >/dev/null 2>&1; then
    echo "✗ supabase CLI not found on PATH" >&2
    echo "  Install: brew install supabase/tap/supabase" >&2
    exit 1
fi

if [[ ! -d "$STILLPOINT_DIR/supabase" ]]; then
    echo "✗ Shared supabase config not found at $STILLPOINT_DIR/supabase" >&2
    echo "  Set BORG_STILLPOINT_SUPABASE_DIR to override the stillpoint repo location." >&2
    exit 1
fi

(cd "$STILLPOINT_DIR" && supabase start)
