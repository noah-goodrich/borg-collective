#!/usr/bin/env bats
# Tests for hooks/borg-dispatch-guard.sh — the >=92% dispatch hard-stop veto (PreToolUse).
#
# Contract: a PreToolUse hook on Agent|Workflow. When ARMED (BORG_USAGE_HALT_ENABLED=1) and the
# guardian's latest sample is a FRESH ok row at/above the halt threshold, it DENIES dispatch (exit
# 2, reason on stderr). In every other case — disabled, below threshold, or ANY uncertainty (stale
# sample, missing/garbage file, non-ok row, non-numeric pct, missing jq, non-dispatch tool) — it
# ALLOWS (exit 0). Fail-OPEN is the safety contract: a guardian problem must never wedge dispatch.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-dispatch-guard.sh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    export BORG_USAGE_SAMPLES="${BATS_TEST_TMPDIR}/usage-samples.jsonl"
    # Deterministic, portable "now" so freshness math never depends on the machine clock or on
    # date-arithmetic direction differing between macOS and Linux.
    export BORG_USAGE_NOW_EPOCH=1000000000
}

# ISO-8601 UTC string for an epoch (both date dialects).
_iso_from_epoch() {
    date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}

# Write a single ok sample row aged `age_sec` before NOW. Args: pct age_sec [resets_at]
_write_ok_row() {
    local pct="$1" age="$2" resets="${3:-Jul 21 at 2:50pm (America/Denver)}"
    local ts
    ts=$(_iso_from_epoch $(( BORG_USAGE_NOW_EPOCH - age )))
    jq -nc --arg ts "$ts" --argjson pct "$pct" --arg r "$resets" \
        '{ts:$ts, status:"ok", pane_count:2, session_pct:$pct, week_pct:10, resets_at:$r}' \
        > "$BORG_USAGE_SAMPLES"
}

# Minimal PreToolUse input JSON for a given tool name.
_input() {
    jq -nc --arg t "$1" '{tool_name:$t, session_id:"s1", cwd:"/Users/noah/dev/ingle"}'
}

# ─── criterion 1: DEFAULT-OFF ────────────────────────────────────────────────

@test "default-OFF: disabled + fresh 95% ok row + Agent -> allow (exit 0)" {
    _write_ok_row 95 0
    # BORG_USAGE_HALT_ENABLED intentionally unset.
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

# ─── criterion 2: DENY when armed + fresh + over threshold ────────────────────

@test "deny: armed + fresh 95% ok row + Agent -> exit 2 with reason naming pct + reset" {
    _write_ok_row 95 0 "Jul 21 at 2:50pm (America/Denver)"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"95"* ]]
    [[ "$output" == *"2:50pm"* ]]
}

@test "deny: armed + fresh over-threshold + Workflow -> exit 2" {
    _write_ok_row 93 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Workflow)"
    [ "$status" -eq 2 ]
}

@test "deny: exactly at the halt threshold (92) -> exit 2" {
    _write_ok_row 92 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 2 ]
}

# ─── criterion 4: below threshold allows ─────────────────────────────────────

@test "allow: armed + fresh 80% ok row + Agent -> exit 0" {
    _write_ok_row 80 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "allow: armed + fresh 91% (one below default 92) + Agent -> exit 0" {
    _write_ok_row 91 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

# ─── criterion 3: FAIL-OPEN on every uncertainty (safety-critical) ───────────

@test "fail-open: armed + over-threshold but STALE sample (older than TTL) -> allow" {
    _write_ok_row 99 100000    # far older than the 300s default TTL
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + missing samples file -> allow" {
    rm -f "$BORG_USAGE_SAMPLES"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + garbage last row -> allow" {
    printf 'this is not json at all\n' > "$BORG_USAGE_SAMPLES"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + last row is non-ok (idle, null pct) -> allow" {
    local ts
    ts=$(_iso_from_epoch "$BORG_USAGE_NOW_EPOCH")
    jq -nc --arg ts "$ts" '{ts:$ts, status:"idle", pane_count:0, session_pct:null, week_pct:null, resets_at:null}' \
        > "$BORG_USAGE_SAMPLES"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + non-numeric session_pct -> allow" {
    local ts
    ts=$(_iso_from_epoch "$BORG_USAGE_NOW_EPOCH")
    jq -nc --arg ts "$ts" '{ts:$ts, status:"ok", pane_count:2, session_pct:"high", week_pct:10, resets_at:"x"}' \
        > "$BORG_USAGE_SAMPLES"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + over-threshold but jq not on PATH -> allow" {
    _write_ok_row 99 0
    export BORG_USAGE_HALT_ENABLED=1
    # A PATH with bash (so `env bash` can start) but NO jq -> the hook must bail open, not
    # crash-block. Empty PATH would break the interpreter itself, which is not what we test here.
    local nojq="${BATS_TEST_TMPDIR}/nojq"
    mkdir -p "$nojq"
    ln -sf "$(command -v bash)" "$nojq/bash"
    PATH="$nojq" run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 0 ]
}

@test "fail-open: armed + empty stdin -> allow" {
    _write_ok_row 99 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<""
    [ "$status" -eq 0 ]
}

# ─── criterion 5: scope + config ─────────────────────────────────────────────

@test "scope: armed + fresh 99% but a non-dispatch tool (Bash) -> allow" {
    _write_ok_row 99 0
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Bash)"
    [ "$status" -eq 0 ]
}

@test "config: BORG_USAGE_HALT_PCT lowers the trigger (50 + fresh 60% -> deny)" {
    _write_ok_row 60 0
    export BORG_USAGE_HALT_ENABLED=1
    export BORG_USAGE_HALT_PCT=50
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 2 ]
}

@test "config: reads the LAST row (a fresh over-threshold row after an older idle row)" {
    local ts_old ts_new
    ts_old=$(_iso_from_epoch $(( BORG_USAGE_NOW_EPOCH - 400 )))
    ts_new=$(_iso_from_epoch "$BORG_USAGE_NOW_EPOCH")
    {
        jq -nc --arg ts "$ts_old" '{ts:$ts, status:"idle", pane_count:0, session_pct:null, week_pct:null, resets_at:null}'
        jq -nc --arg ts "$ts_new" '{ts:$ts, status:"ok", pane_count:2, session_pct:96, week_pct:10, resets_at:"Jul 21 at 2:50pm"}'
    } > "$BORG_USAGE_SAMPLES"
    export BORG_USAGE_HALT_ENABLED=1
    run "$HOOK" <<<"$(_input Agent)"
    [ "$status" -eq 2 ]
}

# ─── criterion 6: wiring + hygiene ───────────────────────────────────────────

@test "wiring: build-plugin.sh registers the guard as a PreToolUse Agent|Workflow hook" {
    # (a) hooks.json wiring: the matcher entry and the hook appear together in the PreToolUse block.
    run grep -A6 '"matcher": "Agent|Workflow"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-dispatch-guard.sh"* ]]
    # (b) build-list: the hook is actually copied into the plugin (not just wired in hooks.json).
    grep -qE '_build_self_contained_hook .*borg-dispatch-guard\.sh' "$BUILD_PLUGIN"
}

@test "hygiene: the hook is executable" {
    [ -x "$HOOK" ]
}
