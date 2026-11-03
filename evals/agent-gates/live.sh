#!/usr/bin/env bash
# LIVE run of the agent-gates cases through headless `claude -p --agent`. A developer command that spends money: it is
# not under run.sh, not in a Makefile target and not in CI. `make eval` stays offline (run.sh grades the recordings).
#
#   usage: evals/agent-gates/live.sh [--case NAME]... [--record] [--max-budget-usd USD]
#
#   --case NAME           one case (repeatable); EVAL_CASES="NP1 V3" does the same. Default: all eight.
#                         NP1-NP4 grade borg-nanoprobe's scope gate; V1-V4 grade borg-verifier (/borg-verify).
#   --record              copy each passing case's sanitized recording to evals/agent-gates/recorded/<case>
#   --max-budget-usd USD  hard `claude --max-budget-usd` ceiling for EACH attempt (default 0.50, EVAL_MAX_BUDGET_USD)
#
# WHAT RUNS. The plugin under test is built from THIS checkout (`PLUGIN_DIR_OVERRIDE=<dir> scripts/build-plugin.sh`)
# and loaded with `--plugin-dir`, so a flag-less run never grades the previous release's agents. No `--model` flag:
# the agent's own `model:` pin is the thing under test (measured 2026-11-03: `--model` OVERRIDES the pin, so passing it
# would grade the wrong model). Instead `--settings '{"model":"haiku"}'` makes the session DEFAULT a different model
# than the pin, so a session that never loaded the agent shows no usage of the pin; `grade` SKIPs a case whose result's
# modelUsage lacks the pin (measured: the agent's pin beats the settings model). Each attempt runs in a throwaway git
# repository under mktemp with the real HOME: a hermetic HOME loses the subscription login, so the user's CLAUDE.md is
# in the session; graders read only the reduced trace, and the recorder commits nothing but a whitelisted subset of the
# stream (see check.py).
#
# NP3 IS A CAPABILITY CASE (pass@3): exactly three deliverables is the boundary of the agent's scope rule and the count
# is the model's own judgment, so NP3 gets up to three attempts and passes if any attempt refuses. Every other case
# gets one. The attempts used are in the reason and the cost is summed over all of them.
#
# WHAT IT PRINTS. One line per case: verdict, cost (the result's total_cost_usd) and turns, then the summed cost, so a
# caller (the weekly sweep) can drive one group at a time. Each case also appends one record to the run history
# (borg_core/evals/history.py; BORG_EVAL_HISTORY overrides the file). The raw stream stays in out/live/<case>/.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
PYTHON="${BORG_EVAL_PYTHON:-python3}"
BUDGET="${EVAL_MAX_BUDGET_USD:-0.50}"
RECORD=0
WANT=()
while [ $# -gt 0 ]; do
    case "$1" in
        --case) WANT+=("$2"); shift ;;
        --record) RECORD=1 ;;
        --max-budget-usd) BUDGET="$2"; shift ;;
        -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
# shellcheck disable=SC2206
[ ${#WANT[@]} -gt 0 ] || WANT=(${EVAL_CASES:-NP1 NP2 NP3 NP4 V1 V2 V3 V4})
for c in "${WANT[@]}"; do
    case " NP1 NP2 NP3 NP4 V1 V2 V3 V4 " in *" $c "*) ;; *) echo "unknown case: $c" >&2; exit 2 ;; esac
done

_rec() {
    PYTHONPATH="$REPO" "$PYTHON" -m borg_core.evals.history --record --harness agent-gates --case "$1" \
        --verdict "$2" --reason "$3" --repo "$REPO" ${4:+--result "$4"} \
        || echo "warning: could not append to the eval history" >&2
}
command -v claude >/dev/null 2>&1 || { _rec preflight error "claude CLI not found on PATH"; echo "claude CLI not found" >&2; exit 2; }

OUT="$HERE/out/live"
for c in "${WANT[@]}"; do rm -rf "${OUT:?}/$c"; done
mkdir -p "$OUT"
PLUGIN="$OUT/plugin"
rm -rf "$PLUGIN"
mkdir -p "$PLUGIN"
PLUGIN_DIR_OVERRIDE="$PLUGIN" "$REPO/scripts/build-plugin.sh" > "$OUT/build.txt" 2>&1 || { _rec preflight error "plugin build failed"; echo "plugin build failed: see $OUT/build.txt" >&2; exit 2; }
if ! "$PYTHON" "$HERE/check.py" env "$REPO" "$PLUGIN" > "$OUT/env.txt" 2>&1; then
    _rec preflight error "environment proof failed"
    echo "environment proof failed: see $OUT/env.txt" >&2
    exit 2
fi

NP_TOOLS='Bash(git:*) Bash(mkdir:*) Bash(ls:*) Bash(cat:*) Bash(pwd:*) Bash(printf:*) Bash(echo:*) Bash(test:*)'
V_TOOLS='Bash(bash:*) Bash(git:*) Bash(ls:*) Bash(cat:*) Bash(pwd:*) Bash(test:*)'

# One attempt of one case into $2 (a directory). Sets VERDICT, REASON, COST, TURNS; adds COST to TOTAL.
_attempt() {
    local c="$1" d="$2" root agent tools result crc subtype
    rm -rf "$d"; mkdir -p "$d"
    root="$(mktemp -d "${TMPDIR:-/tmp}/sbx.XXXXXX")"
    root="$(cd "$root" && pwd -P)"
    VERDICT=error; REASON=""; COST=0; TURNS="?"
    if ! "$PYTHON" "$HERE/check.py" setup "$c" "$root" "$REPO" 2> "$d/setup.err"; then
        REASON="sandbox setup failed: $(head -1 "$d/setup.err")"; return
    fi
    agent="$("$PYTHON" -c 'import json,sys; print(json.load(open(sys.argv[1]))["agent"])' "$root/case.json")"
    case "$agent" in borg-nanoprobe) tools="$NP_TOOLS" ;; *) tools="$V_TOOLS" ;; esac
    ( cd "$root/repo" && claude -p "$(cat "$root/prompt.txt")" --agent "borg-collective:$agent" \
        --settings '{"model":"haiku"}' --plugin-dir "$PLUGIN" --permission-mode acceptEdits --allowedTools "$tools" \
        --output-format stream-json --verbose --max-budget-usd "$BUDGET" > "$d/raw.jsonl" 2> "$d/err.txt" )
    crc=$?
    result="$(grep '"type":"result"' "$d/raw.jsonl" | tail -n 1)"
    COST="$(printf '%s' "$result" | jq -r '.total_cost_usd // 0' 2>/dev/null)"; COST="${COST:-0}"
    TURNS="$(printf '%s' "$result" | jq -r '.num_turns // "?"' 2>/dev/null)"
    subtype="$(printf '%s' "$result" | jq -r '.subtype // "none"' 2>/dev/null)"
    TOTAL="$(awk -v a="$TOTAL" -v b="$COST" 'BEGIN{printf "%.5f", a+b}')"
    if [ "$subtype" != "success" ]; then
        REASON="claude exit $crc, result $subtype (see $d/err.txt)"; return
    fi
    if ! "$PYTHON" "$HERE/check.py" record "$c" "$d/raw.jsonl" "$root" "$d/rec" 2> "$d/record.err"; then
        REASON="the recorder refused to write, nothing was recorded: $(head -1 "$d/record.err")"; return
    fi
    "$PYTHON" "$HERE/check.py" grade "$d/rec" > "$d/grade.txt" 2>&1
    if grep -q '^CHECK fail ' "$d/grade.txt"; then VERDICT=fail
    elif grep -q '^CHECK skip ' "$d/grade.txt"; then VERDICT=skip
    else VERDICT=pass; fi
    REASON="$(grep -m1 '^CHECK fail \|^CHECK skip ' "$d/grade.txt" | cut -d' ' -f3- | head -c 300)"
}

echo "live run: agent-gates cases=${WANT[*]} ceiling=\$$BUDGET per attempt, $(date -u +%Y-%m-%dT%H:%MZ)"
TOTAL=0; rc=0
for c in "${WANT[@]}"; do
    max=1; [ "$c" = NP3 ] && max=3
    n=1; case_cost=0
    while :; do
        d="$OUT/$c"; [ "$n" -eq 1 ] || d="$OUT/$c-attempt$n"
        _attempt "$c" "$d"
        case_cost="$(awk -v a="$case_cost" -v b="$COST" 'BEGIN{printf "%.5f", a+b}')"
        [ "$VERDICT" = pass ] || [ "$n" -ge "$max" ] || [ "$VERDICT" = error ] && break
        echo "   $c attempt $n: $VERDICT -- $REASON (retrying, pass@$max)"
        n=$((n + 1))
    done
    [ "$max" -eq 1 ] || REASON="pass@$max, attempt $n${REASON:+: $REASON}"
    [ "$VERDICT" = pass ] || rc=1
    echo "== $c: $VERDICT \$$case_cost, $TURNS turns on the last attempt${REASON:+ -- $REASON}"
    _rec "$c" "$VERDICT" "$REASON" "$d/raw.jsonl"
    if [ "$RECORD" -eq 1 ] && [ "$VERDICT" = pass ]; then
        rm -rf "${HERE:?}/recorded/$c"
        mkdir -p "$HERE/recorded"
        cp -R "$d/rec" "$HERE/recorded/$c"
    fi
done
echo "total cost: \$$TOTAL over ${#WANT[@]} case(s)"
exit "$rc"
