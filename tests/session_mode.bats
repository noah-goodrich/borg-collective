#!/usr/bin/env bats
# Tests for _borg_session_mode (lib/borg-hooks.sh).
#
# Returns the literal "orchestrator" when $1 exactly matches $BORG_ORCHESTRATOR_ROOT
# (default $HOME/dev), "project" otherwise. Exact match only — descendants of the
# workspace root are still project sessions.

load test_helper/setup

LIB="${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh"

setup() {
    setup_temp_dirs
}

@test "session_mode: cwd == \$HOME/dev returns orchestrator" {
    run bash -c "source '$LIB'; _borg_session_mode '$HOME/dev'"
    [ "$status" -eq 0 ]
    [ "$output" = "orchestrator" ]
}

@test "session_mode: cwd == \$HOME/dev/reveal returns project" {
    run bash -c "source '$LIB'; _borg_session_mode '$HOME/dev/reveal'"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "session_mode: cwd == \$HOME/dev/borg-collective returns project (NOT orchestrator)" {
    run bash -c "source '$LIB'; _borg_session_mode '$HOME/dev/borg-collective'"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "session_mode: trailing slash on cwd matches without trailing slash" {
    run bash -c "source '$LIB'; _borg_session_mode '$HOME/dev/'"
    [ "$status" -eq 0 ]
    [ "$output" = "orchestrator" ]
}

@test "session_mode: trailing slash on project path still returns project" {
    run bash -c "source '$LIB'; _borg_session_mode '$HOME/dev/reveal/'"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "session_mode: BORG_ORCHESTRATOR_ROOT unset falls back to \$HOME/dev default" {
    run bash -c "unset BORG_ORCHESTRATOR_ROOT; source '$LIB'; _borg_session_mode '$HOME/dev'"
    [ "$status" -eq 0 ]
    [ "$output" = "orchestrator" ]
}

@test "session_mode: custom BORG_ORCHESTRATOR_ROOT exact match returns orchestrator" {
    run bash -c "BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' source '$LIB'; BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' _borg_session_mode '/tmp/test-dev'"
    [ "$status" -eq 0 ]
    [ "$output" = "orchestrator" ]
}

@test "session_mode: custom BORG_ORCHESTRATOR_ROOT child path returns project" {
    run bash -c "BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' source '$LIB'; BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' _borg_session_mode '/tmp/test-dev/foo'"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "session_mode: custom BORG_ORCHESTRATOR_ROOT does NOT match default \$HOME/dev" {
    run bash -c "BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' source '$LIB'; BORG_ORCHESTRATOR_ROOT='/tmp/test-dev' _borg_session_mode '$HOME/dev'"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}

@test "session_mode: empty cwd returns project (does not equal default root)" {
    run bash -c "source '$LIB'; _borg_session_mode ''"
    [ "$status" -eq 0 ]
    [ "$output" = "project" ]
}
