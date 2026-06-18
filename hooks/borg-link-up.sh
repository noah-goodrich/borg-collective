#!/usr/bin/env bash
# borg-link-up.sh — Claude Code / Cortex Code Stop hook
# "Link up" to the collective: flush state from the session when it ends.
#
# Project sessions:
# - State update (state.json): status=idle, claude_session_id, last_activity
# - Tracks has_uncommitted_changes for next session's reminder
# - Cleans up per-project skill overlays symlinked during link-down
# - Nudges on exit if no checkpoint was recorded this session ("run /borg-link-up next time")
# - Records session to cairn knowledge graph (best-effort, graceful degradation)
#
# Orchestrator sessions (CWD == $BORG_ORCHESTRATOR_ROOT):
# - Records most-recent checkpoint (or last assistant message) to cairn as project
#   $BORG_ORCHESTRATOR_PROJECT (default: "borg-collective"). Gracefully degrades when cairn
#   is absent — logs failure to $BORG_DIR/.cairn-write-failed and continues.
# - No registry writes, no uncommitted-changes scans, no per-project nudges.
#
# Does NOT generate LLM debriefs. Checkpoints are user-authored via /borg-link-up
# (the skill). Registered as a Stop hook in settings.json for both Claude Code and CoCo.

set -euo pipefail

# Ensure dotfiles bin (cairn client), Homebrew, pipx user bins, and common
# system paths are available when this hook runs in Claude Code's stripped
# PATH environment. Order mirrors a healthy interactive zsh PATH so brew
# binaries shadow system equivalents (e.g. brew jq before /usr/bin/jq).
PATH="${HOME}/.config/dotfiles/zsh/bin:${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
export PATH

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)

[[ -z "$CWD" ]] && exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh"

# Orchestrator-mode sessions touch no per-project state (no registry writes,
# uncommitted-changes scans, or checkpoint nudges). However, if the user ran
# /borg-link-up during the session a checkpoint was written at
# $CWD/.borg/checkpoints/<ts>.md — record that to cairn so orchestrator work is
# not silently discarded from the knowledge graph.
#
# Project tag: BORG_ORCHESTRATOR_PROJECT (default "borg-collective"). A single
# tag is used for all orchestrator sessions rather than per-project attribution
# (v1 choice: keeps the implementation simple; the checkpoint body already lists
# every project touched, so cross-project search still surfaces the record).
#
# Notes truncation policy: the cairn notes column is unbounded text, so we pass
# the full checkpoint with NO byte cap. bash parameter expansion (${var:0:N}) is
# character-safe (Unicode-aware), unlike `head -c N` which counts bytes and can
# split multibyte sequences mid-character. If a checkpoint exceeds the 100 KB
# shell ARG_MAX safety threshold we truncate at the last section boundary before
# that limit and emit a one-line stderr notice — a truncated record is never
# silent.
if [[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]]; then
    if command -v cairn >/dev/null 2>&1; then
        _orch_project="${BORG_ORCHESTRATOR_PROJECT:-borg-collective}"
        _orch_cp_dir="$CWD/.borg/checkpoints"
        _orch_cairn_id="$(date -u +%Y%m%d-%H%M)-orchestrator"

        # Build notes: prefer the most-recent checkpoint file (user-authored
        # via /borg-link-up), fall back to last assistant message from transcript.
        # No byte cap — the cairn notes column is unbounded text (type: text in
        # PostgreSQL). Character-safe truncation only fires above 100 KB to guard
        # against ARG_MAX issues when passing --notes on the command line.
        _orch_notes=""
        if [[ -d "$_orch_cp_dir" ]]; then
            _latest_cp=$(find "$_orch_cp_dir" -maxdepth 1 -name "*.md" -mmin -120 2>/dev/null \
                | sort | tail -1 || true)
            if [[ -n "$_latest_cp" ]]; then
                _orch_notes=$(cat "$_latest_cp" 2>/dev/null || true)
                # Character-safe cap at 100 000 chars (~100 KB). Truncate at the
                # last "^## " section boundary before the cap so the record is
                # never cut mid-sentence. Emit a stderr notice when truncation fires
                # (a silent truncation looks identical to a complete record).
                _ORCH_NOTES_CAP=100000
                if [[ ${#_orch_notes} -gt $_ORCH_NOTES_CAP ]]; then
                    _truncated="${_orch_notes:0:$_ORCH_NOTES_CAP}"
                    # Find last section boundary ("^## ") in the truncated string.
                    # We scan backwards by looking for the last newline+## prefix.
                    _last_section_pos=$(printf '%s' "$_truncated" | grep -bo $'\n## ' 2>/dev/null \
                        | tail -1 | cut -d: -f1 || true)
                    if [[ -n "$_last_section_pos" && "$_last_section_pos" -gt 0 ]]; then
                        _orch_notes="${_truncated:0:$_last_section_pos}"
                    else
                        _orch_notes="$_truncated"
                    fi
                    printf 'borg-link-up: checkpoint truncated for cairn (%d chars -> %d, file: %s)\n' \
                        "$(wc -m < "$_latest_cp")" "${#_orch_notes}" "$_latest_cp" >&2
                fi
            fi
        fi

        # Fall back to last assistant message when no fresh checkpoint exists.
        if [[ -z "$_orch_notes" && -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
            _orch_notes=$(tail -c 20000 "$TRANSCRIPT_PATH" 2>/dev/null \
                | jq -rs '[.[] | select(.message.role == "assistant")] | last | .message.content // ""' \
                2>/dev/null | head -c 1000 || true)
        fi

        _orch_cmd=(cairn record session \
            --id "$_orch_cairn_id" \
            --project "$_orch_project" \
            --tool claude-code)
        [[ -n "$_orch_notes" ]] && _orch_cmd+=(--notes "$_orch_notes")

        _orch_cairn_failed=""
        if command -v timeout >/dev/null 2>&1; then
            _orch_cairn_err=$(timeout 5 "${_orch_cmd[@]}" 2>&1 >/dev/null) || _orch_cairn_failed=1
        else
            _orch_cairn_err=$("${_orch_cmd[@]}" 2>&1 >/dev/null) || _orch_cairn_failed=1
        fi
        if [[ -n "$_orch_cairn_failed" ]]; then
            printf '%s\t%s\n' \
                "cairn write failed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                "${_orch_cairn_err:-no stderr captured}" >> "${BORG_DIR}/.cairn-write-failed"
        fi
    fi
    exit 0
fi

PROJECT=$(_borg_find_project "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

PROJ_DIR=$(_borg_resolve_proj_dir "$PROJECT" "$CWD")

# Check for uncommitted changes (warn in terminal; store flag in state.json)
UNCOMMITTED=""
if command -v git >/dev/null 2>&1; then
    if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        UNCOMMITTED=$(git -C "$CWD" status --porcelain 2>/dev/null | grep -v "^??" || true)
    fi
fi

if [[ -n "$UNCOMMITTED" ]]; then
    printf '\n\033[1;33m▸ WARNING: %s has uncommitted changes\033[0m\n' "$PROJECT" >&2
    printf '\033[1;33m  Run /simplify then commit before your next session.\033[0m\n\n' >&2
    DIRTY_FLAG=true
else
    DIRTY_FLAG=false
fi

# Write status=idle + session fields + has_uncommitted_changes to state.json.
_cur_state=$(_borg_state_read "$PROJ_DIR")
_new_state=$(printf '%s' "$_cur_state" | jq \
    --arg sid "$SESSION_ID" \
    --arg now "$NOW" \
    --argjson dirty "$DIRTY_FLAG" \
    '.status = "idle" | .last_activity = $now |
     .has_uncommitted_changes = $dirty |
     (if $sid != "" then .claude_session_id = $sid else . end)')
_borg_state_write "$PROJ_DIR" "$_new_state" || true

# Per-project skill overlay cleanup
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
PROJECT_SKILLS_DIR="$CWD/.borg/skills"
if [[ -d "$PROJECT_SKILLS_DIR" ]]; then
    for _skill_dir in "$PROJECT_SKILLS_DIR"/*/; do
        [[ -d "$_skill_dir" ]] || continue
        _skill_name="${_skill_dir%/}"
        _skill_name="${_skill_name##*/}"
        _target="$CLAUDE_SKILLS_DIR/$_skill_name"
        if [[ -L "$_target" ]]; then
            _link=$(readlink "$_target" 2>/dev/null || true)
            [[ "$_link" == "${_skill_dir%/}" ]] && rm -f "$_target" || true
        fi
    done
fi

# Nudge: if no checkpoint from the last hour, remind to run /borg-link-up
CHECKPOINT_DIR="$CWD/.borg/checkpoints"
if [[ -d "$CHECKPOINT_DIR" ]]; then
    _recent_cp=$(find "$CHECKPOINT_DIR" -maxdepth 1 -name "*.md" -mmin -60 2>/dev/null | head -1 || true)
    if [[ -z "$_recent_cp" ]]; then
        printf '\n\033[1;33m▸ No checkpoint in the last hour for %s\033[0m\n' "$PROJECT" >&2
        printf '\033[1;33m  Run /borg-link-up next session to save state for future resumption.\033[0m\n\n' >&2
    fi
fi

# ── cairn-extract inbox emission (Layer 1) ────────────────────────────────────
# If a recent checkpoint exists, copy it to the cairn-extract inbox so the
# LLM extraction pipeline can pull decisions/patterns/observations from it.
# Then trigger cairn-extract detached (async, never blocks link-up).
# If cairn-extract is not installed or cairn is down, this is a silent no-op;
# the nightly launchd job (Layer 2) will sweep any remaining inbox files.
CAIRN_INBOX_ROOT="${HOME}/.local/state/borg/cairn-inbox"
_extract_bin="${HOME}/.config/dotfiles/zsh/bin/cairn-extract"
if [[ -d "$CHECKPOINT_DIR" ]]; then
    # Find the most recent checkpoint written this session (within last 2h)
    _newest_cp=$(find "$CHECKPOINT_DIR" -maxdepth 1 -name "*.md" -mmin -120 2>/dev/null \
        | sort | tail -1 || true)
    if [[ -n "$_newest_cp" && -f "$_newest_cp" ]]; then
        _inbox_dir="${CAIRN_INBOX_ROOT}/${PROJECT}"
        mkdir -p "$_inbox_dir"
        _cp_stem="${_newest_cp##*/}"
        # Copy only if not already in inbox or done (idempotent emit)
        if [[ ! -f "${_inbox_dir}/${_cp_stem}" && ! -f "${_inbox_dir}/done/${_cp_stem}" ]]; then
            cp "$_newest_cp" "${_inbox_dir}/${_cp_stem}" 2>/dev/null || true
        fi
        # Trigger extraction async — detached, log to inbox log, never blocks
        if [[ -x "$_extract_bin" ]]; then
            nohup "$_extract_bin" >> "${CAIRN_INBOX_ROOT}/cairn-extract.log" 2>&1 </dev/null &
            disown 2>/dev/null || true
        fi
    fi
fi

# Directive reconciliation nudge: if commits were made this session, check whether any
# open directive's ## Key Files section mentions a path touched by those commits.
# Match against ## Key Files only to avoid false positives from freeform body text.
DIRECTIVES_DIR="$CWD/docs/plans/directives"
if [[ -d "$DIRECTIVES_DIR" ]] && command -v git >/dev/null 2>&1; then
    if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Collect files changed by the most recent commit (if any)
        _changed_files=$(git -C "$CWD" diff --name-only HEAD~1 HEAD 2>/dev/null || true)
        if [[ -n "$_changed_files" ]]; then
            _matched_directives=""
            while IFS= read -r -d '' _dfile; do
                _dname="${_dfile##*/}"
                # Extract only the ## Key Files section lines
                _key_files=$(awk '
                    /^## Key Files/ { found=1; next }
                    found && /^## / { exit }
                    found { print }
                ' "$_dfile" 2>/dev/null || true)
                [[ -z "$_key_files" ]] && continue
                # Check if any changed file appears in the Key Files section
                while IFS= read -r _cf; do
                    [[ -z "$_cf" ]] && continue
                    _cf_base="${_cf##*/}"
                    if echo "$_key_files" | grep -qF "$_cf_base" 2>/dev/null; then
                        _matched_directives+="  - ${_dname}"$'\n'
                        break
                    fi
                done <<< "$_changed_files"
            done < <(find "$DIRECTIVES_DIR" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
            if [[ -n "$_matched_directives" ]]; then
                printf '\n\033[1;36m▸ Directive reconciliation? Committed files overlap with:\033[0m\n' >&2
                printf '%s' "$_matched_directives" >&2
                printf '\033[1;36m  Review open directives and update checkboxes if this work advances them.\033[0m\n\n' >&2
            fi
        fi
    fi
fi

# Record session to cairn knowledge graph (best-effort)
# Notes are built from: recent git commits + last assistant message from transcript.
if command -v cairn >/dev/null 2>&1; then
    _cairn_id="$(date -u +%Y%m%d-%H%M)-${PROJECT}"

    # Build structured notes: recent commits + last assistant message.
    _cairn_notes=""

    # Recent commits (best-effort; empty string if not a git repo or no commits).
    if command -v git >/dev/null 2>&1; then
        _git_log=$(git -C "$CWD" log --oneline -3 2>/dev/null || true)
        [[ -n "$_git_log" ]] && _cairn_notes="## Recent commits"$'\n'"$_git_log"$'\n'
    fi

    # Last assistant message from transcript (cap at 20KB to keep the hook fast).
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
        _last_msg=$(tail -c 20000 "$TRANSCRIPT_PATH" 2>/dev/null \
            | jq -rs '[.[] | select(.message.role == "assistant")] | last | .message.content // ""' \
            2>/dev/null | head -c 1000 || true)
        if [[ -n "$_last_msg" ]]; then
            _cairn_notes+=$'\n'"## Last assistant message"$'\n'"${_last_msg:0:800}"
        fi
    fi

    _cairn_cmd=(cairn record session --id "$_cairn_id" --project "$PROJECT" --tool claude-code)
    [[ -n "$_cairn_notes" ]] && _cairn_cmd+=(--notes "$_cairn_notes")

    # Capture cairn's stderr so a real failure tells us *what* broke (auth, schema,
    # service down). Without this the failure log is just timestamps and a transient
    # outage looks identical to a malformed payload.
    _cairn_failed=""
    if command -v timeout >/dev/null 2>&1; then
        _cairn_err=$(timeout 5 "${_cairn_cmd[@]}" 2>&1 >/dev/null) || _cairn_failed=1
    else
        _cairn_err=$("${_cairn_cmd[@]}" 2>&1 >/dev/null) || _cairn_failed=1
    fi
    if [[ -n "$_cairn_failed" ]]; then
        printf '%s\t%s\n' \
            "cairn write failed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            "${_cairn_err:-no stderr captured}" >> "${BORG_DIR}/.cairn-write-failed"
    fi
fi

exit 0
