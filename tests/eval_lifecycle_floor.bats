#!/usr/bin/env bats
# THE CALLER `evals/lifecycle-manifests/floor-tests.sh` DID NOT HAVE. That file's header said CI ran
# it "on the same leg as the rest of the suite" while nothing in the tree -- no Makefile target, no
# workflow step, no bats case -- invoked it. A floor with no caller is a script someone remembers,
# which is the defect class `tests/eval_floor.bats` exists to end. This file is collected by
# `bats tests/*.bats` by existing, so no CI job is added.
#
# ONE CASE, DELIBERATELY. floor-tests.sh is its own suite with its own PASS/FAIL accounting and its
# own discriminating pairs; re-stating each of its cases here would be a second oracle that drifts
# from the first. This case asserts the suite ran to a verdict and the verdict was clean, and reads
# the count from the suite's own summary line so an empty run cannot pass as a green one.
#
# HERMETIC THE SAME WAY eval_floor.bats IS: floor-tests.sh builds a sandbox `$REPO` and points every
# run.sh invocation at it through `BORG_EVAL_REPO`, so nothing here writes into this checkout's
# `evals/` tree. It hides `claude` itself in the one case that needs it hidden and passes
# `--skip-model` in the other, so no model call is made and nothing is spent.
#
# `[[ ... ]] || false` for the reason eval_floor.bats's header gives: bash 3.2 does not apply
# `set -e` to a failing double-bracket that is not a function's final command.

load test_helper/setup

setup() {
    setup_temp_dirs
}

@test "evals/lifecycle-manifests: the harness's own floor suite passes clean" {
    run env PYTHONDONTWRITEBYTECODE=1 bash "$BORG_HOME/evals/lifecycle-manifests/floor-tests.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"floor: "*" passed, 0 failed"* ]] || false
    [[ "$output" != *"floor: 0 passed"* ]] || false
    [[ "$output" != *"premise broken"* ]] || false
}
