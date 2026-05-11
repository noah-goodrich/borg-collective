#!/usr/bin/env bash
# borg-link-down.sh — Claude Code / Cortex Code SessionStart hook
# "Link down" from the collective: download state INTO the session when it begins.
#
# Consolidates all SessionStart context injection:
# - Registry update: status=active, session_id
# - Git context: branch, uncommitted changes, recent commits
# - Docker container status
# - Plan-mode nudge (if no PROJECT_PLAN.md)
# - Uncommitted-changes reminder from previous session
# - Latest checkpoint from .borg/checkpoints/ (written by /borg-link-up)
# - Cairn knowledge (if available)
#
# Registered as a SessionStart hook in ~/.claude/settings.json

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

MODE=$(_borg_session_mode "$CWD")

# ── Orchestrator-mode branch ─────────────────────────────────────────────────
# When CWD is the workspace root (default $HOME/dev), render a scannable
# cross-project overview AS additionalContext. Write nothing to the registry —
# the orchestrator session is not a project session.
_orch_humanize_age() {
    local ts="$1"
    [[ -z "$ts" ]] && { printf 'never'; return; }
    local epoch_now epoch_ts delta
    epoch_now=$(date -u +%s)
    # macOS BSD date and GNU date both accept ISO-8601 with -j -f / -d respectively.
    epoch_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null \
        || date -u -d "$ts" +%s 2>/dev/null || echo "$epoch_now")
    delta=$(( epoch_now - epoch_ts ))
    (( delta < 60 ))    && { printf '%ds ago' "$delta"; return; }
    (( delta < 3600 ))  && { printf '%dm ago' $(( delta / 60 )); return; }
    (( delta < 86400 )) && { printf '%dh ago' $(( delta / 3600 )); return; }
    printf '%dd ago' $(( delta / 86400 ))
}

_orch_next_hint() {
    local proj_path="$1"
    [[ -z "$proj_path" || ! -d "$proj_path" ]] && { printf '(idle)'; return; }
    local cp next_line dir_file dname
    cp=$(find "$proj_path/.borg/checkpoints" -maxdepth 1 -name "*.md" 2>/dev/null \
        | sort -r | head -1 || true)
    if [[ -n "$cp" && -f "$cp" ]]; then
        next_line=$(awk '
            /^## .*[Nn]ext [Ss]ession/ { found=1; next }
            found && /^## / { exit }
            found && /^[^[:space:]#]/ { print; exit }
        ' "$cp" 2>/dev/null | head -c 160 || true)
        if [[ -n "$next_line" ]]; then
            printf 'next: %s' "$next_line"
            return
        fi
    fi
    dir_file=$(find "$proj_path/docs/plans/directives" -maxdepth 1 -name "*.md" 2>/dev/null \
        | sort -r | head -1 || true)
    if [[ -n "$dir_file" ]]; then
        dname="${dir_file##*/}"
        printf 'directive: %s' "${dname%.md}"
        return
    fi
    printf '(idle)'
}

if [[ "$MODE" == "orchestrator" ]]; then
    OVERVIEW=""
    if [[ -f "$BORG_REGISTRY" ]]; then
        # Build a sorted list (last_activity desc), skipping archived projects.
        # For each project: status, humanized last-active, and a single next-step hint.
        _projects_tsv=$(jq -r '
            .projects // {} | to_entries
            | map(select(.value.archived // false | not))
            | sort_by(.value.last_activity // "")
            | reverse
            | .[]
            | [.key, (.value.status // "idle"), (.value.last_activity // ""), (.value.path // "")]
            | @tsv
        ' "$BORG_REGISTRY" 2>/dev/null || true)

        _proj_count=$(printf '%s\n' "$_projects_tsv" | grep -c . 2>/dev/null || echo 0)
        OVERVIEW+="Orchestrator session — workspace overview (${_proj_count} projects)"$'\n\n'
        if [[ -n "$_projects_tsv" ]]; then
            while IFS=$'\t' read -r _name _status _last _path; do
                [[ -z "$_name" ]] && continue
                _age=$(_orch_humanize_age "$_last")
                _hint=$(_orch_next_hint "$_path")
                OVERVIEW+="  • ${_name} [${_status}] — ${_age} — ${_hint}"$'\n'
            done <<< "$_projects_tsv"
        else
            OVERVIEW+="  (no projects registered — run 'borg add <path>' or 'borg scan')"$'\n'
        fi
    else
        OVERVIEW="Orchestrator session — registry not initialized. Run 'borg setup'."
    fi

    jq -n --arg ctx "$OVERVIEW" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx
        }
    }'
    exit 0
fi

# ── Project-mode (existing behavior) ─────────────────────────────────────────

PROJECT=$(_borg_find_project "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── 0. CLAUDE.md integrity check ─────────────────────────────────────────────
# Skip inside containers — ~/.claude is bind-mounted from the host, and applying
# container-path extensions would pollute the host's CLAUDE.md with /home/dev/... paths.
if [[ ! -f /.dockerenv ]]; then
    _borg_sync_file \
        "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/claude/code/CLAUDE.md" \
        "$HOME/.claude/CLAUDE.md"
    _borg_apply_claude_extensions
fi

# ── 1. Registry update ───────────────────────────────────────────────────────

if [[ -f "$BORG_REGISTRY" ]]; then
    TMP="$BORG_REGISTRY.tmp.$$"
    jq \
        --arg p "$PROJECT" \
        --arg sid "$SESSION_ID" \
        --arg now "$NOW" \
        '
        if .projects | has($p) then
            .projects[$p].status = "active" |
            .projects[$p].last_activity = $now |
            (if $sid != "" then .projects[$p].claude_session_id = $sid else . end)
        else .
        end
        ' "$BORG_REGISTRY" | _borg_strip_ctl > "$TMP" && mv "$TMP" "$BORG_REGISTRY" || true
fi

# ── 1b. Per-project skill overlay ────────────────────────────────────────────
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
PROJECT_SKILLS_DIR="$CWD/.borg/skills"
if [[ -d "$PROJECT_SKILLS_DIR" ]]; then
    mkdir -p "$CLAUDE_SKILLS_DIR"
    for _skill_dir in "$PROJECT_SKILLS_DIR"/*/; do
        [[ -d "$_skill_dir" ]] || continue
        _skill_name="${_skill_dir%/}"
        _skill_name="${_skill_name##*/}"
        ln -sfn "$_skill_dir" "$CLAUDE_SKILLS_DIR/$_skill_name" 2>/dev/null || true
    done
fi

# ── 2. Build context ─────────────────────────────────────────────────────────

CONTEXT_PARTS=()

# Git context (branch, status, recent commits)
if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    git_ctx=""
    branch=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "detached")
    git_ctx+="Git branch: $branch"$'\n'

    status=$(git -C "$CWD" status --short 2>/dev/null | head -20 || true)
    if [[ -n "$status" ]]; then
        git_ctx+="Uncommitted changes:"$'\n'"$status"$'\n'
    fi

    recent=$(git -C "$CWD" log --oneline -5 2>/dev/null || true)
    if [[ -n "$recent" ]]; then
        git_ctx+="Recent commits:"$'\n'"$recent"$'\n'
    fi

    CONTEXT_PARTS+=("$git_ctx")
fi

# Docker container status
container=$(docker ps --filter "label=dev.role=app" --format '{{.Names}}' 2>/dev/null | head -1 || true)
if [[ -n "$container" ]]; then
    CONTEXT_PARTS+=("Devcontainer running: $container")
fi

# Plan-mode nudge: fire when no PROJECT_PLAN.md exists
if [[ -n "$CWD" && ! -f "$CWD/PROJECT_PLAN.md" ]]; then
    CONTEXT_PARTS+=("WORKFLOW REQUIREMENT — NO PROJECT_PLAN.md FOUND

Before writing any code this session:
1. Switch to Opus: /model opus
2. Enter Plan Mode: Shift+Tab
3. Run /borg-plan to establish objectives and acceptance criteria
4. Confirm the plan (creates PROJECT_PLAN.md in the project root)
5. Exit Plan Mode: Shift+Tab
6. Switch to Sonnet: /model sonnet
7. Only then begin implementation

If this is exploratory/investigative work with no deliverable, state that explicitly
and you may proceed without /borg-plan.")
fi

# Uncommitted-changes reminder from previous session
if [[ -f "$BORG_REGISTRY" ]]; then
    UNCOMMITTED_FLAG=$(jq -r --arg p "$PROJECT" \
        '.projects[$p].has_uncommitted_changes // false' "$BORG_REGISTRY" 2>/dev/null || echo "false")
    if [[ "$UNCOMMITTED_FLAG" == "true" ]]; then
        CONTEXT_PARTS+=("REMINDER: Last session ended with uncommitted changes in $PROJECT.
Run 'git status' to see what's pending. Consider /simplify and committing before new work.")
    fi
fi

# Active directives for this project — inject filename + objective line only (no full bodies)
DIRECTIVES_DIR="$CWD/docs/plans/directives"
if [[ -d "$DIRECTIVES_DIR" ]]; then
    _directive_lines=""
    while IFS= read -r -d '' _dfile; do
        _dname="${_dfile##*/}"
        # Extract the first non-blank line that is a heading or italic text after the H1;
        # prefer the ## Objective section's first content line as the summary.
        _obj=$(awk '
            /^## Objective/ { found=1; next }
            found && /^[^#[:space:]]/ { print; exit }
            found && /^[[:space:]]*$/ { next }
        ' "$_dfile" 2>/dev/null | head -c 200 || true)
        if [[ -z "$_obj" ]]; then
            # Fallback: first non-blank non-heading non-italic-meta line
            _obj=$(grep -m1 '^[^#*[:space:]]' "$_dfile" 2>/dev/null | head -c 200 || true)
        fi
        if [[ -n "$_obj" ]]; then
            _directive_lines+="  - ${_dname}: ${_obj}"$'\n'
        else
            _directive_lines+="  - ${_dname}"$'\n'
        fi
    done < <(find "$DIRECTIVES_DIR" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
    if [[ -n "$_directive_lines" ]]; then
        CONTEXT_PARTS+=("Active directives for $PROJECT (check these before starting new work):

${_directive_lines%$'\n'}")
    fi
fi

# Latest checkpoint for this project — written by /borg-link-up
CHECKPOINT_FILE=""
if [[ -d "$CWD/.borg/checkpoints" ]]; then
    CHECKPOINT_FILE=$(find "$CWD/.borg/checkpoints" -maxdepth 1 -name "*.md" 2>/dev/null | sort -r | head -1 || true)
fi
if [[ -n "$CHECKPOINT_FILE" && -f "$CHECKPOINT_FILE" ]]; then
    CHECKPOINT=$(head -c 4000 "$CHECKPOINT_FILE" 2>/dev/null || true)
    if [[ -n "$CHECKPOINT" ]]; then
        CP_BASENAME="${CHECKPOINT_FILE##*/}"
        CONTEXT_PARTS+=("Latest checkpoint for $PROJECT ($CP_BASENAME):

$CHECKPOINT")
    fi
fi

# Cairn knowledge (optional) — with health check and failure surfacing
CAIRN_FAILED_FLAG="${BORG_DIR}/.cairn-write-failed"

if ! command -v cairn >/dev/null 2>&1; then
    CONTEXT_PARTS+=("⚠ CAIRN UNAVAILABLE: cairn not found in PATH.
Cross-session knowledge is not being persisted to the graph. Checkpoints still save locally.
To fix: ensure cairn is installed and in your PATH, then run 'borg setup'.")
else
    # Surface any write failure from the previous session stop
    if [[ -f "$CAIRN_FAILED_FLAG" ]]; then
        _fail_msg=$(cat "$CAIRN_FAILED_FLAG" 2>/dev/null || true)
        CONTEXT_PARTS+=("⚠ CAIRN WRITE FAILED (last session): ${_fail_msg}
The session was NOT committed to the knowledge graph.
Check cairn service health: cairn status")
        rm -f "$CAIRN_FAILED_FLAG"
    fi

    if command -v timeout >/dev/null 2>&1; then
        CAIRN_OUT=$(timeout 5 cairn search "$PROJECT" --project "$PROJECT" --max 5 2>/dev/null || true)
    else
        CAIRN_OUT=$(cairn search "$PROJECT" --project "$PROJECT" --max 5 2>/dev/null || true)
    fi
    # Log hit metrics for the 4-week validation window
    CAIRN_BYTES=$(printf '%s' "$CAIRN_OUT" | wc -c | tr -d ' ')
    printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT" "$CAIRN_BYTES" \
        >> "${BORG_DIR}/cairn-hits.log" 2>/dev/null || true

    if [[ -n "$CAIRN_OUT" ]]; then
        CONTEXT_PARTS+=("Cairn knowledge for $PROJECT:

$CAIRN_OUT")
    else
        CONTEXT_PARTS+=("ℹ Cairn has no data for $PROJECT yet.
Sessions will be committed to cairn after this session ends.")
    fi
fi

# ── 3. Output ─────────────────────────────────────────────────────────────────

if (( ${#CONTEXT_PARTS[@]} > 0 )); then
    FULL_CTX="${CONTEXT_PARTS[0]}"
    for _part in "${CONTEXT_PARTS[@]:1}"; do
        FULL_CTX="${FULL_CTX}

---

${_part}"
    done
    jq -n --arg ctx "$FULL_CTX" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx
        }
    }'
fi

exit 0
