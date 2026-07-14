#!/usr/bin/env bash
# scripts/check-agent-roster.sh — assert the source agent roster matches the plugin distro.
#
# The canonical flow is borg-collective (source) → claude-plugins (distro, read-only copy).
# This guard asserts every agent .md in the source agents/ dir has an identical twin in the
# distro, and vice-versa — so source-side edits and distro-side drift both fail loudly instead
# of the roster silently diverging (the failure mode that filed the source-drift directive).
#
# Exits 0 when the two rosters are identical; exits 1 with a per-file breakdown when they drift.
# Intended as a lightweight drift-guard: run manually, from CI, or from bats tests.
#
# Usage:
#   ./scripts/check-agent-roster.sh
#
# To fix drift, run:
#   ./scripts/sync-plugin.sh        # push source → distro (for source-side edits)
# or copy the distro file back into agents/ (for a distro-authored change), then re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../agents"
DST="${PLUGIN_AGENTS_DIR:-/Users/noah/dev/claude-plugins/borg-collective/agents}"

if [[ ! -d "$SRC" ]]; then
    echo "ERROR: source agents dir not found: $SRC" >&2
    exit 1
fi

if [[ ! -d "$DST" ]]; then
    echo "ERROR: plugin agents dir not found: $DST" >&2
    echo "  Set PLUGIN_AGENTS_DIR to override the default path." >&2
    exit 1
fi

drift=0

# Every source agent must have an identical twin in the distro.
for src_agent in "$SRC"/*.md; do
    [[ -f "$src_agent" ]] || continue
    name="${src_agent##*/}"
    dst_agent="$DST/$name"
    if [[ ! -f "$dst_agent" ]]; then
        echo "DRIFT: $name — in source, missing from distro" >&2
        drift=$((drift + 1))
    elif ! diff -q "$src_agent" "$dst_agent" >/dev/null 2>&1; then
        echo "DRIFT: $name — content differs between source and distro" >&2
        drift=$((drift + 1))
    fi
done

# Every distro agent must exist in the source (catches distro-only agents like the original
# five that filed this directive).
for dst_agent in "$DST"/*.md; do
    [[ -f "$dst_agent" ]] || continue
    name="${dst_agent##*/}"
    if [[ ! -f "$SRC/$name" ]]; then
        echo "DRIFT: $name — in distro, missing from source (source is not canonical)" >&2
        drift=$((drift + 1))
    fi
done

if [[ "$drift" -eq 0 ]]; then
    echo "OK: agent roster in sync (source == distro)"
    exit 0
fi

echo "" >&2
echo "ERROR: $drift agent file(s) drifted between source and distro." >&2
echo "  Fix: run ./scripts/sync-plugin.sh (source→distro), or copy a distro-authored" >&2
echo "  agent back into agents/, then re-run this check." >&2
exit 1
