#!/usr/bin/env bash
# LIVE run of the skill trigger suites through headless `claude -p`. A developer command that spends money, so it is
# not under run.sh, not in any Makefile target and not in CI.
#
#   usage: evals/triggers/live.sh [--mode isolated|in-situ|both] [--skill A[,B]] [--model M] [--jobs N]
#                                 [--max-budget-usd USD] [--out DIR] [--no-record]
#
# Each case is one `claude -p "<query>" --plugin-dir <build of this checkout>` with only the Skill tool, one turn (the skill call is the verdict; the skill body is never run),
# run from a throwaway directory under $TMPDIR (a sandbox inside this repo would let the session read its CLAUDE.md).
#   isolated  adds `--setting-sources project`: only the build under review (plus Claude Code's bundled plugins).
#   in-situ   keeps the user's enabled plugins, the only mode that measures competition between skills.
# The plugin list in the stream's system/init event is checked BEFORE a verdict is graded (borg_core.evals.triggers
# `plugin_problems`); a mismatch (for example a run that became --bare) is recorded as `error` and never as a pass.
# Counting, grading and the Wilson intervals live in borg_core.evals.triggers_cli; the run history is
# borg_core.evals.history (BORG_EVAL_HISTORY overrides the file; each record carries the CLI version from the init
# event, and the report never pools versions). Raw streams stay under --out for diagnosis. A run that never answered
# (session limit, auth) grades as `error`, never as a miss. Re-running into the same --out reuses every stream that
# answered under the same CLI version and only calls the model for the rest (no second history record for those unless RERECORD=1).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
PYTHON="${BORG_EVAL_PYTHON:-python3}"
cli() { PYTHONPATH="$REPO" "$PYTHON" -m borg_core.evals.triggers_cli "$@"; }

if [ "${1:-}" = "--worker" ]; then
    # live.sh --worker MODE SKILL ID  (environment: PLUGIN OUT EXPECT MODEL BUDGET RECORD SBX_ROOT)
    mode="$2"; skill="$3"; id="$4"
    stream="$OUT/streams/$mode-$id.jsonl"
    sandbox="$SBX_ROOT/$mode-$id"; mkdir -p "$sandbox"
    query="$(jq -r --arg id "$id" '.[] | select(.id == $id) | .query' "$HERE/$skill.json")"
    args=(-p "$query" --plugin-dir "$PLUGIN" --tools Skill --output-format stream-json --verbose --model "$MODEL"
        --max-turns 1 --max-budget-usd "$BUDGET" --no-session-persistence)
    [ "$mode" = "isolated" ] && args+=(--setting-sources project)
    expect=(); [ "$mode" = "in-situ" ] && expect=(--expect-file "$EXPECT")
    cached=0
    if [ -s "$stream" ] && jq -e --arg v "$CLIVER" 'select(.type == "system" and .subtype == "init" and .claude_code_version == $v)' "$stream" > /dev/null 2>&1 \
        && jq -e 'select(.type == "result" and ((.is_error | not) or .subtype == "error_max_turns"))' "$stream" > /dev/null 2>&1; then
        cached=1
    else
        (cd "$sandbox" && BORG_NO_SESSION_HOOKS=1 claude "${args[@]}" > "$stream" 2> "$stream.err")
    fi
    out="$(cli grade --suite "$HERE/$skill.json" --id "$id" --stream "$stream" --mode "$mode" --plugin-dir "$PLUGIN" \
        --verdicts "$OUT/verdicts.jsonl" ${expect[@]+"${expect[@]}"} 2>&1)"
    case "$out" in
        ABORT*) verdict=error; reason="$out" ;;
        "VERDICT pass"*) verdict=pass; reason="" ;;
        "VERDICT fail"*) verdict=fail; reason="${out#VERDICT fail }" ;;
        *) verdict=error; reason="grader: $out" ;;
    esac
    echo "$mode $id $verdict $reason"
    if [ "$RECORD" = 1 ] && { [ "$cached" = 0 ] || [ -n "${RERECORD:-}" ]; }; then
        PYTHONPATH="$REPO" "$PYTHON" -m borg_core.evals.history --record --harness triggers --case "$id:$mode" \
            --verdict "$verdict" --reason "$reason" --result "$stream" --repo "$REPO"
    fi
    rm -rf "$sandbox"
    exit 0
fi

MODE=both; ONLY=""; MODEL=sonnet; JOBS=4; BUDGET=1; OUT=""; RECORD=1
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="$2"; shift ;;
        --skill) ONLY="$2"; shift ;;
        --model) MODEL="$2"; shift ;;
        --jobs) JOBS="$2"; shift ;;
        --max-budget-usd) BUDGET="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        --no-record) RECORD=0 ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
for tool in claude jq; do
    command -v "$tool" >/dev/null 2>&1 || { echo "SKIP: $tool not found"; exit 0; }
done
[ "$MODE" = both ] && MODES="isolated in-situ" || MODES="$MODE"
[ -n "$OUT" ] || OUT="${TMPDIR:-/tmp}/borg-triggers-live-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT/streams"
OUT="$(cd "$OUT" && pwd)"
SBX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/borg-triggers-sbx.XXXXXX")"
PLUGIN="$OUT/plugin"
CLIVER="$(claude --version | awk '{print $1}')"
rm -f "$OUT/verdicts.jsonl" "$OUT/results.txt"
PLUGIN_DIR_OVERRIDE="$PLUGIN" bash "$REPO/scripts/build-plugin.sh" > "$OUT/build.log" 2>&1 || { echo "ERROR: plugin build failed, see $OUT/build.log"; exit 1; }
EXPECT="$OUT/expected-plugins.txt"
cli plugins > "$EXPECT"
grep -qx borg-collective "$EXPECT" || echo borg-collective >> "$EXPECT"
export CLIVER PLUGIN OUT EXPECT MODEL BUDGET RECORD SBX_ROOT

: > "$OUT/work.txt"
for suite in "$HERE"/*.json; do
    skill="$(basename "$suite" .json)"
    if [ -n "$ONLY" ]; then case ",$ONLY," in *",$skill,"*) ;; *) continue ;; esac; fi
    for mode in $MODES; do
        jq -r --arg m "$mode" --arg s "$skill" '.[] | "\($m) \($s) \(.id)"' "$suite" >> "$OUT/work.txt"
    done
done
echo "claude $CLIVER, model $MODEL, $(wc -l < "$OUT/work.txt" | tr -d ' ') runs, out $OUT"
xargs -P "$JOBS" -L 1 bash "$HERE/live.sh" --worker < "$OUT/work.txt" | tee "$OUT/results.txt"
rm -rf "$SBX_ROOT"

echo
[ -s "$OUT/verdicts.jsonl" ] && cli report --verdicts "$OUT/verdicts.jsonl" --dir "$HERE" --misfires "$OUT/misfires.json"
cat "$OUT"/streams/*.jsonl | jq -s '[.[] | select(.type == "result") | .total_cost_usd // 0] | "total cost USD: \(add)"' -r
echo "errors: $(grep -c ' error ' "$OUT/results.txt")  (misfires: $OUT/misfires.json)"
