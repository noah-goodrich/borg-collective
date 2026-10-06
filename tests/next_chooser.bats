#!/usr/bin/env bats
# CHARACTERISATION of `borg next --switch` against a populated registry. Pins which window
# _borg_do_switch targets BEFORE the chooser work changes cmd_next, so any ordering drift is red.
# Scores (borg.zsh cmd_next jq): pinned +200, waiting +100, active +50, idle +10, null
# last_activity -50, non-empty tmux_window +5; archived excluded; sort_by(-score, last_activity).

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS="w-old w-new w-idle w-act w-pin"
    unset BORG_WORK_PROJECTS
    _mock_tmux
}

# Same shared mock as tests/cli_contract.bats (logs every call to $TRACE).
_mock_tmux() {
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session)
        [ "${TMUX_MOCK_HAS_SESSION:-0}" = "1" ] && exit 0 || exit 1 ;;
    list-windows)
        printf '%s\n' $TMUX_MOCK_WINDOWS ;;
    list-panes)
        echo "0 %1" ;;
    display-message)
        echo "mock-window" ;;
    *)
        exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"
}

_selected() {
    grep "tmux select-window" "$TRACE" | sed 's/.*-t borg://'
}

_write_registry() {
    local extra="$1"
    cat > "$BORG_REGISTRY" <<JSON
{"projects": {
  "wait-new": {"path":null,"status":"waiting","tmux_window":"w-new","last_activity":"2026-10-04T10:00:00Z"},
  "wait-old": {"path":null,"status":"waiting","tmux_window":"w-old","last_activity":"2026-09-01T10:00:00Z"},
  "act":      {"path":null,"status":"active","tmux_window":"w-act","last_activity":"2026-10-05T10:00:00Z"},
  "idle":     {"path":null,"status":"idle","tmux_window":"w-idle","last_activity":"2026-10-05T11:00:00Z"},
  "never":    {"path":null,"status":"idle"},
  "arch-pin": {"path":null,"status":"archived","pinned":true,"tmux_window":"w-pin","last_activity":"2026-10-05T12:00:00Z"}
  $extra
}}
JSON
}

@test "next --switch: tied top scores go to the OLDEST last_activity; archived pin is excluded" {
    _write_registry ""
    run zsh "$BORG" next --switch
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-old" ]
}

@test "next --switch: a pinned project outranks a waiting tie" {
    _write_registry ', "pinned-idle": {"path":null,"status":"idle","pinned":true,"tmux_window":"w-pin","last_activity":"2026-08-01T10:00:00Z"}'
    run zsh "$BORG" next --switch
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-pin" ]
}
