#!/usr/bin/env bash
# LIVE Cortex skill-trigger check (ADVISORY: a developer command that spends Cortex credits; not in make eval, not in
# CI, never a required check until it passes -- #480 AC5). Runs evals/cortex-skill-trigger/cases.json through
# headless Cortex (stream-json) in a throwaway repo and grades each run with check.py.
#
#   usage: live.sh [--model M] [--max-turns N] [--ceiling TOKENS] [--record DIR]
#
#   --ceiling TOKENS  per-run ceiling on total tokens (input + cache + output, summed over every case); the run
#                     stops before a case once the total reaches it (default 1500000, about 6 cases; one probe case
#                     measured 150k to 250k). Cortex reports tokens, not credits, so tokens are the ceiling.
#   --record DIR      copy the stripped streams and skill hook payloads to DIR (what run.sh replays)
# Isolation: TMUX_TMPDIR points at an empty directory so a should-fire case cannot split a real tmux pane (the first
# probe did); XDG_* point into the run directory so borg's own hooks write there.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL=claude-sonnet-5-5; MAX_TURNS=6; CEILING=1500000; RECORD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --model) MODEL="$2"; shift ;;
        --max-turns) MAX_TURNS="$2"; shift ;;
        --ceiling) CEILING="$2"; shift ;;
        --record) RECORD="$2"; shift ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
for tool in cortex jq python3 git; do command -v "$tool" >/dev/null 2>&1 || { echo "$tool not found" >&2; exit 2; }; done
RUN="$(mktemp -d "${TMPDIR:-/tmp}/borg-cortex-trigger.XXXXXX")"
PROBE="$RUN/probe"; mkdir -p "$PROBE/.cortex" "$RUN/tmux" "$RUN/payloads"
git -C "$PROBE" init -q
cat > "$RUN/record.sh" <<REC
#!/usr/bin/env bash
cat > "$RUN/payloads/\$(date +%s)\$\$\$RANDOM.json"
REC
chmod +x "$RUN/record.sh"
jq -n --arg r "$RUN/record.sh" '{hooks: {PreToolUse: [{matcher: ".*", hooks: [{type: "command", command: $r, timeout: 30}]}]}}' \
    > "$PROBE/.cortex/settings.local.json"
total=0; fails=0; n=$(jq length "$HERE/cases.json")
for i in $(seq 0 $((n - 1))); do
    if [ "$total" -ge "$CEILING" ]; then echo "ceiling $CEILING reached at $total tokens; stopping before case $i" >&2; break; fi
    id=$(jq -r ".[$i].id" "$HERE/cases.json"); skill=$(jq -r ".[$i].skill" "$HERE/cases.json")
    want=$(jq -r ".[$i].should_fire" "$HERE/cases.json"); query=$(jq -r ".[$i].query" "$HERE/cases.json")
    rm -f "$RUN"/payloads/*.json
    jq -nc --arg t "$query" '{type: "user", message: {role: "user", content: $t}}' \
        | env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$RUN/tmux" XDG_STATE_HOME="$RUN/xs" XDG_CONFIG_HOME="$RUN/xc" XDG_DATA_HOME="$RUN/xd" \
            cortex --input-format stream-json --output-format stream-json --bypass --no-mcp \
                --model "$MODEL" --max-turns "$MAX_TURNS" -w "$PROBE" > "$RUN/stream-$id.jsonl" 2> "$RUN/stderr-$id.txt"
    cat "$RUN"/payloads/*.json 2>/dev/null | jq -c 'select(.tool_name == "skill") | {hook_event_name, tool_name, tool_input}' > "$RUN/hooks-$id.jsonl"
    python3 "$HERE/check.py" grade "$RUN/stream-$id.jsonl" "$skill" "$want" "$RUN/hooks-$id.jsonl" || fails=$((fails + 1))
    used=$(python3 "$HERE/check.py" tokens "$RUN/stream-$id.jsonl"); total=$((total + used))
    echo "  case $id: $used tokens (running total $total of $CEILING)"
done
echo "advisory: $fails failing case(s), $total tokens; run directory $RUN"
if [ -n "$RECORD" ]; then
    mkdir -p "$RECORD/payloads"
    for i in $(seq 0 $((n - 1))); do
        id=$(jq -r ".[$i].id" "$HERE/cases.json")
        [ -f "$RUN/stream-$id.jsonl" ] || continue
        jq -c 'select(.type == "assistant" or .type == "result") | if .type == "assistant" then {type, message: {role: .message.role, model: .message.model, content: [.message.content[] | select(.type != "thinking")]}} else {type, subtype, num_turns, usage, modelUsage} end' "$RUN/stream-$id.jsonl" > "$RECORD/stream-$id.jsonl"
        cp "$RUN/hooks-$id.jsonl" "$RECORD/payloads/hooks-$id.jsonl"
    done
fi
[ "$fails" -eq 0 ]
