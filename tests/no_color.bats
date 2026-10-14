#!/usr/bin/env bats
# NO_COLOR (https://no-color.org): set to a NON-EMPTY value, human output carries no ANSI -- no SGR and no OSC-8.
# Two producers, one switch each: borg.zsh's palette block (the colour constants) and borg_core/link/cli.py's
# `_color_enabled`. `--json` and `--porcelain` never carried colour and must not change.
#
# EVERY CASE HAS ITS CONTROL: the same invocation without NO_COLOR must contain an ESC byte, or "no ESC byte"
# would hold of a command that never had any colour to remove.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
ESC=$'\033'

setup() {
    setup_temp_dirs
    # setup_temp_dirs unsets NO_COLOR for the suite; each case sets what it needs inline.
    mkdir -p "$BORG_DIR" "${BATS_TEST_TMPDIR}/ws/alpha"
    cat > "$BORG_REGISTRY" <<EOF
{"projects":{"alpha":{"path":"${BATS_TEST_TMPDIR}/ws/alpha","status":"idle","last_activity":"2026-08-01T00:00:00Z"}}}
EOF
}

@test "no_color: borg link --local --overview carries colour, and none with NO_COLOR=1" {
    run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]] || false
    [[ "$output" == *"$ESC"* ]] || false

    NO_COLOR=1 run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]] || false
    [[ "$output" != *"$ESC"* ]] || false
}

@test "no_color: an EMPTY NO_COLOR keeps colour, and any non-empty value turns it off" {
    NO_COLOR= run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"$ESC"* ]] || false

    NO_COLOR=0 run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" != *"$ESC"* ]] || false
}

@test "no_color: the page is the coloured page minus its escapes, so no column moved" {
    run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    local coloured_plain
    coloured_plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')

    NO_COLOR=1 run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output")" = "$coloured_plain" ]
}

@test "no_color: --json and --porcelain are byte-identical with and without NO_COLOR" {
    run zsh "$BORG" link --local --overview --json
    [ "$status" -eq 0 ]
    local plain_json
    plain_json=$(printf '%s' "$output" | jq 'del(.generated_at)')
    [ -n "$plain_json" ]

    NO_COLOR=1 run zsh "$BORG" link --local --overview --json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq 'del(.generated_at)')" = "$plain_json" ]

    run zsh "$BORG" link --local --overview --porcelain
    [ "$status" -eq 0 ]
    local plain_porcelain="$output"
    NO_COLOR=1 run zsh "$BORG" link --local --overview --porcelain
    [ "$status" -eq 0 ]
    [ "$output" = "$plain_porcelain" ]
}

@test "no_color: borg.zsh's own coloured output (info, die) loses its ESC bytes" {
    run zsh "$BORG" pin alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pinned: alpha"* ]] || false
    [[ "$output" == *"$ESC"* ]] || false

    NO_COLOR=1 run zsh "$BORG" pin alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pinned: alpha"* ]] || false
    [[ "$output" != *"$ESC"* ]] || false

    run zsh "$BORG" pin no-such-repository
    [ "$status" -eq 1 ]
    [[ "$output" == *"$ESC"* ]] || false

    NO_COLOR=1 run zsh "$BORG" pin no-such-repository
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: repository 'no-such-repository' not in registry"* ]] || false
    [[ "$output" != *"$ESC"* ]] || false
}

@test "no_color: borg link's own error line is plain too" {
    NO_COLOR=1 run zsh "$BORG" link no-such-repository
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR:"* ]] || false
    [[ "$output" != *"$ESC"* ]] || false
}
