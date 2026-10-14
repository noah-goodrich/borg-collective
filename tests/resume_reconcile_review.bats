#!/usr/bin/env bats
# RECONCILE-6 review fixes: the S11 relaunch hook runs only after the dynamic gates and never loops, the stall
# watchdog compares like with like (agent scope), and the shared library fails closed when it is missing.
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
    HLOG="${BATS_TEST_TMPDIR}/hook.log"
    : >"$NLOG"
    : >"$ILOG"
    : >"$HLOG"
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
hook_calls() { wc -l <"$HLOG" | tr -d ' '; }

mk_rec() { # <rid> <class> <state> <resume_at> [extra jq]
    jq -n -c --arg rid "$1" --arg sid "$SID" --arg class "$2" --arg state "$3" --argjson ra "$4" --argjson fs "$T0" \
        '{rid:$rid, sid:$sid, scope:"main", class:$class, action:"resume", error:"server_error", reset_text:null,
        detected_by:["liveness"], evidence:{transcript_line:2, uuid:("e-" + $sid), uuids:[("e-" + $sid)]},
        first_seen:$fs, resume_at:$ra, attempt:0, state:$state, state_log:[[$state, $fs]], inject_tries:0,
        notified:false}' | jq -c "${5:-.}" >"$RD/pending/$1.json"
}
rf() { jq -r "$2" "$RD/pending/$1.json" 2>/dev/null || jq -r "$2" "$RD/done/$1.json"; }
t_line() { printf '{"type":"user","uuid":"u-%s","message":{"role":"user","content":"hi"}}\n' "$RANDOM" >>"$1"; }

# hook_file <rc> [state the hook moves the record to]
hook_file() {
    {
        printf 'borg_resume_relaunch_hook() {\n'
        printf '    printf "%%s %%s\\n" "$1" "$2" >>"%s"\n' "$HLOG"
        if [ -n "${2:-}" ]; then
            printf '    jq -c ".state = \\"%s\\"" "$3" >"$3.t" && mv -f "$3.t" "$3"\n' "$2"
        fi
        printf '    return %s\n}\n' "$1"
    } >"${BATS_TEST_TMPDIR}/hook.sh"
    export BORG_RESUME_RELAUNCH_HOOK_FILE="${BATS_TEST_TMPDIR}/hook.sh"
}

@test "relaunch hook: a .borg/no-resume repository is never relaunched" {
    t_line "$PD/$SID.jsonl"
    mkdir -p "$CWD/.borg"
    : >"$CWD/.borg/no-resume"
    mk_rec r_c process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    hook_file 0 done
    watch
    [ "$(hook_calls)" = 0 ]
    [ "$(rf r_c .gate_reason)" = no_resume ]
}

@test "relaunch hook: the concurrency cap applies" {
    t_line "$PD/$SID.jsonl"
    mk_rec r_c process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    hook_file 0 done
    export BORG_RESUME_MAX_ACTIVE=0
    watch
    [ "$(hook_calls)" = 0 ]
    [ "$(rf r_c .gate_reason)" = concurrency ]
}

@test "relaunch hook: at most BORG_RESUME_MAX_PER_PASS dead sessions are relaunched in one pass" {
    local sid2="00000000-0000-4000-8000-0000000000bb"
    t_line "$PD/$SID.jsonl"
    t_line "$PD/$sid2.jsonl"
    jq -n -c --arg sid "$sid2" --arg cwd "$CWD" '{session_id:$sid, cwd:$cwd, in_container:false, mode:"project"}' \
        >"$RD/sessions/$sid2.json"
    mk_rec r_a process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    mk_rec r_b process_death scheduled "$((T0 - 10))" ".cause = \"crash\" | .sid = \"$sid2\""
    hook_file 0 relaunching
    watch
    [ "$(hook_calls)" = 1 ]
}

@test "relaunch hook: returning 0 without a transition is forced to relaunching and never called twice" {
    t_line "$PD/$SID.jsonl"
    mk_rec r_c process_death scheduled "$((T0 - 10))" '.cause = "crash"'
    hook_file 0
    watch
    [ "$(hook_calls)" = 1 ]
    [ "$(rf r_c .state)" = relaunching ]
    at 60
    watch
    at 120
    watch
    [ "$(hook_calls)" = 1 ]
}

@test "stall: an agent-scope record is watched against the AGENT transcript baseline, not main" {
    local ad="$PD/$SID/subagents" i
    mkdir -p "$ad"
    for i in $(seq 1 50); do t_line "$PD/$SID.jsonl"; done
    for i in 1 2 3; do t_line "$ad/agent-A1.jsonl"; done
    mk_rec r_g usage_limit injected "$T0" ".scope = \"agent:A1\" | .injected_at = $T0 | .inject_lines = 50
        | .state_log = [[\"injected\", $T0]]"
    printf '{"type":"user","uuid":"tg","message":{"role":"user","content":"[borg-resume r_g] go"}}\n' \
        >>"$PD/$SID.jsonl"
    printf '{"t":%s,"ev":"permission_prompt","sid":"%s"}\n' "$((T0 + 6))" "$SID" >"$RD/events/$SID.jsonl"
    touch -t 202001010000 "$PD/$SID.jsonl" "$ad/agent-A1.jsonl"
    at 100
    watch
    [ "$(rf r_g .state)" = confirmed ]
    [ "$(rf r_g .confirmed_lines)" = 3 ]
    t_line "$ad/agent-A1.jsonl"
    touch -t 202001010000 "$ad/agent-A1.jsonl"
    at 1000
    watch
    [ "$(rf r_g .state)" = confirmed ]
    [ "$(rf r_g .last_lines)" = 4 ]
}

@test "stall: line growth with an OLD mtime prevents a stall in the gate" {
    t_line "$PD/$SID.jsonl"
    t_line "$PD/$SID.jsonl"
    mk_rec r_s usage_limit confirmed "$T0" \
        ".confirmed_at = $T0 | .confirmed_lines = 1 | .last_lines = 1 | .last_growth_at = $T0"
    printf '{"t":%s,"ev":"permission_prompt","sid":"%s"}\n' "$((T0 + 60))" "$SID" >"$RD/events/$SID.jsonl"
    touch -t 202001010000 "$PD/$SID.jsonl"
    at 700
    watch
    [ "$(rf r_s .state)" = confirmed ]
    [ "$(rf r_s .last_lines)" = 2 ]
}

@test "stall: a permission prompt older than the last growth is not a stuck prompt" {
    t_line "$PD/$SID.jsonl"
    t_line "$PD/$SID.jsonl"
    touch -t 202001010000 "$PD/$SID.jsonl"
    mk_rec r_s usage_limit confirmed "$T0" \
        ".confirmed_at = $T0 | .confirmed_lines = 2 | .last_lines = 2 | .last_growth_at = $((T0 + 300))"
    printf '{"t":%s,"ev":"permission_prompt","sid":"%s"}\n' "$((T0 + 60))" "$SID" >"$RD/events/$SID.jsonl"
    at 1000
    watch
    [ "$(rf r_s .state)" = confirmed ]
}

@test "install layout: watch refuses a lib dir without resume-shared.sh" {
    local ld="${BATS_TEST_TMPDIR}/lib2"
    mkdir -p "$ld"
    cp "$LIB"/*.sh "$ld"/
    rm "$ld/resume-shared.sh"
    export BORG_RESUME_LIBDIR="$ld"
    run "$BIN" watch --once
    [ "$status" -ne 0 ]
}

@test "install layout: gate and liveness fail closed without the shared library" {
    local ld="${BATS_TEST_TMPDIR}/lib3"
    t_line "$PD/$SID.jsonl"
    mk_rec r_t transient scheduled "$((T0 - 10))"
    mkdir -p "$ld"
    cp "$LIB"/*.sh "$ld"/
    rm "$ld/resume-shared.sh"
    run bash -c '. "$1/resume-paths.sh"; . "$1/resume-classify.sh"; . "$1/resume-inventory.sh";
        . "$1/resume-watch.sh"; . "$1/resume-prompt.sh"; . "$1/resume-gate.sh"; . "$1/resume-liveness.sh";
        borg_resume_gate_confirm_pass; borg_resume_gate_due_pass; borg_resume_liveness_pass' _ "$ld"
    [ "$status" -eq 0 ]
    [ ! -s "$ILOG" ]
    [ "$(rf r_t .state)" = scheduled ]
}
