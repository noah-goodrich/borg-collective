#!/usr/bin/env bats
# Tests for `borg spend` (AC4: main-vs-subagent spend split from token-spend.jsonl).
#
# The command reads ~/.claude/token-spend.jsonl and reports the main-loop SHARE so the directive's
# "shrink the main-loop share" goal is observable. It must:
#   1. Empty-guard cleanly when the log is absent (exit 0, informational message).
#   2. Compute the correct all-time total and main-loop % from a known fixture.
#   3. Honor --project to filter to a single project.
#   4. State the per-machine caveat (no host field) in the output.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    # token-spend.jsonl lives under ~/.claude (HOME is isolated by setup_temp_dirs).
    mkdir -p "$HOME/.claude"
    export SPEND_LOG="$HOME/.claude/token-spend.jsonl"
}

# Fixture: two sessions with known costs.
#   alpha: main 80, sub 20  → total 100, main 80%
#   beta:  main 90, sub 10  → total 100, main 90%
# Combined: main 170, sub 30 → total 200, main 85%.
_write_fixture() {
    cat > "$SPEND_LOG" <<'EOF'
{"schema":1,"ts":"2026-06-01T10:00:00Z","session_id":"s-alpha","project":"alpha","cwd":"/x","end_reason":"clear","main":{"by_model":{"claude-opus-4-8":{"input":0,"output":0,"cache_creation":0,"cache_read":0}},"est_cost_usd":80},"subagents":{"by_model":{"claude-sonnet-4-6":{"input":0,"output":0,"cache_creation":0,"cache_read":0}},"agent_count":2,"est_cost_usd":20},"est_cost_usd":100}
{"schema":1,"ts":"2026-06-02T10:00:00Z","session_id":"s-beta","project":"beta","cwd":"/y","end_reason":"clear","main":{"by_model":{"claude-opus-4-8":{"input":0,"output":0,"cache_creation":0,"cache_read":0}},"est_cost_usd":90},"subagents":{"by_model":{},"agent_count":1,"est_cost_usd":10},"est_cost_usd":100}
EOF
}

# ─── empty guard ──────────────────────────────────────────────────────────────

@test "spend exits 0 with a message when the log is absent" {
    rm -f "$SPEND_LOG"
    run "$BORG_CMD" spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"No spend recorded"* ]]
}

# ─── all-time totals + main-loop % ────────────────────────────────────────────

@test "spend computes correct total, main, subagent and main %" {
    _write_fixture
    run "$BORG_CMD" spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"total         \$200"* ]]
    [[ "$output" == *"main-loop     \$170"* ]]
    [[ "$output" == *"(85%)"* ]]
    [[ "$output" == *"subagents     \$30"* ]]
    [[ "$output" == *"(15%)"* ]]
}

# ─── per-project filter ───────────────────────────────────────────────────────

@test "spend --project filters to a single project" {
    _write_fixture
    run "$BORG_CMD" spend --project alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"filtered to project: alpha"* ]]
    [[ "$output" == *"total         \$100"* ]]
    [[ "$output" == *"(80%)"* ]]
    # beta must not appear in the filtered trend/breakdown.
    [[ "$output" != *"beta"* ]]
}

# ─── trend + by-project sections present ──────────────────────────────────────

@test "spend shows recent-sessions trend and by-project sections" {
    _write_fixture
    run "$BORG_CMD" spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent sessions"* ]]
    [[ "$output" == *"By project"* ]]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
}

# ─── per-machine caveat ───────────────────────────────────────────────────────

@test "spend states the per-machine caveat (no host field)" {
    _write_fixture
    run "$BORG_CMD" spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"THIS MACHINE only"* ]]
}

# ─── by-model flag computes from raw tokens without erroring ──────────────────

@test "spend --by-model exits 0 and renders a by-model section" {
    _write_fixture
    run "$BORG_CMD" spend --by-model
    [ "$status" -eq 0 ]
    [[ "$output" == *"By model"* ]]
}

# ─── help + dispatch wiring ───────────────────────────────────────────────────

@test "borg help lists spend" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"spend"* ]]
}
