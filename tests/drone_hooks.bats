#!/usr/bin/env bats
# Tests for drone's host-side borg-hooks lifecycle (pre-up.sh / post-down.sh).
#
# Covers both:
#  - run_borg_hook unit behavior (strict vs lenient, present/absent/non-executable)
#  - drone.zsh integration: hooks fire around `docker compose up/down` but NOT
#    around the transient down in _cycle_project (restart/rebuild).

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"
LIB="${BATS_TEST_DIRNAME}/../lib/drone-hooks.zsh"

setup() {
    setup_temp_dirs

    export TEST_PROJECT="${BATS_TEST_TMPDIR}/sample"
    mkdir -p "$TEST_PROJECT/.devcontainer/borg-hooks"

    # Trace file for invocation order assertions.
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"

    # Mock bin dir on PATH so drone sees our fake docker/tmux.
    # drone resets PATH on startup; use BORG_DRONE_EXTRA_PATH to inject mocks.
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"
    export BORG_DRONE_EXTRA_PATH="$MOCK_BIN"

    # Fake docker: log all subcommands; 'ps' returns a fake container name so
    # wait_for_container succeeds; 'network inspect' returns 0.
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
case "$1" in
    compose)
        shift
        echo "docker-compose $*" >> "$TRACE"
        case "$*" in
            *" ps "*|*" ps")
                echo "sample-devcontainer-1" ;;
        esac
        exit 0
        ;;
    ps)
        echo "sample-devcontainer-1" ;;
    network)
        exit 0 ;;
    inspect)
        echo '[]' ;;
    exec)
        echo "no" ;;
    images)
        echo "" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    # Fake tmux: swallow everything, return 1 for has-session so drone takes
    # the "create a new session" branch without actually opening tmux.
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) exit 1 ;;
    list-panes|list-windows|display-message|display|show-option)
        echo "" ;;
    new-session|new-window|split-window)
        echo "%0" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    # Fake jq passthrough: real jq is available on the host; bats inherits PATH.
    # Fake borg: swallow borg add calls from drone.
    cat > "$MOCK_BIN/borg" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/borg"

    # Minimal devcontainer files so drone sees a valid project.
    cat > "$TEST_PROJECT/.devcontainer/devcontainer.json" <<'EOF'
{ "name": "sample", "dockerComposeFile": "docker-compose.yml", "service": "devcontainer", "workspaceFolder": "/workspace", "remoteUser": "dev" }
EOF
    cat > "$TEST_PROJECT/.devcontainer/docker-compose.yml" <<'EOF'
services:
  devcontainer:
    image: alpine
    labels:
      - dev.role=app
EOF
}

# Build a borg-hook that writes a tagged line to $TRACE and exits with given code.
_install_hook() {
    local name="$1" rc="${2:-0}"
    cat > "$TEST_PROJECT/.devcontainer/borg-hooks/$name" <<EOF
#!/usr/bin/env bash
echo "hook:$name" >> "$TRACE"
exit $rc
EOF
    chmod +x "$TEST_PROJECT/.devcontainer/borg-hooks/$name"
}

# ─── run_borg_hook unit tests ─────────────────────────────────────────────────

@test "run_borg_hook: absent hook returns 0 silently" {
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample pre-up.sh strict"
    [ "$status" -eq 0 ]
}

@test "run_borg_hook: present hook runs and returns 0 on success" {
    _install_hook pre-up.sh 0
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample pre-up.sh strict"
    [ "$status" -eq 0 ]
    grep -q 'hook:pre-up.sh' "$TRACE"
}

@test "run_borg_hook: strict mode propagates non-zero exit" {
    _install_hook pre-up.sh 7
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample pre-up.sh strict"
    [ "$status" -eq 7 ]
    [[ "$output" == *"aborting"* ]]
}

@test "run_borg_hook: lenient mode swallows non-zero exit" {
    _install_hook post-down.sh 5
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample post-down.sh lenient"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
    [[ "$output" == *"continuing"* ]]
}

@test "run_borg_hook: non-executable hook is skipped with warning" {
    cat > "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    # deliberately no chmod +x
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample pre-up.sh strict"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not executable"* ]]
}

@test "run_borg_hook: passes BORG_PROJECT_NAME to hook" {
    cat > "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" <<'EOF'
#!/usr/bin/env bash
echo "name=$BORG_PROJECT_NAME" >> "$TRACE"
exit 0
EOF
    chmod +x "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh"
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' myproj pre-up.sh strict"
    [ "$status" -eq 0 ]
    grep -q 'name=myproj' "$TRACE"
}

@test "run_borg_hook: cds to project dir before running hook" {
    cat > "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" <<'EOF'
#!/usr/bin/env bash
echo "pwd=$PWD" >> "$TRACE"
exit 0
EOF
    chmod +x "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh"
    run zsh -c "source '$LIB'; run_borg_hook '$TEST_PROJECT' sample pre-up.sh strict"
    [ "$status" -eq 0 ]
    grep -q "pwd=$TEST_PROJECT" "$TRACE"
}

# ─── drone.zsh integration ────────────────────────────────────────────────────
# These assert that drone wires run_borg_hook in at the correct lifecycle
# points. They stub docker+tmux via PATH, run drone commands, and check the
# TRACE log for invocation order.

@test "drone up: pre-up.sh fires BEFORE project's docker compose up" {
    _install_hook pre-up.sh 0
    run "$DRONE" up "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    # ensure_postgres runs its own compose up before the project; filter to
    # the project's compose call only (contains "-p sampleproj").
    local hook_line up_line
    hook_line=$(grep -n 'hook:pre-up.sh' "$TRACE" | head -1 | cut -d: -f1)
    up_line=$(grep -n 'docker-compose -p sample .*up' "$TRACE" | head -1 | cut -d: -f1)
    [ -n "$hook_line" ] && [ -n "$up_line" ] && [ "$hook_line" -lt "$up_line" ]
}

@test "drone up: pre-up.sh non-zero exit aborts (project compose never runs)" {
    _install_hook pre-up.sh 1
    run "$DRONE" up "$TEST_PROJECT"
    [ "$status" -ne 0 ]
    # ensure_postgres may still run, but the project's compose must not.
    ! grep -q 'docker-compose -p sample .*up' "$TRACE"
}

@test "drone up: no borg-hooks dir — succeeds silently with no hook output" {
    # Remove the hooks dir entirely
    rm -rf "$TEST_PROJECT/.devcontainer/borg-hooks"
    run "$DRONE" up "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    ! grep -q 'Running borg-hook' <<< "$output"
    ! grep -q 'hook:' "$TRACE"
}

@test "drone down: post-down.sh fires AFTER docker compose down" {
    _install_hook post-down.sh 0
    run "$DRONE" down "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    local down_line hook_line
    down_line=$(grep -n 'docker-compose.*down' "$TRACE" | head -1 | cut -d: -f1)
    hook_line=$(grep -n 'hook:post-down.sh' "$TRACE" | head -1 | cut -d: -f1)
    [ -n "$down_line" ] && [ -n "$hook_line" ] && [ "$down_line" -lt "$hook_line" ]
}

@test "drone down: post-down.sh non-zero exit does NOT fail drone down" {
    _install_hook post-down.sh 13
    run "$DRONE" down "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"post-down.sh"* ]]
}

@test "drone restart: pre-up fires, post-down does NOT fire (transient cycle)" {
    _install_hook pre-up.sh 0
    _install_hook post-down.sh 0
    # restart requires a running container. Since our mock docker 'ps' returns
    # a name, drone should walk the _cycle_project path.
    run "$DRONE" restart "$TEST_PROJECT"
    # Count hook invocations across the cycle.
    local pre_count post_count
    pre_count=$(grep -c 'hook:pre-up.sh' "$TRACE" || true)
    post_count=$(grep -c 'hook:post-down.sh' "$TRACE" || true)
    [ "$pre_count" = "1" ]
    [ "$post_count" = "0" ]
}
