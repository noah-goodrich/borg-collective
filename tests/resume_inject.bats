#!/usr/bin/env bats
# Inject lib and pane proof for borg-resume (slice S8): lib/borg/inject.sh.
# Real tmux on a private server (tmux -L) hosting a fake "claude" script that draws a composer or a fixture screen
# and logs every key it receives. Nothing touches the real tmux server, registry, ~/.claude or state dir.
# The fake's process name is bash, so tests set BORG_RESUME_PANE_CMD_RE; one test proves the default regex.

setup() {
    LIB="${BATS_TEST_DIRNAME}/../lib/borg/inject.sh"
    FXI="${BATS_TEST_DIRNAME}/fixtures/resume-inject"
    FXP="${BATS_TEST_DIRNAME}/fixtures/resume/panes"
    command -v tmux >/dev/null || skip "tmux not installed"
    command -v jq >/dev/null || skip "jq not installed"
    SOCK="borgtest${BASHPID}x${RANDOM}"
    export BORG_RESUME_TMUX_CMD="tmux -L ${SOCK}"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PANE_CMD_RE='^bash$'
    export BORG_RESUME_SEND_DELAY=0.1
    export FAKE_KEYLOG="${BATS_TEST_TMPDIR}/keys.log"
    : >"$FAKE_KEYLOG"
    SID="11111111-2222-3333-4444-555555555555"
    mkdir -p "${BORG_RESUME_DIR}/sessions" "${BATS_TEST_TMPDIR}/bin"
    cat >"${BATS_TEST_TMPDIR}/bin/claude" <<'FAKE'
#!/bin/bash
RULE="$(printf '%.0s─' $(seq 1 60))"
buf="${FAKE_BUF:-}"
draw() {
    printf '\033[2J\033[H'
    if [ -n "${FAKE_SCREEN:-}" ]; then
        cat "$FAKE_SCREEN"
    else
        printf 'earlier output\n\n%s\n❯ %s\n%s\n  ? for shortcuts\n' "$RULE" "$buf" "$RULE"
    fi
}
stty -echo -icanon min 1 2>/dev/null
draw
while IFS= read -rsn1 ch; do
    printf '%q\n' "$ch" >>"$FAKE_KEYLOG"
    case "$ch" in
        $'\r' | "") printf 'SUBMIT %s\n' "$buf" >>"$FAKE_KEYLOG"; buf="" ;;
        $'\025') buf="" ;;
        *) [ -n "${FAKE_NOECHO:-}" ] || buf="${buf}${ch}" ;;
    esac
    [ -n "${FAKE_SCREEN:-}" ] || draw
done
FAKE
    chmod +x "${BATS_TEST_TMPDIR}/bin/claude"
}

teardown() {
    [ -n "${SOCK:-}" ] && tmux -L "$SOCK" kill-server 2>/dev/null || true
}

# launch_fake [session] [ENV=VAL ...]: start the fake in a new tmux session, wait for its first draw.
launch_fake() {
    local _s="${1:-t}"
    shift || true
    tmux -L "$SOCK" new-session -d -s "$_s" -x "${LAUNCH_W:-160}" -y 50 env "$@" "${BATS_TEST_TMPDIR}/bin/claude"
    local _i=0
    while [ "$_i" -lt 50 ]; do
        tmux -L "$SOCK" capture-pane -p -t "$_s" 2>/dev/null | grep -q . && break
        sleep 0.1
        _i=$((_i + 1))
    done
}

pane_of() { tmux -L "$SOCK" list-panes -t "${1:-t}" -F '#{pane_id}'; }
panepid_of() { tmux -L "$SOCK" list-panes -t "${1:-t}" -F '#{pane_pid}' | head -1; }

# register <sid> <pid> [in_container]: a registry row as the S4 hook writes it (claude_start from ps lstart).
register() {
    local _sid="$1" _pid="$2" _c="${3:-false}" _st
    _st="$(LC_ALL=C ps -o lstart= -p "$_pid" | sed -e 's/^ *//' -e 's/ *$//')"
    jq -n --arg sid "$_sid" --argjson pid "$_pid" --arg st "$_st" --argjson c "$_c" \
        '{session_id:$sid, in_container:$c, claude_pid:$pid, claude_start:$st}' \
        >"${BORG_RESUME_DIR}/sessions/${_sid}.json"
}

bind() { tmux -L "$SOCK" set-option -p -t "${2:-t}" @borg_sid "$1"; }

keylog() { cat "$FAKE_KEYLOG"; }

# ---- classifier: fixture-driven, no tmux needed ----

@test "classify: synthetic idle composer and the captured empty composer under a limit banner" {
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXI/idle.txt'"
    [ "$status" -eq 0 ]
    [ "$output" = "idle_empty" ]
}

@test "classify: the scrubbed captured composer (text redacted) is never idle_empty" {
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXP/composer.txt'"
    [ "$status" -eq 0 ]
    [ "$output" != "idle_empty" ]
}

@test "classify: permission dialog fixture is dialog" {
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXP/permission.txt'"
    [ "$output" = "dialog" ]
}

@test "classify: limit dialog and limit auto-continue banner are dialog" {
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXP/limit.txt'"
    [ "$output" = "dialog" ]
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXP/limit_auto_continue.txt'"
    [ "$output" = "dialog" ]
}

@test "classify: trust folder, AskUserQuestion, plan approval, resume size are dialog" {
    local f
    for f in "$FXP/trust_folder.txt" "$FXI/askuser.txt" "$FXI/plan.txt" "$FXI/resume_size.txt"; do
        run bash -c ". '$LIB'; borg_inject_classify_text < '$f'"
        [ "$output" = "dialog" ] || { echo "$f -> $output"; return 1; }
    done
}

@test "classify: draft in composer is draft, queued messages is busy, no composer is unknown" {
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXI/draft.txt'"
    [ "$output" = "draft" ]
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXP/queued_composer.txt'"
    [ "$output" = "busy" ]
    run bash -c ". '$LIB'; borg_inject_classify_text < '$FXI/unknown.txt'"
    [ "$output" = "unknown" ]
    run bash -c ". '$LIB'; printf '' | borg_inject_classify_text"
    [ "$output" = "unknown" ]
}

@test "classify: stale dialog words in scrollback above the composer do not block" {
    run bash -c ". '$LIB'; { printf 'Esc to cancel\n'; cat '$FXI/idle.txt'; } | borg_inject_classify_text"
    [ "$output" = "idle_empty" ]
}

# ---- pane resolution and binding ----

@test "find_pane: resolves only by @borg_sid" {
    launch_fake t
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 1 ]
    bind "$SID"
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 0 ]
    [[ "$output" == "$(pane_of)"* ]]
}

@test "find_pane: a pane bound to another session is never targeted" {
    launch_fake t
    bind "99999999-0000-0000-0000-000000000000"
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "find_pane: after a tmux server restart nothing resolves" {
    launch_fake t
    bind "$SID"
    tmux -L "$SOCK" kill-server
    launch_fake t
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 1 ]
}

@test "find_pane: the default regex needs claude or a version string, a bash pane is not a claude pane" {
    launch_fake t
    bind "$SID"
    run bash -c "unset BORG_RESUME_PANE_CMD_RE; . '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 1 ]
}

@test "find_pane: two panes bound to one sid is ambiguous" {
    launch_fake t
    tmux -L "$SOCK" split-window -t t -d env "${BATS_TEST_TMPDIR}/bin/claude"
    local p
    for p in $(tmux -L "$SOCK" list-panes -t t -F '#{pane_id}'); do bind "$SID" "$p"; done
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 2 ]
}

@test "bind_container: exactly one claude pane in the project window binds" {
    launch_fake t
    tmux -L "$SOCK" set-option -w -t t @project_dir /work/proj
    run bash -c ". '$LIB'; borg_inject_bind_container '$SID' /work/proj"
    [ "$status" -eq 0 ]
    run tmux -L "$SOCK" show-options -p -v -t t @borg_sid
    [ "$output" = "$SID" ]
}

@test "bind_container: two claude panes never bind and never fall back to the rightmost" {
    launch_fake t
    tmux -L "$SOCK" split-window -t t -d env "${BATS_TEST_TMPDIR}/bin/claude"
    tmux -L "$SOCK" set-option -w -t t @project_dir /work/proj
    run bash -c ". '$LIB'; borg_inject_bind_container '$SID' /work/proj"
    [ "$status" -ne 0 ]
    run bash -c ". '$LIB'; borg_inject_find_pane '$SID'"
    [ "$status" -eq 1 ]
}

@test "bind_container: a window with a different project_dir does not bind" {
    launch_fake t
    tmux -L "$SOCK" set-option -w -t t @project_dir /work/other
    run bash -c ". '$LIB'; borg_inject_bind_container '$SID' /work/proj"
    [ "$status" -ne 0 ]
}

# ---- ownership ----

@test "owner: live claude_pid with matching start inside the pane tree passes" {
    launch_fake t
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -eq 0 ]
}

@test "owner: a dead claude_pid fails" {
    launch_fake t
    sleep 0.01 &
    local dead=$!
    wait "$dead"
    jq -n --arg sid "$SID" --argjson pid "$dead" \
        '{session_id:$sid,in_container:false,claude_pid:$pid,claude_start:"x"}' \
        >"${BORG_RESUME_DIR}/sessions/${SID}.json"
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -ne 0 ]
    [[ "$output" == *pid_dead* ]]
}

@test "owner: a recycled pid with a different start time fails" {
    launch_fake t
    register "$SID" "$(panepid_of)"
    jq '.claude_start = "Mon Jan  1 00:00:00 2001"' "${BORG_RESUME_DIR}/sessions/${SID}.json" \
        >"${BATS_TEST_TMPDIR}/r.json"
    mv "${BATS_TEST_TMPDIR}/r.json" "${BORG_RESUME_DIR}/sessions/${SID}.json"
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -ne 0 ]
    [[ "$output" == *start_mismatch* ]]
}

@test "owner: a pid outside the pane process tree fails" {
    launch_fake t
    sleep 30 &
    local other=$!
    register "$SID" "$other"
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    kill "$other" 2>/dev/null || true
    [ "$status" -ne 0 ]
    [[ "$output" == *not_in_pane* ]]
}

@test "owner: no registry row, an empty claude_start, and a container session all fail" {
    launch_fake t
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -ne 0 ]
    [[ "$output" == *no_registry* ]]
    jq -n --arg sid "$SID" --argjson pid "$$" '{session_id:$sid,in_container:false,claude_pid:$pid,claude_start:null}' \
        >"${BORG_RESUME_DIR}/sessions/${SID}.json"
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -ne 0 ]
    register "$SID" "$(panepid_of)" true
    run bash -c ". '$LIB'; borg_inject_owner_check '$SID' '$(panepid_of)'"
    [ "$status" -ne 0 ]
    [[ "$output" == *container* ]]
}

# ---- client activity ----

@test "human_active: a client active 5s ago is active, 60s ago is quiet, none attached is quiet" {
    export BORG_RESUME_NOW_EPOCH=1000000
    export BORG_RESUME_CLIENTS_CMD="printf '999995\n'"
    run bash -c ". '$LIB'; borg_inject_human_active"
    [ "$status" -eq 0 ]
    export BORG_RESUME_CLIENTS_CMD="printf '999940\n'"
    run bash -c ". '$LIB'; borg_inject_human_active"
    [ "$status" -ne 0 ]
    export BORG_RESUME_CLIENTS_CMD="true"
    run bash -c ". '$LIB'; borg_inject_human_active"
    [ "$status" -ne 0 ]
}

@test "human_active: the real list-clients on a server with no clients is quiet" {
    launch_fake t
    unset BORG_RESUME_CLIENTS_CMD
    run bash -c ". '$LIB'; borg_inject_human_active"
    [ "$status" -ne 0 ]
}

# ---- the whole injection ----

@test "line: idle empty composer, bound and owned: injects exactly the text and submits" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' '[borg-resume r_7f3a2c] continue where you stopped'"
    [ "$status" -eq 0 ]
    [[ "$output" == injected* ]]
    keylog | grep -qF 'SUBMIT [borg-resume r_7f3a2c] continue where you stopped'
}

@test "line: text goes through send-keys -l literally, then a separate Enter, delay between" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/sk.log"\nexec tmux -L %s send-keys "$@"\n' \
        "$BATS_TEST_TMPDIR" "$SOCK" >"${BATS_TEST_TMPDIR}/sk"
    chmod +x "${BATS_TEST_TMPDIR}/sk"
    export BORG_RESUME_SENDKEYS_CMD="${BATS_TEST_TMPDIR}/sk"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'Enter C-c Escape ok'"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"${BATS_TEST_TMPDIR}/sk.log" | tr -d ' ')" = "2" ]
    sed -n 1p "${BATS_TEST_TMPDIR}/sk.log" | grep -qF -- "-l -t $(pane_of) Enter C-c Escape ok"
    sed -n 2p "${BATS_TEST_TMPDIR}/sk.log" | grep -qF -- "-t $(pane_of) Enter"
}

@test "equivalence: same two-call transport as borg-usage-watch (text, then a separate Enter), modulo -l" {
    command -v zsh >/dev/null || skip "zsh not installed"
    local uw="${BATS_TEST_DIRNAME}/../bin/borg-usage-watch" rec="${BATS_TEST_TMPDIR}/uw.log"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s"\n' "$rec" >"${BATS_TEST_TMPDIR}/uwsk"
    chmod +x "${BATS_TEST_TMPDIR}/uwsk"
    run zsh -c "BORG_USAGE_SENDKEYS_CMD='${BATS_TEST_TMPDIR}/uwsk' BORG_USAGE_SWEEP_CMD_TEXT='hello there' \
        BORG_USAGE_SENDKEYS_DELAY=0 ; $(awk '/^_send_checkpoint\(\)/,/^}/' "$uw"); _send_checkpoint %9"
    [ "$status" -eq 0 ]
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s/mine.log"\nexec tmux -L %s send-keys "$@"\n' \
        "$BATS_TEST_TMPDIR" "$SOCK" >"${BATS_TEST_TMPDIR}/sk"
    chmod +x "${BATS_TEST_TMPDIR}/sk"
    export BORG_RESUME_SENDKEYS_CMD="${BATS_TEST_TMPDIR}/sk"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello there'"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$rec" | tr -d ' ')" = "2" ]
    local mine="${BATS_TEST_TMPDIR}/mine.log"
    [ "$(sed -n 2p "$rec" | sed 's/%9/PANE/')" = "$(sed -n 2p "$mine" | sed "s/$(pane_of)/PANE/")" ]
    [ "$(sed -n 1p "$rec" | sed 's/%9/PANE/')" = "-t PANE hello there" ]
    [ "$(sed -n 1p "$mine" | sed "s/$(pane_of)/PANE/")" = "-l -t PANE hello there" ]
}

@test "line: blocking screens send nothing and defer or notify" {
    local name want
    for name in permission limit limit_auto_continue trust_folder queued_composer; do
        launch_fake "s_$name" "FAKE_SCREEN=$FXP/$name.txt"
        bind "$SID" "s_$name"
        register "$SID" "$(panepid_of "s_$name")"
        run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
        [ "$status" -ne 0 ] || { echo "$name injected"; return 1; }
        case "$name" in
            queued_composer) want="defer pane_busy" ;;
            *) want="defer pane_dialog" ;;
        esac
        [ "$output" = "$want" ] || { echo "$name: $output (want $want)"; return 1; }
        bind "" "s_$name"
        tmux -L "$SOCK" kill-session -t "s_$name"
    done
    for name in askuser plan resume_size draft unknown; do
        launch_fake "s_$name" "FAKE_SCREEN=$FXI/$name.txt"
        bind "$SID" "s_$name"
        register "$SID" "$(panepid_of "s_$name")"
        run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
        [ "$status" -ne 0 ] || { echo "$name injected"; return 1; }
        case "$name" in
            draft) want="defer pane_draft" ;;
            unknown) want="defer pane_unknown" ;;
            *) want="defer pane_dialog" ;;
        esac
        [ "$output" = "$want" ] || { echo "$name: $output (want $want)"; return 1; }
        tmux -L "$SOCK" kill-session -t "s_$name"
    done
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: a draft already in the composer is never typed over or cleared" {
    launch_fake t FAKE_BUF="half typed note"
    bind "$SID"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *draft* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: a recent client_activity defers and sends nothing" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    export BORG_RESUME_NOW_EPOCH=1000000
    export BORG_RESUME_CLIENTS_CMD="printf '999990\n'"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *human_active* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: unbound session defers and sends nothing, a reused pane id bound elsewhere is untouched" {
    launch_fake t
    bind "99999999-0000-0000-0000-000000000000"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *no_pane* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: ambiguous binding defers" {
    launch_fake t
    tmux -L "$SOCK" split-window -t t -d env "${BATS_TEST_TMPDIR}/bin/claude"
    local p
    for p in $(tmux -L "$SOCK" list-panes -t t -F '#{pane_id}'); do bind "$SID" "$p"; done
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *ambiguous* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: failed ownership defers or notifies and sends nothing" {
    launch_fake t
    bind "$SID"
    jq -n --arg sid "$SID" '{session_id:$sid,in_container:false,claude_pid:999999,claude_start:"x"}' \
        >"${BORG_RESUME_DIR}/sessions/${SID}.json"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -ne 0 ]
    [[ "$output" == *ownership* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: a container session is notify-only and nothing is sent" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)" true
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 11 ]
    [[ "$output" == notify* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: the DISABLED sentinel defers, BORG_RESUME_DISABLE=1 notifies nothing and sends nothing" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    : >"${BORG_RESUME_DIR}/DISABLED"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *paused* ]]
    rm -f "${BORG_RESUME_DIR}/DISABLED"
    BORG_RESUME_DISABLE=1 run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -ne 0 ]
    [[ "$output" == *disabled* ]]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: text that fails verification is cleared and deferred, never submitted" {
    launch_fake t FAKE_NOECHO=1
    bind "$SID"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [[ "$output" == *verify* ]]
    ! keylog | grep -q SUBMIT
}

@test "line: a human who types extra text before the check makes verification fail, text is cleared" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    local hook="${BATS_TEST_TMPDIR}/sk"
    printf '#!/bin/bash\ntmux -L %s send-keys "$@"\nr=$?\n' "$SOCK" >"$hook"
    printf 'case "$*" in *-l*) tmux -L %s send-keys -l -t %s " intruder";; esac\nexit $r\n' \
        "$SOCK" "$(pane_of)" >>"$hook"
    chmod +x "$hook"
    export BORG_RESUME_SENDKEYS_CMD="$hook"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    ! keylog | grep -q SUBMIT
    keylog | grep -qxF "$(printf '%q' $'\025')"
    run bash -c ". '$LIB'; borg_inject_pane_state '$(pane_of)'"
    [ "$output" = "idle_empty" ]
}

@test "line: a rejected control character in the text is refused before anything is sent" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' \$'two\nlines'"
    [ "$status" -ne 0 ]
    run bash -c ". '$LIB'; borg_inject_line '$SID' ''"
    [ "$status" -ne 0 ]
    [ ! -s "$FAKE_KEYLOG" ]
}

# ---- installed layout ----

@test "sourcing from an installed layout with a minimal PATH works" {
    local inst="${BATS_TEST_TMPDIR}/inst/lib/borg"
    mkdir -p "$inst"
    cp "$LIB" "${inst}/inject.sh"
    cp "${BATS_TEST_DIRNAME}/../lib/borg/resume-paths.sh" "${inst}/resume-paths.sh"
    run env -i HOME="$HOME" PATH="/usr/bin:/bin" BORG_RESUME_DIR="$BORG_RESUME_DIR" \
        /bin/bash -c ". '${inst}/inject.sh'; type borg_inject_line >/dev/null \
        && borg_inject_classify_text < '$FXI/idle.txt'"
    [ "$status" -eq 0 ]
    [ "$output" = "idle_empty" ]
}

# ---- review fixes: pane mode proof, wrapped verification, clear-after-failure ----

@test "line: a pane left in copy-mode defers and sends nothing" {
    launch_fake t
    bind "$SID"
    register "$SID" "$(panepid_of)"
    tmux -L "$SOCK" copy-mode -t t
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [ "$output" = "defer pane_in_mode" ]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "pane_ok: a missing pane is pane_gone, a healthy pane passes" {
    launch_fake t
    run bash -c ". '$LIB'; _bi_pane_ok '%999'"
    [ "$status" -ne 0 ]
    [ "$output" = "pane_gone" ]
    run bash -c ". '$LIB'; _bi_pane_ok '$(pane_of)'"
    [ "$status" -eq 0 ]
}

@test "line: synchronize-panes on defers and sends nothing" {
    launch_fake t
    local first
    first="$(pane_of)"
    tmux -L "$SOCK" split-window -t t -d sleep 60
    tmux -L "$SOCK" set-option -w -t t synchronize-panes on
    bind "$SID" "$first"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [ "$output" = "defer pane_synchronized" ]
    [ ! -s "$FAKE_KEYLOG" ]
}

@test "line: the real S6 line injects in a narrow pane where the long path wraps" {
    local w line
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume-with-a-fairly-long-state-directory-name/state"
    mkdir -p "${BORG_RESUME_DIR}/sessions"
    line="$(bash -c ". '${BATS_TEST_DIRNAME}/../lib/borg/resume-prompt.sh'; _rp_line r_7f3a2c usage_limit")"
    [ "${#line}" -gt 150 ]
    for w in 60 70 80; do
        LAUNCH_W=$w launch_fake "n$w"
        bind "$SID" "n$w"
        register "$SID" "$(panepid_of "n$w")"
        run bash -c ". '$LIB'; borg_inject_line '$SID' '$line'"
        [ "$status" -eq 0 ] || { echo "width $w: $output"; return 1; }
        keylog | grep -qF "SUBMIT [borg-resume r_7f3a2c]" || { echo "width $w: no submit"; return 1; }
        bind "" "n$w"
        tmux -L "$SOCK" kill-session -t "n$w"
        : >"$FAKE_KEYLOG"
    done
}

@test "line: verification failure always sends Ctrl+U, even when the composer still reads empty" {
    launch_fake t FAKE_NOECHO=1
    bind "$SID"
    register "$SID" "$(panepid_of)"
    run bash -c ". '$LIB'; borg_inject_line '$SID' 'hello'"
    [ "$status" -eq 10 ]
    [ "$output" = "defer verify_failed" ]
    keylog | grep -qxF "$(printf '%q' $'\025')"
    run grep -c SUBMIT "$FAKE_KEYLOG"
    [ "$output" = "0" ]
}

@test "human_active: a failing list-clients is treated as active (fails closed)" {
    printf '#!/bin/bash\nexit 1\n' >"${BATS_TEST_TMPDIR}/failtmux"
    chmod +x "${BATS_TEST_TMPDIR}/failtmux"
    unset BORG_RESUME_CLIENTS_CMD
    export BORG_RESUME_TMUX_CMD="${BATS_TEST_TMPDIR}/failtmux"
    run bash -c ". '$LIB'; borg_inject_human_active"
    [ "$status" -eq 0 ]
}

@test "bind_container: an existing binding to another session is never overwritten" {
    launch_fake t
    tmux -L "$SOCK" set-option -w -t t @project_dir /work/proj
    bind "99999999-0000-0000-0000-000000000000"
    run bash -c ". '$LIB'; borg_inject_bind_container '$SID' /work/proj"
    [ "$status" -ne 0 ]
    run tmux -L "$SOCK" show-options -p -v -t t @borg_sid
    [ "$output" = "99999999-0000-0000-0000-000000000000" ]
}
