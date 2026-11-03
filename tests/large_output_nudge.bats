#!/usr/bin/env bats
# hooks/large-output-nudge.sh: PostToolUse(Bash|Read) nudge when a tool result is over BORG_LARGE_OUTPUT_CHARS.
# Issue #501 (fix 3 of #500). Tier 1: deterministic, offline. Tier 2 (live claude -p) is run by hand, see the PR.
#
# Payload shapes below match what Claude Code sends: Bash tool_response is an object with stdout and stderr, Read
# is an object with file.content. A bare string is accepted too. Runs in a sandbox HOME; the hook touches no state.

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."
HOOK="$ROOT/hooks/large-output-nudge.sh"
BUILD_PLUGIN="$ROOT/scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    command -v jq >/dev/null || skip "jq not installed"
    unset BORG_LARGE_OUTPUT_CHARS
}

_filler() { head -c "$1" /dev/zero | tr '\0' x; }

_bash_payload() { # <chars> <command>
    jq -n --arg out "$(_filler "$1")" --arg c "$2" \
        '{session_id:"s", hook_event_name:"PostToolUse", tool_name:"Bash",
          tool_input:{command:$c}, tool_response:{stdout:$out, stderr:"", interrupted:false}}'
}

_read_payload() { # <chars> <path>
    jq -n --arg out "$(_filler "$1")" --arg p "$2" \
        '{session_id:"s", hook_event_name:"PostToolUse", tool_name:"Read",
          tool_input:{file_path:$p}, tool_response:{type:"text", file:{filePath:$p, content:$out}}}'
}

_run() { # <payload>
    printf '%s' "$1" >"$BATS_TEST_TMPDIR/payload.json"
    run bash -c "bash '$HOOK' < '$BATS_TEST_TMPDIR/payload.json'"
}

@test "Bash: a 20k-char result nudges with the count and the command" {
    _run "$(_bash_payload 20000 'git diff --stat origin/main')"
    [ "$status" -eq 0 ]
    run jq -r '.hookSpecificOutput.hookEventName' <<<"$output"
    [ "$output" = "PostToolUse" ]
    _run "$(_bash_payload 20000 'git diff --stat origin/main')"
    ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")"
    [[ "$ctx" == *"20000 chars"* ]]
    [[ "$ctx" == *"git diff --stat origin/main"* ]]
    [[ "$ctx" == *"jq"* && "$ctx" == *"head"* && "$ctx" == *"scout"* ]]
}

@test "Read: a 20k-char file nudges with the count and the path" {
    _run "$(_read_payload 20000 /repo/some/big/file.json)"
    [ "$status" -eq 0 ]
    ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")"
    [[ "$ctx" == *"20000 chars"* ]]
    [[ "$ctx" == *"/repo/some/big/file.json"* ]]
}

@test "a 2k-char result stays silent" {
    _run "$(_bash_payload 2000 'ls')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    _run "$(_read_payload 2000 /repo/small.txt)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "stderr counts toward the size" {
    _run "$(jq -n --arg e "$(_filler 9000)" '{tool_name:"Bash",tool_input:{command:"x"},
        tool_response:{stdout:"", stderr:$e}}')"
    [[ "$output" == *"9000 chars"* ]]
}

@test "the command is cut to its first 80 chars and newlines flattened" {
    local long
    long="$(printf 'a%.0s' $(seq 1 120))"
    _run "$(_bash_payload 20000 "$long")"
    ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")"
    [[ "$ctx" == *"\`$(printf 'a%.0s' $(seq 1 80))\`"* ]]
    [[ "$ctx" != *"$(printf 'a%.0s' $(seq 1 81))"* ]]
    _run "$(_bash_payload 20000 $'echo one\necho two')"
    ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$output")"
    [[ "$ctx" == *'`echo one echo two`'* ]]
}

@test "malformed JSON and empty input exit 0 with no output" {
    _run '{"tool_response": {"stdout": "unterminated'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    _run ''
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    _run '{"tool_name":"Bash"}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "BORG_LARGE_OUTPUT_CHARS changes the threshold, and garbage falls back to 8000" {
    local p
    p="$(_bash_payload 2000 'ls')"
    BORG_LARGE_OUTPUT_CHARS=1000 _run "$p"
    [[ "$output" == *"2000 chars"* ]]
    p="$(_bash_payload 20000 'ls')"
    BORG_LARGE_OUTPUT_CHARS=50000 _run "$p"
    [ -z "$output" ]
    BORG_LARGE_OUTPUT_CHARS=banana _run "$p"
    [[ "$output" == *"20000 chars"* ]]
    p="$(_bash_payload 7000 'ls')"
    BORG_LARGE_OUTPUT_CHARS=banana _run "$p"
    [ -z "$output" ]
}

@test "latency: within 50ms per call, the resume hook's budget (host-measured)" {
    command -v perl >/dev/null || skip "perl needed for ms timing"
    local scale="${BORG_RESUME_HOOK_BUDGET_SCALE:-1}" best=999999 i s e d p
    p="$(_bash_payload 20000 'git diff --stat')"
    for i in 1 2 3 4 5; do
        s="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')"
        printf '%s' "$p" | "$HOOK" >/dev/null 2>&1
        e="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')"
        d=$((e - s))
        [ "$d" -lt "$best" ] && best=$d
    done
    echo "# large-output-nudge: ${best}ms (budget $((50 * scale))ms)" >&3
    [ "$best" -le $((50 * scale)) ]
}

@test "hygiene: executable, bash 3.2 syntax, no set -e, no source, one jq and nothing else" {
    [ -x "$HOOK" ]
    run /bin/bash -n "$HOOK"
    [ "$status" -eq 0 ]
    ! grep -qE '^[[:space:]]*set -[a-z]*e' "$HOOK"
    ! grep -qE '^[[:space:]]*(source|\.)[[:space:]]' "$HOOK"
    ! grep -qE '(python|sed |awk |tr |\$\()' <(grep -v '^[[:space:]]*#' "$HOOK")
}

@test "wiring: hooks.json registers it on PostToolUse Bash|Read and the built copy is identical" {
    export BORG_ORCHESTRATOR_ROOT="$BORG_TEST_HOME/dev"
    export PLUGIN_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/claude-plugins/borg-collective"
    mkdir -p "$PLUGIN_DIR_OVERRIDE"
    run "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    local hj="$PLUGIN_DIR_OVERRIDE/hooks/hooks.json"
    run jq -r '[.hooks.PostToolUse[] | select(.hooks[0].command | contains("large-output-nudge"))
        | .matcher] | join(",")' "$hj"
    [ "$output" = "Bash|Read" ]
    run jq -e '[.hooks | to_entries[] | select(.key != "PostToolUse") | .value[].hooks[].command
        | select(contains("large-output-nudge"))] | length == 0' "$hj"
    [ "$status" -eq 0 ]
    [ -x "$PLUGIN_DIR_OVERRIDE/hooks/large-output-nudge.sh" ]
    run diff "$HOOK" "$PLUGIN_DIR_OVERRIDE/hooks/large-output-nudge.sh"
    [ "$status" -eq 0 ]
}

@test "rules: the three narrow-read lines are in the borg-managed source" {
    local f="$ROOT/config/claude/CLAUDE.md"
    grep -q '`-q`.*`git commit`.*`git push`' "$f"
    grep -q '`--stat`.*`tail -n`' "$f"
    grep -q 'Never `find` under `/private/tmp`' "$f"
}
