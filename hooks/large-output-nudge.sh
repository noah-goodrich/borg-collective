#!/usr/bin/env bash
# large-output-nudge.sh — PostToolUse hook (Bash, Read): tell the model when a result was expensive.
#
# Tool output stays in context and is re-read on every later call. Claude Code's own cap
# (BASH_MAX_OUTPUT_LENGTH, default 30000 chars) only truncates; nothing tells the model it just did something
# costly, so the habit never corrects. Over BORG_LARGE_OUTPUT_CHARS (default 8000) this emits
# hookSpecificOutput.additionalContext naming the char count and the first 80 chars of the command or path.
#
# Plugin hooks fire in EVERY session, after every Bash and Read, so this is ONE jq process and nothing else:
# no python, no sed/grep/tr forks, no state files. Silent below the threshold. Fail open: malformed input, a
# missing jq or an unexpected payload shape all exit 0 with no output. No `set -e` by design.

command -v jq >/dev/null 2>&1 || exit 0

jq -c '
    def chars:
        if type == "string" then length
        elif type == "object" then
            if (.file.content | type) == "string" then (.file.content | length)
            elif (.stdout != null or .stderr != null) then
                (((.stdout // "") | tostring | length) + ((.stderr // "") | tostring | length))
            elif (.content | type) == "string" then (.content | length)
            elif (.content | type) == "array" then ([.content[]? | (.text // "" | tostring | length)] | add // 0)
            else (tojson | length) end
        elif type == "array" then ([.[]? | (.text // "" | tostring | length)] | add // 0)
        else 0 end;
    (($ENV.BORG_LARGE_OUTPUT_CHARS // "") | tonumber? // 8000) as $limit
    | (.tool_response | chars) as $n
    | select($n > $limit)
    | ((.tool_input.command // .tool_input.file_path // "") | tostring | gsub("[\r\n\t]+"; " ") | .[0:80]) as $what
    | {hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext:
        ("That result was \($n) chars from `\($what)`. It stays in context and is re-read on every later call. "
         + "Narrow the next read: `-q`, a `jq` slice, `head`/`tail`, or a scout.")}}
' 2>/dev/null

exit 0
