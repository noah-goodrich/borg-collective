#!/usr/bin/env bats
# S4 (borg-resume): hooks/borg-resume-hook.sh and its plugin wiring.
# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (slice S4, "Hook wiring").
#
# The hook is a thin, silent, fail-open forwarder: it maps the Claude Code event to a ledger event and pipes the
# payload into `~/.claude/bin/borg-resume record <event>`. Hooks only append; nothing here transitions state.
# Everything runs in a sandbox: HOME, state dir and PATH stubs. No real tmux, docker, ~/.claude or registry.

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."
HOOK="$ROOT/hooks/borg-resume-hook.sh"
BUILD_PLUGIN="$ROOT/scripts/build-plugin.sh"
FX="$ROOT/tests/fixtures/resume"
SID="00000000-0000-4000-8000-000000000001"

setup() {
    setup_temp_dirs
    command -v jq >/dev/null || skip "jq not installed"
    mkdir -p "$HOME/.claude/bin" "$BATS_TEST_TMPDIR/stubbin"
    ln -s "$ROOT/bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    export BORG_RESUME_LIBDIR="$ROOT/lib/borg"
    export BORG_RESUME_DIR="$BATS_TEST_TMPDIR/resume"
    export BORG_IN_CONTAINER=0
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS TMUX_PANE TMUX
    EV="$BORG_RESUME_DIR/events/$SID.jsonl"
    REG="$BORG_RESUME_DIR/sessions/$SID.json"
    TMUX_LOG="$BATS_TEST_TMPDIR/tmux.calls"
    : >"$TMUX_LOG"
    cat >"$BATS_TEST_TMPDIR/stubbin/tmux" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$TMUX_LOG"
case "\$1" in
    display) printf '%%12\t%s\tborg\texample\t3\t1\t/work/example\n' "\$(cat "$BATS_TEST_TMPDIR/pane_pid")" ;;
esac
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/stubbin/tmux"
    printf '%s' "$$" >"$BATS_TEST_TMPDIR/pane_pid"
    export PATH="$BATS_TEST_TMPDIR/stubbin:$PATH"
}

# _fire <ClaudeEvent> <json>: pipe a payload into the hook the way Claude Code does.
_fire() {
    printf '%s' "$2" | "$HOOK" "$1"
}

_payload() { # <hook_event_name> [extra jq object]
    jq -c -n --arg sid "$SID" --arg e "$1" --argjson x "${2:-{\}}" \
        '{session_id: $sid, cwd: "/work/example", hook_event_name: $e} + $x'
}

# ---- provenance gate (first step of the slice) -------------------------------------------------------------------

@test "provenance: every fixture S4 declares required_captured carries the captured-skeleton tag" {
    run jq -e '.required_captured.S4 as $r | ($r | length) > 0
        and ([$r[] as $n | .fixtures[$n].tag] | all(. == "captured-skeleton"))' "$FX/fixtures.json"
    [ "$status" -eq 0 ]
    RESUME_REQUIRE_CAPTURED=S4 run bats "$ROOT/tests/resume_fixtures.bats" -f "provenance gate: slices in"
    [ "$status" -eq 0 ]
}

# ---- event mapping on CAPTURED payloads --------------------------------------------------------------------------

@test "captured StopFailure payload becomes a stop_failure event with the limit text" {
    run bash -c "'$HOOK' StopFailure <'$FX/stop_failure_payload.json'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "stop_failure" and .sid == "'"$SID"'" and .scope == "main" and .error == "rate_limit"
        and (.msg | test("weekly limit"))' "$EV"
    [ "$status" -eq 0 ]
}

@test "captured SessionStart payload becomes session_start and writes the registry" {
    run bash -c "'$HOOK' SessionStart <'$FX/session_start_payload.json'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "session_start" and .reason == "startup"' "$EV"
    [ "$status" -eq 0 ]
    run jq -e '.session_id == "'"$SID"'" and .source == "startup" and .in_container == false' "$REG"
    [ "$status" -eq 0 ]
}

@test "each registered event maps to its ledger event" {
    local pair ce le
    for pair in SessionEnd:session_end SubagentStart:agent_start SubagentStop:agent_stop \
        PreToolUse:dispatch_intent PostToolUse:dispatch_bound; do
        ce="${pair%%:*}" le="${pair##*:}"
        rm -f "$EV"
        run _fire "$ce" "$(_payload "$ce" '{"agent_id":"a1","reason":"other","tool_use_id":"toolu_1"}')"
        [ "$status" -eq 0 ]
        [ -z "$output" ]
        run jq -e --arg le "$le" '.ev == $le' "$EV"
        [ "$status" -eq 0 ] || { echo "$ce did not map to $le"; false; }
    done
}

@test "Notification maps by notification_type, and an unrelated type records nothing" {
    local pair nt le
    for pair in idle_prompt:idle_prompt permission_prompt:permission_prompt \
        quota_auto_resume_fired:native_resume quota_auto_resume_stale:native_resume \
        quota_auto_resume_disabled:native_resume; do
        nt="${pair%%:*}" le="${pair##*:}"
        rm -f "$EV"
        run _fire Notification "$(_payload Notification '{"notification_type":"'"$nt"'","message":"m"}')"
        [ "$status" -eq 0 ]
        run jq -e --arg le "$le" '.ev == $le' "$EV"
        [ "$status" -eq 0 ] || { echo "$nt did not map to $le"; false; }
    done
    rm -f "$EV"
    run _fire Notification "$(_payload Notification '{"notification_type":"auth_success"}')"
    [ "$status" -eq 0 ]
    [ ! -e "$EV" ]
}

@test "PreToolUse and PostToolUse carry tool_use_id and workflow ids into the event" {
    run _fire PreToolUse "$(_payload PreToolUse '{"tool_name":"Workflow","tool_use_id":"toolu_9",
        "tool_input":{"scriptPath":"/work/example/wf.js","resumeFromRunId":"wf_1"}}')"
    [ "$status" -eq 0 ]
    run jq -e '.ev == "dispatch_intent" and .tool_use_id == "toolu_9" and .script_path == "/work/example/wf.js"
        and .run_id == "wf_1"' "$EV"
    [ "$status" -eq 0 ]
}

# ---- U1: scope is never derived from the StopFailure agent_id ----------------------------------------------------

@test "U1: a StopFailure carrying agent_id still records scope main and a null agent_id" {
    run _fire StopFailure "$(_payload StopFailure '{"error":"rate_limit","agent_id":"a9",
        "last_assistant_message":"x"}')"
    [ "$status" -eq 0 ]
    run jq -e '.scope == "main" and .agent_id == null' "$EV"
    [ "$status" -eq 0 ]
}

@test "a SubagentStop keeps its agent scope (only StopFailure is exempt)" {
    run _fire SubagentStop "$(_payload SubagentStop '{"agent_id":"a9"}')"
    run jq -e '.scope == "agent:a9" and .agent_id == "a9"' "$EV"
    [ "$status" -eq 0 ]
}

# ---- fail-open, silence, no decision -----------------------------------------------------------------------------

@test "garbage, empty and truncated stdin: exit 0, no stdout, nothing recorded" {
    local ev in
    for ev in StopFailure SessionStart Notification PreToolUse bogus ""; do
        for in in "" "not json at all" "{" '{"session_id":' '[1,2,3]' 'null' '{"session_id":"../../etc/x"}'; do
            run bash -c "printf '%s' '$in' | '$HOOK' '$ev'"
            [ "$status" -eq 0 ]
            [ -z "$output" ]
        done
    done
    [ ! -e "$BORG_RESUME_DIR/events" ] || [ -z "$(ls -A "$BORG_RESUME_DIR/events")" ]
}

@test "stdin from /dev/null exits 0 silently" {
    run bash -c "'$HOOK' StopFailure </dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the hook never emits a decision: empty stdout for every event, no decision key in any event line" {
    local ce
    for ce in SessionStart SessionEnd SubagentStart SubagentStop StopFailure PreToolUse PostToolUse; do
        run _fire "$ce" "$(_payload "$ce" '{"decision":"block","reason":"x","error":"rate_limit"}')"
        [ "$status" -eq 0 ]
        [ -z "$output" ]
    done
    run bash -c "grep -c '\"decision\"' '$EV'"
    [ "$output" = "0" ]
    run grep -v '^[[:space:]]*#' "$HOOK"
    [[ "$output" != *decision* ]]
}

@test "a no-op when ~/.claude/bin/borg-resume is missing" {
    rm -f "$HOME/.claude/bin/borg-resume"
    run _fire StopFailure "$(_payload StopFailure '{"error":"rate_limit"}')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$BORG_RESUME_DIR" ]
}

@test "a failing borg-resume never fails the hook, and the failure is logged" {
    rm -f "$HOME/.claude/bin/borg-resume"
    printf '#!/bin/sh\necho boom >&2\nexit 7\n' >"$HOME/.claude/bin/borg-resume"
    chmod +x "$HOME/.claude/bin/borg-resume"
    run _fire StopFailure "$(_payload StopFailure '{"error":"rate_limit"}')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run bash -c "cat '$BORG_RESUME_DIR/hook.log'"
    [[ "$output" == *"stop_failure"* ]]
    [[ "$output" == *"rc=7"* ]]
}

@test "works in a minimal environment (env -i, bare PATH, no HOME-derived vars beyond HOME)" {
    [ -x /usr/bin/jq ] || skip "jq is not in /usr/bin on this machine"
    run env -i HOME="$HOME" PATH="/usr/bin:/bin" BORG_RESUME_LIBDIR="$BORG_RESUME_LIBDIR" \
        BORG_RESUME_DIR="$BORG_RESUME_DIR" BORG_IN_CONTAINER=0 \
        bash -c "printf '%s' '$(_payload StopFailure '{"error":"rate_limit"}')' | '$HOOK' StopFailure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -s "$EV" ]
}

@test "with HOME unset the hook exits 0 and writes nothing" {
    run env -u HOME PATH="$PATH" bash -c "printf '%s' '$(_payload StopFailure '{"error":"rate_limit"}')' \
        | '$HOOK' StopFailure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---- kill switch -------------------------------------------------------------------------------------------------

@test "kill switch: BORG_RESUME_DISABLE=1 records nothing" {
    BORG_RESUME_DISABLE=1 run _fire StopFailure "$(_payload StopFailure '{"error":"rate_limit"}')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$EV" ]
}

@test "kill switch: the DISABLED sentinel pauses injection only, recording continues (S1 contract)" {
    mkdir -p "$BORG_RESUME_DIR"
    : >"$BORG_RESUME_DIR/DISABLED"
    run _fire StopFailure "$(_payload StopFailure '{"error":"rate_limit"}')"
    [ "$status" -eq 0 ]
    [ -s "$EV" ]
}

@test "BORG_NO_SESSION_HOOKS=1 records nothing" {
    BORG_NO_SESSION_HOOKS=1 run _fire SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    [ ! -e "$EV" ]
}

# ---- tmux: SessionStart only, host only --------------------------------------------------------------------------

@test "only SessionStart invokes tmux (host, TMUX_PANE set)" {
    export TMUX_PANE="%12" TMUX=/tmp/sock,1,0
    local ce
    for ce in SessionEnd SubagentStart SubagentStop StopFailure PreToolUse PostToolUse Notification; do
        run _fire "$ce" "$(_payload "$ce" '{"notification_type":"idle_prompt","agent_id":"a1"}')"
        [ "$status" -eq 0 ]
    done
    [ ! -s "$TMUX_LOG" ]
    run _fire SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    run cat "$TMUX_LOG"
    [[ "$output" == *"display"* ]]
    [[ "$output" == *"@borg_sid $SID"* ]]
    run jq -e '.tmux.pane_id == "%12"' "$REG"
    [ "$status" -eq 0 ]
}

@test "container: no tmux call, no pane in the registry, the session is marked in_container (notify-only per U9)" {
    export TMUX_PANE="%12" TMUX=/tmp/sock,1,0
    BORG_IN_CONTAINER=1 run _fire SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$TMUX_LOG" ]
    run jq -e '.in_container == true and .tmux == null and .claude_pid == null' "$REG"
    [ "$status" -eq 0 ]
}

# ---- claude identity and pane binding ----------------------------------------------------------------------------

# _fire_as <argv0> <ClaudeEvent> <json>: run the hook as a child of a process whose argv0 is <argv0>, the way claude
# parents its hooks. The parent writes its own pid to $BATS_TEST_TMPDIR/parent.pid.
_fire_as() {
    printf '%s' "$3" >"$BATS_TEST_TMPDIR/payload.json"
    ( exec -a "$1" bash -c 'echo $$ >"$1"; "$2" "$3" <"$4"; :' _ \
        "$BATS_TEST_TMPDIR/parent.pid" "$HOOK" "$2" "$BATS_TEST_TMPDIR/payload.json" )
}

@test "host registry claude_pid is the hook's parent (alive at record time), not the hook shell" {
    run _fire_as claude SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    local parent
    parent="$(cat "$BATS_TEST_TMPDIR/parent.pid")"
    run jq -e --argjson p "$parent" '.claude_pid == $p and (.claude_start | type == "string")' "$REG"
    [ "$status" -eq 0 ]
}

@test "pane binding needs TMUX as well as TMUX_PANE" {
    export TMUX_PANE="%12"
    run _fire_as claude SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    [ ! -s "$TMUX_LOG" ]
    run jq -e '.tmux == null' "$REG"
    [ "$status" -eq 0 ]
}

@test "a headless claude -p session sharing TMUX_PANE does not steal the pane binding" {
    export TMUX_PANE="%12" TMUX=/tmp/sock,1,0
    run _fire_as "claude" SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    run grep -c "set-option" "$TMUX_LOG"
    [ "$output" = "1" ]
    SID="00000000-0000-4000-8000-000000000002"
    run _fire_as "claude -p" SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    run grep -c "set-option" "$TMUX_LOG"
    [ "$output" = "1" ]
    run grep -c "$SID" "$TMUX_LOG"
    [ "$output" = "0" ]
    run jq -e '.tmux == null and .claude_pid != null' "$BORG_RESUME_DIR/sessions/$SID.json"
    [ "$status" -eq 0 ]
}

@test "a claude outside the pane's process tree is not bound" {
    export TMUX_PANE="%12" TMUX=/tmp/sock,1,0
    printf '%s' "999999" >"$BATS_TEST_TMPDIR/pane_pid"
    run _fire_as claude SessionStart "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    run grep -c "set-option" "$TMUX_LOG"
    [ "$output" = "0" ]
    run jq -e '.tmux == null' "$REG"
    [ "$status" -eq 0 ]
}

@test "container detection honors the dockerenv marker file (override path)" {
    unset BORG_IN_CONTAINER
    : >"$BATS_TEST_TMPDIR/dockerenv"
    BORG_DOCKERENV_FILE="$BATS_TEST_TMPDIR/dockerenv" run _fire SessionStart \
        "$(_payload SessionStart '{"source":"startup"}')"
    [ "$status" -eq 0 ]
    run jq -e '.in_container == true and .claude_pid == null' "$REG"
    [ "$status" -eq 0 ]
}

# ---- latency budgets (measured, not assumed) ---------------------------------------------------------------------

# Best of N runs, in ms. Best-of damps scheduler noise; the budget is a ceiling for the cost of the hook itself.
_best_ms() { # <ClaudeEvent> <payload>
    local best=999999 i s e d
    for i in 1 2 3 4 5; do
        s="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')"
        printf '%s' "$2" | "$HOOK" "$1" >/dev/null 2>&1
        e="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000')"
        d=$((e - s))
        [ "$d" -lt "$best" ] && best=$d
    done
    echo "$best"
}

@test "latency: rare events within 100ms, the Pre/PostToolUse pair within 50ms each (host-measured)" {
    command -v perl >/dev/null || skip "perl needed for ms timing"
    local scale="${BORG_RESUME_HOOK_BUDGET_SCALE:-1}" ms ce
    for ce in StopFailure SubagentStop SessionEnd; do
        ms="$(_best_ms "$ce" "$(_payload "$ce" '{"error":"rate_limit","agent_id":"a1"}')")"
        echo "# $ce: ${ms}ms (budget $((100 * scale))ms)" >&3
        [ "$ms" -le $((100 * scale)) ]
    done
    for ce in PreToolUse PostToolUse; do
        ms="$(_best_ms "$ce" "$(_payload "$ce" '{"tool_name":"Agent","tool_use_id":"toolu_1",
            "tool_input":{"subagent_type":"x"}}')")"
        echo "# $ce: ${ms}ms (budget $((50 * scale))ms)" >&3
        [ "$ms" -le $((50 * scale)) ]
    done
}

# ---- hygiene -----------------------------------------------------------------------------------------------------

@test "hygiene: executable, bash 3.2 syntax, no set -e, no source of repo lib" {
    [ -x "$HOOK" ]
    run /bin/bash -n "$HOOK"
    [ "$status" -eq 0 ]
    ! grep -qE '^[[:space:]]*set -[a-z]*e' "$HOOK"
    ! grep -qE '^[[:space:]]*(source|\.)[[:space:]]' "$HOOK"
}

# ---- plugin wiring -----------------------------------------------------------------------------------------------

_build() {
    export BORG_ORCHESTRATOR_ROOT="$BORG_TEST_HOME/dev"
    export PLUGIN_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/claude-plugins/borg-collective"
    mkdir -p "$PLUGIN_DIR_OVERRIDE"
    run "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    HJ="$PLUGIN_DIR_OVERRIDE/hooks/hooks.json"
}

@test "wiring: hooks.json registers the resume hook for exactly the eight intended events, timeout 5" {
    _build
    run jq -r '[.hooks | to_entries[] | .key as $ev | .value[]
        | select(.hooks[].command | endswith("borg-resume-hook.sh StopFailure")
        or contains("borg-resume-hook.sh")) | $ev] | unique | join(",")' "$HJ"
    [ "$output" = "Notification,PostToolUse,PreToolUse,SessionEnd,SessionStart,StopFailure,SubagentStart,SubagentStop" ]
    run jq -e '[.hooks[][] | .hooks[]
        | select(.command | contains("borg-resume-hook.sh")) | .timeout] | all(. == 5)' "$HJ"
    [ "$status" -eq 0 ]
}

@test "wiring: the resume hook is never on Stop or UserPromptSubmit" {
    _build
    run jq -e '[(.hooks.Stop // [])[], (.hooks.UserPromptSubmit // [])[] | .hooks[].command
        | select(contains("borg-resume-hook"))] | length == 0' "$HJ"
    [ "$status" -eq 0 ]
}

@test "wiring: matchers are Agent|Workflow on Pre/PostToolUse and the regex on Notification" {
    _build
    run jq -r '[.hooks.PreToolUse[], .hooks.PostToolUse[]
        | select(.hooks[0].command | contains("borg-resume-hook")) | .matcher]
        | unique | join(",")' "$HJ"
    [ "$output" = "Agent|Workflow" ]
    run jq -r '.hooks.Notification[] | select(.hooks[0].command | contains("borg-resume-hook")) | .matcher' "$HJ"
    [ "$output" = 'idle_prompt|permission_prompt|quota_auto_resume_.*' ]
}

@test "wiring: the built mirror copy is self-contained and executable" {
    _build
    local built="$PLUGIN_DIR_OVERRIDE/hooks/borg-resume-hook.sh"
    [ -x "$built" ]
    ! grep -qE '^[[:space:]]*(source|\.)[[:space:]]' "$built"
    ! grep -q 'borg-hooks.sh' "$built"
    run diff "$HOOK" "$built"
    [ "$status" -eq 0 ]
}
