#!/usr/bin/env bats
# bin/link-parity-harness is a developer tool, not a CI test -- it shells out to the real (or a
# fixture) registry and the plan files it names. This file intentionally does NOT run its
# differential against real data; it only asserts the script is executable, that its --help works,
# and that the retired `render` leg dies with the reason rather than silently or cryptically.
#
# The `render` case is safe to run here BECAUSE the retirement gate sits above the registry lookup in
# main(): it needs no registry, reads no plan file, and forks nothing.

load test_helper/setup

@test "link-parity-harness is executable" {
    [ -x "$BORG_HOME/bin/link-parity-harness" ]
}

@test "link-parity-harness --help works" {
    run "$BORG_HOME/bin/link-parity-harness" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"link-parity-harness"* ]]
    [[ "$output" == *"--registry"* ]]
}

# AC2/S4. The render differential's oracle is the pre-AC2 zsh renderer at ad99612, which renders the
# OLD document; S3 replaced all three human renderers with render.document(). Asking for it must
# report that the evidence MOVED (to the goldens) rather than exiting 0 on a comparison that no
# longer means anything -- and must not degrade to argparse's bare "invalid choice" either, which is
# why `render` stays a recognized token.
@test "link-parity-harness render is retired and says where the evidence went" {
    run "$BORG_HOME/bin/link-parity-harness" render
    [ "$status" -eq 2 ]
    [[ "$output" == *"retired"* ]]
    [[ "$output" == *"ad99612"* ]]
    [[ "$output" == *"golden"* ]]
    [[ "$output" != *"invalid choice"* ]] || false
}
