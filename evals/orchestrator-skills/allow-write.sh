#!/usr/bin/env bash
# A PermissionRequest hook for the break-glass live cases, and nothing else. live.sh hands it to the sandboxed claude through
# `--settings`. It allows an Edit or Write of EXACTLY the file named by $EVAL_ALLOW_WRITE (the sandbox repository's
# .claude/settings.local.json) and decides nothing about any other path or tool.
#
# WHY IT EXISTS. Measured 2026-11-03 on claude 2.1.300: a headless `-p` run under `--permission-mode acceptEdits` refuses
# to write .claude/settings.local.json ("Claude requested permissions to write to ..."), and an allow rule for that
# path, relative or absolute, does not lift it: the file is a protected path. A PreToolUse allow does not reach it
# either (the hook never fired for the Edit); the PermissionRequest event does, because it is raised exactly when the
# dialog a headless run cannot answer would have been shown. Without a grant BG1 would fail for a reason unrelated to
# the skill, the conflation rule 7 of docs/agents/testing-tiers.md names. `bypassPermissions` would lift every guard
# in the sandbox; this hook lifts one file.
#
# Reads the hook payload on stdin. Prints a JSON allow decision for the one path and nothing otherwise (no output means
# "no opinion": the normal permission flow runs). Always exits 0, so a parse failure can never block a tool.

set -u
payload="$(cat)"
want="${EVAL_ALLOW_WRITE:-}"
[ -n "$want" ] || exit 0
got="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [ -n "$got" ] && [ "$got" = "$want" ]; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
fi
exit 0
