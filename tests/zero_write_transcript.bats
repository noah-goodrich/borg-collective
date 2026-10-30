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

@test "Bash file writes count: redirect, append, tee, sed -i, heredoc to a file" {
    local c
    local -a cmds=(
        "echo hi > out.txt"
        "echo hi >> out.txt"
        "ls 2>/dev/null > list.txt"
        "echo hi | tee out.txt"
        "sed -i '' 's/a/b/' f.txt"
        "sed -n -i.bak 's/a/b/' f.txt"
        "cat > f.txt << 'EOF'
body
EOF"
    )
    for c in "${cmds[@]}"; do
        rm -f "$TX"
        _tx Bash tu1 false "$c"
        _run
        [ -z "$HOOK_OUT" ] || { echo "not counted: $c"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    done
}

@test "Bash non-writes do not count: /dev/null, fd dup, pipe after 2>&1, plain sed" {
    local c
    local -a cmds=(
        "ls 2>/dev/null"
        "make test >/dev/null 2>&1"
        "make test 2>&1 | grep FAIL"
        "echo hi >&2"
        "echo hi > /dev/stderr"
        "sed -n '1,5p' f.txt"
        "cat f.txt << EOF | wc -l
x
EOF"
    )
    for c in "${cmds[@]}"; do
        rm -f "$TX"
        _tx Bash tu1 false "$c"
        _run
        _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE" || { echo "counted: $c"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
    done
}

@test "a transcript with only Read calls keeps zero_commit true" {
    _tx Read tu1 false
    _run
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
}

_lacks() { [[ "$1" != *"$2"* ]] || { echo "unexpected: $2"; return 1; }; }

# _run_as <type> [msg] [id] [transcript]: like _run, but with a chosen agent type.
_run_as() {
    local in
    in=$(jq -nc --arg t "$1" --arg p "${4:-$TX}" --arg m "${2:-Edited lib/foo.sh:10 done.}" --arg i "${3:-agent-wr123456}" \
        --arg c "$BATS_TEST_TMPDIR" \
        '{agent_id:$i,agent_type:$t,agent_transcript_path:$p,last_assistant_message:$m,cwd:$c}')
    rm -f "$LOG_FILE"
    HOOK_OUT=$(bash "$HOOK" <<< "$in" 2>/dev/null)
}

@test "nanoprobe with a successful Edit gets no warning, zero_commit false" {
    _tx Edit tu1 false
    _run_as borg-collective:borg-nanoprobe
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}

@test "nanoprobe with only Read and Grep warns ZERO-WRITE, zero_commit true" {
    _tx Read tu1 false
    _tx Grep tu2 false
    _run_as borg-collective:borg-nanoprobe "Edited lib/foo.sh:10 done." agent-zero1234
    local msg
    msg=$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)
    _has "$msg" "NANOPROBE ZERO-WRITE: agent-ze made no file edits and no git commit/push (checked its transcript)."
    _lacks "$msg" "ZERO-COMMIT"
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
}

@test "a nanoprobe whose only Edit failed (is_error) is flagged" {
    _tx Edit tu1 true
    _run_as borg-nanoprobe
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
}

@test "a successful Bash git -C x commit counts as a write for a grunt" {
    _tx Bash tu1 false "git -C /some/worktree commit -m wip"
    _run_as borg-collective:borg-grunt
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}

@test "a Bash command that is not commit or push does not count" {
    _tx Bash tu1 false "git -C /some/worktree status"
    _run_as borg-grunt
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
}

@test "a reviewer with no writes is not flagged, zero_commit null" {
    _tx Read tu1 false
    _run_as borg-collective:borg-reviewer "Reviewed lib/foo.sh:10 fine." agent-rev12345
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r '.zero_commit | type' "$LOG_FILE")" = "null" ]
}

@test "a missing transcript gives no warning and zero_commit null" {
    _run_as borg-collective:borg-nanoprobe "Edited lib/foo.sh:10 done." agent-wr123456 "${BATS_TEST_TMPDIR}/nope.jsonl"
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r '.zero_commit | type' "$LOG_FILE")" = "null" ]
}

@test "evidence warning is gated to writer types: a reviewer without citations is not warned" {
    _tx Read tu1 false
    _run_as borg-collective:borg-reviewer "Looks fine to me."
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .evidence_found "$LOG_FILE")" = "false" ]
}

# --- Cortex Code transcripts ----------------------------------------------------------------------------------------
# Cortex sends agent_transcript_path = <id>.json (a snapshot with no turns); the turns are in <id>.history.jsonl, one
# message per line, with nested {tool_use:{name,input,tool_use_id}} calls under lowercase names and
# {tool_result:{status,tool_use_id}} results. Shapes recorded from live Cortex 1.2.18 runs (evals/cortex-agents).

CX_SNAP() { printf '%s' "${BATS_TEST_TMPDIR}/cx.json"; }
CX_HIST() { printf '%s' "${BATS_TEST_TMPDIR}/cx.history.jsonl"; }

# _ctx <name> <id> <status> [command]: a Cortex tool call plus its result (status success|error).
_ctx() {
    jq -nc --arg n "$1" --arg i "$2" --arg c "${4:-}" \
        '{role:"assistant",model:"claude-sonnet-5-5",thinking_effort:"high",id:"a",
          content:[{type:"tool_use",tool_use:{name:$n,tool_use_id:$i,classification:"write",client_side_execute:true,
            input:(if $c=="" then {file_path:"a.txt",content:"x"} else {command:$c,description:"d"} end)}}]}' >> "$(CX_HIST)"
    jq -nc --arg n "$1" --arg i "$2" --arg s "$3" \
        '{role:"user",id:"u",content:[{type:"tool_result",message_id:"m",
          tool_result:{name:$n,status:$s,tool_use_id:$i,content:[{type:"text",text:"x"}]}}]}' >> "$(CX_HIST)"
}

# _cpending <name> <id> [command]: a Cortex tool call whose result is not written yet.
_cpending() {
    jq -nc --arg n "$1" --arg i "$2" --arg c "${3:-}" \
        '{role:"assistant",model:"claude-sonnet-5-5",id:"a",
          content:[{type:"tool_use",tool_use:{name:$n,tool_use_id:$i,
            input:(if $c=="" then {file_path:"a.txt"} else {command:$c} end)}}]}' >> "$(CX_HIST)"
}

# _crun [type]: run the hook on the Cortex snapshot path, as Cortex does.
_crun() {
    _run_as "${1:-borg-collective:borg-nanoprobe}" "Edited lib/foo.sh:10 done." agent-cx123456 "$(CX_SNAP)"
}

@test "cortex: a successful write, edit or notebook_edit counts" {
    local n
    for n in write edit notebook_edit; do
        rm -f "$(CX_HIST)"
        _ctx "$n" tu1 success
        _crun
        [ -z "$HOOK_OUT" ] || { echo "not counted: $n"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    done
}

@test "cortex: bash git commit, git push and file-writing commands count" {
    local c
    local -a cmds=(
        "git -C /work add a.txt && git -C /work commit -m 'add a'"
        "git push origin fix/x"
        "printf 'OK' > /work/out/a.txt"
        "echo hi | tee out.txt"
        "sed -i '' 's/a/b/' f.txt"
    )
    for c in "${cmds[@]}"; do
        rm -f "$(CX_HIST)"
        _ctx bash tu1 success "$c"
        _crun
        [ -z "$HOOK_OUT" ] || { echo "not counted: $c"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
    done
}

@test "cortex: read-only bash, read, grep and glob do not count" {
    local c
    for c in "git status" "ls -la /work/out" "make test >/dev/null 2>&1" "wc -c a.txt"; do
        rm -f "$(CX_HIST)"
        _ctx bash tu1 success "$c"
        _ctx read tu2 success
        _ctx grep tu3 success
        _ctx glob tu4 success
        _crun
        _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE" || { echo "counted: $c"; return 1; }
        [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
    done
}

@test "cortex: a write or bash write whose result status is error does not count" {
    _ctx write tu1 error
    _ctx bash tu2 error "git -C /work commit -m x"
    _crun
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "true" ]
}

@test "cortex: a write with no result yet counts (the history lags)" {
    _cpending edit tu1
    _crun
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}

@test "cortex: a malformed line and a non-array content are tolerated" {
    printf '%s\n' '{not json' >> "$(CX_HIST)"
    printf '%s\n' '{"role":"user","content":"plain string"}' >> "$(CX_HIST)"
    _ctx write tu1 success
    _crun
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}

@test "cortex: a snapshot with no history beside it gives no verdict (was a false ZERO-WRITE)" {
    printf '%s\n' '{"title":"t","thread":{"threadId":"1"}}' > "$(CX_SNAP)"
    _crun
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r '.zero_commit | type' "$LOG_FILE")" = "null" ]
}

@test "cortex: a Claude-shaped block inside a Cortex history is not counted" {
    # a Cortex history never carries .message.content; the Cortex parse must not fall back to it
    jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"tu1",name:"Write",input:{file_path:"a"}}]}}' >> "$(CX_HIST)"
    _crun
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "ZERO-WRITE"
}

@test "cortex: a reviewer with no writes is not flagged, a namespaced grunt with a write is clean" {
    _ctx read tu1 success
    _crun borg-collective:borg-reviewer
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r '.zero_commit | type' "$LOG_FILE")" = "null" ]
    rm -f "$(CX_HIST)"
    _ctx write tu1 success
    _crun borg-collective:borg-grunt
    [ -z "$HOOK_OUT" ]
    [ "$(jq -r .zero_commit "$LOG_FILE")" = "false" ]
}
