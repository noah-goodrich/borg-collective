#!/usr/bin/env bats
# The offline half of the link-next eval -- AC B4 of 2026-10-03-evals-for-everything, Phase 1b.
#
# `evals/link-next/run.sh` applies each case's regex graders to recorded replies: the known-good reply must pass
# and every known-bad reply (the 2026-10-20 shape, invented names) must FAIL. The cases below mutate a COPY of
# that directory so each way the grader could stop discriminating is proven to turn the harness red. Every
# mutation sits beside a clean run, because a gate only ever shown a passing tree is the vacuous green this
# repository keeps paying for. No case here reaches a model; live.sh is the only thing that does.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    COPY="${BATS_TEST_TMPDIR}/link-next"
    cp -R "${REPO_ROOT}/evals/link-next" "$COPY"
    rm -rf "$COPY/out"
}

harness() {
    run env "BORG_EVAL_REPO=${1:-$REPO_ROOT}" bash "$COPY/run.sh" --skip-model --skip-network
}

@test "link-next: the shipped harness passes and grades every known-bad reply FAIL" {
    harness
    [ "$status" -eq 0 ]
    [[ "$output" == *"link-verdict-honest-waits.bad-nothing-waits.md is graded FAIL"* ]] || false
    [[ "$output" == *"next-empty-no-declined.bad-declined.md is graded FAIL"* ]] || false
    [[ "$output" == *"0 fail"* ]] || false
}

@test "link-next: the incident reply (nothing waits above a page listing items) fails the verdict graders" {
    local bad="$COPY/transcripts/link-verdict-honest-waits.bad-nothing-waits.md"
    grep -qF 'Nothing is waiting on you.' "$bad"
    grep -qF 'Approve the Acme vendor quote' "$bad"
    local pat
    pat="$(awk '/^---$/{n++; next} n>=2 && NF{print; exit}' "$COPY/cases/link-verdict-honest-waits/graders/no-nothing-waits.md")"
    run env "PAT=$pat" python3 -I -c 'import os, re, sys; sys.exit(0 if re.search(os.environ["PAT"], open(sys.argv[1]).read()) else 1)' "$bad"
    [ "$status" -eq 1 ]
}

@test "link-next: a blanked grader pattern turns the harness red" {
    printf -- '---\ntype: regex\nweight: 1\n---\n\n' > "$COPY/cases/link-verdict-honest-waits/graders/no-nothing-waits.md"
    harness
    [ "$status" -eq 1 ]
    [[ "$output" == *"empty pattern"* ]] || false
}

@test "link-next: a grader that passes everything turns the harness red, naming the reply it let through" {
    local g
    for g in "$COPY"/cases/link-verdict-honest-waits/graders/*.md; do
        grep -q 'type: regex' "$g" || continue
        printf -- '---\ntype: regex\nweight: 1\n---\n[\\s\\S]*\n' > "$g"
    done
    harness
    [ "$status" -eq 1 ]
    [[ "$output" == *"link-verdict-honest-waits.bad-nothing-waits.md PASSED every grader"* ]] || false
}

@test "link-next: a known-bad reply that is actually honest turns the harness red" {
    cp "$COPY/transcripts/next-empty-no-declined.good.md" "$COPY/transcripts/next-empty-no-declined.bad-declined.md"
    harness
    [ "$status" -eq 1 ]
    [[ "$output" == *"next-empty-no-declined.bad-declined.md PASSED every grader"* ]] || false
}

@test "link-next: a known-good reply the graders reject turns the harness red" {
    printf 'Nothing is waiting on you.\n' > "$COPY/transcripts/next-empty-no-declined.good-extra.md"
    harness
    [ "$status" -eq 1 ]
    [[ "$output" == *"good-extra.md fails grader"* ]] || false
}

@test "link-next: a case with no known-bad transcript fails instead of passing vacuously" {
    rm "$COPY"/transcripts/next-rows-chooser.bad-*.md
    harness
    [ "$status" -eq 1 ]
    [[ "$output" == *"next-rows-chooser: needs a known-good and at least one known-bad transcript"* ]] || false
}

@test "link-next: the sandbox copy of borg-link swaps one line, and a skill that lost its injection line fails" {
    harness
    [ "$status" -eq 0 ]
    [[ "$output" == *"differs from the shipped skill in exactly one line"* ]] || false

    local fake="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$fake"
    : > "$fake/borg.zsh"
    cp -R "${REPO_ROOT}/skills" "$fake/skills"
    grep -v '^!`NO_COLOR=1 borg link' "${REPO_ROOT}/skills/borg-link/SKILL.md" > "$fake/skills/borg-link/SKILL.md"
    harness "$fake"
    [ "$status" -eq 1 ]
    [[ "$output" == *"link-verdict-honest-waits: sandbox build failed"* ]] || false
}

@test "link-next: the sandbox copy of borg-next swaps one sentence, and a skill that lost it fails" {
    local fake="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$fake"
    : > "$fake/borg.zsh"
    cp -R "${REPO_ROOT}/skills" "$fake/skills"
    sed 's/with the Bash tool (it logs nothing)/with the shell/' "${REPO_ROOT}/skills/borg-next/SKILL.md" > "$fake/skills/borg-next/SKILL.md"
    harness "$fake"
    [ "$status" -eq 1 ]
    [[ "$output" == *"next-empty-no-declined: sandbox build failed"* ]] || false
}

@test "link-next: fixtures and cases carry only synthetic names" {
    run jq -r '[.rows[].project, .quiet[]] | unique | join(",")' "${REPO_ROOT}/evals/link-next/fixtures/next-rows.json" "${REPO_ROOT}/evals/link-next/fixtures/next-empty.json"
    [ "${lines[0]}" = "demo-api,demo-app" ]
    [ "${lines[1]}" = "demo-api,demo-app" ]
    run grep -rhoE '▸ IN FOCUS  [^ ]+' "${REPO_ROOT}/evals/link-next/fixtures"
    [ "$(printf '%s\n' "$output" | sort -u)" = '▸ IN FOCUS  demo-app' ]
    run grep -rEl '/Users/|@gmail|sk-[A-Za-z0-9]{10}|ghp_' "${REPO_ROOT}/evals/link-next" --exclude-dir=out
    [ "$status" -eq 1 ]
}

@test "link-next: the ledger maps both skills to this eval" {
    run jq -r '.items["skills/borg-link"].eval, .items["skills/borg-next"].eval' "${REPO_ROOT}/evals/ledger.json"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "evals/link-next" ]
    [ "${lines[1]}" = "evals/link-next" ]
    [ -x "${REPO_ROOT}/evals/link-next/run.sh" ] || [ -f "${REPO_ROOT}/evals/link-next/run.sh" ]
}

@test "link-next: the borg-next sandbox points every borg call at a stub that exits 0, once" {
    local sb="${BATS_TEST_TMPDIR}/sb"
    run bash "${REPO_ROOT}/evals/link-next/sandbox.sh" next-empty-no-declined "$sb"
    [ "$status" -eq 0 ]
    [ -x "$sb/bin/borg" ]
    run "$sb/bin/borg" next --declined
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run grep -cF "the executable at $sb/bin/borg," "$sb/skills/borg-next/SKILL.md"
    [ "$output" = "1" ]
    run grep -c 'declined' "$sb/skills/borg-next/SKILL.md"
    run grep -cF 'The reply to the user never contains the word "declined"' "$sb/skills/borg-next/SKILL.md"
    [ "$output" = "1" ]
}
