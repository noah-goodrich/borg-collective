#!/usr/bin/env bash
# borg-cortex-plan.sh — Cortex Code CLI only: make plan mode follow borg-plan.
#
#   PostToolUse EnterPlanMode : print additionalContext telling the model to load the borg-plan skill and write the
#                               plan in the PROJECT_PLAN.md template (inject).
#   PreToolUse  ExitPlanMode  : exit 2 with a borg-plan message when the plan lacks Acceptance Criteria, Scope
#                               Boundaries (or a "NOT building" line) or a "- Plan-slug:" line (gate).
#
# The accepted plan is written to docs/plans/PROJECT_PLAN.md by borg-plan-promote.sh (its Cortex branch), not here.
# Not registered for Claude Code (build-plugin.sh does not ship it): `borg setup` registers it in Cortex's hooks.json
# with tool-name matchers. Cortex payloads name the tools EnterPlanMode/ExitPlanMode; the lowercase forms are accepted too.
# permission_mode stays "default" in Cortex plan mode, so nothing here branches on it.
#
# No-op (exit 0, no output) in the Queen session, outside a git repo, when docs/plans/PROJECT_PLAN.md or the root
# PROJECT_PLAN.md already exists, and when BORG_PLAN_GATE=off. Fails open on any unexpected condition; the only
# non-zero exit is the gate's deliberate exit 2.
# Evidence and design: docs/plans/directives/2026-10-22-borg-plan-in-cortex-plan-mode.md

PATH="${HOME}/.config/dotfiles/zsh/bin:${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"
export PATH

[[ "${BORG_PLAN_GATE:-}" == "off" ]] && exit 0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
DEBUG_LOG="$STATE_DIR/cortex-plan-debug.log"

_debug() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    { type _borg_rotate_log >/dev/null 2>&1 && _borg_rotate_log "$DEBUG_LOG"; } 2>/dev/null || true
    { printf '%s [borg-cortex-plan] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$DEBUG_LOG"; } 2>/dev/null || true
}

INPUT=$(cat /dev/stdin 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || true)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)

ACTION=""
case "$EVENT:$TOOL" in
    PostToolUse:EnterPlanMode|PostToolUse:enter_plan_mode) ACTION=inject ;;
    PreToolUse:ExitPlanMode|PreToolUse:exit_plan_mode) ACTION=gate ;;
    *) exit 0 ;;
esac
[[ -z "$CWD" ]] && exit 0

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

[[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]] && exit 0

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[[ -z "$REPO_ROOT" ]] && exit 0
if [[ -f "${REPO_ROOT}/docs/plans/PROJECT_PLAN.md" || -f "${REPO_ROOT}/PROJECT_PLAN.md" ]]; then
    exit 0
fi

if [[ "$ACTION" == "inject" ]]; then
    # shellcheck disable=SC2016  # backticks and <date> in the text are literal, not expansions
    CONTEXT='[borg] This repository plans with the borg-plan skill, so your plan must match its PROJECT_PLAN.md template. Before you call exit_plan_mode: load the borg-plan skill, then write the plan with these sections: Objective (1-2 sentences), Acceptance Criteria (each criterion followed by a "Verify:" line naming a command or file check), Scope Boundaries (lines starting "NOT building:"), Ship Definition, Timeline, Risks, and a line "- Plan-slug: `<date>-<short-slug>`". You may keep Cortex sections such as Context and Critical Files in addition. Do not write PROJECT_PLAN.md yourself: a hook promotes the accepted plan.'
    _debug "inject emitted cwd=$CWD"
    jq -n --arg c "$CONTEXT" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
    exit 0
fi

PLAN=$(printf '%s' "$INPUT" | jq -r '.tool_input.plan // ""' 2>/dev/null || true)
missing=""
printf '%s' "$PLAN" | grep -qi 'acceptance criteria' || missing="$missing Acceptance-Criteria"
printf '%s' "$PLAN" | grep -qiE 'scope boundaries|NOT building' || missing="$missing Scope-Boundaries"
printf '%s' "$PLAN" | grep -qiE '^[[:space:]]*-[[:space:]]*plan-slug:' || missing="$missing Plan-slug"
if [[ -n "$missing" ]]; then
    _debug "BLOCK missing:$missing cwd=$CWD"
    printf 'borg: plan rejected, missing:%s. Load the borg-plan skill, use its PROJECT_PLAN.md template (Objective, Acceptance Criteria with a Verify line each, Scope Boundaries, Ship Definition, Timeline, Risks, Plan-slug), then call exit_plan_mode again.\n' "$missing" >&2
    exit 2
fi
_debug "PASS cwd=$CWD"
exit 0
