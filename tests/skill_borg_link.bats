#!/usr/bin/env bats
# PINNED WORDING, not concepts. These assertions match exact strings/headings in
# skills/borg-link/SKILL.md. An editor changing SKILL.md's prose must update this file in
# lockstep — do not expect this suite to catch a meaning-preserving rewording; it only catches the
# specific mutations recorded in each test's non-vacuity note (see Phase 4, A6, phase4-spec.md /
# phase4-corrections.md). bats string-matching a markdown file cannot verify that a model actually
# follows the prose — the step-9 live smoke (run once, by hand, by the owner after redeploy) is
# the only real behavioral evidence this artifact has. Its result belongs in the placeholder below.
#
# STEP-9 SMOKE BASELINE (owner fills in after `borg setup` redeploy):
#   Fallback row forced: <TBD>
#   First tool call observed: <TBD>
#   Staleness downgraded?: <TBD>

load test_helper/setup

SKILL="${BORG_HOME}/skills/borg-link/SKILL.md"

@test "A6 primary path: SKILL.md runs the engine and no longer forbids shelling out" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg link --json"* ]] || false
    [[ "$output" != *"Do **not** shell out to"* ]] || false
    [[ "$output" == *"--brief"* ]] || false
    [[ "$output" == *"--refresh"* ]] || false
}

@test "A6 fallback contract: the section exists, states its trigger, and forbids the staleness downgrade in exact words" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Fallback"* ]] || false
    [[ "$output" == *"not in registry"* ]] || false
    [[ "$output" == *"rc="* ]] || false
    [[ "$output" == *"has_live_window"* ]] || false
    [[ "$output" == *"null"* ]] || false
    [[ "$output" == *"apply NO staleness downgrade"* ]] || false
}

@test "A6 retired couplings stay retired" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" != *"lib/reaper.sh"* ]] || false
    [[ "$output" != *"docs/plans/severed"* ]] || false
    [[ "$output" != *"Cancelled ("* ]] || false
    [[ "$output" != *"grep -qx"* ]] || false
    [[ "$output" != *"~/.config/borg/registry.json"* ]] || false
}

@test "A6 the file exists and is non-empty" {
    [ -f "$SKILL" ]
    [ -s "$SKILL" ]
}
