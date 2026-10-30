#!/usr/bin/env bash
# borg-nanoprobe-log.sh — Claude Code / Cortex Code SubagentStop hook
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
# ZERO-WRITE (writer types only): zero_commit is true when the transcript shows no Edit/Write/NotebookEdit/
# MultiEdit, no git commit/push, and no Bash file write (> or >> to anything but /dev/null|stdout|stderr or an
# fd dup such as 2>&1, tee, sed -i, heredoc to a file). Counted in one jq pass; no per-call subprocess.
#
# Claude Code internal agents (prompt suggestions, away summaries, compaction; agent_type "") are skipped:
# the plugin matcher is ".+" and the guard after AGENT_TYPE is parsed covers registrations without one.
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
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r 'if .agent_type == null then "?" else .agent_type end' 2>/dev/null || true)
# Only a PRESENT, empty agent_type marks a Claude Code internal agent. A missing or null key is an unknown
# payload shape (Cortex Code does send agent_type, verified 2026-10-30, but its registration in borg.zsh has no
# matcher): logged as "?". An empty one the matcher lets through must not reach the evidence/zero-commit
# warnings or the log.
[[ -z "$AGENT_TYPE" ]] && exit 0
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null || true)
LAST_MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
[[ -z "$CWD" ]] && CWD="${PWD:-}"

# Cortex Code sends agent_transcript_path = <id>.json, a conversation snapshot with no turns in it. The turns live
# beside it in <id>.history.jsonl, one message per line: an assistant line carries model and thinking_effort, a tool
# call is {type:"tool_use", tool_use:{name, input, tool_use_id}} with a lowercase name (bash, write, edit), and its
# result is {type:"tool_result", tool_result:{status, tool_use_id}}, where status "error" marks a failed call.
# Claude Code transcripts end in .jsonl, so a .json path selects the Cortex shape. The ZERO-WRITE and model/effort
# judgements below read TX_FILE; the summary recovery stays Claude-only (Cortex sends last_assistant_message).
TX_FILE="$TRANSCRIPT_PATH"
TX_FMT=claude
if [[ "$TRANSCRIPT_PATH" == *.json ]]; then
    TX_FILE="${TRANSCRIPT_PATH%.json}.history.jsonl"
    TX_FMT=cortex
fi

# ─── Summary recovery ─────────────────────────────────────────────────────────
# last_assistant_message is the final assistant TEXT block. Background subagents end on a tool_use with
# no text (SubagentHandback, or StructuredOutput for workflow/schema agents), so it arrives empty. Recover
# the report from the tail of the transcript (agent_transcript_path): the LAST assistant message. One API
# message is written as one line per content block, so every entry sharing the last entry's message.id is
# joined (the last entry alone when it has no id). Preference order: text blocks, else SubagentHandback
# input.message, else StructuredOutput input.summary/answer/reason/verdict, else compact JSON of the input.
# The final line is often a user tool_result. Lines are parsed one by one because the file is written
# asynchronously and the last line may be torn. Any failure leaves LAST_MSG empty. The evidence score
# below is computed from the recovered text too.
if [[ -z "$LAST_MSG" && -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" && -r "$TRANSCRIPT_PATH" ]]; then
    RECOVERED=$(tail -n 80 "$TRANSCRIPT_PATH" 2>/dev/null | jq -Rrs '
        [split("\n")[] | (fromjson? // empty) | select(type == "object" and .type == "assistant")] as $all
        | ($all | last) as $lastE
        | (if ($lastE.message.id // "") != "" then [$all[] | select(.message.id == $lastE.message.id)]
           else [$lastE] end) as $entries
        | [$entries[] | (.message.content // []) | if type == "string" then [{type: "text", text: .}] else . end
           | .[]?] as $c
        | ([$c[] | select(.type == "text") | .text] | join("\n")) as $text
        | if $text != "" then $text
          else
            ([$c[] | select(.type == "tool_use" and .name == "SubagentHandback")] | last) as $h
            | ([$c[] | select(.type == "tool_use" and .name == "StructuredOutput")] | last) as $s
            | if $h != null and ($h.input.message | type) == "string" then $h.input.message
              elif $h != null then ($h.input | tojson)
              elif $s != null then
                ([$s.input.summary, $s.input.answer, $s.input.reason, $s.input.verdict
                  | select(type == "string" and . != "")] | first) // ($s.input | tojson)
              else "" end
          end // ""' 2>/dev/null || true)
    [[ -n "$RECOVERED" ]] && LAST_MSG="$RECOVERED"
fi

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
# ZERO-WRITE comes from the agent transcript (successful edits, git commit/push, Bash file writes), never the payload
# cwd, which is the parent session's. zero_commit is null when not applicable.
# A 0-write run (the 15-read/0-write/32k-abort failure) is flagged loudly so the orchestrator
# re-spawns instead of believing the work landed. The payload cwd is the PARENT session's cwd (a
# nanoprobe works in its own worktree via git -C and removes it), so the repo cannot answer this;
# the transcript can. Count file-edit tool calls plus Bash git commit/push and Bash file writes (a > or >>
# redirect to anything but /dev/null|stdout|stderr or an fd dup like 2>&1, tee, sed -i, a heredoc to a file),
# joining each tool_use to its tool_result by tool_use_id and dropping only is_error results (a call with
# no result yet counts). All patterns run inside the one jq pass over the transcript.
# Cortex transcripts (TX_FMT=cortex) go through `norm` first, which maps each nested tool_use/tool_result to the
# Claude block shape (bash/write/edit/notebook_edit -> Bash/Write/Edit/NotebookEdit, status "error" -> is_error),
# so the counting rules below are the same for both CLIs.
# zero_commit: true = flagged, false = writes found, null = not applicable (non-writer or no transcript).
ZERO_COMMIT=null
if [[ "$IS_WRITER" == "true" && -n "$TX_FILE" && -r "$TX_FILE" ]]; then
    # git, then any mix of -C <path> (bare or quoted), -c k=v and --long[=value], then commit|push; the
    # lead-in may be start, whitespace, ; & | ( or a quote so `bash -c '...git commit...'` matches.
    _git_re="(^|[[:space:];&|(\"'])git((\\s+-C\\s+(\"[^\"]*\"|'[^']*'|\\S+))|(\\s+-c\\s+\\S+)|(\\s+--[A-Za-z][A-Za-z-]*(=\\S+)?))*\\s+(commit|push)(\\s|\$|[\"'])"
    # Bash-shaped writes, folded into the SAME single jq pass (no extra subprocess). A Bash command counts
    # when, after dropping fd duplicates (2>&1, >&2) and redirects to /dev/null|stdout|stderr, it still has
    # a `>` or `>>` (not part of ->, =>, <>, >|), or it runs tee, or sed -i / --in-place. A heredoc written
    # to a file (cat > f << EOF) is covered by the redirect. A `>` inside a quoted string is a known false positive.
    _w_dup='[0-9&]*>&[0-9-]+'
    _w_sink='[0-9&]*>>?\s*/dev/(null|stdout|stderr)(\s|$|[;&|)"'"'"'])'
    _w_redir='(^|[^-=<>|])>'
    _w_tee='(^|[\s;&|("'"'"'])tee(\s|$)'
    _w_sed='(^|[\s;&|("'"'"'])sed\s+([^|;&]*\s)?(-[A-Za-z]*i|--in-place)'
    # Line by line: one malformed line (fromjson?) or non-array content must not void the whole parse.
    # A tool_use with no tool_result yet counts (the transcript lags); only an is_error result drops it.
    _writes=$(jq -R -r -n --arg re "$_git_re" --arg dup "$_w_dup" --arg sink "$_w_sink" --arg redir "$_w_redir" \
        --arg tee "$_w_tee" --arg sed "$_w_sed" --arg fmt "$TX_FMT" '
        def norm:
            if $fmt != "cortex" then .
            elif .type == "tool_use" and (.tool_use | type) == "object" then
                .tool_use | {type: "tool_use", id: .tool_use_id, input: (.input // {}),
                    name: ({bash: "Bash", write: "Write", edit: "Edit", notebook_edit: "NotebookEdit"}[.name // ""]
                        // .name)}
            elif .type == "tool_result" and (.tool_result | type) == "object" then
                .tool_result | {type: "tool_result", tool_use_id, is_error: (.status == "error")}
            else . end;
        [inputs | fromjson? | ((if $fmt == "cortex" then .content? else .message.content? end) // [])
            | if type == "array" then .[] else empty end
            | select(type == "object") | norm] as $blocks
        | ([$blocks[] | select(.type == "tool_result" and (.is_error // false) == true) | .tool_use_id]) as $bad
        | [$blocks[]
            | select(.type == "tool_use" and (.id as $i | $bad | index($i) == null))
            | select(
                (.name | IN("Edit", "Write", "NotebookEdit", "MultiEdit"))
                or (.name == "Bash" and ((.input.command // "") | (
                    test($re)
                    or (gsub($dup; "") | gsub($sink; " ") | test($redir))
                    or test($tee)
                    or test($sed)
                  )))
              )
          ] | length
    ' "$TX_FILE" 2>/dev/null || true)
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

# Model + effort from the transcript's first assistant entry (same selection as borg.zsh's
# _borg_nanoprobe_model_effort). Recorded now because Claude Code prunes transcripts after ~30 days.
# A Cortex history line carries them at the top level (model, thinking_effort); the first assistant line that has a
# model wins. Absent file or field yields JSON null; never drops the row.
MODEL_JSON=null
EFFORT_JSON=null
if [[ -n "$TX_FILE" && -f "$TX_FILE" && -r "$TX_FILE" ]]; then
    if [[ "$TX_FMT" == "cortex" ]]; then
        _me=$(jq -c 'select(.role == "assistant" and (.model | type) == "string") |
            [.model, (.thinking_effort // null)]' "$TX_FILE" 2>/dev/null | head -1 || true)
    else
        _me=$(jq -c 'select(.type == "assistant") |
            [(.message.model // null), (.effort // .perTurnEffort // null)]' "$TX_FILE" 2>/dev/null \
            | head -1 || true)
    fi
    if [[ -n "$_me" ]]; then
        MODEL_JSON=$(printf '%s' "$_me" | jq -c '.[0]' 2>/dev/null || echo null)
        EFFORT_JSON=$(printf '%s' "$_me" | jq -c '.[1]' 2>/dev/null || echo null)
        [[ -n "$MODEL_JSON" ]] || MODEL_JSON=null
        [[ -n "$EFFORT_JSON" ]] || EFFORT_JSON=null
    fi
fi

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
    --argjson model "$MODEL_JSON" \
    --argjson effort "$EFFORT_JSON" \
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
        zero_commit: $zero_commit,
        model: $model,
        effort: $effort
    }' 2>/dev/null || true)

[[ -n "$LINE" ]] || exit 0

# Retention: cap at 1 MiB, one previous generation; `borg nanoprobes` reads the live file then .1.
# bash 3.2: a failed `source` is fatal under set -e even inside `{ }`/`|| true`; a subshell contains it.
# The lib is resolved script-relative first, the installed copy second (same order as the lifecycle hooks).
(
    _borg_lib_dir="${BASH_SOURCE[0]%/*}"
    [[ "$_borg_lib_dir" == "${BASH_SOURCE[0]}" ]] && _borg_lib_dir=.
    _borg_lib="$_borg_lib_dir/../lib/borg-hooks.sh"
    [[ -f "$_borg_lib" ]] || _borg_lib="${HOME}/.claude/lib/borg-hooks.sh"
    source "$_borg_lib" && _borg_rotate_log "$LOG_FILE"
) >/dev/null 2>&1 || true

printf '%s\n' "$LINE" >> "$LOG_FILE" 2>/dev/null || true

exit 0
