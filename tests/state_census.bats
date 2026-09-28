#!/usr/bin/env bats
# The reader census gate — AC2 of 2026-09-28-state-hygiene-reader-census.
#
# Ten of sixteen `.borg/<name>` names in this tree had no code reader, and one of them was the
# decommissioned cairn service's own export, still named in CLAUDE.md's Architecture Rules as a
# place to grep for prior decisions. Cairn (Postgres + pgvector) measured 0.4% restatement;
# auto-memory (markdown on a filesystem) currently reads 0.129 reads/session against a
# pre-registered 0.2 bar. Same failure, opposite engines — a store nothing reads is a write-only
# store, so the gate is about obligation to read, not about storage.
#
# EVERY CASE IS PAIRED WITH THE DIRECTION THAT PROVES IT DISCRIMINATES, which is
# tests/prose_contracts.bats' stated rule and the reason this file has six fixtures rather than one
# assertion against a passing tree. A census only ever run against a green repository is the vacuous
# green it exists to prevent.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIXTURES="${BATS_TEST_DIRNAME}/fixtures/census"
    GATE=(env "PYTHONPATH=${REPO_ROOT}" python3 -m borg_core.census.cli)
}

@test "census: this repository passes its own gate" {
    run "${GATE[@]}" "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 violations"* ]]
}

@test "census: state 1 — written by code, absent from the census, FAILS" {
    run "${GATE[@]}" "${FIXTURES}/undeclared"
    [ "$status" -eq 1 ]
    [[ "$output" == *".borg/orphan"* ]]
    [[ "$output" == *"absent from the census"* ]]
}

@test "census: state 1 — declared with no reader at all, FAILS" {
    run "${GATE[@]}" "${FIXTURES}/no-reader"
    [ "$status" -eq 1 ]
    [[ "$output" == *"NO READER declared"* ]]
}

@test "census: state 2 — a docs promise with no reader FAILS" {
    # The exact shape CLAUDE.md carried for two months after cairn was decommissioned: an
    # instruction to every agent to grep a store that no code path reads.
    run "${GATE[@]}" "${FIXTURES}/docs-promise"
    [ "$status" -eq 1 ]
    [[ "$output" == *".borg/lore"* ]]
}

@test "census: state 3 — on disk with no writer and no reader PASSES" {
    # `.borg/ghost/old.md` exists in this fixture and is named nowhere. Inert historical data is not
    # a defect, and this is what `.borg/knowledge/`'s 1106 kept files became once the promise to
    # grep them was deleted. Retiring a store means deleting the promise, not the data.
    [ -f "${FIXTURES}/inert/.borg/ghost/old.md" ]
    run "${GATE[@]}" "${FIXTURES}/inert"
    [ "$status" -eq 0 ]
}

@test "census: a stale reader declaration FAILS" {
    # The ratchet's real value: a reader cannot be renamed or deleted without this going red.
    run "${GATE[@]}" "${FIXTURES}/stale-reader"
    [ "$status" -eq 1 ]
    [[ "$output" == *"stale"* ]]
}

@test "census: a well-formed store PASSES" {
    run "${GATE[@]}" "${FIXTURES}/passing"
    [ "$status" -eq 0 ]
}

@test "census: the promise to grep .borg/knowledge is gone from CLAUDE.md" {
    # AC3's repo half, pinned here because it is what makes the gate green. The FILES must survive:
    # retiring a store deletes the promise, not the data.
    # Asserted on the LINE, not on a phrase: the rule is hard-wrapped at 120 like everything else
    # in this tree, so "grep them before assuming" spans two physical lines and a naive grep for it
    # matches nothing whether the fix landed or not. First draft of this case did exactly that and
    # went red against a correct file.
    run bash -c "grep -m1 'Prior decisions live in' '${REPO_ROOT}/CLAUDE.md'"
    [ "$status" -eq 0 ]
    [[ "$output" == *".borg/checkpoints"* ]]
    [[ "$output" == *"docs/plans/assimilated"* ]]
    [[ "$output" != *".borg/knowledge"* ]]
}

@test "census: .borg/knowledge's tracked files are still there" {
    run bash -c "cd '${REPO_ROOT}' && git ls-files .borg/knowledge | wc -l | tr -d ' '"
    [ "$output" = "1106" ]
}
