#!/usr/bin/env bash
# NO-OP for the shared stillpoint Supabase stack.
#
# The shared stack is ALWAYS-ON: started once (see pre-up.sh) and shared
# across every project on this machine. An individual `drone down` must
# NEVER stop it — doing so would take down Postgres/Auth/Storage for every
# other project still using the shared stack. This is the documented
# external-infra-persists leniency (same pattern as the per-project
# --supabase model's volume persistence, taken one step further: the whole
# stack, not just its volumes, outlives this drone's lifecycle).
#
# To stop the shared stack, do it explicitly and deliberately from the
# stillpoint repo: `cd ~/dev/stillpoint && supabase stop`. This hook will
# never do that for you.

set -euo pipefail

echo "▸ Shared stillpoint Supabase stack persists across drone down — no-op" >&2
exit 0
