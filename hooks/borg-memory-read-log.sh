#!/usr/bin/env bash
# borg-memory-read-log.sh — PostToolUse hook: log every read of a Claude Code project-memory file.
#
# THE QUESTION THIS ANSWERS: cairn's decommission (see ~/dev/cairn/docs/research/README.md) leaves
# auto-memory (~/.claude/projects/*/memory/*.md) as the sole cross-session knowledge layer. Nobody
# has ever checked whether it is actually READ — 283 files / 723,639 bytes with no hit-log
# equivalent to cairn-hits.log. This closes that gap with the same instrument, so the fallback
# cannot become a second write-only store unnoticed.
#
# Pre-registered null (do not move this bar after seeing the number): <0.2 reads/session means
# auto-memory is not a working retrieval loop.
#
# Fires on every Read call; matches only paths under a project's memory/ directory so normal file
# reads are not logged. Always exits 0 — this is passive observation, never a gate.

set -u

INPUT=$(cat /dev/stdin 2>/dev/null) || exit 0
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
[[ -z "$FILE_PATH" || "$FILE_PATH" == "null" ]] && exit 0

# Only paths of the shape ~/.claude/projects/<project-dir>/memory/<name>.md
case "$FILE_PATH" in
    "$HOME"/.claude/projects/*/memory/*.md) ;;
    *) exit 0 ;;
esac

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Extract the project dir segment (the raw -Users-noah-dev-X slug, same identity cairn-hits.log
# uses for its project column) so per-project reads/session can be computed the same way.
PROJECT_DIR="${FILE_PATH#"$HOME"/.claude/projects/}"
PROJECT_DIR="${PROJECT_DIR%%/memory/*}"

FILE_NAME="${FILE_PATH##*/}"
BYTES=$(wc -c < "$FILE_PATH" 2>/dev/null | tr -d ' ' || echo 0)

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
mkdir -p "$BORG_DIR" 2>/dev/null || true

{ printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$PROJECT_DIR" "$FILE_NAME" "$BYTES" \
    >> "${BORG_DIR}/memory-hits.log"; } 2>/dev/null || true

exit 0
