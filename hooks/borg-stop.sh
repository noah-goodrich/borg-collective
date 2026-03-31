#!/usr/bin/env bash
# borg-stop.sh — Claude Code Stop hook
# Fires when a Claude Code session ends (user exits or session closes).
#
# Updates registry: status=idle, claude_session_id=<id>
# Spawns async LLM debrief via claude -p → ~/.config/borg/debriefs/<project>.md
# Registered as a Stop hook in ~/.claude/settings.json alongside session-log.sh

set -euo pipefail

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

# Fast registry update: status=idle (no blocking LLM call)
TMP="$BORG_REGISTRY.tmp.$$"
jq \
    --arg p "$PROJECT" \
    --arg sid "$SESSION_ID" \
    --arg now "$NOW" \
    '
    if .projects | has($p) then
        .projects[$p].status = "idle" |
        .projects[$p].last_activity = $now |
        (if $sid != "" then .projects[$p].claude_session_id = $sid else . end)
    else .
    end
    ' "$BORG_REGISTRY" > "$TMP" && mv "$TMP" "$BORG_REGISTRY"

# Async LLM debrief — does not block hook exit
DEBRIEF_DIR="$BORG_DIR/debriefs"
mkdir -p "$DEBRIEF_DIR"
DEBRIEF_FILE="$DEBRIEF_DIR/${PROJECT}.md"

if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] && command -v claude >/dev/null 2>&1; then
    _transcript="$TRANSCRIPT"
    _debrief_file="$DEBRIEF_FILE"
    _registry="$BORG_REGISTRY"
    _project="$PROJECT"
    _session_id="$SESSION_ID"
    (
        _date=$(date '+%Y-%m-%d %H:%M')
        _tail=$(tail -200 "$_transcript")
        _prompt="Analyze this Claude Code session transcript (JSONL format) and produce a structured debrief.

# Session Debrief: ${_project}
*Date: ${_date}*

## Objective
One sentence: what was the goal? If it changed mid-session, note both.

## Outcome
Specific results only:
- Files created/modified (with paths)
- Features built or bugs fixed
- Commands that now work

## Decisions Made
Significant decisions with reasoning. Skip trivial choices.

## Blockers and Observations
Gotchas, unexpected errors, root causes discovered.

## Next Steps
What should the next session do FIRST? Be specific with file paths and commands.
1. [action]
2. [second action]

Be concise and specific. No vague summaries.
---
TRANSCRIPT (JSONL, last 200 lines):
${_tail}"

        claude -p "$_prompt" --model claude-sonnet-4-6 --no-session-persistence --bare \
            > "${_debrief_file}.tmp" 2>/dev/null \
            && mv "${_debrief_file}.tmp" "$_debrief_file"

        # Update registry summary with Objective line
        if [[ -f "$_debrief_file" && -f "$_registry" ]]; then
            _summary=$(grep -A1 "^## Objective" "$_debrief_file" | grep -v "^## Objective" | head -1 | head -c 200 || true)
            if [[ -n "$_summary" ]]; then
                _tmp="${_registry}.dtmp.$$"
                jq --arg p "$_project" --arg s "$_summary" \
                    'if .projects | has($p) then .projects[$p].summary = $s else . end' \
                    "$_registry" > "$_tmp" && mv "$_tmp" "$_registry"
            fi
        fi

        # Commit session record to cairn (optional — degrades gracefully if unavailable)
        if [[ -f "$_debrief_file" ]] && command -v cairn >/dev/null 2>&1; then
            _obj=$(grep -A1 "^## Objective" "$_debrief_file" | grep -v "^## Objective" | head -1 | head -c 200 || true)
            _notes=$(head -c 2000 "$_debrief_file")
            _cairn_id="cc-${_project}-$(date +%Y%m%d-%H%M%S)"
            if [[ -n "$_obj" ]]; then
                cairn record session \
                    --id "$_cairn_id" \
                    --project "$_project" \
                    --tool "claude-code" \
                    --objective "$_obj" \
                    --notes "$_notes" \
                    2>/dev/null || true
            else
                cairn record session \
                    --id "$_cairn_id" \
                    --project "$_project" \
                    --tool "claude-code" \
                    --notes "$_notes" \
                    2>/dev/null || true
            fi
        fi
    ) >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
fi

exit 0
