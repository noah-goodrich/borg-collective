#!/usr/bin/env bats
# The compass reader on the `borg link --json` wire, through the real zsh wrapper.
#
# These cases cross the zsh -> Python boundary on purpose: `borg.zsh` assigns its config surface without
# `export`, so a variable the wrapper does not hand down is invisible to the reader. Every map here is
# synthetic and lives under the sandbox; nothing reads a real map directory.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_DIR"
    printf '%s\n' '{"repositories":{"widgets":{"path":"'"${BATS_TEST_TMPDIR}"'/widgets","status":"idle"}}}' > "$BORG_REGISTRY"
    mkdir -p "${BATS_TEST_TMPDIR}/widgets"
    unset BORG_MAP_DIR
}

_tiny_map() {
    local dir="$1" today
    today="$(date +%F)"
    mkdir -p "$dir/log" "$dir/destinations"
    printf '%s\n' "## Today's leg" "" "- Ship alpha" > "$dir/log/$today.md"
    printf '%s\n' '---' 'id: alpha' 'domain: work' 'status: active' 'definition: approved' 'target: TBD' \
        'repositories:' '  - widgets' '---' '' '### W1 First step' '- status: active' '- [x] one' '- [ ] two' \
        > "$dir/destinations/alpha.md"
    printf '%s\n' '| Destination | Due |' '|---|---|' '| alpha | TBD |' > "$dir/README.md"
}

@test "compass: an empty map directory carries found false on --json --local" {
    local map="${BATS_TEST_TMPDIR}/empty-map"
    mkdir -p "$map"
    BORG_MAP_DIR="$map" run zsh "$BORG" link --json --local
    [ "$status" -eq 0 ]
    run jq -c '[.version, .compass]' <<< "$output"
    [ "$status" -eq 0 ]
    [ "$output" = "[2,{\"found\":false,\"map_dir\":\"$map\"}]" ]
}

@test "compass: an absent map directory is found false and nothing else" {
    local map="${BATS_TEST_TMPDIR}/no-such-map"
    BORG_MAP_DIR="$map" run zsh "$BORG" link --json --local
    [ "$status" -eq 0 ]
    run jq -c '.compass' <<< "$output"
    [ "$output" = "{\"found\":false,\"map_dir\":\"$map\"}" ]
}

@test "compass: with BORG_MAP_DIR unset the reader defaults to HOME/dev/map" {
    run zsh "$BORG" link --json --local
    [ "$status" -eq 0 ]
    run jq -c '.compass' <<< "$output"
    [ "$output" = "{\"found\":false,\"map_dir\":\"${HOME}/dev/map\"}" ]
}

@test "compass: a tiny synthetic map reaches the wire through the zsh wrapper" {
    local map="${BATS_TEST_TMPDIR}/tiny-map"
    _tiny_map "$map"
    BORG_MAP_DIR="$map" run zsh "$BORG" link --json --local
    [ "$status" -eq 0 ]
    local doc="$output"
    run jq -r '.compass | [.found, .leg.text, .destinations[0].id, .destinations[0].state, .destinations[0].next_waypoint.done, .destinations[0].next_waypoint.total] | @tsv' <<< "$doc"
    [ "$output" = "$(printf 'true\tShip alpha\talpha\tundated\t1\t2')" ]
    run jq -c '.compass.repositories' <<< "$doc"
    [ "$output" = '{"widgets":{"destination":"alpha","on_leg":true}}' ]
    run jq -c '.compass.warnings' <<< "$doc"
    [ "$output" = '[]' ]
}

@test "compass: --porcelain is byte-identical with and without a map" {
    local map="${BATS_TEST_TMPDIR}/tiny-map"
    _tiny_map "$map"
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run zsh "$BORG" link --porcelain --local
    [ "$status" -eq 0 ]
    local without="$output"
    BORG_MAP_DIR="$map" run zsh "$BORG" link --porcelain --local
    [ "$status" -eq 0 ]
    [ -n "$without" ]
    [ "$output" = "$without" ]
}
