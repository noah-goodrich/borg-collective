#!/usr/bin/env bats
# Fixture provenance + shape checks for the resume design (slice S0a), and the
# spike-resume-payloads.sh harness contract.
#
# Provenance gate: RESUME_REQUIRE_CAPTURED=S4 (or S4,S7) fails unless every fixture that
# slice lists in required_captured is tagged captured-skeleton. Unset, that gate is
# informational so the synthetic fixtures do not block this slice.

setup() {
    FX="${BATS_TEST_DIRNAME}/fixtures/resume"
    MAN="$FX/fixtures.json"
    HARNESS="${BATS_TEST_DIRNAME}/../scripts/spike-resume-payloads.sh"
    SKEL="${BATS_TEST_DIRNAME}/../scripts/resume-skeleton.py"
    EXTRACTOR_VERSION="v2"
    command -v jq >/dev/null || skip "jq not installed"
}

_not_captured() {
    jq -r --arg s "$1" '. as $m | ($m.required_captured[$s] // ["__undeclared__"])[]
        | select(($m.fixtures[.].tag // "missing") != "captured-skeleton")' "$MAN"
}

@test "manifest parses and every fixture is tagged captured-skeleton or synthetic" {
    run jq -e '[.fixtures[].tag] | all(. == "captured-skeleton" or . == "synthetic")' "$MAN"
    [ "$status" -eq 0 ]
}

@test "captured-skeleton entries name the extractor version, synthetic entries say why" {
    run jq -r --arg v "$EXTRACTOR_VERSION" '.fixtures | to_entries[]
        | select((.value.tag == "captured-skeleton" and .value.extractor != $v)
              or (.value.tag == "synthetic" and ((.value.synthetic_reason // "") | length) == 0))
        | .key' "$MAN"
    [ -z "$output" ]
}

@test "extractor version in the script matches the tests" {
    run grep -c "^VERSION = \"$EXTRACTOR_VERSION\"" "$SKEL"
    [ "$output" = "1" ]
}

@test "every manifest entry points at an existing file" {
    local f
    for f in $(jq -r '.fixtures[].file' "$MAN"); do
        [ -f "$FX/$f" ] || { echo "missing $f"; false; }
    done
}

@test "every file under fixtures/resume is listed in the manifest" {
    local listed actual
    listed="$(jq -r '.fixtures[].file' "$MAN" | sort)"
    actual="$(cd "$FX" && find . -type f ! -name fixtures.json | sed 's#^\./##' | sort)"
    [ "$listed" = "$actual" ]
}

@test "required_captured only references declared fixtures" {
    run jq -r '. as $m | $m.required_captured | to_entries[] | .key as $s | .value[]
        | select($m.fixtures[.] == null) | "\($s): \(.)"' "$MAN"
    [ -z "$output" ]
}

@test "jsonl fixtures: every line is a JSON object" {
    local f
    for f in $(jq -r '.fixtures[] | select(.kind=="jsonl") | .file' "$MAN"); do
        run jq -s -e 'all(type == "object")' "$FX/$f"
        [ "$status" -eq 0 ] || { echo "bad jsonl $f"; false; }
    done
}

@test "jsonl object check fails on an interior non-object line" {
    printf '%s\n' '{"a":1}' '[1]' '{"b":2}' > "$BATS_TEST_TMPDIR/bad.jsonl"
    run jq -s -e 'all(type == "object")' "$BATS_TEST_TMPDIR/bad.jsonl"
    [ "$status" -ne 0 ]
}

@test "shape: every main_* error fixture ends in a typed api error record" {
    local f
    for f in main_rate_limit main_rate_limit_session main_authentication_failed main_invalid_request main_max_output_tokens; do
        run jq -s -e '.[-1] | .isApiErrorMessage == true and (.error | type == "string") and has("apiErrorStatus")' "$FX/$f.jsonl"
        [ "$status" -eq 0 ] || { echo "bad $f"; false; }
    done
    run jq -s -e 'map(.error) | . == ["rate_limit"]' "$FX/main_rate_limit.jsonl"
}

@test "shape: weekly and session limit phrasings both present" {
    run grep -c "weekly limit" "$FX/main_rate_limit.jsonl"
    [ "$output" = "1" ]
    run grep -c "session limit" "$FX/main_rate_limit_session.jsonl"
    [ "$output" = "1" ]
}

@test "shape: api_error_tail ends in a synthetic error record" {
    run jq -s -e '.[-1] | .type == "assistant" and .isApiErrorMessage == true and .apiErrorStatus == 429 and (.error | type == "string")' "$FX/main_rate_limit.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: error followed by bookkeeping records" {
    run jq -s -e '(map(.isApiErrorMessage // false) | index(true)) as $i | $i != null and (length - $i) > 3' "$FX/main_server_error_tail.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: interrupt markers end the transcript" {
    local f
    for f in interrupt_user interrupt_tool_use; do
        run jq -s -e '.[-1].message.content[0].text | startswith("[Request interrupted by user")' "$FX/$f.jsonl"
        [ "$status" -eq 0 ]
    done
}

@test "shape: subagent first record and meta" {
    run jq -s -e '.[0] | .type == "user" and .isSidechain == true and (.agentId|length>0) and (.sessionId|length>0) and (.cwd|length>0)' "$FX/subagents/agent-a0b6facb8e5d1b6ac.jsonl"
    [ "$status" -eq 0 ]
    run jq -e 'has("agentType") and has("description") and has("model") and has("spawnDepth")' "$FX/subagents/agent-a0b6facb8e5d1b6ac.meta.json"
    [ "$status" -eq 0 ]
}

@test "shape: workflow manifest and journal" {
    run jq -e 'has("runId") and has("scriptPath") and has("script") and has("status") and has("agentCount")' "$FX/workflows/wf_ab12cd.json"
    [ "$status" -eq 0 ]
    run jq -s -e 'all(has("type")) and (map(.type) | index("started") != null) and (map(.type) | index("launched") != null)' "$FX/workflows/wf_ab12cd.journal.jsonl"
    [ "$status" -eq 0 ]
}

@test "shape: hook payloads carry the common fields" {
    local f
    for f in stop_failure_payload session_start_payload; do
        run jq -e 'has("hook_event_name") and has("session_id") and has("cwd") and has("transcript_path")' "$FX/$f.json"
        [ "$status" -eq 0 ]
    done
    run jq -e 'has("error") and has("error_details") and has("last_assistant_message")' "$FX/stop_failure_payload.json"
    [ "$status" -eq 0 ]
}

@test "fixtures leak test: no home path, secret, email or real UUID" {
    local bad
    bad="$(grep -rEho '/Users/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?(/[A-Za-z0-9._-]+)?' "$FX" | grep -v '^/Users/noah/dev/example$' | grep -v '^/Users/noah/dev$' | grep -v '^/Users/noah$' || true)"
    [ -z "$bad" ] || { echo "path: $bad"; false; }
    run grep -rEl '/home/[A-Za-z0-9._-]+|sk-ant|sk-[A-Za-z0-9]{20}|ghp_|AKIA|eyJ[A-Za-z0-9_-]{10}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$FX"
    [ -z "$output" ] || { echo "secret/email in: $output"; false; }
    bad="$(grep -rEho '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$FX" | grep -v '^00000000-0000-4000-8000-[0-9]\{12\}$' || true)"
    [ -z "$bad" ] || { echo "real-looking uuid: $bad"; false; }
}

@test "fixtures leak test: no UUID from the local transcript store appears in a fixture" {
    local store="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}" ids
    [ -d "$store" ] || skip "no local transcript store"
    ids="$(ls "$store" "$store"/* 2>/dev/null | grep -Eo '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | sort -u)"
    [ -n "$ids" ] || skip "no session ids in the local store"
    printf '%s\n' "$ids" > "$BATS_TEST_TMPDIR/ids"
    run grep -rFl -f "$BATS_TEST_TMPDIR/ids" "$FX"
    [ -z "$output" ] || { echo "real session id in: $output"; false; }
}

@test "pane fixtures pass the harness pane allowlist unchanged" {
    local f
    for f in composer permission limit; do
        run "$HARNESS" scrubpane < "$FX/panes/$f.txt"
        [ "$output" = "$(cat "$FX/panes/$f.txt")" ] || { echo "pane $f changed"; false; }
    done
}

@test "provenance gate logic flags synthetic fixtures" {
    run _not_captured S4
    [[ "$output" == *stop_failure_payload* ]]
}

@test "provenance gate logic flags undeclared slices" {
    run _not_captured S99
    [[ "$output" == *__undeclared__* ]]
}

@test "provenance gate: slices in RESUME_REQUIRE_CAPTURED have captured fixtures" {
    [ -n "${RESUME_REQUIRE_CAPTURED:-}" ] || skip "informational: set RESUME_REQUIRE_CAPTURED=S4,S7,... to enforce"
    local s bad=""
    for s in $(printf '%s' "$RESUME_REQUIRE_CAPTURED" | tr ',' ' '); do
        bad="$bad $(_not_captured "$s" | tr '\n' ' ')"
    done
    [ -z "${bad// /}" ] || { echo "not captured:$bad"; false; }
}

@test "harness: executable and parses under /bin/bash -n" {
    [ -x "$HARNESS" ]
    [ -x /bin/bash ] || skip "no /bin/bash"
    /bin/bash -n "$HARNESS"
}

@test "harness hook: appends a line, exits 0, prints nothing" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run "$HARNESS" hook StopFailure < "$FX/stop_failure_payload.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "StopFailure" and .payload.session_id != null' "$BORG_SPIKE_DIR/payloads.jsonl"
    [ "$status" -eq 0 ]
}

# bash 3.2 does not abort a test on a failed [[ ]] unless it is the last command,
# so every assertion goes through a function that returns non-zero explicitly.
_absent() {
    local h="$1"
    shift
    local n
    for n in "$@"; do
        case "$h" in *"$n"*) echo "unexpected: $n"; return 1 ;; esac
    done
    return 0
}

_present() {
    case "$1" in *"$2"*) return 0 ;; esac
    echo "missing: $2"
    return 1
}

_hook() {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    printf '%s' "$1" | "$HARNESS" hook StopFailure
}

@test "harness hook: keeps the strict limit sentence, redacts other text and user paths" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","cwd":"/Users/someone/dev/secret","prompt":"my private prompt","last_assistant_message":"You'"'"'ve hit your session limit · resets 7am"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _present "$output" 'resets 7am' || false
    _absent "$output" 'private prompt' || false
    _absent "$output" 'someone' || false
    _absent "$output" 'secret' || false
}

@test "harness hook: plain private text in error_details is redacted (no secret shape)" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","error":"rate_limit","error_details":"customer Acme owes money"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'Acme' || false
    _present "$output" '"error":"rate_limit"' || false
}

@test "harness hook: unlisted keys with plain text are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"extra_note":"Customer Acme owes 50k","error_info":"private plan about merger","agent_type":"my private agent name"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'Acme' || false
    _absent "$output" 'merger' || false
    _absent "$output" 'private agent' || false
    _absent "$output" 'extra_note' || false
}

@test "harness hook: strings in arrays and under nested unlisted keys are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"items":["my private text in array"],"nested":{"foo":"internal codename ingle"}}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'private text' || false
    _absent "$output" 'codename' || false
    _absent "$output" 'ingle' || false
    rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
    _hook '{"content":["bare array private words","second private words"]}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'bare array' 'second private' || false
    _present "$output" '"content":["<str>","<str>"]' || false
}

@test "harness hook: limit-shaped sentence with free text in kind, month or timezone is dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local s
    for s in "You've hit your Acme merger limit · resets 7am" \
             "You've hit your weekly limit · resets Foo 3 at 7am" \
             "You've hit your weekly limit · resets 7am (Customer_Acme_Owes_Fifty_Thousand_Dollars/Secret_Merger_Plan_Codename_Ingle)"; do
        rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
        _hook "{\"last_assistant_message\":\"$s\"}"
        run cat "$BORG_SPIKE_DIR/payloads.jsonl"
        _present "$output" '"last_assistant_message":"<str>"' || false
    done
    rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
    _hook '{"zzz":"You'"'"'ve hit your weekly limit · resets 7am"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'weekly limit' || false
    _present "$output" '"<key>":"<str>"' || false
}

@test "harness scrubpane: limit-shaped lines with free text in kind, month or timezone are redacted" {
    local s
    for s in "You've hit your Acme merger limit · resets 7am" \
             "You've hit your weekly limit · resets Foo 3 at 7am" \
             "You've hit your weekly limit · resets 7am (Customer_Acme_Owes_Fifty_Thousand_Dollars/Secret_Merger_Plan_Codename_Ingle)"; do
        run bash -c "printf '%s\n' \"\$1\" | '$HARNESS' scrubpane" _ "$s"
        [ "$output" = "<redacted>" ] || { echo "kept: $s"; false; }
    done
    run bash -c "printf '%s\n' \"\$1\" | '$HARNESS' scrubpane" _ "You've hit your weekly limit · resets Jul 7 at 7am (America/Denver)"
    _present "$output" 'America/Denver' || false
}

@test "harness hook: closed-set model and notification_type survive, lookalikes do not" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"model":"claude-opus-4-7[1m]","notification_type":"idle_prompt"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _present "$output" '"model":"claude-opus-4-7[1m]"' || false
    _present "$output" '"notification_type":"idle_prompt"' || false
    local k v
    for k in model defaultModel; do
        for v in claude-acme-merger-plan claude-bob-owes-money; do
            rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
            _hook "{\"$k\":\"$v\"}"
            run cat "$BORG_SPIKE_DIR/payloads.jsonl"
            _absent "$output" "$v" || false
            _present "$output" "\"$k\":\"<str>\"" || false
        done
    done
    rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
    _hook '{"notification_type":"acme_merger_plan_x"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'acme' || false
}

@test "harness hook: credential-shape guard alone rejects a model-shaped secret" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run python3 -B -I -c "
import importlib.util, sys
sys.dont_write_bytecode = True
s =importlib.util.spec_from_file_location('rs', '$SKEL')
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
m.ENUM_RULES['notification_type'] = m.re.compile(r'.+')
print(m.enum_ok('notification_type', 'my_secret_plan'), m.enum_ok('notification_type', 'my_plain_plan'))
"
    [ "$output" = "False True" ]
    _hook '{"notification_type":"my_secret_plan"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'secret_plan' || false
}

@test "harness hook: ISO timestamps come back as the fixed fake series" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"timestamp":"2031-05-06T07:08:09.123Z"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _present "$output" '"timestamp":"2026-01-01T00:00:01.000Z"' || false
    _absent "$output" '2031' || false
}

@test "harness hook: python3 present but failing falls back to the jq skeleton" {
    local d="$BATS_TEST_TMPDIR/failpy"
    mkdir -p "$d/bin"
    cp "$HARNESS" "$d/h.sh"
    printf '%s\n' 'import sys' 'sys.exit(3)' > "$d/resume-skeleton.py"
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run bash -c "printf '%s' '{\"session_id\":\"s\",\"extra\":\"private\",\"error\":\"rate_limit\"}' | '$d/h.sh' hook StopFailure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'private' 'rate_limit' || false
    _present "$output" '"session_id":"<str>"' || false
}

@test "harness hook: PATH without python3 writes the jq skeleton, exits 0 silently" {
    local d="$BATS_TEST_TMPDIR/nopy" t
    mkdir -p "$d"
    for t in jq date cat mkdir chmod sed tr; do
        ln -sf "$(command -v "$t")" "$d/$t"
    done
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run /usr/bin/env PATH="$d" /bin/bash -c "printf '%s' '{\"session_id\":\"s\",\"extra\":\"private\"}' | /bin/bash '$HARNESS' hook StopFailure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'private' || false
    _present "$output" '"session_id":"<str>"' || false
}

@test "harness hook: case variant of a free-text key is dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"LastAssistantMessage":"private words","Last_Assistant_Message":"more private words"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'private words' || false
}

@test "harness hook: Bearer, URL, AIza and sk_live credentials are dropped under any key" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"ka1":"Bearer abcdef1234567890","message":"postgres://user:pw@host/db","error_details":"AIzaSyA1234567890abcdefghij","kb2":"sk_live_abc123XYZ"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'Bearer' || false
    _absent "$output" 'postgres' || false
    _absent "$output" 'AIza' || false
    _absent "$output" 'sk_live' || false
    # one probe per record so a collapsing "<key>" cannot hide a survivor
    local p
    for p in 'Bearer abcdef1234567890' 'postgres://user:pw@host/db' 'AIzaSyA1234567890abcdefghij' 'sk_live_abc123XYZ'; do
        rm -f "$BORG_SPIKE_DIR/payloads.jsonl"
        _hook "{\"message\":\"$p\",\"text\":\"$p\",\"error\":\"$p\"}"
        run cat "$BORG_SPIKE_DIR/payloads.jsonl"
        _absent "$output" "$p" || false
    done
}

@test "harness hook: /private/var, /tmp, spaced and Windows paths are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"kc3":"/private/var/folders/xx/secret-project","message":"/tmp/secretproj/file.txt","error_details":"/Users/bob/My Docs/tax return/x.pdf","kd4":"C:\\Users\\bob\\taxes\\x.pdf"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'secret-project' || false
    _absent "$output" 'secretproj' || false
    _absent "$output" 'tax return' || false
    _absent "$output" 'bob' || false
    _absent "$output" 'taxes' || false
}

@test "harness hook: token-shaped enum values and keys are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"error":"sk-ant-abc123def456","status":"hunter2-password-xyz","model":"acme-merger-plan","mode":"AKIAABCDEFGHIJ12","ghp_abcdefghijklmnopqrstuvwxyz0123456789":1,"MY_SECRET_PW_hunter2":2}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'sk-ant' || false
    _absent "$output" 'hunter2' || false
    _absent "$output" 'acme' || false
    _absent "$output" 'AKIA' || false
    _absent "$output" 'ghp_' || false
    _absent "$output" 'SECRET' || false
}

@test "harness hook: fallback jq skeleton (no extractor beside the script) keeps no text" {
    local d="$BATS_TEST_TMPDIR/lone"
    mkdir -p "$d" && cp "$HARNESS" "$d/h.sh"
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    printf '%s' '{"session_id":"s","error":"rate_limit","extra":"private","nested":{"foo":"codename"},"items":["in array"],"n":3}' | "$d/h.sh" hook StopFailure
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'private' || false
    _absent "$output" 'codename' || false
    _absent "$output" 'in array' || false
    _absent "$output" 'rate_limit' || false
    _present "$output" '"<key>":3' || false
}

@test "harness hook: long assistant message mentioning limits keeps only the limit sentence" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","last_assistant_message":"Here is how server error handling and rate limit retries work, password hunter2, tail: sk-ant-nope"}'
    _hook '{"session_id":"s","last_assistant_message":"long preamble about hunter2. You'"'"'ve hit your weekly limit · resets Jul 7 at 7am (America/Denver) and then more private words"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    _absent "$output" 'hunter2' || false
    _absent "$output" 'server error handling' || false
    _absent "$output" 'private words' || false
    _absent "$output" 'weekly limit' || false
}

@test "harness hook: transcript_path becomes the fixed fake projects shape" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","transcript_path":"/Users/bob/.claude/projects/-Users-bob-dev-x/abc.jsonl"}'
    run jq -r '.payload.transcript_path' "$BORG_SPIKE_DIR/payloads.jsonl"
    [ "$output" = "/Users/noah/dev/example/.claude/projects/-Users-noah-dev-example/<sid>.jsonl" ]
}

@test "harness scrubpane: redacts every line outside the allowlist" {
    run bash -c "printf '%s\n' 'my private prompt about hunter2' '│ > token sk-ant-abc │' '  ls /Users/someone/dev/x' '❯ 1. Yes' '  ? for shortcuts' | '$HARNESS' scrubpane"
    _absent "$output" 'hunter2' || false
    _absent "$output" 'sk-ant' || false
    _absent "$output" 'someone' || false
    _present "$output" '❯ 1. Yes' || false
    _present "$output" '? for shortcuts' || false
    [ "$(printf '%s\n' "$output" | grep -c '<redacted>')" = "3" ]
}

@test "harness scrubpane: limit line with trailing text is redacted" {
    run bash -c "printf '%s\n' 'You'\\''ve hit your session limit · resets 7am (America/Denver) plus hunter2' | '$HARNESS' scrubpane"
    [ "$output" = "<redacted>" ]
}

@test "harness: hook command is shell-quoted for paths with spaces" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike dir"
    run "$HARNESS" settings
    run jq -r '.hooks.StopFailure[0].hooks[0].command' "$output"
    [[ "$output" == *"hook StopFailure" ]]
    run bash -c "eval \"set -- $output\"; [ -x \"\$1\" ]"
    [ "$status" -eq 0 ]
}

@test "harness: show prints captured payloads, scratch dir is mode 700" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    "$HARNESS" hook StopFailure < "$FX/stop_failure_payload.json"
    run "$HARNESS" show
    _present "$output" 'StopFailure' || false
    [ "$(stat -f %Lp "$BORG_SPIKE_DIR" 2>/dev/null || stat -c %a "$BORG_SPIKE_DIR")" = "700" ]
}

@test "harness hook: garbage and empty stdin still exit 0 silently" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run bash -c "printf 'not json{' | '$HARNESS' hook Notification"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run bash -c "'$HARNESS' hook Notification < /dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "harness hook: unwritable scratch dir still exits 0" {
    export BORG_SPIKE_DIR="/proc/nonexistent/x"
    run "$HARNESS" hook SessionEnd < "$FX/session_start_payload.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "harness settings: temp file wires all events, nothing global touched" {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    run "$HARNESS" settings
    [ "$status" -eq 0 ]
    [ "$output" = "$BORG_SPIKE_DIR/settings.spike.json" ]
    run jq -e '(.hooks | keys | sort) == ["Notification","PostToolUse","PreToolUse","SessionEnd","SessionStart","StopFailure","SubagentStart","SubagentStop"]
        and (.hooks.PreToolUse[0].matcher == "Agent|Workflow")
        and ([.hooks[][0].hooks[0].timeout] | all(. == 5))' "$BORG_SPIKE_DIR/settings.spike.json"
    [ "$status" -eq 0 ]
}

@test "harness is not installed as a live hook" {
    run grep -rl "spike-resume-payloads" "${BATS_TEST_DIRNAME}/.." \
        --exclude-dir=.git --exclude-dir=tests --exclude=spike-resume-payloads.sh \
        --exclude=resume-skeleton.py
    [ -z "$output" ]
}

@test "harness snap: captures a private tmux pane, allowlisted" {
    command -v tmux >/dev/null || skip "tmux not installed"
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    local sock="borgspike$$" pane out i
    tmux -L "$sock" new-session -d -s t "echo 'my private prompt hunter2 /Users/someone/dev/secret'; echo '❯ 1. Yes'; sleep 30"
    pane="$(tmux -L "$sock" list-panes -t t -F '#{pane_id}' | head -1)"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        tmux -L "$sock" capture-pane -p -t "$pane" 2>/dev/null | grep -q "1. Yes" && break
        sleep 0.25
    done
    run env BORG_SPIKE_TMUX_SOCK="$sock" "$HARNESS" snap "$pane" demo
    tmux -L "$sock" kill-server 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ -f "$output" ]
    run cat "$output"
    _present "$output" '<redacted>' || false
    _present "$output" '1. Yes' || false
    _absent "$output" 'hunter2' || false
    _absent "$output" 'someone' || false
}

@test "extractor: keeps enum fields and strict limit sentence, drops everything else" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local in out
    in='{"type":"assistant","error":"rate_limit","isSidechain":false,"apiErrorStatus":429,"uuid":"4cfc980b-e51b-42da-9cd5-d75d0a33c88c","parentUuid":"d0165fec-e970-4833-91d8-7dfb071cebe6","cwd":"/Users/bob/dev/x","timestamp":"2026-07-05T17:59:00.619Z","gitBranch":"feat/secret","message":{"content":[{"type":"text","text":"You'"'"'ve hit your weekly limit · resets Jul 7 at 7am (America/Denver)"}]},"note":"token sk-ant-abc123 bob@example.com","long":"You'"'"'ve hit your weekly limit · resets 7am and my password is hunter2"}'
    out="$(printf '%s' "$in" | python3 -I "$SKEL" scrub)"
    _present "$out" '"error":"rate_limit"' || false
    _present "$out" '"apiErrorStatus":429' || false
    _present "$out" 'weekly limit · resets Jul 7 at 7am (America/Denver)' || false
    _present "$out" '00000000-0000-4000-8000-000000000001' || false
    _present "$out" '00000000-0000-4000-8000-000000000002' || false
    _absent "$out" '4cfc980b' || false
    _absent "$out" 'bob' || false
    _absent "$out" 'sk-ant' || false
    _absent "$out" 'hunter2' || false
    _absent "$out" 'secret' || false
    _present "$out" '"<key>":"<str>"' || false
}

@test "extractor: unlisted string keys and odd object keys never survive" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run bash -c "printf '%s' '{\"customField\":\"hello\",\"/Users/bob/x\":1,\"level\":\"suggestion\",\"type\":\"has space and words\"}' | python3 -I '$SKEL' scrub"
    _absent "$output" 'hello' || false
    _absent "$output" 'bob' || false
    _present "$output" '"level":"suggestion"' || false
    _present "$output" '"type":"<str>"' || false
}

@test "extractor: enum values outside the closed set or token-shaped are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local in='{"error":"made_up_kind","status":"hunter2-password-xyz","model":"acme-merger-plan","mode":"AKIAABCDEFGHIJ12","type":"sk-ant-abc123def456","role":"assistant"}'
    run python3 -I "$SKEL" --stdin <<<"$in"
    _present "$output" '"role":"assistant"' || false
    _absent "$output" 'made_up_kind' 'hunter2' 'acme' 'AKIA' 'sk-ant' || false
}

@test "extractor: token-shaped and unknown keys become <key>" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local in='{"ghp_abcdefghijklmnopqrstuvwxyz0123456789":1,"MY_SECRET_PW_hunter2":2,"acme_merger":3,"type":"user"}'
    run python3 -I "$SKEL" --stdin <<<"$in"
    _present "$output" '"type":"user"' || false
    _absent "$output" 'ghp_' 'hunter2' 'acme' || false
}

_ext() {
    printf '%s' "$1" | python3 -I "$SKEL" --stdin
}

@test "extractor: limit-shaped free text in kind, month or timezone becomes <str>" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local s out
    for s in "You've hit your Acme merger limit · resets 7am" \
             "You've hit your weekly limit · resets Foo 3 at 7am" \
             "You've hit your weekly limit · resets 7am (Customer_Acme_Owes_Fifty_Thousand_Dollars/Secret_Merger_Plan_Codename_Ingle)"; do
        out="$(_ext "{\"text\":\"$s\"}")"
        [ "$out" = '{"text":"<str>"}' ] || { echo "kept: $out"; false; }
    done
}

@test "extractor: a valid limit sentence survives only under a text key" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local out
    out="$(_ext "{\"zzz\":\"You've hit your weekly limit · resets 7am\"}")"
    [ "$out" = '{"<key>":"<str>"}' ] || { echo "$out"; false; }
    out="$(_ext "{\"text\":\"You've hit your weekly Opus limit · resets Dec 31 at 11:30pm (Asia/Tokyo)\"}")"
    _present "$out" 'weekly Opus limit · resets Dec 31 at 11:30pm (Asia/Tokyo)' || false
}

@test "extractor: model and notification_type lookalikes become <str>, real values survive" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local out
    out="$(_ext '{"model":"claude-acme-merger-plan","defaultModel":"claude-bob-owes-money","notification_type":"acme_merger_plan_x"}')"
    [ "$out" = '{"model":"<str>","defaultModel":"<str>","notification_type":"<str>"}' ] || { echo "$out"; false; }
    out="$(_ext '{"model":"claude-sonnet-4-6","defaultModel":"<synthetic>","notification_type":"quota_auto_resume_started"}')"
    _present "$out" '"model":"claude-sonnet-4-6"' || false
    _present "$out" '"notification_type":"quota_auto_resume_started"' || false
}

@test "extractor: bare string arrays and distinct unknown keys all become <str>" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local out
    out="$(_ext '{"items":["private one","private two"]}')"
    [ "$out" = '{"<key>":["<str>","<str>"]}' ] || { echo "$out"; false; }
    out="$(_ext '{"k2":{"k3":["beta text"]}}')"
    [ "$out" = '{"<key>":{"<key>":["<str>"]}}' ] || { echo "$out"; false; }
    out="$(_ext '{"content":["bare one","bare two"]}')"
    [ "$out" = '{"content":["<str>","<str>"]}' ] || { echo "$out"; false; }
}

@test "extractor: ISO timestamps become the fixed fake series" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local out
    out="$(_ext '{"timestamp":"2031-05-06T07:08:09.123Z","endTime":"2031-05-06T07:08:10.123Z"}')"
    [ "$out" = '{"timestamp":"2026-01-01T00:00:01.000Z","endTime":"2026-01-01T00:00:02.000Z"}' ] || { echo "$out"; false; }
}

@test "pane allowlist and extractor accept and reject the same limit lines" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local s pane ext
    for s in "You've hit your session limit · resets 7am" \
             "You've hit your weekly limit · resets Jul 7 at 7am (America/Denver)" \
             "You've hit your Sonnet limit · resets 9:30pm (UTC)" \
             "You've hit your Acme limit · resets 7am" \
             "You've hit your weekly limit · resets Foo 7 at 7am" \
             "You've hit your weekly limit · resets 7am (America/Nowhere)"; do
        pane="$(printf '%s\n' "$s" | "$HARNESS" scrubpane)"
        ext="$(_ext "{\"text\":\"$s\"}")"
        if [ "$pane" = "$s" ]; then
            _present "$ext" "$s" || false
        else
            [ "$ext" = '{"text":"<str>"}' ] || { echo "disagree: $s"; false; }
        fi
    done
}
