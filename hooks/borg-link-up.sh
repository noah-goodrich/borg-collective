#!/usr/bin/env bash
# borg-link-up.sh — Claude Code / Cortex Code Stop hook
# "Link up" to the collective: flush state from the session when it ends.
#
# - Registry update: status=idle, claude_session_id, last_activity
# - Tracks has_uncommitted_changes for next session's reminder
# - Cleans up per-project skill overlays symlinked during link-down
# - Nudges on exit if no checkpoint was recorded this session ("run /borg-link-up next time")
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
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh"

# Orchestrator-mode sessions touch no project state. Exit before any registry
# writes, uncommitted-changes scans, or checkpoint nudges fire.
if [[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]]; then
    exit 0
fi

PROJECT=$(_borg_find_project "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Require registry to exist
[[ -f "$BORG_REGISTRY" ]] || exit 0

# Fast registry update: status=idle
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
    ' "$BORG_REGISTRY" | _borg_strip_ctl > "$TMP" && mv "$TMP" "$BORG_REGISTRY"

# Check for uncommitted changes: warn in terminal + store flag for next session
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

TMP2="$BORG_REGISTRY.tmp2.$$"
jq --arg p "$PROJECT" --argjson f "$DIRTY_FLAG" \
    'if .projects | has($p) then .projects[$p].has_uncommitted_changes = $f else . end' \
    "$BORG_REGISTRY" | _borg_strip_ctl > "$TMP2" && mv "$TMP2" "$BORG_REGISTRY"

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

# Record session to cairn knowledge graph (best-effort)
if command -v cairn >/dev/null 2>&1; then
    _cairn_id="$(date -u +%Y%m%d-%H%M)-${PROJECT}"
    _cairn_cmd=(cairn record session --id "$_cairn_id" --project "$PROJECT" --tool claude-code)
    if command -v timeout >/dev/null 2>&1; then
        timeout 5 "${_cairn_cmd[@]}" 2>/dev/null || printf '%s\n' \
            "cairn write failed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${BORG_DIR}/.cairn-write-failed"
    else
        "${_cairn_cmd[@]}" 2>/dev/null || printf '%s\n' \
            "cairn write failed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${BORG_DIR}/.cairn-write-failed"
    fi
fi

exit 0
