#!/usr/bin/env bats
# `borg handoff` through the wrapper, and the Queen's SessionStart card that names it (#504). The lint's rules are
# pinned in borg_core/handoff/test_core.py; these cases pin that the verb is reachable and the Queen is told of it.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
FIXTURES="${BATS_TEST_DIRNAME}/../borg_core/handoff/fixtures"

setup() {
    setup_temp_dirs
}

@test "handoff: check passes one thread and fails two PR refs with the split prompt" {
    run zsh "$BORG" handoff check "$FIXTURES/good-one-thread.md"
    [ "$status" -eq 0 ]
    run zsh "$BORG" handoff check "$FIXTURES/bad-two-refs.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"split: this goal names 2 PR threads"* ]] || false
}

@test "handoff: check fails a handoff with no stop condition" {
    run zsh "$BORG" handoff check "$FIXTURES/bad-no-stop.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no \`Stop condition:\` line"* ]] || false
}

@test "handoff: write refuses two PRs and writes one queen checkpoint for one" {
    local repo="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$repo"
    run zsh "$BORG" handoff write --repository "$repo" --goal "land o/r#1 and o/r#2" --done-when "merged" --next none
    [ "$status" -eq 1 ]
    [ ! -d "$repo/.borg/checkpoints" ]
    run zsh "$BORG" handoff write --repository "$repo" --goal "o/r#1: land it" --done-when "merged" --next "o/r#2"
    [ "$status" -eq 0 ]
    local files=("$repo"/.borg/checkpoints/*-queen.md)
    [ "${#files[@]}" -eq 1 ]
    run zsh "$BORG" handoff check "${files[0]}"
    [ "$status" -eq 0 ]
}

@test "handoff: the Queen's SessionStart card names the verb" {
    local orch="$HOME/dev"
    mkdir -p "$orch"
    run bash "${BATS_TEST_DIRNAME}/../hooks/borg-link-down.sh" <<< "$(printf '{"session_id":"q-1","cwd":"%s"}' "$orch")"
    [ "$status" -eq 0 ]
    [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" == *"borg handoff write"* ]] || false
}
