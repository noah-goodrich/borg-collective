#!/usr/bin/env bats
# Relaunch and resume dialog for borg-resume (slice S11), driven through borg-resume watch --once.
# Everything is synthetic: a fake tmux (tests/fixtures/resume-relaunch/fake-tmux.sh) on a state dir, a stub claude,
# a stub injector and notifier. No real claude, tmux, docker, launchd, notifier or state dir.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    LIB="${BATS_TEST_DIRNAME}/../lib/borg"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_RESUME_LIBDIR="$LIB"
    export BORG_IN_CONTAINER=0
    NOW=1791806400
    export BORG_RESUME_NOW_EPOCH=$NOW
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_PANES_CMD BORG_RESUME_MAX_RELAUNCH_PER_HOUR
    export BORG_RESUME_BOOT_EPOCH=$((NOW - 86400 * 30))
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export BORG_RESUME_RELAUNCH_TRIES=4 BORG_RESUME_RELAUNCH_POLL_SEC=0
    export BORG_RESUME_MAX_ACTIVE=10 BORG_RESUME_MAX_PER_PASS=1
    RD="$BORG_RESUME_DIR"
    FT="${BATS_TEST_TMPDIR}/ft"
    mkdir -p "$FT" "${BATS_TEST_TMPDIR}/bin"
    export FT FIXDIR="${BATS_TEST_DIRNAME}/fixtures/resume-inject"
    export BORG_RESUME_TMUX_CMD="${BATS_TEST_DIRNAME}/fixtures/resume-relaunch/fake-tmux.sh"
    printf '#!/bin/sh\nexit 0\n' >"${BATS_TEST_TMPDIR}/bin/claude"
    chmod +x "${BATS_TEST_TMPDIR}/bin/claude"
    export BORG_CLAUDE_BIN="${BATS_TEST_TMPDIR}/bin/claude"
    ILOG="${BATS_TEST_TMPDIR}/inject.log"
    NLOG="${BATS_TEST_TMPDIR}/notify.log"
    : >"$ILOG"
    : >"$NLOG"
    cat >"${BATS_TEST_TMPDIR}/bin/inject" <<STUB
#!/bin/bash
printf '%s\t%s\n' "\$1" "\$2" >>"$ILOG"
echo "injected pane=%1"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/usage" <<'STUB'
#!/bin/bash
echo "Current session: 40% used"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/notify" <<STUB
#!/bin/bash
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$NLOG"
STUB
    chmod +x "${BATS_TEST_TMPDIR}/bin/inject" "${BATS_TEST_TMPDIR}/bin/usage" "${BATS_TEST_TMPDIR}/bin/notify"
    export BORG_RESUME_INJECT_CMD="${BATS_TEST_TMPDIR}/bin/inject"
    export BORG_RESUME_USAGE_CMD="${BATS_TEST_TMPDIR}/bin/usage"
    export BORG_RESUME_NOTIFY_CMD="${BATS_TEST_TMPDIR}/bin/notify"
    SID="00000000-0000-4000-8000-0000000000aa"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done"
    export BORG_RESUME_CWD_ALLOW="${BATS_TEST_TMPDIR}/work"
    CWD="${BATS_TEST_TMPDIR}/work/proj"
    mkdir -p "$CWD"
    sleep 0 &
    DEADPID=$!
    wait "$DEADPID"
    echo clean >"$FT/scenario"
}

lstart_of() { LC_ALL=C date -r "$1" '+%a %b %e %T %Y' 2>/dev/null || LC_ALL=C date -d "@$1" '+%a %b %e %T %Y'; }
set_mtime() {
    touch -t "$(date -r "$2" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$2" +%Y%m%d%H%M.%S)" "$1"
}

# <sid> [mode] [project] : a dead session with an agent in flight
mk_dead() {
    local sid="$1" f="$PD/$1.jsonl"
    jq -n -c --arg sid "$sid" --argjson pid "$DEADPID" --arg st "$(lstart_of $((NOW - 3600)))" \
        --arg p "${3:-proj}" --arg m "${2:-project}" --arg cwd "$CWD" \
        '{session_id:$sid, cwd:$cwd, project:$p, mode:$m, in_container:false, claude_pid:$pid, claude_start:$st,
          tmux:{pane_id:"%1", pane_pid:1, session:"s", window:"win", window_index:1, pane_index:0, project_dir:$cwd}}' \
        >"$RD/sessions/$sid.json"
    set_mtime "$RD/sessions/$sid.json" $((NOW - 60))
    printf '{"type":"user","uuid":"u-%s","cwd":"%s","message":{"role":"user","content":"hello"}}\n' \
        "$RANDOM" "$CWD" >"$f"
    printf '{"type":"assistant","uuid":"t-%s","message":{"role":"assistant","stop_reason":"tool_use",' "$RANDOM" >>"$f"
    printf '"content":[{"type":"tool_use","id":"x","name":"Agent","input":{}}]}}\n' >>"$f"
    set_mtime "$f" $((NOW - 3600))
}

# detect (first pass), then run the due pass once the grace has passed
run_due() {
    run "$BIN" watch --once
    [ "$status" -eq 0 ]
    BORG_RESUME_NOW_EPOCH=$((NOW + 400)) run "$BIN" watch --once
    [ "$status" -eq 0 ]
}

n_calls() { grep -c "^$1 " "$FT/calls.log" 2>/dev/null || true; }
n_inject() { wc -l <"$ILOG" | tr -d ' '; }
rec() { cat "$RD"/pending/*.json "$RD"/done/*.json 2>/dev/null | jq -r -s "$1"; }
want() { printf '%s' "$1" >"$FT/want_sid"; }

@test "clean relaunch: argv-form new-window, absolute claude, pane bound, then the normal injection runs" {
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(n_calls new-window)" = 1 ]
    grep -qxF "ARG[--resume]" "$FT/calls.log"
    grep -qxF "ARG[$SID]" "$FT/calls.log"
    grep -qxF "ARG[${BATS_TEST_TMPDIR}/bin/claude]" "$FT/calls.log"
    grep -qxF "ARG[$CWD]" "$FT/calls.log"
    grep -q "^%9|$SID|" "$FT/panes"
    [ "$(n_inject)" = 1 ]
    [ "$(rec '.[0].state')" = injected ]
    [ "$(rec '.[0].relaunch.cause')" = pane_closed ]
}

@test "relaunch counts against the S9 session counters" {
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(jq -r .injections_today "$RD/state/$SID.json")" = 2 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 2 ]
    [ "$(wc -l <"$RD/relaunch.log" | tr -d ' ')" = 1 ]
}

@test "nothing is relaunched before the grace has passed" {
    mk_dead "$SID"
    want "$SID"
    run "$BIN" watch --once
    [ "$status" -eq 0 ]
    [ ! -e "$FT/calls.log" ]
}

@test "resume-size dialog (default, U17 uncaptured): notify_only, nothing typed, manual command given" {
    echo size >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    ! grep -q "send-keys" "$FT/calls.log"
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(rec '.[0].done_reason')" = relaunch_resume_size_dialog ]
    [ "$(n_inject)" = 0 ]
    grep -q "claude --resume $SID" "$NLOG"
}

@test "resume-size dialog, opted in (SYNTHETIC fixture): the digit alone, never followed by Enter" {
    export BORG_RESUME_ANSWER_SIZE_DIALOG=1
    echo size >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    grep -q "send-keys -t %9 -l 2" "$FT/calls.log"
    ! grep -q "Enter" "$FT/calls.log"
    ! grep -q "send-keys -t %9 -l 1" "$FT/calls.log"
    [ "$(n_inject)" = 1 ]
    [ "$(rec '.[0].state')" = injected ]
}

@test "login shell wraps claude: argv form via exec \"\$@\", no string building" {
    mk_dead "$SID"
    want "$SID"
    export BORG_RESUME_LOGIN_SHELL=/bin/bash
    run_due
    grep -qxF "ARG[/bin/bash]" "$FT/calls.log"
    grep -qxF "ARG[-l]" "$FT/calls.log"
    grep -qxF 'ARG[exec "$@"]' "$FT/calls.log"
    grep -qxF "ARG[${BATS_TEST_TMPDIR}/bin/claude]" "$FT/calls.log"
    grep -qxF "ARG[$SID]" "$FT/calls.log"
}

@test "a cwd containing # is rejected (tmux format expansion)" {
    CWD="${BATS_TEST_TMPDIR}/work/a#(touch pwned)"
    mkdir -p "$CWD"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].done_reason')" = bad_cwd ]
}

@test "trust prompt: notify_only, nothing typed, nothing injected, exact command in the notice" {
    echo trust >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(rec '.[0].done_reason')" = relaunch_trust_prompt ]
    ! grep -q "send-keys" "$FT/calls.log"
    [ "$(n_inject)" = 0 ]
    grep -q "claude --resume $SID" "$NLOG"
}

@test "permission prompt: notify_only, nothing typed, nothing injected" {
    echo perm >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(rec '.[0].done_reason')" = relaunch_permission_prompt ]
    ! grep -q "send-keys" "$FT/calls.log"
    [ "$(n_inject)" = 0 ]
}

@test "unrecognized screen: notify_only after the window, nothing typed, nothing injected" {
    echo unknown >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(rec '.[0].done_reason')" = relaunch_no_verification ]
    ! grep -q "send-keys" "$FT/calls.log"
    [ "$(n_inject)" = 0 ]
}

@test "forked session id is a failure: notify_only, new id recorded, nothing injected" {
    echo forked >"$FT/scenario"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(rec '.[0].done_reason')" = relaunch_forked ]
    [ "$(rec '.[0].forked_to')" = "ffffffff-0000-4000-8000-000000000001" ]
    [ "$(n_inject)" = 0 ]
}

@test "resume-size dialog, opted in, where the summary option forks the id: failure, never injected" {
    export BORG_RESUME_ANSWER_SIZE_DIALOG=1
    echo size >"$FT/scenario"
    mk_dead "$SID"
    want "ffffffff-0000-4000-8000-0000000000ee"
    run_due
    [ "$(rec '.[0].state')" = notify_only ]
    [ "$(n_inject)" = 0 ]
}

@test "hostile cwd names run nothing and are passed as one argv element" {
    local d
    for d in '$(touch pwned)' 'a`touch pwned`b' 'two words' "it's"; do
        rm -rf "$RD" "$FT"
        mkdir -p "$FT" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done"
        echo clean >"$FT/scenario"
        CWD="${BATS_TEST_TMPDIR}/work/$d"
        mkdir -p "$CWD"
        mk_dead "$SID"
        want "$SID"
        run_due
        grep -qxF "ARG[$CWD]" "$FT/calls.log"
        [ "$(n_calls new-window)" = 1 ]
    done
    [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
    [ ! -e "$PWD/pwned" ]
    [ ! -e "$CWD/pwned" ]
}

@test "a cwd with a newline is rejected (notify_only, no launch)" {
    CWD="${BATS_TEST_TMPDIR}/work/line
break"
    mkdir -p "$CWD"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].done_reason')" = bad_cwd ]
}

@test "a cwd outside the allowed roots is rejected" {
    CWD="${BATS_TEST_TMPDIR}/elsewhere"
    mkdir -p "$CWD"
    mk_dead "$SID"
    jq -c '.tmux.project_dir = "/nonexistent-project"' "$RD/sessions/$SID.json" >"$RD/sessions/t.json"
    mv "$RD/sessions/t.json" "$RD/sessions/$SID.json"
    want "$SID"
    run_due
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].done_reason')" = bad_cwd ]
}

@test "a non-UUID session id is rejected" {
    SID="not-a-uuid-at-all"
    mk_dead "$SID"
    want "$SID"
    run_due
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].done_reason')" = bad_sid ]
}

@test "hourly relaunch cap holds with 5 dead sessions" {
    local i s
    for i in 1 2 3 4 5; do
        s="00000000-0000-4000-8000-00000000010$i"
        mk_dead "$s" project "p$i"
    done
    run "$BIN" watch --once
    for i in 1 2 3 4 5 6; do
        BORG_RESUME_NOW_EPOCH=$((NOW + 400 + i)) run "$BIN" watch --once
        want "x"
    done
    [ "$(n_calls new-window)" = 3 ]
    [ "$(wc -l <"$RD/relaunch.log" | tr -d ' ')" = 3 ]
    [ "$(rec '[.[] | select(.gate_reason == "relaunch_cap")] | length')" = 2 ]
}

@test "a deliberate stop (mark-closed) is never relaunched" {
    mk_dead "$SID"
    want "$SID"
    run "$BIN" watch --once
    printf '{"t":%s,"ev":"session_end","sid":"%s","via":"mark_closed","reason":"other"}\n' "$NOW" "$SID" \
        >>"$RD/events/$SID.jsonl"
    BORG_RESUME_NOW_EPOCH=$((NOW + 400)) run "$BIN" watch --once
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].state')" = cancelled ]
}

@test "a trailing interrupt marker is never relaunched" {
    mk_dead "$SID"
    want "$SID"
    run "$BIN" watch --once
    printf '{"type":"user","uuid":"i-1","message":{"role":"user","content":[{"type":"text",' >>"$PD/$SID.jsonl"
    printf '"text":"[Request interrupted by user]"}]}}\n' >>"$PD/$SID.jsonl"
    BORG_RESUME_NOW_EPOCH=$((NOW + 400)) run "$BIN" watch --once
    [ ! -e "$FT/calls.log" ]
}

@test "reboot with the tmux server gone: new-session, then the normal flow" {
    touch "$FT/down"
    export BORG_RESUME_BOOT_EPOCH=$((NOW - 600))
    mk_dead "$SID"
    want "$SID"
    run_due
    [ "$(n_calls new-session)" = 1 ]
    [ "$(rec '.[0].cause')" = reboot ]
    [ "$(n_inject)" = 1 ]
}

@test "a pane left at a shell is never typed into: a new window is opened, the old pane is unbound" {
    local p
    for p in 'user@host ~ % ' 'dquote> ' '> ' 'building something'; do
        rm -rf "$RD" "$FT"
        mkdir -p "$FT" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done"
        echo clean >"$FT/scenario"
        printf '%%3|%s|99|zsh\n' "$SID" >"$FT/panes"
        printf '%s' "$p" >"$FT/cap.%3"
        : >"$ILOG"
        mk_dead "$SID"
        want "$SID"
        run_due
        ! grep -q "send-keys" "$FT/calls.log"
        [ "$(n_calls new-window)" = 1 ]
        grep -q "^%3||" "$FT/panes"
        grep -q "^%10|$SID|" "$FT/panes"
        [ "$(n_inject)" = 1 ]
    done
}

@test "a session that is alive (owned claude pane) is not relaunched" {
    sleep 30 &
    local p=$!
    mk_dead "$SID"
    run "$BIN" watch --once
    jq -c --argjson p "$p" --arg st "$(LC_ALL=C ps -o lstart= -p "$p")" '.claude_pid = $p | .claude_start = $st' \
        "$RD/sessions/$SID.json" >"$RD/sessions/$SID.json.t" && mv "$RD/sessions/$SID.json.t" "$RD/sessions/$SID.json"
    printf '%%3|%s|%s|claude\n' "$SID" "$p" >"$FT/panes"
    printf 'x\n' >"$FT/cap.%3"
    want "$SID"
    BORG_RESUME_NOW_EPOCH=$((NOW + 400)) run "$BIN" watch --once
    kill "$p" 2>/dev/null || true
    [ ! -e "$FT/calls.log" ]
    [ "$(rec '.[0].state')" = cancelled ]
}
