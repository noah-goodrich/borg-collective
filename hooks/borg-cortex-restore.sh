#!/usr/bin/env bash
# borg-cortex-restore.sh — Cortex Code CLI only (not in build-plugin.sh; #516 S3).
#
# Cortex does not deliver SessionStart additionalContext to its model, but UserPromptSubmit additionalContext does
# (docs/evidence/2026-11-03-cortex-hook-probe.md). So the checkpoint restore that borg-link-down.sh builds rides in on
# the first prompt of a session instead: this hook runs the builder on a SessionStart-shaped copy of the payload and
# re-emits its context under UserPromptSubmit.
#
# Registered twice, same script:
#   UserPromptSubmit: emit the restore once per session; a marker file keyed by session_id records that it was sent.
#   SessionStart:     on source "compact" delete the marker, so the next prompt restores again. Any other source: no-op.
#
# Fail open: every error path exits 0 with no output. A prompt is never blocked.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat 2>/dev/null || true)
FIELDS=$(printf '%s' "$INPUT" | jq -r '[.session_id // "", .hook_event_name // "", .source // ""] | join("\u001f")' 2>/dev/null) || exit 0
IFS=$'\037' read -r SESSION_ID EVENT SOURCE <<< "$FIELDS" || true

# The id becomes a file name: accept only a plain token.
[[ "$SESSION_ID" =~ ^[A-Za-z0-9._-]+$ && "$SESSION_ID" != .* ]] || exit 0

MARKER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg/cortex-restore"
MARKER="$MARKER_DIR/$SESSION_ID"

case "$EVENT" in
    SessionStart)
        [[ "$SOURCE" == "compact" ]] && rm -f "$MARKER" 2>/dev/null
        exit 0
        ;;
    UserPromptSubmit) ;;
    *) exit 0 ;;
esac

[[ -e "$MARKER" ]] && exit 0

BUILDER="${BASH_SOURCE[0]%/*}/borg-link-down.sh"
[[ -f "$BUILDER" ]] || exit 0

# Mark first-run done whether or not the builder had anything to say, so a failing builder costs one run, not one per prompt.
{ mkdir -p "$MARKER_DIR" && : > "$MARKER"; } 2>/dev/null || exit 0

CONTEXT=$(printf '%s' "$INPUT" | jq -c '.hook_event_name = "SessionStart" | .source = "startup"' 2>/dev/null \
    | bash "$BUILDER" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null) || exit 0
[[ -n "$CONTEXT" ]] || exit 0

jq -n --arg ctx "$CONTEXT" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}' 2>/dev/null || true
exit 0
