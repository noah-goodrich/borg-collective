#!/usr/bin/env bats
# Tier 1 load check for Cortex (AC1 of PROJECT_PLAN.md, tracking issue #480). Cortex Code CLI silently skips a skill or
# agent whose `description:` is a folded (`>`) or literal (`|`) block scalar: `cortex plugin validate` reports "Invalid
# YAML", and the file never registers (how borg-grunt and borg-scout went missing, fixed in #471 and #474). Claude Code
# accepts both forms, so nothing else in CI notices. This file runs no model and no `cortex`; it reads frontmatter.
# tests/agent_frontmatter.bats pins the other agent rules (name, model); the description rule for skills and agents
# lives here, in one place, so both are held to the same reader.

ROOT="${BATS_TEST_DIRNAME}/.."

# Print one line per problem with the description of the file $1, nothing when it is a single-line scalar.
# Frontmatter is the block between the first two `---` lines. Problems: no description, more than one, an empty value,
# a block scalar header (`>`, `>-`, `>+`, `|`, `|-`, `|+`), or a value that continues on an indented next line.
_description_problems() {
    awk '
        NR == 1 { if ($0 != "---") { print "no frontmatter"; bad = 1; exit } next }
        /^---$/ { exit }
        /^description:/ {
            count++
            v = $0; sub(/^description:[ \t]*/, "", v)
            if (v == "") print "description is empty or has its value on the next line"
            else if (v ~ /^[>|][-+0-9]*[ \t]*$/) print "description is a block scalar (" v ")"
            grab = 1; next
        }
        grab && /^[ \t]+[^ \t]/ { print "description continues on a second line"; next }
        { grab = 0 }
        END {
            if (!bad && count == 0) print "no description"
            if (count > 1) print "description appears " count " times"
        }
    ' "$1"
}

# Every file under skills/ and agents/ that Cortex would read, with the problems found; exit 1 when there are any.
_check_all() {
    local f p bad=0
    for f in "$ROOT"/skills/*/SKILL.md "$ROOT"/agents/*.md; do
        [ -f "$f" ] || continue
        p=$(_description_problems "$f")
        if [ -n "$p" ]; then
            echo "${f#"$ROOT"/}: $p"
            bad=1
        fi
    done
    return "$bad"
}

@test "cortex load: the check is looking at a non-empty set of skills and agents" {
    local s a
    s=$(find "$ROOT/skills" -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')
    a=$(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    [ "$s" -ge 10 ] || { echo "only $s SKILL.md found"; false; }
    [ "$a" -ge 3 ] || { echo "only $a agents found"; false; }
}

@test "cortex load: every skill and agent description is a single-line scalar" {
    run _check_all
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

# The shadow of the case above: a grader that has never failed proves nothing (docs/agents/testing-tiers.md, rule 2).
_fixture() {
    mkdir -p "$BATS_TEST_TMPDIR/fx"
    printf '%s\n' "$2" > "$BATS_TEST_TMPDIR/fx/$1.md"
    echo "$BATS_TEST_TMPDIR/fx/$1.md"
}

@test "cortex load: a one-line double-quoted description is accepted" {
    local f
    f=$(_fixture ok $'---\nname: x\ndescription: "Does a thing. Use when \\"asked\\"."\nuser-invocable: true\n---\nbody')
    [ -z "$(_description_problems "$f")" ]
}

@test "cortex load: a folded description turns the check red" {
    local f
    f=$(_fixture folded $'---\nname: x\ndescription: >\n  Does a thing.\n  More text.\nuser-invocable: true\n---\nbody')
    run _description_problems "$f"
    [[ "$output" == *"block scalar (>)"* ]] || { echo "$output"; false; }
    [[ "$output" == *"continues on a second line"* ]] || { echo "$output"; false; }
}

@test "cortex load: every folded and literal header form is rejected" {
    local h f
    for h in '>' '>-' '>+' '|' '|-' '|+'; do
        f=$(_fixture "hdr" "---"$'\n'"name: x"$'\n'"description: $h"$'\n'"  Text."$'\n'"---")
        [[ "$(_description_problems "$f")" == *"block scalar"* ]] || { echo "header $h accepted"; false; }
    done
}

@test "cortex load: a missing, empty or doubled description turns the check red" {
    local f
    f=$(_fixture none $'---\nname: x\n---\nbody')
    [[ "$(_description_problems "$f")" == *"no description"* ]] || false
    f=$(_fixture empty $'---\nname: x\ndescription:\n---\nbody')
    [[ "$(_description_problems "$f")" == *"empty"* ]] || false
    f=$(_fixture twice $'---\nname: x\ndescription: "a"\ndescription: "b"\n---\nbody')
    [[ "$(_description_problems "$f")" == *"appears 2 times"* ]] || false
}

@test "cortex load: a plain multi-line description turns the check red" {
    local f
    f=$(_fixture plain $'---\nname: x\ndescription: Does a thing and\n  keeps going here.\n---\nbody')
    [[ "$(_description_problems "$f")" == *"continues on a second line"* ]] || false
}

@test "cortex load: text after the frontmatter is not read as the description" {
    local f
    f=$(_fixture body $'---\nname: x\ndescription: "ok"\n---\ndescription: >\n  not frontmatter')
    [ -z "$(_description_problems "$f")" ]
}
