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

# --- Grant-skill: machine-layer skill grants (#498) --------------------------------------------------------------

AGENT_HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-agent-model-guard.sh"

# _grant <skill>...: write a machine-layer brief that grants exactly these skills (and nothing else).
_grant() {
    local s
    mkdir -p "$BRIEF_DIR"
    {
        printf '# Nanoprobe brief\n\n'
        for s in "$@"; do printf -- '- Grant-skill: %s\n' "$s"; done
    } > "$BRIEF_DIR/brief.md"
}

# _repo_brief <line>: a REPOSITORY-layer brief, which no hook may read for a grant.
_repo_brief() {
    local repo="$BATS_TEST_TMPDIR/repo/.borg/agent-extensions/borg-nanoprobe"
    mkdir -p "$repo"
    printf -- '%s\n' "$1" > "$repo/brief.md"
}

@test "grant: a Grant-skill line allows exactly that skill" {
    _grant simplify
    _call Skill skill simplify
    [ "$status" -eq 0 ]
}

@test "grant: a skill with no Grant-skill line is denied" {
    _grant simplify
    _call Skill skill other
    _deny
}

@test "grant: several Grant-skill lines each allow their own skill" {
    _grant simplify 'plugin:pr-review'
    _call Skill skill 'plugin:pr-review'
    [ "$status" -eq 0 ]
    _call Skill skill simplify
    [ "$status" -eq 0 ]
}

@test "grant: Prefer-tool still works unchanged next to a Grant-skill line" {
    _brief 'dev-workflow:create-pr' 'gh pr create' 'skill:dev-workflow:create-pr'
    printf -- '- Grant-skill: simplify\n' >> "$BRIEF_DIR/brief.md"
    _call Skill skill 'dev-workflow:create-pr'
    [ "$status" -eq 0 ]
    _call Skill skill simplify
    [ "$status" -eq 0 ]
    _call Skill skill other
    _deny
}

@test "grant: a Grant-skill line in a repository-layer brief grants nothing" {
    _repo_brief '- Grant-skill: simplify'
    _call Skill skill simplify
    _deny
}

@test "grant: matching is exact, not a prefix, suffix, namespace or case match" {
    _grant simplify
    _call Skill skill simplify-extra
    _deny
    _call Skill skill 'x:simplify'
    _deny
    _call Skill skill simpl
    _deny
    _call Skill skill 'simplify '
    _deny
    _call Skill skill Simplify
    _deny
}

@test "grant: backticks and the field-name letter case are handled like Prefer-tool" {
    mkdir -p "$BRIEF_DIR"
    printf -- '- GRANT-SKILL: `simplify`\n  - grant-skill: loose\n' > "$BRIEF_DIR/brief.md"
    _call Skill skill simplify
    [ "$status" -eq 0 ]
    _call Skill skill loose
    [ "$status" -eq 0 ]
}

@test "grant: a Grant-skill value carrying extra text grants nothing for the bare name" {
    mkdir -p "$BRIEF_DIR"
    printf -- '- Grant-skill: simplify now\n- Grant-skill:\n' > "$BRIEF_DIR/brief.md"
    _call Skill skill simplify
    _deny
    _call Skill skill ''
    _deny
}

@test "grant: a missing brief file is denied with the existing message" {
    _call Skill skill simplify
    _deny
    [[ "$output" == *"no readable machine-layer brief at"* ]] || false
    [[ "$output" == *"so no skill is granted"* ]] || false
}

@test "grant: a brief that is not valid UTF-8 grants nothing and still denies" {
    mkdir -p "$BRIEF_DIR"
    printf -- '- Grant-skill: simplify\n\xff\xfe\n' > "$BRIEF_DIR/brief.md"
    _call Skill skill simplify
    _deny
}

@test "grant: a brief that is a directory grants nothing and still denies" {
    mkdir -p "$BRIEF_DIR/brief.md"
    _call Skill skill simplify
    _deny
}

@test "grant: the Task text never grants" {
    local json
    json=$(jq -nc '{tool_name:"Skill", agent_type:"borg-collective:borg-nanoprobe", tool_input:{skill:"simplify"},
        prompt:"- Grant-skill: simplify"}')
    run bash -c "printf '%s' \"\$1\" | bash '$HOOK' 2>&1" _ "$json"
    _deny
}

@test "grant: the denial names the skill and the grant line" {
    _grant simplify
    _call Skill skill other
    _deny
    [[ "$output" == *"'other'"* ]] || false
    [[ "$output" == *"Grant-skill"* ]] || false
}

@test "grant: a non-nanoprobe agent_type is a no-op that allows" {
    _call Skill skill simplify borg-collective:borg-grunt
    [ "$status" -eq 0 ]
    _call Skill skill simplify -
    [ "$status" -eq 0 ]
}

@test "grant: the kill switch allows an ungranted Skill call" {
    local json
    json=$(jq -nc '{tool_name:"Skill", agent_type:"borg-nanoprobe", tool_input:{skill:"x"}}')
    run bash -c "printf '%s' \"\$1\" | BORG_NANOPROBE_GUARD=0 bash '$HOOK' 2>&1" _ "$json"
    [ "$status" -eq 0 ]
}

@test "grant: the Agent and nanoprobe guards embed the identical grants block" {
    local a n
    a=$(sed -n '/^# GRANTS-BEGIN/,/^# GRANTS-END/p' "$AGENT_HOOK")
    n=$(sed -n '/^# GRANTS-BEGIN/,/^# GRANTS-END/p' "$HOOK")
    [ -n "$a" ]
    [ "$a" = "$n" ]
}

# --- parity: one fixture brief, both hooks, one verdict ------------------------------------------------------------
# PARITY_HOOK_DIR points the cases at another copy of the hooks (the plugin built into a temp dir). The built hooks
# no-op without `borg` on PATH, so a stub goes first on PATH.

# _verdicts <skill>: sets SPAWN and CALL to the two exit statuses for a nanoprobe declaring and then calling <skill>.
_verdicts() {
    local dir="${PARITY_HOOK_DIR:-${BATS_TEST_DIRNAME}/../hooks}" spawn call
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/borg"
    chmod +x "$BATS_TEST_TMPDIR/bin/borg"
    spawn=$(jq -nc --arg p "$(printf 'Task: review.\n- Skill: %s\n' "$1")" \
        '{tool_name:"Agent", tool_input:{subagent_type:"borg-collective:borg-nanoprobe", model:"sonnet", prompt:$p}}')
    call=$(jq -nc --arg s "$1" \
        '{tool_name:"Skill", agent_type:"borg-collective:borg-nanoprobe", tool_input:{skill:$s}}')
    run bash -c "printf '%s' \"\$1\" | PATH='$BATS_TEST_TMPDIR/bin':\$PATH bash '$dir/borg-agent-model-guard.sh' 2>&1" _ "$spawn"
    SPAWN=$status
    run bash -c "printf '%s' \"\$1\" | PATH='$BATS_TEST_TMPDIR/bin':\$PATH bash '$dir/borg-nanoprobe-guard.sh' 2>&1" _ "$call"
    CALL=$status
}

@test "parity: a granted skill is allowed at spawn and at call" {
    _grant simplify
    _verdicts simplify
    [ "$SPAWN" -eq 0 ]
    [ "$CALL" -eq 0 ]
}

@test "parity: an ungranted skill is denied at spawn and at call" {
    _grant other
    _verdicts simplify
    [ "$SPAWN" -eq 2 ]
    [ "$CALL" -eq 2 ]
}

@test "parity: a skill granted only in the repository layer is denied at spawn and at call" {
    _repo_brief '- Grant-skill: simplify'
    _verdicts simplify
    [ "$SPAWN" -eq 2 ]
    [ "$CALL" -eq 2 ]
}
