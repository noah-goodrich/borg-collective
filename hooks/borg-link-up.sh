#!/usr/bin/env bash
# borg-link-up.sh — Claude Code / Cortex Code Stop hook
# "Link up" to the collective: flush state from the session when it ends.
#
# Project sessions:
# - State update (state.json): status=idle, claude_session_id, last_activity
# - Tracks has_uncommitted_changes for next session's reminder
# - Cleans up per-project skill overlays symlinked during link-down
# - Nudges on exit if no checkpoint was recorded this session ("run /borg-link-up next time")
#
# Orchestrator sessions (CWD == $BORG_ORCHESTRATOR_ROOT):
# - No registry writes, no uncommitted-changes scans, no per-project nudges. Early exit.
#
# Does NOT generate LLM debriefs. Checkpoints are user-authored via /borg-link-up
# (the skill). Registered as a Stop hook in settings.json for both Claude Code and CoCo.

set -euo pipefail

# Ensure pipx user bins and common system paths are available when this hook runs in
# Claude Code's stripped PATH environment. Order mirrors a healthy interactive zsh PATH
# so brew binaries shadow system equivalents (e.g. brew jq before /usr/bin/jq).
PATH="${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
export PATH

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)

[[ -z "$CWD" ]] && exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh"

# Orchestrator-mode sessions touch no per-project state: no registry writes,
# uncommitted-changes scans, or checkpoint nudges. Checkpoints written via
# /borg-link-up during the session already live at $CWD/.borg/checkpoints/<ts>.md —
# that is the durable record; nothing further to do here.
if [[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]]; then
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

# Clock divergence check: compare the newest checkpoint filename's encoded timestamp
# (<YYYY-MM-DD-HHMM>...) against the checkpoint file's actual mtime. A container/VM
# clock that froze during a laptop sleep/resume (e.g. the Podman VM) shows up as a
# large gap between "when the name says it was written" and "when the filesystem says
# it was written" — a direct, dependency-free divergence signal that needs no separate
# host-time source. >5 minutes of skew is treated as divergence.
CLOCK_DIVERGED=false
CLOCK_DELTA=0
_cdiv_dir="$CWD/.borg/checkpoints"
if [[ -d "$_cdiv_dir" ]]; then
    _cdiv_latest=$(find "$_cdiv_dir" -maxdepth 1 -name "*.md" 2>/dev/null | sort -r | head -1 || true)
    if [[ -n "$_cdiv_latest" && -f "$_cdiv_latest" ]]; then
        _cdiv_base="${_cdiv_latest##*/}"
        _cdiv_ts="${_cdiv_base:0:15}"
        if [[ "$_cdiv_ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
            _cdiv_name_epoch=$(date -j -f "%Y-%m-%d-%H%M" "$_cdiv_ts" +%s 2>/dev/null \
                || date -d "${_cdiv_ts:0:10} ${_cdiv_ts:11:2}:${_cdiv_ts:13:2}" +%s 2>/dev/null || true)
            # GNU first: GNU `stat -f` prints a filesystem block to STDOUT before exiting 1, so a
            # bsd||gnu chain captures "File: ...\nID: ...\n<epoch>" and the arithmetic below dies
            # with "File: unbound variable" under `set -u`. BSD's `stat -c` fails with empty stdout.
            _cdiv_mtime_epoch=$(stat -c %Y "$_cdiv_latest" 2>/dev/null || stat -f %m "$_cdiv_latest" 2>/dev/null || true)
            if [[ -n "$_cdiv_name_epoch" && -n "$_cdiv_mtime_epoch" ]]; then
                CLOCK_DELTA=$(( _cdiv_mtime_epoch - _cdiv_name_epoch ))
                (( CLOCK_DELTA < 0 )) && CLOCK_DELTA=$(( -CLOCK_DELTA ))
                (( CLOCK_DELTA > 300 )) && CLOCK_DIVERGED=true
            fi
        fi
    fi
fi

# Write status=idle + session fields + has_uncommitted_changes + clock_divergence to
# state.json (same atomic tmp+mv write this hook already uses for every other field).
_cur_state=$(_borg_state_read "$PROJ_DIR")
_new_state=$(printf '%s' "$_cur_state" | jq \
    --arg sid "$SESSION_ID" \
    --arg now "$NOW" \
    --argjson dirty "$DIRTY_FLAG" \
    --argjson diverged "$CLOCK_DIVERGED" \
    --argjson delta "$CLOCK_DELTA" \
    '.status = "idle" | .last_activity = $now |
     .has_uncommitted_changes = $dirty |
     .clock_divergence = {detected: $diverged, delta_seconds: $delta} |
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

exit 0
