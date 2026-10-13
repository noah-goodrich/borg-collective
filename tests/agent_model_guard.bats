#!/usr/bin/env bats
# Tests for hooks/borg-agent-model-guard.sh — PreToolUse (Agent/Task) deny-by-default allowlist of
# subagent_type, with sonnet/haiku + low/medium/high caps. research-tools:* is exempt from the caps
# but allowed only when the session transcript shows a research-tools skill/command invocation.
# Policy: docs/agent-routing.md.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-agent-model-guard.sh"
WF_HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-workflow-model-guard.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
}

# _agent <tool_input-json> [transcript_path] [tool_name]
_agent() {
    local json
    json=$(jq -nc --argjson ti "$1" --arg tp "${2:-}" --arg tn "${3:-Agent}" \
        '{tool_name:$tn, tool_input:$ti} + (if $tp == "" then {} else {transcript_path:$tp} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

# --- 1. deny-by-default -------------------------------------------------------------------------

@test "missing subagent_type is denied and says what to use" {
    _agent '{"prompt":"x"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"subagent_type"* ]] || false
    [[ "$output" == *"borg-collective:borg-nanoprobe"* ]] || false
}

@test "the deny message names the Queen/drone session tier" {
    _agent '{"prompt":"x"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"Policy: Queen/drone sessions run Opus xhigh"* ]] || false
    [[ "$output" != *"orchestrator/drone"* ]] || false
}

@test "empty subagent_type is denied" {
    _agent '{"prompt":"x","subagent_type":""}'
    [ "$status" -eq 2 ]
}

@test "general-purpose is denied, pointing at the specialists" {
    _agent '{"subagent_type":"general-purpose"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"general-purpose"* ]] || false
    [[ "$output" == *"borg-collective:borg-nanoprobe"* ]] || false
}

@test "Explore is denied and redirected to borg-scout" {
    _agent '{"subagent_type":"Explore"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"use subagent_type borg-collective:borg-scout for read-only search"* ]] || false
}

@test "Plan is denied" {
    _agent '{"subagent_type":"Plan"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"Plan"* ]] || false
}

@test "fork is denied" {
    _agent '{"subagent_type":"fork"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"fork"* ]] || false
}

@test "the claude catch-all type is denied" {
    _agent '{"subagent_type":"claude"}'
    [ "$status" -eq 2 ]
}

@test "borg-collective:ROUTING is denied (a doc, not an agent)" {
    _agent '{"subagent_type":"borg-collective:ROUTING"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"docs/agent-routing.md"* ]] || false
}

@test "unknown types are denied, listing the allowlist" {
    _agent '{"subagent_type":"some-plugin:whatever"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"borg-collective:borg-scout"* ]] || false
    [[ "$output" == *"claude-code-guide"* ]] || false
}

@test "an un-namespaced specialist name is denied with the namespaced form" {
    _agent '{"subagent_type":"borg-scout"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"borg-collective:borg-scout"* ]] || false
}

# --- 2. allowlist + caps ------------------------------------------------------------------------

@test "all allowlisted types pass with no overrides" {
    local t
    for t in scout grunt nanoprobe researcher reviewer verifier; do
        _agent "{\"subagent_type\":\"borg-collective:borg-$t\"}"
        [ "$status" -eq 0 ] || { echo "borg-$t: $output"; false; }
    done
    _agent '{"subagent_type":"claude-code-guide","effort":"low"}'
    [ "$status" -eq 0 ]
}

@test "claude-code-guide with no effort is denied and the message names the fix" {
    _agent '{"subagent_type":"claude-code-guide"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"pins no effort"* ]] || false
    [[ "$output" == *"effort: 'low'"* ]] || false
}

@test "claude-code-guide with effort low is allowed and with xhigh is still denied" {
    _agent '{"subagent_type":"claude-code-guide","effort":"low"}'
    [ "$status" -eq 0 ]
    _agent '{"subagent_type":"claude-code-guide","effort":"xhigh"}'
    [ "$status" -eq 2 ]
}

@test "the legacy Task tool name is guarded too" {
    _agent '{"subagent_type":"general-purpose"}' "" Task
    [ "$status" -eq 2 ]
    _agent '{"subagent_type":"borg-collective:borg-scout"}' "" Task
    [ "$status" -eq 0 ]
}

@test "model opus or fable is denied on an allowed type" {
    local m
    for m in opus fable claude-opus-5-5 inherit; do
        _agent "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"model\":\"$m\"}"
        [ "$status" -eq 2 ] || { echo "model $m allowed"; false; }
        [[ "$output" == *"model"* ]] || false
    done
}

@test "effort xhigh or max is denied on an allowed type" {
    local e
    for e in xhigh max; do
        _agent "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"effort\":\"$e\"}"
        [ "$status" -eq 2 ] || { echo "effort $e allowed"; false; }
        [[ "$output" == *"effort"* ]] || false
    done
}

@test "model sonnet/haiku (alias or id) and effort low/medium/high are allowed" {
    local m e
    for m in sonnet haiku claude-sonnet-5-5 claude-haiku-4-5; do
        _agent "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"model\":\"$m\"}"
        [ "$status" -eq 0 ] || { echo "model $m: $output"; false; }
    done
    for e in low medium high; do
        _agent "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"effort\":\"$e\",\"model\":\"sonnet\"}"
        [ "$status" -eq 0 ] || { echo "effort $e: $output"; false; }
    done
}

@test "a non-string model is denied" {
    _agent '{"subagent_type":"borg-collective:borg-nanoprobe","model":5}'
    [ "$status" -eq 2 ]
}

# --- 3. research-tools:* needs a transcript invocation ------------------------------------------

_transcript() { printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/t.jsonl"; }

SKILL_RT='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"research-tools:research","args":"x"}}]}}'
SKILL_OTHER='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"borg-collective:borg-plan"}}]}}'
CMD_NS='{"type":"user","message":{"role":"user","content":"<command-message>research</command-message>\n<command-name>/research-tools:research</command-name>\n<command-args>x</command-args>"}}'
CMD_BARE_DEEP='{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<command-name>/deep-research</command-name>"}]}}'
CMD_BARE_BRAIN='{"type":"user","message":{"role":"user","content":"<command-name>/brainstorm</command-name>"}}'
CMD_OTHER='{"type":"user","message":{"role":"user","content":"<command-name>/borg-collective:borg-link</command-name>"}}'
# Mentions of the skill inside a tool result are not an invocation.
MENTION='{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"run research-tools:research <command-name>/research</command-name>"}]}}'

@test "research-tools type is denied with no transcript at all" {
    _agent '{"subagent_type":"research-tools:research-lead"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"research-tools"* ]] || false
    [[ "$output" == *"borg-collective:borg-researcher"* ]] || false
}

@test "research-tools type is denied when the transcript has no invocation" {
    _transcript "$SKILL_OTHER" "$CMD_OTHER" "$MENTION"
    _agent '{"subagent_type":"research-tools:research-lead"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 2 ]
}

@test "research-tools type is denied when the transcript path is unreadable" {
    _agent '{"subagent_type":"research-tools:research-lead"}' "${BATS_TEST_TMPDIR}/missing.jsonl"
    [ "$status" -eq 2 ]
}

@test "research-tools type is allowed after a research-tools Skill tool_use, any model/effort" {
    _transcript "$SKILL_OTHER" "$SKILL_RT"
    _agent '{"subagent_type":"research-tools:research-lead","model":"opus","effort":"max"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "research-tools type is allowed after a namespaced slash-command invocation" {
    _transcript "$CMD_NS"
    _agent '{"subagent_type":"research-tools:x","model":"opus"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "research-tools type is allowed after bare /deep-research and /brainstorm" {
    _transcript "$CMD_BARE_DEEP"
    _agent '{"subagent_type":"research-tools:x","effort":"xhigh"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
    _transcript "$CMD_BARE_BRAIN"
    _agent '{"subagent_type":"research-tools:x"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "a research invocation does not unlock non-research types or lift their caps" {
    _transcript "$SKILL_RT"
    _agent '{"subagent_type":"general-purpose"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 2 ]
    _agent '{"subagent_type":"borg-collective:borg-nanoprobe","model":"opus"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 2 ]
}

# --- fail-open on non-Agent / unreadable input, kill switch -------------------------------------

@test "non-Agent tool is ignored" {
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "malformed JSON and empty stdin are ignored" {
    run bash -c "printf '%s' '{not json' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
    run bash -c "printf '' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "BORG_AGENT_MODEL_GUARD=0 disables the guard" {
    export BORG_AGENT_MODEL_GUARD=0
    _agent '{"subagent_type":"general-purpose","model":"opus"}'
    [ "$status" -eq 0 ]
}

# --- wiring + drift ----------------------------------------------------------------------------

@test "wiring: build-plugin.sh copies the hook and registers an Agent|Task PreToolUse matcher" {
    grep -qE '_build_self_contained_hook .*borg-agent-model-guard\.sh' "$BUILD_PLUGIN"
    run grep -B7 -A2 'borg-agent-model-guard.sh"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"matcher": "Agent|Task"'* ]] || false
}

@test "the Agent and Workflow guards embed the identical policy block" {
    local a w
    a=$(sed -n '/^# POLICY-BEGIN/,/^# POLICY-END/p' "$HOOK")
    w=$(sed -n '/^# POLICY-BEGIN/,/^# POLICY-END/p' "$WF_HOOK")
    [ -n "$a" ]
    [ "$a" = "$w" ]
}

@test "the allowlist names every roster agent file plus the verifier and claude-code-guide" {
    local f n
    for f in "${BATS_TEST_DIRNAME}"/../agents/borg-*.md; do
        n=${f##*/}; n=${n%.md}
        grep -q "borg-collective:$n" "$HOOK" || { echo "allowlist missing $n"; false; }
    done
    grep -q "borg-collective:borg-verifier" "$HOOK"
    grep -q "claude-code-guide" "$HOOK"
}

# --- docs / card / skill state the policy --------------------------------------------------------

@test "docs/agent-routing.md states the policy and no longer claims an opus[1m] default" {
    local doc="${BATS_TEST_DIRNAME}/../docs/agent-routing.md"
    grep -q "xhigh" "$doc"
    grep -q "research-tools" "$doc"
    grep -q "borg-collective:borg-verifier" "$doc"
    grep -q 'subagent_type:"claude-code-guide", effort:"low"' "$doc"
    grep -q 'agentType: "claude-code-guide", effort: "low"' "$doc"
    ! grep -q "opus\[1m\]" "$doc"
    ! grep -q "inherit-ok" "$doc"
}

@test "the SessionStart routing card states the allowlist, the caps and the research exception" {
    local hook="${BATS_TEST_DIRNAME}/../hooks/borg-link-down.sh"
    grep -q "deny-by-default allowlist" "$hook"
    grep -q "sonnet/haiku" "$hook"
    grep -q "research-tools" "$hook"
    grep -q "claude-code-guide requires effort" "$hook"
    ! grep -q "inherit-ok" "$hook"
}

@test "fable-reviewer says agentType, or model + effort" {
    grep -q "agentType, or model + effort" "${BATS_TEST_DIRNAME}/../skills/fable-reviewer/SKILL.md"
}
