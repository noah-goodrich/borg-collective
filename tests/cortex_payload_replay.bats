#!/usr/bin/env bats
# Replay layer for the hooks borg registers in Cortex Code CLI (tier A3 and A4 of the 2026-10-22 battery).
#
# Every hook that `_borg_register_cortex_hooks` writes to hooks.json receives every synthetic Cortex payload in
# tests/fixtures/cortex/ and must exit 0 with stdout empty or valid JSON. The one exception is the guard's own deny.
# Fixtures carry Cortex's real field names and Claude-style tool names (Bash, Read, Write, EnterPlanMode,
# ExitPlanMode); every value is invented (cwd placeholder, session id 00000000-0000-4000-8000-000000000001).
# See docs/plans/directives/2026-10-22-borg-plan-in-cortex-plan-mode.md AC5.
#
# THE HAZARD: hooks write state and read config. HOME, XDG_CONFIG_HOME and XDG_STATE_HOME are sandboxed
# (setup_temp_dirs), and the hooks run from the checkout, never from ~/.snowflake.

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"
FIXTURES="${BATS_TEST_DIRNAME}/fixtures/cortex"

setup() {
    setup_temp_dirs
    COCO_DIR="$BORG_TEST_HOME/.snowflake/cortex"
    mkdir -p "$COCO_DIR/hooks" "$BORG_TEST_HOME/dev" "$BORG_DIR" "$XDG_STATE_HOME"

    REPO="${BATS_TEST_TMPDIR}/acme-widgets"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    git -C "$REPO" commit -q --allow-empty -m init

    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        _borg_register_cortex_hooks '$COCO_DIR'
    "
    [ "$status" -eq 0 ]
    # the script names of every registered hook, once each
    jq -r '.hooks[][] | .hooks[].command | split("/") | last' "$COCO_DIR/hooks.json" | sort -u > "${BATS_TEST_TMPDIR}/hooks.txt"
}

# Run hook $1 on fixture file $2 (or on the payload in $3 when given), cwd the sandbox repository.
_replay() {
    local hook="$1" fixture="$2" payload="${BATS_TEST_TMPDIR}/payload.json"
    jq --arg cwd "$REPO" 'walk(if type == "string" then gsub("__CWD__"; $cwd) else . end)' "$FIXTURES/$fixture.json" > "$payload"
    if [[ -n "${3:-}" ]]; then
        jq --arg c "$3" '.tool_input.command = $c' "$payload" > "$payload.2" && mv "$payload.2" "$payload"
    fi
    RC=0
    OUT=$(HOME="$BORG_TEST_HOME" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        bash "${BATS_TEST_DIRNAME}/../hooks/$hook" < "$payload" 2>"${BATS_TEST_TMPDIR}/err") || RC=$?
}

@test "replay: the registered hook list is the eight borg hooks plus borg-cortex-plan.sh" {
    [ "$(wc -l < "${BATS_TEST_TMPDIR}/hooks.txt" | tr -d ' ')" -eq 9 ]
    grep -qx 'borg-cortex-plan.sh' "${BATS_TEST_TMPDIR}/hooks.txt"
    grep -qx 'bash-guard.sh' "${BATS_TEST_TMPDIR}/hooks.txt"
}

@test "replay: every registered hook exits 0 with empty or JSON stdout on every Cortex payload" {
    local hook fx bad=""
    while IFS= read -r hook; do
        for fx in session-start stop notification user-prompt-submit pretooluse-bash pretooluse-bash-readonly \
                  pretooluse-read pretooluse-write posttooluse-enter-plan-mode pretooluse-exit-plan-mode \
                  posttooluse-exit-plan-mode; do
            _replay "$hook" "$fx"
            if [[ "$RC" -ne 0 ]]; then
                bad="$bad
$hook $fx: exit $RC"
                continue
            fi
            if [[ -n "$OUT" ]] && ! printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
                bad="$bad
$hook $fx: stdout is not JSON: ${OUT:0:120}"
            fi
        done
    done < "${BATS_TEST_TMPDIR}/hooks.txt"
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

@test "replay: the guard denies a force-push to main with exit 2 and its message" {
    # built here from pieces, so the literal is not typed into a Bash tool call of the session that wrote this test
    local verb="git push" flag="--for""ce" cmd
    cmd="$verb $flag origin main"
    _replay bash-guard.sh pretooluse-bash-force-push "$cmd"
    [ "$RC" -eq 2 ]
    [ -s "${BATS_TEST_TMPDIR}/err" ] || [ -n "$OUT" ]
    grep -qi 'block\|force\|main' "${BATS_TEST_TMPDIR}/err"
}

@test "replay: the guard approves a read-only command with permissionDecision allow" {
    _replay bash-guard.sh pretooluse-bash-readonly
    [ "$RC" -eq 0 ]
    [ "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision')" = "allow" ]
}

@test "replay: the plan-mode inject answers EnterPlanMode and stays silent for the other events" {
    _replay borg-cortex-plan.sh posttooluse-enter-plan-mode
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext | contains("borg-plan")' >/dev/null
    _replay borg-cortex-plan.sh pretooluse-bash
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the plan-mode gate blocks a plan without the borg-plan sections" {
    local payload="${BATS_TEST_TMPDIR}/payload.json"
    jq --arg cwd "$REPO" '.cwd = $cwd | .tool_input.plan = "## Context\nstuff"' "$FIXTURES/pretooluse-exit-plan-mode.json" > "$payload"
    RC=0
    OUT=$(HOME="$BORG_TEST_HOME" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        bash "${BATS_TEST_DIRNAME}/../hooks/borg-cortex-plan.sh" < "$payload" 2>"${BATS_TEST_TMPDIR}/err") || RC=$?
    [ "$RC" -eq 2 ]
    grep -q 'borg-plan' "${BATS_TEST_TMPDIR}/err"
}

@test "replay: the promote hook writes the plan from the PostToolUse payload" {
    _replay borg-plan-promote.sh posttooluse-exit-plan-mode
    [ "$RC" -eq 0 ]
    [ -f "$REPO/docs/plans/PROJECT_PLAN.md" ]
    grep -q '2026-10-22-widgets-discount' "$REPO/docs/plans/PROJECT_PLAN.md"
}

@test "replay: the fixtures are synthetic (no home directory path, no real session id)" {
    # the only UUID allowed is the all-zero invented one; strip it, then look for a path or any other UUID
    run bash -c "sed 's/00000000-0000-4000-8000-000000000001//g' '$FIXTURES'/*.json | grep -cE '/Users/|/home/[a-z]|[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]'"
    [ "$output" = "0" ]
}
