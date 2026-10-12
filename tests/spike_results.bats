#!/usr/bin/env bats
# Spike results contract (resume design, slice S0b). Asserts the results file exists,
# parses, and has one entry per gating spike, with the design's outcome vocabulary
# (pass | fail | unknown, plus partial). It does NOT assert any outcome is pass: a fail
# or partial outcome selects the documented fallback in the design. A pass entry must
# carry evidence_paths and no gaps; anything with a gap is partial.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    RES="$ROOT/spike/SPIKE_RESULTS.json"
    GATING="U1 U2 U6 U7 U8 U9 U13 U15 U16 U17"
    command -v jq >/dev/null || skip "jq not installed"
}

@test "results file exists and parses" {
    [ -f "$RES" ]
    run jq -e '.spikes | type == "array"' "$RES"
    [ "$status" -eq 0 ]
}

@test "one entry per gating id, no duplicates, no extras" {
    local id
    for id in $GATING; do
        run jq -e --arg id "$id" '[.spikes[] | select(.id == $id)] | length == 1' "$RES"
        [ "$status" -eq 0 ] || { echo "missing or duplicate $id"; false; }
    done
    run jq -r '[.spikes[].id] | length' "$RES"
    [ "$output" = "10" ]
}

# The outcome contract, as one jq filter (prints one line per violation). It is also run
# against deliberately broken copies below, so the rule itself is under test.
_violations() {
    jq -r '.spikes[] | .id as $id | .outcome as $o
        | ((.not_run_parts // []) | length) as $nr | ((.refuted_parts // []) | length) as $rf
        | ((.evidence_paths // []) | length) as $ev
        | (if (["pass","fail","unknown","partial"] | index($o)) == null then "\($id): illegal outcome \(.outcome)" else empty end),
          (if .outcome == "pass" and ($ev == 0 or $nr > 0 or $rf > 0) then "\($id): pass needs evidence_paths and no not_run_parts or refuted_parts" else empty end),
          (if .outcome == "partial" and ($ev == 0 or ($nr + $rf) == 0) then "\($id): partial needs evidence_paths and a gap" else empty end),
          (if .outcome == "fail" and ((.fallback // "") | length) == 0 then "\($id): fail needs a fallback" else empty end),
          (if .outcome == "unknown" and $nr == 0 then "\($id): unknown needs not_run_parts saying why" else empty end),
          (if (.claude_version | type) != "string" or ((.date // "") | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not) then "\($id): missing claude_version or date" else empty end),
          (if ((.evidence // "") | length) == 0 or ((.fallback | type) != "string") then "\($id): missing evidence text or fallback" else empty end)' "$@"
}

@test "every entry has a legal outcome, per-entry version and date, and honours the pass rule" {
    run _violations "$RES"
    [ -z "$output" ] || { echo "$output"; false; }
    run jq -e '.outcomes == ["pass","fail","unknown","partial"]' "$RES"
    [ "$status" -eq 0 ]
}

@test "the pass rule catches a pass entry that carries a gap" {
    jq '(.spikes[] | select(.id == "U7") | .not_run_parts) = ["something not run"]' "$RES" >"$BATS_TEST_TMPDIR/m1.json"
    run _violations "$BATS_TEST_TMPDIR/m1.json"
    [[ "$output" == *"U7: pass needs"* ]]
    jq '(.spikes[] | select(.id == "U7") | .refuted_parts) = [{"claim":"x","fallback":"y"}]' "$RES" >"$BATS_TEST_TMPDIR/m2.json"
    run _violations "$BATS_TEST_TMPDIR/m2.json"
    [[ "$output" == *"U7: pass needs"* ]]
}

@test "the pass rule catches a pass entry without evidence_paths" {
    jq 'del(.spikes[] | select(.id == "U7") | .evidence_paths)' "$RES" >"$BATS_TEST_TMPDIR/m3.json"
    run _violations "$BATS_TEST_TMPDIR/m3.json"
    [[ "$output" == *"U7: pass needs"* ]]
}

@test "the design vocabulary is enforced: the old words are illegal" {
    jq '(.spikes[] | select(.id == "U7") | .outcome) = "confirmed"' "$RES" >"$BATS_TEST_TMPDIR/m4.json"
    run _violations "$BATS_TEST_TMPDIR/m4.json"
    [[ "$output" == *"U7: illegal outcome"* ]]
}

@test "each refuted part names a fallback" {
    run jq -r '.spikes[] | .id as $id | (.refuted_parts // [])[]
        | select(((.fallback // "") | length) == 0) | $id' "$RES"
    [ -z "$output" ]
}

@test "non-gating spikes are unknown, or a run one with evidence and an honest gap" {
    run jq -e '.non_gating | all(.outcome == "unknown"
        or (.outcome == "partial" and ((.evidence_paths // []) | length) > 0 and ((.not_run_parts // []) | length) > 0)
        or (.outcome == "pass" and ((.evidence_paths // []) | length) > 0 and ((.not_run_parts // []) | length) == 0))' "$RES"
    [ "$status" -eq 0 ]
}

@test "evidence paths point at existing files" {
    local p
    for p in $(jq -r '(.spikes + .non_gating)[].evidence_paths[]?' "$RES"); do
        [ -e "$ROOT/$p" ] || { echo "missing $p"; false; }
    done
}

@test "summary doc has a table row with the matching outcome for every gating id" {
    local id want
    [ -f "$ROOT/docs/resume/spike-results.md" ]
    for id in $GATING; do
        want="$(jq -r --arg id "$id" '.spikes[] | select(.id == $id) | .outcome' "$RES")"
        grep -Eq "^\| ${id}[[:space:]]+\|.*\| ${want}[[:space:]]*\|$" "$ROOT/docs/resume/spike-results.md" \
            || { echo "doc row for $id lacks outcome $want"; false; }
    done
}

@test "event-name sequences: names only, and they show what the results claim" {
    local ev="$ROOT/tests/fixtures/resume/events" f
    for f in "$ev"/*.txt; do
        run grep -Evx 'SessionStart|SessionEnd|Stop|StopFailure|SubagentStart|SubagentStop|Notification|PreToolUse|PostToolUse' "$f"
        [ -z "$output" ] || { echo "$f has a non-event-name line"; false; }
    done
    grep -qx Stop "$ev/clean_turn.txt"
    run grep -cx Stop "$ev/esc_interrupt.txt"
    [ "$output" = "0" ]
    run grep -cx Stop "$ev/queued_two_turns.txt"
    [ "$output" = "2" ]
    grep -qx StopFailure "$ev/subagent_api_error.txt"
    grep -qx SubagentStart "$ev/subagent_api_error.txt"
    run grep -cx SubagentStop "$ev/subagent_api_error.txt"
    [ "$output" = "0" ]
    run grep -cx Notification "$ev/main_limit_weekly.txt"
    [ "$output" = "0" ]
}

@test "failed-run workflow manifest: status completed with null results" {
    run jq -e '.status == "completed" and (.result | type == "array" and length > 0 and all(. == null))' \
        "$ROOT/tests/fixtures/resume/workflows/wf_failed.json"
    [ "$status" -eq 0 ]
}

@test "queued composer pane fixture shows the queue hint" {
    grep -q 'to send now' "$ROOT/tests/fixtures/resume/panes/queued_composer.txt"
    grep -q 'Press up to edit queued messages' "$ROOT/tests/fixtures/resume/panes/queued_composer.txt"
}

@test "captured-skeleton fixtures from the spikes carry the extractor version" {
    run jq -e --arg v "$(grep -m1 '^VERSION = ' "$ROOT/scripts/resume-skeleton.py" | sed 's/.*"\(.*\)".*/\1/')" \
        '[.fixtures[] | select(.tag == "captured-skeleton")] | length > 0 and all(.extractor == $v)' \
        "$ROOT/tests/fixtures/resume/fixtures.json"
    [ "$status" -eq 0 ]
}

@test "stub proxy parses and binds loopback only" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run python3 -I -c 'import py_compile, sys; py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)' \
        "$ROOT/spike/stub-proxy.py" "$BATS_TEST_TMPDIR/stub-proxy.pyc"
    [ "$status" -eq 0 ]
    run grep -c '"127.0.0.1"' "$ROOT/spike/stub-proxy.py"
    [ "$output" -ge 1 ]
}

@test "launchd_probe is recorded outside the gating list, with the pass rule" {
    run jq -e '.launchd_probe | (.outcome == "pass" or .outcome == "partial") and (.evidence | length > 0) and (.claude_version | type == "string")' "$RES"
    [ "$status" -eq 0 ]
    run jq -e '(.launchd_probe.outcome != "pass") or ((.launchd_probe.evidence_paths | length > 0) and ((.launchd_probe.gaps // []) | length == 0))' "$RES"
    [ "$status" -eq 0 ]
    run jq -e '(.launchd_probe.outcome != "partial") or ((.launchd_probe.gaps // []) | length > 0)' "$RES"
    [ "$status" -eq 0 ]
    local p
    for p in $(jq -r '.launchd_probe.evidence_paths[]?' "$RES"); do
        [ -e "$ROOT/$p" ] || { echo "missing $p"; false; }
    done
    if [ "$(jq -r '.launchd_probe.outcome' "$RES")" = "pass" ]; then
        grep -q '^probe_exit=0$' "$ROOT/spike/launchd-probe-evidence.txt"
        grep -Eq '^Current session: [0-9]+% used' "$ROOT/spike/launchd-probe-evidence.txt"
        grep -Eq '^session_pct=[0-9]+$' "$ROOT/spike/launchd-probe-evidence.txt"
    fi
}

@test "summary doc has a launchd_probe row matching the recorded outcome" {
    local want
    want="$(jq -r '.launchd_probe.outcome' "$RES")"
    grep -Eq "^\| launchd_probe[[:space:]]+\|.*\| ${want}[[:space:]]*\|$" "$ROOT/docs/resume/spike-results.md"
}
