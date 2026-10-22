#!/usr/bin/env bash
# borg-plan-promote.sh — PreToolUse hook: auto-promote in-session plan to PROJECT_PLAN.md
#
# Fires on Edit, Write, NotebookEdit tool calls (and Cortex Code CLI's lowercase edit, write).
# When Claude Code exits plan mode (ExitPlanMode) and the user proceeds to implementation, this hook captures the plan
# and writes it to docs/plans/PROJECT_PLAN.md before the first file edit — silently,
# without blocking.
#
# Gates:
#   1. Repository-mode only (not orchestrator).
#   2. Edit target must be inside the repo working tree.
#   3. cwd must be a git repo (used to find repo root).
#   4. No existing PROJECT_PLAN.md at either canonical location.
#   5. Session JSONL must contain an ExitPlanMode tool call since the most recent
#      non-meta user message (i.e. the current user turn).
#
# Cortex Code CLI branch (PostToolUse on ExitPlanMode): Cortex's transcript is a conversations/<id>.json file, not
# the Claude JSONL gate 5 reads, so the branch below reads the plan from tool_input.plan instead. It applies gates 1,
# 3 and 4, writes docs/plans/PROJECT_PLAN.md, and also overwrites the team plan file .cortex/plans/plan-<task-id>.md
# the response names (never the plan_<timestamp>.md files Cortex writes itself). The Claude path is unchanged.
#
# Always exits 0 — never blocks. On any unexpected failure, logs a debug line to
# ~/.local/state/borg/plan-promote-debug.log and exits 0.
#
# Registered as a PreToolUse hook in ~/.claude/settings.json, and in Cortex's hooks.json as PreToolUse (no-op there,
# Cortex payloads fail gate 5) and as PostToolUse on ExitPlanMode|exit_plan_mode (the Cortex branch).

set -euo pipefail

PATH="${HOME}/.config/dotfiles/zsh/bin:${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
export PATH

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
DEBUG_LOG="$STATE_DIR/plan-promote-debug.log"

_debug() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    # Retention: cap the log at 1 MiB, one previous generation (_borg_rotate_log, lib/borg-hooks.sh).
    { type _borg_rotate_log >/dev/null 2>&1 && _borg_rotate_log "$DEBUG_LOG"; } 2>/dev/null || true
    printf '%s [borg-plan-promote] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$DEBUG_LOG" 2>/dev/null || true
}

INPUT=$(cat /dev/stdin 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)

[[ -z "$CWD" || -z "$SESSION_ID" ]] && exit 0

# ── Gate 1: repository-mode only ─────────────────────────────────────────────

# >>> borg-hooks.sh: script-relative first, installed copy second (build-plugin.sh inlines the lib over this block)
_borg_lib_dir="${BASH_SOURCE[0]%/*}"
[[ "$_borg_lib_dir" == "${BASH_SOURCE[0]}" ]] && _borg_lib_dir=.
_borg_lib="$_borg_lib_dir/../lib/borg-hooks.sh"
# The lib sources its reaper.sh sibling unguarded, and on bash 3.2 that failure kills the hook: usable = both files.
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] || _borg_lib="${HOME}/.claude/lib/borg-hooks.sh"
# shellcheck source=../lib/borg-hooks.sh
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] && source "$_borg_lib" 2>/dev/null || true
# <<< borg-hooks.sh
declare -F _borg_session_mode >/dev/null || exit 0

MODE=$(_borg_session_mode "$CWD")
[[ "$MODE" == "orchestrator" ]] && exit 0

# ── Cortex branch: PostToolUse ExitPlanMode carries the plan in tool_input.plan ───────────────────────────────
# Accept both tool-name spellings (Cortex payloads say ExitPlanMode; its own tool is exit_plan_mode).

HOOK_EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || true)
if [[ "$HOOK_EVENT" == "PostToolUse" ]]; then
    case "$TOOL_NAME" in
        ExitPlanMode|exit_plan_mode) ;;
        *) exit 0 ;;
    esac

    # Promote only when the user accepted: a rejected or "keep planning" exit has different response text.
    _resp=$(printf '%s' "$INPUT" | jq -r '.tool_response | tostring' 2>/dev/null || true)
    case "$_resp" in
        *"Plan mode has ended"*) ;;
        *) exit 0 ;;
    esac

    PLAN_TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input.plan // ""' 2>/dev/null || true)
    [[ -z "$PLAN_TEXT" ]] && exit 0

    # Gate 3: cwd must be a git repo.
    REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
    [[ -z "$REPO_ROOT" ]] && exit 0

    # Gate 4: no existing PROJECT_PLAN.md.
    PLAN_PRIMARY="${REPO_ROOT}/docs/plans/PROJECT_PLAN.md"
    if [[ -f "$PLAN_PRIMARY" || -f "${REPO_ROOT}/PROJECT_PLAN.md" ]]; then
        exit 0
    fi

    mkdir -p "${REPO_ROOT}/docs/plans" 2>/dev/null || {
        _debug "cortex: failed to create ${REPO_ROOT}/docs/plans"
        exit 0
    }
    {
        printf '<!-- auto-promoted from session plan by borg-plan-promote.sh at %s -->\n\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        printf '%s\n' "$PLAN_TEXT"
    } > "$PLAN_PRIMARY" 2>/dev/null || {
        _debug "cortex: failed to write $PLAN_PRIMARY"
        exit 0
    }
    _debug "cortex: promoted plan to $PLAN_PRIMARY"

    # Team mode: workers implement from .cortex/plans/plan-<task-id>.md (hyphen), which keeps Cortex's native plan.
    # The response names it after "Plan saved to" in backticks. Only a plan-*.md under <repo>/.cortex/plans/ is
    # touched; the plan_<timestamp>.md files (underscore) are Cortex's own and are left alone.
    # shellcheck disable=SC2016  # backticks and <date> in the text are literal, not expansions
    _team=$(printf '%s' "$_resp" | sed -n 's/.*Plan saved to `\([^`]*\)`.*/\1/p' | head -1)
    _team_dir="${_team%/*}"
    _team_base="${_team##*/}"
    case "$_team_base" in
        plan-*.md)
            case "$_team_dir" in
                *..*) _debug "cortex: team plan path has .., skipped" ;;
                "${REPO_ROOT}/.cortex/plans"|"${CWD}/.cortex/plans")
                    if [[ -d "$_team_dir" ]]; then
                        printf '%s\n' "$PLAN_TEXT" > "$_team" 2>/dev/null \
                            && _debug "cortex: synced team plan $_team_base" \
                            || _debug "cortex: failed to write team plan $_team_base"
                    fi
                    ;;
                *) _debug "cortex: team plan outside .cortex/plans, skipped" ;;
            esac
            ;;
    esac
    exit 0
fi

# ── Gate 2: edit target inside repo working tree ──────────────────────────────

_target_path=""
case "$TOOL_NAME" in
    # Claude Code names its tools Edit/Write; Cortex Code CLI names them in lowercase (edit/write).
    Edit|Write|edit|write)
        _target_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
        ;;
    NotebookEdit)
        _target_path=$(printf '%s' "$INPUT" | jq -r '.tool_input.notebook_path // ""' 2>/dev/null || true)
        ;;
    *)
        exit 0
        ;;
esac

[[ -z "$_target_path" ]] && exit 0

# Skip edits targeting .claude/ dirs or global config (outside repository)
case "$_target_path" in
    "${HOME}/.claude/"*|"${XDG_CONFIG_HOME:-$HOME/.config}/"*)
        exit 0
        ;;
esac

# ── Gate 3: cwd must be a git repo ───────────────────────────────────────────

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[[ -z "$REPO_ROOT" ]] && exit 0

# Normalize REPO_ROOT through realpath (resolves macOS /var → /private/var symlinks and
# other symlink chains). The CWD directory always exists so realpath can resolve it fully.
# We don't normalize the target path because it may not exist yet (about to be written).
# Instead we check if the target starts with CWD (raw) or REPO_ROOT (raw or resolved).
if command -v realpath >/dev/null 2>&1; then
    REPO_ROOT=$(realpath "$REPO_ROOT" 2>/dev/null || printf '%s' "$REPO_ROOT")
    _norm_cwd=$(realpath "$CWD" 2>/dev/null || printf '%s' "$CWD")
else
    _norm_cwd="$CWD"
fi

# Target must be under the repo root (matched against normalized OR raw CWD prefix to
# handle macOS symlink differences between what the hook input reports vs git's view).
_target_in_repo=0
case "$_target_path" in
    "${REPO_ROOT}/"*|"${REPO_ROOT}") _target_in_repo=1 ;;
    "${_norm_cwd}/"*|"${_norm_cwd}") _target_in_repo=1 ;;
    "${CWD}/"*|"${CWD}") _target_in_repo=1 ;;
esac
[[ "$_target_in_repo" -eq 0 ]] && exit 0

# ── Gate 4: no existing PROJECT_PLAN.md ──────────────────────────────────────

PLAN_PRIMARY="${REPO_ROOT}/docs/plans/PROJECT_PLAN.md"
PLAN_FALLBACK="${REPO_ROOT}/PROJECT_PLAN.md"

if [[ -f "$PLAN_PRIMARY" || -f "$PLAN_FALLBACK" ]]; then
    exit 0
fi

# ── Gate 5: find ExitPlanMode since last real user turn in session JSONL ─────

# Construct session JSONL path: encode CWD by replacing all / with -
_encoded_cwd="${CWD//\//-}"
JSONL_PATH="${HOME}/.claude/projects/${_encoded_cwd}/${SESSION_ID}.jsonl"

if [[ ! -f "$JSONL_PATH" ]]; then
    _debug "JSONL not found at $JSONL_PATH — skipping"
    exit 0
fi

# Use python3 (always available on macOS) to parse JSONL safely.
# We scan from the END of the file, working backward:
#   - First ExitPlanMode we encounter is our candidate.
#   - If we hit a non-meta user message before finding ExitPlanMode, stop
#     (plan was from a prior turn — don't re-promote).
#
# The python script is written as a here-string to a temp variable and run via
# python3 -c to avoid bash heredoc-inside-$() parsing issues with || operators.
_py_script='
import sys, json
path = sys.argv[1]
try:
    fh = open(path)
    lines = fh.readlines()
    fh.close()
except Exception:
    sys.exit(0)
plan = None
for line in reversed(lines):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    t = obj.get("type", "")
    if t == "user" and not obj.get("isMeta", False):
        break
    if t == "assistant":
        content = obj.get("message", {}).get("content", [])
        for item in content:
            if isinstance(item, dict) and item.get("name") == "ExitPlanMode":
                plan = item.get("input", {}).get("plan", "")
                break
        if plan is not None:
            break
if plan:
    sys.stdout.write(plan)
'

PLAN_TEXT=""
if command -v python3 >/dev/null 2>&1; then
    PLAN_TEXT=$(python3 -c "$_py_script" "$JSONL_PATH" 2>/dev/null) || PLAN_TEXT=""
fi

[[ -z "$PLAN_TEXT" ]] && exit 0

# ── Promote plan to docs/plans/PROJECT_PLAN.md ───────────────────────────────

PROMO_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCS_PLANS_DIR="${REPO_ROOT}/docs/plans"

mkdir -p "$DOCS_PLANS_DIR" 2>/dev/null || {
    _debug "Failed to create $DOCS_PLANS_DIR"
    exit 0
}

{
    printf '<!-- auto-promoted from session plan by borg-plan-promote.sh at %s -->\n\n' "$PROMO_TS"
    printf '%s\n' "$PLAN_TEXT"
} > "$PLAN_PRIMARY" 2>/dev/null || {
    _debug "Failed to write $PLAN_PRIMARY"
    exit 0
}

# PreToolUse stderr on exit 0 goes to the debug log only (https://code.claude.com/docs/en/hooks,
# "Exit code 0"). `systemMessage` is a universal JSON field shown to the user; deliberately NO
# permissionDecision, so tool flow is untouched. Plain text, one object, only on promotion.
jq -n '{systemMessage: "▸ borg: auto-promoted in-session plan to docs/plans/PROJECT_PLAN.md"}' 2>/dev/null || true

exit 0
