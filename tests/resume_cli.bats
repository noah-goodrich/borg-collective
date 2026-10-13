#!/usr/bin/env bats
# CLI verbs for borg-resume (slice S14): status, cancel, run, pause/unpause (lib/borg/resume-cli.sh, bin/borg-resume).
# Everything is synthetic and lives in $BATS_TEST_TMPDIR. Stubs: BORG_RESUME_INJECT_CMD (replaces borg_inject_line),
# BORG_RESUME_USAGE_CMD (the /usage probe), BORG_RESUME_NOTIFY_CMD (the notifier), BORG_RESUME_TMUX_CMD /
# BORG_RESUME_PANES_CMD / BORG_RESUME_SENDKEYS_CMD for the one test that drives the real inject lib. No real tmux,
# claude, docker, launchd, osascript or state dir is touched. Clock pinned with BORG_RESUME_NOW_EPOCH.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_IN_CONTAINER=0
    T0=1791806400
    export BORG_RESUME_NOW_EPOCH=$T0
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_RUNNING_SEC BORG_RESUME_RETAIN_DAYS
    unset BORG_RESUME_CONFIRM_DONE_SEC BORG_RESUME_CONFIRM_PROGRESS_LINES BORG_RESUME_WEEKLY BORG_RESUME_AUTO_COMPACT
    unset BORG_USAGE_HALT_ENABLED BORG_RESUME_MAX_ACTIVE BORG_RESUME_MAX_CONSECUTIVE BORG_RESUME_MAX_AGE_HOURS
    unset BORG_RESUME_PANES_CMD BORG_RESUME_TMUX_CMD BORG_RESUME_SENDKEYS_CMD BORG_RESUME_MAX_PER_PASS
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    SID2="00000000-0000-4000-8000-0000000000bb"
    SID3="00000000-0000-4000-8000-0000000000cc"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done" "$CWD" "${BATS_TEST_TMPDIR}/bin"
    ILOG="${BATS_TEST_TMPDIR}/inject.log"
    NLOG="${BATS_TEST_TMPDIR}/notify.log"
    : >"$ILOG"
    : >"$NLOG"
    printf 'injected pane=%%1\n' >"${BATS_TEST_TMPDIR}/inject.out"
    printf '0' >"${BATS_TEST_TMPDIR}/inject.rc"
    printf '40' >"${BATS_TEST_TMPDIR}/usage.pct"
    cat >"${BATS_TEST_TMPDIR}/bin/inject" <<STUB
#!/bin/bash
printf '%s\t%s\n' "\$1" "\$2" >>"$ILOG"
if [ -f "${BATS_TEST_TMPDIR}/inject.append" ]; then
    jq -n -c --arg t "\$2" '{type:"user",uuid:"race1",message:{role:"user",content:\$t}}' \\
        >>"\$(cat "${BATS_TEST_TMPDIR}/inject.append")"
fi
cat "${BATS_TEST_TMPDIR}/inject.out"
exit "\$(cat "${BATS_TEST_TMPDIR}/inject.rc")"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/usage" <<STUB
#!/bin/bash
[ -e "${BATS_TEST_TMPDIR}/usage.fail" ] && exit 1
printf 'Current session: %s%% used\n' "\$(cat "${BATS_TEST_TMPDIR}/usage.pct")"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/notify" <<STUB
#!/bin/bash
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$NLOG"
STUB
    chmod +x "${BATS_TEST_TMPDIR}/bin/inject" "${BATS_TEST_TMPDIR}/bin/usage" "${BATS_TEST_TMPDIR}/bin/notify"
    export BORG_RESUME_INJECT_CMD="${BATS_TEST_TMPDIR}/bin/inject"
    export BORG_RESUME_USAGE_CMD="${BATS_TEST_TMPDIR}/bin/usage"
    export BORG_RESUME_NOTIFY_CMD="${BATS_TEST_TMPDIR}/bin/notify"
}

at() { export BORG_RESUME_NOW_EPOCH=$((T0 + $1)); }
watch() { run "$BIN" watch --once; [ "$status" -eq 0 ]; }
set_inject() { printf '%s\n' "$1" >"${BATS_TEST_TMPDIR}/inject.out"; printf '%s' "$2" >"${BATS_TEST_TMPDIR}/inject.rc"; }
set_pct() { printf '%s' "$1" >"${BATS_TEST_TMPDIR}/usage.pct"; rm -f "$RD/usage-probe.json"; }
n_inject() { wc -l <"$ILOG" | tr -d ' '; }
n_notify() { wc -l <"$NLOG" | tr -d ' '; }

# ---- builders (SYNTHETIC) ---------------------------------------------------------------------
mk_reg() { # <sid> [extra jq]
    jq -n -c --arg sid "$1" --arg cwd "$CWD" '{session_id:$sid, cwd:$cwd, in_container:false, mode:"project"}' |
        jq -c "${2:-.}" >"$RD/sessions/$1.json"
}
t_user() { printf '{"type":"user","uuid":"u-%s","cwd":"%s","message":{"role":"user","content":"hello"}}\n' "$RANDOM" "$CWD" >>"$1"; }
t_asst_end() { printf '{"type":"assistant","uuid":"a-%s","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}]}}\n' "$RANDOM" >>"$1"; }
t_err() { # <file> <uuid> [error] [text]
    printf '{"type":"assistant","uuid":"%s","isApiErrorMessage":true,"error":"%s","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"%s"}]}}\n' \
        "$2" "${3:-server_error}" "${4:-API Error: 500}" >>"$1"
}
mk_main() { # <sid> : user line 1, synthetic error line 2, registry
    local f="$PD/$1.jsonl"
    : >"$f"
    t_user "$f"
    t_err "$f" "e-$1"
    mk_reg "$1"
}
mk_rec() { # <rid> <sid> <scope> <class> <state> <resume_at> [first_seen] [extra jq]
    local fs="${7:-$T0}"
    jq -n -c --arg rid "$1" --arg sid "$2" --arg scope "$3" --arg class "$4" --arg state "$5" --argjson ra "$6" \
        --argjson fs "$fs" '{rid:$rid, sid:$sid, scope:$scope, class:$class, action:"resume", error:"server_error",
        reset_text:null, detected_by:["scan"], evidence:{transcript_line:2, uuid:("e-" + $sid), uuids:[("e-" + $sid)]},
        first_seen:$fs, resume_at:$ra, attempt:0, state:$state, state_log:[[$state, $fs]], inject_tries:0,
        notified:false}' | jq -c "${8:-.}" >"$RD/pending/$1.json"
}
rf() { # <rid> <jq expr>
    local f="$RD/pending/$1.json"
    [ -f "$f" ] || f="$RD/done/$1.json"
    jq -r "$2" "$f"
}
mk_state() { # <sid> <jq expr> : edit state/<sid>.json (creates a default one)
    mkdir -p "$RD/state"
    local f="$RD/state/$1.json"
    [ -f "$f" ] || printf '{"consecutive":0,"resumed_total":0,"injections_today":0,"day":"2026-10-12","last_progress_lines":0,"hook_cursor":0}\n' >"$f"
    jq -c "$2" "$f" >"$f.t" && mv "$f.t" "$f"
}
ev() { # <sid> <json>
    printf '%s\n' "$2" >>"$RD/events/$1.jsonl"
}

# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (slice S14). Single-writer rule:
# the CLI only APPENDS events (cancel, run); the watcher folds them and owns every transition.

# ---- status -------------------------------------------------------------------------------------

@test "status on an empty ledger succeeds and says so" {
    run "$BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"no records"* ]] || false
}

@test "status lists records grouped by state with rid, project, class, cause, due, last reason" {
    mk_main "$SID"
    mk_reg "$SID" '.project = "alpha"'
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    run "$BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"scheduled (1)"* ]] || false
    [[ "$output" == *"$rid"* ]] || false
    [[ "$output" == *alpha* ]] || false
    [[ "$output" == *transient* ]] || false
    [[ "$output" == *server_error* ]] || false
    [[ "$output" == *"in 45s"* ]] || false
}

@test "status output fits a 60 column pane" {
    mk_main "$SID"
    mk_reg "$SID" '.project = "alpha-with-a-rather-long-project-name"'
    at 0
    watch
    run "$BIN" status
    local l
    for l in "${lines[@]}"; do
        [ "${#l}" -le 60 ] || { echo "too wide: $l" >&2; false; }
    done
}

@test "status shows the pause state, the sentinel and the env kill switch" {
    run "$BIN" status
    [[ "$output" == *"running"* ]] || false
    touch "$RD/DISABLED"
    run "$BIN" status
    [[ "$output" == *"PAUSED"* ]] || false
    BORG_RESUME_DISABLE=1 run "$BIN" status
    [[ "$output" == *"DISABLED"* ]] || false
}

@test "status --json is a machine document with records, counts and the pause state" {
    mk_main "$SID"
    mk_reg "$SID" '.project = "alpha"'
    at 0
    watch
    touch "$RD/DISABLED"
    run "$BIN" status --json
    [ "$status" -eq 0 ]
    echo "$output" | jq -e --arg rid "$(basename "$RD"/pending/*.json .json)" '
        .paused == true and .now == 1791806400 and .counts.scheduled == 1
        and (.records | length) == 1
        and .records[0].rid == $rid and .records[0].project == "alpha" and .records[0].class == "transient"
        and .records[0].state == "scheduled" and .records[0].cause == "server_error"
        and .records[0].resume_at == 1791806445 and .records[0].due_in == 45' >/dev/null
}

@test "status hides old terminal records unless --all" {
    mk_rec r_old001 "$SID" main transient expired 1791000000 1791000000
    mv "$RD/pending/r_old001.json" "$RD/done/r_old001.json"
    touch -t 202601010000 "$RD/done/r_old001.json"
    run "$BIN" status --json
    [ "$(echo "$output" | jq '.records | length')" = 0 ]
    run "$BIN" status --json --all
    [ "$(echo "$output" | jq '.records | length')" = 1 ]
}

# ---- cancel -------------------------------------------------------------------------------------

@test "cancel appends a cancel event and does not touch the record (single writer)" {
    mk_rec r_aaaaaa "$SID" main transient scheduled $((T0 + 600))
    run "$BIN" cancel r_aaaaaa
    [ "$status" -eq 0 ]
    [ "$(rf r_aaaaaa .state)" = scheduled ]
    jq -e --arg s "$SID" '.ev == "cancel" and .rid == "r_aaaaaa" and .sid == $s and .t == 1791806400' \
        "$RD/events/$SID.jsonl" >/dev/null
}

@test "the watcher folds a cancel into a terminal cancelled record in done/" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    run "$BIN" cancel "$rid"
    [ "$status" -eq 0 ]
    watch
    [ ! -f "$RD/pending/$rid.json" ]
    [ "$(rf "$rid" .state)" = cancelled ]
    [ "$(rf "$rid" .done_reason)" = user_cancel ]
    at 60
    watch
    [ "$(n_inject)" = 0 ]
}

@test "a cancelled record blocks re-creation for the same evidence uuid" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    "$BIN" cancel "$rid"
    watch
    at 120
    watch
    run bash -c "ls '$RD'/pending/*.json 2>/dev/null | wc -l"
    [ "$(echo "$output" | tr -d ' ')" = 0 ]
    [ "$(rf "$rid" .state)" = cancelled ]
}

@test "cancel is idempotent: a second cancel, and one on a terminal record, change nothing" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    "$BIN" cancel "$rid"
    watch
    run "$BIN" cancel "$rid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already cancelled"* ]] || false
    watch
    [ "$(rf "$rid" .state)" = cancelled ]
    [ "$(jq -r '[.state_log[] | select(.[0] == "cancelled")] | length' "$RD/done/$rid.json")" = 1 ]
}

@test "cancel of an unknown or malformed rid fails with a clear message" {
    run "$BIN" cancel r_nope00
    [ "$status" -eq 1 ]
    [[ "$output" == *"no such record"* ]] || false
    [[ "$output" == *"borg resume status"* ]] || false
    [ ! -d "$RD/events" ] || [ -z "$(ls "$RD/events")" ]
    run "$BIN" cancel 'bad/rid'
    [ "$status" -eq 2 ]
    run "$BIN" cancel
    [ "$status" -eq 2 ]
}

@test "cancel --session cancels every active record of that session, --all every active record" {
    mk_rec r_aaaaaa "$SID" main transient scheduled $((T0 + 600))
    mk_rec r_bbbbbb "$SID" "agent:x1" transient deferred $((T0 + 600))
    mk_rec r_cccccc "$SID2" main transient scheduled $((T0 + 600))
    run "$BIN" cancel --session "$SID"
    [ "$status" -eq 0 ]
    watch
    [ "$(rf r_aaaaaa .state)" = cancelled ]
    [ "$(rf r_bbbbbb .state)" = cancelled ]
    [ "$(rf r_cccccc .state)" = scheduled ]
    run "$BIN" cancel --all
    [ "$status" -eq 0 ]
    watch
    [ "$(rf r_cccccc .state)" = cancelled ]
}

@test "a cancel for an injected record stops tracking it" {
    mk_rec r_aaaaaa "$SID" main transient injected $((T0 - 60))
    "$BIN" cancel r_aaaaaa
    watch
    [ "$(rf r_aaaaaa .state)" = cancelled ]
}

# ---- run ----------------------------------------------------------------------------------------

@test "run makes a scheduled record due now and still goes through the gate and the injector" {
    mk_main "$SID"
    at 0
    watch
    [ "$(n_inject)" = 0 ]
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    run "$BIN" run "$rid"
    [ "$status" -eq 0 ]
    [[ "$output" == *injected* ]] || false
    [ "$(n_inject)" = 1 ]
    [ "$(rf "$rid" .state)" = injected ]
}

@test "run does not bypass the kill switch: paused means nothing is injected and the output says why" {
    mk_main "$SID"
    at 0
    watch
    touch "$RD/DISABLED"
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    run "$BIN" run "$rid"
    [ "$status" -eq 0 ]
    [[ "$output" == *paused* ]] || false
    [ "$(n_inject)" = 0 ]
}

@test "run does not bypass BORG_RESUME_DISABLE" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    BORG_RESUME_DISABLE=1 run "$BIN" run "$rid"
    [[ "$output" == *BORG_RESUME_DISABLE* ]] || false
    [ "$(n_inject)" = 0 ]
}

@test "run does not bypass the idle proof: the injector refuses, the record defers, the decision is printed" {
    mk_main "$SID"
    at 0
    watch
    set_inject "defer pane_not_idle" 10
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    run "$BIN" run "$rid"
    [ "$status" -eq 0 ]
    [ "$(n_inject)" = 1 ]
    [[ "$output" == *deferred* ]] || false
    [[ "$output" == *pane_not_idle* ]] || false
    [ "$(rf "$rid" .state)" = deferred ]
}

@test "run revives an expired record from done/ and sends it through the gate" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    jq -c '.state = "expired" | .done_reason = "age"' "$RD/pending/$rid.json" >"$RD/done/$rid.json"
    rm "$RD/pending/$rid.json"
    run "$BIN" run "$rid"
    [ "$status" -eq 0 ]
    [ "$(n_inject)" = 1 ]
    [ "$(rf "$rid" .state)" = injected ]
    [ -f "$RD/pending/$rid.json" ]
}

@test "run refuses a record that already finished or was superseded" {
    mk_rec r_dddddd "$SID" main transient done $((T0 - 60))
    mv "$RD/pending/r_dddddd.json" "$RD/done/r_dddddd.json"
    run "$BIN" run r_dddddd
    [ "$status" -eq 1 ]
    [[ "$output" == *"nothing to resume"* ]] || false
    [ "$(n_inject)" = 0 ]
}

@test "run of an unknown rid fails with a clear message and injects nothing" {
    run "$BIN" run r_nope00
    [ "$status" -eq 1 ]
    [[ "$output" == *"no such record"* ]] || false
    [ "$(n_inject)" = 0 ]
}

@test "a capped record stays capped on plain run and resumes on run --force" {
    mk_main "$SID"
    at 0
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    mk_state "$SID" '.consecutive = 3'
    run "$BIN" run "$rid"
    [[ "$output" == *capped* ]] || false
    [ "$(n_inject)" = 0 ]
    run "$BIN" run "$rid" --force
    [ "$status" -eq 0 ]
    [ "$(n_inject)" = 1 ]
    [ "$(rf "$rid" .state)" = injected ]
}

@test "run rejects unknown flags with usage" {
    run "$BIN" run r_aaaaaa --bogus
    [ "$status" -eq 2 ]
}

# ---- pause / unpause ----------------------------------------------------------------------------

@test "pause keeps recording but the watcher injects nothing; unpause resumes" {
    run "$BIN" pause
    [ "$status" -eq 0 ]
    [ -e "$RD/DISABLED" ]
    mk_main "$SID"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    run "$BIN" unpause
    [ ! -e "$RD/DISABLED" ]
    watch
    [ "$(n_inject)" = 1 ]
}

# ---- the names printed by S9/S10 notifications exist -------------------------------------------------

@test "every borg resume verb named in a gate or liveness notification is a real verb" {
    local verbs v
    verbs="$(grep -ho 'borg resume [a-z-]*' "${BATS_TEST_DIRNAME}/../lib/borg/resume-gate.sh" \
        "${BATS_TEST_DIRNAME}/../lib/borg/resume-liveness.sh" | awk '{print $3}' | sort -u)"
    [ -n "$verbs" ]
    for v in $verbs; do
        case "$v" in
            status | cancel | run | pause | unpause) ;;
            *) echo "notification names unknown verb: $v" >&2; false ;;
        esac
    done
}
