#!/usr/bin/env bash
# LIVE run of the four link-next cases through `claude plugin eval`. A developer command: it spends money, so it
# is not under run.sh, not in any Makefile target and not in CI. `make eval` stays offline.
#
#   usage: evals/link-next/live.sh [--runs N] [--model M] [--max-cost-usd USD] [--case NAME]
#
#   --runs N            runs per case (default 3, the directive's figure)
#   --model M           the model the runner uses for every case (default haiku, the cheapest the runner allows)
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
RUNS=3; MODEL=haiku; CEILING=1; ONLY=""
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
command -v claude >/dev/null 2>&1 || { echo "claude CLI not found on PATH; the live run cannot start" >&2; exit 2; }

OUT="$HERE/out/live"
rm -rf "$OUT"
mkdir -p "$OUT"
echo "live run: model=$MODEL runs=$RUNS ceiling=\$$CEILING per case, $(date -u +%Y-%m-%dT%H:%MZ)"

rc=0
for casedir in "$HERE"/cases/*/; do
    c="${casedir%/}"; c="${c##*/}"
    [ -z "$ONLY" ] || [ "$ONLY" = "$c" ] || continue
    bash "$HERE/sandbox.sh" "$c" "$OUT/$c/plugin" || { echo "sandbox failed: $c" >&2; rc=1; continue; }
    allow="$(sed -n 's/^allow_tools=//p' "$casedir/sandbox.conf")"
    allow="${allow//@STUB@/$OUT/$c/plugin/bin/borg}"
    ANTHROPIC_API_KEY= claude plugin eval "$OUT/$c/plugin" ${allow:+--allow-tools "$allow"} \
        --model "$MODEL" --runs "$RUNS" --ablation none \
        --max-cost-usd "$CEILING" --trust-plugin --no-publish --output-dir "$OUT/$c/result" \
        --report "$OUT/$c/report.html" --keep-temp > "$OUT/$c/stdout.txt" 2>&1
    case_rc=$?
    echo "== $c (runner exit $case_rc)"
    tail -n 6 "$OUT/$c/stdout.txt"
    [ "$case_rc" -eq 0 ] || rc=1
done
exit "$rc"
