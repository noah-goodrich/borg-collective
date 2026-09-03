#!/usr/bin/env bats
# bin/link-parity-harness is a developer tool, not a CI test -- it shells out to the real (or a
# fixture) registry and the plan files it names. This file intentionally does NOT run its
# differential against real data; it only asserts the script is executable, that its --help works,
# and that the retired `render` leg dies with the reason rather than silently or cryptically.
#
# The `render` case is safe to run here BECAUSE the retirement gate sits above the registry lookup in
# main(): it needs no registry, reads no plan file, and forks nothing.

# ── EVERY `[[ ... ]]` HERE ENDS IN `|| false`, AND THAT IS NOT STYLE ─────────────────────────────
# macOS ships GNU bash 3.2, which does NOT apply `set -e` to a failing double-bracket conditional
# that is not the final command of its function; bash 5, which is what CI's ubuntu lane runs, does.
# Measured on the machine of record with a `set -e` function whose non-final false double-bracket
# test is followed by an `echo`: bash 3.2 prints the echo and returns 0. So a bare double-bracket
# assertion mid-body is INERT locally and gates only in CI -- the direction nobody notices.
#
# FIVE of the six double-bracket assertions below were bare, and FOUR of those five were non-final
# and so gated nothing here; the fifth escaped only by accident of being the last command of its
# body. Not a theory: with `ad99612` rewritten to `deadbee` in RENDER_RETIRED_LEAD, the render case
# still reported `ok` while asserting a string that was absent from its output, and it goes red on
# that same mutation now. eval_floor.bats carries the fuller write-up of the same class. Grepping
# this file for a double-bracket line without the suffix must find nothing.
#
# Single brackets are left alone: bash 3.2 DOES honour `set -e` for a failing non-final single-
# bracket test, verified by the same probe, so `[ "$status" -eq 2 ]` already gates on both platforms.
# The prose above spells "double-bracket" out rather than quoting the operator on purpose, so the
# grep this note prescribes stays a clean zero instead of matching the comment that describes it.

load test_helper/setup

@test "link-parity-harness is executable" {
    [ -x "$BORG_HOME/bin/link-parity-harness" ]
}

@test "link-parity-harness --help works" {
    run "$BORG_HOME/bin/link-parity-harness" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"link-parity-harness"* ]] || false
    [[ "$output" == *"--registry"* ]] || false
}

# AC2/S4. The render differential's oracle is the pre-AC2 zsh renderer at ad99612, which renders the
# OLD document; S3 replaced all three human renderers with render.document(). Asking for it must
# report that the evidence MOVED (to the goldens) rather than exiting 0 on a comparison that no
# longer means anything -- and must not degrade to argparse's bare "invalid choice" either, which is
# why `render` stays a recognized token.
@test "link-parity-harness render is retired and says where the evidence went" {
    run "$BORG_HOME/bin/link-parity-harness" render
    [ "$status" -eq 2 ]
    [[ "$output" == *"retired"* ]] || false
    [[ "$output" == *"ad99612"* ]] || false
    [[ "$output" == *"golden"* ]] || false
    [[ "$output" != *"invalid choice"* ]] || false
}
