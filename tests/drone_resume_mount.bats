#!/usr/bin/env bats
# S3 (borg-resume): the host resume ledger is bind-mounted into drone containers, and
# `drone up <project> --resume <sid>` relaunches claude with --resume. Project names are invented.
# No container is started: docker and tmux are stubs that log to $TRACE.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"
ROOT="${BATS_TEST_DIRNAME}/.."
SID="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e5f"
MOUNT_TARGET="/home/dev/.local/state/borg/resume"

setup() {
    setup_temp_dirs
    setup_mock_bin

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    export WINDOWS="${BATS_TEST_TMPDIR}/windows"
    : > "$TRACE"
    : > "$WINDOWS"
    export BORG_TMUX_SESSION="rtest"
    export TMUX="/tmp/tmux-1000/default,1234,0"
    unset TMUX_PANE
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/ledger/resume"

    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
name_of() { while [[ $# -gt 0 ]]; do [[ "$1" == "-n" ]] && { echo "$2"; return; }; shift; done; }
case "$1" in
    has-session) [[ -s "$WINDOWS" ]] ;;
    list-windows) cat "$WINDOWS" ;;
    new-session|new-window) name_of "$@" >> "$WINDOWS"; echo "%1" ;;
    split-window) echo "%2" ;;
    list-panes) printf '%s\n' "0 %1" "50 %2" ;;
    show-option) exit 1 ;;
    display-message) echo "bash" ;;
esac
exit 0
MOCK
    cat > "$MOCK_BIN/borg" <<'MOCK'
#!/usr/bin/env bash
echo "borg $*" >> "$TRACE"
[[ "$1" == "add" ]] || exit 0
name="${2##*/}"
jq --arg n "$name" --arg p "$2" \
    '.projects[$n] = ((.projects[$n] // {}) + {path: $p, tmux_window: null})' \
    "$BORG_REGISTRY" > "$BORG_REGISTRY.n" && mv "$BORG_REGISTRY.n" "$BORG_REGISTRY"
MOCK
    cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
[[ "$1" == "ps" ]] && echo "app-1"
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux" "$MOCK_BIN/borg" "$MOCK_BIN/docker"

    PROJ="$BATS_TEST_TMPDIR/dev/amber-fox-labs"
    mkdir -p "$PROJ"
    echo '{"projects":{}}' > "$BORG_REGISTRY"
}

_claude_keys() { grep -E '^tmux send-keys' "$TRACE" | grep 'claude --model' || true; }

@test "compose templates mount only the resume dir, never ~/.claude" {
    local t
    for t in supabase supabase-shared; do
        grep -qE "^ +- ~/\.local/state/borg/resume:${MOUNT_TARGET}" "$ROOT/templates/$t/docker-compose.yml"
        ! grep -qE '^ +- ~/\.claude:' "$ROOT/templates/$t/docker-compose.yml"
    done
}

@test "scaffold output mounts the resume dir in the borg service only" {
    run "$DRONE" scaffold "$PROJ"
    [ "$status" -eq 0 ]
    local c="$PROJ/.devcontainer/docker-compose.yml"
    grep -qE "^ +- ~/\.local/state/borg/resume:${MOUNT_TARGET}" "$c"
    ! grep -qE '^ +- ~/\.claude:' "$c"
    # The mount sits after the borg service header, so the team-portable base service stays clean.
    local borg_line mount_line
    borg_line=$(grep -n -- '-borg:$' "$c" | head -1 | cut -d: -f1)
    mount_line=$(grep -n 'borg/resume' "$c" | head -1 | cut -d: -f1)
    [ "$mount_line" -gt "$borg_line" ]
}

@test "up --resume passes the session id to claude" {
    run "$DRONE" up "$PROJ" --resume "$SID"
    [ "$status" -eq 0 ]
    [[ "$(_claude_keys)" == *"claude --model opus --effort xhigh --resume $SID"* ]]
}

@test "up without --resume leaves the claude command line unchanged" {
    run "$DRONE" up "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$(_claude_keys)" == *"claude --model opus --effort xhigh"* ]]
    [[ "$(_claude_keys)" != *"--resume"* ]]
}

@test "up --resume accepts the flag before the project" {
    run "$DRONE" up --resume "$SID" "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$(_claude_keys)" == *"--resume $SID"* ]]
}

@test "up --resume rejects a malformed session id and creates no window" {
    local bad
    for bad in 'a;b' '$(id)' 'x y' '../etc' '-n'; do
        : > "$WINDOWS"
        run "$DRONE" up "$PROJ" --resume "$bad"
        [ "$status" -ne 0 ]
    done
    [ ! -s "$WINDOWS" ]
    [ -z "$(_claude_keys)" ]
}

@test "up --resume with no session id is rejected" {
    run "$DRONE" up "$PROJ" --resume
    [ "$status" -ne 0 ]
    [ -z "$(_claude_keys)" ]
}

@test "up on a devcontainer project creates the host ledger dir before compose up" {
    mkdir -p "$PROJ/.devcontainer"
    : > "$PROJ/.devcontainer/docker-compose.yml"
    [ ! -d "$BORG_RESUME_DIR" ]
    run "$DRONE" up "$PROJ" --resume "$SID"
    [ "$status" -eq 0 ]
    [ -d "$BORG_RESUME_DIR" ]
    [[ "$(_claude_keys)" == *"--resume $SID"* ]]
}

@test "spike U9 and U10 are recorded honestly, never as an empty pass" {
    run jq -e '
      [(.spikes + .non_gating)[] | select(.id == "U9" or .id == "U10")]
      | length == 2 and all(
          .outcome as $o
          | ($o == "pass" and ((.evidence_paths // []) | length) > 0
                          and ((.not_run_parts // []) | length) == 0
                          and ((.refuted_parts // []) | length) == 0)
            or ($o == "partial" and ((.not_run_parts // []) | length) > 0)
            or ($o == "fail"))' "$ROOT/spike/SPIKE_RESULTS.json"
    [ "$status" -eq 0 ]
}
