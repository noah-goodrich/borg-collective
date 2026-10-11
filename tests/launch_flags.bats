#!/usr/bin/env bats
# Every borg-owned interactive Claude launch must pass --model/--effort, defaulting to opus/xhigh and
# overridable via BORG_CLAUDE_MODEL / BORG_CLAUDE_EFFORT. Headless `claude -p` calls are out of scope.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"
DRONE_SRC="${BATS_TEST_DIRNAME}/../drone.zsh"
BORG_SRC="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    export ARGS_LOG="${BATS_TEST_TMPDIR}/claude-args.log"
    cat > "$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARGS_LOG"
MOCK
    chmod +x "$MOCK_BIN/claude"
    export BORG_ORCHESTRATOR_ROOT="$BATS_TEST_TMPDIR"
    export TMUX=fake
    export BORG_PATH_PREFIX="$MOCK_BIN"
    unset BORG_CLAUDE_MODEL BORG_CLAUDE_EFFORT
}

@test "borg claude: defaults to --model opus --effort xhigh" {
    run zsh "$BORG_CMD" claude
    grep -qx -- '--model opus --effort xhigh --continue' "$ARGS_LOG"
}

@test "borg claude: BORG_CLAUDE_MODEL / BORG_CLAUDE_EFFORT override" {
    BORG_CLAUDE_MODEL=sonnet BORG_CLAUDE_EFFORT=high run zsh "$BORG_CMD" claude
    grep -qx -- '--model sonnet --effort high --continue' "$ARGS_LOG"
}

@test "borg init: launch line carries the model/effort flags with overrides" {
    run grep -nE '_borg_launch_in_tmux "\$prompt_file" claude --model "\$\{BORG_CLAUDE_MODEL:-opus\}" --effort "\$\{BORG_CLAUDE_EFFORT:-xhigh\}" ' "$BORG_SRC"
    [ "$status" -eq 0 ]
}

@test "drone: every interactive claude launch (4 sites) carries the flags" {
    run grep -cE '"claude --model \$\{BORG_CLAUDE_MODEL:-opus\} --effort \$\{BORG_CLAUDE_EFFORT:-xhigh\}"' "$DRONE_SRC"
    [ "$output" -eq 4 ]
}

@test "drone: no bare claude launch remains" {
    run grep -nE '(create_2pane_window "[^"]*"|send-keys -t "[^"]*") "claude"' "$DRONE_SRC"
    [ "$status" -ne 0 ]
}

@test "drone: launch string expands defaults and overrides" {
    local line='"claude --model ${BORG_CLAUDE_MODEL:-opus} --effort ${BORG_CLAUDE_EFFORT:-xhigh}"'
    run zsh -c "unset BORG_CLAUDE_MODEL BORG_CLAUDE_EFFORT; print -r -- $line"
    [ "$output" = "claude --model opus --effort xhigh" ]
    run zsh -c "BORG_CLAUDE_MODEL=sonnet BORG_CLAUDE_EFFORT=high; print -r -- $line"
    [ "$output" = "claude --model sonnet --effort high" ]
}
