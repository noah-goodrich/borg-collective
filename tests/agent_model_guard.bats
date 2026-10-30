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
    # The guard reads CORTEX_PROJECT_DIR as "running under Cortex Code"; the Claude Code cases must not inherit it.
    unset CORTEX_PROJECT_DIR
}

# _agent <tool_input-json> [transcript_path] [tool_name]
_agent() {
    local json
    json=$(jq -nc --argjson ti "$1" --arg tp "${2:-}" --arg tn "${3:-Agent}" \
        '{tool_name:$tn, tool_input:$ti} + (if $tp == "" then {} else {transcript_path:$tp} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

# _cortex <tool_input-json>: the same call the way Cortex Code delivers it (tool_name Task, CORTEX_PROJECT_DIR set).
_cortex() {
    local json
    json=$(jq -nc --argjson ti "$1" '{hook_event_name:"PreToolUse", tool_name:"Task", tool_input:$ti,
        transcript_path:"/work/.cortex/conversations/00000000-0000-4000-8000-000000000001.json"}')
    run bash -c "printf '%s' \"\$1\" | CORTEX_PROJECT_DIR=/work '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
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

# --- Cortex Code (CORTEX_PROJECT_DIR set, tool_name Task) ----------------------------------------------------------
# Measured live on Cortex 1.2.18 (evals/cortex-agents): agents resolve by their exact `name:`, so borg's are installed
# as borg-collective:<name>; a per-call model is honored as a full id and ignored as an alias.

CORTEX_SPECIALISTS="snowflake-object-discovery semantic-view-transform dbt-verify sql-verify feedback"

@test "cortex: every namespaced borg agent passes with no overrides" {
    local t
    for t in scout grunt nanoprobe researcher reviewer verifier; do
        _cortex "{\"subagent_type\":\"borg-collective:borg-$t\",\"description\":\"d\",\"prompt\":\"p\"}"
        [ "$status" -eq 0 ] || { echo "borg-$t: $output"; false; }
    done
}

@test "cortex: a full sonnet/haiku id passes and an alias is denied with the full-id fix" {
    local m
    for m in claude-sonnet-5-5 claude-haiku-5-5 claude-haiku-4-5; do
        _cortex "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"model\":\"$m\"}"
        [ "$status" -eq 0 ] || { echo "model $m: $output"; false; }
    done
    for m in sonnet haiku Sonnet; do
        _cortex "{\"subagent_type\":\"borg-collective:borg-nanoprobe\",\"model\":\"$m\"}"
        [ "$status" -eq 2 ] || { echo "alias $m allowed"; false; }
        [[ "$output" == *"alias, which Cortex ignores"* ]] || false
        [[ "$output" == *"claude-sonnet-5-5"* ]] || false
    done
}

@test "cortex: an opus pin, xhigh effort or a non-string model is still denied on a borg agent" {
    _cortex '{"subagent_type":"borg-collective:borg-nanoprobe","model":"claude-opus-5-5"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"above the cap"* ]] || false
    _cortex '{"subagent_type":"borg-collective:borg-nanoprobe","effort":"max"}'
    [ "$status" -eq 2 ]
    _cortex '{"subagent_type":"borg-collective:borg-nanoprobe","model":5}'
    [ "$status" -eq 2 ]
}

@test "cortex: Explore, Plan, general-purpose and untyped spawns are denied, even with a full-id pin" {
    local t
    for t in Explore Plan general-purpose; do
        _cortex "{\"subagent_type\":\"$t\",\"model\":\"claude-haiku-5-5\"}"
        [ "$status" -eq 2 ] || { echo "$t allowed"; false; }
        [[ "$output" == *"borg-collective:borg-"* ]] || false
    done
    _cortex '{"description":"d","prompt":"p"}'
    [ "$status" -eq 2 ]
}

@test "cortex: a bare borg name is denied and pointed at the namespaced form" {
    _cortex '{"subagent_type":"borg-verifier"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"borg-collective:borg-verifier"* ]] || false
}

@test "cortex: each Cortex Snowflake agent with no model is denied and the message names the fix" {
    local t
    for t in $CORTEX_SPECIALISTS; do
        _cortex "{\"subagent_type\":\"$t\",\"description\":\"d\",\"prompt\":\"p\"}"
        [ "$status" -eq 2 ] || { echo "$t allowed unpinned"; false; }
        [[ "$output" == *"'$t' pins no model"* ]] || false
        [[ "$output" == *"model: 'claude-sonnet-5-5'"* ]] || false
    done
}

@test "cortex: each Cortex Snowflake agent passes with a full sonnet or haiku id" {
    local t m
    for t in $CORTEX_SPECIALISTS; do
        for m in claude-sonnet-5-5 claude-haiku-5-5; do
            _cortex "{\"subagent_type\":\"$t\",\"model\":\"$m\"}"
            [ "$status" -eq 0 ] || { echo "$t $m: $output"; false; }
        done
    done
}

@test "cortex: a Cortex Snowflake agent with an alias, an opus pin or xhigh effort is denied" {
    _cortex '{"subagent_type":"dbt-verify","model":"haiku"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"alias, which Cortex ignores"* ]] || false
    _cortex '{"subagent_type":"sql-verify","model":"claude-opus-5-5"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"above the cap"* ]] || false
    _cortex '{"subagent_type":"snowflake-object-discovery","model":"claude-sonnet-5-5","effort":"xhigh"}'
    [ "$status" -eq 2 ]
}

@test "claude: the Cortex Snowflake agents stay off the allowlist, and aliases stay allowed" {
    local t
    for t in $CORTEX_SPECIALISTS; do
        _agent "{\"subagent_type\":\"$t\",\"model\":\"claude-sonnet-5-5\"}"
        [ "$status" -eq 2 ] || { echo "$t allowed in Claude Code"; false; }
    done
    _agent '{"subagent_type":"borg-collective:borg-nanoprobe","model":"sonnet"}'
    [ "$status" -eq 0 ]
}

@test "cortex: an empty CORTEX_PROJECT_DIR is Claude Code, and the kill switch works under Cortex" {
    local json
    json='{"tool_name":"Task","tool_input":{"subagent_type":"borg-collective:borg-nanoprobe","model":"sonnet"}}'
    run bash -c "printf '%s' '$json' | CORTEX_PROJECT_DIR= '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    export BORG_AGENT_MODEL_GUARD=0
    _cortex '{"subagent_type":"Explore"}'
    [ "$status" -eq 0 ]
}

@test "cortex: the Cortex rules sit outside the shared POLICY block" {
    run bash -c "sed -n '/^# POLICY-BEGIN/,/^# POLICY-END/p' '$HOOK' | grep -c 'CORTEX'"
    [ "$output" = "0" ]
    grep -q '^CORTEX_SPECIALISTS = ' "$HOOK"
    ! grep -q 'CORTEX_SPECIALISTS' "$WF_HOOK"
}
