#!/usr/bin/env bats
# ZERO-WRITE transcript judgement in hooks/borg-nanoprobe-log.sh: lag, malformed lines, git forms.

load test_helper/setup

setup() {
    setup_temp_dirs
    LOG_FILE="$XDG_STATE_HOME/borg/agents.jsonl"
    HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-nanoprobe-log.sh"
    TX="${BATS_TEST_TMPDIR}/t.jsonl"
}

_has() { [[ "$1" == *"$2"* ]] || { echo "missing: $2"; return 1; }; }

_run() {
    local in
    in=$(jq -nc --arg p "$TX" '{agent_id:"agent-wr123456",agent_type:"borg-nanoprobe",agent_transcript_path:$p,last_assistant_message:"Edited lib/foo.sh:10 done.",cwd:"/parent"}')
    rm -f "$LOG_FILE"
    HOOK_OUT=$(bash "$HOOK" <<< "$in" 2>/dev/null)
}

# _tx <name> <id> <is_error> [command]: a tool_use plus its tool_result.
_tx() {
    jq -nc --arg n "$1" --arg i "$2" --arg c "${4:-}" \
        '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:$i,name:$n,input:(if $c=="" then {file_path:"a.txt"} else {command:$c} end)}]}}' >> "$TX"
    jq -nc --arg i "$2" --argjson e "$3" \
        '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:$i,is_error:$e,content:"x"}]}}' >> "$TX"
}

# _pending <name> <id> [command]: a tool_use whose result is not flushed yet.
_pending() {
    jq -nc --arg n "$1" --arg i "$2" --arg c "${3:-}" \
        '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:$i,name:$n,input:(if $c=="" then {file_path:"a.txt"} else {command:$c} end)}]}}' >> "$TX"
}

@test "MultiEdit and NotebookEdit count as writes" {
    local n
    for n in MultiEdit NotebookEdit; do
        rm -f "$TX"
        _tx "$n" tu1 false
        _run
        [ -z "$HOOK_OUT" ]
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    done
}

@test "these Bash commands count as writes" {
    local c
    local -a cmds=(
        "git push origin fix/x"
        "git add -A && git commit -m x"
        "bash -c 'git commit -m x'"
        "git -c user.name=x commit -m x"
        "git --no-pager commit -m x"
        "git -C \"/some dir/wt\" commit -m x"
        "git -C '/some dir/wt' -c a=b --no-pager push"
        "(git commit -m x)"
    )
    for c in "${cmds[@]}"; do
        rm -f "$TX"
        _tx Bash tu1 false "$c"
        _run
        [ -z "$HOOK_OUT" ] || { echo "not counted: $c"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    done
}

@test "lookalike git commands do not count" {
    local c
    for c in "git status" "echo mygit commit" "git log --grep commit" "git commit-tree abc"; do
        rm -f "$TX"
        _tx Bash tu1 false "$c"
        _run
        _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE" || { echo "counted: $c"; return 1; }
    done
}

@test "an Edit with no tool_result yet counts as a write" {
    _pending Edit tu1
    _run
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}

@test "an Edit whose result is_error does not count, even beside a pending Read" {
    _tx Edit tu1 true
    _pending Read tu2
    _run
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
}

@test "a malformed line and a non-array content are tolerated" {
    printf '%s\n' '{not json' >> "$TX"
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"plain string"}}' >> "$TX"
    _tx Edit tu1 false
    _run
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    rm -f "$TX"
    printf '%s\n' '{not json' >> "$TX"
    _tx Read tu1 false
    _run
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
}
