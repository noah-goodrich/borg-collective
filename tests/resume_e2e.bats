#!/usr/bin/env bats
# End-to-end flows for borg-resume (slice S16): hook -> watcher -> gate -> inject/relaunch -> confirm -> done.
# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (S16, Test strategy).
#
# What is real: the INSTALLED layout (bin/borg-resume + lib/borg/*.sh + the hook copied into a sandbox HOME/.claude by
# borg_resume_install_lib, nothing resolved through the repo checkout), a PRIVATE tmux server (tmux -L <unique socket>,
# killed in teardown, never the user's server), real send-keys / capture-pane / pane options, and the captured
# stop_failure payload and main_rate_limit transcript fixtures. What is stubbed: the claude binary (a bash script that
# draws a composer, plays the SessionStart hook, logs argv and keys, and appends a user record when it gets a
# submit), the usage probe and the notifier. No real claude, docker, launchd, osascript, ~/.claude or state dir.
# Clock pinned with BORG_RESUME_NOW_EPOCH (the stub claude reads the same clock from a file).

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    FXR="${BATS_TEST_DIRNAME}/fixtures/resume"
    command -v tmux >/dev/null || skip "tmux not installed"
    command -v jq >/dev/null || skip "jq not installed"
    SB="${BATS_TEST_TMPDIR}"
    SOCK="borge2e${BASHPID}x${RANDOM}"
    export HOME="$SB/home"
    export XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config"
    unset TMUX TMUX_PANE BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_WATCH BORG_RESUME_LIBDIR
    unset BORG_RESUME_MAX_ACTIVE BORG_RESUME_MAX_CONSECUTIVE BORG_RESUME_MAX_RELAUNCH_PER_HOUR BORG_RESUME_PANES_CMD
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    mkdir -p "$HOME/.claude/bin" "$HOME/.claude/hooks" "$SB/bin" "$SB/work/proj"

    # The installed layout: exactly what `borg setup` puts under ~/.claude.
    cp "$ROOT/bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    cp "$ROOT/hooks/borg-resume-hook.sh" "$HOME/.claude/hooks/borg-resume-hook.sh"
    chmod +x "$HOME/.claude/bin/borg-resume" "$HOME/.claude/hooks/borg-resume-hook.sh"
    bash -c ". '$ROOT/lib/resume-install.sh' && borg_resume_install_lib '$ROOT/lib/borg' '$HOME/.claude/lib/borg'" \
        >/dev/null
    IBIN="$HOME/.claude/bin/borg-resume"
    IHOOK="$HOME/.claude/hooks/borg-resume-hook.sh"

    T0=1791806400
    NOWFILE="$SB/now"
    at "$T0"
    export BORG_RESUME_DIR="$SB/resume"
    export BORG_RESUME_PROJECTS_DIR="$SB/projects"
    export BORG_IN_CONTAINER=0
    export BORG_RESUME_TMUX_CMD="tmux -L ${SOCK}"
    export BORG_RESUME_PANE_CMD_RE='^bash$'
    export BORG_RESUME_SEND_DELAY=0.1
    export BORG_RESUME_BOOT_EPOCH=$((T0 - 86400 * 30))
    export BORG_RESUME_RELAUNCH_TRIES=30 BORG_RESUME_RELAUNCH_POLL_SEC=1
    export BORG_RESUME_LOGIN_SHELL=/bin/bash
    export BORG_RESUME_CWD_ALLOW="$SB/work"
    export BORG_CLAUDE_BIN="$SB/bin/claude"
    export FAKE_KEYLOG="$SB/keys.log" FAKE_ARGVLOG="$SB/argv.log" FAKE_NOWFILE="$NOWFILE"
    export FAKE_SCREENFILE="$SB/screen.txt"
    : >"$FAKE_KEYLOG"
    : >"$FAKE_ARGVLOG"
    SKLOG="$SB/sendkeys.log"
    NLOG="$SB/notify.log"
    : >"$SKLOG"
    : >"$NLOG"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"%s"\nexec tmux -L %s send-keys "$@"\n' "$SKLOG" "$SOCK" >"$SB/bin/sk"
    printf '#!/bin/bash\necho "Current session: 40%% used"\n' >"$SB/bin/usage"
    printf '#!/bin/bash\nprintf "%%s|%%s|%%s\\n" "$1" "$2" "$3" >>"%s"\n' "$NLOG" >"$SB/bin/notify"
    chmod +x "$SB/bin/sk" "$SB/bin/usage" "$SB/bin/notify"
    export BORG_RESUME_SENDKEYS_CMD="$SB/bin/sk"
    export BORG_RESUME_USAGE_CMD="$SB/bin/usage"
    export BORG_RESUME_NOTIFY_CMD="$SB/bin/notify"
    _write_fake_claude

    SID="00000000-0000-4000-8000-0000000000aa"
    export FAKE_SID="$SID"
    RD="$BORG_RESUME_DIR"
    PD="$BORG_RESUME_PROJECTS_DIR/-proj"
    SD="$PD/$SID"
    CWD="$SB/work/proj"
    mkdir -p "$PD" "$RD"
    # The private server is started AFTER every export above: panes inherit this environment, which is how the stub
    # claude and the hook it runs find the sandbox. A keeper session holds the server open.
    tmux -L "$SOCK" -f /dev/null new-session -d -s keeper -x 160 -y 50 -c "$CWD" sleep 3600
}

teardown() {
    [ -n "${SOCK:-}" ] && tmux -L "$SOCK" kill-server 2>/dev/null || true
}

at() { # <epoch> : move the pinned clock (watcher and stub claude)
    export BORG_RESUME_NOW_EPOCH="$1"
    printf '%s' "$1" >"$NOWFILE"
}

# The stub claude. argv logged; --resume <sid> picks the session; plays SessionStart through the INSTALLED hook (so the
# registry and the @borg_sid binding come from real code); then a composer (or FAKE_SCREENFILE) and a key logger. A
# submit appends a user record carrying the typed text to the session transcript, as the real thing does.
_write_fake_claude() {
    cat >"$SB/bin/claude" <<'FAKE'
#!/bin/bash
printf 'ARGV %s\n' "$*" >>"$FAKE_ARGVLOG"
sid="${FAKE_SID:-}"
src=startup
while [ $# -gt 0 ]; do
    case "$1" in
        --resume) sid="$2"; src=resume; shift ;;
    esac
    shift
done
printf 'SID %s\n' "$sid" >>"$FAKE_ARGVLOG"
tp="$BORG_RESUME_PROJECTS_DIR/-proj/$sid.jsonl"
now="$(cat "$FAKE_NOWFILE")"
jq -n -c --arg s "$sid" --arg c "$PWD" --arg t "$tp" --arg src "$src" \
    '{session_id:$s, cwd:$c, transcript_path:$t, hook_event_name:"SessionStart", source:$src}' |
    BORG_RESUME_NOW_EPOCH="$now" "$HOME/.claude/hooks/borg-resume-hook.sh" SessionStart
RULE="$(printf '%.0s─' $(seq 1 60))"
buf=""
draw() {
    printf '\033[2J\033[H'
    if [ -f "$FAKE_SCREENFILE" ]; then
        cat "$FAKE_SCREENFILE"
    else
        printf 'earlier output\n\n%s\n❯ %s\n%s\n  ? for shortcuts\n' "$RULE" "$buf" "$RULE"
    fi
}
stty -echo -icanon min 1 2>/dev/null
draw
shown=""
[ -f "$FAKE_SCREENFILE" ] && shown=1
while true; do
    if IFS= read -rsn1 -t 1 ch; then
        printf '%q\n' "$ch" >>"$FAKE_KEYLOG"
        case "$ch" in
            $'\r' | "")
                printf 'SUBMIT %s\n' "$buf" >>"$FAKE_KEYLOG"
                jq -n -c --arg t "$buf" --arg s "$sid" \
                    '{type:"user", uuid:("sub-" + $s), message:{role:"user", content:$t}}' >>"$tp"
                buf=""
                ;;
            $'\025') buf="" ;;
            *) buf="${buf}${ch}" ;;
        esac
        [ -f "$FAKE_SCREENFILE" ] || draw
    else
        # bash 3.2 reports a read timeout as status 1, so every failure is treated as an idle tick (the pane's
        # SIGHUP ends the loop when tmux goes away). A screen file that appears later (after the relaunch is verified) is drawn on the next idle tick.
        if [ -z "$shown" ] && [ -f "$FAKE_SCREENFILE" ]; then
            draw
            shown=1
        fi
    fi
done
FAKE
    chmod +x "$SB/bin/claude"
}

# ---- builders ---------------------------------------------------------------------------------------------------
# Start the stub claude as a live session in its own tmux session and wait until the hook has bound the pane.
start_live() { # [session-name]
    local _s="${1:-live}" _i=0
    tmux -L "$SOCK" new-session -d -s "$_s" -x 160 -y 50 -c "$CWD" "$SB/bin/claude"
    while [ "$_i" -lt 100 ]; do
        [ -f "$RD/sessions/$SID.json" ] &&
            [ -n "$(tmux -L "$SOCK" list-panes -t "$_s" -F '#{@borg_sid}' 2>/dev/null)" ] && return 0
        sleep 0.1
        _i=$((_i + 1))
    done
    echo "stub claude never registered" >&2
    return 1
}

set_mtime() { touch -t "$(date -r "$2" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$2" +%Y%m%d%H%M.%S)" "$1"; }

# The captured rate_limit transcript as the main transcript, plus the captured failed workflow with its errored agent.
mk_transcript() {
    # Timestamps are shifted to the pinned clock (the reset text is parsed relative to the record time); nothing else
    # in the captured skeleton changes.
    jq -c --argjson n "$T0" 'if has("timestamp") then .timestamp = (($n - 300) | todate) else . end' \
        "$FXR/main_rate_limit.jsonl" >"$PD/$SID.jsonl"
    set_mtime "$PD/$SID.jsonl" $((T0 - 300))
    mkdir -p "$SD/workflows" "$SD/subagents/workflows/wf_failed"
    cp "$FXR/workflows/wf_failed.json" "$SD/workflows/wf_failed.json"
    cp "$FXR/workflows/wf_failed.journal.jsonl" "$SD/subagents/workflows/wf_failed/journal.jsonl"
    cp "$FXR/subagents/agent-a0000000000000002.jsonl" "$SD/subagents/workflows/wf_failed/"
    cp "$FXR/subagents/agent-a0000000000000002.meta.json" "$SD/subagents/workflows/wf_failed/"
    set_mtime "$SD/subagents/workflows/wf_failed/agent-a0000000000000002.jsonl" $((T0 - 600))
    # An Agent-tool agent that died on the API error (SYNTHETIC: no captured errored agent transcript exists).
    printf '{"type":"user","isSidechain":true,"cwd":"%s","message":{"role":"user","content":"do the brief"}}\n' "$CWD" \
        >"$SD/subagents/agent-a0000000000000009.jsonl"
    printf '{"type":"assistant","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use",' \
        >>"$SD/subagents/agent-a0000000000000009.jsonl"
    printf '"id":"t1","name":"Bash","input":{}}]}}\n' >>"$SD/subagents/agent-a0000000000000009.jsonl"
    printf '{"type":"assistant","isApiErrorMessage":true,"error":"rate_limit","message":{"role":"assistant",' \
        >>"$SD/subagents/agent-a0000000000000009.jsonl"
    printf '"model":"<synthetic>","content":[{"type":"text","text":"You hit your limit"}]}}\n' \
        >>"$SD/subagents/agent-a0000000000000009.jsonl"
    printf '{"agentType":"general-purpose","description":"d-9"}\n' >"$SD/subagents/agent-a0000000000000009.meta.json"
    set_mtime "$SD/subagents/agent-a0000000000000009.jsonl" $((T0 - 600))
}

# The captured StopFailure payload, with the session id swapped for ours, into the INSTALLED hook.
hook_stop_failure() {
    jq -c --arg s "$SID" --arg cwd "$CWD" --arg tp "$PD/$SID.jsonl" \
        '.session_id = $s | .cwd = $cwd | .transcript_path = $tp' "$FXR/stop_failure_payload.json" |
        "$IHOOK" StopFailure
}

# A session whose claude was SIGKILLed: dead pid, no pane, no hook event of any kind. The registry is what the last
# SessionStart left behind; the transcript ends on a dangling Agent tool_use (killed mid-turn) or on an interrupt
# marker.
# A synthetic-error tail is deliberately not used: the scan owns that scope and liveness adds nothing there.
dead_pid() { sleep 0 & DEADPID=$!; wait "$DEADPID"; }
lstart_of() { LC_ALL=C date -r "$1" '+%a %b %e %T %Y' 2>/dev/null || LC_ALL=C date -d "@$1" '+%a %b %e %T %Y'; }
mk_killed() { # [transcript-tail: tool|interrupt]
    local f="$PD/$SID.jsonl" tail="${1:-tool}"
    dead_pid
    mkdir -p "$RD/sessions"
    jq -n -c --arg sid "$SID" --argjson pid "$DEADPID" --arg st "$(lstart_of $((T0 - 3600)))" --arg cwd "$CWD" \
        '{session_id:$sid, cwd:$cwd, project:"proj", mode:"project", in_container:false, claude_pid:$pid,
          claude_start:$st, tmux:{pane_id:"%99", pane_pid:1, session:"keeper", window:"proj", window_index:1,
          pane_index:0, project_dir:$cwd}}' >"$RD/sessions/$SID.json"
    set_mtime "$RD/sessions/$SID.json" $((T0 - 60))
    mkdir -p "$RD/events"
    printf '{"type":"user","uuid":"u-1","cwd":"%s","message":{"role":"user","content":"hello"}}\n' "$CWD" >"$f"
    printf '{"type":"assistant","uuid":"t-1","message":{"role":"assistant","stop_reason":"tool_use",' >>"$f"
    printf '"content":[{"type":"tool_use","id":"x","name":"Agent","input":{}}]}}\n' >>"$f"
    case "$tail" in
        interrupt) cat "$FXR/interrupt_user.jsonl" >>"$f" ;;
    esac
    set_mtime "$f" $((T0 - 3600))
}

# ---- assertions and drivers -------------------------------------------------------------------------------------
watch() { run "$IBIN" watch --once; [ "$status" -eq 0 ]; }
n_sk() { wc -l <"$SKLOG" | tr -d ' '; }
n_new_windows() { grep -c '^ARGV --resume' "$FAKE_ARGVLOG" || true; }
all_recs() { cat "$RD"/pending/*.json "$RD"/done/*.json 2>/dev/null; }
rq() { all_recs | jq -r -s "$1"; }
the_rid() { rq '.[0].rid'; }
pane_of() { tmux -L "$SOCK" list-panes -t "${1:-live}" -F '#{pane_id}' | head -1; }
MAIN='[.[] | select(.scope == "main")][0]'
WFREC='[.[] | select(.scope | startswith("workflow:"))][0]'
submits() { grep -c '^SUBMIT ' "$FAKE_KEYLOG" || true; }
# The stub logs SUBMIT asynchronously after the Enter: poll (bounded) rather than assert at once.
wait_submits() { # <n>
    local _i=0
    while [ "$_i" -lt 50 ] && [ "$(submits)" != "$1" ]; do
        sleep 0.1
        _i=$((_i + 1))
    done
    [ "$(submits)" = "$1" ]
}

# ---- (a) stop_failure through the hook, the whole way to done ----------------------------------------------------

@test "e2e (a): stop_failure -> watch -> ONE send-keys pair with the exact line -> ack -> confirmed -> done" {
    mk_transcript
    start_live live
    hook_stop_failure
    [ -s "$RD/events/$SID.jsonl" ]
    jq -e -s 'any(.ev == "stop_failure" and .sid == "'"$SID"'")' "$RD/events/$SID.jsonl" >/dev/null
    watch
    # Three records for the one session: main usage limit (hook + scan), the errored agent, the failed workflow.
    [ "$(rq 'length')" = 3 ]
    [ "$(rq "$MAIN | .state")" = scheduled ]
    [ "$(rq "$MAIN | .class")" = usage_limit ]
    [ "$(rq "$MAIN | .detected_by | sort | join(\",\")")" = "hook,scan" ]
    [ "$(rq "$WFREC | .class")" = transient ]
    local ra
    ra="$(rq "$MAIN | .resume_at")"
    # Before reset plus grace: nothing is sent, not even for the workflow record that is due earlier.
    at $((ra - 5))
    watch
    [ "$(n_sk)" = 0 ]
    # Past it: exactly one text/Enter pair into the pane the hook bound to this sid.
    at $((ra + 1))
    watch
    [ "$(n_sk)" = 2 ]
    wait_submits 1
    local line pane rid
    pane="$(pane_of live)"
    line="$(sed -n 's/^SUBMIT //p' "$FAKE_KEYLOG")"
    rid="$(printf '%s' "$line" | sed -n 's/^\[borg-resume \(r_[0-9a-f]*\)\].*/\1/p')"
    [ -n "$rid" ]
    [ "$("$IBIN" prompt "$rid" --line)" = "$line" ]
    sed -n 1p "$SKLOG" | grep -qxF -- "-l -t $pane $line"
    sed -n 2p "$SKLOG" | grep -qxF -- "-t $pane Enter"
    [ "$(tmux -L "$SOCK" show-options -p -v -t "$pane" @borg_sid)" = "$SID" ]
    [ "$(rq '[.[] | select(.state == "injected")] | length')" = 3 ]
    # The prompt file lists the fixture workflow and the errored agent.
    [ -s "$RD/prompts/$rid.md" ]
    grep -q 'wf_fake001' "$RD/prompts/$rid.md"
    grep -q 'a0000000000000009' "$RD/prompts/$rid.md"
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
    [ "$(jq -r .injections_today "$RD/state/$SID.json")" = 1 ]
    # The submitted tag lands in the transcript: confirmed. A further pass sends nothing more.
    at $((ra + 10))
    watch
    [ "$(rq '[.[] | select(.state == "confirmed")] | length')" -ge 1 ]
    [ "$(rq "$MAIN | .state")" = confirmed ]
    [ "$(rq "$MAIN | .confirmed_by")" = tag ]
    [ "$(n_sk)" = 2 ]
    # The model acks: confirmed -> done, and the no-progress counter is reset.
    run "$IBIN" ack "$rid"
    [ "$status" -eq 0 ]
    at $((ra + 20))
    watch
    [ "$(rq "$MAIN | .state")" = done ]
    [ "$(rq "$MAIN | .done_reason")" = ack ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 0 ]
    [ -f "$RD/done/$(rq "$MAIN | .rid").json" ]
    [ "$(n_sk)" = 2 ]
}

@test "e2e (a): measured progress after confirmation ends the record and resets the consecutive counter" {
    mk_transcript
    start_live live
    hook_stop_failure
    watch
    local ra i
    ra="$(rq "$MAIN | .resume_at")"
    at $((ra + 1))
    watch
    at $((ra + 10))
    watch
    [ "$(rq "$MAIN | .state")" = confirmed ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
    for i in $(seq 1 30); do
        jq -n -c --arg u "p-$i" '{type:"assistant", uuid:$u, message:{role:"assistant",
            content:[{type:"text", text:"work"}]}}' >>"$PD/$SID.jsonl"
    done
    at $((ra + 20))
    watch
    [ "$(rq "$MAIN | .state")" = done ]
    [ "$(rq "$MAIN | .done_reason")" = progress ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 0 ]
    [ "$(jq -r .last_progress_lines "$RD/state/$SID.json")" -gt 30 ]
    [ "$(n_sk)" = 2 ]
}

# ---- (b) SIGKILL-style: no hook event, liveness + scan + relaunch -----------------------------------------------

@test "e2e (b): killed process, no hook event: liveness -> relaunch --resume -> gate -> one injection" {
    mk_killed tool
    # Detection pass (no hook event exists), then the due passes after the grace.
    watch
    [ "$(rq 'length')" = 1 ]
    [ "$(rq "$MAIN | .class")" = process_death ]
    [ "$(rq "$MAIN | .detected_by | join(\",\")")" = liveness ]
    [ -z "$(ls "$RD/events" 2>/dev/null)" ]
    at $((T0 + 400))
    watch
    # S11: a NEW window runs the stub claude with --resume <sid>; the stub plays SessionStart through the hook.
    [ "$(n_new_windows)" = 1 ]
    grep -qxF "ARGV --resume $SID" "$FAKE_ARGVLOG"
    [ "$(rq '[.[] | select(.class == "process_death")][0].state')" = relaunching ]
    [ "$(rq "$MAIN | .relaunch.cause")" = pane_closed ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
    [ "$(jq -r .injections_today "$RD/state/$SID.json")" = 1 ]
    [ "$(wc -l <"$RD/relaunch.log" | tr -d ' ')" = 1 ]
    [ "$(n_sk)" = 0 ]
    # The next due pass hands the SAME session to the normal gate flow: one injection, into the relaunched pane.
    at $((T0 + 500))
    watch
    [ "$(n_new_windows)" = 1 ]
    [ "$(wc -l <"$RD/relaunch.log" | tr -d ' ')" = 1 ]
    [ "$(n_sk)" = 2 ]
    wait_submits 1
    local pane
    pane="$(tmux -L "$SOCK" list-panes -a -F '#{pane_id}|#{@borg_sid}' | grep "|$SID\$" | cut -d'|' -f1)"
    [ "$(printf '%s\n' "$pane" | wc -l | tr -d ' ')" = 1 ]
    sed -n 1p "$SKLOG" | grep -qF -- "-l -t $pane [borg-resume r_"
    sed -n 2p "$SKLOG" | grep -qxF -- "-t $pane Enter"
    [ "$(rq "$MAIN | .state")" = injected ]
    # Caps are counted once per action: one tick for the relaunch (above), one for the injection.
    [ "$(jq -r .injections_today "$RD/state/$SID.json")" = 2 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 2 ]
    at $((T0 + 700))
    watch
    [ "$(rq "$MAIN | .state")" = confirmed ]
    # Repeated passes neither relaunch nor inject again.
    at $((T0 + 600))
    watch
    [ "$(n_new_windows)" = 1 ]
    [ "$(n_sk)" = 2 ]
}

# ---- (c) a permission dialog on screen: nothing is typed --------------------------------------------------------

@test "e2e (c): relaunched claude sits in a permission dialog -> nothing is ever typed" {
    mk_killed tool
    watch
    at $((T0 + 400))
    watch
    [ "$(n_new_windows)" = 1 ]
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    # The relaunch is verified (watch returned with the record relaunching) BEFORE the dialog is drawn: the stub
    # only draws the screen file once it exists, so the dialog cannot race the verification.
    [ "$(rq '[.[] | select(.class == "process_death")][0].state')" = relaunching ]
    cp "$FXR/panes/permission.txt" "$FAKE_SCREENFILE"
    local _i=0 _pane
    _pane="$(tmux -L "$SOCK" list-panes -a -F '#{pane_id}|#{@borg_sid}' | grep "|$SID\$" | cut -d'|' -f1)"
    while [ "$_i" -lt 50 ] && tmux -L "$SOCK" capture-pane -p -t "$_pane" | grep -qF '? for shortcuts'; do
        sleep 0.2
        _i=$((_i + 1))
    done
    if tmux -L "$SOCK" capture-pane -p -t "$_pane" | grep -qF '? for shortcuts'; then
        echo "dialog never drawn" >&2
        return 1
    fi
    at $((T0 + 500))
    watch
    [ "$(rq "$MAIN | .state")" = deferred ]
    [ "$(rq "$MAIN | .gate_reason")" = pane_dialog ]
    [ "$(n_sk)" = 0 ]
    # Later passes may retire the record (liveness: the session is alive again); none of them ever types.
    at $((T0 + 900))
    watch
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ "$(n_new_windows)" = 1 ]
}

@test "e2e (c): live session sitting in a permission dialog -> due record is deferred, nothing is sent" {
    cp "$FXR/panes/permission.txt" "$FAKE_SCREENFILE"
    mk_transcript
    start_live live
    hook_stop_failure
    watch
    local ra
    ra="$(rq '.[0].resume_at')"
    at $((ra + 1))
    watch
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ "$(rq '.[0].state')" = deferred ]
    at $((ra + 61))
    watch
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
}

# ---- (d) deliberate stops are never resumed or relaunched -------------------------------------------------------

@test "e2e (d): a trailing interrupt marker on a dead session -> never relaunched, never injected" {
    mk_killed interrupt
    watch
    at $((T0 + 400))
    watch
    at $((T0 + 900))
    watch
    [ "$(n_new_windows)" = 0 ]
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ "$(rq '[.[] | select(.state | IN("relaunching", "injected", "confirmed"))] | length')" = 0 ]
}

@test "e2e (d): mark-closed on a dead session mid-turn -> never relaunched, never injected" {
    mk_killed tool
    run "$IBIN" mark-closed "$SID"
    [ "$status" -eq 0 ]
    watch
    at $((T0 + 400))
    watch
    at $((T0 + 900))
    watch
    [ "$(n_new_windows)" = 0 ]
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ "$(rq '[.[] | select(.state | IN("relaunching", "injected", "confirmed"))] | length')" = 0 ]
}

@test "e2e (d): mark-closed on a LIVE session with a limit error -> nothing is typed" {
    mk_transcript
    start_live live
    hook_stop_failure
    run "$IBIN" mark-closed "$SID"
    [ "$status" -eq 0 ]
    watch
    local ra
    ra="$(rq '.[0].resume_at // empty')"
    at $((T0 + 90000))
    watch
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ -z "$ra" ] || [ "$(rq '[.[] | select(.state | IN("injected", "confirmed"))] | length')" = 0 ]
}

# ---- (e) kill switch ---------------------------------------------------------------------------------------------

@test "e2e (e): the DISABLED sentinel stops injection; unpausing lets the same record through" {
    mk_transcript
    start_live live
    hook_stop_failure
    run "$IBIN" pause
    [ "$status" -eq 0 ]
    [ -e "$RD/DISABLED" ]
    watch
    local ra
    ra="$(rq '.[0].resume_at')"
    at $((ra + 1))
    watch
    at $((ra + 700))
    watch
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    [ "$(rq '.[0].state')" != injected ]
    # Recording continued while paused: the record exists. Unpausing releases it.
    run "$IBIN" unpause
    [ "$status" -eq 0 ]
    at $((ra + 800))
    watch
    [ "$(n_sk)" = 2 ]
    wait_submits 1
}

@test "e2e (e): the DISABLED sentinel also stops a relaunch" {
    mk_killed tool
    run "$IBIN" pause
    [ "$status" -eq 0 ]
    watch
    at $((T0 + 400))
    watch
    at $((T0 + 900))
    watch
    [ "$(n_new_windows)" = 0 ]
    [ "$(n_sk)" = 0 ]
}

@test "e2e (e): BORG_RESUME_DISABLE=1 stops everything, the hook records nothing" {
    mk_transcript
    start_live live
    BORG_RESUME_DISABLE=1 hook_stop_failure
    # Nothing was recorded: no stop_failure event and no record (SessionStart events from the stub are fine).
    if [ -f "$RD/events/$SID.jsonl" ] && grep -q stop_failure "$RD/events/$SID.jsonl"; then
        return 1
    fi
    [ -z "$(ls "$RD/pending" "$RD/done" 2>/dev/null | grep '\.json$')" ]
    # Positive control: the same hook call without the switch DOES record, so the checks above can fail.
    hook_stop_failure
    grep -q stop_failure "$RD/events/$SID.jsonl"
    watch
    [ "$(rq "$MAIN | .state")" != null ]
    local ra
    ra="$(rq "$MAIN | .resume_at")"
    # With the switch, a due record is never injected, however late the pass.
    at $((ra + 1))
    BORG_RESUME_DISABLE=1 run "$IBIN" watch --once
    at $((ra + 90000))
    BORG_RESUME_DISABLE=1 run "$IBIN" watch --once
    [ "$(n_sk)" = 0 ]
    [ "$(submits)" = 0 ]
    # Without it, the same record goes through.
    at $((ra + 90100))
    watch
    [ "$(n_sk)" = 2 ]
}

# ---- the installed layout is what runs --------------------------------------------------------------------------

@test "e2e: the installed layout is self-contained (no repo path in use) and fails loudly when a lib file is missing" {
    [ -f "$HOME/.claude/lib/borg/resume-shared.sh" ]
    [ -f "$HOME/.claude/lib/borg/resume-relaunch.sh" ]
    [ -f "$HOME/.claude/lib/borg/resume-cli.sh" ]
    run "$IBIN" status --json
    [ "$status" -eq 0 ]
    rm -f "$HOME/.claude/lib/borg/resume-paths.sh"
    run bash -c "printf '{\"session_id\":\"$SID\"}' | '$IBIN' record stop_failure"
    [ "$status" -eq 3 ]
}
