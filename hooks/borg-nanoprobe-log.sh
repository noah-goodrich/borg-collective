#!/usr/bin/env bash
# borg-nanoprobe-log.sh — Claude Code SubagentStop hook
#
# Fires when a subagent (e.g. borg-nanoprobe) completes. Appends one JSONL line
# to <state root>/agents.jsonl describing the run so the orchestrator can list
# nanoprobes via `borg nanoprobes` and pull transcripts via `borg nanoprobe-log`.
#
# Evidence gate: scores last_assistant_message for file-path citations before
# logging. Appends evidence_found + evidence_score to the JSONL record and emits
# a systemMessage warning when evidence is absent, so the orchestrator can see at a glance
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

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
LOG_FILE="$STATE_DIR/agents.jsonl"

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
# Append-only history: carry a pre-move config-dir log across ONCE, or readers (which prefer the state
# root as soon as it exists) would see only the newest run. Copy, never move.
OLD_LOG="${XDG_CONFIG_HOME:-$HOME/.config}/borg/agents.jsonl"
{ [ -e "$LOG_FILE" ] || [ ! -f "$OLD_LOG" ] || cp "$OLD_LOG" "$LOG_FILE"; } 2>/dev/null || true

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

# A SubagentStop hook that exits 0 has its stderr sent to the debug log only -- never the user
# (https://code.claude.com/docs/en/hooks, "Exit code 0"). The user-visible, non-blocking channel is
# ONE JSON object on stdout carrying `systemMessage` (plain text, no ANSI), emitted below. No
# `decision` field, so the subagent is not kept running. Nothing else here may write to stdout.
WARNINGS=""
_warn() {
    WARNINGS+="${WARNINGS:+$'\n\n'}$1"
}

# Only writer types are expected to leave file edits or commits behind. Read-only types (reviewer,
# researcher, scout, ...) legitimately end with neither, so both checks below skip them.
IS_WRITER=false
case "$AGENT_TYPE" in
    borg-collective:borg-nanoprobe|borg-collective:borg-grunt|borg-nanoprobe|borg-grunt) IS_WRITER=true ;;
esac

# Warn orchestrator when a writer nanoprobe completes without citing its work.
if [[ "$IS_WRITER" == "true" && "$EVIDENCE_FOUND" == "false" && -n "$LAST_MSG" ]]; then
    _warn "▸ NANOPROBE EVIDENCE WARNING: ${AGENT_ID:0:8} completed without file-path citations.
  Review the transcript (${TRANSCRIPT_PATH:-unknown}) to confirm work was done."
fi

# ─── Zero-write detection ─────────────────────────────────────────────────────
# Both warnings (EVIDENCE, ZERO-WRITE) apply to writer types only (borg-nanoprobe, borg-grunt).
# ZERO-WRITE comes from the agent transcript (successful edits or git commit/push), never the payload
# cwd, which is the parent session's. zero_commit is null when not applicable.
# A 0-write run (the 15-read/0-write/32k-abort failure) is flagged loudly so the orchestrator
# re-spawns instead of believing the work landed. The payload cwd is the PARENT session's cwd (a
# nanoprobe works in its own worktree via git -C and removes it), so the repo cannot answer this;
# the transcript can. Count file-edit tool calls plus Bash git commit/push, joining each tool_use to
# its tool_result by tool_use_id and dropping only is_error results (a call with no result yet counts).
# zero_commit: true = flagged, false = writes found, null = not applicable (non-writer or no transcript).
ZERO_COMMIT=null
if [[ "$IS_WRITER" == "true" && -n "$TRANSCRIPT_PATH" && -r "$TRANSCRIPT_PATH" ]]; then
    # git, then any mix of -C <path> (bare or quoted), -c k=v and --long[=value], then commit|push; the
    # lead-in may be start, whitespace, ; & | ( or a quote so `bash -c '...git commit...'` matches.
    _git_re="(^|[[:space:];&|(\"'])git((\\s+-C\\s+(\"[^\"]*\"|'[^']*'|\\S+))|(\\s+-c\\s+\\S+)|(\\s+--[A-Za-z][A-Za-z-]*(=\\S+)?))*\\s+(commit|push)(\\s|\$|[\"'])"
    # Line by line: one malformed line (fromjson?) or non-array content must not void the whole parse.
    # A tool_use with no tool_result yet counts (the transcript lags); only an is_error result drops it.
    _writes=$(jq -R -r -n --arg re "$_git_re" '
        [inputs | fromjson? | (.message.content? // []) | if type == "array" then .[] else empty end
            | select(type == "object")] as $blocks
        | ([$blocks[] | select(.type == "tool_result" and (.is_error // false) == true) | .tool_use_id]) as $bad
        | [$blocks[]
            | select(.type == "tool_use" and (.id as $i | $bad | index($i) == null))
            | select(
                (.name | IN("Edit", "Write", "NotebookEdit", "MultiEdit"))
                or (.name == "Bash" and ((.input.command // "") | test($re)))
              )
          ] | length
    ' "$TRANSCRIPT_PATH" 2>/dev/null || true)
    if [[ "$_writes" =~ ^[0-9]+$ ]]; then
        if (( _writes == 0 )); then
            ZERO_COMMIT=true
            _warn "▸ NANOPROBE ZERO-WRITE: ${AGENT_ID:0:8} made no file edits and no git commit/push (checked its transcript). Re-spawn with a tighter, single-deliverable brief."
        else
            ZERO_COMMIT=false
        fi
    fi
fi

# Emit ONE object. No warnings => no stdout at all.
if [[ -n "$WARNINGS" ]]; then
    jq -n --arg msg "$WARNINGS" '{systemMessage: $msg}' 2>/dev/null || true
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
    --argjson zero_commit "$ZERO_COMMIT" \
    '{
        id: $id,
        agent_type: $type,
        transcript_path: $tpath,
        summary: $summary,
        status: "completed",
        finished_at: $finished,
        cwd: $cwd,
        evidence_found: $evidence_found,
        evidence_score: $evidence_score,
        zero_commit: $zero_commit
    }' 2>/dev/null || true)

[[ -n "$LINE" ]] || exit 0

# Retention: cap at 1 MiB, one previous generation; `borg nanoprobes` reads the live file then .1.
{ source "${HOME}/.claude/lib/borg-hooks.sh" && _borg_rotate_log "$LOG_FILE"; } >/dev/null 2>&1 || true

printf '%s\n' "$LINE" >> "$LOG_FILE" 2>/dev/null || true

exit 0
