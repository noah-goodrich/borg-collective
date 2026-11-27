#!/usr/bin/env bash
# Offline harness (Tier 1) for the skill trigger suites (#480 step 4, AC4). NEVER reaches a model, the wire or a
# credential. The live half is live.sh (headless `claude -p`, a developer command that spends money, never CI).
#
#   SUITES   every evals/triggers/<skill>.json is admissible (>= 20 cases, >= 40% near-misses, no hints) and names a
#            self-firing skill; with --complete (set once every batch has landed) every self-firing skill has one.
#   FLOORS   the runner aborts, never grades, when the plugin list is wrong: a --bare run (no plugin) aborts in both
#            modes, an isolated run with an extra plugin aborts, an in-situ run whose list differs from the enabled set
#            aborts, a run that never answered (session limit) aborts instead of grading as a miss, and an abort writes
#            no verdict row. A matching list grades. (floor/*.jsonl are init-shaped
#            streams; a real --bare run needs an API key, so its empty list is hand-written here.)
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model, --skip-network   ACCEPTED AND INERT. --complete: require a suite for every self-firing skill.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
COMPLETE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        --complete) COMPLETE="--complete" ;;
        -h|--help) echo "usage: evals/triggers/run.sh [--skip-model] [--skip-network] [--complete]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi
if [ -n "${BORG_EVAL_PYTHON:-}" ]; then PYTHON="$BORG_EVAL_PYTHON"
elif [ -x "$REPO/.venv/bin/python" ]; then PYTHON="$REPO/.venv/bin/python"
else PYTHON="python3"; fi

OUT="$REPO/evals/triggers/out"
rm -rf "$OUT"
mkdir -p "$OUT"
PASS=0; FAIL=0; SKIPPED=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

cli() { PYTHONPATH="$REPO" "$PYTHON" -m borg_core.evals.triggers_cli "$@"; }
F="$HERE/floor"
BUILD=/build/borg-collective

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    skip "interpreter '$PYTHON' not found -- set BORG_EVAL_PYTHON"
else
    # shellcheck disable=SC2086
    if cli validate --dir "$HERE" --skills "$REPO/skills" $COMPLETE > "$OUT/validate.txt" 2>&1; then
        ok "suites: $(grep -c '^suite ' "$OUT/validate.txt") admissible${COMPLETE:+, every self-firing skill covered}"
    else
        bad "suites: $(grep -m1 '^PROBLEM' "$OUT/validate.txt")"
    fi

    # floor cases: <stream> <mode> <expect-file contents|-> <want exit> <label>
    floor() {
        local stream="$1" mode="$2" expect="$3" want="$4" label="$5" rc
        local args=(grade --suite "$F/pane.json" --id pane-01 --stream "$F/$stream" --mode "$mode" --plugin-dir "$BUILD"
            --verdicts "$OUT/v-$label.jsonl")
        if [ "$expect" != "-" ]; then printf '%s\n' "$expect" > "$OUT/e-$label.txt"; args+=(--expect-file "$OUT/e-$label.txt"); fi
        cli "${args[@]}" > "$OUT/$label.txt" 2>&1; rc=$?
        if [ "$rc" -ne "$want" ]; then bad "floor $label: exit $rc, want $want -- $(head -1 "$OUT/$label.txt")"; return; fi
        if [ "$want" -eq 3 ] && [ -e "$OUT/v-$label.jsonl" ]; then bad "floor $label: aborted but wrote a verdict"; return; fi
        ok "floor $label: exit $want"
    }
    floor bare.jsonl isolated - 3 bare-isolated-aborts
    floor bare.jsonl in-situ "borg-collective" 3 bare-in-situ-aborts
    floor wrong-list.jsonl isolated - 3 isolated-extra-plugin-aborts
    floor wrong-list.jsonl in-situ "borg-collective" 3 in-situ-wrong-list-aborts
    floor limit.jsonl isolated - 3 session-limit-run-aborts-not-a-miss
    floor isolated-ok.jsonl isolated - 0 isolated-matching-list-grades
    floor isolated-ok.jsonl in-situ "borg-collective" 0 in-situ-matching-list-grades
    floor wrong-list.jsonl in-situ "borg-collective
hookify" 1 in-situ-matching-list-grades-a-miss
fi

echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "no case was graded: nothing was verified" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
