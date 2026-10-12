#!/usr/bin/env bats
# Pins borg-grunt and borg-scout to the current Haiku (5.5). The bare "haiku" alias resolves to
# haiku-4-5, which ignores effort; 5.5 honors it and is ~10x cheaper.

AGENTS="${BATS_TEST_DIRNAME}/../agents"

@test "borg-grunt pins model claude-haiku-5-5" {
    run grep -m1 "^model:" "${AGENTS}/borg-grunt.md"
    [ "$output" = "model: claude-haiku-5-5" ]
}

@test "borg-scout pins model claude-haiku-5-5" {
    run grep -m1 "^model:" "${AGENTS}/borg-scout.md"
    [ "$output" = "model: claude-haiku-5-5" ]
}
