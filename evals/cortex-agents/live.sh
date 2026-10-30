#!/usr/bin/env bash
# LIVE run of the Cortex Code agent checks: drives headless Cortex (stream-json, not --print, which trial and
# subscription accounts refuse) through two scripted sessions in a throwaway git repository, then grades what Cortex
# actually did with check.py. A developer command: it spends Cortex credits, so it is not under run.sh, not in any
# Makefile target and not in CI. `make eval` stays offline and replays what this script recorded.
#
#   usage: evals/cortex-agents/live.sh [--model M] [--effort E] [--max-turns N] [--record] [--keep]
#
#   --model M      the main session's model (default claude-sonnet-5-5; must not be a Haiku, A1/A2 compare to it)
#   --effort E     the session effort (default medium; must differ from the scout's `effort: low` pin, A3 needs it)
#   --max-turns N  cap per session (default 30)
#   --record       also write the sanitized run to evals/cortex-agents/recorded/ (what run.sh replays offline)
#   --keep         keep the probe repository instead of deleting it
#
# Session 1 (no borg guard) measures the Cortex facts borg's Cortex support rests on: a borg-collective:<name> agent
# resolves to the installed copy and runs its model pin (A4), the agent's `effort:` pin is ignored for the session's
# effort (A3) and a per-call full model id is honored (A2). Session 1b makes the alias call alone (A1): Cortex writes
# no model on an alias request's history, so only that session's billing can show it ran no Haiku. Session 2
# registers THIS checkout's hooks/borg-agent-model-guard.sh and hooks/borg-nanoprobe-log.sh the way borg setup does
# and checks their live decisions (G0-G5) and rows (L1-L3). See check.py for each check.
#
# Isolation: the agents are installed by this checkout's _borg_install_cortex_agents into the probe's
# .cortex/agents; the hooks go in the probe's .cortex/settings.local.json, which Cortex merges with the user's
# hooks.json. XDG_STATE_HOME/XDG_CONFIG_HOME/XDG_DATA_HOME point into the run directory for the cortex process, so
# the user's own borg hooks (which also fire) write there instead of the real borg state. The two sessions DO stay
# in Cortex's conversation history (~/.snowflake/cortex/conversations): their histories are what A1-A4 read.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
MODEL=claude-sonnet-5-5; EFFORT=medium; MAX_TURNS=30; RECORD=0; KEEP=0
while [ $# -gt 0 ]; do
    case "$1" in
        --model) MODEL="$2"; shift ;;
        --effort) EFFORT="$2"; shift ;;
        --max-turns) MAX_TURNS="$2"; shift ;;
        --record) RECORD=1 ;;
        --keep) KEEP=1 ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done
for tool in cortex jq python3 zsh git; do
    command -v "$tool" >/dev/null 2>&1 || { echo "$tool not found on PATH; the live run cannot start" >&2; exit 2; }
done
if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi
CONV="$HOME/.snowflake/cortex/conversations"

# Kept outside out/, which run.sh deletes on every offline run, so a live run can be re-graded or re-recorded later.
RUN="$HERE/live-runs/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$RUN/payloads" "$RUN/histories" "$RUN/branch-state" "$RUN/xdg/state" "$RUN/xdg/config" "$RUN/xdg/data"
PROBE="$(mktemp -d "${TMPDIR:-/tmp}/borg-cortex-eval.XXXXXX")"
PROBE="$(cd "$PROBE" && pwd -P)"
# shellcheck disable=SC2329  # invoked by the EXIT trap
cleanup() { [ "$KEEP" -eq 1 ] || rm -rf "$PROBE"; }
trap cleanup EXIT

git -C "$PROBE" init -q
git -C "$PROBE" config user.email eval@example.invalid
git -C "$PROBE" config user.name "borg eval"
printf 'probe repository for evals/cortex-agents\n' > "$PROBE/README.txt"
git -C "$PROBE" add README.txt
git -C "$PROBE" commit -q -m init

# The agents, exactly as borg setup installs them (namespaced name, everything else byte-identical).
BORG_HOME="$REPO" zsh -c "source '$REPO/borg.zsh' >/dev/null 2>&1; _borg_install_cortex_agents '$PROBE/.cortex'" \
    > "$RUN/install.log" 2>&1
[ -f "$PROBE/.cortex/agents/borg-scout.md" ] || { echo "agent install failed: $(cat "$RUN/install.log")" >&2; exit 2; }
pin() { sed -n "s/^$2: //p" "$PROBE/.cortex/agents/$1.md" | head -1; }

# The recorder: every payload Cortex sends to the hooks below, verbatim.
cat > "$RUN/record.sh" <<EOF
#!/usr/bin/env bash
payload="\$(cat)"
event="\$(printf '%s' "\$payload" | jq -r '.hook_event_name // "unknown"')"
printf '%s' "\$payload" > "$RUN/payloads/\$event-\$(date +%s)\$\$\$RANDOM.json"
exit 0
EOF
chmod +x "$RUN/record.sh"

# settings.local.json for one session: the recorder always, the branch's guard and logger when $1 is "guarded".
# The logger writes to its own state directory so its rows are told apart from the user's installed logger's.
write_settings() {
    jq -n --arg rec "$RUN/record.sh" --arg guard "$REPO/hooks/borg-agent-model-guard.sh" \
        --arg logger "$REPO/hooks/borg-nanoprobe-log.sh" --arg state "$RUN/branch-state" --arg mode "$1" '
        def cmd($c): {type: "command", command: $c, timeout: 30};
        {hooks: {
            PreToolUse: ([{matcher: "Agent|Task", hooks: [cmd($rec)]}]
                + (if $mode == "guarded" then [{matcher: "Agent|Task", hooks: [cmd("bash " + ($guard | @sh))]}] else [] end)),
            SubagentStart: [{hooks: [cmd($rec)]}],
            SubagentStop: ([{hooks: [cmd($rec)]}]
                + (if $mode == "guarded"
                   then [{hooks: [cmd("XDG_STATE_HOME=" + ($state | @sh) + " bash " + ($logger | @sh))]}] else [] end))
        }}' > "$PROBE/.cortex/settings.local.json"
}

common="Use the description field exactly as given. Run every call in the foreground (run_in_background false).
If a call is denied or fails, do not retry it and do not substitute another agent; go on to the next step.
After the last step, reply with exactly: DONE"
prompt_assume="Automated routing test in $PROBE. Make exactly these task tool calls, in order, then stop.
1. subagent_type \"borg-collective:borg-scout\", description \"A4-name\", prompt \"List the top-level files in $PROBE and reply with their names on one line.\"
2. subagent_type \"Explore\", model \"claude-haiku-5-5\", description \"A2-fullid\", prompt \"Reply with the single word ok. Use no tools.\"
$common"
prompt_alias="Automated routing test in $PROBE. Make exactly this one task tool call, then stop.
1. subagent_type \"Explore\", model \"haiku\", description \"A1-alias\", prompt \"Reply with the single word ok. Use no tools.\"
$common"
prompt_guarded="Automated routing test in $PROBE. Make exactly these task tool calls, in order, then stop.
1. subagent_type \"Explore\", description \"G1-explore\", prompt \"Reply with the single word ok. Use no tools.\"
2. subagent_type \"snowflake-object-discovery\", description \"G2-sfod\", prompt \"Reply with the single word ok. Use no tools.\"
3. subagent_type \"borg-collective:borg-scout\", model \"haiku\", description \"G3-alias\", prompt \"Reply with the single word ok. Use no tools.\"
4. subagent_type \"borg-collective:borg-scout\", description \"G4-scout\", prompt \"List the top-level files in $PROBE and reply with their names on one line.\"
5. subagent_type \"borg-collective:borg-grunt\", description \"G5-grunt\", prompt \"In the git repository $PROBE: create the directory $PROBE/out, write the file $PROBE/out/grunt.txt containing exactly the line OK, then run: git -C $PROBE add out/grunt.txt && git -C $PROBE commit -m 'eval: grunt write'. Reply with the path:line of the file you wrote.\"
$common"

run_session() {
    local name="$1" text="$2"
    write_settings "$name"
    jq -nc --arg t "$text" '{type: "user", message: {role: "user", content: $t}}' \
        | env XDG_STATE_HOME="$RUN/xdg/state" XDG_CONFIG_HOME="$RUN/xdg/config" XDG_DATA_HOME="$RUN/xdg/data" \
            cortex --input-format stream-json --output-format stream-json --bypass --no-mcp \
                --model "$MODEL" --effort "$EFFORT" --max-turns "$MAX_TURNS" -w "$PROBE" \
            > "$RUN/stream-$name.jsonl" 2> "$RUN/stderr-$name.txt"
    echo "== session $name (cortex exit $?): $(jq -r 'select(.type == "result") | "\(.subtype) turns=\(.num_turns) usage=\(.modelUsage | map_values(.outputTokens) | tostring)"' "$RUN/stream-$name.jsonl" 2>/dev/null)"
}

echo "live run: model=$MODEL effort=$EFFORT probe=$PROBE run=$RUN $(date -u +%Y-%m-%dT%H:%MZ)"
run_session assume "$prompt_assume"
run_session alias "$prompt_alias"
run_session guarded "$prompt_guarded"

# Histories: each session's own, plus every subagent's named by a SubagentStart/Stop payload.
for s in assume alias guarded; do
    sid="$(jq -r 'select(.type == "system" and .subtype == "init") | .session_id' "$RUN/stream-$s.jsonl" | head -1)"
    [ -n "$sid" ] && [ -f "$CONV/$sid.history.jsonl" ] && cp "$CONV/$sid.history.jsonl" "$RUN/histories/"
done
for p in "$RUN"/payloads/Subagent*.json; do
    [ -f "$p" ] || continue
    t="$(jq -r '.agent_transcript_path // ""' "$p")"
    h="${t%.json}.history.jsonl"
    [ -n "$t" ] && [ -f "$h" ] && cp "$h" "$RUN/histories/"
done
[ -f "$RUN/branch-state/borg/agents.jsonl" ] && cp "$RUN/branch-state/borg/agents.jsonl" "$RUN/branch-state/agents.jsonl"
git -C "$PROBE" log --format=%s > "$RUN/probe-git-log.txt" 2>/dev/null
cat "$PROBE/out/grunt.txt" > "$RUN/probe-grunt.txt" 2>/dev/null
jq -n --arg probe "$PROBE" --arg model "$MODEL" --arg effort "$EFFORT" --arg cv "$(cortex --version 2>/dev/null | head -1)" \
    --arg sm "$(pin borg-scout model)" --arg se "$(pin borg-scout effort)" --arg gm "$(pin borg-grunt model)" \
    --arg date "$(date -u +%Y-%m-%dT%H:%MZ)" \
    '{probe: $probe, session_model_flag: $model, session_effort_flag: $effort, cortex_version: $cv, date: $date,
      scout_pin_model: $sm, scout_pin_effort: $se, grunt_pin_model: $gm}' > "$RUN/meta.json"

python3 "$HERE/check.py" grade "$RUN" | tee "$RUN/grade.txt"
rc=${PIPESTATUS[0]}
python3 "$HERE/check.py" replay "$RUN" "$REPO" | tee "$RUN/replay.txt"
[ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
if [ "$RECORD" -eq 1 ]; then
    if [ "$rc" -eq 0 ]; then
        python3 "$HERE/check.py" sanitize "$RUN" "$HERE/recorded" && echo "recorded: $HERE/recorded"
    else
        echo "not recorded: the live run did not pass (exit $rc)" >&2
    fi
fi
echo "run directory: $RUN"
exit "$rc"
