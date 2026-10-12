#!/usr/bin/env bats
# Tests for hooks/borg-workflow-model-guard.sh — PreToolUse (Workflow) guard. Every agent() call must
# carry an allowlisted agentType (research-tools:* only after a research-tools invocation) or, with no
# agentType, model sonnet/haiku AND effort low/medium/high. Any model/effort given alongside an
# agentType meets the same caps (research-tools exempt). Fails CLOSED: options that are not an object
# literal, scripts that cannot be parsed, and script paths/names that cannot be resolved are denied.
# The /* inherit-ok */ escape hatch is gone. Policy: docs/agent-routing.md.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-workflow-model-guard.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    mkdir -p "$HOME"
}

# Feed a workflow script (as tool_input.script) to the hook; optional 2nd arg = transcript path.
_run_script() {
    local json
    json=$(jq -nc --arg s "$1" --arg tp "${2:-}" \
        '{tool_name:"Workflow", tool_input:{script:$s}} + (if $tp == "" then {} else {transcript_path:$tp} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

_run_json() {
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$1"
}

SCOUT="'borg-collective:borg-scout'"

# --- allowlist + caps ---------------------------------------------------------------------------

@test "agentType on the allowlist, no overrides, is allowed" {
    local t
    for t in scout grunt nanoprobe researcher reviewer verifier; do
        _run_script "await agent('find x', { label: 'scan', agentType: 'borg-collective:borg-$t' })"
        [ "$status" -eq 0 ] || { echo "borg-$t: $output"; false; }
    done
    _run_script "await agent('q', { agentType: 'claude-code-guide', effort: 'low' })"
    [ "$status" -eq 0 ]
}

@test "agentType claude-code-guide with no effort is denied" {
    _run_script "await agent('q', { agentType: 'claude-code-guide' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"pins no effort"* ]] || false
}

@test "model + effort within the caps and no agentType is allowed" {
    _run_script "await agent('write', { model: 'sonnet', effort: 'medium' })"
    [ "$status" -eq 0 ]
    _run_script "await agent('write', { model: 'claude-haiku-4-5', effort: 'low' })"
    [ "$status" -eq 0 ]
}

@test "model only (no effort, no agentType) is denied" {
    _run_script "await agent('write', { label: 'w', model: 'sonnet' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"effort"* ]] || false
    [[ "$output" == *"label 'w'"* ]] || false
}

@test "effort only (no model, no agentType) is denied" {
    _run_script "await agent('write', { effort: 'low' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"model"* ]] || false
}

@test "no options at all is denied, naming the line and the fix" {
    _run_script $'const a = 1\nawait agent(`do (this)`)'
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 2"* ]] || false
    [[ "$output" == *"borg-collective:borg-scout"* ]] || false
}

@test "unpinned options (label only) are denied" {
    _run_script "await agent('p', { label: 'scan' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 1 (label 'scan')"* ]] || false
}

@test "only the offending call among several is named" {
    _run_script $'await agent(\'a\', { agentType: \'borg-collective:borg-scout\' })\nawait agent(\'b\')\nawait agent(\'c\', { model: \'haiku\', effort: \'low\' })'
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 2"* ]] || false
    [[ "$output" != *"line 1"* ]] || false
    [[ "$output" != *"line 3"* ]] || false
}

@test "opus, fable and inherit models are denied, with or without agentType" {
    local m
    for m in opus fable inherit claude-opus-5-5; do
        _run_script "await agent('p', { model: '$m', effort: 'low' })"
        [ "$status" -eq 2 ] || { echo "no-agentType model $m allowed"; false; }
        _run_script "await agent('p', { agentType: $SCOUT, model: '$m' })"
        [ "$status" -eq 2 ] || { echo "agentType model $m allowed"; false; }
    done
}

@test "effort xhigh and max are denied, with or without agentType" {
    local e
    for e in xhigh max; do
        _run_script "await agent('p', { model: 'sonnet', effort: '$e' })"
        [ "$status" -eq 2 ] || { echo "effort $e allowed"; false; }
        _run_script "await agent('p', { agentType: $SCOUT, effort: '$e' })"
        [ "$status" -eq 2 ] || { echo "agentType effort $e allowed"; false; }
    done
}

@test "agentType off the allowlist is denied, each with a fix" {
    local t
    for t in general-purpose Explore Plan fork claude borg-collective:ROUTING borg-scout some:thing; do
        _run_script "await agent('p', { agentType: '$t' })"
        [ "$status" -eq 2 ] || { echo "agentType $t allowed"; false; }
        [[ "$output" == *"borg-collective:borg-"* ]] || { echo "no fix for $t: $output"; false; }
    done
}

@test "inherit-ok comment no longer bypasses the guard" {
    _run_script "await agent('hard open-ended', { /* inherit-ok */ label: 'think' })"
    [ "$status" -eq 2 ]
}

# --- research-tools -----------------------------------------------------------------------------

_transcript() { printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/t.jsonl"; }
SKILL_RT='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"research-tools:deep-research"}}]}}'
CMD_RT='{"type":"user","message":{"role":"user","content":"<command-name>/research</command-name>"}}'

@test "research-tools agentType is denied without a research invocation in the transcript" {
    _run_script "await agent('p', { agentType: 'research-tools:research-lead' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"research-tools"* ]] || false
    _transcript '{"type":"user","message":{"role":"user","content":"hello"}}'
    _run_script "await agent('p', { agentType: 'research-tools:research-lead' })" "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 2 ]
}

@test "research-tools agentType is allowed, any model/effort, after a skill or command invocation" {
    _transcript "$SKILL_RT"
    _run_script "await agent('p', { agentType: 'research-tools:research-lead', model: 'opus', effort: 'max' })" "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
    _transcript "$CMD_RT"
    _run_script "await agent('p', { agentType: 'research-tools:x', effort: 'xhigh' })" "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

# --- fail closed --------------------------------------------------------------------------------

@test "options passed as a variable are denied" {
    _run_script "const opts = { label: 'x', model: 'sonnet', effort: 'low' }; await agent('p', opts)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"object literal"* ]] || false
}

@test "spread options are denied" {
    _run_script "await agent('p', { ...base, label: 'x' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"spread"* ]] || false
}

@test "a non-literal options expression is denied" {
    _run_script "await agent('p', cond ? { model: 'sonnet', effort: 'low' } : { model: 'haiku', effort: 'low' })"
    [ "$status" -eq 2 ]
}

@test "agentType, model or effort given as a variable or expression is denied" {
    _run_script "await agent('p', { agentType: kind })"
    [ "$status" -eq 2 ]
    _run_script "await agent('p', { model: pick(), effort: 'low' })"
    [ "$status" -eq 2 ]
    _run_script "await agent('p', { model, effort: 'low' })"
    [ "$status" -eq 2 ]
    _run_script 'await agent("p", { agentType: `borg-collective:borg-${kind}` })'
    [ "$status" -eq 2 ]
}

@test "a const holding a string literal is resolved" {
    _run_script "const M = 'sonnet'; const E = 'high'; await agent('p', { model: M, effort: E })"
    [ "$status" -eq 0 ]
    _run_script "const M = 'opus'; await agent('p', { model: M, effort: 'low' })"
    [ "$status" -eq 2 ]
    _run_script "let M = 'sonnet'; M = 'opus'; await agent('p', { model: M, effort: 'low' })"
    [ "$status" -eq 2 ]
}

@test "an indirect reference to agent is denied" {
    _run_script "const run = agent; await run('p', { model: 'opus' })"
    [ "$status" -eq 2 ]
    _run_script "await Promise.all(items.map(agent))"
    [ "$status" -eq 2 ]
}

@test "unbalanced and unterminated scripts are denied" {
    _run_script "await agent('p', { label: 'x' "
    [ "$status" -eq 2 ]
    _run_script "await agent('p, { label: 'x' })"
    [ "$status" -eq 2 ]
    _run_script 'await agent(`p ${x`, { label: "x" })'
    [ "$status" -eq 2 ]
    _run_script "/* never closed await agent('p', { model: 'sonnet', effort: 'low' })"
    [ "$status" -eq 2 ]
}

# --- no false denies on realistic scripts -------------------------------------------------------

@test "agent( inside strings, comments and template text is ignored" {
    _run_script $'// agent(\'x\')\nconst s = "agent(y)"\n/* agent(z) */\nconst t = `agent(w)`'
    [ "$status" -eq 0 ]
}

@test "multi-line template-literal prompt containing agent( and nested quotes is not misparsed" {
    local script
    script=$'const items = ["a", "b"]\nconst res = await agent(`\nYou are a reviewer. Do not call agent(\'x\', { model: "opus" }) yourself.\nSay "done" or \'fail\'; keep `code spans` escaped: \\`like this\\`.\n${items.map((i) => `- ${i} (agent(${i}))`).join("\\n")}\nPlain braces { and ) and ( are fine here.\n`, {\n  label: "review",\n  agentType: \'borg-collective:borg-reviewer\',\n  schema: { type: "object", properties: { verdict: { type: "string", enum: ["pass", "fail"] } }, required: ["verdict"] },\n})\n'
    _run_script "$script"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "pipeline and parallel stage callbacks with pinned agent() calls are allowed" {
    local script
    script=$'const files = await parallel(["a", "b"].map((f) => () => agent(`scan ${f}`, { label: `scan-${f}`, agentType: \'borg-collective:borg-scout\' })))\nconst out = await pipeline([\n  async (ctx) => agent(`plan with agent( in prose`, { model: \'sonnet\', effort: \'high\', schema: { type: \'object\', properties: { steps: { type: \'array\', items: { type: \'string\' } } } } }),\n  async (ctx, prev) => {\n    const r = await agent(\n      `write ${prev.steps.length} things, it\'s fine`,\n      { label: "write", model: "haiku", effort: "low" },\n    )\n    return r\n  },\n])\n'
    _run_script "$script"
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "an unpinned agent() nested in a pipeline stage is still caught" {
    local script
    script=$'await pipeline([\n  async () => agent(`ok`, { agentType: \'borg-collective:borg-scout\' }),\n  async () => agent(`oops (agent( in text)`, { label: \'bad\' }),\n])\n'
    _run_script "$script"
    [ "$status" -eq 2 ]
    [[ "$output" == *"line 3 (label 'bad')"* ]] || false
    [[ "$output" != *"line 2"* ]] || false
}

@test "regex literals and division do not derail the parse" {
    _run_script $'const re = /["\'`]\\(/g\nconst half = total / 2 / 3\nawait agent(`x`.replace(/a\\/b/, "c"), { model: "sonnet", effort: "low" })'
    [ "$status" -eq 0 ] || { echo "$output"; false; }
}

# --- input resolution ---------------------------------------------------------------------------

@test "scriptPath input is read and checked" {
    printf "await agent('p', { label: 'file-stage' })\n" > "${BATS_TEST_TMPDIR}/wf.js"
    _run_json "$(jq -nc --arg p "${BATS_TEST_TMPDIR}/wf.js" '{tool_name:"Workflow", tool_input:{scriptPath:$p}}')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"file-stage"* ]] || false
}

@test "a clean scriptPath is allowed" {
    printf "await agent('p', { agentType: 'borg-collective:borg-scout' })\n" > "${BATS_TEST_TMPDIR}/wf.js"
    _run_json "$(jq -nc --arg p "${BATS_TEST_TMPDIR}/wf.js" '{tool_name:"Workflow", tool_input:{scriptPath:$p}}')"
    [ "$status" -eq 0 ]
}

@test "unreadable scriptPath is denied" {
    _run_json '{"tool_name":"Workflow","tool_input":{"scriptPath":"/nonexistent/wf.js"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"scriptPath"* ]] || false
}

@test "saved workflow name resolves in the project .claude/workflows and is checked" {
    mkdir -p "${BATS_TEST_TMPDIR}/proj/.claude/workflows"
    printf "await agent('p', { label: 'saved-bad' })\n" > "${BATS_TEST_TMPDIR}/proj/.claude/workflows/my-flow.js"
    _run_json "$(jq -nc --arg c "${BATS_TEST_TMPDIR}/proj" '{tool_name:"Workflow", cwd:$c, tool_input:{name:"my-flow"}}')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"saved-bad"* ]] || false
    printf "await agent('p', { agentType: 'borg-collective:borg-scout' })\n" > "${BATS_TEST_TMPDIR}/proj/.claude/workflows/my-flow.js"
    _run_json "$(jq -nc --arg c "${BATS_TEST_TMPDIR}/proj" '{tool_name:"Workflow", cwd:$c, tool_input:{name:"my-flow"}}')"
    [ "$status" -eq 0 ]
}

@test "saved workflow name resolves in the user ~/.claude/workflows" {
    mkdir -p "$HOME/.claude/workflows"
    printf "await agent('p', { label: 'user-bad' })\n" > "$HOME/.claude/workflows/u-flow.mjs"
    _run_json "$(jq -nc --arg c "${BATS_TEST_TMPDIR}" '{tool_name:"Workflow", cwd:$c, tool_input:{name:"u-flow"}}')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"user-bad"* ]] || false
}

@test "an unresolvable saved workflow name is denied" {
    _run_json "$(jq -nc --arg c "${BATS_TEST_TMPDIR}" '{tool_name:"Workflow", cwd:$c, tool_input:{name:"nope"}}')"
    [ "$status" -eq 2 ]
    [[ "$output" == *"nope"* ]] || false
}

@test "a saved workflow name with a path separator is denied" {
    _run_json "$(jq -nc --arg c "${BATS_TEST_TMPDIR}" '{tool_name:"Workflow", cwd:$c, tool_input:{name:"../../etc/x"}}')"
    [ "$status" -eq 2 ]
}

@test "a Workflow call with no script, scriptPath or name is denied" {
    _run_json '{"tool_name":"Workflow","tool_input":{}}'
    [ "$status" -eq 2 ]
}

@test "inline script wins over a name" {
    run bash -c "printf '%s' '{\"tool_name\":\"Workflow\",\"tool_input\":{\"name\":\"my-flow\",\"script\":\"agent(1)\"}}' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
}

# --- not-ours input, kill switch, wiring --------------------------------------------------------

@test "malformed JSON and empty stdin are ignored" {
    run bash -c "printf '%s' '{not json' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
    run bash -c "printf '' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "non-Workflow tool is ignored" {
    run bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"script\":\"agent(1)\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "BORG_WORKFLOW_MODEL_GUARD=0 disables the guard" {
    export BORG_WORKFLOW_MODEL_GUARD=0
    _run_script "await agent('p')"
    [ "$status" -eq 0 ]
}

@test "the deny message no longer advertises the inherit-ok escape hatch" {
    _run_script "await agent('p')"
    [ "$status" -eq 2 ]
    [[ "$output" != *"inherit-ok"* ]] || false
}

@test "wiring: build-plugin.sh copies the hook and registers a Workflow PreToolUse matcher" {
    grep -qE '_build_self_contained_hook .*borg-workflow-model-guard\.sh' "$BUILD_PLUGIN"
    run grep -A6 '"matcher": "Workflow"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-workflow-model-guard.sh"* ]] || false
}

@test "routing guide lives in docs/, not agents/ (agents/ files register as spawnable types)" {
    [ -f "${BATS_TEST_DIRNAME}/../docs/agent-routing.md" ]
    [ ! -e "${BATS_TEST_DIRNAME}/../agents/ROUTING.md" ]
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

@test "borg-collective and research-tools agentTypes with no effort are not hit by the guide effort rule" {
    _run_script "await agent('q', { agentType: 'borg-collective:borg-scout' })"
    [ "$status" -eq 0 ]
    _transcript "$SKILL_RT"
    _run_script "await agent('p', { agentType: 'research-tools:research-lead' })" "${BATS_TEST_TMPDIR}/t.jsonl"
    [ "$status" -eq 0 ]
}

@test "the deny policy text says claude-code-guide needs effort low/medium/high" {
    _run_script "await agent('q', { model: 'opus', effort: 'low' })"
    [ "$status" -eq 2 ]
    [[ "$output" == *"claude-code-guide also needs effort low/medium/high"* ]] || false
}
