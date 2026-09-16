#!/usr/bin/env bats
# Contracts over PROSE — the class of defect CI could not see.
#
# WHY THIS FILE EXISTS. On 2026-09-15/16 this repository shipped five defects with five green lanes
# every time. Every one of them lived in markdown: a stray line above a SKILL.md's frontmatter, the
# deletion of the sentence that makes Step 0.75 a gate, two rival slug annotations in one plan, a
# directive whose parent line used a convention the gate cannot read, and a slug interpolated into a
# grep regex. The suite ran 805 bats and 1176 pytest against zsh, borg_core and the hooks -- and
# asserted NOTHING about the prose those tools read. `tests/skill_frontmatter.bats` closed the first
# two. This file closes the rest.
#
# Every case is paired with the direction that proves it discriminates, because a contract that
# cannot fail is the defect it is meant to catch, one layer up.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    LIB="${REPO_ROOT}/lib/promote-next.sh"
}

# ── The plan declares its slug exactly once ──────────────────────────────────────────────────────

@test "plan: PROJECT_PLAN.md declares exactly one slug annotation" {
    # Two annotations for one fact shipped on 2026-09-15: #199 added `- Plan-slug:` and #203 added
    # `*Archived-as:*`, git merged them CLEANLY, and the plan carried both with identical values
    # while /borg-plan was told to write both. No conflict marker, no gate.
    local n
    n=$(grep -c '^- Plan-slug:' "${REPO_ROOT}/PROJECT_PLAN.md")
    [ "$n" -eq 1 ] || { echo "expected exactly 1 '- Plan-slug:' line, found $n"; false; }
}

@test "plan: the retired *Archived-as:* form appears in no plan or skill" {
    # Scoped to the surfaces a writer reads. lib/promote-next.sh names the retired form ON PURPOSE,
    # in the docstring that records why it was retired, so it is excluded by path rather than by a
    # cleverer pattern -- a historical note is not a live convention.
    local hits
    hits=$(grep -rln 'Archived-as' "${REPO_ROOT}/PROJECT_PLAN.md" "${REPO_ROOT}/skills" 2>/dev/null || true)
    [ -z "$hits" ] || { echo "retired annotation still live in: $hits"; false; }
}

@test "plan: the annotation check is looking at a real file with a real value" {
    # The floor for the floor: both cases above pass trivially against a missing or empty plan.
    [ -f "${REPO_ROOT}/PROJECT_PLAN.md" ]
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${REPO_ROOT}/PROJECT_PLAN.md'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# ── Directives name their parent in the form the gate reads ──────────────────────────────────────

@test "directives: every parent is declared as *Parent plan: <slug>*" {
    # The design-doc skill writes `*Filed: <date> · Status: <s> · Parent: <slug>*`; Step 0.75 greps
    # `^\*Parent plan: <slug>\*`. A directive written with the skill was therefore INVISIBLE to the
    # gate -- measured 2026-09-16, when merging the Step 0.75 directive moved the blocker count from
    # 9 to 9. Two other files were in the same state.
    local bad=""
    for f in "${REPO_ROOT}"/docs/plans/directives/*.md; do
        [ -f "$f" ] || continue
        if grep -q '^\*Filed:.*·[[:space:]]*Parent:' "$f" && ! grep -q '^\*Parent plan:' "$f"; then
            bad="${bad}\n  ${f##*/}"
        fi
    done
    [ -z "$bad" ] || { printf "directives invisible to Step 0.75:%b\n" "$bad"; false; }
}

@test "directives: a design-doc-style parent line IS detected as invisible" {
    # The discriminating direction. Without it the case above passes on an empty directory, on a
    # typo'd glob, and on a pattern that matches nothing.
    local d="${BATS_TEST_TMPDIR}/d"
    mkdir -p "$d"
    printf '# Directive: X\n\n*Filed: 2026-09-16 · Status: Proposed · Parent: some-plan*\n' > "$d/bad.md"
    run bash -c "grep -q '^\*Filed:.*·[[:space:]]*Parent:' '$d/bad.md' && ! grep -q '^\*Parent plan:' '$d/bad.md'"
    [ "$status" -eq 0 ]
}

@test "directives: a directive naming a parent in ANY form is never a top-level candidate" {
    # The second consequence of the same defect: _borg_promote_next_candidates reads "no
    # ^*Parent plan:" as TOP-LEVEL, so Step 4c offered a CHILD directive for auto-promotion.
    #
    # THE OBVIOUS VERSION OF THIS TEST IS A TAUTOLOGY AND I SHIPPED IT FIRST. Asking whether a
    # candidate lacks `^\*Parent plan:` re-states the function's own selection rule, so it passes
    # for every input and survived its mutation while the other six went red. The invariant that
    # actually has teeth is about the FACT, not the syntax: a file that names a parent in ANY
    # recognised form must not be offered as top-level, so reverting one to the design-doc form
    # turns this red.
    source "$LIB"
    local cand f
    cand=$(_borg_promote_next_candidates "${REPO_ROOT}/docs/plans/directives")
    for slug in $cand; do
        f="${REPO_ROOT}/docs/plans/directives/${slug}.md"
        [ -f "$f" ] || continue
        if grep -q '^\*Parent plan:' "$f" || grep -q '^\*Filed:.*·[[:space:]]*Parent:' "$f"; then
            echo "directive naming a parent offered as top-level: $slug"
            false
        fi
    done
}

# ── The child scan matches the slug LITERALLY ────────────────────────────────────────────────────

@test "gate: a slug containing a regex metacharacter matches only its own file" {
    # `.` matched any character, so `a.b` also returned `aXb` -- a child that does not exist.
    local d="${BATS_TEST_TMPDIR}/m"
    mkdir -p "$d"
    printf '# X\n*Parent plan: 2026-01-01-alpha.beta*\n' > "$d/real.md"
    printf '# Y\n*Parent plan: 2026-01-01-alphaXbeta*\n' > "$d/decoy.md"
    source "$LIB"
    run _borg_child_directives "$d" "2026-01-01-alpha.beta"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
    [[ "$output" == *"real.md"* ]]
    [[ "$output" != *"decoy.md"* ]]
}

@test "gate: a slug that is an INVALID regex still finds its child" {
    # The serious direction. `a[b` made grep fail, the file was dropped, and the function returned
    # rc 0 with ZERO children -- "no open children, safe to ship" while a child existed. That is the
    # certify-instead-of-gate defect re-entering through the PATTERN rather than the slug.
    local d="${BATS_TEST_TMPDIR}/b"
    mkdir -p "$d"
    printf '# Z\n*Parent plan: 2026-01-01-a[b*\n' > "$d/bracket.md"
    source "$LIB"
    run _borg_child_directives "$d" "2026-01-01-a[b"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
    [[ "$output" == *"bracket.md"* ]]
}

@test "gate: a trailing-content parent line is NOT a match" {
    # `-x` is stricter than the old leading `^`, which also matched `*Parent plan: X* (see also)`.
    local d="${BATS_TEST_TMPDIR}/t"
    mkdir -p "$d"
    printf '# T\n*Parent plan: real-slug* and some trailing prose\n' > "$d/trailing.md"
    source "$LIB"
    run _borg_child_directives "$d" "real-slug"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── The lifecycle skills still invoke the manifest CLI (AC5.2) ───────────────────────────────────

@test "skills: all three lifecycle skills invoke borg_core.manifest.cli" {
    # AC5.2 shipped as prose in three SKILL.md files with NO oracle behind it -- the same gap that
    # let the other four defects through, added one step later by the session that had just
    # finished reporting the gap. A future edit could delete every invocation and stay green.
    local f n
    for f in borg-plan borg-link-up borg-assimilate; do
        n=$(grep -c 'borg_core\.manifest\.cli' "${REPO_ROOT}/skills/${f}/SKILL.md" || true)
        [ "$n" -ge 1 ] || { echo "skills/${f}/SKILL.md no longer invokes borg_core.manifest.cli"; false; }
    done
}

@test "skills: the invocation check would notice a skill that lost it" {
    local tmp="${BATS_TEST_TMPDIR}/SKILL.md"
    printf -- '---\nname: x\n---\n\nNo invocation here.\n' > "$tmp"
    run bash -c "grep -c 'borg_core\.manifest\.cli' '$tmp'"
    [ "$output" = "0" ]
}
