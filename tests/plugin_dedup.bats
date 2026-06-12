#!/usr/bin/env bats
# Tests for B2 de-dup: _borg_unregister_hook in borg.zsh, and for B1 build-plugin.sh.
#
# B2 tests: verify that borg setup removes literal ~/.claude/hooks/... entries from
# settings.json without disturbing other hooks or permissions.
#
# B1 tests: verify build-plugin.sh basic behaviour (idempotency, --dry-run, self-containment).

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
CHECK_VERSION="${BATS_TEST_DIRNAME}/../scripts/check-plugin-version.sh"

# ─── Helpers ─────────────────────────────────────────────────────────────────

_fake_settings_with_hooks() {
    local settings="$1"
    cat > "$settings" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/borg-link-down.sh", "timeout": 10 }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/borg-link-up.sh", "timeout": 10 }]
      },
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/notify.sh", "timeout": 5 }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/bash-guard.sh", "timeout": 5 }]
      },
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "/some/external/hook.sh", "timeout": 10 }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/tool-count-nudge.sh", "timeout": 10 }]
      }
    ]
  },
  "permissions": {
    "allow": ["Bash(*)", "Read(*)"]
  },
  "model": "claude-sonnet-4-5"
}
EOF
}

# ─── B2: _borg_unregister_hook tests ─────────────────────────────────────────

@test "B2: _borg_unregister_hook removes matching hook entry from settings.json" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    _fake_settings_with_hooks "$settings"

    zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/borg-link-down.sh' 'SessionStart' 'borg-link-down.sh'
    "

    count=$(jq '.hooks.SessionStart // [] | length' "$settings")
    [ "$count" -eq 0 ]
}

@test "B2: _borg_unregister_hook leaves non-borg hooks intact" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    _fake_settings_with_hooks "$settings"

    zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/bash-guard.sh' 'PreToolUse' 'bash-guard.sh'
    "

    external_count=$(jq '[.hooks.PreToolUse[]?.hooks[]? | select(.command == "/some/external/hook.sh")] | length' "$settings")
    [ "$external_count" -eq 1 ]
}

@test "B2: _borg_unregister_hook preserves permissions and model keys" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    _fake_settings_with_hooks "$settings"

    zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/borg-link-up.sh' 'Stop' 'borg-link-up.sh'
    "

    model=$(jq -r '.model' "$settings")
    perm=$(jq -r '.permissions.allow[0]' "$settings")
    [ "$model" = "claude-sonnet-4-5" ]
    [ "$perm" = "Bash(*)" ]
}

@test "B2: _borg_unregister_hook is a no-op when hook not present" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    echo '{"hooks": {}, "model": "claude-sonnet-4-5"}' > "$settings"

    run zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/borg-link-down.sh' 'SessionStart' 'borg-link-down.sh'
    "
    [ "$status" -eq 0 ]

    model=$(jq -r '.model' "$settings")
    [ "$model" = "claude-sonnet-4-5" ]
}

@test "B2: _borg_unregister_hook removes multiple borg hooks leaving non-borg hooks" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    _fake_settings_with_hooks "$settings"

    zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/notify.sh' 'Stop' 'notify.sh'
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/borg-link-up.sh' 'Stop' 'borg-link-up.sh'
    "

    stop_count=$(jq '.hooks.Stop // [] | length' "$settings")
    [ "$stop_count" -eq 0 ]
}

@test "B2: _borg_unregister_hook preserves co-located non-borg hooks in a shared matcher block" {
    setup_temp_dirs
    local settings="$BORG_TEST_HOME/.claude/settings.json"
    mkdir -p "$(dirname "$settings")"
    cat > "$settings" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/session-log.sh", "timeout": 5 },
          { "type": "command", "command": "$HOME/.claude/hooks/borg-link-up.sh", "timeout": 30 }
        ]
      }
    ]
  },
  "model": "claude-sonnet-4-5"
}
EOF

    zsh -c "
        source '$BORG_ZSH' 2>/dev/null || true
        _borg_unregister_hook '$settings' '\$HOME/.claude/hooks/borg-link-up.sh' 'Stop' 'borg-link-up.sh'
    "

    # The co-located non-borg hook must survive; only the borg hook is removed.
    session_log=$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "$HOME/.claude/hooks/session-log.sh")] | length' "$settings")
    borg_hook=$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "$HOME/.claude/hooks/borg-link-up.sh")] | length' "$settings")
    [ "$session_log" -eq 1 ]
    [ "$borg_hook" -eq 0 ]
}

# ─── B1: build-plugin.sh tests ───────────────────────────────────────────────

@test "B1: build-plugin.sh exits 0 when plugin dir does not exist" {
    run bash "$BUILD_PLUGIN" 2>&1
    [ "$status" -eq 0 ]
}

@test "B1: build-plugin.sh --dry-run exits 0 and prints nothing harmful" {
    run bash "$BUILD_PLUGIN" --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | grep -qv "ERROR"
}

@test "B1: build-plugin.sh is idempotent — second run reports no changes" {
    local fake_plugin="${BATS_TEST_TMPDIR}/fake-plugin"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.2.0"}' > "$fake_plugin/.claude-plugin/plugin.json"
    mkdir -p "$fake_plugin/skills/borg-plan"
    touch "$fake_plugin/skills/borg-plan/SKILL.md"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$BUILD_PLUGIN' --dry-run 2>&1"
    [ "$status" -eq 0 ]
}

@test "B1: built hooks contain no source references to borg-hooks.sh" {
    local fake_plugin="${BATS_TEST_TMPDIR}/selfcontained-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.1.0"}' > "$fake_plugin/.claude-plugin/plugin.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    for hook in borg-link-down.sh borg-link-up.sh borg-notify.sh borg-plan-promote.sh; do
        if [[ -f "$fake_plugin/hooks/$hook" ]]; then
            run bash -c "grep -E '^source.*borg-hooks\.sh' '$fake_plugin/hooks/$hook'"
            [ "$status" -ne 0 ]
        fi
    done
}

@test "B1: built lifecycle hooks begin with borg guard" {
    local fake_plugin="${BATS_TEST_TMPDIR}/guard-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.1.0"}' > "$fake_plugin/.claude-plugin/plugin.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    for hook in borg-link-down.sh borg-link-up.sh borg-notify.sh; do
        if [[ -f "$fake_plugin/hooks/$hook" ]]; then
            grep -q "command -v borg" "$fake_plugin/hooks/$hook"
        fi
    done
}

@test "B1: generated hooks.json has top-level hooks wrapper" {
    local fake_plugin="${BATS_TEST_TMPDIR}/hooksjson-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.1.0"}' > "$fake_plugin/.claude-plugin/plugin.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    if [[ -f "$fake_plugin/hooks/hooks.json" ]]; then
        run jq -e '.hooks' "$fake_plugin/hooks/hooks.json"
        [ "$status" -eq 0 ]
    fi
}

@test "B1: generated hooks.json covers all 6 lifecycle events" {
    local fake_plugin="${BATS_TEST_TMPDIR}/events-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.1.0"}' > "$fake_plugin/.claude-plugin/plugin.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    if [[ -f "$fake_plugin/hooks/hooks.json" ]]; then
        for event in SessionStart Stop Notification PreToolUse PostToolUse SubagentStop; do
            run jq -e --arg ev "$event" '.hooks[$ev] | length > 0' "$fake_plugin/hooks/hooks.json"
            [ "$status" -eq 0 ]
        done
    fi
}

@test "B1: build-plugin.sh syncs plugin.json version from VERSION file" {
    local fake_plugin="${BATS_TEST_TMPDIR}/version-sync-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    echo '{"version": "0.2.16"}' > "$fake_plugin/.claude-plugin/plugin.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    cli_version=$(tr -d '[:space:]' < "${BATS_TEST_DIRNAME}/../VERSION")
    plugin_version=$(jq -r '.version' "$fake_plugin/.claude-plugin/plugin.json")
    [ "$plugin_version" = "$cli_version" ]
}

@test "B1: build-plugin.sh version sync is idempotent when already in sync" {
    local fake_plugin="${BATS_TEST_TMPDIR}/version-idempotent-test"
    mkdir -p "$fake_plugin/skills" "$fake_plugin/hooks" "$fake_plugin/agents" "$fake_plugin/.claude-plugin"
    cli_version=$(tr -d '[:space:]' < "${BATS_TEST_DIRNAME}/../VERSION")
    echo "{\"version\": \"$cli_version\"}" > "$fake_plugin/.claude-plugin/plugin.json"

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$BUILD_PLUGIN' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "version already in sync"
}

# ─── B1b: fresh-machine / path-agnostic tests ────────────────────────────────

@test "B1b: build-plugin.sh creates plugin dir when it does not exist (fresh machine)" {
    local fake_marketplace="${BATS_TEST_TMPDIR}/fresh-machine-marketplace"
    local fake_plugin="${fake_marketplace}/borg-collective"
    mkdir -p "$fake_marketplace/.claude-plugin"
    echo '{"name":"noah-local","plugins":[]}' > "$fake_marketplace/.claude-plugin/marketplace.json"

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$BUILD_PLUGIN' 2>&1"
    [ "$status" -eq 0 ]
    [ -d "$fake_plugin" ]
}

@test "B1b: build-plugin.sh creates plugin.json when it does not exist (fresh machine)" {
    local fake_plugin="${BATS_TEST_TMPDIR}/fresh-plugin-json"
    mkdir -p "$fake_plugin"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    [ -f "$fake_plugin/.claude-plugin/plugin.json" ]
    cli_version=$(tr -d '[:space:]' < "${BATS_TEST_DIRNAME}/../VERSION")
    plugin_version=$(jq -r '.version' "$fake_plugin/.claude-plugin/plugin.json")
    [ "$plugin_version" = "$cli_version" ]
}

@test "B1b: build-plugin.sh adds borg-collective entry to marketplace.json when absent" {
    local fake_marketplace="${BATS_TEST_TMPDIR}/marketplace-add-test"
    local fake_plugin="${fake_marketplace}/borg-collective"
    mkdir -p "$fake_marketplace/.claude-plugin"
    echo '{"name":"noah-local","plugins":[]}' > "$fake_marketplace/.claude-plugin/marketplace.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    has_entry=$(jq 'any(.plugins[]; .name == "borg-collective")' "$fake_marketplace/.claude-plugin/marketplace.json")
    [ "$has_entry" = "true" ]
}

@test "B1b: build-plugin.sh marketplace.json update is idempotent" {
    local fake_marketplace="${BATS_TEST_TMPDIR}/marketplace-idempotent-test"
    local fake_plugin="${fake_marketplace}/borg-collective"
    mkdir -p "$fake_marketplace/.claude-plugin"
    echo '{"name":"noah-local","plugins":[{"name":"borg-collective","description":"x","source":"./borg-collective"}]}' \
        > "$fake_marketplace/.claude-plugin/marketplace.json"

    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true
    PLUGIN_DIR_OVERRIDE="$fake_plugin" bash "$BUILD_PLUGIN" 2>&1 || true

    count=$(jq '[.plugins[] | select(.name == "borg-collective")] | length' \
        "$fake_marketplace/.claude-plugin/marketplace.json")
    [ "$count" -eq 1 ]
}

@test "B1b: build-plugin.sh script contains no hardcoded /Users/ path" {
    run grep -n '/Users/' "$BUILD_PLUGIN"
    [ "$status" -ne 0 ]
}

@test "B1b: build-plugin.sh uses HOME-derived default for plugin dir (no hardcoded username)" {
    local fake_home="${BATS_TEST_TMPDIR}/fake-home-user"
    local fake_marketplace="${fake_home}/dev/claude-plugins"
    local fake_plugin="${fake_marketplace}/borg-collective"
    mkdir -p "$fake_marketplace/.claude-plugin"
    echo '{"name":"noah-local","plugins":[]}' > "$fake_marketplace/.claude-plugin/marketplace.json"

    run bash -c "HOME='$fake_home' unset PLUGIN_DIR_OVERRIDE; HOME='$fake_home' bash '$BUILD_PLUGIN' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$fake_home"* ]] || [[ "$output" != *"/Users/noah"* ]]
}

# ─── B3: check-plugin-version.sh drift-guard tests ───────────────────────────

@test "B3: check-plugin-version.sh exits 0 when versions match" {
    local fake_plugin="${BATS_TEST_TMPDIR}/drift-guard-pass"
    mkdir -p "$fake_plugin/borg-collective/.claude-plugin"
    cli_version=$(tr -d '[:space:]' < "${BATS_TEST_DIRNAME}/../VERSION")
    echo "{\"version\": \"$cli_version\"}" > "$fake_plugin/borg-collective/.claude-plugin/plugin.json"

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$CHECK_VERSION'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK:"
}

@test "B3: check-plugin-version.sh exits 1 when versions differ" {
    local fake_plugin="${BATS_TEST_TMPDIR}/drift-guard-fail"
    mkdir -p "$fake_plugin/borg-collective/.claude-plugin"
    echo '{"version": "0.2.16"}' > "$fake_plugin/borg-collective/.claude-plugin/plugin.json"

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$CHECK_VERSION'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ERROR: version mismatch"
}

@test "B3: check-plugin-version.sh exits 1 when plugin.json not found" {
    local fake_plugin="${BATS_TEST_TMPDIR}/drift-guard-missing"
    mkdir -p "$fake_plugin/borg-collective"

    run bash -c "PLUGIN_DIR_OVERRIDE='$fake_plugin' bash '$CHECK_VERSION'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "not found"
}
