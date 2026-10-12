#!/usr/bin/env bash
# borg-resume-hook.sh -- thin forwarder from Claude Code hook events to the borg-resume ledger (slice S4).
#
# Registered (timeout 5) for SessionStart, SessionEnd, SubagentStart, SubagentStop, StopFailure, Notification and
# PreToolUse/PostToolUse matched on Agent|Workflow. Stop and UserPromptSubmit are deliberately NOT hooked.
# The event name arrives as $1 (the Claude Code event); the payload arrives on stdin.
#
# Contract: hooks only APPEND facts. This script never emits a decision, never prints, never transitions state,
# and ALWAYS exits 0 (no set -e on purpose). Its own failures are swallowed into resume/hook.log. It stays
# self-contained: it sources nothing, so the plugin mirror can ship it as-is (also inside drone containers, where
# the guard "borg on PATH" used by the other hooks would wrongly turn it off).
#
# Kill switch: BORG_RESUME_DISABLE=1 exits before anything is read. The DISABLED sentinel pauses INJECTION only;
# recording continues, so `borg-resume record` applies that half (S1 contract).

_ev="${1:-}"
[ -n "${HOME:-}" ] || exit 0
[ "${BORG_RESUME_DISABLE:-}" = "1" ] && exit 0

# A hook can run with a bare environment: make jq (Homebrew) and the user's bin findable.
PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"

_bin="$HOME/.claude/bin/borg-resume"
[ -x "$_bin" ] || exit 0

_payload="$(cat 2>/dev/null)"
[ -n "$_payload" ] || exit 0

case "$_ev" in
    SessionStart) _le="session_start" ;;
    SessionEnd) _le="session_end" ;;
    SubagentStart) _le="agent_start" ;;
    SubagentStop) _le="agent_stop" ;;
    StopFailure) _le="stop_failure" ;;
    PreToolUse) _le="dispatch_intent" ;;
    PostToolUse) _le="dispatch_bound" ;;
    Notification)
        # The only event that needs the payload to pick the ledger event. Anything unrecognized records nothing.
        command -v jq >/dev/null 2>&1 || exit 0
        _nt="$(printf '%s' "$_payload" | jq -r '.notification_type // empty' 2>/dev/null)"
        case "$_nt" in
            idle_prompt) _le="idle_prompt" ;;
            permission_prompt) _le="permission_prompt" ;;
            quota_auto_resume_*) _le="native_resume" ;;
            *) exit 0 ;;
        esac
        ;;
    *) exit 0 ;;
esac

# claude is this script's parent; borg-resume runs as our child, so hand the pid over explicitly.
{ printf '%s' "$_payload" | BORG_RESUME_CLAUDE_PID="$PPID" "$_bin" record "$_le" >/dev/null 2>&1; } 2>/dev/null
_rc=$?
if [ "$_rc" -ne 0 ]; then
    _dir="${BORG_RESUME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/resume}"
    _log="$_dir/hook.log"
    {
        mkdir -p "$_dir"
        # Keep the log bounded without a rotation dependency: drop it when it passes ~64KB.
        [ "$(wc -c <"$_log" 2>/dev/null || echo 0)" -gt 65536 ] && rm -f "$_log"
        printf '%s %s rc=%s\n' "$(date +%s)" "$_le" "$_rc" >>"$_log"
    } 2>/dev/null
fi
exit 0
