#!/usr/bin/env bats
# Watcher fold + scan for borg-resume (slice S7): borg-resume watch --once.
# Everything is synthetic and lives in $BATS_TEST_TMPDIR: no real claude, tmux, docker, launchd or state dir.
# Clock pinned with BORG_RESUME_NOW_EPOCH; transcript mtimes set with touch -t.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    FXR="${BATS_TEST_DIRNAME}/fixtures/resume"
    FXC="${BATS_TEST_DIRNAME}/fixtures/resume-classify"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_IN_CONTAINER=0
    # 2026-10-12 12:00:00 UTC
    export BORG_RESUME_NOW_EPOCH=1791806400
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_RUNNING_SEC BORG_RESUME_RETAIN_DAYS
    unset BORG_RESUME_CONFIRM_DONE_SEC BORG_RESUME_CONFIRM_PROGRESS_LINES
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    SID2="00000000-0000-4000-8000-0000000000bb"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$CWD"
}

watch() { run "$BIN" watch --once; }

# ---- builders (SYNTHETIC) ---------------------------------------------------------------------
mk_reg() { # <sid>
    printf '{"session_id":"%s","cwd":"%s","in_container":false}\n' "$1" "$CWD" >"$RD/sessions/$1.json"
}
t_user() { printf '{"type":"user","uuid":"u-%s","cwd":"%s","message":{"role":"user","content":"hello"}}\n' "$RANDOM" "$CWD" >>"$1"; }
t_asst_end() { printf '{"type":"assistant","uuid":"a-%s","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}]}}\n' "$RANDOM" >>"$1"; }
t_err() { # <file> <uuid> [error] [text]
    printf '{"type":"assistant","uuid":"%s","isApiErrorMessage":true,"error":"%s","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"%s"}]}}\n' \
        "$2" "${3:-server_error}" "${4:-API Error: 500}" >>"$1"
}
t_int() { printf '{"type":"user","uuid":"i-%s","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}\n' "$RANDOM" >>"$1"; }
t_close() { printf '{"type":"system","subtype":"turn_duration"}\n' >>"$1"; }
mk_main() { # <sid> <kind> [uuid] ; kinds: err | err_closed | int | done | auth
    local f="$PD/$1.jsonl"
    : >"$f"
    t_user "$f"
    case "$2" in
        err) t_err "$f" "${3:-e-1}" ;;
        err_closed) t_err "$f" "${3:-e-1}"; t_close "$f" ;;
        auth) t_err "$f" "${3:-e-1}" authentication_failed "Login expired" ;;
        int) t_int "$f" ;;
        done) t_asst_end "$f"; t_close "$f" ;;
    esac
    mk_reg "$1"
}
hook_stop_failure() { # <sid> [error] [msg] [agent_id]
    jq -c -n --arg sid "$1" --arg e "${2:-server_error}" --arg m "${3:-API Error: 500}" --arg a "${4:-}" --argjson t "$BORG_RESUME_NOW_EPOCH" \
        '{t:$t, ev:"stop_failure", sid:$sid, scope:(if $a == "" then "main" else "agent:" + $a end),
          agent_id:(if $a == "" then null else $a end), error:$e, msg:$m, tool_use_id:null}' >>"$RD/events/$1.jsonl"
    mk_reg "$1"
}
n_pending() { ls "$RD"/pending/*.json 2>/dev/null | wc -l | tr -d ' '; }
n_done() { ls "$RD"/done/*.json 2>/dev/null | wc -l | tr -d ' '; }
all_recs() { cat "$RD"/pending/*.json "$RD"/done/*.json 2>/dev/null; }
rec_q() { all_recs | jq -r -s "$1"; }

# ---- detection and convergence ---------------------------------------------------------------

@test "scan alone: a synthetic error at the transcript tail makes one scheduled transient record" {
    mk_main "$SID" err
    watch
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = main ]
    [ "$(rec_q '.[0].class')" = transient ]
    [ "$(rec_q '.[0].state')" = scheduled ]
    [ "$(rec_q '.[0].evidence.uuid')" = e-1 ]
    [ "$(rec_q '.[0].detected_by | join(",")')" = scan ]
    [ "$(rec_q '.[0].resume_at')" = "$((BORG_RESUME_NOW_EPOCH + 45))" ]
}

@test "hook event plus scan for the same error yields ONE record detected by both" {
    mk_main "$SID" err
    hook_stop_failure "$SID"
    watch
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].detected_by | sort | join(",")')" = "hook,scan" ]
    [ "$(rec_q '.[0].evidence.uuid')" = e-1 ]
}

@test "hook event alone (no transcript yet) creates a record, a later scan merges into it" {
    hook_stop_failure "$SID"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].evidence.uuid')" = null ]
    mk_main "$SID" err
    BORG_RESUME_NOW_EPOCH=$((BORG_RESUME_NOW_EPOCH + 5)) run "$BIN" watch --once
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].evidence.uuid')" = e-1 ]
    [ "$(rec_q '.[0].detected_by | sort | join(",")')" = "hook,scan" ]
}

@test "two sessions yield two records" {
    mk_main "$SID" err e-1
    mk_main "$SID2" err e-2
    watch
    [ "$(n_pending)" = 2 ]
    [ "$(rec_q 'map(.sid) | unique | length')" = 2 ]
}

@test "a rate_limit error with reset text is scheduled at the parsed reset plus grace" {
    f="$PD/$SID.jsonl"
    : >"$f"
    t_user "$f"
    t_err "$f" e-9 rate_limit "You have hit your session limit - resets 7:10pm (UTC)"
    mk_reg "$SID"
    watch
    [ "$(rec_q '.[0].class')" = usage_limit ]
    [ "$(rec_q '.[0].action')" = resume ]
    [ "$(rec_q '.[0].resume_at')" = "$((1791832200 + 120))" ]
}

@test "synthetic error followed by a clean-close record is STILL an interruption" {
    mk_main "$SID" err_closed
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].evidence.uuid')" = e-1 ]
}

@test "a cleanly finished session yields nothing" {
    mk_main "$SID" done
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 0 ]
}

@test "auth failure yields a notify_only record, moved to done/" {
    mk_main "$SID" auth
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 1 ]
    [ "$(rec_q '.[0].state')" = notify_only ]
    [ "$(rec_q '.[0].class')" = notify_only ]
}

# ---- deliberate ends -------------------------------------------------------------------------

@test "captured user-interrupt fixtures yield no record" {
    cp "$FXC/interrupt_user.jsonl" "$PD/$SID.jsonl"
    cp "$FXC/interrupt_tool_use.jsonl" "$PD/$SID2.jsonl"
    mk_reg "$SID"
    mk_reg "$SID2"
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 0 ]
}

@test "Esc then pane kill (interrupt marker, no SessionEnd) yields no record" {
    mk_main "$SID" int
    printf '{"t":1791800000,"ev":"session_start","sid":"%s","scope":"main"}\n' "$SID" >"$RD/events/$SID.jsonl"
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 0 ]
}

@test "a stop_failure hook whose transcript ends in the interrupt marker yields no record" {
    mk_main "$SID" int
    hook_stop_failure "$SID"
    watch
    [ "$(n_pending)" = 0 ]
}

@test "a skipped agent and a Ctrl+X Ctrl+K agent (trailing interrupt marker) yield no record" {
    mk_main "$SID" done
    sub="$PD/$SID/subagents"
    mkdir -p "$sub"
    for a in askip akill; do
        : >"$sub/agent-$a.jsonl"
        t_user "$sub/agent-$a.jsonl"
        t_int "$sub/agent-$a.jsonl"
        TZ=UTC touch -t 202610121000 "$sub/agent-$a.jsonl"
    done
    watch
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 0 ]
}

@test "an interrupt after a scheduled record closes it as cancelled (interrupted_by_user), never resumed" {
    mk_main "$SID" err
    watch
    [ "$(n_pending)" = 1 ]
    t_int "$PD/$SID.jsonl"
    BORG_RESUME_NOW_EPOCH=$((BORG_RESUME_NOW_EPOCH + 10)) run "$BIN" watch --once
    [ "$(n_pending)" = 0 ]
    [ "$(n_done)" = 1 ]
    [ "$(rec_q '.[0].state')" = cancelled ]
    [ "$(rec_q '.[0].reason')" = interrupted_by_user ]
}

# ---- agents and workflows --------------------------------------------------------------------

@test "an errored Agent-tool agent yields an agent-scope record" {
    mk_main "$SID" done
    sub="$PD/$SID/subagents"
    mkdir -p "$sub"
    : >"$sub/agent-a1.jsonl"
    t_user "$sub/agent-a1.jsonl"
    t_err "$sub/agent-a1.jsonl" ea-1 rate_limit "limit hit"
    TZ=UTC touch -t 202610121000 "$sub/agent-a1.jsonl"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = "agent:a1" ]
    [ "$(rec_q '.[0].evidence.uuid')" = ea-1 ]
}

@test "a finished_with_failures workflow yields a workflow-scope record" {
    mk_main "$SID" done
    mkdir -p "$PD/$SID/workflows" "$PD/$SID/subagents/workflows/wf_failed"
    cp "$FXR/workflows/wf_failed.json" "$PD/$SID/workflows/wf_failed.json"
    cp "$FXR/workflows/wf_failed.journal.jsonl" "$PD/$SID/subagents/workflows/wf_failed/journal.jsonl"
    watch
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].scope')" = "workflow:wf_fake001" ]
    [ "$(rec_q '.[0].state')" = scheduled ]
}

@test "a clean finished workflow yields nothing" {
    mk_main "$SID" done
    mkdir -p "$PD/$SID/workflows" "$PD/$SID/subagents/workflows/wf_ab12cd"
    cp "$FXR/workflows/wf_ab12cd.json" "$PD/$SID/workflows/wf_ab12cd.json"
    cp "$FXR/workflows/wf_ab12cd.journal.jsonl" "$PD/$SID/subagents/workflows/wf_ab12cd/journal.jsonl"
    watch
    [ "$(n_pending)" = 0 ]
}

mk_confirmed_aaaaaa() {
    local n
    n="$(wc -l <"$PD/$SID.jsonl" | tr -d ' ')"
    jq -n --arg sid "$SID" --argjson at "$((BORG_RESUME_NOW_EPOCH - 60))" --argjson n "$n" '{rid:"r_aaaaaa", sid:$sid, scope:"main",
        class:"transient", action:"backoff", error:"server_error", detected_by:["scan"], evidence:{uuid:"e-1", uuids:["e-1"]},
        first_seen:1791790000, resume_at:1791790045, attempt:0, state:"confirmed", confirmed_at:$at, confirmed_lines:$n,
        state_log:[["confirmed",$at]], inject_tries:1, notified:false}' >"$RD/pending/r_aaaaaa.json"
}

# ---- dedupe and idempotency ------------------------------------------------------------------

@test "a second watch --once run changes nothing" {
    mk_main "$SID" err
    hook_stop_failure "$SID"
    watch
    first="$(all_recs | jq -c -s .)"
    watch
    [ "$status" -eq 0 ]
    [ "$(all_recs | jq -c -s .)" = "$first" ]
    [ "$(n_pending)" = 1 ]
}

@test "the same uuid never creates a second record, even when the first is terminal" {
    mk_main "$SID" auth
    watch
    [ "$(n_done)" = 1 ]
    watch
    [ "$(n_done)" = 1 ]
    [ "$(n_pending)" = 0 ]
}

@test "a new uuid merges into a scheduled record: resume_at is the max, uuids are unioned" {
    mk_main "$SID" err e-1
    watch
    t_err "$PD/$SID.jsonl" e-2
    BORG_RESUME_NOW_EPOCH=$((BORG_RESUME_NOW_EPOCH + 100)) run "$BIN" watch --once
    [ "$(n_pending)" = 1 ]
    [ "$(rec_q '.[0].evidence.uuids | sort | join(",")')" = "e-1,e-2" ]
    [ "$(rec_q '.[0].resume_at')" -gt "$((BORG_RESUME_NOW_EPOCH + 45))" ]
}

@test "a stale confirmed record does not swallow a new interruption with a new uuid" {
    mk_main "$SID" err e-2
    mk_confirmed_aaaaaa
    watch
    [ "$(n_pending)" = 2 ]
    [ "$(jq -r .state "$RD/pending/r_aaaaaa.json")" = confirmed ]
    [ "$(rec_q 'map(select(.rid != "r_aaaaaa")) | .[0].evidence.uuid')" = e-2 ]
    [ "$(rec_q 'map(select(.rid != "r_aaaaaa")) | .[0].attempt')" = 1 ]
}

@test "an error whose uuid is already attached to a confirmed record creates nothing" {
    mk_main "$SID" err e-1
    mk_confirmed_aaaaaa
    watch
    [ "$(n_pending)" = 1 ]
}

# ---- confirmed -> done -----------------------------------------------------------------------

mk_confirmed() { # <confirmed_at> <confirmed_lines>
    jq -n --arg sid "$SID" --argjson at "$1" --argjson ln "$2" '{rid:"r_cccccc", sid:$sid, scope:"main", class:"transient",
        action:"backoff", error:"server_error", detected_by:["scan"], evidence:{uuid:"e-1", uuids:["e-1"]},
        first_seen:1791790000, resume_at:1791790045, attempt:0, state:"confirmed", confirmed_at:$at, confirmed_lines:$ln,
        state_log:[["confirmed",$at]], inject_tries:1, notified:false}' >"$RD/pending/r_cccccc.json"
}

@test "confirmed becomes done on 25+ transcript lines of progress and resets consecutive" {
    mk_main "$SID" err
    printf '{"consecutive":2,"resumed_total":2,"injections_today":1,"day":"2026-10-12","last_progress_lines":0}\n' >"$RD/state/$SID.json" 2>/dev/null ||
        { mkdir -p "$RD/state" && printf '{"consecutive":2}\n' >"$RD/state/$SID.json"; }
    n="$(wc -l <"$PD/$SID.jsonl" | tr -d ' ')"
    mk_confirmed $((BORG_RESUME_NOW_EPOCH - 60)) "$n"
    for _ in $(seq 1 26); do t_asst_end "$PD/$SID.jsonl"; done
    watch
    [ "$(jq -r .state "$RD/done/r_cccccc.json")" = done ]
    [ ! -e "$RD/pending/r_cccccc.json" ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 0 ]
}

@test "confirmed with little progress stays confirmed before 30 minutes" {
    mk_main "$SID" done
    n="$(wc -l <"$PD/$SID.jsonl" | tr -d ' ')"
    mk_confirmed $((BORG_RESUME_NOW_EPOCH - 600)) "$n"
    watch
    [ "$(jq -r .state "$RD/pending/r_cccccc.json")" = confirmed ]
}

@test "confirmed becomes done after 30 minutes without progress and increments consecutive" {
    mk_main "$SID" done
    mkdir -p "$RD/state"
    printf '{"consecutive":1,"resumed_total":1,"injections_today":1,"day":"2026-10-12","last_progress_lines":0}\n' >"$RD/state/$SID.json"
    n="$(wc -l <"$PD/$SID.jsonl" | tr -d ' ')"
    mk_confirmed $((BORG_RESUME_NOW_EPOCH - 1900)) "$n"
    watch
    [ "$(jq -r .state "$RD/done/r_cccccc.json")" = done ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 2 ]
}

# ---- lock ------------------------------------------------------------------------------------

@test "an overlapping run exits on the lock without touching anything" {
    mk_main "$SID" err
    sleep 30 &
    lp=$!
    mkdir -p "$RD/.watch.lock"
    printf '%s\n' "$lp" >"$RD/.watch.lock/pid"
    watch
    kill "$lp" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 0 ]
    [ -d "$RD/.watch.lock" ]
}

@test "a stale lock with a dead pid is taken over and released" {
    mk_main "$SID" err
    mkdir -p "$RD/.watch.lock"
    printf '999999\n' >"$RD/.watch.lock/pid"
    watch
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 1 ]
    [ ! -e "$RD/.watch.lock" ]
}

@test "the lock is released after a normal run" {
    watch
    [ ! -e "$RD/.watch.lock" ]
}

# ---- kill switches ---------------------------------------------------------------------------

@test "BORG_RESUME_DISABLE=1 makes watch a no-op" {
    mk_main "$SID" err
    BORG_RESUME_DISABLE=1 run "$BIN" watch --once
    [ "$status" -eq 0 ]
    [ "$(n_pending)" = 0 ]
}

@test "the DISABLED sentinel does not stop folding (recording continues)" {
    mk_main "$SID" err
    : >"$RD/DISABLED"
    watch
    [ "$(n_pending)" = 1 ]
}

@test "watch without --once is a usage error" {
    run "$BIN" watch
    [ "$status" -eq 2 ]
}

# ---- retention -------------------------------------------------------------------------------

old() { TZ=UTC touch -t "$2" "$1"; }

@test "retention removes old terminal records, idle events, registries and counters; keeps active ones" {
    mkdir -p "$RD/state" "$RD/prompts"
    printf '{"rid":"r_old001","sid":"%s","scope":"main","state":"done","evidence":{"uuids":["x"]}}\n' "$SID2" >"$RD/done/r_old001.json"
    printf '{"rid":"r_new001","sid":"%s","scope":"main","state":"done","evidence":{"uuids":["y"]}}\n' "$SID2" >"$RD/done/r_new001.json"
    old "$RD/done/r_old001.json" 202609010000
    : >"$RD/prompts/r_old001.md"
    old "$RD/prompts/r_old001.md" 202609010000
    echo '{"t":1,"ev":"agent_start","sid":"x"}' >"$RD/events/$SID2.jsonl"
    old "$RD/events/$SID2.jsonl" 202609010000
    mk_reg "$SID2"
    old "$RD/sessions/$SID2.json" 202609010000
    echo '{"consecutive":0}' >"$RD/state/$SID2.json"
    old "$RD/state/$SID2.json" 202609010000
    jq -n --arg sid "$SID" '{rid:"r_act001", sid:$sid, scope:"main", state:"scheduled", evidence:{uuids:["z"]}, first_seen:1791790000}' \
        >"$RD/pending/r_act001.json"
    echo '{"t":1,"ev":"agent_start","sid":"x"}' >"$RD/events/$SID.jsonl"
    old "$RD/events/$SID.jsonl" 202609010000
    mk_reg "$SID"
    old "$RD/sessions/$SID.json" 202609010000
    watch
    [ ! -e "$RD/done/r_old001.json" ]
    [ ! -e "$RD/prompts/r_old001.md" ]
    [ -e "$RD/done/r_new001.json" ]
    [ ! -e "$RD/events/$SID2.jsonl" ]
    [ ! -e "$RD/sessions/$SID2.json" ]
    [ ! -e "$RD/state/$SID2.json" ]
    [ -e "$RD/events/$SID.jsonl" ]
    [ -e "$RD/sessions/$SID.json" ]
    [ -e "$RD/pending/r_act001.json" ]
}

@test "retention never goes below the scan window even if configured lower" {
    printf '{"rid":"r_two001","sid":"%s","scope":"main","state":"done","evidence":{"uuids":["x"]}}\n' "$SID2" >"$RD/done/r_two001.json"
    old "$RD/done/r_two001.json" 202610100000
    BORG_RESUME_RETAIN_DAYS=0 run "$BIN" watch --once
    [ -e "$RD/done/r_two001.json" ]
}

@test "watch.log is rotated once it passes 1MiB" {
    head -c 1100000 /dev/zero | tr '\0' 'x' >"$RD/watch.log"
    watch
    [ -e "$RD/watch.log.1" ]
    [ ! -e "$RD/watch.log" ] || [ "$(wc -c <"$RD/watch.log" | tr -d ' ')" -lt 100000 ]
}
