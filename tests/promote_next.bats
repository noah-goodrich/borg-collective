#!/usr/bin/env bats
# Tests for lib/promote-next.sh — chained auto-promotion candidate-scan and next-slug logic
# backing skills/borg-assimilate Step 4c.
#
# Decision outcomes (see lib/promote-next.sh for the full contract):
#   NOOP          — zero top-level candidates
#   AUTO <slug>   — a resolved *Next:* pointer, or exactly one top-level candidate
#   ASK <n>       — two or more candidates and no resolved *Next:* signal

load test_helper/setup

LIB="${BATS_TEST_DIRNAME}/../lib/promote-next.sh"

setup() {
    setup_temp_dirs
    DIR="${BATS_TEST_TMPDIR}/directives"
    mkdir -p "$DIR"
}

# Write a top-level directive (no *Parent plan:* line).
# Args: <slug>
_mk_top_level() {
    local slug="$1"
    printf '# Directive: %s\n\nSome body text.\n' "$slug" > "$DIR/$slug.md"
}

# Write a child directive carrying a *Parent plan:* line pointing at a shipped plan slug.
# Args: <slug> <parent_slug>
_mk_child() {
    local slug="$1" parent="$2"
    printf '# Directive: %s\n\n*Parent plan: %s*\n' "$slug" "$parent" > "$DIR/$slug.md"
}

# Write a "shipped plan" file (stands in for the just-archived PROJECT_PLAN.md) carrying
# an optional *Next: <slug>* pointer.
# Args: <path> <next_slug or empty>
_mk_shipped() {
    local path="$1" next="$2"
    if [ -n "$next" ]; then
        printf '# Shipped Plan\n\n*Next: %s*\n' "$next" > "$path"
    else
        printf '# Shipped Plan\n\nNo pointer here.\n' > "$path"
    fi
}

@test "promote_next: zero top-level candidates -> NOOP" {
    _mk_child "orphan" "some-other-plan"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR'"

    [ "$status" -eq 0 ]
    [ "$output" = "NOOP" ]
}

@test "promote_next: exactly one candidate -> AUTO <slug>" {
    _mk_top_level "only-candidate"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR'"

    [ "$status" -eq 0 ]
    [ "$output" = "AUTO only-candidate" ]
}

@test "promote_next: two-plus candidates, no *Next:* signal -> ASK <n>" {
    _mk_top_level "candidate-a"
    _mk_top_level "candidate-b"
    _mk_top_level "candidate-c"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR'"

    [ "$status" -eq 0 ]
    [ "$output" = "ASK 3" ]
}

@test "promote_next: resolved *Next:* pointer wins over count even with two-plus raw candidates" {
    _mk_top_level "candidate-a"
    _mk_top_level "candidate-b"
    _mk_top_level "chained-next"
    SHIPPED="${BATS_TEST_TMPDIR}/shipped-plan.md"
    _mk_shipped "$SHIPPED" "chained-next"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR' '$SHIPPED'"

    [ "$status" -eq 0 ]
    [ "$output" = "AUTO chained-next" ]
}

@test "promote_next: dangling *Next:* pointer to a nonexistent slug falls through to the count branch, does not crash" {
    _mk_top_level "candidate-a"
    _mk_top_level "candidate-b"
    SHIPPED="${BATS_TEST_TMPDIR}/shipped-plan.md"
    _mk_shipped "$SHIPPED" "no-such-directive"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR' '$SHIPPED'"

    [ "$status" -eq 0 ]
    [ "$output" = "ASK 2" ]
}

@test "promote_next: dangling *Next:* pointer with exactly one real candidate falls through to AUTO on the candidate" {
    _mk_top_level "only-candidate"
    SHIPPED="${BATS_TEST_TMPDIR}/shipped-plan.md"
    _mk_shipped "$SHIPPED" "no-such-directive"

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR' '$SHIPPED'"

    [ "$status" -eq 0 ]
    [ "$output" = "AUTO only-candidate" ]
}

@test "promote_next: missing directives directory -> NOOP, does not crash" {
    run bash -c "source '$LIB'; _borg_promote_next_decide '${BATS_TEST_TMPDIR}/does-not-exist'"

    [ "$status" -eq 0 ]
    [ "$output" = "NOOP" ]
}

@test "promote_next: shipped plan with no *Next:* line and one candidate -> AUTO <slug>" {
    _mk_top_level "only-candidate"
    SHIPPED="${BATS_TEST_TMPDIR}/shipped-plan.md"
    _mk_shipped "$SHIPPED" ""

    run bash -c "source '$LIB'; _borg_promote_next_decide '$DIR' '$SHIPPED'"

    [ "$status" -eq 0 ]
    [ "$output" = "AUTO only-candidate" ]
}

# ── Step 0.75: the child-directive gate ──────────────────────────────────────────────────────────
# These cover the defect measured 2026-09-15: Step 0.75 computed a slug from the objective prose,
# which cannot produce the hand-written archived filename, so the gate found 0 children where 9
# existed and was specified to proceed without comment. The slug is now DECLARED by
# PROJECT_PLAN.md's `- Plan-slug:` annotation (AC5.9, Ruling 1). Each behaviour is pinned in the
# firing direction AND the direction that proves it discriminates.

_mk_plan() {   # <path> <annotation-line-or-empty>
    if [ -n "$2" ]; then
        printf '# Project Plan\n*Established: 2026-08-24*\n\n%s\n\n## Objective\n\nMake borg link the single front door that answers from a clean read of derived fact.\n' "$2" > "$1"
    else
        printf '# Project Plan\n*Established: 2026-08-24*\n\n## Objective\n\nMake borg link the single front door that answers from a clean read of derived fact.\n' > "$1"
    fi
}

@test "step075: the slug is READ from the annotation, not computed from the objective" {
    local plan="${BATS_TEST_TMPDIR}/PROJECT_PLAN.md"
    _mk_plan "$plan" '- Plan-slug: `2026-08-24-one-front-door`'
    source "$LIB"
    run _borg_plan_declared_slug "$plan"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-08-24-one-front-door" ]
    # The objective would compute to something else entirely; it is never consulted.
    [[ "$output" != *"make-borg-link"* ]] || false
}

@test "step075: the bare (backtick-free) annotation form is accepted too" {
    local plan="${BATS_TEST_TMPDIR}/PROJECT_PLAN.md"
    _mk_plan "$plan" '- Plan-slug: 2026-08-24-one-front-door'
    source "$LIB"
    run _borg_plan_declared_slug "$plan"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-08-24-one-front-door" ]
}

@test "step075: a plan with no annotation FAILS LOUD instead of returning a guess" {
    local plan="${BATS_TEST_TMPDIR}/PROJECT_PLAN.md"
    _mk_plan "$plan" ""
    source "$LIB"
    run _borg_plan_declared_slug "$plan"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "step075: an annotation present but valueless is a refusal, not an empty slug" {
    source "$LIB"
    local plan
    for body in '- Plan-slug:' '- Plan-slug: ' '- Plan-slug: ``'; do
        plan="${BATS_TEST_TMPDIR}/p.md"
        _mk_plan "$plan" "$body"
        run _borg_plan_declared_slug "$plan"
        [ "$status" -ne 0 ] || { echo "accepted a valueless annotation: [$body]"; false; }
        [ -z "$output" ]
    done
}

@test "step075: prose mentioning the annotation does not win over the annotation" {
    # PROJECT_PLAN.md carries an explanatory paragraph about `- Plan-slug:` right beside the
    # annotation, so an unanchored match is a live hazard, not a hypothetical. Verified by mutation:
    # dropping the `^-` anchor makes this return the whole sentence as the "slug".
    local plan="${BATS_TEST_TMPDIR}/PROJECT_PLAN.md"
    printf '# Project Plan\n\nThis plan explains that Plan-slug: is how the slug is declared.\n\n- Plan-slug: `the-real-slug`\n' > "$plan"
    source "$LIB"
    run _borg_plan_declared_slug "$plan"
    [ "$status" -eq 0 ]
    [ "$output" = "the-real-slug" ]
}

@test "step075: an empty slug is rc 2, never zero matches" {
    _mk_child child-a 2026-08-24-real-slug
    source "$LIB"
    run _borg_child_directives "$DIR" ""
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    # Discriminates: the same directory WITH the slug finds the child.
    run _borg_child_directives "$DIR" 2026-08-24-real-slug
    [ "$status" -eq 0 ]
    [[ "$output" == *"child-a.md"* ]] || false
}

@test "step075: only directives parented to THIS slug are returned" {
    _mk_child mine   2026-08-24-real-slug
    _mk_child theirs 2026-01-01-other-plan
    _mk_top_level unparented
    source "$LIB"
    run _borg_child_directives "$DIR" 2026-08-24-real-slug
    [ "$status" -eq 0 ]
    [[ "$output" == *"mine.md"* ]] || false
    [[ "$output" != *"theirs.md"* ]] || false
    [[ "$output" != *"unparented.md"* ]] || false
}

@test "step075: a slug that is a PREFIX of another does not match it" {
    # `2026-08-24-front` must not match `*Parent plan: 2026-08-24-front-door*`.
    _mk_child longer 2026-08-24-front-door
    source "$LIB"
    run _borg_child_directives "$DIR" 2026-08-24-front
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "step075: a missing directives dir is zero children, not an error" {
    source "$LIB"
    run _borg_child_directives "${BATS_TEST_TMPDIR}/absent" 2026-08-24-real-slug
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "step075: an EMPTY-but-existing directives dir is zero children, not a fatal glob" {
    command -v zsh >/dev/null || skip "zsh not installed"
    # `[ -d ]` covers a MISSING directory; a directory that exists and holds no `.md` made the
    # earlier glob loop die under zsh NOMATCH with `no matches found`. Only zsh shows it — bash
    # leaves the literal and the `-f` test rejected it.
    mkdir -p "${BATS_TEST_TMPDIR}/empty"
    run zsh -c "emulate -L zsh; set -e; source '$LIB'; _borg_child_directives '${BATS_TEST_TMPDIR}/empty' a-slug"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "step075: the missing-dir guard survives zsh NOMATCH (pins what bash cannot)" {
    command -v zsh >/dev/null || skip "zsh not installed"
    # Under zsh an unmatched glob is FATAL, so this is the only interpreter in which deleting
    # `[ -d "$dir" ] || return 0` is observable. Verified by mutation: removing that line makes
    # this case fail with `no matches found` while all bash cases stay green.
    run zsh -c "emulate -L zsh; set -e; source '$LIB'; _borg_child_directives '${BATS_TEST_TMPDIR}/absent' a-slug"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "step075: the gate fires on THIS repository, cross-checked against an independent count" {
    # AC3 of the 2026-09-15 directive asks that the gate be proven on the live tree. It names nine
    # files; this asserts non-empty and agreement with a SEPARATE grep instead of pinning 9, because
    # a hard count goes red the next time any directive is filed or resolved -- the number is a fact
    # about the repo's backlog, not about this code.
    local root="${BATS_TEST_DIRNAME}/.."
    source "$LIB"
    local slug
    slug=$(_borg_plan_declared_slug "$root/PROJECT_PLAN.md") || skip "no active PROJECT_PLAN.md"
    local via_helper via_grep
    via_helper=$(_borg_child_directives "$root/docs/plans/directives" "$slug" | wc -l | tr -d ' ')
    via_grep=$(grep -lF "*Parent plan: ${slug}*" "$root"/docs/plans/directives/*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$via_helper" -gt 0 ] || { echo "gate found no children on the live tree"; false; }
    [ "$via_helper" -eq "$via_grep" ] || { echo "helper=$via_helper grep=$via_grep"; false; }
}
