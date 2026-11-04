#!/usr/bin/env bash
# Offline harness (Tier 1) for the agent gates: borg-nanoprobe's scope gate, borg-verifier (the engine of
# /borg-verify), and the four leaf workers borg-grunt, borg-scout, borg-reviewer and borg-researcher (GR*, SC*, RW*, RE*). THIS FILE NEVER REACHES A MODEL, THE WIRE OR A CREDENTIAL. The live half is live.sh (headless
# `claude -p --agent`, a developer command that spends money, never CI); it records each case as a sanitized,
# content-stripped stream plus sandbox facts under recorded/, and this harness grades those recordings with the same
# check.py that grades a live run:
#
#   ENV       the environment proof: both agents pin a model, the build copies them, the verifier guard allows the
#             exact verification command (`bash verify.sh`) and still denies `git push`, each nanoprobe brief names
#             nothing under test, and the verifier fixture's real verify.sh exits green or red and leaves its nonce.
#   RECORDED  check.py grade recorded/: the claims the live run measured still hold in the recording. NP1-NP3 refuse
#             (prefix, count, no write, sandbox unchanged), NP4 accepts (no refusal, both files, a commit), V1-V4
#             return one JSON verdict whose fields match the seeded defect, with the nonce proving the command ran.
#             PROD is the one real 2026-11-02 SubagentHandback refusal, so the final-message reducer is proven on
#             the production shape too.
#   KNOWN-BAD every mutation in check.py MUTATIONS (a fact made false in a copy of a recording) must be rejected by
#             the check it targets; a check that passes everything turns this red.
#   SANITIZE  this repository is public: check.py sanitize must refuse a recording that would hold the account email,
#             a home path or a session id, writing nothing, and must accept the recordings themselves.
#   FLOORS    a recording that is missing is a failure, never a skip.
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model, --skip-network   ACCEPTED AND INERT -- nothing here reads the model or the wire.
#
# Environment (for the bats cases that mutate a COPY of this directory):
#   BORG_EVAL_REPO     the checkout whose agents/, hooks/ and skills/ the proof reads  (default: two levels up)
#   BORG_EVAL_PYTHON   the interpreter for check.py                (default: $REPO/.venv/bin/python, then python3)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/agent-gates/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
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

OUT="$REPO/evals/agent-gates/out"
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
    local rc
    # ENV
    "$PYTHON" "$HERE/check.py" env "$REPO" > "$OUT/env.txt" 2>&1
    tally env "$OUT/env.txt"

    local want
    for want in NP1 NP2 NP3 NP4 V1 V2 V3 V4 GR1 GR2 SC1 SC2 RW1 RW2 RE1 RE2; do
        if [ ! -f "$REC/$want/meta.json" ]; then
            bad "no recording at $REC/$want: run evals/agent-gates/live.sh --case $want --record"
            return
        fi
    done

    # RECORDED
    "$PYTHON" "$HERE/check.py" grade "$REC" > "$OUT/grade.txt" 2>&1
    rc=$?
    tally recorded "$OUT/grade.txt"
    [ "$rc" -eq 3 ] && bad "recorded: premise broken -- $(grep '^PREMISE' "$OUT/grade.txt" | head -1)"
    [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || [ "$rc" -eq 3 ] || bad "recorded: check.py grade exited $rc"

    # KNOWN-BAD: each mutation must be rejected by its own check, with the verdict it declares (fail, or skip when
    # the mutation takes away the premise a case needs).
    local kind target expect
    while read -r kind target expect; do
        [ -n "$kind" ] || continue
        if ! "$PYTHON" "$HERE/check.py" mutate "$REC" "$kind" "$OUT/bad-$kind" > "$OUT/bad-$kind.log" 2>&1; then
            bad "known-bad $kind: the mutation could not be built -- $(head -1 "$OUT/bad-$kind.log")"
            continue
        fi
        "$PYTHON" "$HERE/check.py" grade "$OUT/bad-$kind" > "$OUT/bad-$kind.txt" 2>&1
        if grep -q "^CHECK $expect $target " "$OUT/bad-$kind.txt"; then
            ok "known-bad $kind is rejected by $target ($expect)"
        else
            bad "known-bad $kind did not $expect $target; that check no longer discriminates"
        fi
    done < <("$PYTHON" "$HERE/check.py" mutations)

    # SANITIZE: the refusal that keeps a leak out of recorded/ must fire on each planted leak and write nothing, and
    # must not fire on the recordings themselves.
    local name leak
    while IFS='|' read -r name leak; do
        rm -rf "$OUT/leaky-$name" "$OUT/leaky-$name-out"
        mkdir -p "$OUT/leaky-$name"
        cp -R "$REC/NP4" "$OUT/leaky-$name/NP4"
        printf '%s\n' "{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"$leak\"}]}}" \
            >> "$OUT/leaky-$name/NP4/stream.jsonl"
        "$PYTHON" "$HERE/check.py" sanitize "$OUT/leaky-$name" "$OUT/leaky-$name-out" > "$OUT/leaky-$name.txt" 2>&1
        rc=$?
        if [ "$rc" -eq 3 ] && grep -q 'sanitize refused' "$OUT/leaky-$name.txt" && [ ! -e "$OUT/leaky-$name-out" ]; then
            ok "sanitize refuses a recording that would hold $name, and writes nothing"
        else
            bad "sanitize did not refuse a planted $name (exit $rc)"
        fi
    done <<'LEAKS'
an account email|mail someone@gmail.com now
a home path|see /Users/someone/project
a session id|session 0e958b2a-1b2c-4d3e-8f4a-5b6c7d8e9f0a
system prompt text|<system-reminder> Contents of the global instructions
LEAKS
    if "$PYTHON" "$HERE/check.py" sanitize "$REC" "$OUT/clean-out" > "$OUT/clean.txt" 2>&1; then
        ok "sanitize accepts every committed recording (nothing in them needs refusing)"
    else
        bad "sanitize refuses a committed recording -- $(head -1 "$OUT/clean.txt")"
    fi
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
