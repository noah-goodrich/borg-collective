#!/usr/bin/env bats
# Prose contract for the shell-command hygiene convention (directive 2026-10-13-shell-command-hygiene, slice C1).
# The blanket "wrap pipelines in bash -c" rule must not return; the narrowed guidance must stay pinned.
# Pure file reads: nothing here executes the prose under test.

ROOT="${BATS_TEST_DIRNAME%/*}"
RULES="$ROOT/config/claude/CLAUDE.md"

@test "rules file has no table row mapping a pipe, env prefix or && chain to bash -c" {
    run grep -nE '^\|.*`bash -c ' "$RULES"
    [ "$status" -eq 1 ]
}

@test "rules file drops the old 'use it for pipelines' sentence" {
    run grep -n 'Use it for pipelines and compound commands' "$RULES"
    [ "$status" -eq 1 ]
}

@test "rules file Subagent Rules no longer say bash -c for pipelines" {
    run grep -nE "bash -c '\.\.\.'. for pipelines" "$RULES"
    [ "$status" -eq 1 ]
}

@test "rules file no longer claims the wildcard does not match shell operators" {
    run grep -n 'does NOT match shell operators' "$RULES"
    [ "$status" -eq 1 ]
}

@test "rules file carries the narrowed anchors" {
    grep -q 'matched per subcommand' "$RULES"
    grep -q 'literal paths' "$RULES"
    grep -q 'genuine control flow' "$RULES"
}

@test "no agent or skill file instructs wrapping a pipeline or chain in bash -c" {
    run grep -nE "bash -c '[^']*([|]|&&|;)" "$ROOT"/agents/*.md "$ROOT"/skills/*/SKILL.md
    [ "$status" -eq 1 ]
}

@test "no agent or skill file prescribes any bash -c wrapper" {
    run grep -nE "^bash -c |^[$] bash -c " "$ROOT"/agents/*.md "$ROOT"/skills/*/SKILL.md
    [ "$status" -eq 1 ]
}

@test "rules file carries no script-shaping advice to dodge the check" {
    run grep -niE 'free of brace|nested quotes' "$RULES"
    [ "$status" -eq 1 ]
}

@test "stale pointers to the old CLAUDE.md section name are gone" {
    run grep -rn 'Bash Permission Patterns' "$ROOT/skills" "$ROOT/agents"
    [ "$status" -eq 1 ]
}

@test "agent and Subagent Rules bullets are pinned" {
    grep -q 'allow rules match per subcommand' "$ROOT/agents/borg-nanoprobe.md"
    grep -q 'never to get past a removal check' "$ROOT/agents/borg-nanoprobe.md"
    grep -q 'Write pipes and' "$RULES"
}

@test "no guidance recommends a bracketed or respelled removal word" {
    run grep -nE '\[r\]m|r\\m|"r""m"|file indirection' "$RULES" "$ROOT"/agents/*.md "$ROOT"/skills/*/SKILL.md
    [ "$status" -eq 1 ]
}

@test "both settings.base.json files still allowlist bash -c" {
    grep -q '"Bash(bash -c:\*)"' "$ROOT/config/claude/settings.base.json"
    grep -q '"Bash(bash -c:\*)"' "$ROOT/config/cortex/settings.base.json"
}
