#!/usr/bin/env bash
# Offline half of the Cortex skill-trigger check (#480 step 5). NEVER REACHES A MODEL. It grades the recording that
# live.sh made: a should-fire run must show the skill in the stream AND the hook payloads, a should-not-fire run must
# not, and a known-bad mutation (the skill name swapped) must be rejected. The live half is advisory.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/cortex-skill-trigger/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
PYTHON="${BORG_EVAL_PYTHON:-python3}"
REC="$HERE/recorded"
FAIL=0
expect() { # <want-rc> <label> <check.py args...>
    local want="$1" label="$2"; shift 2
    "$PYTHON" "$HERE/check.py" "$@" > /dev/null 2>&1; local rc=$?
    if [ "$rc" -eq "$want" ]; then echo "  PASS  $label"; else echo "  FAIL  $label (rc $rc, wanted $want)"; FAIL=1; fi
}
[ -s "$REC/stream-fire.jsonl" ] && [ -s "$REC/stream-nofire.jsonl" ] || { echo "  FAIL  no recording in $REC"; exit 1; }
expect 0 "should-fire: pane fired in stream and hooks" grade "$REC/stream-fire.jsonl" pane true "$REC/payloads/skill-hooks.jsonl"
expect 0 "should-not-fire: pane absent from the plain question" grade "$REC/stream-nofire.jsonl" pane false
expect 1 "known-bad: wrong skill name must fail should-fire" grade "$REC/stream-fire.jsonl" borg-next true
expect 1 "known-bad: should-not-fire must fail on the fired run" grade "$REC/stream-fire.jsonl" pane false
expect 1 "known-bad: stream and hooks disagreeing must fail" grade "$REC/stream-nofire.jsonl" pane false "$REC/payloads/skill-hooks.jsonl"
[ "$FAIL" -eq 0 ] && echo "cortex-skill-trigger: all recorded checks pass" || echo "cortex-skill-trigger: FAILED"
exit "$FAIL"
