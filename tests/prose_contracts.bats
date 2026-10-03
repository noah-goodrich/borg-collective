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
    PLAN_FIXTURES="${BATS_TEST_DIRNAME}/fixtures/plan"
}

# ── The plan declares its slug exactly once ──────────────────────────────────────────────────────
#
# NO ACTIVE PLAN IS A LEGAL STATE, and asserting otherwise made assimilation impossible. The slot is
# single by design and promotion is strictly serial, so between the commit that archives a plan and
# the commit that promotes the next one, `PROJECT_PLAN.md` DOES NOT EXIST. `/borg-assimilate`
# archives by renaming it into `docs/plans/assimilated/`, which is exactly what PR #230 does --
# one `R097` rename and nothing else -- and this file's own floor case hard-asserted `[ -f
# "${REPO_ROOT}/PROJECT_PLAN.md" ]`, so the shipping PR for every completed plan was red by
# construction. Measured on #230: `not ok 614` and `not ok 616` with the other four lanes green.
#
# The two concerns were conflated and are now separated. "Does the live plan declare its slug
# exactly once" is a question about THIS REPOSITORY and is conditional on a plan existing. "Does the
# checker discriminate" is a question about `_borg_plan_declared_slug` and must hold at every moment,
# including between plans -- so it is asked against FIXTURES, which also makes it a stronger test: it
# exercises the zero-annotation and two-annotation directions that a live plan, being correct, never
# supplies.

@test "plan: PROJECT_PLAN.md declares exactly one slug annotation" {
    # Two annotations for one fact shipped on 2026-09-15: #199 added `- Plan-slug:` and #203 added
    # `*Archived-as:*`, git merged them CLEANLY, and the plan carried both with identical values
    # while /borg-plan was told to write both. No conflict marker, no gate.
    #
    # SKIPPED, NOT PASSED, when there is no active plan -- a silent pass here would be the vacuous
    # green the floor case below exists to forbid, and a skip says which of the two states we are in.
    if [ ! -f "${REPO_ROOT}/PROJECT_PLAN.md" ]; then
        skip "no active plan (between assimilation and the next promotion)"
    fi
    local n
    n=$(grep -c '^- Plan-slug:' "${REPO_ROOT}/PROJECT_PLAN.md")
    [ "$n" -eq 1 ] || { echo "expected exactly 1 '- Plan-slug:' line, found $n"; false; }
}

@test "plan: an active plan's declared slug is readable by the gate" {
    # The other half of the live-plan question: one annotation that the gate cannot parse is as bad
    # as two. Conditional for the same reason as above.
    if [ ! -f "${REPO_ROOT}/PROJECT_PLAN.md" ]; then
        skip "no active plan (between assimilation and the next promotion)"
    fi
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${REPO_ROOT}/PROJECT_PLAN.md'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "plan: the retired *Archived-as:* form appears in no plan or skill" {
    # Scoped to the surfaces a writer reads. lib/promote-next.sh names the retired form ON PURPOSE,
    # in the docstring that records why it was retired, so it is excluded by path rather than by a
    # cleverer pattern -- a historical note is not a live convention.
    local hits
    hits=$(grep -rln 'Archived-as' "${REPO_ROOT}/PROJECT_PLAN.md" "${REPO_ROOT}/skills" 2>/dev/null || true)
    [ -z "$hits" ] || { echo "retired annotation still live in: $hits"; false; }
}

@test "plan: the annotation check discriminates -- one annotation is read" {
    # THE FLOOR FOR THE FLOOR, moved off the live plan. Its job is to prove the cases above cannot
    # pass vacuously, and that proof must not itself depend on a plan being active -- the state in
    # which the cases above skip is precisely when a broken checker would go unnoticed.
    [ -f "${PLAN_FIXTURES}/one-annotation.md" ]
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${PLAN_FIXTURES}/one-annotation.md'"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-01-01-fixture-plan" ]
}

@test "plan: the annotation check discriminates -- no annotation is refused" {
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${PLAN_FIXTURES}/no-annotation.md'"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "plan: the annotation check discriminates -- a PRESENT but empty annotation is refused" {
    # Distinct from the no-annotation case, and the distinction is load-bearing. Here the line
    # EXISTS, so `grep -m1` succeeds and the no-annotation guard never fires; only the `-n` check
    # after the backtick-unwrap refuses it. Verified by mutation: delete that check and, without
    # this case, the whole suite stays green.
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${PLAN_FIXTURES}/empty-annotation.md'"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "plan: the annotation check discriminates -- a missing file is refused" {
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${PLAN_FIXTURES}/does-not-exist.md'"
    [ "$status" -ne 0 ]
}

@test "plan: two rival annotations are caught by the count, not by the reader" {
    # `_borg_plan_declared_slug` uses `grep -m1`, so it reads the FIRST of two and reports success --
    # which is why the count check is a separate case and not folded into the reader. This pins that
    # division of labour, so a future "fix" to the reader cannot quietly make the count check
    # redundant, nor the reverse.
    local n
    n=$(grep -c '^- Plan-slug:' "${PLAN_FIXTURES}/two-annotations.md")
    [ "$n" -eq 2 ]
    run bash -c "source '$LIB'; _borg_plan_declared_slug '${PLAN_FIXTURES}/two-annotations.md'"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-01-01-fixture-plan" ]
}

# ── The checkpoint name comes from code, not from prose ─────────────────────────────────────────
#
# AC1 of 2026-09-28-state-hygiene-reader-census. `skills/borg-link-up/SKILL.md` used to say "run
# `date +%Y-%m-%d-%H%M` and use its literal stdout" -- minute resolution, nothing session-specific,
# and the existence guard beside it checked only the CURRENT directory. Two sessions in two
# worktrees of one clone each found the name free and both wrote it: three filenames exist twice on
# the live registry with different bodies, two pairs inside the same minute.
#
# THESE CASES GUARD THE PROSE, which is the only place the regression can happen. The generator is
# pinned by borg_core/checkpoint/test_core.py; nothing there can stop a future edit from putting a
# `date` call back into the skill, and a `date` call in the skill silently reopens the collision.

@test "checkpoint: no skill composes a checkpoint timestamp itself" {
    local hits
    hits=$(grep -rln 'date +%Y-%m-%d-%H%M' "${REPO_ROOT}/skills" 2>/dev/null || true)
    [ -z "$hits" ] || { echo "a skill still composes a checkpoint timestamp: $hits"; false; }
}

@test "checkpoint: borg-link-up delegates the name to borg checkpoint-name" {
    # The paired direction: the case above passes trivially if the skill simply stopped naming the
    # file at all. This one proves the delegation is present, not merely that the old call is gone.
    grep -q 'borg checkpoint-name' "${REPO_ROOT}/skills/borg-link-up/SKILL.md"
}

@test "checkpoint: the verb exists in the CLI and in borg help" {
    # A skill instructing a command that does not exist is worse than the prose it replaced, and
    # `borg help` is this repo's stated surface of record.
    grep -q 'checkpoint-name)' "${REPO_ROOT}/borg.zsh"
    run bash -c "grep -c 'checkpoint-name' '${REPO_ROOT}/borg.zsh'"
    [ "$output" -ge 2 ]
}

@test "checkpoint: the emitted stem carries second resolution and a session tag" {
    # End to end through the real verb, with a known session id, so the contract the skill relies on
    # is asserted against the CLI rather than against the library it happens to call today.
    run env CLAUDE_CODE_SESSION_ID=deadbeef-0000-0000-0000-000000000000 \
        "${REPO_ROOT}/borg.zsh" checkpoint-name
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-deadbe$ ]]
}

@test "checkpoint: the stem degrades to a bare timestamp with no session, and still exits 0" {
    # An unnamed checkpoint is a lost checkpoint, so a missing session id must never be an error.
    run env -u CLAUDE_CODE_SESSION_ID "${REPO_ROOT}/borg.zsh" checkpoint-name
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$ ]]
}

# ── The hook-language rule states its own inversion ─────────────────────────────────────────────
#
# The 2026-08-11 toolchain directive ratified "Hooks stay shell -- permanently, and this is arithmetic rather than
# preference" on a measurement of EMPTY interpreters. Measured 2026-10-02 on the shipped artifact that comparison
# inverts: hooks/bash-guard.sh costs more than python3's entire startup in every 20-run mean on both machines
# measured. These cases pin that DIRECTION and never a figure, which differs per machine.
#
# A rule that QUALIFIES a ratified decision is the single most likely thing to be silently re-simplified back to
# the original -- someone reads "hooks stay shell", does not find the qualification, and re-states the narrow
# version as the whole truth.

@test "hooks: CLAUDE.md states the subprocess-count rule for hook language" {
    grep -q 'SUBPROCESS COUNT' "${REPO_ROOT}/CLAUDE.md"
    grep -q 'At most one helper process' "${REPO_ROOT}/CLAUDE.md"
    grep -q 'Never node or ruby in a hook body' "${REPO_ROOT}/CLAUDE.md"
}

@test "hooks: the rule names what it qualifies and pins the direction, not a figure" {
    grep -q 'QUALIFIES a ratified' "${REPO_ROOT}/CLAUDE.md"
    grep -q "costs MORE than Python's" "${REPO_ROOT}/CLAUDE.md"
    grep -q "entire interpreter startup" "${REPO_ROOT}/CLAUDE.md"
    grep -q 'Hooks stay shell' "${REPO_ROOT}/CLAUDE.md"
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

# ── The shim layer (AC1) ─────────────────────────────────────────────────────────────────────────
#
# A prose criterion with no mechanical check is the thing this repository keeps shipping. The shim
# directive's own verify clause was "a reader can name which tier a new shim belongs in without
# reading source", which nothing can fail.
#
# THE FIRST VERSION OF THESE CASES WAS ITSELF COARSE, and three of six mutations survived it. It
# grepped the WHOLE of CLAUDE.md, a ~900-line file where `recon-adapter-<source>`, `prose
# extension` and `absent file` all already appear in other sections — so deleting the shim section's
# copy left the greps green. That is the identical defect as pinning a specific criterion to a
# 165-case suite. Every case below extracts the SECTION first and greps only inside it.

_shim_section() {
    # From the section's own heading to the start of the next top-level bullet. Anchored on the
    # heading text rather than a line number, because line numbers in CLAUDE.md drift constantly.
    sed -n '/^- \*\*THE SHIM LAYER: two tiers, one direction\.\*\*/,/^- \*\*`prefer-tool` extensions/p' \
        "${REPO_ROOT}/CLAUDE.md"
}

@test "shim: the section this suite greps actually exists, and is bounded at BOTH ends" {
    # Guards the guard in both directions. Too SHORT: the heading was reworded, every case below
    # greps an empty string and passes vacuously -- how the first draft of this suite failed. Too
    # LONG: the END anchor (the `prefer-tool` bullet, which this section has no relationship to) was
    # reworded or removed, and the sed range runs to end-of-file -- measured at 308 lines, at which
    # point cases 2-4 are whole-file greps again and the recon section supplies `recon-adapter-<source>`
    # from inside the widened window. A floor alone cannot see that; the ceiling can.
    local n
    n=$(_shim_section | wc -l | tr -d ' ')
    [ "$n" -ge 15 ] || { echo "shim section not found or too short ($n lines)"; false; }
    [ "$n" -le 40 ] || { echo "shim section unbounded: $n lines -- did the end anchor move?"; false; }
}

@test "shim: the section names both tiers AND the rule that chooses between them" {
    local s; s=$(_shim_section)
    [[ "$s" == *'recon-adapter-<source>'* ]] || { echo "executable tier not named"; false; }
    [[ "$s" == *'Prose extensions'* ]] || { echo "prose tier not named"; false; }
    [[ "$s" == *'MUST happen ships as an executable adapter'* ]] \
        || { echo "the rule choosing between tiers is missing"; false; }
}

@test "shim: the section states the one-directional rule" {
    local s; s=$(_shim_section)
    [[ "$s" == *'employer plugin never'* ]] || { echo "the one-way rule is not stated"; false; }
}

@test "shim: the section says a shim is closed by an absent file, not a probe" {
    # The directive is explicit that a `command -v borg` probe is the WRONG fix, because it hands
    # teammates a dead code path. That reasoning is the part a future reader will otherwise undo.
    local s; s=$(_shim_section)
    [[ "$s" == *'ABSENT FILE'* ]] || { echo "absent-file rule missing"; false; }
    [[ "$s" == *'command -v borg'* ]] || { echo "the rejected probe alternative is not named"; false; }
}
