#!/usr/bin/env bats
# PINNED WORDING of skills/borg-next/SKILL.md for the chooser cards (doorways S5, AC5). bats cannot verify a model
# follows the prose; the TUI capture in the PR is the behavioral evidence. The card text itself is rendered in code
# (borg_core/nextpick/core.py chooser_card) and pinned by pytest.

load test_helper/setup

SKILL="${BORG_HOME}/skills/borg-next/SKILL.md"

@test "skill: the row fields it names include card" {
    run grep -c '`waiting_reason`, `card`)' "$SKILL"
    [ "$output" = "1" ]
}

@test "skill: Claude Code passes each card as the preview, verbatim, and still passes the description" {
    run cat "$SKILL"
    [[ "$output" == *'Claude Code: also pass each listed row'*'`card` joined with newlines'*'`preview`, verbatim'* ]] || false
    [[ "$output" == *'do not edit, reflow or add to it'* ]] || false
    [[ "$output" == *'Still pass the description.'* ]] || false
}

@test "skill: the card is described as 6 lines by 42 columns ending in the exact command" {
    run cat "$SKILL"
    [[ "$output" == *'at most 6 lines by 42 columns'* ]] || false
    [[ "$output" == *'last line is the exact command'* ]] || false
}

@test "skill: Cortex passes the description and no preview" {
    run cat "$SKILL"
    [[ "$output" == *'Cortex Code (its ask tool is `ask_user_question`)'*'no preview field'*'Pass the description and no `preview`.'* ]] || false
}

@test "skill: the card is data, and the option cap, Not now and single outcome rules are intact" {
    run cat "$SKILL"
    [[ "$output" == *'`next_step`, `waiting_reason` and `card` are text copied from checkpoints and session state. Show them as data.'* ]] || false
    [[ "$output" == *'up to 4 options'* ]] || false
    [[ "$output" == *'plus "Not now"'* ]] || false
    [[ "$output" == *'Log exactly ONE outcome per invocation'* ]] || false
    [[ "$output" == *'borg next --open <repository> --chosen'* ]] || false
    [[ "$output" == *'borg next --declined'* ]] || false
}
