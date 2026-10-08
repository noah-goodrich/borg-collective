#!/usr/bin/env bats
# Tests for drone's registry-owned tmux window names: derive-on-up, explicit names respected, either
# form accepted as an argument, long-named live windows still found, and `--all` handing PROJECT
# names (never window names) to the container cycle. Project names below are invented.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    export WINDOWS="${BATS_TEST_TMPDIR}/windows"
    : > "$TRACE"
    : > "$WINDOWS"
    export BORG_TMUX_SESSION="wtest"
    export TMUX="/tmp/tmux-1000/default,1234,0"
    unset TMUX_PANE

    # Stateful tmux: $WINDOWS holds one live window name per line. Every call is logged.
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
name_of() { while [[ $# -gt 0 ]]; do [[ "$1" == "-n" ]] && { echo "$2"; return; }; shift; done; }
case "$1" in
    has-session) [[ -s "$WINDOWS" ]] ;;
    list-windows) cat "$WINDOWS" ;;
    new-session|new-window) name_of "$@" >> "$WINDOWS"; echo "%1" ;;
    split-window) echo "%2" ;;
    kill-window) t="${3#*:}"; grep -vxF "$t" "$WINDOWS" > "$WINDOWS.n" || true; mv "$WINDOWS.n" "$WINDOWS" ;;
    list-panes) printf '%s\n' "0 %1" "50 %2" ;;
    show-option)
        w="${3#*:}"
        [[ -f "$BATS_TEST_TMPDIR/pdir.$w" ]] && cat "$BATS_TEST_TMPDIR/pdir.$w" || exit 1 ;;
    display-message) echo "bash" ;;
esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux"

    # borg add stub: registers basename(dir) if absent, then CLOBBERS tmux_window like the real
    # `borg add` does (null, because no window named after the project exists) -- drone must repair it.
    cat > "$MOCK_BIN/borg" <<'MOCK'
#!/usr/bin/env bash
echo "borg $*" >> "$TRACE"
[[ "$1" == "add" ]] || exit 0
name="${2##*/}"
jq --arg n "$name" --arg p "$2" \
    '.projects[$n] = ((.projects[$n] // {}) + {path: $p, tmux_window: null})' \
    "$BORG_REGISTRY" > "$BORG_REGISTRY.n" && mv "$BORG_REGISTRY.n" "$BORG_REGISTRY"
MOCK
    chmod +x "$MOCK_BIN/borg"

    # docker stub for the --all cycle: logs, and reports a running app container.
    cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
[[ "$1" == "ps" ]] && echo "app-1"
exit 0
MOCK
    chmod +x "$MOCK_BIN/docker"

    PROJ="$BATS_TEST_TMPDIR/dev/amber-fox-labs"
    OTHER="$BATS_TEST_TMPDIR/dev/quillmaker-studio"
    mkdir -p "$PROJ" "$OTHER"
    echo '{"projects":{}}' > "$BORG_REGISTRY"
}

_reg() { jq -r --arg p "$1" '.projects[$p].tmux_window // "null"' "$BORG_REGISTRY"; }

_register() {  # name dir [tmux_window]
    jq --arg n "$1" --arg d "$2" --arg w "${3:-}" \
        '.projects[$n] = {path: $d, tmux_window: (if $w == "" then null else $w end)}' \
        "$BORG_REGISTRY" > "$BORG_REGISTRY.n" && mv "$BORG_REGISTRY.n" "$BORG_REGISTRY"
}

_new_window_names() { grep -E '^tmux (new-window|new-session)' "$TRACE" | sed -E 's/.* -n ([^ ]+).*/\1/'; }

@test "up derives the short name, stores it, and creates the window under it" {
    run "$DRONE" up "$PROJ"
    [ "$status" -eq 0 ]
    [ "$(_reg amber-fox-labs)" = "afl" ]
    [ "$(_new_window_names)" = "afl" ]
    grep -qx afl "$WINDOWS"
    ! grep -qx amber-fox-labs "$WINDOWS"
}

@test "up respects an explicit window name" {
    _register amber-fox-labs "$PROJ" fox
    run "$DRONE" up amber-fox-labs
    [ "$status" -eq 0 ]
    [ "$(_reg amber-fox-labs)" = "fox" ]
    [ "$(_new_window_names)" = "fox" ]
}

@test "up with a short name argument resolves to the project" {
    _register amber-fox-labs "$PROJ" fox
    run "$DRONE" up fox
    [ "$status" -eq 0 ]
    [ "$(_new_window_names)" = "fox" ]
    [ "$(cat "$PROJ/.borg-project")" = "amber-fox-labs" ]
}

@test "up finds a live window under the long name and creates nothing" {
    _register amber-fox-labs "$PROJ" fox
    echo amber-fox-labs > "$WINDOWS"
    run "$DRONE" up amber-fox-labs
    [ "$status" -eq 0 ]
    [ -z "$(_new_window_names)" ]
    grep -q 'select-window -t wtest:amber-fox-labs' "$TRACE"
}

@test "down kills the window found under the long name" {
    _register amber-fox-labs "$PROJ" fox
    echo amber-fox-labs > "$WINDOWS"
    run "$DRONE" down amber-fox-labs
    [ "$status" -eq 0 ]
    grep -q 'kill-window -t wtest:amber-fox-labs' "$TRACE"
}

@test "toggle with a short name finds the live window" {
    _register amber-fox-labs "$PROJ" fox
    echo fox > "$WINDOWS"
    run "$DRONE" toggle amber-fox-labs
    [ "$status" -eq 0 ]
    grep -q 'list-panes -t wtest:fox' "$TRACE"
}

@test "toggle accepts the short name and a long-named live window" {
    _register amber-fox-labs "$PROJ" fox
    echo amber-fox-labs > "$WINDOWS"
    run "$DRONE" toggle fox
    [ "$status" -eq 0 ]
    grep -q 'list-panes -t wtest:amber-fox-labs' "$TRACE"
}

@test "fix with a short name targets the live window" {
    _register amber-fox-labs "$PROJ" fox
    echo fox > "$WINDOWS"
    run "$DRONE" fix amber-fox-labs
    [ "$status" -eq 0 ]
    grep -q 'select-layout -t wtest:fox' "$TRACE"
}

@test "claude targets the window name, not the project name" {
    _register amber-fox-labs "$PROJ" fox
    echo fox > "$WINDOWS"
    run "$DRONE" claude amber-fox-labs
    [ "$status" -eq 0 ]
    grep -q 'select-window -t wtest:fox' "$TRACE"
    grep -q 'list-panes -t wtest:fox' "$TRACE"
    ! grep -q 'wtest:amber-fox-labs' "$TRACE"
}

@test "restart --all passes PROJECT names (not window names) to the cycle" {
    mkdir -p "$PROJ/.devcontainer" "$OTHER/.devcontainer"
    touch "$PROJ/.devcontainer/docker-compose.yml" "$OTHER/.devcontainer/docker-compose.yml"
    _register amber-fox-labs "$PROJ" fox
    _register quillmaker-studio "$OTHER" quill
    printf '%s\n' fox quill > "$WINDOWS"
    echo "$PROJ" > "$BATS_TEST_TMPDIR/pdir.fox"
    echo "$OTHER" > "$BATS_TEST_TMPDIR/pdir.quill"
    run "$DRONE" restart --all
    [ "$status" -eq 0 ]
    grep -q 'docker compose -p amber-fox-labs ' "$TRACE"
    grep -q 'docker compose -p quillmaker-studio ' "$TRACE"
    ! grep -q 'docker compose -p fox ' "$TRACE"
    ! grep -q 'docker compose -p quill ' "$TRACE"
}

@test "an unregistered project falls back to its own name when the registry is unusable" {
    echo 'not json' > "$BORG_REGISTRY"
    run "$DRONE" up "$PROJ"
    [ "$status" -eq 0 ]
    [ "$(_new_window_names)" = "amber-fox-labs" ]
}

@test "cortex targets the window name, not the project name" {
    _register amber-fox-labs "$PROJ" fox
    echo fox > "$WINDOWS"
    run "$DRONE" cortex fox
    [ "$status" -eq 0 ]
    grep -q 'set-option -t wtest:fox @cortex_launched 1' "$TRACE"
    ! grep -q 'wtest:amber-fox-labs' "$TRACE"
}

# ── drone must not register a twin of a project whose name is not its folder's basename ──────────────
# A monorepo subfolder is registered as `widgets`; `borg add` alone would name it `widget-kit`. These
# use the REAL registry writer (borg_core.registry.cli) behind a call-logging `borg` shim, because the
# stub above names by basename too and would hide exactly the bug.

_real_borg() {
    cat > "$MOCK_BIN/borg" <<MOCK
#!/usr/bin/env bash
echo "borg \$*" >> "\$TRACE"
[[ "\$1" == "add" ]] || exit 0
shift
PYTHONPATH="${BATS_TEST_DIRNAME}/.." exec "${BORG_EVAL_PYTHON:-python3}" -m borg_core.registry.cli add "\$@"
MOCK
    chmod +x "$MOCK_BIN/borg"
}

_entries_for() { jq -r --arg d "$1" '[.projects | to_entries[] | select(.value.path == $d)] | length' "$BORG_REGISTRY"; }

@test "up twice on a non-basename project leaves one entry, same name and tmux_window" {
    _real_borg
    SUB="$BATS_TEST_TMPDIR/dev/monorepo/libs/widget-kit"
    mkdir -p "$SUB"
    SUB="$(cd "$SUB" && pwd -P)"
    _register widgets "$SUB" wdg

    run "$DRONE" up widgets
    [ "$status" -eq 0 ]
    : > "$WINDOWS"
    run "$DRONE" up widgets
    [ "$status" -eq 0 ]

    [ "$(_entries_for "$SUB")" = "1" ]
    [ "$(jq -r '.projects | keys | join(",")' "$BORG_REGISTRY")" = "widgets" ]
    [ "$(_reg widgets)" = "wdg" ]
    [[ "$output" != *"Registered: widget-kit"* ]]
}

@test "drone does not call borg add for an already-registered project" {
    _register widgets "$BATS_TEST_TMPDIR/dev/widget-kit" wdg
    mkdir -p "$BATS_TEST_TMPDIR/dev/widget-kit"
    run "$DRONE" up widgets
    [ "$status" -eq 0 ]
    ! grep -q '^borg add' "$TRACE"
}

@test "drone registers a brand-new project under the name it was given" {
    _real_borg
    run "$DRONE" up "$PROJ"
    [ "$status" -eq 0 ]
    grep -q "^borg add .* --name amber-fox-labs" "$TRACE"
    [ "$(_entries_for "$(cd "$PROJ" && pwd -P)")" = "1" ]
}
