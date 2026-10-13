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

@test "borg-resume: status --json runs first, before any CronCreate" {
    grep -q 'borg-resume status --all --json' "$RESUME"
    local s c
    s="$(grep -n 'borg-resume status --all --json' "$RESUME" | head -1 | cut -d: -f1)"
    c="$(grep -n 'CronCreate' "$RESUME" | head -1 | cut -d: -f1)"
    [ "$s" -lt "$c" ]
}

@test "borg-resume: CronCreate is only the fallback, recurring:false, no-double-run prompt" {
    grep -q 'CronCreate' "$RESUME"
    grep -qi 'fallback' "$RESUME"
    grep -q 'recurring: false' "$RESUME"
    grep -qi 'already finished or was resumed, do nothing' "$RESUME"
}

@test "borg-resume: records are matched by scope or sid, terminal records block the fallback" {
    grep -q 'scope == "workflow:<runId>"' "$RESUME"
    grep -q 'CLAUDE_CODE_SESSION_ID' "$RESUME"
    grep -q 'do NOT `CronCreate`' "$RESUME"
}

@test "borg-resume: fallback is refused when paused, disabled, or status errors" {
    grep -q 'Do not use the fallback while `paused` or `disabled_env` is true' "$RESUME"
    grep -q 'exits non-zero' "$RESUME"
    grep -q 'launchctl list | grep borg.resume-watch' "$RESUME"
}

@test "borg-resume: no create_trigger" {
    run grep -q 'create_trigger' "$RESUME"
    [ "$status" -ne 0 ]
}

@test "borg-resume: no send_later" {
    run grep -q 'send_later' "$RESUME"
    [ "$status" -ne 0 ]
}

@test "borg-resume: no unpredictable-limit framing" {
    run grep -qi 'unpredictable' "$RESUME"
    [ "$status" -ne 0 ]
}

@test "borg-resume: names resumeFromRunId and SendMessage; workflow agents never SendMessaged" {
    grep -q 'resumeFromRunId' "$RESUME"
    grep -q 'SendMessage' "$RESUME"
    grep -qi 'workflow agents are never SendMessaged' "$RESUME"
}

@test "borg-resume: documents only CLI verbs that exist; kill switch named" {
    local v
    for v in status cancel pause unpause run ack defer; do grep -q "borg-resume $v" "$RESUME"; done
    run grep -Eq 'run --now|run --print|borg-resume log' "$RESUME"
    [ "$status" -ne 0 ]
    grep -q 'DISABLED' "$RESUME"
    grep -q 'BORG_RESUME_DISABLE=1' "$RESUME"
}

@test "borg-resume: keeps the honest caveats" {
    grep -qi 'lost if the session exits' "$RESUME"
    grep -qi 'session model' "$RESUME"
    grep -q 'RemoteTrigger' "$RESUME"
    grep -qi 'fresh cloud session' "$RESUME"
}
