#!/usr/bin/env bash
# pre-commit-remind.sh — PreToolUse hook: nudge to run /simplify and /borg-assimilate before commit
# Fires on all Bash tool calls. Emits additionalContext reminder when command is git commit.
# Always exits 0 — reminder only, never blocks.

set -euo pipefail

INPUT=$(cat /dev/stdin 2>/dev/null || true)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

case "$COMMAND" in
    *"git commit"*)
        case "$COMMAND" in
            *"--dry-run"*) exit 0 ;;
        esac
        MSG="WORKFLOW REMINDER: About to commit. Have you run /simplify on the changed code this session? If yes, proceed. If not, run /simplify first — it catches reuse and quality issues before they land in git history."
        if [[ -n "$CWD" && -f "$CWD/PROJECT_PLAN.md" ]]; then
            MSG="$MSG Also: have you run /borg-assimilate to verify acceptance criteria are met?"
        fi
        jq -n --arg msg "$MSG" '{
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": $msg
            }
        }'
        ;;
esac

exit 0
