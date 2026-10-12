#!/usr/bin/env bats
# Contracts for agents/borg-verifier.md, skills/borg-verify, skills/borg-resume.

ROOT="${BATS_TEST_DIRNAME}/.."
VERIFIER="$ROOT/agents/borg-verifier.md"
VERIFY="$ROOT/skills/borg-verify/SKILL.md"
RESUME="$ROOT/skills/borg-resume/SKILL.md"

fm() { awk '/^---$/{n++; next} n==1' "$1"; }

@test "verifier: frontmatter pins sonnet/high with read-only tools" {
    [ -f "$VERIFIER" ]
    run fm "$VERIFIER"
    echo "$output" | grep -qx 'name: borg-verifier'
    echo "$output" | grep -qx 'model: sonnet'
    echo "$output" | grep -qx 'effort: high'
    echo "$output" | grep -qx 'tools: Bash, Read, Grep, Glob'
    ! echo "$output" | grep -Eq '^tools:.*(Edit|Write)'
}

@test "verifier: description names the evaluator role" {
    run fm "$VERIFIER"
    echo "$output" | grep -qi 'independent pre-merge evaluator'
    echo "$output" | grep -q 'PASS/FAIL'
}

@test "borg-verify: spawns borg-collective:borg-verifier" {
    grep -q 'borg-collective:borg-verifier' "$VERIFY"
}

@test "borg-verify: no bare borg-nanoprobe reference remains" {
    run bash -c "grep -n 'borg-nanoprobe' '$VERIFY' | grep -v 'borg-collective:borg-nanoprobe'"
    [ "$status" -ne 0 ]
}

@test "borg-resume: uses CronCreate, not create_trigger/send_later" {
    grep -q 'CronCreate' "$RESUME"
    ! grep -q 'create_trigger' "$RESUME"
    ! grep -q 'send_later' "$RESUME"
}

@test "borg-resume: states the three caveats" {
    grep -qi 'lost if the session exits' "$RESUME"
    grep -qi 'session model' "$RESUME"
    grep -q 'RemoteTrigger' "$RESUME"
    grep -qi 'fresh cloud session' "$RESUME"
}
