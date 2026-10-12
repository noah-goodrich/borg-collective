#!/usr/bin/env bats
# In-flight inventory for borg-resume (slice S5): borg-resume inventory <sid> --json.
# Trees are built per test in $BATS_TEST_TMPDIR by a SYNTHETIC builder (directive layout, hand-made records);
# the captured-skeleton workflow manifests/journals from tests/fixtures/resume/ are copied into that layout too.
# Clock pinned with BORG_RESUME_NOW_EPOCH; transcript mtimes set with touch -t.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    FXR="${BATS_TEST_DIRNAME}/fixtures/resume"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_IN_CONTAINER=0
    # 2026-10-12 12:00:00 UTC
    export BORG_RESUME_NOW_EPOCH=1791806400
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_RUNNING_SEC
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
    SID="00000000-0000-4000-8000-0000000000aa"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    SD="${PD}/${SID}"
    SUB="${SD}/subagents"
    mkdir -p "$SUB" "${SD}/workflows"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$CWD"
}

inv() { run "$BIN" inventory "$SID" --json; }

# ---- record builders (SYNTHETIC) -------------------------------------------------------------
r_user() { printf '{"type":"user","isSidechain":%s,"cwd":"%s","sessionId":"%s","message":{"role":"user","content":"%s"}}\n' "${3:-false}" "$CWD" "$SID" "$1" >>"$2"; }
r_asst_end() { printf '{"type":"assistant","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"all done"}]}}\n' >>"$1"; }
r_asst_tool() { printf '{"type":"assistant","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}\n' >>"$1"; }
r_err() { printf '{"type":"assistant","isApiErrorMessage":true,"error":"rate_limit","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"You hit your limit"}]}}\n' >>"$1"; }
r_int() { printf '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}\n' >>"$1"; }
r_close() { printf '{"type":"system","subtype":"turn_duration"}\n' >>"$1"; }

# mk_agent <id> <kind: done|errored|errored_closed|orphaned|running|interrupted|toolpending> [dir]
mk_agent() {
    local id="$1" kind="$2" dir="${3:-$SUB}" f
    mkdir -p "$dir"
    f="${dir}/agent-${id}.jsonl"
    : >"$f"
    r_user "do the brief" "$f" true
    case "$kind" in
        done) r_asst_end "$f" ;;
        errored) r_asst_tool "$f"; r_err "$f" ;;
        errored_closed) r_err "$f"; r_close "$f" ;;
        interrupted) r_asst_tool "$f"; r_int "$f" ;;
        orphaned | running | toolpending) r_asst_tool "$f" ;;
    esac
    printf '{"agentType":"general-purpose","description":"d-%s"}\n' "$id" >"${dir}/agent-${id}.meta.json"
    case "$kind" in
        running) TZ=UTC touch -t 202610121158 "$f" ;;
        *) TZ=UTC touch -t 202610121000 "$f" ;;
    esac
}

# put a captured-skeleton manifest+journal into the directive layout as run <wid>
mk_wf_from_fixture() {
    local wid="$1" man="$2" jr="$3"
    mkdir -p "${SD}/subagents/workflows/${wid}"
    cp "${FXR}/workflows/${man}" "${SD}/workflows/${wid}.json"
    [ -n "$jr" ] && cp "${FXR}/workflows/${jr}" "${SD}/subagents/workflows/${wid}/journal.jsonl"
    return 0
}

wfq() { jq -r --arg w "$1" ".workflows[] | select(.manifest_id == \$w) | $2" <<<"$output"; }
agq() { jq -r --arg a "$1" ".agents[] | select(.agent_id == \$a) | $2" <<<"$output"; }

# ---- empty / unknown -------------------------------------------------------------------------

@test "unknown session gives an empty inventory and exit 0" {
    run "$BIN" inventory "00000000-0000-4000-8000-0000000000ff" --json
    [ "$status" -eq 0 ]
    jq -e '.found == false and .agents == [] and .workflows == [] and .worktrees == []' <<<"$output"
}

@test "empty and unsafe session ids give an empty inventory, exit 0" {
    run "$BIN" inventory "" --json
    [ "$status" -eq 0 ]
    jq -e '.found == false' <<<"$output"
    run "$BIN" inventory "../etc" --json
    [ "$status" -eq 0 ]
    jq -e '.found == false' <<<"$output"
}

@test "no session argument is a usage error" {
    run "$BIN" inventory
    [ "$status" -eq 2 ]
}

# ---- Agent-tool agents -----------------------------------------------------------------------

@test "agent statuses: done, errored, orphaned, running, interrupted_by_user" {
    r_user "main task" "${PD}/${SID}.jsonl"
    mk_agent a1 done
    mk_agent a2 errored
    mk_agent a3 orphaned
    mk_agent a4 running
    mk_agent a5 interrupted
    inv
    [ "$status" -eq 0 ]
    jq -e . <<<"$output" >/dev/null
    [ "$(agq a1 .status)" = done ]
    [ "$(agq a2 .status)" = errored ]
    [ "$(agq a3 .status)" = orphaned ]
    [ "$(agq a4 .status)" = running ]
    [ "$(agq a5 .status)" = interrupted_by_user ]
    [ "$(agq a1 .kind)" = agent ]
    [ "$(agq a1 .agent_type)" = general-purpose ]
}

@test "running vs orphaned is driven by transcript mtime" {
    mk_agent a3 toolpending
    TZ=UTC touch -t 202610121158 "${SUB}/agent-a3.jsonl"
    inv
    [ "$(agq a3 .status)" = running ]
    TZ=UTC touch -t 202610121100 "${SUB}/agent-a3.jsonl"
    inv
    [ "$(agq a3 .status)" = orphaned ]
}

@test "synthetic error beats a trailing clean close (not only trailing_clean_close decides done)" {
    mk_agent a2 errored_closed
    inv
    [ "$(agq a2 .status)" = errored ]
}

@test "an agent that died on an API error is found by transcript scan alone (no events, no agent_id source)" {
    mk_agent a2 errored
    [ ! -e "${BORG_RESUME_DIR}/events/${SID}.jsonl" ]
    inv
    [ "$(agq a2 .status)" = errored ]
}

@test "done via an agent_stop event when the tail is not an assistant end" {
    mk_agent a6 toolpending
    mkdir -p "${BORG_RESUME_DIR}/events"
    printf '{"t":1,"ev":"agent_stop","sid":"%s","scope":"agent:a6","agent_id":"a6"}\n' "$SID" >"${BORG_RESUME_DIR}/events/${SID}.jsonl"
    inv
    [ "$(agq a6 .status)" = done ]
}

@test "brief reference is the transcript path at line 1, not a copy of the brief" {
    mk_agent a1 done
    inv
    [ "$(agq a1 .brief_ref.path)" = "${SUB}/agent-a1.jsonl" ]
    [ "$(agq a1 .brief_ref.line)" = 1 ]
    ! grep -q "do the brief" <<<"$output"
}

@test "non-recursive glob: workflow agents never appear under agents" {
    mk_agent a1 done
    mk_agent w1 orphaned "${SUB}/workflows/wf_r1"
    inv
    [ "$(jq -r '.agents | length' <<<"$output")" = 1 ]
    [ "$(jq -r '.agents[0].agent_id' <<<"$output")" = a1 ]
}

# ---- workflows -------------------------------------------------------------------------------

@test "workflow from the captured finished fixture is finished and carries runId and scriptPath" {
    mk_wf_from_fixture wf_ab12cd wf_ab12cd.json wf_ab12cd.journal.jsonl
    inv
    [ "$(wfq wf_ab12cd .status)" = finished ]
    [ "$(wfq wf_ab12cd .run_id)" = wf_fake001 ]
    [ "$(wfq wf_ab12cd .resumable)" = false ]
    [ -n "$(wfq wf_ab12cd .script_path)" ]
    [ "$(wfq wf_ab12cd .script_inline)" = false ]
}

@test "re-run after kill is correlated by journal step key and not double counted" {
    # Key = the journal record "key" (v2:fake003): agent a4 started and was killed, a5 re-ran it and finished.
    mk_wf_from_fixture wf_ab12cd wf_ab12cd.json wf_ab12cd.journal.jsonl
    mk_agent a0000000000000004 orphaned "${SUB}/workflows/wf_ab12cd"
    mk_agent a0000000000000005 done "${SUB}/workflows/wf_ab12cd"
    inv
    [ "$(wfq wf_ab12cd '.steps | length')" = 3 ]
    [ "$(wfq wf_ab12cd '.steps[] | select(.key == "v2:fake003") | .attempts')" = 2 ]
    [ "$(wfq wf_ab12cd '.agents[] | select(.agent_id == "a0000000000000004") | .superseded')" = true ]
    [ "$(wfq wf_ab12cd '.agents[] | select(.agent_id == "a0000000000000005") | .superseded')" = false ]
    [ "$(wfq wf_ab12cd .status)" = finished ]
    [ "$(wfq wf_ab12cd '.unfinished_steps | length')" = 0 ]
}

@test "captured failed fixture (result of nulls, journaled failed) is finished_with_failures and resumable" {
    mk_wf_from_fixture wf_failed wf_failed.json wf_failed.journal.jsonl
    inv
    [ "$(wfq wf_failed .status)" = finished_with_failures ]
    [ "$(wfq wf_failed .resumable)" = true ]
}

@test "completed manifest with a null in result is finished_with_failures even with a clean journal" {
    mk_wf_from_fixture wf_ab12cd wf_failed.json wf_ab12cd.journal.jsonl
    inv
    [ "$(wfq wf_ab12cd .status)" = finished_with_failures ]
}

@test "finished manifest with an errored owned agent is finished_with_failures" {
    mk_wf_from_fixture wf_ab12cd wf_ab12cd.json wf_ab12cd.journal.jsonl
    mk_agent a7 errored "${SUB}/workflows/wf_ab12cd"
    inv
    [ "$(wfq wf_ab12cd .status)" = finished_with_failures ]
}

@test "no result and a started-without-result step beside a finished one is partial" {
    mk_wf_from_fixture wf_ab12cd wf_ab12cd.json wf_ab12cd.journal.jsonl
    jq 'del(.result)' "${SD}/workflows/wf_ab12cd.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_ab12cd.json"
    printf '{"type":"started","key":"v2:fake009","agentId":"a9","label":"x","phase":"p"}\n' >>"${SD}/subagents/workflows/wf_ab12cd/journal.jsonl"
    inv
    [ "$(wfq wf_ab12cd .status)" = partial ]
    [ "$(wfq wf_ab12cd '.unfinished_steps | join(",")')" = "v2:fake009" ]
    [ "$(wfq wf_ab12cd .resumable)" = true ]
}

@test "no result and no completed step is unfinished" {
    mk_wf_from_fixture wf_x wf_ab12cd.json ""
    jq 'del(.result)' "${SD}/workflows/wf_x.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_x.json"
    printf '{"type":"launched"}\n{"type":"started","key":"v2:k1","agentId":"a1"}\n' >"${SD}/subagents/workflows/wf_x/journal.jsonl"
    inv
    [ "$(wfq wf_x .status)" = unfinished ]
}

@test "journaled failed with no re-run counts as an unfinished step" {
    mk_wf_from_fixture wf_x wf_ab12cd.json ""
    jq 'del(.result)' "${SD}/workflows/wf_x.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_x.json"
    printf '{"type":"started","key":"v2:k1","agentId":"a1"}\n{"type":"result","key":"v2:k1","agentId":"a1","result":"ok"}\n{"type":"started","key":"v2:k2","agentId":"a2"}\n{"type":"failed","key":"v2:k2","agentId":"a2"}\n' >"${SD}/subagents/workflows/wf_x/journal.jsonl"
    inv
    [ "$(wfq wf_x .status)" = partial ]
    [ "$(wfq wf_x '.unfinished_steps | join(",")')" = "v2:k2" ]
}

@test "a result record carrying null is an unfinished step (U8 literal-null assumption)" {
    mk_wf_from_fixture wf_x wf_ab12cd.json ""
    jq 'del(.result)' "${SD}/workflows/wf_x.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_x.json"
    printf '{"type":"started","key":"v2:k1","agentId":"a1"}\n{"type":"result","key":"v2:k1","agentId":"a1","result":null}\n' >"${SD}/subagents/workflows/wf_x/journal.jsonl"
    inv
    [ "$(wfq wf_x '.unfinished_steps | join(",")')" = "v2:k1" ]
}

@test "workflow whose owned agents ended with the interrupt marker is interrupted_by_user" {
    mk_wf_from_fixture wf_x wf_ab12cd.json ""
    jq 'del(.result)' "${SD}/workflows/wf_x.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_x.json"
    printf '{"type":"started","key":"v2:k1","agentId":"a1"}\n' >"${SD}/subagents/workflows/wf_x/journal.jsonl"
    mk_agent a1 interrupted "${SUB}/workflows/wf_x"
    inv
    [ "$(wfq wf_x .status)" = interrupted_by_user ]
    [ "$(wfq wf_x .resumable)" = false ]
}

@test "inline-only workflow source sets script_inline" {
    mk_wf_from_fixture wf_x wf_ab12cd.json ""
    jq 'del(.scriptPath)' "${SD}/workflows/wf_x.json" >"${BATS_TEST_TMPDIR}/m.json" && mv "${BATS_TEST_TMPDIR}/m.json" "${SD}/workflows/wf_x.json"
    inv
    [ "$(wfq wf_x .script_inline)" = true ]
    [ "$(wfq wf_x .script_path)" = null ]
}

@test "workflow agents are listed only inside their workflow, kind workflow_agent" {
    mk_wf_from_fixture wf_ab12cd wf_ab12cd.json wf_ab12cd.journal.jsonl
    mk_agent a2 done "${SUB}/workflows/wf_ab12cd"
    inv
    [ "$(wfq wf_ab12cd '.agents[0].kind')" = workflow_agent ]
    [ "$(jq -r '.agents | length' <<<"$output")" = 0 ]
}

# ---- session level, worktrees ----------------------------------------------------------------

@test "session block: turn state, prompt head, newest checkpoint, git branch and dirty" {
    git -C "$CWD" init -q -b feat/x
    git -C "$CWD" commit -q --allow-empty -m init
    mkdir -p "${CWD}/.borg/checkpoints"
    : >"${CWD}/.borg/checkpoints/2026-10-01-old.md"
    : >"${CWD}/.borg/checkpoints/2026-10-11-new.md"
    touch -t 202610010000 "${CWD}/.borg/checkpoints/2026-10-01-old.md"
    touch -t 202610110000 "${CWD}/.borg/checkpoints/2026-10-11-new.md"
    local t="${PD}/${SID}.jsonl"
    r_user "build the inventory" "$t"
    r_asst_tool "$t"
    r_err "$t"
    inv
    [ "$(jq -r .session.turn_state <<<"$output")" = errored ]
    [ "$(jq -r .session.error <<<"$output")" = rate_limit ]
    [ "$(jq -r .session.prompt_head <<<"$output")" = "build the inventory" ]
    [ "$(jq -r .session.checkpoint <<<"$output")" = "${CWD}/.borg/checkpoints/2026-10-11-new.md" ]
    [ "$(jq -r .session.git.branch <<<"$output")" = feat/x ]
    [ "$(jq -r .session.git.dirty <<<"$output")" = true ]
}

@test "turn state: interrupted, complete and in_progress" {
    local t="${PD}/${SID}.jsonl"
    r_user "q" "$t"; r_asst_tool "$t"; r_int "$t"
    inv
    [ "$(jq -r .session.turn_state <<<"$output")" = interrupted ]
    : >"$t"; r_user "q" "$t"; r_asst_end "$t"; r_close "$t"
    inv
    [ "$(jq -r .session.turn_state <<<"$output")" = complete ]
    : >"$t"; r_user "q" "$t"; r_asst_tool "$t"
    inv
    [ "$(jq -r .session.turn_state <<<"$output")" = in_progress ]
}

@test "cwd comes from the registry when present" {
    r_user "q" "${PD}/${SID}.jsonl"
    mkdir -p "${BORG_RESUME_DIR}/sessions"
    printf '{"session_id":"%s","cwd":"%s/elsewhere"}\n' "$SID" "$BATS_TEST_TMPDIR" >"${BORG_RESUME_DIR}/sessions/${SID}.json"
    inv
    [ "$(jq -r .session.cwd <<<"$output")" = "${BATS_TEST_TMPDIR}/elsewhere" ]
}

@test "worktrees: linked worktrees listed with a dirty flag, agent in one carries it" {
    git -C "$CWD" init -q -b main
    git -C "$CWD" commit -q --allow-empty -m init
    local wt
    wt="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/wt1"
    git -C "$CWD" worktree add -q -b side "$wt"
    printf 'x\n' >"${wt}/new.txt"
    r_user "q" "${PD}/${SID}.jsonl"
    mk_agent a1 orphaned
    sed -i.bak "s#\"cwd\":\"${CWD}\"#\"cwd\":\"${wt}\"#" "${SUB}/agent-a1.jsonl"
    inv
    [ "$(jq -r '.worktrees | length' <<<"$output")" = 1 ]
    [ "$(jq -r '.worktrees[0].path' <<<"$output")" = "$wt" ]
    [ "$(jq -r '.worktrees[0].branch' <<<"$output")" = side ]
    [ "$(jq -r '.worktrees[0].dirty' <<<"$output")" = true ]
    [ "$(agq a1 .worktree.path)" = "$wt" ]
    [ "$(agq a1 .worktree.dirty)" = true ]
    git -C "$wt" add new.txt
    git -C "$wt" commit -q -m c
    inv
    [ "$(jq -r '.worktrees[0].dirty' <<<"$output")" = false ]
}

# ---- spike outcome ---------------------------------------------------------------------------

@test "spike U8 outcome is the documented fallback this inventory implements" {
    run jq -r '.spikes[] | select(.id == "U8") | .outcome + "|" + .fallback' "${BATS_TEST_DIRNAME}/../spike/SPIKE_RESULTS.json"
    [ "$status" -eq 0 ]
    # partial: literal-null return untested -> the fallback (started-without-result, failed, null result = unfinished)
    case "$output" in
        pass* ) ;;
        partial\|*"started-without-result and failed as unfinished"*"null entries in result as unfinished"* ) ;;
        * ) echo "unexpected U8 spike state: $output"; false ;;
    esac
}

@test "spike U6 outcome: new agent id on re-run is what the journal fixture shows" {
    run jq -r '.spikes[] | select(.id == "U6") | .outcome' "${BATS_TEST_DIRNAME}/../spike/SPIKE_RESULTS.json"
    [ "$output" = pass ] || [ "$output" = partial ]
    # captured journal: key v2:fake003 started under two different agent ids
    run jq -s '[.[] | select(.type == "started" and .key == "v2:fake003") | .agentId] | unique | length' "${FXR}/workflows/wf_ab12cd.journal.jsonl"
    [ "$output" = 2 ]
}

@test "inventory library parses under /bin/bash -n and defines functions only" {
    [ -x /bin/bash ] || skip "no /bin/bash"
    run /bin/bash -n "${BATS_TEST_DIRNAME}/../lib/borg/resume-inventory.sh"
    [ "$status" -eq 0 ]
    run bash -c ". '${BATS_TEST_DIRNAME}/../lib/borg/resume-inventory.sh'"
    [ -z "$output" ]
}
