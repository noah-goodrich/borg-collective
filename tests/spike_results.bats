#!/usr/bin/env bats
# Spike results contract (resume design, slice S0b). Asserts the results file exists,
# parses, and has one entry per gating spike. It does NOT assert any outcome is
# confirmed: a refuted outcome selects the documented fallback in the design, so each
# refuted entry (or refuted part) must name one.

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

@test "every entry has a legal outcome, evidence and the tested version and date" {
    run jq -e '.claude_version == "2.1.296" and (.date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
        and (.spikes | all(.outcome as $o | ["confirmed","refuted","not-run"] | index($o) != null)
             and all((.evidence | type == "string") and (.evidence | length) > 0)
             and all(.fallback | type == "string"))' "$RES"
    [ "$status" -eq 0 ]
}

@test "each refuted entry or refuted part names a fallback" {
    run jq -r '.spikes[] | select(.outcome == "refuted" and ((.fallback // "") | length) == 0) | .id' "$RES"
    [ -z "$output" ]
    run jq -r '.spikes[] | .id as $id | (.refuted_parts // [])[]
        | select(((.fallback // "") | length) == 0) | $id' "$RES"
    [ -z "$output" ]
}

@test "each not-run entry says why" {
    run jq -r '.spikes[] | select(.outcome == "not-run" and ((.not_run_parts // []) | length) == 0) | .id' "$RES"
    [ -z "$output" ]
}

@test "non-gating spikes are recorded as unknown" {
    run jq -e '.non_gating | all(.outcome == "unknown")' "$RES"
    [ "$status" -eq 0 ]
}

@test "evidence paths point at existing files" {
    local p
    for p in $(jq -r '.spikes[].evidence_paths[]?' "$RES"); do
        [ -e "$ROOT/$p" ] || { echo "missing $p"; false; }
    done
}

@test "summary doc exists and lists every gating id" {
    local id
    [ -f "$ROOT/docs/resume/spike-results.md" ]
    for id in $GATING; do
        grep -q "$id" "$ROOT/docs/resume/spike-results.md" || { echo "doc lacks $id"; false; }
    done
}

@test "captured-skeleton fixtures from the spikes carry the extractor version" {
    run jq -e --arg v "$(grep -m1 '^VERSION = ' "$ROOT/scripts/resume-skeleton.py" | sed 's/.*"\(.*\)".*/\1/')" \
        '[.fixtures[] | select(.tag == "captured-skeleton")] | length > 0 and all(.extractor == $v)' \
        "$ROOT/tests/fixtures/resume/fixtures.json"
    [ "$status" -eq 0 ]
}

@test "stub proxy parses and binds loopback only" {
    command -v python3 >/dev/null || skip "python3 not installed"
    run python3 -I -m py_compile "$ROOT/spike/stub-proxy.py"
    [ "$status" -eq 0 ]
    run grep -c '"127.0.0.1"' "$ROOT/spike/stub-proxy.py"
    [ "$output" -ge 1 ]
}
