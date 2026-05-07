#!/usr/bin/env bash
# borg-nanoprobe-log.sh — Claude Code SubagentStop hook
#
# Fires when a subagent (e.g. borg-nanoprobe) completes. Appends one JSONL line
# to ~/.config/borg/agents.jsonl describing the run so the orchestrator can list
# nanoprobes via `borg nanoprobes` and pull transcripts via `borg nanoprobe-log`.
#
# This hook is informational. It NEVER blocks the session — exit 0 on every path,
# including write failures or malformed payloads.
#
# Verified payload fields (per the nanoprobe directive):
#   - agent_id
#   - agent_type
#   - agent_transcript_path
#   - last_assistant_message
# Status is implicit — the hook only fires on completion, so we hard-code
# "status": "completed" in the JSONL record.

set -euo pipefail

# Mirror the SessionStart PATH so brew/pipx tools (jq) resolve under Claude Code's
# stripped PATH environment. Order matches a healthy interactive zsh PATH.
PATH="${HOME}/.config/dotfiles/zsh/bin:${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
export PATH

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
LOG_FILE="$BORG_DIR/agents.jsonl"

mkdir -p "$BORG_DIR" 2>/dev/null || exit 0

INPUT=$(cat /dev/stdin 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null || true)
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null || true)
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null || true)
LAST_MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)

# Truncate summary to ~500 chars to keep the JSONL file scannable.
if (( ${#LAST_MSG} > 500 )); then
    SUMMARY="${LAST_MSG:0:497}..."
else
    SUMMARY="$LAST_MSG"
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD="${PWD:-}"

# Atomic append: build the line in jq, then >> the file. Drop the line silently
# on any jq error — never block the session.
LINE=$(jq -nc \
    --arg id "$AGENT_ID" \
    --arg type "$AGENT_TYPE" \
    --arg tpath "$TRANSCRIPT_PATH" \
    --arg summary "$SUMMARY" \
    --arg finished "$NOW" \
    --arg cwd "$CWD" \
    '{
        id: $id,
        agent_type: $type,
        transcript_path: $tpath,
        summary: $summary,
        status: "completed",
        finished_at: $finished,
        cwd: $cwd
    }' 2>/dev/null || true)

[[ -n "$LINE" ]] || exit 0

printf '%s\n' "$LINE" >> "$LOG_FILE" 2>/dev/null || true

exit 0
