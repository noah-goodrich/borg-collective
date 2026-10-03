#!/usr/bin/env bats
# The eval coverage ledger gate -- AC2 and AC3 of 2026-10-03-evals-for-everything, Decision 4.
#
# `evals/ledger.json` must account for every `skills/*/SKILL.md` and `agents/*.md` as an eval or a
# dated waiver. The gate is `python3 -m borg_core.evals.cli check`; every case below runs it against
# a SANDBOXED tree so each failure direction is proven to fire, and one case runs it against this
# repository so the real ledger is held to the same rule. A gate only ever run against a passing tree
# is the vacuous green this repo keeps paying for, which is why the clean sandbox case sits beside
# each failing one -- the pair proves the check discriminates.
#
# Expiry is pinned with `--today` so no case here is a time bomb; only the real-repository case reads
# the real clock, on purpose: that one is SUPPOSED to go red the day a waiver lapses.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SB="${BATS_TEST_TMPDIR}/tree"
    mkdir -p "$SB/skills/alpha" "$SB/skills/beta" "$SB/agents" "$SB/evals/e1"
    : > "$SB/skills/alpha/SKILL.md"
    : > "$SB/skills/beta/SKILL.md"
    : > "$SB/agents/gamma.md"
    : > "$SB/evals/e1/run.sh"
    write_ledger '"skills/alpha": {"eval": "evals/e1"},
        "skills/beta": {"waiver": "later", "review_by": "2026-12-01"},
        "agents/gamma": {"waiver": "later", "review_by": "2026-12-01"}'
}

write_ledger() {
    cat > "$SB/evals/ledger.json" <<JSON
{"version": 1,
 "evals": {"evals/e1": {"covers": ["evals/e1/**", "skills/alpha/**"]}},
 "items": {$1}}
JSON
}

gate() {
    run env "PYTHONPATH=${REPO_ROOT}" python3 -m borg_core.evals.cli check --root "$SB" --today "${1:-2026-10-03}"
}

@test "ledger: this repository passes its own gate" {
    run env "PYTHONPATH=${REPO_ROOT}" python3 -m borg_core.evals.cli check --root "$REPO_ROOT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 problems"* ]] || false
}

@test "ledger: a closed sandbox tree passes" {
    gate
    [ "$status" -eq 0 ]
}

@test "ledger: an unlisted skill fails, naming it" {
    mkdir "$SB/skills/zz-test" && : > "$SB/skills/zz-test/SKILL.md"
    gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/zz-test"* ]] || false
    [[ "$output" == *"not in the ledger"* ]] || false
}

@test "ledger: an unlisted agent fails, naming it" {
    : > "$SB/agents/ZZ-new.md"
    gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"agents/ZZ-new"* ]] || false
}

@test "ledger: a row pointing at a missing eval path fails, naming it" {
    rm "$SB/evals/e1/run.sh"
    gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"evals/e1"* ]] || false
    [[ "$output" == *"eval path missing"* ]] || false
}

@test "ledger: an expired waiver fails, naming the item and the date" {
    gate 2026-12-02
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/beta"* ]] || false
    [[ "$output" == *"expired 2026-12-01"* ]] || false
}

@test "ledger: a waiver is still good on its review_by day" {
    gate 2026-12-01
    [ "$status" -eq 0 ]
}

@test "ledger: a waiver without a reason or a date fails" {
    write_ledger '"skills/alpha": {"eval": "evals/e1"},
        "skills/beta": {"waiver": "", "review_by": "2026-12-01"},
        "agents/gamma": {"waiver": "later"}'
    gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/beta: waiver has no reason"* ]] || false
    [[ "$output" == *"agents/gamma: waiver needs review_by"* ]] || false
}

@test "ledger: a row for an item that no longer exists fails" {
    rm -r "$SB/skills/beta"
    gate
    [ "$status" -eq 1 ]
    [[ "$output" == *"skills/beta"* ]] || false
    [[ "$output" == *"does not exist"* ]] || false
}
