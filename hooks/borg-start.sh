#!/usr/bin/env bash
# borg-start.sh — Claude Code SessionStart hook
# Fires when a Claude Code session begins.
#
# Consolidates all SessionStart context injection:
# - Registry update: status=active, session_id
# - Git context: branch, uncommitted changes, recent commits
# - Docker container status
# - Plan-mode nudge (if no PROJECT_PLAN.md)
# - Uncommitted-changes reminder from previous session
# - Last session debrief
# - Cairn knowledge (if available)
#
# Registered as a SessionStart hook in ~/.claude/settings.json

set -euo pipefail

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

PROJECT=$(basename "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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
        ' "$BORG_REGISTRY" > "$TMP" && mv "$TMP" "$BORG_REGISTRY" || true
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
1. Run /borg-plan to establish objectives and acceptance criteria
2. Confirm the plan (creates PROJECT_PLAN.md in the project root)
3. Only then begin implementation

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

# Last session debrief
DEBRIEF_FILE="$BORG_DIR/debriefs/${PROJECT}.md"
if [[ -f "$DEBRIEF_FILE" ]]; then
    DEBRIEF=$(head -c 4000 "$DEBRIEF_FILE" 2>/dev/null || true)
    if [[ -n "$DEBRIEF" ]]; then
        CONTEXT_PARTS+=("Last session debrief for $PROJECT:

$DEBRIEF")
    fi
fi

# Cairn knowledge (optional)
if command -v cairn >/dev/null 2>&1; then
    CAIRN_OUT=$(timeout 5 cairn search "$PROJECT" --project "$PROJECT" --max 5 2>/dev/null || true)
    if [[ -n "$CAIRN_OUT" ]]; then
        CONTEXT_PARTS+=("Cairn knowledge for $PROJECT:

$CAIRN_OUT")
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
