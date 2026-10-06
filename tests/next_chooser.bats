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
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
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

_last_row() {
    tail -n 1 "${XDG_STATE_HOME}/borg/next-recs.jsonl"
}

@test "next --pick 1: switches to the top row and logs a scripted chooser row" {
    _write_registry ""
    run zsh "$BORG" next --pick 1
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-old" ]
    _last_row | jq -e '.chooser == true and .scripted == true and .switch == false and .shown == false
        and .rec == "wait-old" and .opened == "wait-old" and .opened_after_s == 0
        and (.top3 | length) == 3 and (.ts | type) == "string" and has("session") and has("active")'
}

@test "next --pick 2: opens the second ranked row, rec stays the top" {
    _write_registry ""
    run zsh "$BORG" next --pick 2
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-new" ]
    _last_row | jq -e '.rec == "wait-old" and .opened == "wait-new"'
}

@test "next --pick 99: out of range dies non-zero and switches nothing" {
    _write_registry ""
    run zsh "$BORG" next --pick 99
    [ "$status" -ne 0 ]
    [[ "$output" == *"out of range"* ]]
    [ -z "$(_selected)" ]
}

@test "next --pick without a number dies non-zero" {
    _write_registry ""
    run zsh "$BORG" next --pick
    [ "$status" -ne 0 ]
}

@test "next --switch: logs one chooser:false row with null rec and opened" {
    _write_registry ""
    run zsh "$BORG" next --switch
    [ "$status" -eq 0 ]
    _last_row | jq -e '.chooser == false and .scripted == false and .switch == true and .shown == false
        and .rec == null and .opened == null and .opened_after_s == null and (.top3 | length) == 3'
}

@test "next (non-TTY bare run): prints the recommendation and logs a chooser:false row" {
    _write_registry ""
    run zsh "$BORG" next < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: wait-old"* ]]
    _last_row | jq -e '.chooser == false and .switch == false and .rec == null and .opened == null'
}

@test "next: an unwritable state dir still exits 0 with unchanged stdout" {
    _write_registry ""
    run zsh "$BORG" next < /dev/null
    [ "$status" -eq 0 ]
    local expected="$output"
    : > "${BATS_TEST_TMPDIR}/blocker"
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/blocker"
    run zsh "$BORG" next < /dev/null
    [ "$status" -eq 0 ]
    [ "$output" = "$expected" ]
}
