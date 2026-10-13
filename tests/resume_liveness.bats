#!/usr/bin/env bats
# Liveness detector for borg-resume (slice S10), driven through borg-resume watch --once.
# Everything is synthetic: stubbed tmux list-panes (BORG_RESUME_PANES_CMD), notices (BORG_RESUME_NOTIFY_CMD),
# tmux (BORG_RESUME_TMUX_CMD), boot time and clock. No real claude, tmux, docker, launchd or state dir.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    LIB="${BATS_TEST_DIRNAME}/../lib/borg"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_RESUME_LIBDIR="$LIB"
    export BORG_IN_CONTAINER=0
    # 2026-10-12 12:00:00 UTC
    NOW=1791806400
    export BORG_RESUME_NOW_EPOCH=$NOW
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_LIVENESS_GRACE_SEC BORG_RESUME_STALL_MIN
    export BORG_RESUME_BOOT_EPOCH=$((NOW - 86400 * 30))
    export BORG_RESUME_PANES_CMD='true'
    export BORG_RESUME_TMUX_CMD='false'
    export BORG_RESUME_NOTIFY_CMD="printf \"%s\\n\" \"\$3\" >>\"\$BATS_TEST_TMPDIR/delivered\""
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    SID2="00000000-0000-4000-8000-0000000000bb"
    SID3="00000000-0000-4000-8000-0000000000cc"
    SID4="00000000-0000-4000-8000-0000000000dd"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$CWD"
    sleep 0 &
    DEADPID=$!
    wait "$DEADPID"
    ALIVEPID=$$
    ALIVESTART="$(LC_ALL=C ps -o lstart= -p "$ALIVEPID")"
}

watch() { run "$BIN" watch --once; }

lstart_of() { LC_ALL=C date -r "$1" '+%a %b %e %T %Y' 2>/dev/null || LC_ALL=C date -d "@$1" '+%a %b %e %T %Y'; }
set_mtime() { # <file> <epoch>
    touch -t "$(date -r "$2" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$2" +%Y%m%d%H%M.%S)" "$1"
}

# <sid> <pid> <start> [project] [mode] [in_container]
mk_regx() {
    jq -n -c --arg sid "$1" --argjson pid "$2" --arg st "$3" --arg p "${4:-proj}" --arg m "${5:-project}" \
        --argjson c "${6:-false}" --arg cwd "$CWD" \
        '{session_id:$sid, cwd:$cwd, project:$p, mode:$m, in_container:$c, claude_pid:$pid, claude_start:$st,
          tmux:{pane_id:"%1", pane_pid:1, session:"s", window:"win", window_index:1, pane_index:0, project_dir:$cwd}}' \
        >"$RD/sessions/$1.json"
    set_mtime "$RD/sessions/$1.json" $((NOW - 60))
}
# registry of a session whose claude died at DEADPID (started an hour ago)
mk_dead() { mk_regx "$1" "$DEADPID" "$(lstart_of $((NOW - 3600)))" "${2:-proj}" "${3:-project}"; }

t_user() {
    printf '{"type":"user","uuid":"u-%s","cwd":"%s","message":{"role":"user","content":"hello"}}\n' \
        "$RANDOM" "$CWD" >>"$1"
}
t_asst_end() {
    printf '{"type":"assistant","uuid":"a-%s","message":{"role":"assistant","stop_reason":"end_turn",' "$RANDOM" >>"$1"
    printf '"content":[{"type":"text","text":"ok"}]}}\n' >>"$1"
}
t_tool() {
    printf '{"type":"assistant","uuid":"t-%s","message":{"role":"assistant","stop_reason":"tool_use",' "$RANDOM" >>"$1"
    printf '"content":[{"type":"tool_use","id":"x","name":"Agent","input":{}}]}}\n' >>"$1"
}
t_err() { # <file> <uuid> [error] [text]
    printf '{"type":"assistant","uuid":"%s","isApiErrorMessage":true,"error":"%s",' "$2" "${3:-server_error}" >>"$1"
    printf '"message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"%s"}]}}\n' \
        "${4:-API Error: 500}" >>"$1"
}
t_int() {
    printf '{"type":"user","uuid":"i-%s","message":{"role":"user","content":[{"type":"text",' "$RANDOM" >>"$1"
    printf '"text":"[Request interrupted by user]"}]}}\n' >>"$1"
}
t_close() { printf '{"type":"system","subtype":"turn_duration"}\n' >>"$1"; }
# <sid> <kind> ; kinds: open (agent in flight) | idle (finished) | int | err_closed | tool
mk_tr() {
    local f="$PD/$1.jsonl"
    : >"$f"
    t_user "$f"
    case "$2" in
        open) t_tool "$f" ;;
        idle) t_asst_end "$f"; t_close "$f" ;;
        int) t_int "$f" ;;
        err_closed) t_err "$f" e-1; t_close "$f" ;;
        errlimit) t_err "$f" e-9 rate_limit "You have hit your session limit - resets 7:10pm (UTC)" ;;
    esac
    set_mtime "$f" $((NOW - 3600))
}
ev() { # <sid> <json-without-sid>
    printf '%s\n' "$2" | jq -c --arg sid "$1" '. + {sid:$sid}' >>"$RD/events/$1.jsonl"
}

n_pending() { ls "$RD"/pending/*.json 2>/dev/null | wc -l | tr -d ' '; }
n_done() { ls "$RD"/done/*.json 2>/dev/null | wc -l | tr -d ' '; }
all_recs() { cat "$RD"/pending/*.json "$RD"/done/*.json 2>/dev/null; }
rec_q() { all_recs | jq -r -s "$1"; }
n_recs() { all_recs | jq -s 'length'; }

# ---- core death + open work -------------------------------------------------------------------

@test "idle session with no open work is never resumed, even when dead" {
    mk_tr "$SID" idle
    mk_dead "$SID"
    watch
    [ "$status" -eq 0 ]
    [ "$(n_recs)" = 0 ]
}

@test "killed with an agent in flight: one process_death record, 5 minute grace, early notice with cancel hint" {
    mk_tr "$SID" open
    mk_dead "$SID" myproj
    watch
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = main ]
    [ "$(rec_q '.[0].class')" = process_death ]
    [ "$(rec_q '.[0].action')" = resume ]
    [ "$(rec_q '.[0].state')" = scheduled ]
    [ "$(rec_q '.[0].detected_by | join(",")')" = liveness ]
    [ "$(rec_q '.[0].resume_at')" = "$((NOW + 300))" ]
    [ "$(rec_q '.[0].cause')" = pane_closed ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
    run jq -r '.msg' "$RD/notify.jsonl"
    [[ "$output" == *"mark-closed myproj"* ]]
}

@test "a second pass does not create a second record or a second notice (idempotency key)" {
    mk_tr "$SID" open
    mk_dead "$SID"
    watch
    BORG_RESUME_NOW_EPOCH=$((NOW + 30)) run "$BIN" watch --once
    BORG_RESUME_NOW_EPOCH=$((NOW + 60)) run "$BIN" watch --once
    [ "$(n_recs)" = 1 ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
}

@test "pane at a shell (claude exited, pane lives) is a crash" {
    mk_tr "$SID" open
    mk_dead "$SID"
    export BORG_RESUME_PANES_CMD="printf '%%7|$SID|555|zsh\n'"
    watch
    [ "$(rec_q '.[0].cause')" = crash ]
    [ "$(rec_q '.[0].state')" = scheduled ]
}

@test "alive pid with the recorded start time is alive: nothing" {
    mk_tr "$SID" open
    mk_regx "$SID" "$ALIVEPID" "$ALIVESTART"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "alive pid with a different start time (pid reuse) is dead" {
    mk_tr "$SID" open
    mk_regx "$SID" "$ALIVEPID" "$(lstart_of $((NOW - 7200)))"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].class')" = process_death ]
}

@test "no pid evidence and no bound pane is unknown, never death (absence of activity is not death)" {
    mk_tr "$SID" open
    jq -n -c --arg sid "$SID" --arg cwd "$CWD" \
        '{session_id:$sid, cwd:$cwd, project:"proj", in_container:false,
          tmux:{pane_id:"%1", pane_pid:1, window:"win"}}' >"$RD/sessions/$SID.json"
    set_mtime "$RD/sessions/$SID.json" $((NOW - 60))
    watch
    [ "$(n_recs)" = 0 ]
}

@test "a bound pane at a shell with no pid facts is dead; a bound claude pane is alive" {
    mk_tr "$SID" open
    jq -n -c --arg sid "$SID" --arg cwd "$CWD" \
        '{session_id:$sid, cwd:$cwd, project:"proj", in_container:false, tmux:{pane_id:"%1", pane_pid:1}}' \
        >"$RD/sessions/$SID.json"
    set_mtime "$RD/sessions/$SID.json" $((NOW - 60))
    export BORG_RESUME_PANES_CMD="printf '%%7|$SID|555|claude\n'"
    watch
    [ "$(n_recs)" = 0 ]
    export BORG_RESUME_PANES_CMD="printf '%%7|$SID|555|zsh\n'"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].cause')" = crash ]
}

@test "synthetic error plus clean close is open work owned by the scan: no duplicate liveness record" {
    mk_tr "$SID" err_closed
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 1 ]
    [ "$(rec_q '.[0].detected_by | join(",")')" = scan ]
    [ "$(rec_q '.[0].class')" = transient ]
}

@test "open-work test: synthetic error with a trailing close is open, interrupt and clean close are not" {
    mk_tr "$SID" err_closed
    mk_tr "$SID2" idle
    mk_tr "$SID3" int
    mk_tr "$SID4" open
    run bash -c "
        . '$LIB/resume-paths.sh'; . '$LIB/resume-classify.sh'; . '$LIB/resume-inventory.sh'
        . '$LIB/resume-watch.sh'; . '$LIB/resume-liveness.sh'
        for s in $SID $SID2 $SID3 $SID4; do _rl_tail_state '$PD/'\$s.jsonl; done | tr '\n' ' '"
    [ "$output" = "error clean interrupt open " ]
}

# ---- deliberate ends --------------------------------------------------------------------------

@test "SessionEnd prompt_input_exit is a deliberate end: dead + open work, still no record" {
    mk_tr "$SID" open
    mk_dead "$SID"
    ev "$SID" '{"t":1791800000,"ev":"session_end","scope":"main","reason":"prompt_input_exit"}'
    watch
    [ "$(n_recs)" = 0 ]
}

@test "Esc then pane kill is not resumed (the interrupt marker decides)" {
    mk_tr "$SID" int
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "mark-closed project is not resumed" {
    mk_tr "$SID" open
    mk_dead "$SID" closedproj
    "$BIN" mark-closed closedproj
    watch
    [ "$(n_recs)" = 0 ]
}

@test "sticky close: mark_closed then a late SessionEnd other from the dying claude stays closed" {
    mk_tr "$SID" open
    mk_dead "$SID" closedproj
    "$BIN" mark-closed closedproj
    ev "$SID" '{"t":1791806390,"ev":"session_end","scope":"main","reason":"other"}'
    ev "$SID" '{"t":1791806391,"ev":"stop_failure","scope":"main","error":"server_error","msg":"x"}'
    watch
    [ "$(n_recs)" = 0 ]
}

@test "sticky close cancels a record the hook path created after the mark" {
    mk_tr "$SID" open
    mk_dead "$SID" closedproj
    f="$PD/$SID.jsonl"
    t_err "$f" e-77
    "$BIN" mark-closed closedproj
    ev "$SID" '{"t":1791806391,"ev":"stop_failure","scope":"main","error":"server_error","msg":"x"}'
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(rec_q '.[0].state')" = cancelled ]
    [ "$(rec_q '.[0].reason')" = deliberate_end ]
}

@test "a later session_start clears the close: a new death is resumed" {
    mk_tr "$SID" open
    mk_dead "$SID" closedproj
    "$BIN" mark-closed closedproj
    ev "$SID" '{"t":1791806392,"ev":"session_start","scope":"main"}'
    watch
    [ "$(n_pending)" = 1 ]
}

@test "recovery inside the grace window cancels the scheduled liveness record" {
    mk_tr "$SID" open
    mk_dead "$SID"
    watch
    [ "$(n_pending)" = 1 ]
    mk_regx "$SID" "$ALIVEPID" "$ALIVESTART"
    BORG_RESUME_NOW_EPOCH=$((NOW + 60)) run "$BIN" watch --once
    [ "$(n_pending)" = 0 ]
    [ "$(rec_q '.[0].state')" = cancelled ]
    [ "$(rec_q '.[0].reason')" = recovered ]
}

# ---- tmux and docker ---------------------------------------------------------------------------

@test "tmux down (list-panes fails), not a reboot: notify_only, nothing to relaunch into" {
    mk_tr "$SID" open
    mk_dead "$SID"
    export BORG_RESUME_PANES_CMD='exit 1'
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(rec_q '.[0].class')" = notify_only ]
    [ "$(rec_q '.[0].action')" = notify ]
    [ "$(rec_q '.[0].cause')" = tmux_down ]
}

@test "container session is never declared dead (container identity U9 is unestablished): no record" {
    mk_tr "$SID" open
    mk_regx "$SID" 0 "" workspace project true
    watch
    [ "$(n_recs)" = 0 ]
    mk_regx "$SID" "$DEADPID" "$(lstart_of $((NOW - 3600)))" myproj project true
    watch
    [ "$(n_recs)" = 0 ]
}

# ---- reboot staging ---------------------------------------------------------------------------

@test "reboot: dead sessions are staged 20 minutes apart (max 3 per hour), orchestrator first" {
    for s in "$SID" "$SID2" "$SID3" "$SID4"; do mk_tr "$s" open; done
    export BORG_RESUME_BOOT_EPOCH=$((NOW - 600))
    mk_dead "$SID" p1
    mk_dead "$SID2" p2
    mk_dead "$SID3" p3
    mk_dead "$SID4" orch orchestrator
    export BORG_RESUME_PANES_CMD='true'
    watch
    [ "$(n_pending)" = 4 ]
    [ "$(rec_q 'map(.cause) | unique | join(",")')" = reboot ]
    [ "$(rec_q 'map(select(.sid == "'"$SID4"'"))[0].resume_at')" = "$((NOW + 300))" ]
    [ "$(rec_q 'map(.resume_at) | sort | map(. - '"$NOW"' - 300) | join(",")')" = "0,1200,2400,3600" ]
}

# ---- workflows --------------------------------------------------------------------------------

mk_wf() { # a journal with a started step and no result, idle since NOW-3600; owner transcript finished
    mk_tr "$SID" idle
    mkdir -p "$PD/$SID/subagents/workflows/wf_x1"
    printf '{"type":"launched"}\n{"type":"started","key":"k1","agentId":"aw1"}\n' \
        >"$PD/$SID/subagents/workflows/wf_x1/journal.jsonl"
    : >"$PD/$SID/subagents/workflows/wf_x1/agent-aw1.jsonl"
    t_user "$PD/$SID/subagents/workflows/wf_x1/agent-aw1.jsonl"
    t_tool "$PD/$SID/subagents/workflows/wf_x1/agent-aw1.jsonl"
    set_mtime "$PD/$SID/subagents/workflows/wf_x1/journal.jsonl" $((NOW - 3600))
    set_mtime "$PD/$SID/subagents/workflows/wf_x1/agent-aw1.jsonl" $((NOW - 3600))
}

@test "workflow killed: started without result, journal idle, owner dead -> workflow-scope record" {
    mk_wf
    mk_dead "$SID"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = "workflow:wf_x1" ]
    [ "$(rec_q '.[0].class')" = process_death ]
}

@test "workflow with an alive owner and an idle journal is NOT killed" {
    mk_wf
    mk_regx "$SID" "$ALIVEPID" "$ALIVESTART"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "workflow with a journal that is still moving is not killed even if the owner is dead" {
    mk_wf
    set_mtime "$PD/$SID/subagents/workflows/wf_x1/journal.jsonl" $((NOW - 100))
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "workflow: owner logged a limit error -> workflow-scope usage_limit record even with the owner alive" {
    mk_wf
    t_err "$PD/$SID.jsonl" e-9 rate_limit "You have hit your session limit - resets 7:10pm (UTC)"
    mk_regx "$SID" "$ALIVEPID" "$ALIVESTART"
    watch
    [ "$(rec_q 'map(select(.scope == "workflow:wf_x1"))[0].class')" = usage_limit ]
}

@test "an interrupted workflow agent is a deliberate end: no record" {
    mk_wf
    t_int "$PD/$SID/subagents/workflows/wf_x1/agent-aw1.jsonl"
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

# ---- agents -----------------------------------------------------------------------------------

@test "main finished but an orphaned agent is in flight and the owner is dead -> agent-scope record" {
    mk_tr "$SID" idle
    mkdir -p "$PD/$SID/subagents"
    : >"$PD/$SID/subagents/agent-a1.jsonl"
    t_user "$PD/$SID/subagents/agent-a1.jsonl"
    t_tool "$PD/$SID/subagents/agent-a1.jsonl"
    set_mtime "$PD/$SID/subagents/agent-a1.jsonl" $((NOW - 3600))
    mk_dead "$SID"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = "agent:a1" ]
}

@test "an agent that finished or was interrupted is not open work" {
    mk_tr "$SID" idle
    mkdir -p "$PD/$SID/subagents"
    : >"$PD/$SID/subagents/agent-a1.jsonl"
    t_user "$PD/$SID/subagents/agent-a1.jsonl"
    t_int "$PD/$SID/subagents/agent-a1.jsonl"
    : >"$PD/$SID/subagents/agent-a2.jsonl"
    t_user "$PD/$SID/subagents/agent-a2.jsonl"
    t_asst_end "$PD/$SID/subagents/agent-a2.jsonl"
    set_mtime "$PD/$SID/subagents/agent-a1.jsonl" $((NOW - 3600))
    set_mtime "$PD/$SID/subagents/agent-a2.jsonl" $((NOW - 3600))
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

# ---- stall watchdog ---------------------------------------------------------------------------

mk_confirmed() { # confirmed 15 minutes ago, 10 transcript lines at the time
    mk_tr "$SID" open
    mk_regx "$SID" "$ALIVEPID" "$ALIVESTART"
    set_mtime "$PD/$SID.jsonl" $((NOW - 900))
    jq -n -c --arg sid "$SID" --argjson at $((NOW - 900)) '
        {rid:"r_aaaaaa", sid:$sid, scope:"main", class:"transient", action:"backoff", error:"server_error",
         detected_by:["scan"], evidence:{uuid:"e-1", uuids:["e-1"], transcript_line:2}, first_seen:($at - 100),
         resume_at:($at - 50), attempt:0, state:"confirmed", state_log:[["confirmed", $at]], inject_tries:1,
         notified:false, confirmed_at:$at, confirmed_lines:2}' >"$RD/pending/r_aaaaaa.json"
}

@test "stall watchdog: confirmed, no growth for 10 minutes, a permission_prompt arrived -> stalled + notice" {
    mk_confirmed
    ev "$SID" "{\"t\":$((NOW - 800)),\"ev\":\"permission_prompt\",\"scope\":\"main\"}"
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(rec_q '.[0].state')" = stalled ]
    run jq -r 'select(.kind == "stalled") | .msg' "$RD/notify.jsonl"
    [[ "$output" == *"win"* ]]
}

@test "stall watchdog: the pane classifies as a dialog -> stalled" {
    mk_confirmed
    export BORG_RESUME_PANES_CMD="printf '%%7|$SID|555|claude\n'"
    export BORG_RESUME_TMUX_CMD="$BATS_TEST_TMPDIR/fake-tmux"
    printf '%s\n' '#!/bin/sh' \
        'printf "Do you want to proceed?\n 1. Yes\n 2. No\n Esc to cancel\n"' >"$BATS_TEST_TMPDIR/fake-tmux"
    chmod +x "$BATS_TEST_TMPDIR/fake-tmux"
    watch
    [ "$(rec_q '.[0].state')" = stalled ]
}

@test "stall watchdog: no permission prompt and a quiet idle pane is NOT stalled" {
    mk_confirmed
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].state')" = confirmed ]
}

@test "stall watchdog: transcript still moving or younger than 10 minutes is not stalled" {
    mk_confirmed
    ev "$SID" "{\"t\":$((NOW - 800)),\"ev\":\"permission_prompt\",\"scope\":\"main\"}"
    t_tool "$PD/$SID.jsonl"
    set_mtime "$PD/$SID.jsonl" $((NOW - 30))
    watch
    [ "$(rec_q '.[0].state')" = confirmed ]
}

@test "kill switch BORG_RESUME_DISABLE=1 records nothing" {
    mk_tr "$SID" open
    mk_dead "$SID"
    BORG_RESUME_DISABLE=1 run "$BIN" watch --once
    [ "$(n_recs)" = 0 ]
}

# ---- review fixes -----------------------------------------------------------------------------

mk_agent() { # <sid> <agent-id> <mtime>
    mkdir -p "$PD/$1/subagents"
    : >"$PD/$1/subagents/agent-$2.jsonl"
    t_user "$PD/$1/subagents/agent-$2.jsonl"
    t_tool "$PD/$1/subagents/agent-$2.jsonl"
    set_mtime "$PD/$1/subagents/agent-$2.jsonl" "$3"
}

@test "Esc with an agent in flight then pane kill: no agent or workflow record (deliberate stop)" {
    mk_tr "$SID" int
    mk_agent "$SID" a1 $((NOW - 3600))
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "Esc with a workflow in flight then pane kill: no record" {
    mk_wf
    t_int "$PD/$SID.jsonl"
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "a stale orphaned agent from hours before main moved on is not open work" {
    mk_tr "$SID" idle
    mk_agent "$SID" a1 $((NOW - 36000))
    mk_dead "$SID"
    watch
    [ "$(n_recs)" = 0 ]
}

@test "limit-failed workflow plus a dead owner: liveness never reclassifies the limit record" {
    mk_wf
    t_err "$PD/$SID.jsonl" e-9 rate_limit "You have hit your session limit - resets 7:10pm (UTC)"
    mk_dead "$SID"
    watch
    [ "$(rec_q 'map(select(.scope == "workflow:wf_x1")) | length')" = 1 ]
    [ "$(rec_q 'map(select(.scope == "workflow:wf_x1"))[0].class')" = usage_limit ]
    [ "$(rec_q 'map(select(.scope == "workflow:wf_x1"))[0].error')" = rate_limit ]
    [ "$(rec_q 'map(select(.scope == "workflow:wf_x1"))[0].reset_text != null')" = true ]
}

@test "notices are coalesced to one per session and delivered host-side" {
    mk_tr "$SID" idle
    mk_agent "$SID" a1 $((NOW - 3600))
    mk_agent "$SID" a2 $((NOW - 3600))
    mk_dead "$SID" myproj
    watch
    [ "$(n_recs)" = 2 ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
    [ "$(wc -l <"$BATS_TEST_TMPDIR/delivered" | tr -d ' ')" = 1 ]
    run cat "$BATS_TEST_TMPDIR/delivered"
    [[ "$output" == *"mark-closed myproj"* ]]
}

@test "the notify outbox stays bounded" {
    mk_tr "$SID" open
    mk_dead "$SID"
    export BORG_RESUME_NOTIFY_KEEP=3
    for i in 1 2 3 4 5 6 7 8; do printf '{"t":1,"kind":"x"}\n' >>"$RD/notify.jsonl"; done
    watch
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" -le 4 ]
}
