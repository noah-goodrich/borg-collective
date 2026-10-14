#!/usr/bin/env bats
# borg-notifyd check(): a repository with an EMPTY tmux_window must still fire its container-origin
# "waiting" notification. The registry line used to be tab-joined; a tab is IFS whitespace, so the empty
# window collapsed and notify_origin slid into `window`, leaving origin empty and the notification silent.

load test_helper/setup

setup() {
    setup_temp_dirs
    export NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    : > "$NOTIFY_LOG"
}

# Run a zsh snippet with check() loaded and _borg_osa_notify stubbed to append to $NOTIFY_LOG.
_run_check() {
    run zsh -c '
        export BORG_NOTIFYD_LIB_ONLY=1
        source "$1/bin/borg-notifyd"
        _borg_osa_notify() { print -r -- "$*" >> "$NOTIFY_LOG" }
        '"$1"'
        true
    ' _ "$BORG_HOME"
}

@test "notifyd: empty tmux_window + container origin + transition to waiting fires exactly once" {
    printf '{"projects":{"nowin":{"status":"idle","notify_origin":"container"}}}\n' > "$BORG_REGISTRY"
    _run_check 'check silent
        printf "{\"projects\":{\"nowin\":{\"status\":\"waiting\",\"notify_origin\":\"container\"}}}\n" > "$BORG_REGISTRY"
        check
        check'
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$NOTIFY_LOG" | tr -d ' ')" = "1" ]
    grep -q 'Claude Code nowin Ready for input' "$NOTIFY_LOG"
}

@test "notifyd: a populated tmux_window still fires with the window in the subtitle" {
    printf '{"projects":{"p":{"status":"idle","tmux_window":"w","notify_origin":"container"}}}\n' > "$BORG_REGISTRY"
    _run_check 'check silent
        printf "{\"projects\":{\"p\":{\"status\":\"waiting\",\"tmux_window\":\"w\",\"notify_origin\":\"container\"}}}\n" > "$BORG_REGISTRY"
        check'
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$NOTIFY_LOG" | tr -d ' ')" = "1" ]
    grep -q 'Claude Code w — p Ready for input' "$NOTIFY_LOG"
}

@test "notifyd: host-origin waiting never fires" {
    printf '{"projects":{"h":{"status":"idle","notify_origin":"host"}}}\n' > "$BORG_REGISTRY"
    _run_check 'check silent
        printf "{\"projects\":{\"h\":{\"status\":\"waiting\",\"notify_origin\":\"host\"}}}\n" > "$BORG_REGISTRY"
        check'
    [ "$status" -eq 0 ]
    [ ! -s "$NOTIFY_LOG" ]
}
