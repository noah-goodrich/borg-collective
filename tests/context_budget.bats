#!/usr/bin/env bats
# Context budgets (context-diet directive, AC2). A skill body loads on every invocation, so its size is a
# cost every run pays. This file holds the caps; each is a byte count (`wc -c`), checked against the file
# on disk. S4b adds the SKILL.md cap; a later slice adds the CLAUDE.md cases to this same file.

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

@test "budget: the three references files exist and SKILL.md routes to the two it reads" {
    [ -s "${SKILL_DIR}/references/queen-view.md" ]
    [ -s "${SKILL_DIR}/references/fallback.md" ]
    [ -s "${SKILL_DIR}/references/rationale.md" ]
    run cat "${SKILL_DIR}/SKILL.md"
    [[ "$output" == *'references/queen-view.md'* ]] || false
    [[ "$output" == *'references/fallback.md'* ]] || false
}
