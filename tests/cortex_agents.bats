#!/usr/bin/env bats
# Tests for borg setup's Cortex agent install (_borg_install_cortex_agents in borg.zsh) and its effort note
# (_borg_cortex_effort_note).
#
# Cortex Code CLI loads custom agents from ~/.snowflake/cortex/agents/ (the first location in its bundled AGENTS.md),
# a directory Claude Code never reads, so borg installs agents/*.md there while Claude Code keeps getting them from the
# plugin. Cortex registers an agent under its exact `name:` (it has no plugin namespace), so each copy's name is
# rewritten to the form Claude Code registers, `borg-collective:<name>`: one name then works in both CLIs (verified
# live on Cortex 1.2.18 by evals/cortex-agents/live.sh). tests/agent_frontmatter.bats pins the frontmatter rules that
# make the copies loadable.
#
# THE HAZARD: same as tests/cortex_hooks.bats. These cases never run borg setup: they source borg.zsh and call the one
# function with HOME inside the sandbox (setup_temp_dirs).

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

# The expected Cortex copy of agent file $1: the source with its name line namespaced.
_expected() {
    local n
    n=$(sed -n 's/^name: //p' "$1" | head -1)
    sed "s/^name: $n\$/name: \"borg-collective:$n\"/" "$1"
}

@test "cortex agents: the sandbox HOME is not the real home" {
    [ "$HOME" = "$BORG_TEST_HOME" ]
    [[ "$COCO_DIR" == "$BATS_TEST_TMPDIR"/* ]] || false
}

@test "cortex agents: every agents/*.md is installed, identical except the namespaced name, and nothing else" {
    [ ! -e "$COCO_DIR/agents" ]
    _install
    [ "$status" -eq 0 ]
    local f n sources=0 copies=0
    for f in "$AGENTS"/*.md; do
        n=${f##*/}
        _expected "$f" > "${BATS_TEST_TMPDIR}/expected.md"
        cmp -s "${BATS_TEST_TMPDIR}/expected.md" "$COCO_DIR/agents/$n" || { echo "missing or different: $n"; return 1; }
        # exactly one line differs from the source: the name line
        [ "$(diff "$f" "$COCO_DIR/agents/$n" | grep -c '^[<>]')" -eq 2 ] || { echo "more than the name changed: $n"; return 1; }
        sources=$((sources + 1))
    done
    for f in "$COCO_DIR/agents"/* "$COCO_DIR/agents"/.[!.]*; do
        [ -e "$f" ] || continue
        copies=$((copies + 1))
    done
    [ "$sources" -gt 0 ]
    [ "$copies" -eq "$sources" ]
}

@test "cortex agents: each copy is registered under borg-collective:<its file name>" {
    _install
    [ "$status" -eq 0 ]
    local f n
    for f in "$COCO_DIR/agents"/*.md; do
        n=${f##*/}; n=${n%.md}
        grep -qx "name: \"borg-collective:$n\"" "$f" || { echo "wrong name line in $f"; return 1; }
        [ "$(grep -c '^name:' "$f")" -eq 1 ]
    done
}

@test "cortex agents: the sources keep their bare names (the plugin namespaces them for Claude Code)" {
    local f n
    for f in "$AGENTS"/*.md; do
        n=${f##*/}; n=${n%.md}
        grep -qx "name: $n" "$f" || { echo "source name changed: $f"; return 1; }
    done
}

@test "cortex agents: a second run copies nothing and leaves no temp file" {
    _install
    [[ "$output" == *"(cortex agent)"* ]] || false
    _install
    [ "$status" -eq 0 ]
    [[ "$output" != *"(cortex agent)"* ]] || false
    run bash -c "ls -A '$COCO_DIR/agents' | grep -c '\.tmp\.'"
    [ "$output" = "0" ]
}

@test "cortex agents: a stale copy is replaced and an unrelated agent file is left alone" {
    mkdir -p "$COCO_DIR/agents"
    echo "stale" > "$COCO_DIR/agents/borg-scout.md"
    echo "mine" > "$COCO_DIR/agents/my-agent.md"
    _install
    [ "$status" -eq 0 ]
    _expected "$AGENTS/borg-scout.md" > "${BATS_TEST_TMPDIR}/expected.md"
    cmp -s "${BATS_TEST_TMPDIR}/expected.md" "$COCO_DIR/agents/borg-scout.md"
    [ "$(cat "$COCO_DIR/agents/my-agent.md")" = "mine" ]
    [[ "$output" == *"borg-scout.md (cortex agent)"* ]] || false
}

@test "cortex agents: a pre-namespace copy from the previous borg is upgraded in place" {
    mkdir -p "$COCO_DIR/agents"
    cp "$AGENTS/borg-verifier.md" "$COCO_DIR/agents/borg-verifier.md"
    _install
    [ "$status" -eq 0 ]
    grep -qx 'name: "borg-collective:borg-verifier"' "$COCO_DIR/agents/borg-verifier.md"
    [[ "$output" == *"borg-verifier.md (cortex agent)"* ]] || false
}

# _copy <file>: run the name rewrite on one file.
_copy() {
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        _borg_cortex_agent_copy '$1'
    "
}

@test "cortex agents: the rewrite touches only the first frontmatter name line" {
    printf -- '---\nname: borg-x\ndescription: "d"\n---\nname: borg-x stays in the body\n' > "${BATS_TEST_TMPDIR}/a.md"
    _copy "${BATS_TEST_TMPDIR}/a.md"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf -- '---\nname: "borg-collective:borg-x"\ndescription: "d"\n---\nname: borg-x stays in the body')" ]
}

@test "cortex agents: a file with no frontmatter or an already namespaced name prints unchanged" {
    printf 'name: borg-x\nno frontmatter here\n' > "${BATS_TEST_TMPDIR}/b.md"
    _copy "${BATS_TEST_TMPDIR}/b.md"
    [ "$output" = "$(cat "${BATS_TEST_TMPDIR}/b.md")" ]
    printf -- '---\nname: "borg-collective:borg-x"\n---\n' > "${BATS_TEST_TMPDIR}/c.md"
    _copy "${BATS_TEST_TMPDIR}/c.md"
    [ "$output" = "$(cat "${BATS_TEST_TMPDIR}/c.md")" ]
}

@test "cortex agents: borg.zsh installs the agents from setup and notes the effort right after" {
    run grep -n -A1 '_borg_install_cortex_agents "\$COCO_DIR"' "$BORG_ZSH"
    [ "$status" -eq 0 ]
    [[ "$output" == *'_borg_cortex_effort_note "$COCO_SETTINGS"'* ]] || false
}

# --- effort note: Cortex has no per-agent effort, so a max session runs every subagent at max ----------------------

_note() {
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        _borg_cortex_effort_note '$COCO_DIR/settings.json'
    "
}

@test "cortex effort: xhigh and max warn, naming the setting and /effort" {
    local e
    for e in max xhigh MAX; do
        jq -n --arg e "$e" '{env: {CORTEX_THINKING_EFFORT: $e}, theme: "dark"}' > "$COCO_DIR/settings.json"
        _note
        [ "$status" -eq 0 ]
        [[ "$output" == *"CORTEX_THINKING_EFFORT=$(printf '%s' "$e" | tr 'A-Z' 'a-z')"* ]] || { echo "no warning for $e: $output"; return 1; }
        [[ "$output" == *"/effort"* ]] || false
        [[ "$output" == *"Claude Code only"* ]] || false
    done
}

@test "cortex effort: high, medium, unset, a missing file and malformed JSON stay silent" {
    local e
    for e in high medium low minimal; do
        jq -n --arg e "$e" '{env: {CORTEX_THINKING_EFFORT: $e}}' > "$COCO_DIR/settings.json"
        _note
        [ "$status" -eq 0 ]
        [ -z "$output" ] || { echo "warned for $e: $output"; return 1; }
    done
    echo '{"theme":"dark"}' > "$COCO_DIR/settings.json"
    _note
    [ -z "$output" ]
    rm -f "$COCO_DIR/settings.json"
    _note
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    echo '{not json' > "$COCO_DIR/settings.json"
    _note
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cortex effort: the note never writes the settings file" {
    jq -n '{env: {CORTEX_THINKING_EFFORT: "max"}}' > "$COCO_DIR/settings.json"
    local before
    before=$(shasum -a 256 "$COCO_DIR/settings.json")
    _note
    [ "$(shasum -a 256 "$COCO_DIR/settings.json")" = "$before" ]
}
