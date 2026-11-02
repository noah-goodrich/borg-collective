#!/usr/bin/env bats
# The eval run history's shell edges: the report CLI as `make`/launchd will call it, and the cortex live harness's
# preflight abort leaving a record. The logic (Wilson, trends, parsing) is pytest's: borg_core/evals/test_history.py.
# Nothing here reaches a model or the real history file: BORG_EVAL_HISTORY always names a file under the test tmp.

load test_helper/setup

setup() {
    setup_temp_dirs
    export BORG_EVAL_HISTORY="$BATS_TEST_TMPDIR/history.jsonl"
}

@test "history --report: a missing file prints nothing and exits 0" {
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.history --report
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "history --report: prints an interval per case and the per-SHA trend" {
    for v in pass pass fail; do
        PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.history --record --harness h --case P1 --verdict "$v" --sha abcdef0123
    done
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.history --report
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "h/P1  n=3 pass=2 skip=0 error=0  wilson95=[0.208, 0.939]" ]] || false
    [ "${lines[1]}" = "trend h/P1  abcdef0:2/3" ]
}

@test "history: the default store is under the state root, not the config dir" {
    unset BORG_EVAL_HISTORY
    PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.history --record --harness h --case P1 --verdict skip --reason r
    [ -f "$XDG_STATE_HOME/borg/evals/history.jsonl" ]
}

@test "cortex live.sh: a missing tool aborts with one error record naming it" {
    local real
    real="$(command -v python3)"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -sf "$real" "$BATS_TEST_TMPDIR/bin/python3"
    run env PATH="$BATS_TEST_TMPDIR/bin" BORG_EVAL_HISTORY="$BORG_EVAL_HISTORY" "$(command -v bash)" "$BORG_HOME/evals/cortex-agents/live.sh"
    [ "$status" -eq 2 ]
    [ "$(wc -l < "$BORG_EVAL_HISTORY")" -eq 1 ]
    run jq -r '"\(.harness)/\(.case) \(.verdict) \(.reason)"' "$BORG_EVAL_HISTORY"
    [ "$output" = "cortex-agents/preflight error cortex not found on PATH; the live run cannot start" ]
}

@test "link-next live.sh: a missing claude aborts with one error record naming it" {
    local real
    real="$(command -v python3)"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -sf "$real" "$BATS_TEST_TMPDIR/bin/python3"
    run env PATH="$BATS_TEST_TMPDIR/bin" BORG_EVAL_HISTORY="$BORG_EVAL_HISTORY" "$(command -v bash)" "$BORG_HOME/evals/link-next/live.sh"
    [ "$status" -eq 2 ]
    run jq -r '"\(.harness)/\(.case) \(.verdict) \(.reason)"' "$BORG_EVAL_HISTORY"
    [ "$output" = "link-next/preflight error claude CLI not found on PATH" ]
}
