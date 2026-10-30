#!/usr/bin/env bash
# Offline harness for borg's agents, model guard and run logger in Cortex Code. THIS FILE NEVER REACHES A MODEL.
# The live half is live.sh (headless Cortex, a developer command that spends credits, never CI); it records one
# sanitized run to recorded/, and this harness grades and replays that recording deterministically:
#
#   RECORDED  check.py grade recorded/: the claims the live run measured still hold in the recording (A1-A4: a
#             borg-collective:<name> agent resolves to its installed copy and pin, `effort:` is ignored for the
#             session's, a per-call full id is honored and an alias is not; G0-G5: the guard's live decisions;
#             L1-L3: the logger's live rows).
#   REPLAY    check.py replay recorded/ <repo>: THIS checkout's guard and logger, run on the recorded Cortex
#             payloads and histories, decide and write what they did live (R1, R2). A hook change that would act
#             differently on real Cortex input turns this red.
#   KNOWN-BAD every mutation in check.py MUTATIONS (a fact or a fix made false in a copy of the recording) must be
#             rejected by the check it targets; a check that passes everything turns this red.
#   FLOORS    a recording that is missing or unscripted is a failure, never a skip.
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model, --skip-network   ACCEPTED AND INERT -- nothing here reads the model or the wire.
#
# Environment (for the bats cases that mutate a COPY of this directory):
#   BORG_EVAL_REPO     the checkout whose hooks/ the replay runs   (default: two levels above this file)
#   BORG_EVAL_PYTHON   the interpreter for check.py                (default: $REPO/.venv/bin/python, then python3)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/cortex-agents/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
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

OUT="$REPO/evals/cortex-agents/out"
rm -rf "$OUT"
mkdir -p "$OUT"
REC="$HERE/recorded"

PASS=0; FAIL=0; SKIPPED=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# Turn check.py's `CHECK pass|fail|skip <id> <message>` lines into PASS/FAIL/SKIP, prefixed with $1.
tally() {
    local prefix="$1" file="$2" verdict id msg
    while read -r _ verdict id msg; do
        case "$verdict" in
            pass) ok "$prefix $id: $msg" ;;
            fail) bad "$prefix $id: $msg" ;;
            skip) skip "$prefix $id: $msg" ;;
        esac
    done < <(grep '^CHECK ' "$file")
}

run_cases() {
    if [ ! -f "$REC/meta.json" ]; then
        bad "no recording at $REC: run evals/cortex-agents/live.sh --record"
        return
    fi

    # RECORDED
    "$PYTHON" "$HERE/check.py" grade "$REC" > "$OUT/grade.txt" 2>&1
    rc=$?
    tally recorded "$OUT/grade.txt"
    [ "$rc" -eq 3 ] && bad "recorded: premise broken -- $(grep '^PREMISE' "$OUT/grade.txt" | head -1)"
    [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || [ "$rc" -eq 3 ] || bad "recorded: check.py grade exited $rc"

    # REPLAY
    "$PYTHON" "$HERE/check.py" replay "$REC" "$REPO" > "$OUT/replay.txt" 2>&1
    rc=$?
    tally replay "$OUT/replay.txt"
    [ "$rc" -eq 3 ] && bad "replay: premise broken -- $(grep '^PREMISE' "$OUT/replay.txt" | head -1)"

    # KNOWN-BAD: each mutation must be rejected by its own check, and only a FAIL counts as rejected.
    local kind target
    while read -r kind target; do
        [ -n "$kind" ] || continue
        if ! "$PYTHON" "$HERE/check.py" mutate "$REC" "$kind" "$OUT/bad-$kind" > "$OUT/bad-$kind.log" 2>&1; then
            bad "known-bad $kind: the mutation could not be built -- $(head -1 "$OUT/bad-$kind.log")"
            continue
        fi
        "$PYTHON" "$HERE/check.py" grade "$OUT/bad-$kind" > "$OUT/bad-$kind.txt" 2>&1
        if grep -q "^CHECK fail $target " "$OUT/bad-$kind.txt"; then
            ok "known-bad $kind is rejected by $target"
        else
            bad "known-bad $kind PASSED $target; that check no longer discriminates"
        fi
    done < <("$PYTHON" -c 'import sys; sys.path.insert(0, sys.argv[1]); import check
for k, v in check.MUTATIONS.items(): print(k, v)' "$HERE")
}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    skip "interpreter '$PYTHON' not found -- set BORG_EVAL_PYTHON; check.py cannot run"
else
    run_cases
fi

echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "no case was graded: nothing was verified" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
