#!/usr/bin/env bats
# Tests for borg setup's Cortex hook registration (_borg_register_cortex_hooks in borg.zsh).
#
# Cortex Code CLI never reads ~/.snowflake/cortex/settings.json for hooks. Its loader reads
# ~/.snowflake/cortex/hooks.json (the location its bundled HOOKS.md and CONFIGURATION.md document), so borg
# registers the twelve hooks there and scrubs the stale entries older versions wrote into settings.json.
# See docs/plans/directives/2026-10-15-borg-in-cortex.md (AC1).
#
# THE HAZARD: borg setup rewrites the real Cortex and Claude configuration. These cases never run it. They
# source borg.zsh and call the one registration function with HOME and XDG_CONFIG_HOME inside the sandbox
# (setup_temp_dirs), and a case that touched the real ~/.snowflake would fail the home-is-sandboxed check.

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    COCO_DIR="$BORG_TEST_HOME/.snowflake/cortex"
    HOOKS_JSON="$COCO_DIR/hooks.json"
    SETTINGS_JSON="$COCO_DIR/settings.json"
    mkdir -p "$COCO_DIR/hooks"
}

# Run the registration function against the sandboxed Cortex directory.
_register() {
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        _borg_register_cortex_hooks '$COCO_DIR'
    "
}

# The eight event|script pairs borg registers with the empty matcher, in registration order. The three plan-mode
# entries (2026-10-22 directive AC4) and the model guard (Agent|Task) carry tool-name matchers and are asserted in
# their own block below.
_expected_pairs() {
    printf '%s\n' \
        "SessionStart|borg-link-down.sh" \
        "Stop|borg-link-up.sh" \
        "Notification|notify.sh" \
        "Notification|borg-notify.sh" \
        "PreToolUse|pre-commit-remind.sh" \
        "PreToolUse|bash-guard.sh" \
        "PreToolUse|borg-plan-promote.sh" \
        "SubagentStop|borg-nanoprobe-log.sh"
}

# A settings.json as the old borg setup left it: the eight stale entries (literal $HOME paths), plus the
# keys Cortex really reads from this file.
_write_stale_settings() {
    cat > "$SETTINGS_JSON" <<'EOF'
{
  "cortexAgentConnectionName": "work",
  "theme": "dark",
  "permissions": { "allow": ["Bash(git status:*)"] },
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/borg-link-down.sh", "timeout": 10 }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/borg-link-up.sh", "timeout": 10 }] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/notify.sh", "timeout": 10 }] },
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/borg-notify.sh", "timeout": 10 }] }
    ],
    "PreToolUse": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/pre-commit-remind.sh", "timeout": 10 }] },
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/bash-guard.sh", "timeout": 10 }] },
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/borg-plan-promote.sh", "timeout": 10 }] }
    ],
    "SubagentStop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "$HOME/.snowflake/cortex/hooks/borg-nanoprobe-log.sh", "timeout": 10 }] }
    ]
  }
}
EOF
}

@test "cortex hooks: the sandbox HOME is not the real home" {
    [ "$HOME" = "$BORG_TEST_HOME" ]
    [[ "$COCO_DIR" == "$BATS_TEST_TMPDIR"/* ]]
}

@test "cortex hooks: hooks.json is created with the twelve entries in the documented shape" {
    [ ! -e "$HOOKS_JSON" ]
    _register
    [ "$status" -eq 0 ]
    [ -f "$HOOKS_JSON" ]
    jq -e . "$HOOKS_JSON" >/dev/null

    # exactly twelve hook commands in total
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 12 ]

    local pair event name
    while IFS='|' read -r event name; do
        # each is a {matcher, hooks:[{type:command, command, timeout}]} group under its event
        run jq -e --arg e "$event" --arg c "$COCO_DIR/hooks/$name" '
            .hooks[$e] | any(
                .matcher == "" and
                (.hooks | length == 1) and
                .hooks[0].type == "command" and
                .hooks[0].command == $c and
                .hooks[0].timeout == 10
            )' "$HOOKS_JSON"
        [ "$status" -eq 0 ] || { echo "missing $event $name"; return 1; }
    done < <(_expected_pairs)

    # the three plan-mode hooks carry their tool-name matcher, each once
    run jq -e --arg c "$COCO_DIR/hooks/borg-cortex-plan.sh" '
        .hooks.PostToolUse | map(select(.hooks[0].command == $c)) |
        length == 1 and .[0].matcher == "EnterPlanMode|enter_plan_mode" and .[0].hooks[0].timeout == 10' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    run jq -e --arg c "$COCO_DIR/hooks/borg-cortex-plan.sh" '
        .hooks.PreToolUse | map(select(.hooks[0].command == $c)) |
        length == 1 and .[0].matcher == "ExitPlanMode|exit_plan_mode" and .[0].hooks[0].timeout == 10' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    run jq -e --arg c "$COCO_DIR/hooks/borg-plan-promote.sh" '
        .hooks.PostToolUse | map(select(.hooks[0].command == $c)) |
        length == 1 and .[0].matcher == "ExitPlanMode|exit_plan_mode" and .[0].hooks[0].timeout == 10' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    # and promote keeps its original empty-matcher PreToolUse entry (expand, not replace)
    run jq -e --arg c "$COCO_DIR/hooks/borg-plan-promote.sh" '
        .hooks.PreToolUse | map(select(.hooks[0].command == $c)) | length == 1 and .[0].matcher == ""' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    # the model guard fires on Cortex's task tool, which reaches hooks as tool_name "Task"
    run jq -e --arg c "$COCO_DIR/hooks/borg-agent-model-guard.sh" '
        .hooks.PreToolUse | map(select(.hooks[0].command == $c)) |
        length == 1 and .[0].matcher == "Agent|Task" and .[0].hooks[0].timeout == 10' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
}

@test "cortex hooks: the model guard's matcher catches Cortex's Task tool name and nothing else" {
    _register
    [ "$status" -eq 0 ]
    local m
    m=$(jq -r --arg c "$COCO_DIR/hooks/borg-agent-model-guard.sh" \
        '.hooks.PreToolUse[] | select(.hooks[0].command == $c) | .matcher' "$HOOKS_JSON")
    # Cortex 1.2.18 tests a matcher as new RegExp(`^(?:${m})$`, "i") against the mapped tool name (task -> Task):
    # the same whole-name, case-insensitive test, done with grep -E -i -x
    printf '%s\n' Task task Agent | grep -E -i -x -q -- "$m"
    [ "$(printf '%s\n' Task task Agent | grep -E -i -x -c -- "$m")" -eq 3 ]
    [ "$(printf '%s\n' Bash TaskOutput task_list subagent | grep -E -i -x -c -- "$m")" -eq 0 ]
}

@test "cortex hooks: a hooks.json from before the model guard gains exactly that one entry" {
    _register
    [ "$status" -eq 0 ]
    local tmp="$HOOKS_JSON.old"
    jq '.hooks.PreToolUse |= map(select(.hooks[0].command | endswith("borg-agent-model-guard.sh") | not))' \
        "$HOOKS_JSON" > "$tmp" && mv "$tmp" "$HOOKS_JSON"
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 11 ]
    _register
    [ "$status" -eq 0 ]
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 12 ]
    [[ "$output" == *"borg-agent-model-guard.sh"* ]] || false
}

@test "cortex hooks: only the six Cortex events carry borg hooks" {
    _register
    [ "$status" -eq 0 ]
    [ "$(jq -r '.hooks | keys | join(",")' "$HOOKS_JSON")" = "Notification,PostToolUse,PreToolUse,SessionStart,Stop,SubagentStop" ]
}

@test "cortex hooks: the hook commands point at files setup copies into the Cortex hooks directory" {
    _register
    [ "$status" -eq 0 ]
    local cmd
    while IFS= read -r cmd; do
        [[ "$cmd" == "$COCO_DIR/hooks/"*.sh ]] || { echo "unexpected path: $cmd"; return 1; }
        # same directory borg.zsh's copy loop writes to, same file names as hooks/ in the checkout
        [ -f "${BATS_TEST_DIRNAME}/../hooks/${cmd##*/}" ] || { echo "no such hook in checkout: ${cmd##*/}"; return 1; }
    done < <(jq -r '.hooks[][] | .hooks[].command' "$HOOKS_JSON")
}

@test "cortex hooks: a second run is a no-op (byte-identical hooks.json)" {
    _register
    [ "$status" -eq 0 ]
    local first
    first=$(shasum -a 256 "$HOOKS_JSON")
    _register
    [ "$status" -eq 0 ]
    [ "$(shasum -a 256 "$HOOKS_JSON")" = "$first" ]
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 12 ]
}

@test "cortex hooks: a second run leaves a migrated settings.json byte-identical too" {
    _write_stale_settings
    _register
    [ "$status" -eq 0 ]
    local s1 h1
    s1=$(shasum -a 256 "$SETTINGS_JSON")
    h1=$(shasum -a 256 "$HOOKS_JSON")
    _register
    [ "$status" -eq 0 ]
    [ "$(shasum -a 256 "$SETTINGS_JSON")" = "$s1" ]
    [ "$(shasum -a 256 "$HOOKS_JSON")" = "$h1" ]
}

@test "cortex hooks: stale borg entries leave settings.json and every other key stays" {
    _write_stale_settings
    _register
    [ "$status" -eq 0 ]

    # no borg hook command survives in settings.json
    run grep -c "snowflake/cortex/hooks" "$SETTINGS_JSON"
    [ "$output" = "0" ]
    [ "$(jq '[.. | objects | select(has("command"))] | length' "$SETTINGS_JSON")" -eq 0 ]

    # the other keys are untouched
    [ "$(jq -r .cortexAgentConnectionName "$SETTINGS_JSON")" = "work" ]
    [ "$(jq -r .theme "$SETTINGS_JSON")" = "dark" ]
    [ "$(jq -c .permissions "$SETTINGS_JSON")" = '{"allow":["Bash(git status:*)"]}' ]

    # and no empty husk of the emptied hooks object is left behind
    [ "$(jq 'has("hooks")' "$SETTINGS_JSON")" = "false" ]

    # the entries moved: hooks.json now carries all twelve
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 12 ]
}

@test "cortex hooks: only borg's stale entries leave settings.json, a user's own hook there stays" {
    _write_stale_settings
    local tmp="$SETTINGS_JSON.edit"
    jq '.hooks.PreToolUse += [{"matcher":"bash","hooks":[{"type":"command","command":"/opt/mine/guard.sh","timeout":5}]}]
        | .hooks.UserPromptSubmit = [{"matcher":"","hooks":[{"type":"command","command":"/opt/mine/prompt.sh"}]}]' \
        "$SETTINGS_JSON" > "$tmp" && mv "$tmp" "$SETTINGS_JSON"

    _register
    [ "$status" -eq 0 ]

    [ "$(jq -r '[.. | objects | .command? // empty] | sort | join(",")' "$SETTINGS_JSON")" = "/opt/mine/guard.sh,/opt/mine/prompt.sh" ]
    [ "$(jq '.hooks.PreToolUse | length' "$SETTINGS_JSON")" -eq 1 ]
    [ "$(jq -r '.hooks.PreToolUse[0].matcher' "$SETTINGS_JSON")" = "bash" ]
    # events that held only borg entries are gone, not left as empty lists
    [ "$(jq -r '.hooks | keys | join(",")' "$SETTINGS_JSON")" = "PreToolUse,UserPromptSubmit" ]
    [ "$(jq -r .theme "$SETTINGS_JSON")" = "dark" ]
}

@test "cortex hooks: a settings.json with no hooks key is left exactly as it was" {
    printf '%s\n' '{"theme":"dark","permissions":{"allow":["Bash(ls:*)"]}}' > "$SETTINGS_JSON"
    local before
    before=$(shasum -a 256 "$SETTINGS_JSON")
    _register
    [ "$status" -eq 0 ]
    [ "$(shasum -a 256 "$SETTINGS_JSON")" = "$before" ]
}

@test "cortex hooks: the function does not create settings.json" {
    _register
    [ "$status" -eq 0 ]
    [ ! -e "$SETTINGS_JSON" ]
}

@test "cortex hooks: a user's own hook already in hooks.json is kept" {
    cat > "$HOOKS_JSON" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/opt/mine/validator.sh", "timeout": 30 }] }
    ],
    "SessionEnd": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "/opt/mine/cleanup.sh" }] }
    ]
  },
  "someOtherKey": 7
}
EOF
    _register
    [ "$status" -eq 0 ]

    run jq -e '.hooks.PreToolUse | any(.matcher == "Bash" and .hooks[0].command == "/opt/mine/validator.sh" and .hooks[0].timeout == 30)' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    run jq -e '.hooks.SessionEnd[0].hooks[0].command == "/opt/mine/cleanup.sh"' "$HOOKS_JSON"
    [ "$status" -eq 0 ]
    [ "$(jq .someOtherKey "$HOOKS_JSON")" = "7" ]
    # the user's two hooks plus borg's twelve
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 14 ]
}

@test "cortex hooks: an unreadable hooks.json is left alone, settings.json keeps its stale entries, setup is told" {
    printf '%s' '{ this is not json' > "$HOOKS_JSON"
    _write_stale_settings
    local h s
    h=$(shasum -a 256 "$HOOKS_JSON")
    s=$(shasum -a 256 "$SETTINGS_JSON")
    _register
    [ "$status" -eq 0 ]
    [[ "$output" == *"hooks.json"* ]]
    [ "$(shasum -a 256 "$HOOKS_JSON")" = "$h" ]
    [ "$(shasum -a 256 "$SETTINGS_JSON")" = "$s" ]
}

@test "cortex hooks: nothing is registered in the Claude settings file" {
    mkdir -p "$BORG_TEST_HOME/.claude"
    printf '%s\n' '{"model":"x"}' > "$BORG_TEST_HOME/.claude/settings.json"
    local before
    before=$(shasum -a 256 "$BORG_TEST_HOME/.claude/settings.json")
    _write_stale_settings
    _register
    [ "$status" -eq 0 ]
    [ "$(shasum -a 256 "$BORG_TEST_HOME/.claude/settings.json")" = "$before" ]
    [ ! -e "$BORG_TEST_HOME/.cortex/settings.json" ]
}

@test "cortex hooks: a hooks.json from before the plan-mode hooks gains exactly the three new entries" {
    _register
    [ "$status" -eq 0 ]
    local tmp="$HOOKS_JSON.old"
    jq 'del(.hooks.PostToolUse) | .hooks.PreToolUse |= map(select(.hooks[0].command | endswith("borg-cortex-plan.sh") | not))' \
        "$HOOKS_JSON" > "$tmp" && mv "$tmp" "$HOOKS_JSON"
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 9 ]
    _register
    [ "$status" -eq 0 ]
    [ "$(jq '[.hooks[][] | .hooks[]] | length' "$HOOKS_JSON")" -eq 12 ]
    local first
    first=$(shasum -a 256 "$HOOKS_JSON")
    _register
    [ "$(shasum -a 256 "$HOOKS_JSON")" = "$first" ]
}

@test "cortex hooks: borg.zsh calls the registration from setup and no longer registers into settings.json" {
    run grep -n '_borg_register_cortex_hooks "\$COCO_DIR"' "$BORG_ZSH"
    [ "$status" -eq 0 ]
    run grep -n '_borg_register_hook "\$COCO_SETTINGS"' "$BORG_ZSH"
    [ "$status" -ne 0 ]
}
