#!/usr/bin/env bash
# borg-stop.sh — Claude Code Stop hook
# Fires when a Claude Code session ends (user exits or session closes).
#
# Updates registry: status=idle, summary=<extracted>, claude_session_id=<id>
# Registered as a Stop hook in ~/.claude/settings.json alongside session-log.sh

set -euo pipefail

BORG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

PROJECT=$(basename "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Require registry to exist
[[ -f "$BORG_REGISTRY" ]] || exit 0

# Generate summary if transcript exists
SUMMARY=""
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    SUMMARY=$(python3 "$BORG_ROOT/summarize.py" "$TRANSCRIPT" 2>/dev/null || true)
fi

# Atomic registry update
TMP="$BORG_REGISTRY.tmp.$$"
jq \
    --arg p "$PROJECT" \
    --arg sid "$SESSION_ID" \
    --arg summary "$SUMMARY" \
    --arg now "$NOW" \
    '
    if .projects | has($p) then
        .projects[$p].status = "idle" |
        .projects[$p].last_activity = $now |
        (if $sid != "" then .projects[$p].claude_session_id = $sid else . end) |
        (if $summary != "" then .projects[$p].summary = $summary else . end)
    else .
    end
    ' "$BORG_REGISTRY" > "$TMP" && mv "$TMP" "$BORG_REGISTRY"

exit 0
