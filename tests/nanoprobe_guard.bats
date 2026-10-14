#!/usr/bin/env bats
# Tests for hooks/borg-nanoprobe-guard.sh — PreToolUse (Skill|Write|Edit|MultiEdit|NotebookEdit|Bash): a
# nanoprobe may call only the skill its machine-layer brief grants, and may not write to or name borg/extensions/.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-nanoprobe-guard.sh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    BRIEF_DIR="$XDG_CONFIG_HOME/borg/extensions/agent-extensions/borg-nanoprobe"
}

# _brief <prefer-tool> <instead-of> [requires]
_brief() {
    mkdir -p "$BRIEF_DIR"
    {
        printf '# Nanoprobe brief\n\n'
        printf -- '- Prefer-tool: `%s`\n' "$1"
        printf -- '- Instead-of: `%s`\n' "$2"
        if [ -n "${3:-}" ]; then printf -- '- Requires: `%s`\n' "$3"; fi
    } > "$BRIEF_DIR/brief.md"
}

# _call <tool> <key> <value> [agent_type]  (agent_type defaults to the plugin-scoped nanoprobe; - for none)
_call() {
    local at="${4:-borg-collective:borg-nanoprobe}" json
    json=$(jq -nc --arg t "$1" --arg k "$2" --arg v "$3" --arg at "$at" \
        '{tool_name:$t, tool_input:{($k):$v}} + (if $at == "-" then {} else {agent_type:$at} end)')
    run bash -c "printf '%s' \"\$1\" | bash '$HOOK' 2>&1" _ "$json"
}

_deny() {
    [ "$status" -eq 2 ] || { echo "expected deny, got $status: $output"; false; }
    [[ "$output" == *"borg nanoprobe guard"* ]] || false
}

@test "a complete machine brief allows the named skill" {
    _brief 'dev-workflow:create-pr' 'gh pr create' 'skill:dev-workflow:create-pr'
    _call Skill skill 'dev-workflow:create-pr'
    [ "$status" -eq 0 ]
}

@test "the bare nanoprobe agent_type is gated too" {
    _brief 'dev-workflow:create-pr' 'gh pr create' 'skill:dev-workflow:create-pr'
    _call Skill skill 'other:skill' borg-nanoprobe
    _deny
}

@test "a different skill is denied" {
    _brief 'dev-workflow:create-pr' 'gh pr create' 'skill:dev-workflow:create-pr'
    _call Skill skill 'other:skill'
    _deny
}

@test "a brief whose Instead-of is not gh pr create denies" {
    _brief 'dev-workflow:create-pr' 'git push' 'skill:dev-workflow:create-pr'
    _call Skill skill 'dev-workflow:create-pr'
    _deny
}

@test "a brief with no Requires line denies" {
    _brief 'dev-workflow:create-pr' 'gh pr create'
    _call Skill skill 'dev-workflow:create-pr'
    _deny
}

@test "no brief at all denies" {
    _call Skill skill 'dev-workflow:create-pr'
    _deny
}

@test "a nanoprobe Write under the extensions dir is denied" {
    _call Write file_path "$XDG_CONFIG_HOME/borg/extensions/agent-extensions/borg-nanoprobe/brief.md"
    _deny
}

@test "a nanoprobe Edit under the extensions dir via .. is denied" {
    _call Edit file_path "$XDG_CONFIG_HOME/borg/other/../extensions/x.md"
    _deny
}

@test "a nanoprobe Write elsewhere is allowed" {
    _call Write file_path "$BATS_TEST_TMPDIR/work/file.txt"
    [ "$status" -eq 0 ]
}

@test "a non-nanoprobe session's Skill call passes through" {
    _call Skill skill 'anything' borg-collective:borg-grunt
    [ "$status" -eq 0 ]
    _call Skill skill 'anything' -
    [ "$status" -eq 0 ]
}

@test "a non-nanoprobe Write under the extensions dir passes through" {
    _call Write file_path "$XDG_CONFIG_HOME/borg/extensions/x.md" -
    [ "$status" -eq 0 ]
}

@test "the hook is built and registered with the Skill matcher" {
    grep -qE '_build_self_contained_hook .*borg-nanoprobe-guard\.sh' "$BUILD_PLUGIN"
    run grep -B6 'borg-nanoprobe-guard.sh"' "$BUILD_PLUGIN"
    [[ "$output" == *"Skill|Write|Edit|MultiEdit|NotebookEdit|Bash"* ]]
}

@test "a nanoprobe Bash redirect into the brief path is denied" {
    _call Bash command "echo x > $XDG_CONFIG_HOME/borg/extensions/agent-extensions/borg-nanoprobe/brief.md"
    _deny
}

@test "a nanoprobe Bash tee via the tilde form is denied" {
    _call Bash command 'echo x | tee ~/.config/borg/extensions/agent-extensions/borg-nanoprobe/brief.md'
    _deny
}

@test "a nanoprobe Bash command via the XDG variable form is denied" {
    _call Bash command 'echo x >> "$XDG_CONFIG_HOME/borg/extensions/y"'
    _deny
}

@test "a nanoprobe Bash command not mentioning the directory passes" {
    _call Bash command 'git status --short'
    [ "$status" -eq 0 ]
}

@test "a non-nanoprobe Bash command mentioning the directory passes" {
    _call Bash command "echo x > $XDG_CONFIG_HOME/borg/extensions/x.md" borg-collective:borg-grunt
    [ "$status" -eq 0 ]
    _call Bash command "ls $XDG_CONFIG_HOME/borg/extensions" -
    [ "$status" -eq 0 ]
}
