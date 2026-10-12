#!/usr/bin/env bats
# Tests for borg-nanoprobe-log.sh summary recovery from the transcript.
# Background subagents end on a tool_use with no text block, so last_assistant_message is empty.

load test_helper/setup

BORG_NANOPROBE_LOG="${BATS_TEST_DIRNAME}/../hooks/borg-nanoprobe-log.sh"

setup() {
    setup_temp_dirs
    export LOG_FILE="$XDG_STATE_HOME/borg/agents.jsonl"
}

_has() { [[ "$1" == *"$2"* ]] || { echo "missing: $2"; return 1; }; }

_recover_payload() {
    jq -nc --arg t "$1" --arg m "${2:-}" --arg c "$BATS_TEST_TMPDIR" \
        '{agent_id:"rec-1",agent_type:"borg-nanoprobe",agent_transcript_path:$t,last_assistant_message:$m,cwd:$c}'
}

_asst_tool() {
    jq -nc --arg n "$1" --argjson i "$2" \
        '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"tu1",name:$n,input:$i}]}}'
}

_user_result() {
    jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:"tu1",content:"ok"}]}}'
}

@test "recover: SubagentHandback ending gives the head of input.message" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        echo '{"type":"user","message":{"role":"user","content":"go"}}'
        _asst_tool SubagentHandback '{"message":"Handback report: shipped the thing"}'
    } > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "Handback report: shipped the thing" ]
}

@test "recover: StructuredOutput ending prefers input.summary" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    _asst_tool StructuredOutput '{"verdict":"pass","summary":"The summary text"}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "The summary text" ]
}

@test "recover: StructuredOutput without a string key falls back to compact JSON" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    _asst_tool StructuredOutput '{"findings":[1,2]}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = '{"findings":[1,2]}' ]
}

@test "recover: a non-empty last_assistant_message is used as-is" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    _asst_tool SubagentHandback '{"message":"from transcript"}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t" "from payload")"
    [ "$(jq -r .summary "$LOG_FILE")" = "from payload" ]
}

@test "recover: missing transcript keeps summary empty, writes the row, exits 0" {
    run bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "${BATS_TEST_TMPDIR}/nope.jsonl")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(wc -l < "$LOG_FILE" | tr -d ' ')" -eq 1 ]
    [ "$(jq -r .summary "$LOG_FILE")" = "" ]
}

@test "recover: a final user tool_result line still resolves the last assistant entry" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        _asst_tool SubagentHandback '{"message":"resolved past result"}'
        _user_result
    } > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "resolved past result" ]
}

@test "recover: a malformed final line is tolerated" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        _asst_tool SubagentHandback '{"message":"before garbage"}'
        printf '{"type":"assis'
    } > "$t"
    run bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$status" -eq 0 ]
    [ "$(jq -r .summary "$LOG_FILE")" = "before garbage" ]
}

@test "recover: text blocks are joined when the last assistant entry has them" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:"part one"},{type:"text",text:"part two"}]}}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    _has "$(jq -r .summary "$LOG_FILE")" "part one"
    _has "$(jq -r .summary "$LOG_FILE")" "part two"
}

@test "recover: the evidence score is computed from the recovered text" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    _asst_tool SubagentHandback '{"message":"Changed lib/foo.sh:42 as asked"}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .evidence_found "$LOG_FILE")" = "true" ]
    [ "$(jq -r .evidence_score "$LOG_FILE")" -ge 2 ]
}

@test "recover: a SubagentHandback whose message is not a string gives compact JSON" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    _asst_tool SubagentHandback '{"message":{"a":1}}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = '{"message":{"a":1}}' ]
}

@test "recover: an assistant entry whose content is a plain string is used" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    jq -nc '{type:"assistant",message:{role:"assistant",content:"plain string report"}}' > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "plain string report" ]
}

@test "recover: two assistant lines sharing a message.id recover the text" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        jq -nc '{type:"assistant",message:{id:"msg_1",role:"assistant",content:[{type:"text",text:"split report"}]}}'
        jq -nc '{type:"assistant",message:{id:"msg_1",role:"assistant",content:[{type:"tool_use",id:"tu2",name:"Bash",input:{command:"true"}}]}}'
    } > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "split report" ]
}

@test "recover: a handback in an earlier same-id line is found" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        jq -nc '{type:"assistant",message:{id:"msg_2",role:"assistant",content:[{type:"tool_use",id:"a",name:"SubagentHandback",input:{message:"handed back"}}]}}'
        jq -nc '{type:"assistant",message:{id:"msg_2",role:"assistant",content:[{type:"tool_use",id:"b",name:"Bash",input:{command:"true"}}]}}'
    } > "$t"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "handed back" ]
}

@test "recover: 30 non-assistant lines after the last assistant entry still recover" {
    local t="${BATS_TEST_TMPDIR}/t.jsonl" i
    _asst_tool SubagentHandback '{"message":"deep recovery"}' > "$t"
    for i in $(seq 1 30); do _user_result >> "$t"; done
    bash "$BORG_NANOPROBE_LOG" <<< "$(_recover_payload "$t")"
    [ "$(jq -r .summary "$LOG_FILE")" = "deep recovery" ]
}
