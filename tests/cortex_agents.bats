#!/usr/bin/env bats
# Tests for borg setup's Cortex agent install (_borg_install_cortex_agents in borg.zsh).
#
# Cortex Code CLI loads custom agents from ~/.snowflake/cortex/agents/ (the first location in its bundled AGENTS.md),
# a directory Claude Code never reads, so borg copies agents/*.md there while Claude Code keeps getting them from the
# plugin. tests/agent_frontmatter.bats pins the frontmatter rules that make the copies loadable.
#
# THE HAZARD: same as tests/cortex_hooks.bats. These cases never run borg setup: they source borg.zsh and call the one
# install function with HOME inside the sandbox (setup_temp_dirs).

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"
AGENTS="${BATS_TEST_DIRNAME}/../agents"

setup() {
    setup_temp_dirs
    COCO_DIR="$BORG_TEST_HOME/.snowflake/cortex"
    mkdir -p "$COCO_DIR"
}

# Run the install function against the sandboxed Cortex directory.
_install() {
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        _borg_install_cortex_agents '$COCO_DIR'
    "
}

@test "cortex agents: the sandbox HOME is not the real home" {
    [ "$HOME" = "$BORG_TEST_HOME" ]
    [[ "$COCO_DIR" == "$BATS_TEST_TMPDIR"/* ]] || false
}

@test "cortex agents: every agents/*.md is copied byte-identical, and nothing else" {
    [ ! -e "$COCO_DIR/agents" ]
    _install
    [ "$status" -eq 0 ]
    local f n sources=0 copies=0
    for f in "$AGENTS"/*.md; do
        n=${f##*/}
        cmp -s "$f" "$COCO_DIR/agents/$n" || { echo "missing or different: $n"; return 1; }
        sources=$((sources + 1))
    done
    for f in "$COCO_DIR/agents"/*; do
        copies=$((copies + 1))
    done
    [ "$sources" -gt 0 ]
    [ "$copies" -eq "$sources" ]
}

@test "cortex agents: a second run copies nothing" {
    _install
    [[ "$output" == *"(cortex agent)"* ]] || false
    _install
    [ "$status" -eq 0 ]
    [[ "$output" != *"(cortex agent)"* ]] || false
}

@test "cortex agents: a stale copy is replaced and an unrelated agent file is left alone" {
    mkdir -p "$COCO_DIR/agents"
    echo "stale" > "$COCO_DIR/agents/borg-scout.md"
    echo "mine" > "$COCO_DIR/agents/my-agent.md"
    _install
    [ "$status" -eq 0 ]
    cmp -s "$AGENTS/borg-scout.md" "$COCO_DIR/agents/borg-scout.md"
    [ "$(cat "$COCO_DIR/agents/my-agent.md")" = "mine" ]
    [[ "$output" == *"borg-scout.md (cortex agent)"* ]] || false
}

@test "cortex agents: borg.zsh installs the agents from setup" {
    run grep -n '_borg_install_cortex_agents "\$COCO_DIR"' "$BORG_ZSH"
    [ "$status" -eq 0 ]
}
