#!/usr/bin/env bats
# The orchestrator prompt text must name the namespaced nanoprobe agent and must not tell the
# orchestrator to pass background/model/effort (the agent frontmatter sets them).

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "borg.zsh orchestration prompt uses the namespaced nanoprobe, no background: true" {
    run awk '/== ORCHESTRATION MODEL ==/{f=1} f{print} f&&/borg nanoprobe-log/{exit}' "${REPO_ROOT}/borg.zsh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-collective:borg-nanoprobe"* ]]
    [[ "$output" != *"background: true"* ]]
    [[ "$output" == *"model, effort or background"* ]]
}

@test "borg.zsh nanoprobes hint uses the namespaced subagent_type" {
    run grep -n "Spawn one via the Agent tool" "${REPO_ROOT}/borg.zsh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"subagent_type=borg-collective:borg-nanoprobe"* ]]
}

@test "CLAUDE.md nanoprobe passage uses the namespaced name, no background: true" {
    run grep -n "Nanoprobe orchestrator (drones vs nanoprobes)" "${REPO_ROOT}/CLAUDE.md"
    [ "$status" -eq 0 ]
    run grep -c "background: true" "${REPO_ROOT}/CLAUDE.md"
    [ "$output" -eq 0 ]
    run grep -c "borg-collective:borg-nanoprobe" "${REPO_ROOT}/CLAUDE.md"
    [ "$output" -ge 1 ]
}

@test "orchestration-architecture.md matches the routing policy" {
    f="${REPO_ROOT}/docs/orchestration-architecture.md"
    run grep -c "general-purpose → inherited\|session default is now Opus 4.8\|every .agent(). call carries an explicit" "$f"
    [ "$output" -eq 0 ]
    run grep -c "docs/agent-routing.md" "$f"
    [ "$output" -ge 1 ]
    run grep -c "xhigh" "$f"
    [ "$output" -ge 1 ]
}
