#!/usr/bin/env bash
# resume-inventory.sh -- in-flight inventory builder for borg-resume (slice S5).
#
# Sourced by bin/borg-resume (needs resume-paths.sh and resume-classify.sh already sourced). Bash 3.2 safe.
# Functions only; sourcing prints nothing.
#
#   borg_resume_inventory <sid>   prints ONE JSON document on stdout, always exits 0 (an unknown, empty or
#                                 unsafe session id yields the empty inventory with found:false).
#
# Disk layout it reads (host side, resolved by glob on the session id; BORG_RESUME_PROJECTS_DIR overrides
# $HOME/.claude/projects, for tests):
#   <proj>/<sid>.jsonl                                      main transcript
#   <proj>/<sid>/subagents/agent-*.jsonl (+ .meta.json)     Agent-tool agents   (NON-recursive glob)
#   <proj>/<sid>/subagents/workflows/wf_<id>/agent-*.jsonl  workflow agents     (kind workflow_agent)
#   <proj>/<sid>/subagents/workflows/wf_<id>/journal.jsonl  workflow journal
#   <proj>/<sid>/workflows/wf_<id>.json                     workflow manifest
#
# Ground truth respected (see the directive and spike/SPIKE_RESULTS.json):
#   * U1 partial: nothing here relies on agent_id/agent_type in a StopFailure payload. A subagent that died of
#     an API error has no SubagentStop and no known id; it is found ONLY by scanning its own transcript.
#   * U6/U7: a killed workflow agent re-runs under a NEW agent id, and workflows resume only through
#     Workflow resumeFromRunId. They are never listed as agents and never get SendMessage.
#   * U8: a killed agent leaves `started` with no `result`; a limit-failed agent is journaled `failed` and the
#     run can still finish with a result array of nulls. All three count as unfinished. A literal null RETURN
#     from agent() is untested (ASSUMPTION: it is journaled as a result record whose result is null, and is
#     treated the same as a failure).
#   * U15: a trailing "[Request interrupted by user]" record without stop_hook_summary is a deliberate
#     interrupt, never an error.
#
# Agent status, first match wins: errored (last meaningful record is a synthetic API error), interrupted_by_user
# (last meaningful record is the interrupt marker), done (an agent_stop event for it, or the last meaningful
# record is an assistant end: stop_reason end_turn, or trailing turn_duration close), running (transcript mtime
# under BORG_RESUME_RUNNING_SEC, default 300), else orphaned. The synthetic-error test deliberately precedes
# the clean-close test so a trailing close can never launder an error into `done`.

_ri_now() {
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) date +%s ;;
        *) printf '%s\n' "$BORG_RESUME_NOW_EPOCH" ;;
    esac
}

_ri_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || printf '0\n'
}

_ri_projects_dir() {
    printf '%s\n' "${BORG_RESUME_PROJECTS_DIR:-$HOME/.claude/projects}"
}

# Print "<transcript-or-empty>\t<session-dir-or-empty>" for a sid.
_ri_locate() {
    local _sid="$1" _pd _t _d _f
    _pd="$(_ri_projects_dir)"
    _t="" _d=""
    for _f in "$_pd"/*/"$_sid".jsonl; do
        [ -f "$_f" ] && { _t="$_f"; break; }
    done
    for _f in "$_pd"/*/"$_sid"; do
        [ -d "$_f" ] && { _d="$_f"; break; }
    done
    [ -z "$_d" ] && [ -n "$_t" ] && [ -d "${_t%.jsonl}" ] && _d="${_t%.jsonl}"
    printf '%s\t%s\n' "$_t" "$_d"
}

_ri_empty() {
    jq -n -c --arg sid "$1" '{
        session_id: $sid, found: false, session: null, agents: [], workflows: [], worktrees: []
    }'
}

# git helpers: all fail soft and print nothing outside a repo.
_ri_git_branch() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }
_ri_git_dirty() {
    local _o
    _o="$(git -C "$1" status --porcelain 2>/dev/null)" || { printf 'false\n'; return; }
    if [ -n "$_o" ]; then printf 'true\n'; else printf 'false\n'; fi
}

# Does the events file hold an agent_stop for this agent id?
_ri_agent_stopped() {
    local _sid="$1" _aid="$2" _ef
    _ef="$(borg_resume_events_file "$_sid")"
    [ -f "$_ef" ] || return 1
    jq -e -n --arg a "$_aid" '[inputs | select(.ev == "agent_stop" and .agent_id == $a)] | length > 0' "$_ef" >/dev/null 2>&1
}

# Status of one agent transcript. Usage: _ri_agent_status <sid> <agent_id> <file>
_ri_agent_status() {
    local _sid="$1" _aid="$2" _f="$3" _out _flag _rec _age _now _mt
    _out="$(resume_last_meaningful_with_close "$_f" 60 2>/dev/null)"
    if [ -n "$_out" ]; then
        _flag="${_out%%$'\t'*}"
        _rec="${_out#*$'\t'}"
        if [ -n "$(resume_synthetic_error "$_rec" 2>/dev/null)" ]; then
            printf 'errored\n'; return
        fi
        if resume_record_is_interrupt "$_rec"; then
            printf 'interrupted_by_user\n'; return
        fi
        if _ri_agent_stopped "$_sid" "$_aid"; then
            printf 'done\n'; return
        fi
        if printf '%s' "$_rec" | jq -e --arg flag "$_flag" '
            .type == "assistant" and ((.isApiErrorMessage // false) | not)
            and ([.message.content[]? | select(type == "object" and .type == "tool_use")] | length == 0)
            and (.message.stop_reason == "end_turn" or $flag == "true")' >/dev/null 2>&1; then
            printf 'done\n'; return
        fi
    elif _ri_agent_stopped "$_sid" "$_aid"; then
        printf 'done\n'; return
    fi
    _now="$(_ri_now)"
    _mt="$(_ri_mtime "$_f")"
    _age=$((_now - _mt))
    if [ "$_age" -lt "${BORG_RESUME_RUNNING_SEC:-300}" ]; then
        printf 'running\n'
    else
        printf 'orphaned\n'
    fi
}

# worktree record for a path as JSON (null when it is not a git work tree).
_ri_worktree_json() {
    local _p="$1" _b _c _d
    git -C "$_p" rev-parse --git-dir >/dev/null 2>&1 || { printf 'null\n'; return; }
    _b="$(_ri_git_branch "$_p")"
    _c="$(git -C "$_p" log -1 --format='%h %s' 2>/dev/null)"
    _d="$(_ri_git_dirty "$_p")"
    jq -n -c --arg p "$_p" --arg b "$_b" --arg c "$_c" --argjson d "$_d" \
        '{path: $p, branch: (if $b == "" then null else $b end), last_commit: (if $c == "" then null else $c end), dirty: $d}'
}

# One agent as a JSON object. Usage: _ri_agent_json <sid> <file> <kind> [owner_run]
_ri_agent_json() {
    local _sid="$1" _f="$2" _kind="$3" _owner="${4:-}" _base _aid _meta _status _cwd _wt
    _base="${_f##*/}"
    _aid="${_base#agent-}"
    _aid="${_aid%.jsonl}"
    _meta="${_f%.jsonl}.meta.json"
    [ -f "$_meta" ] || _meta=/dev/null
    _status="$(_ri_agent_status "$_sid" "$_aid" "$_f")"
    _cwd="$(head -n 1 "$_f" 2>/dev/null | jq -r '.cwd // empty' 2>/dev/null)"
    _wt=null
    if [ -n "$_cwd" ] && [ -d "$_cwd" ]; then
        _wt="$(git -C "$_cwd" rev-parse --show-toplevel 2>/dev/null)"
        # A linked worktree has a .git FILE; the main checkout has a .git directory.
        if [ -n "$_wt" ] && [ -f "$_wt/.git" ]; then _wt="$(_ri_worktree_json "$_wt")"; else _wt=null; fi
    fi
    jq -c -n --arg aid "$_aid" --arg kind "$_kind" --arg owner "$_owner" --arg status "$_status" \
        --arg cwd "$_cwd" --arg path "$_f" --argjson wt "${_wt:-null}" --slurpfile meta "$_meta" '
        ($meta[0] // {}) as $m
        | {
            agent_id: $aid, kind: $kind, status: $status,
            agent_type: ($m.agentType // null), description: ($m.description // null),
            cwd: (if $cwd == "" then null else $cwd end),
            brief_ref: {path: $path, line: 1},
            worktree: $wt
          }
        | if $owner != "" then . + {run_id: $owner} else . end' 2>/dev/null
}

# Workflow entry. Usage: _ri_workflow_json <sid> <session_dir> <wf-basename-without-ext>
# Step correlation key: the journal record `key` (e.g. "v2:fake003"). A step's latest journal record decides
# its state, so a killed agent that was re-run under a new agent id (same key) is ONE step, not two, and the
# old agent is marked superseded rather than double-counted.
_ri_workflow_json() {
    local _sid="$1" _sd="$2" _wid="$3" _man _wdir _jr _agents _f _line _steps
    _man="$_sd/workflows/$_wid.json"
    _wdir="$_sd/subagents/workflows/$_wid"
    _jr="$_wdir/journal.jsonl"
    [ -f "$_man" ] || _man=/dev/null
    [ -f "$_jr" ] || _jr=/dev/null
    _agents=""
    for _f in "$_wdir"/agent-*.jsonl; do
        [ -f "$_f" ] || continue
        _line="$(_ri_agent_json "$_sid" "$_f" workflow_agent "$_wid")"
        [ -n "$_line" ] && _agents="${_agents}${_line}"$'\n'
    done
    _steps="$(jq -c -s '
        [.[] | select(type == "object" and .key != null and (.type == "started" or .type == "result" or .type == "failed"))] as $recs
        | {
            ids: ([$recs[] | .agentId | select(. != null)] | unique),
            steps: ($recs
              | reduce .[] as $r ({}; .[$r.key | tostring] = ((.[$r.key | tostring] // {key: ($r.key | tostring), attempts: 0})
                  | .attempts += (if $r.type == "started" then 1 else 0 end)
                  | .last = $r.type | .agent_id = $r.agentId
                  | .null_result = ($r.type == "result" and $r.result == null)))
              | [.[] | . + {state: (if .last == "result" and (.null_result | not) then "done" else "unfinished" end)}]
              | map({key, attempts, agent_id, state, last}))
          }' "$_jr" 2>/dev/null)"
    [ -n "$_steps" ] || _steps='{"ids":[],"steps":[]}'
    printf '%s' "$_agents" | jq -c -s --arg wid "$_wid" --argjson j "$_steps" --slurpfile man "$_man" '
        ($man[0] // null) as $m
        | $j.steps as $steps
        | ([$steps[] | .agent_id]) as $cur
        | (. | map(. + {superseded: (.agent_id as $a | ($j.ids | index($a)) != null and ($cur | index($a)) == null)})) as $ag
        | ($ag | map(select(.status == "errored" and (.superseded | not)))) as $err
        | ($m != null and ($m | has("result"))) as $hasres
        | ($hasres and (($m.result | type) == "array" or ($m.result | type) == "object")
            and ([$m.result | .. | nulls] | length > 0)) as $nullres
        | ([$steps[] | select(.state == "unfinished")]) as $unf
        | ([$steps[] | select(.state == "done")]) as $done
        | ($ag | map(select(.status != "done" and (.superseded | not)))) as $notdone
        | (if $hasres then
              (if ($unf | length) > 0 or ($err | length) > 0 or $nullres then "finished_with_failures" else "finished" end)
           elif ($notdone | length) > 0 and ($notdone | all(.status == "interrupted_by_user")) then "interrupted_by_user"
           elif ($done | length) > 0 and ($unf | length) > 0 then "partial"
           else "unfinished" end) as $status
        | {
            run_id: ($m.runId // $wid), manifest_id: $wid, kind: "workflow", status: $status,
            resumable: ($status == "partial" or $status == "unfinished" or $status == "finished_with_failures"),
            script_path: (if ($m.scriptPath // "") == "" then null else $m.scriptPath end),
            script_inline: (($m.scriptPath // "") == "" and ($m.script // "") != ""),
            unfinished_steps: ($unf | map(.key)),
            steps: $steps,
            agents: $ag
          }' 2>/dev/null
}

# Session-level block. Usage: _ri_session_json <sid> <transcript> <cwd>
_ri_session_json() {
    local _sid="$1" _t="$2" _cwd="$3" _out _flag _rec _state _err _ck _br _dirty _ph _fp
    _state="none" _err=""
    if [ -n "$_t" ] && [ -f "$_t" ]; then
        _state="in_progress"
        _out="$(resume_last_meaningful_with_close "$_t" 200 2>/dev/null)"
        if [ -n "$_out" ]; then
            _flag="${_out%%$'\t'*}"
            _rec="${_out#*$'\t'}"
            _err="$(resume_synthetic_error "$_rec" 2>/dev/null)"
            if [ -n "$_err" ]; then
                _state="errored"
                _err="${_err%%$'\t'*}"
            elif resume_record_is_interrupt "$_rec"; then
                _state="interrupted"
            elif printf '%s' "$_rec" | jq -e --arg flag "$_flag" '
                .type == "assistant"
                and ([.message.content[]? | select(type == "object" and .type == "tool_use")] | length == 0)
                and (.message.stop_reason == "end_turn" or $flag == "true")' >/dev/null 2>&1; then
                _state="complete"
            fi
        fi
        _ph="$(tail -n 400 "$_t" | jq -R -r '
            (try fromjson catch null) | select(type == "object" and .type == "user" and ((.isSidechain // false) | not))
            | (.message.content // empty) | if type == "string" then . else ([.[]? | select(type == "object" and .type == "text") | .text] | join(" ")) end
            | select(length > 0 and (startswith("[Request interrupted") | not) and (startswith("<") | not))
            | .[0:200]' 2>/dev/null | tail -n 1)"
        _fp="$(head -n 60 "$_t" | jq -R -r '
            (try fromjson catch null) | select(type == "object" and .type == "user" and ((.isSidechain // false) | not))
            | (.message.content // empty) | if type == "string" then . else ([.[]? | select(type == "object" and .type == "text") | .text] | join(" ")) end
            | select(length > 0 and (startswith("[Request interrupted") | not) and (startswith("<") | not))
            | .[0:200]' 2>/dev/null | head -n 1)"
    fi
    _ck="" _br="" _dirty=false
    if [ -n "$_cwd" ] && [ -d "$_cwd" ]; then
        # shellcheck disable=SC2012
        _ck="$(ls -t "$_cwd"/.borg/checkpoints/*.md 2>/dev/null | head -n 1)"
        _br="$(_ri_git_branch "$_cwd")"
        _dirty="$(_ri_git_dirty "$_cwd")"
    fi
    jq -n -c --arg t "$_t" --arg cwd "$_cwd" --arg state "$_state" --arg err "$_err" --arg ph "$_ph" --arg fp "$_fp" \
        --arg ck "$_ck" --arg br "$_br" --argjson dirty "$_dirty" '
        def e: if . == "" then null else . end;
        {
            transcript: ($t | e), cwd: ($cwd | e), turn_state: $state, error: ($err | e),
            prompt_head: ($ph | e), first_prompt_head: ($fp | e),
            checkpoint: ($ck | e), git: {branch: ($br | e), dirty: $dirty}
        }'
}

borg_resume_inventory() {
    local _sid="${1:-}" _loc _t _sd _cwd _reg _session _agents _wfs _wts _f _line _b _seen _wid _path _wl
    if ! borg_resume_valid_sid "$_sid"; then
        _ri_empty "$_sid"
        return 0
    fi
    _loc="$(_ri_locate "$_sid")"
    _t="${_loc%%$'\t'*}"
    _sd="${_loc#*$'\t'}"
    if [ -z "$_t" ] && [ -z "$_sd" ]; then
        _ri_empty "$_sid"
        return 0
    fi
    _cwd=""
    _reg="$(borg_resume_registry_file "$_sid")"
    [ -f "$_reg" ] && _cwd="$(jq -r '.cwd // empty' "$_reg" 2>/dev/null)"
    if [ -z "$_cwd" ] && [ -n "$_t" ]; then
        _cwd="$(head -n 20 "$_t" | jq -R -r '(try fromjson catch null) | select(type == "object") | .cwd // empty' 2>/dev/null | head -n 1)"
    fi
    _session="$(_ri_session_json "$_sid" "$_t" "$_cwd")"

    _agents=""
    if [ -n "$_sd" ]; then
        for _f in "$_sd"/subagents/agent-*.jsonl; do
            [ -f "$_f" ] || continue
            _line="$(_ri_agent_json "$_sid" "$_f" agent)"
            [ -n "$_line" ] && _agents="${_agents}${_line}"$'\n'
        done
    fi

    # Workflow ids: manifests plus journal directories, de-duplicated (a run killed before its manifest was
    # written still has a directory).
    _wfs=""
    _seen=" "
    if [ -n "$_sd" ]; then
        for _path in "$_sd"/workflows/wf_*.json "$_sd"/subagents/workflows/wf_*; do
            [ -e "$_path" ] || continue
            _wid="${_path##*/}"
            _wid="${_wid%.json}"
            case "$_seen" in *" $_wid "*) continue ;; esac
            _seen="${_seen}${_wid} "
            _wl="$(_ri_workflow_json "$_sid" "$_sd" "$_wid")"
            [ -n "$_wl" ] && _wfs="${_wfs}${_wl}"$'\n'
        done
    fi

    _wts=""
    if [ -n "$_cwd" ] && [ -d "$_cwd" ]; then
        # Linked worktrees of the session's repo (the first porcelain entry is the main checkout; skip it).
        git -C "$_cwd" worktree list --porcelain 2>/dev/null | awk '/^worktree /{n++; if (n > 1) print substr($0, 10)}' >"${TMPDIR:-/tmp}/.ri_wt.$$" 2>/dev/null
        while IFS= read -r _b; do
            [ -n "$_b" ] || continue
            _line="$(_ri_worktree_json "$_b")"
            [ "$_line" != "null" ] && _wts="${_wts}${_line}"$'\n'
        done <"${TMPDIR:-/tmp}/.ri_wt.$$"
        rm -f "${TMPDIR:-/tmp}/.ri_wt.$$"
    fi

    jq -n -c --arg sid "$_sid" --argjson session "$_session" \
        --argjson agents "$(printf '%s' "$_agents" | jq -s -c '.')" \
        --argjson wfs "$(printf '%s' "$_wfs" | jq -s -c '.')" \
        --argjson wts "$(printf '%s' "$_wts" | jq -s -c '.')" '
        {session_id: $sid, found: true, session: $session, agents: $agents, workflows: $wfs, worktrees: $wts}'
    return 0
}
