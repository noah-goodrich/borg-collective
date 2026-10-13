#!/usr/bin/env bats
# The compose project name has ONE source of truth: the registry/project name drone passes to
# `docker compose -p`. Lookups (get_repository_container / get_service_name) must filter on the same
# value, normalized the way docker compose normalizes it, never on the folder basename. Names invented.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    export WINDOWS="${BATS_TEST_TMPDIR}/windows"
    export STARTED="${BATS_TEST_TMPDIR}/started"
    : > "$TRACE"
    : > "$WINDOWS"
    : > "$STARTED"
    export BORG_TMUX_SESSION="wtest"
    export TMUX="/tmp/tmux-1000/default,1234,0"
    unset TMUX_PANE

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
    show-option)
        w="${3#*:}"
        [[ -f "$BATS_TEST_TMPDIR/pdir.$w" ]] && cat "$BATS_TEST_TMPDIR/pdir.$w" || exit 1 ;;
    display-message) echo "wf" ;;
esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux"

    cat > "$MOCK_BIN/borg" <<'MOCK'
#!/usr/bin/env bash
echo "borg $*" >> "$TRACE"
exit 0
MOCK
    chmod +x "$MOCK_BIN/borg"

    # docker stub: `compose -p X ... up` records the label value compose would stamp (X lowercased,
    # chars outside [a-z0-9_-] dropped). `ps --filter label=com.docker.compose.project=V` answers
    # ONLY when V equals that recorded value, exactly like the real daemon.
    cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
if [[ "$1" == "compose" ]]; then
    p=""; prev=""
    for a in "$@"; do [[ "$prev" == "-p" ]] && p="$a"; prev="$a"; done
    case " $* " in
        *" up "*) [[ -n "$p" ]] && printf '%s\n' "$p" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_\n-' > "$STARTED" ;;
        *" ps "*) [[ -n "$p" && "$p" == "$(cat "$STARTED")" ]] && echo "app-1" ;;
    esac
    exit 0
fi
if [[ "$1" == "ps" ]]; then
    want=""
    for a in "$@"; do
        [[ "$a" == label=com.docker.compose.project=* ]] && want="${a#label=com.docker.compose.project=}"
    done
    if [[ -s "$STARTED" && "$want" == "$(cat "$STARTED")" ]]; then
        case "$*" in *Label*) echo "app" ;; *) echo "app-1" ;; esac
    fi
fi
exit 0
MOCK
    chmod +x "$MOCK_BIN/docker"

    DIR="$BATS_TEST_TMPDIR/dev/widgets-wt-12"
    mkdir -p "$DIR/.devcontainer"
    touch "$DIR/.devcontainer/docker-compose.yml"
}

_register() {  # name dir [tmux_window]
    jq -n --arg n "$1" --arg d "$2" --arg w "${3:-}" \
        '{projects: {($n): {path: $d, tmux_window: (if $w == "" then null else $w end)}}}' > "$BORG_REGISTRY"
}

@test "up finds the container when the registry name differs from the folder" {
    _register widgets-feature "$DIR"
    run "$DRONE" up widgets-feature
    [ "$status" -eq 0 ]
    [[ "$output" != *"Timed out"* ]]
    grep -q 'docker compose -p widgets-feature .* up -d' "$TRACE"
    grep -q 'label=com.docker.compose.project=widgets-feature' "$TRACE"
    ! grep -q 'label=com.docker.compose.project=widgets-wt-12' "$TRACE"
}

@test "up normalizes an uppercase registry name the way compose does" {
    _register Widgets_Feature.X "$DIR"
    run "$DRONE" up Widgets_Feature.X
    [ "$status" -eq 0 ]
    [[ "$output" != *"Timed out"* ]]
    grep -q 'label=com.docker.compose.project=widgets_featurex' "$TRACE"
}

@test "sh normalizes an uppercase dotted registry name before the lookup" {
    _register Widgets_Feature.X "$DIR"
    echo widgets_featurex > "$STARTED"
    run "$DRONE" sh Widgets_Feature.X
    [[ "$output" != *"No running app container"* ]]
    grep -q 'label=com.docker.compose.project=widgets_featurex' "$TRACE"
    ! grep -q 'label=com.docker.compose.project=Widgets_Feature.X' "$TRACE"
}

@test "exec finds the container under a name that needs normalization" {
    _register Widgets_Feature.X "$DIR"
    echo widgets_featurex > "$STARTED"
    run "$DRONE" exec Widgets_Feature.X -- true
    [[ "$output" != *"not running"* ]]
    grep -q 'label=com.docker.compose.project=widgets_featurex' "$TRACE"
    ! grep -q 'label=com.docker.compose.project=Widgets_Feature.X' "$TRACE"
}

@test "restart with no argument inside a window uses the registry name, not the folder" {
    _register widgets-feature "$DIR" wf
    echo wf > "$WINDOWS"
    echo "$DIR" > "$BATS_TEST_TMPDIR/pdir.wf"
    run "$DRONE" restart
    [ "$status" -eq 0 ]
    [[ "$output" != *"Timed out"* ]]
    grep -q 'docker compose -p widgets-feature ' "$TRACE"
    ! grep -q 'docker compose -p widgets-wt-12 ' "$TRACE"
    grep -q 'label=com.docker.compose.project=widgets-feature' "$TRACE"
    ! grep -q 'label=com.docker.compose.project=widgets-wt-12' "$TRACE"
}
