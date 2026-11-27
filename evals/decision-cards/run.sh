#!/usr/bin/env bash
# Offline harness for the decision gate (docs/agents/testing-tiers.md, Tier 1 shadow of a Tier 2 grader). Issue: the
# 2026-10-04, 2026-10-15 and 2026-11-25 misses where a session listed "Needs Noah: #97" instead of asking.
#
# THIS FILE NEVER REACHES A MODEL. grade.py is the grader a live run would apply to a reduced trace of the turn; here it
# runs over hand-authored traces: traces/good*.trace.json must pass, and every traces/bad-*.trace.json must fail (a terse
# list with no AskUserQuestion call; an ask with no context or link; a recommendation not listed first; undescribed
# options; one option). A grader that passes everything, or one that was blanked, turns a known-bad red here.
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model, --skip-network   ACCEPTED AND INERT -- nothing here reads the model or the wire.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/decision-cards/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi
if [ -n "${BORG_EVAL_PYTHON:-}" ]; then
    PYTHON="$BORG_EVAL_PYTHON"
elif [ -x "$REPO/.venv/bin/python" ]; then
    PYTHON="$REPO/.venv/bin/python"
else
    PYTHON="python3"
fi

OUT="$REPO/evals/decision-cards/out"
rm -rf "$OUT"
mkdir -p "$OUT"

PASS=0; FAIL=0; SKIPPED=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    echo "  SKIP  decision-cards: no interpreter ($PYTHON) to run grade.py"
    SKIPPED=$((SKIPPED+1))
    echo
    echo "RESULT: 0 pass, 0 fail, $SKIPPED skip"
    echo "no trace was graded: nothing was verified" >&2
    exit 1
fi

goods=0; bads=0
for trace in "$HERE"/traces/good*.trace.json; do
    goods=$((goods+1))
    if "$PYTHON" -I "$HERE/grade.py" "$trace" >/dev/null; then
        ok "decision-cards: ${trace##*/} passes"
    else
        bad "decision-cards: the known-good ${trace##*/} fails the grader"
    fi
done
for trace in "$HERE"/traces/bad-*.trace.json; do
    bads=$((bads+1))
    if "$PYTHON" -I "$HERE/grade.py" "$trace" >/dev/null; then
        bad "decision-cards: ${trace##*/} PASSED; the grader no longer discriminates"
    else
        ok "decision-cards: ${trace##*/} is graded FAIL"
    fi
done
[ "$goods" -ge 2 ] || bad "decision-cards: needs a known-good trace that asks and one that has nothing to ask"
[ "$bads" -ge 4 ] || bad "decision-cards: needs known-bad traces for a terse list, no context, recommendation not first, no options"

echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "no trace was graded: nothing was verified" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
