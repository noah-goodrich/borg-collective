#!/usr/bin/env bats
# Tests for drone's window-name abbreviation layer: the map's invariants (_drone_wname_selftest),
# the project <-> window round trip, and that cmd_claude / cmd_cortex hand get_left_pane the WINDOW
# name. An unanchored or empty tmux target silently resolves to the focused pane, so a long name
# passed for a mapped project sends keystrokes to whatever window the user is looking at.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export BORG_TMUX_SESSION="drsess"
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/dev"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT/borg-collective"

    # Mock tmux: only the abbreviated window "borg" exists; the long name does not. Targets are
    # logged so a test can assert which window name a pane lookup was aimed at.
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    list-windows) echo "borg" ;;
    list-panes)
        case "$*" in
            *"drsess:borg "*|*"drsess:borg") echo "0 %7" ;;
        esac ;;
    display-message) echo "zsh" ;;
esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux"
    export TMUX="/tmp/tmux-1000/default,1234,0"
}

# Run a snippet in a zsh that has loaded drone.zsh's functions (dispatching `help` is a no-op).
_in_drone() {
    zsh -c "source '$DRONE' help >/dev/null 2>&1; $1" < /dev/null
}

@test "_drone_wname_selftest: the shipped abbreviation map is injective" {
    run _in_drone '_drone_wname_selftest'
    [ "$status" -eq 0 ]
}

@test "_drone_wname_selftest: a duplicate abbreviation is reported and fails" {
    run _in_drone 'DRONE_WNAME_ABBREV[zzz-one]=dup; DRONE_WNAME_ABBREV[zzz-two]=dup; _drone_wname_selftest'
    [ "$status" -ne 0 ]
    [[ "$output" == *"'dup' maps from both"* ]]
}

@test "abbreviate then un-abbreviate round-trips every mapped project" {
    run _in_drone 'bad=0
        for k in ${(ok)DRONE_WNAME_ABBREV}; do
            w="$(_drone_wname "$k")"
            [[ "$w" == "${DRONE_WNAME_ABBREV[$k]}" ]] || { print "wname $k -> $w"; bad=1; }
            [[ "$(_drone_unabbrev "$w")" == "$k" ]] || { print "unabbrev $w -> $(_drone_unabbrev "$w") not $k"; bad=1; }
        done
        (( bad == 0 ))'
    [ "$status" -eq 0 ]
}

@test "drone claude aims get_left_pane at the window name, not the project name" {
    run "$DRONE" claude borg-collective
    [ "$status" -eq 0 ]
    grep -q '^tmux list-panes -t drsess:borg ' "$TRACE"
    ! grep -q 'drsess:borg-collective' "$TRACE"
}

@test "drone cortex aims get_left_pane at the window name, not the project name" {
    run "$DRONE" cortex borg-collective
    [ "$status" -eq 0 ]
    grep -q '^tmux list-panes -t drsess:borg ' "$TRACE"
    ! grep -q 'drsess:borg-collective' "$TRACE"
}
