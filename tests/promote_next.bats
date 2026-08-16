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
