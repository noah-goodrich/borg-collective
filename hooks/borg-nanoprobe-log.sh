#!/usr/bin/env bash
# borg-nanoprobe-log.sh — Claude Code SubagentStop hook
#
# Fires when a subagent (e.g. borg-nanoprobe) completes. Appends one JSONL line
# to ~/.config/borg/agents.jsonl describing the run so the orchestrator can list
# nanoprobes via `borg nanoprobes` and pull transcripts via `borg nanoprobe-log`.
#
# Evidence gate: scores last_assistant_message for file-path citations before
# logging. Appends evidence_found + evidence_score to the JSONL record and emits
# a stderr warning when evidence is absent, so the orchestrator can see at a glance
# which nanoprobes completed without citing their work.
#
# Evidence scoring:
#   0 — no file/path references found
#   1 — bare filename mentioned (e.g. "borg-hooks.sh")
#   2 — path:line citation found (e.g. "lib/borg-hooks.sh:42")
#   3 — path:line citations + git diff present in worktree
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
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
[[ -z "$CWD" ]] && CWD="${PWD:-}"

# Truncate summary to ~500 chars to keep the JSONL file scannable.
if (( ${#LAST_MSG} > 500 )); then
    SUMMARY="${LAST_MSG:0:497}..."
else
    SUMMARY="$LAST_MSG"
fi

# ─── Evidence scoring ─────────────────────────────────────────────────────────
# Score the last_assistant_message for proof that work was actually done.
# Pattern: path:line  e.g.  lib/borg-hooks.sh:42  or  hooks/foo.sh:123
_score_evidence() {
    local msg="$1" cwd="$2" score=0

    # Score 1: any word ending in a recognisable file extension
    if printf '%s' "$msg" | grep -qE '[A-Za-z0-9_/-]+\.[a-z]{1,6}' 2>/dev/null; then
        score=1
    fi

    # Score 2: path:line citation  e.g. lib/borg-hooks.sh:42
    if printf '%s' "$msg" | grep -qE '[A-Za-z0-9_./-]+\.[a-z]{1,6}:[0-9]+' 2>/dev/null; then
        score=2
    fi

    # Score 3: path:line AND git diff shows actual changes in the worktree
    if (( score >= 2 )) && [[ -n "$cwd" ]] && command -v git >/dev/null 2>&1; then
        if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local _diff
            _diff=$(git -C "$cwd" diff --stat 2>/dev/null || true)
            [[ -n "$_diff" ]] && score=3 || true
        fi
    fi

    printf '%d' "$score"
}

EVIDENCE_SCORE=$(_score_evidence "$LAST_MSG" "$CWD" 2>/dev/null || printf '0')
if (( EVIDENCE_SCORE > 0 )); then
    EVIDENCE_FOUND=true
else
    EVIDENCE_FOUND=false
fi

# Warn orchestrator when a nanoprobe completes without citing its work.
if [[ "$EVIDENCE_FOUND" == "false" && -n "$LAST_MSG" ]]; then
    printf '\n\033[1;33m▸ NANOPROBE EVIDENCE WARNING: %s completed without file-path citations.\033[0m\n' \
        "${AGENT_ID:0:8}" >&2
    printf '\033[1;33m  Review the transcript (%s) to confirm work was done.\033[0m\n\n' \
        "${TRANSCRIPT_PATH:-unknown}" >&2
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Atomic append: build the line in jq, then >> the file. Drop the line silently
# on any jq error — never block the session.
LINE=$(jq -nc \
    --arg id "$AGENT_ID" \
    --arg type "$AGENT_TYPE" \
    --arg tpath "$TRANSCRIPT_PATH" \
    --arg summary "$SUMMARY" \
    --arg finished "$NOW" \
    --arg cwd "$CWD" \
    --argjson evidence_found "$EVIDENCE_FOUND" \
    --argjson evidence_score "$EVIDENCE_SCORE" \
    '{
        id: $id,
        agent_type: $type,
        transcript_path: $tpath,
        summary: $summary,
        status: "completed",
        finished_at: $finished,
        cwd: $cwd,
        evidence_found: $evidence_found,
        evidence_score: $evidence_score
    }' 2>/dev/null || true)

[[ -n "$LINE" ]] || exit 0

printf '%s\n' "$LINE" >> "$LOG_FILE" 2>/dev/null || true

exit 0
