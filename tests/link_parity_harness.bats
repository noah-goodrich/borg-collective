#!/usr/bin/env bats
# bin/link-parity-harness is a developer tool, not a CI test -- it shells out to git history and
# needs a real (or fixture) registry. This file intentionally does NOT run it against real data;
# it only asserts the script is executable and its --help works, per the tool's own scope note.

load test_helper/setup

@test "link-parity-harness is executable" {
    [ -x "$BORG_HOME/bin/link-parity-harness" ]
}

@test "link-parity-harness --help works" {
    run "$BORG_HOME/bin/link-parity-harness" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"link-parity-harness"* ]]
    [[ "$output" == *"--oracle-ref"* ]]
}
