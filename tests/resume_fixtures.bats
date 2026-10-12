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

_hook() {
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    printf '%s' "$1" | "$HARNESS" hook StopFailure
}

@test "harness hook: keeps the strict limit sentence, redacts other text and user paths" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","cwd":"/Users/someone/dev/secret","prompt":"my private prompt","last_assistant_message":"You'"'"'ve hit your session limit · resets 7am"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" == *"resets 7am"* ]]
    [[ "$output" != *"private prompt"* ]]
    [[ "$output" != *someone* ]]
    [[ "$output" != *secret* ]]
}

@test "harness hook: plain private text in error_details is redacted (no secret shape)" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","error":"rate_limit","error_details":"customer Acme owes money"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *Acme* ]]
    [[ "$output" == *'"error":"rate_limit"'* ]]
}

@test "harness hook: unlisted keys with plain text are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"extra_note":"Customer Acme owes 50k","error_info":"private plan about merger","agent_type":"my private agent name"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *Acme* ]]
    [[ "$output" != *merger* ]]
    [[ "$output" != *"private agent"* ]]
    [[ "$output" != *extra_note* ]]
}

@test "harness hook: strings in arrays and under nested unlisted keys are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"items":["my private text in array"],"nested":{"foo":"internal codename ingle"}}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *"private text"* ]]
    [[ "$output" != *codename* ]]
    [[ "$output" != *ingle* ]]
}

@test "harness hook: case variant of a free-text key is dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"LastAssistantMessage":"private words","Last_Assistant_Message":"more private words"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *"private words"* ]]
}

@test "harness hook: Bearer, URL, AIza and sk_live credentials are dropped under any key" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"a":"Bearer abcdef1234567890","message":"postgres://user:pw@host/db","error_details":"AIzaSyA1234567890abcdefghij","b":"sk_live_abc123XYZ"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *Bearer* ]]
    [[ "$output" != *postgres* ]]
    [[ "$output" != *AIza* ]]
    [[ "$output" != *sk_live* ]]
}

@test "harness hook: /private/var, /tmp, spaced and Windows paths are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"a":"/private/var/folders/xx/secret-project","message":"/tmp/secretproj/file.txt","error_details":"/Users/bob/My Docs/tax return/x.pdf","b":"C:\\Users\\bob\\taxes\\x.pdf"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *secret-project* ]]
    [[ "$output" != *secretproj* ]]
    [[ "$output" != *"tax return"* ]]
    [[ "$output" != *bob* ]]
    [[ "$output" != *taxes* ]]
}

@test "harness hook: token-shaped enum values and keys are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"error":"sk-ant-abc123def456","status":"hunter2-password-xyz","model":"acme-merger-plan","mode":"AKIAABCDEFGHIJ12","ghp_abcdefghijklmnopqrstuvwxyz0123456789":1,"MY_SECRET_PW_hunter2":2}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *sk-ant* ]]
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *acme* ]]
    [[ "$output" != *AKIA* ]]
    [[ "$output" != *ghp_* ]]
    [[ "$output" != *SECRET* ]]
}

@test "harness hook: fallback jq skeleton (no extractor beside the script) keeps no text" {
    local d="$BATS_TEST_TMPDIR/lone"
    mkdir -p "$d" && cp "$HARNESS" "$d/h.sh"
    export BORG_SPIKE_DIR="$BATS_TEST_TMPDIR/spike"
    printf '%s' '{"session_id":"s","error":"rate_limit","extra":"private","nested":{"foo":"codename"},"items":["in array"],"n":3}' | "$d/h.sh" hook StopFailure
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *private* ]]
    [[ "$output" != *codename* ]]
    [[ "$output" != *"in array"* ]]
    [[ "$output" != *rate_limit* ]]
    [[ "$output" == *'"<key>":3'* ]]
}

@test "harness hook: long assistant message mentioning limits keeps only the limit sentence" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","last_assistant_message":"Here is how server error handling and rate limit retries work, password hunter2, tail: sk-ant-nope"}'
    _hook '{"session_id":"s","last_assistant_message":"long preamble about hunter2. You'"'"'ve hit your weekly limit · resets Jul 7 at 7am (America/Denver) and then more private words"}'
    run cat "$BORG_SPIKE_DIR/payloads.jsonl"
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *"server error handling"* ]]
    [[ "$output" != *"private words"* ]]
    [[ "$output" != *"weekly limit"* ]]
}

@test "harness hook: transcript_path becomes the fixed fake projects shape" {
    command -v python3 >/dev/null || skip "python3 not installed"
    _hook '{"session_id":"s","transcript_path":"/Users/bob/.claude/projects/-Users-bob-dev-x/abc.jsonl"}'
    run jq -r '.payload.transcript_path' "$BORG_SPIKE_DIR/payloads.jsonl"
    [ "$output" = "/Users/noah/dev/example/.claude/projects/-Users-noah-dev-example/<sid>.jsonl" ]
}

@test "harness scrubpane: redacts every line outside the allowlist" {
    run bash -c "printf '%s\n' 'my private prompt about hunter2' '│ > token sk-ant-abc │' '  ls /Users/someone/dev/x' '❯ 1. Yes' '  ? for shortcuts' | '$HARNESS' scrubpane"
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *sk-ant* ]]
    [[ "$output" != *someone* ]]
    [[ "$output" == *"❯ 1. Yes"* ]]
    [[ "$output" == *"? for shortcuts"* ]]
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
    [[ "$output" == *StopFailure* ]]
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
    [[ "$output" == *"<redacted>"* ]]
    [[ "$output" == *"1. Yes"* ]]
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *someone* ]]
}

@test "extractor: keeps enum fields and strict limit sentence, drops everything else" {
    command -v python3 >/dev/null || skip "python3 not installed"
    local in out
    in='{"type":"assistant","error":"rate_limit","isSidechain":false,"apiErrorStatus":429,"uuid":"4cfc980b-e51b-42da-9cd5-d75d0a33c88c","parentUuid":"d0165fec-e970-4833-91d8-7dfb071cebe6","cwd":"/Users/bob/dev/x","timestamp":"2026-07-05T17:59:00.619Z","gitBranch":"feat/secret","message":{"content":[{"type":"text","text":"You'"'"'ve hit your weekly limit · resets Jul 7 at 7am (America/Denver)"}]},"note":"token sk-ant-abc123 bob@example.com","long":"You'"'"'ve hit your weekly limit · resets 7am and my password is hunter2"}'
    out="$(printf '%s' "$in" | python3 -I "$SKEL" scrub)"
    [[ "$out" == *'"error":"rate_limit"'* ]]
    [[ "$out" == *'"apiErrorStatus":429'* ]]
    [[ "$out" == *"weekly limit · resets Jul 7 at 7am (America/Denver)"* ]]
    [[ "$out" == *"00000000-0000-4000-8000-000000000001"* ]]
    [[ "$out" == *"00000000-0000-4000-8000-000000000002"* ]]
    [[ "$out" != *4cfc980b* ]]
    [[ "$out" != *bob* ]]
    [[ "$out" != *sk-ant* ]]
    [[ "$out" != *hunter2* ]]
    [[ "$out" != *secret* ]]
    [[ "$out" == *'"<key>":"<str>"'* ]]
}

@test "extractor: unlisted string keys and odd object keys never survive" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run bash -c "printf '%s' '{\"customField\":\"hello\",\"/Users/bob/x\":1,\"level\":\"suggestion\",\"type\":\"has space and words\"}' | python3 -I '$SKEL' scrub"
    [[ "$output" != *hello* ]]
    [[ "$output" != *bob* ]]
    [[ "$output" == *'"level":"suggestion"'* ]]
    [[ "$output" == *'"type":"<str>"'* ]]
}

@test "extractor: enum values outside the closed set or token-shaped are dropped" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run bash -c "printf %s "error":"made_up_kind" | python3 -I  --stdin"
    [[ "$output" == *role:assistant* ]]
    [[ "$output" != *made_up_kind* ]]
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *acme* ]]
    [[ "$output" != *AKIA* ]]
    [[ "$output" != *sk-ant* ]]
}

@test "extractor: token-shaped and unknown keys become <key>" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run bash -c "printf %s "ghp_abcdefghijklmnopqrstuvwxyz0123456789":1 | python3 -I  --stdin"
    [[ "$output" == *type:user* ]]
    [[ "$output" != *ghp_* ]]
    [[ "$output" != *hunter2* ]]
    [[ "$output" != *acme* ]]
}
