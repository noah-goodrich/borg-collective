#!/usr/bin/env bats
# The weekly eval sweep, end to end through its real shell harnesses with a STUB claude. Nothing here reaches a model
# or spends anything: the stub is a plain sh script that prints a canned result and logs its argv, and BORG_CLAUDE_BIN
# is the only way the driver finds a claude. The logic (budget rule, guardian, summary) is pytest's:
# borg_core/evals/sweep/test_core.py. These cases pin what only the shell can show: the pinned model and caps reach
# the harness argv, the history and sweep-last.json are written, a spent cap skips the rest, and run.sh keeps its
# opus/xhigh defaults.
#
# The harnesses `rm -rf` their own evals/*/out, so the sweep runs against a COPY of the checkout, never this one.

load test_helper/setup

setup() {
    setup_temp_dirs
    export BORG_EVAL_HISTORY="$BATS_TEST_TMPDIR/history.jsonl"
    export BORG_USAGE_SAMPLES="$BATS_TEST_TMPDIR/no-samples.jsonl"
    export STUB_LOG="$BATS_TEST_TMPDIR/claude.log"
    export STUB_COST=0.2
    export BORG_EVAL_SWEEP_TODAY=2026-11-10
    SANDBOX="$BATS_TEST_TMPDIR/checkout"
    mkdir -p "$SANDBOX" "$BATS_TEST_TMPDIR/stubbin"
    rsync -a --exclude=.git --exclude=.venv --exclude=node_modules --exclude='evals/*/out' "$BORG_HOME/" "$SANDBOX/"
    cat > "$BATS_TEST_TMPDIR/stubbin/claude" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
case "$*" in
  *"reply with the single word READY"*) echo READY; exit 0 ;;
  "plugin eval"*) exit 0 ;;
esac
printf '{"type":"result","subtype":"success","total_cost_usd":%s,"num_turns":2,"usage":{"input_tokens":5,"output_tokens":7},"modelUsage":{"claude-opus-5-5":{}}}\n' "$STUB_COST"
STUB
    chmod +x "$BATS_TEST_TMPDIR/stubbin/claude"
    export BORG_CLAUDE_BIN="$BATS_TEST_TMPDIR/stubbin/claude"
    SUMMARY="$XDG_STATE_HOME/borg/evals/sweep-last.json"
}

sweep() {
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.sweep.cli --repo "$SANDBOX"
}

@test "sweep: pins the model and the caps, builds the plugin, and writes history and the summary" {
    sweep
    # every lifecycle case fails against a stub (nothing authors a manifest), so the sweep needs attention: exit 1
    [ "$status" -eq 1 ]
    [ -f "$SUMMARY" ]
    [ "$(jq -r .schema "$SUMMARY")" = 1 ]
    [ "$(jq -r .model "$SUMMARY")" = claude-opus-5-5 ]
    [ "$(jq -r '.cases | length' "$SUMMARY")" = 49 ]
    [ "$(jq -r '[.cases[] | select(.harness=="link-next" and .verdict=="pass")] | length' "$SUMMARY")" = 4 ]
    grep -q -- '--model claude-opus-5-5' "$STUB_LOG"
    grep -q -- '--max-budget-usd 1.50' "$STUB_LOG"
    grep -q -- '--plugin-dir /' "$STUB_LOG"
    grep -q -- 'plugin eval .* --model claude-opus-5-5 --runs 1 .*--max-cost-usd 1.50' "$STUB_LOG"
    [ "$(wc -l < "$BORG_EVAL_HISTORY")" -ge 10 ]
    grep -q '"harness":"lifecycle-manifests"' "$BORG_EVAL_HISTORY"
    grep -q '"cost_usd":0.2' "$BORG_EVAL_HISTORY"
}

@test "sweep: agent-gates runs with NO --model (its agents' pins are under test), every other harness keeps it" {
    sweep
    jq -e '.cap_usd == 15' "$SUMMARY"
    [ "$(jq -r '[.cases[] | select(.harness=="agent-gates")] | length' "$SUMMARY")" = 16 ]
    [ "$(jq -r '[.cases[] | select(.harness=="agent-gates" and .model!="agent-frontmatter")] | length' "$SUMMARY")" = 0 ]
    grep -q -- '--agent borg-collective:borg-nanoprobe' "$STUB_LOG"
    ! grep -- '--agent' "$STUB_LOG" | grep -q -- '--model '
    grep -- '--agent' "$STUB_LOG" | grep -q -- '--settings {"model":"haiku"}'
    grep -q -- '--model claude-opus-5-5 --effort xhigh' "$STUB_LOG"
}

@test "sweep: the plugin under test is a throwaway build, not the installed plugin and not the checkout" {
    sweep
    local dir
    dir="$(grep -o -- '--plugin-dir [^ ]*' "$STUB_LOG" | head -1)"
    dir="${dir#--plugin-dir }"
    [ -n "$dir" ]
    [[ "$dir" == */borg-sweep-plugin-*/borg-collective ]] || false
    [ ! -e "$dir" ]
}

@test "sweep: a spent cap skips the remaining link-next cases, records each skip, and exits 1" {
    BORG_EVAL_SWEEP_TODAY=2027-01-01 STUB_COST=1.5 sweep
    [ "$status" -eq 1 ]
    [ "$(jq -r '[.cases[] | select(.harness=="link-next" and .verdict=="skip")] | length' "$SUMMARY")" = 4 ]
    jq -e '.spend_usd == 9' "$SUMMARY"
    jq -r '.cases[] | select(.harness=="link-next") | .reason' "$SUMMARY" | grep -q 'sweep cap'
    [ "$(grep -c '"verdict":"skip"' "$BORG_EVAL_HISTORY")" -ge 4 ]
    ! grep -q '^plugin eval' "$STUB_LOG"
}

@test "sweep: a halted usage guardian skips everything and spends nothing" {
    printf '{"status":"ok","session_pct":97,"ts":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$BORG_USAGE_SAMPLES"
    sweep
    [ "$status" -eq 1 ]
    [ ! -s "$STUB_LOG" ]
    [ "$(jq -r '.halted' "$SUMMARY")" != "" ]
    [ "$(jq -r .counts.skip "$SUMMARY")" = 49 ]
}

@test "sweep: no claude is an error for every case, not a silent pass" {
    export BORG_CLAUDE_BIN=/nonexistent/claude
    export BORG_CLAUDE_SEARCH_DIRS="$BATS_TEST_TMPDIR/empty"
    run env PATH="/usr/bin:/bin" PYTHONPATH="$BORG_HOME" python3 -m borg_core.evals.sweep.cli --repo "$SANDBOX"
    [ "$status" -eq 1 ]
    [ "$(jq -r .counts.error "$SUMMARY")" = 49 ]
}

@test "run.sh: still defaults to opus and xhigh, and EVAL_MODEL overrides the model" {
    run env PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" EVAL_CASES=P1 BORG_EVAL_REPO="$SANDBOX" \
        bash "$SANDBOX/evals/lifecycle-manifests/run.sh"
    grep -q -- '--model opus --effort xhigh' "$STUB_LOG"
    : > "$STUB_LOG"
    run env PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" EVAL_CASES=P1 BORG_EVAL_REPO="$SANDBOX" \
        EVAL_MODEL=claude-opus-5-5 EVAL_EFFORT=high bash "$SANDBOX/evals/lifecycle-manifests/run.sh"
    grep -q -- '--model claude-opus-5-5 --effort high' "$STUB_LOG"
    ! grep -q -- '--model opus' "$STUB_LOG"
}

# ── evals/link-next/live.sh: per-case output, the cost parse and the verdict mapping ─────────────────────────────
# A stub `plugin eval` that writes the documented aggregate-result.json into --output-dir and exits with $STUB_EVAL_RC.
_eval_stub() {
    cat > "$BATS_TEST_TMPDIR/stubbin/claude" <<'STUB'
#!/bin/sh
[ "$1 $2" = "plugin eval" ] || exit 0
while [ $# -gt 0 ]; do [ "$1" = "--output-dir" ] && out="$2"; shift; done
mkdir -p "$out"
printf '{"schemaVersion":1,"costUsd":0.31,"partial":false,"partialReason":%s,"unknownField":1}\n' "${STUB_PARTIAL:-null}" > "$out/aggregate-result.json"
echo "runner output"
exit "${STUB_EVAL_RC:-0}"
STUB
    chmod +x "$BATS_TEST_TMPDIR/stubbin/claude"
}

_live() {
    PATH="$BATS_TEST_TMPDIR/stubbin:$PATH" run bash "$SANDBOX/evals/link-next/live.sh" "$@"
}

@test "live.sh --case clears only that case's output, so a loop over cases keeps every case's evidence" {
    _eval_stub
    _live --runs 1 --case next-rows-chooser
    [ "$status" -eq 0 ]
    _live --runs 1 --case link-verdict-honest-none
    [ "$status" -eq 0 ]
    [ -f "$SANDBOX/evals/link-next/out/live/next-rows-chooser/stdout.txt" ]
    [ -f "$SANDBOX/evals/link-next/out/live/link-verdict-honest-none/stdout.txt" ]
    _live --runs 1
    [ -f "$SANDBOX/evals/link-next/out/live/next-empty-no-declined/stdout.txt" ]
}

@test "live.sh refuses a case name that is not a case directory before removing anything" {
    _eval_stub
    mkdir -p "$SANDBOX/evals/link-next/out/live/keep"
    _live --case ../live
    [ "$status" -eq 2 ]
    [ -d "$SANDBOX/evals/link-next/out/live/keep" ]
}

@test "live.sh records the runner's costUsd and maps its exit codes to verdicts" {
    _eval_stub
    _live --case next-rows-chooser
    run jq -r '[.verdict, (.cost_usd|tostring)] | join(" ")' "$BORG_EVAL_HISTORY"
    [ "$output" = "pass 0.31" ]
    : > "$BORG_EVAL_HISTORY"
    STUB_EVAL_RC=2 STUB_PARTIAL='"cost_ceiling"' _live --case next-rows-chooser
    [ "$(jq -r .verdict "$BORG_EVAL_HISTORY")" = skip ]
    [[ "$(jq -r .reason "$BORG_EVAL_HISTORY")" == *"cost ceiling"* ]] || false
    : > "$BORG_EVAL_HISTORY"
    STUB_EVAL_RC=2 STUB_PARTIAL='"auth_failed"' _live --case next-rows-chooser
    [ "$(jq -r .verdict "$BORG_EVAL_HISTORY")" = error ]
    : > "$BORG_EVAL_HISTORY"
    STUB_EVAL_RC=143 _live --case next-rows-chooser
    [ "$(jq -r .verdict "$BORG_EVAL_HISTORY")" = error ]
    : > "$BORG_EVAL_HISTORY"
    STUB_EVAL_RC=1 _live --case next-rows-chooser
    [ "$(jq -r .verdict "$BORG_EVAL_HISTORY")" = fail ]
}

@test "live.sh: a runner that writes no aggregate file records a null cost, not a guess" {
    cat > "$BATS_TEST_TMPDIR/stubbin/claude" <<'STUB'
#!/bin/sh
exit 0
STUB
    _live --case next-rows-chooser
    [ "$(jq -r '.cost_usd|tostring' "$BORG_EVAL_HISTORY")" = null ]
}
