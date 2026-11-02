#!/usr/bin/env bash
# LIVE run of the four link-next cases through `claude plugin eval`. A developer command: it spends money, so it
# is not under run.sh, not in any Makefile target and not in CI. `make eval` stays offline.
#
#   usage: evals/link-next/live.sh [--runs N] [--model M] [--max-cost-usd USD] [--case NAME]
#
#   --runs N            runs per case (default 3, the directive's figure)
#   --model M           the model the runner uses for every case (default sonnet; haiku is flaky here, see directive)
#   --max-cost-usd USD  hard ceiling for EACH case's invocation (default 1); the runner checks it before each run
#   --case NAME         one case only (default: all four)
#
# One plugin sandbox per case (sandbox.sh), because the fixture is baked into the sandbox copy of the skill. The
# baseline arm is off (--ablation none): the question is whether the skill obeys its own sentence, not whether it
# beats no skill. Results land in evals/link-next/out/live/<case>/ with the runner's report and aggregate JSON;
# the per-case cost is the runner's own figure, printed at the end. The runner does not report the model id, so
# this script prints the model it was told to use and the date, for the report.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
RUNS=3; MODEL=sonnet; CEILING=1; ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --runs) RUNS="$2"; shift ;;
        --model) MODEL="$2"; shift ;;
        --max-cost-usd) CEILING="$2"; shift ;;
        --case) ONLY="$2"; shift ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

# THE RUN HISTORY (borg_core/evals/history.py; BORG_EVAL_HISTORY overrides the file): one record per case, and one
# `error` record for an environmental abort. The runner reports no model id, turns or tokens, so those stay null.
# Cost is the runner's aggregate-result.json `costUsd` (one number for the whole invocation, judge calls included),
# read by the core's parser from the file named in $4; a missing, unreadable or unrecognized file records null,
# which the sweep then charges at the per-case ceiling.
_rec() {
    command -v python3 >/dev/null 2>&1 || return 0
    PYTHONPATH="$REPO" python3 -m borg_core.evals.history --record --harness link-next --case "$1" \
        --verdict "$2" --reason "$3" --repo "$REPO" ${4:+--plugin-eval-result "$4"} \
        || echo "warning: could not append to the eval history" >&2
}
command -v claude >/dev/null 2>&1 || { _rec preflight error "claude CLI not found on PATH"; echo "claude CLI not found on PATH; the live run cannot start" >&2; exit 2; }

OUT="$HERE/out/live"
# A one-case run clears ONLY that case's evidence, so a caller looping over `--case` (the weekly sweep) keeps every
# earlier case's report and stdout; the all-cases run resets the whole directory. A name that is not a case
# directory is refused BEFORE anything is removed, so `--case ../x` cannot aim the removal elsewhere.
if [ -n "$ONLY" ]; then
    [ -d "$HERE/cases/$ONLY" ] && [ "${ONLY#*/}" = "$ONLY" ] || { echo "unknown case: $ONLY" >&2; exit 2; }
    rm -rf "$OUT/$ONLY"
else
    rm -rf "$OUT"
fi
mkdir -p "$OUT"
echo "live run: model=$MODEL runs=$RUNS ceiling=\$$CEILING per case, $(date -u +%Y-%m-%dT%H:%MZ)"

rc=0
for casedir in "$HERE"/cases/*/; do
    c="${casedir%/}"; c="${c##*/}"
    [ -z "$ONLY" ] || [ "$ONLY" = "$c" ] || continue
    bash "$HERE/sandbox.sh" "$c" "$OUT/$c/plugin" || { _rec "$c" error "sandbox build failed"; echo "sandbox failed: $c" >&2; rc=1; continue; }
    allow="$(sed -n 's/^allow_tools=//p' "$casedir/sandbox.conf")"
    allow="${allow//@STUB@/$OUT/$c/plugin/bin/borg}"
    ANTHROPIC_API_KEY= claude plugin eval "$OUT/$c/plugin" ${allow:+--allow-tools "$allow"} \
        --model "$MODEL" --runs "$RUNS" --ablation none \
        --max-cost-usd "$CEILING" --trust-plugin --no-publish --output-dir "$OUT/$c/result" \
        --report "$OUT/$c/report.html" --keep-temp > "$OUT/$c/stdout.txt" 2>&1
    case_rc=$?
    echo "== $c (runner exit $case_rc)"
    tail -n 6 "$OUT/$c/stdout.txt"
    # The runner's exit codes: 0 met the threshold; 1 below it or a load error; 2 partial (cost ceiling or auth);
    # 130 interrupted; 143 terminated. A cost ceiling is a skip (the plan: a case over its cap is skipped), an
    # auth failure or an interruption is an error (no evidence either way), anything else nonzero is a fail.
    agg="$OUT/$c/result/aggregate-result.json"; [ -s "$agg" ] || agg=""
    partial=""; [ -n "$agg" ] && partial="$(jq -r '.partialReason // empty' "$agg" 2>/dev/null)"
    case "$case_rc:$partial" in
        0:*) _rec "$c" pass "" "$agg" ;;
        2:cost_ceiling) _rec "$c" skip "cost ceiling \$$CEILING reached" "$agg"; rc=1 ;;
        2:auth_failed) _rec "$c" error "runner auth failed" "$agg"; rc=1 ;;
        130:*|143:*) _rec "$c" error "runner interrupted (exit $case_rc)" "$agg"; rc=1 ;;
        *) _rec "$c" fail "runner exit $case_rc" "$agg"; rc=1 ;;
    esac
done
exit "$rc"
