#!/usr/bin/env bats
# borg_tmux_switch focuses the AGENT pane, not whichever pane has the highest pane_top. Side-by-side panes
# both have pane_top 0, so the old "sort -rn | head -1" tie broke on the pane id string and %4 (cortex) beat
# %3 (claude). Fixture: TMUX_MOCK_PANES holds "pane_top pane_index pane_id pane_current_command" lines.

load test_helper/setup

setup() {
    setup_temp_dirs
    setup_mock_bin
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) exit 0 ;;
    list-panes)
        case "$*" in
            *pane_current_command*) printf "%s\n" "$TMUX_MOCK_PANES" ;;
            *) printf "%s\n" "$TMUX_MOCK_PANES" | awk "{print \$1, \$3}" ;;
        esac ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$MOCK_BIN/tmux"
}

_switch() {
    zsh -c "
        warn() { :; }
        source '$BORG_HOME/lib/tmux.zsh'
        borg_tmux_switch w1
    "
}

_focused() {
    grep "tmux select-pane" "$TRACE" | sed "s/.*-t //"
}

@test "side-by-side claude + cortex focuses the claude pane" {
    export TMUX_MOCK_PANES=$'0 0 %3 claude\n0 1 %4 cortex'
    run _switch
    [ "$status" -eq 0 ]
    [ "$(_focused)" = "%3" ]
}

@test "side-by-side with claude on the higher pane id still focuses claude" {
    export TMUX_MOCK_PANES=$'0 0 %3 cortex\n0 1 %4 claude'
    run _switch
    [ "$(_focused)" = "%4" ]
}

@test "cortex is chosen when no pane runs claude" {
    export TMUX_MOCK_PANES=$'0 0 %3 cortex\n0 1 %4 zsh'
    run _switch
    [ "$(_focused)" = "%3" ]
}

@test "stacked panes with no agent focus the bottom pane" {
    export TMUX_MOCK_PANES=$'0 0 %7 zsh\n30 1 %2 zsh'
    run _switch
    [ "$(_focused)" = "%2" ]
}

@test "a pane_top tie with no agent breaks on the lowest pane_index" {
    export TMUX_MOCK_PANES=$'0 1 %9 zsh\n0 0 %3 zsh'
    run _switch
    [ "$(_focused)" = "%3" ]
}
