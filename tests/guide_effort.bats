#!/usr/bin/env bats
# Tests for the claude-code-guide effort rule in hooks/borg-agent-model-guard.sh and
# hooks/borg-workflow-model-guard.sh: the built-in pins no effort, so both guards require an explicit
# low/medium/high. Policy: docs/agent-routing.md.

load test_helper/setup

AGENT_HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-agent-model-guard.sh"
WF_HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-workflow-model-guard.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash

setup() {
    setup_temp_dirs
    mkdir -p "$HOME"
}

# _agent <tool_input-json> [transcript_path] [tool_name]
_agent() {
    local json
    json=$(jq -nc --argjson ti "$1" --arg tp "${2:-}" --arg tn "${3:-Agent}" \
        '{tool_name:$tn, tool_input:$ti} + (if $tp == "" then {} else {transcript_path:$tp} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$AGENT_HOOK' 2>&1" _ "$json"
}

# Feed a workflow script (as tool_input.script) to the workflow hook; optional 2nd arg = transcript path.
_run_script() {
    local json
    json=$(jq -nc --arg s "$1" --arg tp "${2:-}" \
        '{tool_name:"Workflow", tool_input:{script:$s}} + (if $tp == "" then {} else {transcript_path:$tp} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$WF_HOOK' 2>&1" _ "$json"
}

_transcript() { printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/t.jsonl"; }

SKILL_RT='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"research-tools:research","args":"x"}}]}}'

@test "a padded claude-code-guide type cannot skip the effort rule" {
    _agent '{"subagent_type":" claude-code-guide "}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"pins no effort"* ]] || false
}

@test "borg-collective and research-tools types with no effort are not hit by the guide effort rule" {
    _agent '{"subagent_type":"borg-collective:borg-scout"}'
    [ "$status" -eq 0 ]
    _transcript "$SKILL_RT"
    _agent '{"subagent_type":"research-tools:research-lead"}' "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "the deny policy text says claude-code-guide needs effort low/medium/high" {
    _agent '{"subagent_type":"general-purpose"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"claude-code-guide also needs effort low/medium/high"* ]] || false
}

@test "a padded claude-code-guide agentType cannot skip the effort rule" {
    _run_script "await agent('q', { agentType: ' claude-code-guide ' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"pins no effort"* ]] || false
}

@test "claude-code-guide with effort xhigh or max is denied" {
    _run_script "await agent('q', { agentType: 'claude-code-guide', effort: 'xhigh' })"
    [ "$status" -eq 2 ]
    _run_script "await agent('q', { agentType: 'claude-code-guide', effort: 'max' })"
    [ "$status" -eq 2 ]
}

@test "claude-code-guide with effort from a const holding low is allowed" {
    _run_script "const E = 'low'; await agent('q', { agentType: 'claude-code-guide', effort: E })"
    [ "$status" -eq 0 ]
}

@test "claude-code-guide with model haiku and effort low is allowed" {
    _run_script "await agent('q', { agentType: 'claude-code-guide', model: 'haiku', effort: 'low' })"
    [ "$status" -eq 0 ]
}

@test "borg-collective and research-tools agentTypes with no effort are not hit by the workflow guide effort rule" {
    _run_script "await agent('q', { agentType: 'borg-collective:borg-scout' })"
    [ "$status" -eq 0 ]
    _transcript "$SKILL_RT"
    _run_script "await agent('p', { agentType: 'research-tools:research-lead' })" "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "the workflow deny policy text says claude-code-guide needs effort low/medium/high" {
    _run_script "await agent('q', { model: 'opus', effort: 'low' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"claude-code-guide also needs effort low/medium/high"* ]] || false
}
