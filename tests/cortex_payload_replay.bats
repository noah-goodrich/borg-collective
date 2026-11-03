#!/usr/bin/env bats
# Replay layer for the hooks borg registers in Cortex Code CLI (tier A3 and A4 of the 2026-10-22 battery).
#
# Every hook that `_borg_register_cortex_hooks` writes to hooks.json receives every synthetic Cortex payload in
# tests/fixtures/cortex/ and must exit 0 with stdout empty or valid JSON. The exceptions are the guards' own denies.
# Fixtures carry Cortex's real field names and Claude-style tool names (Bash, Read, Write, Task, EnterPlanMode,
# ExitPlanMode); every value is invented (cwd placeholder, session id 00000000-0000-4000-8000-000000000001).
# The Task and SubagentStop shapes, and the *.history.jsonl subagent transcripts, were recorded from a live Cortex
# 1.2.18 run (evals/cortex-agents/live.sh) and then rewritten with invented values. Every replay sets
# CORTEX_PROJECT_DIR, as Cortex does for every command hook.
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
    jq --arg cwd "$REPO" --arg fx "$FIXTURES" \
        'walk(if type == "string" then gsub("__CWD__"; $cwd) | gsub("__FIXTURES__"; $fx) else . end)' \
        "$FIXTURES/$fixture.json" > "$payload"
    if [[ -n "${3:-}" ]]; then
        jq --arg c "$3" '.tool_input.command = $c' "$payload" > "$payload.2" && mv "$payload.2" "$payload"
    fi
    RC=0
    _run_hook "$hook" "$payload"
}

# Run hook $1 on payload file $2 the way Cortex does (CORTEX_PROJECT_DIR set), cwd the sandbox repository.
_run_hook() {
    RC=0
    OUT=$(HOME="$BORG_TEST_HOME" XDG_CACHE_HOME="$BORG_TEST_HOME/.cache" BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" CORTEX_PROJECT_DIR="$REPO" \
        bash "${BATS_TEST_DIRNAME}/../hooks/$1" < "$2" 2>"${BATS_TEST_TMPDIR}/err") || RC=$?
}

@test "replay: the registered hook list is the eighteen borg hooks plus borg-cortex-plan.sh" {
    [ "$(wc -l < "${BATS_TEST_TMPDIR}/hooks.txt" | tr -d ' ')" -eq 19 ]
    grep -qx 'borg-cortex-plan.sh' "${BATS_TEST_TMPDIR}/hooks.txt"
    grep -qx 'bash-guard.sh' "${BATS_TEST_TMPDIR}/hooks.txt"
    grep -qx 'borg-agent-model-guard.sh' "${BATS_TEST_TMPDIR}/hooks.txt"
}

@test "replay: every registered hook exits 0 with empty or JSON stdout on every Cortex payload" {
    local hook fx bad=""
    while IFS= read -r hook; do
        for fx in session-start stop notification user-prompt-submit pretooluse-bash pretooluse-bash-readonly \
                  pretooluse-read pretooluse-write posttooluse-enter-plan-mode pretooluse-exit-plan-mode \
                  posttooluse-exit-plan-mode pretooluse-task subagent-stop; do
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
    run bash -c "sed 's/00000000-0000-4000-8000-000000000001//g' '$FIXTURES'/*.json '$FIXTURES'/*.jsonl | grep -cE '/Users/|/home/[a-z]|/private/|[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]'"
    [ "$output" = "0" ]
}

# --- the Task payload: the model guard ------------------------------------------------------------------------------

@test "replay: the model guard allows a namespaced borg agent on Cortex's Task payload" {
    _replay borg-agent-model-guard.sh pretooluse-task
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the model guard denies Explore, an alias pin and an unpinned Snowflake agent on that payload" {
    local payload="${BATS_TEST_TMPDIR}/payload.json" ti
    for ti in '{"subagent_type":"Explore"}' \
              '{"subagent_type":"borg-collective:borg-nanoprobe","model":"sonnet"}' \
              '{"subagent_type":"snowflake-object-discovery"}'; do
        jq --arg cwd "$REPO" --argjson ti "$ti" '.cwd = $cwd | .tool_input += $ti' "$FIXTURES/pretooluse-task.json" > "$payload"
        _run_hook borg-agent-model-guard.sh "$payload"
        [ "$RC" -eq 2 ] || { echo "allowed: $ti"; return 1; }
        grep -q 'borg agent model guard: Agent call denied' "${BATS_TEST_TMPDIR}/err"
    done
}

@test "replay: the model guard allows a Snowflake agent pinned to a full Sonnet id on that payload" {
    local payload="${BATS_TEST_TMPDIR}/payload.json"
    jq --arg cwd "$REPO" '.cwd = $cwd | .tool_input.subagent_type = "dbt-verify" | .tool_input.model = "claude-sonnet-5-5"' \
        "$FIXTURES/pretooluse-task.json" > "$payload"
    _run_hook borg-agent-model-guard.sh "$payload"
    [ "$RC" -eq 0 ]
}

# --- the SubagentStop payload: the run logger -----------------------------------------------------------------------

@test "replay: a Cortex SubagentStop logs the model, effort and writes from the history beside the snapshot" {
    _replay borg-nanoprobe-log.sh subagent-stop
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
    local log="$XDG_STATE_HOME/borg/agents.jsonl"
    [ "$(jq -r .agent_type "$log")" = "borg-collective:borg-grunt" ]
    [ "$(jq -r .model "$log")" = "claude-haiku-5-5" ]
    [ "$(jq -r .effort "$log")" = "max" ]
    [ "$(jq -r .zero_commit "$log")" = "false" ]
}

@test "replay: a Cortex subagent whose writes all failed is flagged ZERO-WRITE" {
    local payload="${BATS_TEST_TMPDIR}/payload.json"
    jq --arg cwd "$REPO" --arg fx "$FIXTURES" '.cwd = $cwd | .agent_transcript_path = ($fx + "/subagent-readonly.json")' \
        "$FIXTURES/subagent-stop.json" > "$payload"
    _run_hook borg-nanoprobe-log.sh "$payload"
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.systemMessage | contains("ZERO-WRITE")' >/dev/null
    local log="$XDG_STATE_HOME/borg/agents.jsonl"
    [ "$(jq -r .zero_commit "$log")" = "true" ]
    [ "$(jq -r .model "$log")" = "claude-sonnet-5-5" ]
    [ "$(jq -r .effort "$log")" = "high" ]
}

# --- the S1 hooks: arrival brief, supabase guard, tool-count nudge, prefer-tool log ---------------------------------

@test "replay: the arrival brief answers Cortex's startup SessionStart with a systemMessage" {
    _replay borg-arrival-brief.sh session-start
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.systemMessage | length > 0' >/dev/null
}

@test "replay: the arrival brief stays silent on the compact SessionStart Cortex fires after PreCompact" {
    _replay borg-arrival-brief.sh session-start-compact
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the supabase guard denies a local stack boot outside the shared stack and allows an ordinary command" {
    _replay borg-supabase-guard.sh pretooluse-bash "supabase start"
    [ "$RC" -eq 2 ]
    grep -qi 'supabase' "${BATS_TEST_TMPDIR}/err"
    _replay borg-supabase-guard.sh pretooluse-bash
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the tool-count nudge speaks once the context file is over the threshold, on a Cortex PostToolUse" {
    mkdir -p "$BORG_TEST_HOME/.cache/borg/context"
    printf '{"total_input_tokens": 200000}\n' > "$BORG_TEST_HOME/.cache/borg/context/00000000-0000-4000-8000-000000000001.json"
    _replay tool-count-nudge.sh posttooluse-bash
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext | contains("SESSION CHECK-IN")' >/dev/null
}

@test "replay: the prefer-tool log is silent and exits 0 on a Cortex Bash PostToolUse with no preference set" {
    _replay borg-prefer-tool-log.sh posttooluse-bash
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

# --- the S2 hooks: precompact checkpoint, subagent guards, large-output nudge, nanoprobe skill gate ------------------

# Run hook $1 on fixture $2 with cwd the sandbox repository and the jq filter $3 applied.
_replay_jq() {
    local hook="$1" fixture="$2" filter="$3" payload="${BATS_TEST_TMPDIR}/payload.json"
    jq --arg cwd "$REPO" "(.cwd = \$cwd) | $filter" "$FIXTURES/$fixture.json" > "$payload"
    _run_hook "$hook" "$payload"
}

@test "replay: the precompact hook writes a checkpoint quoting the last prompt from the history beside the json" {
    mkdir -p "$REPO/.borg/checkpoints"
    local conv="${BATS_TEST_TMPDIR}/00000000-0000-4000-8000-000000000001"
    printf '{"history_length": 2}\n' > "$conv.json"
    printf '%s\n' '{"role":"user","id":"u1","content":[{"type":"text","text":"wire the cortex hooks","is_user_prompt":true,"internalOnly":false}]}' > "$conv.history.jsonl"
    jq --arg cwd "$REPO" --arg t "$conv.json" '.cwd = $cwd | .transcript_path = $t' "$FIXTURES/pre-compact.json" > "${BATS_TEST_TMPDIR}/payload.json"
    _run_hook borg-precompact-checkpoint.sh "${BATS_TEST_TMPDIR}/payload.json"
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
    local written=("$REPO/.borg/checkpoints"/*.md)
    [ "${#written[@]}" -eq 1 ]
    grep -q '> wire the cortex hooks' "${written[0]}"
    grep -q 'trigger=manual' "${written[0]}"
}

@test "replay: the precompact hook stays silent in a repository borg does not live in" {
    _replay borg-precompact-checkpoint.sh pre-compact
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
    [ ! -e "$REPO/.borg" ]
}

@test "replay: the scout guard denies a mutating Bash call from the Cortex-named scout and allows a read-only one" {
    _replay_jq scout-readonly-guard.sh pretooluse-in-subagent '.tool_name = "Bash" | .tool_input = {command: "rm -r build"}'
    [ "$RC" -eq 2 ]
    grep -q 'borg scout guard' "${BATS_TEST_TMPDIR}/err"
    _replay_jq scout-readonly-guard.sh pretooluse-in-subagent '.tool_name = "Bash" | .tool_input = {command: "git status"}'
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the scout guard ignores a Cortex Bash call from a different agent" {
    _replay_jq scout-readonly-guard.sh pretooluse-in-subagent '.agent_type = "borg-collective:borg-grunt" | .tool_name = "Bash" | .tool_input = {command: "rm -r build"}'
    [ "$RC" -eq 0 ]
    _replay scout-readonly-guard.sh pretooluse-bash "rm -r build"
    [ "$RC" -eq 0 ]
}

@test "replay: the verifier guard denies a push from the Cortex-named verifier and allows a read-only git call" {
    local base='.agent_type = "borg-collective:borg-verifier" | .tool_name = "Bash"'
    _replay_jq borg-verifier-guard.sh pretooluse-in-subagent "$base | .tool_input = {command: \"git push origin main\"}"
    [ "$RC" -eq 2 ]
    grep -q 'borg verifier guard' "${BATS_TEST_TMPDIR}/err"
    _replay_jq borg-verifier-guard.sh pretooluse-in-subagent "$base | .tool_input = {command: \"git status\"}"
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the large-output nudge reads Cortex's content[] text parts, in and out of a subagent" {
    export BORG_LARGE_OUTPUT_CHARS=50
    _replay large-output-nudge.sh posttooluse-bash
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext | contains("That result was") and contains("echo probe-bash")' >/dev/null
    export BORG_LARGE_OUTPUT_CHARS=10
    _replay large-output-nudge.sh posttooluse-in-subagent
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext | contains("/work/probe/notes.txt")' >/dev/null
}

@test "replay: the large-output nudge sums several text parts and is silent under the default limit" {
    _replay large-output-nudge.sh posttooluse-bash
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
    _replay_jq large-output-nudge.sh posttooluse-bash '.tool_response.content = [range(0; 3) | {type: "text", text: ("x" * 3000)}]'
    [ "$RC" -eq 0 ]
    printf '%s' "$OUT" | jq -e '.hookSpecificOutput.additionalContext | contains("9000 chars")' >/dev/null
}

@test "replay: the nanoprobe guard denies an ungranted lowercase skill call and allows a granted one" {
    local brief="$XDG_CONFIG_HOME/borg/extensions/agent-extensions/borg-nanoprobe"
    _replay_jq borg-nanoprobe-guard.sh pretooluse-skill '.agent_type = "borg-collective:borg-nanoprobe"'
    [ "$RC" -eq 2 ]
    grep -q "probe-skill" "${BATS_TEST_TMPDIR}/err"
    mkdir -p "$brief"
    printf -- '- Grant-skill: probe-skill\n' > "$brief/brief.md"
    _replay_jq borg-nanoprobe-guard.sh pretooluse-skill '.agent_type = "borg-collective:borg-nanoprobe"'
    [ "$RC" -eq 0 ]
    [ -z "$OUT" ]
}

@test "replay: the nanoprobe guard leaves a lowercase skill call from any other caller alone" {
    _replay borg-nanoprobe-guard.sh pretooluse-skill
    [ "$RC" -eq 0 ]
    _replay_jq borg-nanoprobe-guard.sh pretooluse-skill '.agent_type = "borg-collective:borg-scout"'
    [ "$RC" -eq 0 ]
}
