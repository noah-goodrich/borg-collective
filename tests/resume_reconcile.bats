#!/usr/bin/env bats
# RECONCILE-6: S9 (gate) and S10 (liveness) were built in parallel. This file pins the three reconciliations:
# one "moving" rule and one stall owner, one deduplicated notification path, and the gate honouring S10's cause.
# Everything is synthetic and lives in $BATS_TEST_TMPDIR; no real tmux, claude, docker, launchd or notifier.

setup() {
    LIB="${BATS_TEST_DIRNAME}/../lib/borg"
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_RESUME_LIBDIR="$LIB"
    export BORG_IN_CONTAINER=0
    T0=1791806400
    export BORG_RESUME_NOW_EPOCH=$T0
    unset BORG_RESUME_DISABLE BORG_RESUME_PANES_CMD BORG_RESUME_TMUX_CMD BORG_RESUME_SENDKEYS_CMD
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done" "$CWD" "${BATS_TEST_TMPDIR}/bin"
    NLOG="${BATS_TEST_TMPDIR}/notify.log"
    ILOG="${BATS_TEST_TMPDIR}/inject.log"
    : >"$NLOG"
    : >"$ILOG"
    printf '#!/bin/bash\nprintf "%%s|%%s|%%s\\n" "$1" "$2" "$3" >>"%s"\n' "$NLOG" >"${BATS_TEST_TMPDIR}/bin/notify"
    printf '#!/bin/bash\nprintf "%%s\\t%%s\\n" "$1" "$2" >>"%s"\nprintf "injected pane=%%%%1\\n"\n' \
        "$ILOG" >"${BATS_TEST_TMPDIR}/bin/inject"
    printf '#!/bin/bash\nprintf "Current session: 40%%%% used\\n"\n' >"${BATS_TEST_TMPDIR}/bin/usage"
    chmod +x "${BATS_TEST_TMPDIR}"/bin/*
    export BORG_RESUME_NOTIFY_CMD="${BATS_TEST_TMPDIR}/bin/notify"
    export BORG_RESUME_INJECT_CMD="${BATS_TEST_TMPDIR}/bin/inject"
    export BORG_RESUME_USAGE_CMD="${BATS_TEST_TMPDIR}/bin/usage"
    jq -n -c --arg sid "$SID" --arg cwd "$CWD" '{session_id:$sid, cwd:$cwd, in_container:false, mode:"project"}' \
        >"$RD/sessions/$SID.json"
}

at() { export BORG_RESUME_NOW_EPOCH=$((T0 + $1)); }
watch() { run "$BIN" watch --once; [ "$status" -eq 0 ]; }
n_notify() { wc -l <"$NLOG" | tr -d ' '; }

# Run a snippet with the shared library sourced.
shared() {
    bash -c '. "$1/resume-paths.sh"; . "$1/resume-classify.sh"; . "$1/resume-shared.sh"; shift; eval "$*"' _ "$LIB" "$@"
}

mk_rec() { # <rid> <class> <state> <resume_at> [extra jq]
    jq -n -c --arg rid "$1" --arg sid "$SID" --arg class "$2" --arg state "$3" --argjson ra "$4" --argjson fs "$T0" \
        '{rid:$rid, sid:$sid, scope:"main", class:$class, action:"resume", error:"server_error", reset_text:null,
        detected_by:["liveness"], evidence:{transcript_line:2, uuid:("e-" + $sid), uuids:[("e-" + $sid)]},
        first_seen:$fs, resume_at:$ra, attempt:0, state:$state, state_log:[[$state, $fs]], inject_tries:0,
        notified:false}' | jq -c "${5:-.}" >"$RD/pending/$1.json"
}
rf() { jq -r "$2" "$RD/pending/$1.json" 2>/dev/null || jq -r "$2" "$RD/done/$1.json"; }

t_line() { printf '{"type":"user","uuid":"u-%s","message":{"role":"user","content":"hi"}}\n' "$RANDOM" >>"$1"; }

# ---- (1) one definition of "moving" -------------------------------------------------------------

@test "moving: more lines than the baseline is growth" {
    local f="${BATS_TEST_TMPDIR}/t.jsonl"
    t_line "$f"; t_line "$f"; t_line "$f"
    run shared "borg_resume_transcript_moving '$f' 2 0 600"
    [ "$status" -eq 0 ]
}

@test "moving: more bytes with the same line count (an unterminated partial line) is growth" {
    local f="${BATS_TEST_TMPDIR}/t.jsonl" sz
    t_line "$f"; t_line "$f"
    sz="$(wc -c <"$f" | tr -d ' ')"
    printf '{"type":"assistant","partial' >>"$f"
    touch -t 202001010000 "$f"
    run shared "borg_resume_transcript_moving '$f' 2 $sz 600"
    [ "$status" -eq 0 ]
}

@test "moving: only a recent mtime is a hint (2), not growth" {
    local f="${BATS_TEST_TMPDIR}/t.jsonl" sz
    t_line "$f"; t_line "$f"
    sz="$(wc -c <"$f" | tr -d ' ')"
    run shared "BORG_RESUME_NOW_EPOCH=\$(( \$(date +%s) + 30 )); borg_resume_transcript_moving '$f' 2 $sz 600"
    [ "$status" -eq 2 ]
}

@test "moving: unchanged and old is quiet (1)" {
    local f="${BATS_TEST_TMPDIR}/t.jsonl" sz
    t_line "$f"; t_line "$f"
    sz="$(wc -c <"$f" | tr -d ' ')"
    touch -t 202001010000 "$f"
    run shared "borg_resume_transcript_moving '$f' 2 $sz 600"
    [ "$status" -eq 1 ]
}

@test "S10 no longer carries its own stall watchdog" {
    run grep -c '_rl_stall_pass' "$LIB/resume-liveness.sh"
    [ "$output" = 0 ]
}

@test "stall: a confirmed record stalls once, notifies once (one outbox line), and counts as no progress" {
    printf '{"type":"user","uuid":"u1"}\n{"type":"assistant","uuid":"a1"}\n' >"$PD/$SID.jsonl"
    touch -t 202001010000 "$PD/$SID.jsonl"
    mk_rec r_s usage_limit confirmed "$T0" \
        '.confirmed_at = 1791806400 | .confirmed_lines = 2 | .last_growth_at = 1791806400'
    printf '{"t":%s,"ev":"permission_prompt","sid":"%s","scope":"main"}\n' "$((T0 + 60))" "$SID" \
        >"$RD/events/$SID.jsonl"
    mkdir -p "$RD/state"
    jq -n -c '{consecutive:0, resumed_total:0, injections_today:0, day:"2026-10-12", last_progress_lines:0,
        hook_cursor:0}' >"$RD/state/$SID.json"
    at 700
    watch
    [ "$(rf r_s .state)" = stalled ]
    [ "$(n_notify)" = 1 ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
    [ "$(jq -r .kind "$RD/notify.jsonl")" = stalled ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
}

# ---- (2) one notification path --------------------------------------------------------------------

@test "notify: a gate notification lands in the notify.jsonl outbox and is delivered" {
    run shared "borg_resume_notify expired '$SID' r_x 'Resume r_x expired'"
    [ "$status" -eq 0 ]
    [ "$(n_notify)" = 1 ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
    [ "$(jq -r .msg "$RD/notify.jsonl")" = "Resume r_x expired" ]
}

@test "notify: the same event twice is delivered and logged once" {
    run shared "borg_resume_notify expired '$SID' r_x 'm'; borg_resume_notify expired '$SID' r_x 'm again'"
    [ "$(n_notify)" = 1 ]
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" = 1 ]
}

@test "notify: a different kind or rid is a different event" {
    run shared "borg_resume_notify expired '$SID' r_x 'a'; borg_resume_notify capped '$SID' r_x 'b';
        borg_resume_notify expired '$SID' r_y 'c'"
    [ "$(n_notify)" = 3 ]
}

@test "notify: an explicit key lets the same (kind, sid) fire again for a new detection" {
    run shared "borg_resume_notify early_notice '$SID' '' 'a' k1; borg_resume_notify early_notice '$SID' '' 'b' k2;
        borg_resume_notify early_notice '$SID' '' 'c' k1"
    [ "$(n_notify)" = 2 ]
}

@test "notify: BORG_RESUME_NOTIFY_CMD may be a shell snippet reading the positional arguments" {
    export BORG_RESUME_NOTIFY_CMD="printf \"%s\\n\" \"\$3\" >>\"$NLOG\""
    run shared "borg_resume_notify expired '$SID' r_x 'snippet message'"
    [ "$(cat "$NLOG")" = "snippet message" ]
}

@test "notify: the outbox stays bounded" {
    export BORG_RESUME_NOTIFY_KEEP=2
    run shared "for i in 1 2 3 4 5 6 7 8; do borg_resume_notify k\$i '$SID' r_\$i m; done"
    [ "$(wc -l <"$RD/notify.jsonl" | tr -d ' ')" -le 4 ]
}

@test "the gate has no notify seam of its own any more" {
    run grep -c 'read -r -a _w <<<"\$BORG_RESUME_NOTIFY_CMD"' "$LIB/resume-gate.sh"
    [ "$output" = 0 ]
}

# ---- (3) the gate honours S10's cause ---------------------------------------------------------------

@test "gate: process_death with cause crash is never injected and defers (no_pane)" {
    printf 'borg_resume_relaunch_hook() { return 1; }\n' >"${BATS_TEST_TMPDIR}/nohook.sh"
    export BORG_RESUME_RELAUNCH_HOOK_FILE="${BATS_TEST_TMPDIR}/nohook.sh"
    printf '{"type":"user","uuid":"u1"}\n' >"$PD/$SID.jsonl"
    mk_rec r_c process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    watch
    [ ! -s "$ILOG" ]
    [ "$(rf r_c .state)" = deferred ]
    [ "$(rf r_c .gate_reason)" = no_pane ]
}

@test "gate: pane_closed and reboot causes are never injected either" {
    printf 'borg_resume_relaunch_hook() { return 1; }\n' >"${BATS_TEST_TMPDIR}/nohook.sh"
    export BORG_RESUME_RELAUNCH_HOOK_FILE="${BATS_TEST_TMPDIR}/nohook.sh"
    printf '{"type":"user","uuid":"u1"}\n' >"$PD/$SID.jsonl"
    mk_rec r_p process_death scheduled "$((T0 - 10))" '.cause = "pane_closed"'
    mk_rec r_b process_death scheduled "$((T0 - 10))" '.cause = "reboot" | .scope = "workflow:wf1"'
    watch
    [ ! -s "$ILOG" ]
    [ "$(rf r_p .state)" = deferred ]
    at 400
    watch
    [ ! -s "$ILOG" ]
    [ "$(rf r_b .gate_reason)" = no_pane ]
}

@test "gate: the S11 hook point is called for a dead-owner record instead of injecting" {
    printf '{"type":"user","uuid":"u1"}\n' >"$PD/$SID.jsonl"
    mk_rec r_c process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    cat >"${BATS_TEST_TMPDIR}/hook.sh" <<EOF
borg_resume_relaunch_hook() { printf '%s %s\n' "\$1" "\$2" >>"${BATS_TEST_TMPDIR}/hook.log"; return 1; }
EOF
    export BORG_RESUME_RELAUNCH_HOOK_FILE="${BATS_TEST_TMPDIR}/hook.sh"
    watch
    [ ! -s "$ILOG" ]
    grep -q "r_c crash" "${BATS_TEST_TMPDIR}/hook.log"
}

@test "gate: a transient record with no cause is still injected (no regression)" {
    printf '{"type":"user","uuid":"u1"}\n' >"$PD/$SID.jsonl"
    mk_rec r_t transient scheduled "$((T0 - 10))"
    watch
    [ "$(wc -l <"$ILOG" | tr -d ' ')" = 1 ]
}
