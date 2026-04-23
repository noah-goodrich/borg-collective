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

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh"

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

exit 0
