#!/usr/bin/env bats
# Tests for hooks/borg-cortex-plan.sh: the Cortex-only inject (PostToolUse EnterPlanMode) and gate (PreToolUse
# ExitPlanMode) hooks. See docs/plans/directives/2026-10-22-borg-plan-in-cortex-plan-mode.md (AC2, AC3).
# Payloads are synthetic: shapes recorded from Cortex 1.2.14 and 1.2.18 on 2026-10-22, values invented.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-cortex-plan.sh"
SID="00000000-0000-4000-8000-000000000001"

GOOD_PLAN=$'# Project Plan: widgets discount\n\n- Plan-slug: `2026-10-22-widgets-discount`\n\n## Objective\nAdd a discount.\n\n## Acceptance Criteria\n1. It works. Verify: pytest\n\n## Scope Boundaries\nNOT building: coupons.\n\n## Ship Definition\nMerged.'

setup() {
    setup_temp_dirs
    REPO="${BATS_TEST_TMPDIR}/acme-widgets"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    git -C "$REPO" commit -q --allow-empty -m init
    mkdir -p "${BORG_TEST_HOME}/dev"
}

# Arguments: event tool cwd [plan]
_payload() {
    jq -nc --arg e "$1" --arg t "$2" --arg cwd "$3" --arg plan "${4:-}" --arg sid "$SID" '
        {session_id: $sid, transcript_path: "/work/.cortex/conversations/x.json", cwd: $cwd,
         permission_mode: "default", hook_event_name: $e, tool_name: $t, tool_use_id: "toolu_synthetic01"}
        + (if $t == "EnterPlanMode" or $t == "enter_plan_mode" then {tool_input: {reason: "Plan the change"}}
           else {tool_input: {plan: $plan}} end)'
}

_run() {
    # stderr kept apart: the gate speaks on stderr, the inject on stdout
    HOOK_RC=0
    HOOK_OUT=$(HOME="$BORG_TEST_HOME" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        bash "$HOOK" <<< "$1" 2>"${BATS_TEST_TMPDIR}/err") || HOOK_RC=$?
    HOOK_ERR=$(cat "${BATS_TEST_TMPDIR}/err")
}

_has() { [[ "$1" == *"$2"* ]] || { echo "missing: $2 in: $1"; return 1; }; }

# ── gate ──────────────────────────────────────────────────────────────────────

@test "gate: a plan with all three borg-plan markers passes silently" {
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "$GOOD_PLAN")"
    [ "$HOOK_RC" -eq 0 ]
    [ -z "$HOOK_OUT" ]
    [ -z "$HOOK_ERR" ]
}

@test "gate: a native Cortex plan is blocked with exit 2 and a borg-plan message naming everything missing" {
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" $'## Context\nstuff\n\n## Steps\n1. do it')"
    [ "$HOOK_RC" -eq 2 ]
    [ -z "$HOOK_OUT" ]
    _has "$HOOK_ERR" "borg-plan"
    _has "$HOOK_ERR" "Acceptance-Criteria"
    _has "$HOOK_ERR" "Scope-Boundaries"
    _has "$HOOK_ERR" "Plan-slug"
}

@test "gate: each marker missing alone blocks, and only that one is named" {
    local plan
    plan=$(printf '%s' "$GOOD_PLAN" | grep -v -i 'acceptance criteria')
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "$plan")"
    [ "$HOOK_RC" -eq 2 ]
    _has "$HOOK_ERR" "missing: Acceptance-Criteria."

    plan=$(printf '%s' "$GOOD_PLAN" | grep -v -i -E 'scope boundaries|NOT building')
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "$plan")"
    [ "$HOOK_RC" -eq 2 ]
    _has "$HOOK_ERR" "missing: Scope-Boundaries."

    plan=$(printf '%s' "$GOOD_PLAN" | grep -v -i 'plan-slug')
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "$plan")"
    [ "$HOOK_RC" -eq 2 ]
    _has "$HOOK_ERR" "missing: Plan-slug."
}

@test "gate: a NOT building line stands in for a Scope Boundaries heading, and the slug match ignores case" {
    local plan=$'## Acceptance criteria\nx\n\nNOT building: coupons\n\n- PLAN-SLUG: `2026-10-22-x`'
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "$plan")"
    [ "$HOOK_RC" -eq 0 ]
}

@test "gate: the lowercase exit_plan_mode tool name is gated too" {
    _run "$(_payload PreToolUse exit_plan_mode "$REPO" "just a plan")"
    [ "$HOOK_RC" -eq 2 ]
}

@test "gate: no-op in the Queen session" {
    _run "$(_payload PreToolUse ExitPlanMode "${BORG_TEST_HOME}/dev" "just a plan")"
    [ "$HOOK_RC" -eq 0 ]
    [ -z "$HOOK_ERR" ]
}

@test "gate: no-op outside a git repository" {
    mkdir -p "${BATS_TEST_TMPDIR}/plain"
    _run "$(_payload PreToolUse ExitPlanMode "${BATS_TEST_TMPDIR}/plain" "just a plan")"
    [ "$HOOK_RC" -eq 0 ]
}

@test "gate: no-op when docs/plans/PROJECT_PLAN.md or the root PROJECT_PLAN.md exists" {
    mkdir -p "$REPO/docs/plans"
    : > "$REPO/docs/plans/PROJECT_PLAN.md"
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "just a plan")"
    [ "$HOOK_RC" -eq 0 ]

    rm "$REPO/docs/plans/PROJECT_PLAN.md"
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "just a plan")"
    [ "$HOOK_RC" -eq 2 ]

    : > "$REPO/PROJECT_PLAN.md"
    _run "$(_payload PreToolUse ExitPlanMode "$REPO" "just a plan")"
    [ "$HOOK_RC" -eq 0 ]
}

@test "gate: BORG_PLAN_GATE=off is the escape hatch" {
    HOOK_OUT=$(BORG_PLAN_GATE=off HOME="$BORG_TEST_HOME" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        bash "$HOOK" <<< "$(_payload PreToolUse ExitPlanMode "$REPO" "just a plan")" 2>&1)
    [ -z "$HOOK_OUT" ]
}

@test "gate: a subdirectory of the repository resolves to the repository root" {
    mkdir -p "$REPO/src/deep"
    : > "$REPO/PROJECT_PLAN.md"
    _run "$(_payload PreToolUse ExitPlanMode "$REPO/src/deep" "just a plan")"
    [ "$HOOK_RC" -eq 0 ]
}

# ── inject ────────────────────────────────────────────────────────────────────

@test "inject: EnterPlanMode PostToolUse prints additionalContext JSON naming the borg-plan skill and template" {
    _run "$(_payload PostToolUse EnterPlanMode "$REPO")"
    [ "$HOOK_RC" -eq 0 ]
    [ -z "$HOOK_ERR" ]
    printf '%s' "$HOOK_OUT" | jq -e . >/dev/null
    [ "$(printf '%s' "$HOOK_OUT" | jq -r '.hookSpecificOutput.hookEventName')" = "PostToolUse" ]
    local ctx
    ctx=$(printf '%s' "$HOOK_OUT" | jq -r '.hookSpecificOutput.additionalContext')
    _has "$ctx" "borg-plan skill"
    _has "$ctx" "Acceptance Criteria"
    _has "$ctx" "Verify:"
    _has "$ctx" "NOT building:"
    _has "$ctx" "Ship Definition"
    _has "$ctx" "Timeline"
    _has "$ctx" "Risks"
    _has "$ctx" "Plan-slug"
    _has "$ctx" "Do not write PROJECT_PLAN.md yourself"
}

@test "inject: the lowercase enter_plan_mode tool name injects too" {
    _run "$(_payload PostToolUse enter_plan_mode "$REPO")"
    [ "$HOOK_RC" -eq 0 ]
    printf '%s' "$HOOK_OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

@test "inject: no-op in the Queen session, outside git, with a PROJECT_PLAN.md, and with BORG_PLAN_GATE=off" {
    _run "$(_payload PostToolUse EnterPlanMode "${BORG_TEST_HOME}/dev")"
    [ "$HOOK_RC" -eq 0 ]; [ -z "$HOOK_OUT" ]

    mkdir -p "${BATS_TEST_TMPDIR}/plain"
    _run "$(_payload PostToolUse EnterPlanMode "${BATS_TEST_TMPDIR}/plain")"
    [ "$HOOK_RC" -eq 0 ]; [ -z "$HOOK_OUT" ]

    mkdir -p "$REPO/docs/plans"
    : > "$REPO/docs/plans/PROJECT_PLAN.md"
    _run "$(_payload PostToolUse EnterPlanMode "$REPO")"
    [ "$HOOK_RC" -eq 0 ]; [ -z "$HOOK_OUT" ]
    rm "$REPO/docs/plans/PROJECT_PLAN.md"
    : > "$REPO/PROJECT_PLAN.md"
    _run "$(_payload PostToolUse EnterPlanMode "$REPO")"
    [ "$HOOK_RC" -eq 0 ]; [ -z "$HOOK_OUT" ]
    rm "$REPO/PROJECT_PLAN.md"

    HOOK_OUT=$(BORG_PLAN_GATE=off HOME="$BORG_TEST_HOME" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        bash "$HOOK" <<< "$(_payload PostToolUse EnterPlanMode "$REPO")" 2>&1)
    [ -z "$HOOK_OUT" ]
}

# ── dispatch ──────────────────────────────────────────────────────────────────

@test "dispatch: other events and tools are ignored, including the wrong event for a plan-mode tool" {
    local ev tool
    for pair in "PreToolUse EnterPlanMode" "PostToolUse ExitPlanMode" "PreToolUse Bash" "PostToolUse Write" "SessionStart none" "Stop none"; do
        ev=${pair% *}; tool=${pair#* }
        _run "$(_payload "$ev" "$tool" "$REPO" "just a plan")"
        [ "$HOOK_RC" -eq 0 ] || { echo "rc $HOOK_RC for $pair"; return 1; }
        [ -z "$HOOK_OUT" ] || { echo "output for $pair"; return 1; }
        [ -z "$HOOK_ERR" ] || { echo "stderr for $pair"; return 1; }
    done
}

@test "dispatch: empty stdin and malformed JSON exit 0" {
    _run ""
    [ "$HOOK_RC" -eq 0 ]
    _run "{ not json"
    [ "$HOOK_RC" -eq 0 ]
}

@test "dispatch: the hook is not in the Claude Code plugin hook list" {
    run grep -c 'borg-cortex-plan' "${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
    [ "$output" = "0" ]
}
