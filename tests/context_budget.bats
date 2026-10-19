#!/usr/bin/env bats
# Context budgets (context-diet directive, AC2). A skill body loads on every invocation, so its size is a
# cost every run pays. This file holds the caps; each is a byte count (`wc -c`), checked against the file
# on disk. The CLAUDE.md cases below keep the context-diet cut from growing back.

load test_helper/setup

SKILL_DIR="${BORG_HOME}/skills/borg-link"

# AC4 caps a repository-scope run at 9,216 bytes into context: SKILL.md plus the 920 B pipe output.
SKILL_CAP=8192

@test "budget: skills/borg-link/SKILL.md is at most 8192 bytes" {
    local size
    size="$(wc -c < "${SKILL_DIR}/SKILL.md")"
    [ "$size" -le "$SKILL_CAP" ] || {
        echo "SKILL.md is ${size} bytes, over the ${SKILL_CAP} cap" >&2
        false
    }
}

@test "budget: the references files exist and SKILL.md routes to the two it reads" {
    [ -s "${SKILL_DIR}/references/questions.md" ]
    [ -s "${SKILL_DIR}/references/queen-view.md" ]
    [ -s "${SKILL_DIR}/references/fallback.md" ]
    [ -s "${SKILL_DIR}/references/rationale.md" ]
    run cat "${SKILL_DIR}/SKILL.md"
    [[ "$output" == *'references/questions.md'* ]] || false
    [[ "$output" == *'references/fallback.md'* ]] || false
}

# The top-level CLAUDE.md loads into every session in this repository. A nested CLAUDE.md loads only when a file in
# its directory is read, so it may be longer, but not without bound.
ROOT_CLAUDE_CAP=8192
NESTED_CLAUDE_CAP=12288

@test "budget: the top-level CLAUDE.md is at most 8192 bytes" {
    local size
    size="$(wc -c < "${BORG_HOME}/CLAUDE.md")"
    [ "$size" -le "$ROOT_CLAUDE_CAP" ] || {
        echo "CLAUDE.md is ${size} bytes, over the ${ROOT_CLAUDE_CAP} cap" >&2
        false
    }
}

@test "budget: every other tracked CLAUDE.md is at most 12288 bytes" {
    local f size over=0
    while IFS= read -r f; do
        [ "$f" = "CLAUDE.md" ] && continue
        size="$(wc -c < "${BORG_HOME}/${f}")"
        if [ "$size" -gt "$NESTED_CLAUDE_CAP" ]; then
            echo "${f} is ${size} bytes, over the ${NESTED_CLAUDE_CAP} cap" >&2
            over=1
        fi
    done < <(git -C "$BORG_HOME" ls-files '*CLAUDE.md' | grep -v '^tests/fixtures/')
    [ "$over" -eq 0 ]
}

@test "budget: every docs/agents file the CLAUDE.md index names exists" {
    local f n=0
    while IFS= read -r f; do
        n=$((n + 1))
        [ -s "${BORG_HOME}/${f}" ] || { echo "index names ${f}, which is missing or empty" >&2; false; }
    done < <(grep -o 'docs/agents/[a-z-]*\.md' "${BORG_HOME}/CLAUDE.md" | sort -u)
    [ "$n" -ge 1 ]
}

@test "budget: every nested CLAUDE.md the index names exists" {
    local f n=0
    while IFS= read -r f; do
        n=$((n + 1))
        [ -s "${BORG_HOME}/${f}" ] || { echo "index names ${f}, which is missing or empty" >&2; false; }
    done < <(grep -o '[a-z_/]*/CLAUDE\.md' "${BORG_HOME}/CLAUDE.md" | sort -u)
    [ "$n" -ge 1 ]
}
