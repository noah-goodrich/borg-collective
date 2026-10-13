#!/usr/bin/env bash
# resume-gate.sh -- pre-flight gate and confirmation for borg-resume (slice S9).
#
# Sourced by bin/borg-resume (watch branch) after resume-watch.sh; resume-watch.sh calls the two entry points from
# borg_resume_watch_once. Bash 3.2 safe, jq required. Functions only; sourcing prints nothing.
#
#   borg_resume_gate_confirm_pass   injecting/injected -> confirmed (prompt tag in the transcript, or an ack),
#                                   no-evidence retry or failure, confirmed -> stalled (post-confirmation watchdog)
#   borg_resume_gate_due_pass       for every due record: weekly notices, supersede, age, cap, container,
#                                   concurrency, headroom probe, dispatch guard, D3 /compact, then render with the
#                                   S6 renderer and call borg_inject_line (S8); map EVERY inject exit to a state
#
# Safety rules honoured here (directive): never inject without positive proof (that is borg_inject_line; the gate
# only decides WHETHER to ask it); never resume a deliberate stop (interrupt marker -> cancelled); at most
# BORG_RESUME_MAX_ACTIVE (2) sessions in injecting/injected/confirmed; 3 consecutive no-progress resumes and 12
# injections per session per day -> capped; the DISABLED sentinel leaves every record untouched; limit-class records
# fail closed when the usage probe fails; container sessions are notify-only; agent_id from StopFailure is never
# relied on (scope comes from the record).
#
# Records of one session are grouped: the first ready record (a prompt_too_long one first) leads, the rest follow it
# (`lead` field), and the S6 prompt for the lead lists every scope. A follower stays `injected` until the lead
# resolves; _rg_sync_members then mirrors the lead's outcome.
#
# Exit mapping of borg_inject_line: 0 injected -> injected; 10 defer -> deferred with gate_reason (a pane that is not
# provably idle for 10 minutes notifies ONCE and keeps deferring; there is no inject-anyway); 11 notify ->
# notify_only + one notification; 12 disabled -> deferred; 2 bad text -> failed + one notification.
#
# Test seams, honoured ONLY when BORG_RESUME_DIR is set (an isolated state dir, never production):
#   BORG_RESUME_INJECT_CMD  command run as `<cmd> <sid> <text>`; replaces borg_inject_line (stdout + exit code
#                           follow the same protocol). Without it, an isolated dir requires BORG_RESUME_TMUX_CMD,
#                           else injection reports `defer no_tmux`, so a test can never reach a real tmux.
#   BORG_RESUME_NOTIFY_CMD  the notifier seam of the shared delivery path (resume-shared.sh); without it nothing is
#                           shown. BORG_RESUME_RELAUNCH_HOOK_FILE: a file sourced to define the S11 relaunch hook.
#   The usage probe in an isolated dir needs BORG_RESUME_USAGE_CMD, else it counts as failed.
#
# Env: BORG_RESUME_MAX_ACTIVE (2), BORG_RESUME_MAX_CONSECUTIVE (3), BORG_RESUME_MAX_PER_DAY (12),
# BORG_RESUME_MAX_PER_PASS (1), BORG_RESUME_MAX_AGE_HOURS (48), BORG_RESUME_HEADROOM_MAX (90),
# BORG_RESUME_CONFIRM_WAIT_SEC (90), BORG_RESUME_STALL_MIN (10), BORG_RESUME_IDLE_NOTIFY_SEC (600),
# BORG_RESUME_COMPACT_WAIT_SEC (120), BORG_RESUME_WEEKLY (notify = notify-only), BORG_RESUME_WEEKLY_MIN_SEC (86400),
# BORG_RESUME_AUTO_COMPACT (S6 flag), BORG_USAGE_HALT_ENABLED / _PCT / _TTL_SEC / BORG_USAGE_SAMPLES (dispatch guard).
#
# Relaunch of a dead process and the resume-size dialog live in resume-relaunch.sh (S11). Deferred: launchd (S12), doctor (S13),
# status/cancel/pause/run verbs (S14; notifications already name `borg resume cancel|run <rid>`). Liveness (S10)
# records dead owners; this gate owns the post-confirmation stall watchdog.

# shellcheck disable=SC2016
_RG_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=/dev/null
command -v borg_inject_line >/dev/null 2>&1 || . "$_RG_DIR/inject.sh" 2>/dev/null
# shellcheck source=/dev/null
command -v borg_resume_probe >/dev/null 2>&1 || . "$_RG_DIR/resume-probe.sh" 2>/dev/null
# shellcheck source=/dev/null
command -v borg_resume_prompt >/dev/null 2>&1 || . "$_RG_DIR/resume-prompt.sh" 2>/dev/null
# shellcheck source=/dev/null
command -v borg_resume_notify >/dev/null 2>&1 || . "$_RG_DIR/resume-shared.sh" 2>/dev/null
# S11 relaunch hook for dead sessions (lib/borg/resume-relaunch.sh), called only from _rg_dispatch_dead
# shellcheck source=/dev/null
command -v borg_resume_relaunch_hook >/dev/null 2>&1 || . "$_RG_DIR/resume-relaunch.sh" 2>/dev/null

_RG_SEP=$'\037'
_RG_GROUP=""
_RG_NINJ=0
_RG_READY=""

# ---------------------------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------------------------

_rg_int() { # <env-name> <default>
    local _v="${!1:-}"
    case "$_v" in "" | *[!0-9]*) _v="$2" ;; esac
    printf '%s' "$_v"
}

_rg_log() { _rw_log "gate: $*"; }
_rg_isolated() { [ -n "${BORG_RESUME_DIR:-}" ]; }

# Fail closed: without the shared library (notify, "moving") every notice would be lost and the stall check would
# fall through on elapsed time alone. Log and skip the pass instead.
_rg_shared_loaded() {
    command -v borg_resume_shared_ok >/dev/null 2>&1 && borg_resume_shared_ok && return 0
    _rw_log "gate: resume-shared.sh not loaded, pass skipped"
    return 1
}

_rg_fmt_time() {
    date -r "$1" '+%a %b %d %H:%M' 2>/dev/null || date -d "@$1" '+%a %b %d %H:%M' 2>/dev/null || printf '%s' "$1"
}

_rg_lines() { # <file> -> line count (0 when unreadable)
    local _n=0
    [ -f "$1" ] && _n="$(wc -l <"$1" | tr -d ' ')"
    printf '%s' "${_n:-0}"
}

# One notification per (record, key): the key is written BEFORE the send, so a crash can never double-notify.
_rg_note() { # <file> <key> <message>
    local _f="$1" _k="$2" _m="$3" _sid
    [ -n "$(jq -r --arg k "$_k" '(.notices // {})[$k] // empty' "$_f" 2>/dev/null)" ] && return 0
    _rw_update "$_f" --arg k "$_k" --argjson now "$(_rc_now)" \
        '.notices = ((.notices // {}) + {($k): $now}) | .notified = true' || return 0
    _sid="$(jq -r .sid "$_f" 2>/dev/null)"
    _rg_log "notify ${_f##*/} $_k"
    # RECONCILE-6: the single delivery path (bounded outbox + dedup) lives in resume-shared.sh.
    borg_resume_notify "$_k" "$_sid" "$(jq -r .rid "$_f" 2>/dev/null)" "$_m"
    return 0
}

# State transition. Terminal states and a reason also record done_reason. Extra jq filter may use $now.
_rg_to() { # <file> <state> [reason] [extra filter]
    local _f="$1" _st="$2" _r="${3:-}" _x="${4:-.}"
    _rw_update "$_f" --arg st "$_st" --arg r "$_r" --argjson now "$(_rc_now)" "
        .state = \$st
        | .state_log = ((.state_log + [[\$st, \$now] + (if \$r == \"\" then [] else [\$r] end)])[-40:])
        | (if \$r != \"\" and (\$st | IN(\"deferred\", \"injecting\", \"injected\", \"confirmed\") | not)
           then .done_reason = \$r else . end)
        | $_x"
}

# The optional third argument is a not-before time (gate_next): the gate skips the record until then. resume_at itself
# is never rewritten here, it stays the scheduled time.
_rg_defer() { # <file> <reason> [not-before]
    local _f="$1" _r="$2" _ra="${3:-}"
    _rw_update "$_f" --arg r "$_r" --arg ra "$_ra" --argjson now "$(_rc_now)" '
        (if .state != "deferred" or (.gate_reason // "") != $r
         then .state_log = ((.state_log + [["deferred", $now, $r]])[-40:]) else . end)
        | .state = "deferred" | .gate_reason = $r
        | (if $ra != "" then .gate_next = ($ra | tonumber) else del(.gate_next) end)'
}

_rg_each() { # <fn> [args]: apply fn <file> [args] to every file of the current group
    local _fn="$1" _f
    shift
    while IFS= read -r _f; do
        [ -n "$_f" ] && "$_fn" "$_f" "$@"
    done <<EOF
$_RG_GROUP
EOF
}

_rg_lead() { printf '%s\n' "$_RG_GROUP" | head -n 1; }

_rg_counter() { # <sid> <key> -> number (0 when no state file yet)
    local _f _v
    _f="$(_rw_state_file "$1")"
    [ -f "$_f" ] || { printf '0'; return 0; }
    _rw_state_ensure "$1"
    _v="$(jq -r --arg k "$2" '.[$k] // 0' "$_f" 2>/dev/null)"
    case "$_v" in "" | *[!0-9]*) _v=0 ;; esac
    printf '%s' "$_v"
}

# Load the fields of a record file into _f_* variables.
_rg_fields() {
    local _line
    _line="$(jq -r '[.rid, .sid, .scope, .class, .state, (.resume_at // "-"), (.first_seen // 0),
        (.reset_text // "-"), (.evidence.transcript_line // "-"), (.injected_at // "-")]
        | map(tostring) | join("\u001f")' "$1" 2>/dev/null)" || return 1
    [ -n "$_line" ] || return 1
    IFS="$_RG_SEP" read -r _f_rid _f_sid _f_scope _f_class _f_state _f_ra _f_fs _f_reset _f_evl _f_inj <<EOF
$_line
EOF
    [ "$_f_ra" != "-" ] || _f_ra="$_f_fs"
    return 0
}

_rg_main_transcript() { # <sid>
    local _loc
    _loc="$(_ri_locate "$1")"
    printf '%s\n' "${_loc%%$'\t'*}"
}

# ---------------------------------------------------------------------------------------------
# supersede
# ---------------------------------------------------------------------------------------------

# Count transcript records after <after-line> that mean the session moved on: user/assistant records that are not
# bookkeeping, synthetic errors, meta records, compact output, or this record's own prompt tag. With no known
# evidence line (after=0 and floor>0) only records timestamped after <floor> count.
_rg_progress() { # <file> <after-line> <floor-epoch> <rid>
    local _f="$1" _after="$2" _fs="$3" _rid="$4"
    [ -f "$_f" ] || { printf '0'; return 0; }
    tail -n +$((_after + 1)) "$_f" | jq -R -n -r --argjson fs "$_fs" --arg tag "[borg-resume $_rid]" \
        "$_RC_JQ_DEFS"'
        [inputs | (try fromjson catch null) | select(type == "object")
         | select((.type == "user" or .type == "assistant") and (is_bookkeeping | not))
         | select((.isApiErrorMessage // false) | not)
         | select((.isMeta // false) | not)
         | select((.isCompactSummary // false) | not)
         | select(([texts] | flatten | join(" ")) as $t
                  | ($t | contains($tag) | not)
                  and ($t | test("<command-name>/compact|<local-command-stdout>|^/compact") | not))
         | select($fs == 0 or ((try (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0) > $fs))
        ] | length' 2>/dev/null
}

# Does the main transcript hold a SendMessage to <agent> after <fs>?
_rg_sent_message() { # <main-file> <fs> <agent-id>
    [ -f "$1" ] || return 1
    [ "$(jq -R -n -r --argjson fs "$2" --arg aid "$3" '
        [inputs | (try fromjson catch null) | select(type == "object" and .type == "assistant")
         | select((try (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0) > $fs)
         | .message.content[]? | select(type == "object" and .type == "tool_use" and .name == "SendMessage")
         | select((.input.to // .input.agent_id // .input.recipient // "") == $aid)]
        | length' "$1" 2>/dev/null)" -gt 0 ]
}

# Did a later Agent call re-spawn the old agent's task (same description, or same brief by sha1)?
_rg_respawned() { # <main-file> <fs> <agent-file> <meta-file>
    local _desc _bsha _line _d _p _psha
    [ -f "$1" ] && [ -f "$3" ] || return 1
    _desc=""
    [ -f "$4" ] && _desc="$(jq -r '.description // empty' "$4" 2>/dev/null)"
    _bsha="$(head -n 1 "$3" | jq -j "$_RC_JQ_DEFS"'[texts] | flatten | join("\n")' 2>/dev/null | _rw_sha1)"
    while IFS="$_RG_SEP" read -r _d _p; do
        [ -n "$_d$_p" ] || continue
        if [ -n "$_desc" ] && [ "$_d" = "$_desc" ]; then return 0; fi
        if [ -n "$_p" ]; then
            _psha="$(printf '%s' "$_p" | base64 --decode 2>/dev/null | _rw_sha1)"
            [ -n "$_psha" ] && [ "$_psha" = "$_bsha" ] && return 0
        fi
    done < <(jq -R -n -r --argjson fs "$2" '
        inputs | (try fromjson catch null) | select(type == "object" and .type == "assistant")
        | select((try (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0) > $fs)
        | .message.content[]?
        | select(type == "object" and .type == "tool_use" and (.name == "Agent" or .name == "Task"))
        | [(.input.description // ""), ((.input.prompt // "") | @base64)] | join("\u001f")' "$1" 2>/dev/null)
    return 1
}

# Superseded? Prints the reason and returns 0 when something else already continued this scope.
_rg_superseded() { # <file> (fields loaded)
    local _loc _t _sd _tf _aid _after _fl _n _runid
    _loc="$(_ri_locate "$_f_sid")"
    _t="${_loc%%$'\t'*}"
    _sd="${_loc#*$'\t'}"
    _after=0
    _fl="$_f_fs"
    case "$_f_evl" in "-" | "" | *[!0-9]*) ;; *) _after="$_f_evl" _fl=0 ;; esac
    case "$_f_scope" in
        main)
            if [ -f "$(borg_resume_events_file "$_f_sid")" ] && jq -e -R -n --argjson fs "$_f_fs" '
                [inputs | fromjson? | select(type == "object" and .ev == "native_resume" and (.t // 0) >= $fs)]
                | length > 0' "$(borg_resume_events_file "$_f_sid")" >/dev/null 2>&1; then
                printf 'native_resume'
                return 0
            fi
            _n="$(_rg_progress "$_t" "$_after" "$_fl" "$_f_rid")"
            [ "${_n:-0}" -gt 0 ] && { printf 'transcript_advanced'; return 0; }
            ;;
        agent:*)
            _aid="${_f_scope#agent:}"
            [ -n "$_sd" ] && _tf="$_sd/subagents/agent-$_aid.jsonl"
            if [ -n "${_tf:-}" ]; then
                _n="$(_rg_progress "$_tf" "$_after" "$_fl" "$_f_rid")"
                [ "${_n:-0}" -gt 0 ] && { printf 'agent_advanced'; return 0; }
                _rg_sent_message "$_t" "$_f_fs" "$_aid" && { printf 'send_message'; return 0; }
                _rg_respawned "$_t" "$_f_fs" "$_tf" "$_sd/subagents/agent-$_aid.meta.json" &&
                    { printf 'respawned'; return 0; }
            fi
            ;;
        workflow:*)
            _runid="${_f_scope#workflow:}"
            if [ -f "$_t" ] && [ "$(jq -R -n -r --arg id "$_runid" '
                [inputs | (try fromjson catch null) | select(type == "object" and .type == "assistant")
                 | .message.content[]? | select(type == "object" and .type == "tool_use" and .name == "Workflow")
                 | select(.input.resumeFromRunId == $id)] | length' "$_t" 2>/dev/null)" -gt 0 ]; then
                printf 'workflow_resumed'
                return 0
            fi
            if [ -n "$_sd" ] && [ -f "$_sd/workflows/$_runid.json" ]; then
                _n="$(jq -s -r --arg id "$_runid" '
                    (map(select(.runId == $id))[0]) as $m
                    | if $m == null or ($m.scriptPath | not) then 0
                      else [.[] | select(.runId != $id and .scriptPath == $m.scriptPath
                                         and (.startTime // 0) > ($m.startTime // 0))] | length end' \
                    "$_sd"/workflows/wf_*.json 2>/dev/null)"
                [ "${_n:-0}" -gt 0 ] && { printf 'newer_run'; return 0; }
            fi
            ;;
    esac
    return 1
}

# ---------------------------------------------------------------------------------------------
# static checks (no external calls): weekly notices, due, supersede, age, cap, container
# ---------------------------------------------------------------------------------------------

# D9: a limit record whose reset is far away is a weekly limit. Two notifications, or notify-only on request.
# Returns 1 when the record became terminal.
_rg_weekly() { # <file> (fields loaded)
    local _now _when
    [ "$_f_class" = usage_limit ] && [ "$_f_reset" != "-" ] || return 0
    [ $((_f_ra - _f_fs)) -ge "$(_rg_int BORG_RESUME_WEEKLY_MIN_SEC 86400)" ] || return 0
    _now="$(_rc_now)"
    _when="$(_rg_fmt_time "$_f_ra")"
    if [ "${BORG_RESUME_WEEKLY:-}" = notify ]; then
        _rg_to "$1" notify_only weekly_notify_only
        _rg_note "$1" weekly_detect \
            "Weekly limit hit, auto-resume is off. Resets about $_when. Resume by hand: borg resume run $_f_rid"
        return 1
    fi
    _rg_note "$1" weekly_detect \
        "Weekly limit hit. Auto-resume at $_when. Cancel with: borg resume cancel $_f_rid"
    if [ "$_now" -lt "$_f_ra" ] && [ $((_f_ra - _now)) -le 900 ]; then
        _rg_note "$1" weekly_pre \
            "Weekly limit auto-resume in under 15 minutes ($_when). Cancel with: borg resume cancel $_f_rid"
    fi
    return 0
}

# HOOK POINT for S11 (relaunch): a process_death record is handed to borg_resume_relaunch_hook <rid> <cause> <file>
# when that function exists; it returns 0 when it took ownership of the record (state transitions are then its job).
# Until S11 defines it the record defers with no_pane and nothing is injected. BORG_RESUME_RELAUNCH_HOOK_FILE (an
# isolated state dir only) is sourced first so a test can define the hook.
#
# CONTRACT: the hook is called ONLY from _rg_run_group, after every dynamic gate (.borg/no-resume, no_session_hooks,
# per-pass and concurrency caps) has passed, and at most once per session per pass. The consecutive and daily caps
# were applied in the static pass. After the hook returns 0 the gate re-reads the record: one still in
# new/scheduled/deferred is forced to `relaunching` (a non-due state the hook's owner moves on), so a hook that
# forgets to transition can never be called again for the same record. Returns 0 when the hook took ownership.
_rg_dead_owner() { # <file>
    local _f="$1" _cause _rid _st
    _cause="$(jq -r '.cause // "unknown"' "$_f" 2>/dev/null)"
    _rid="$(jq -r .rid "$_f")"
    if _rg_isolated && [ -n "${BORG_RESUME_RELAUNCH_HOOK_FILE:-}" ]; then
        # shellcheck source=/dev/null
        . "$BORG_RESUME_RELAUNCH_HOOK_FILE" 2>/dev/null
    fi
    if command -v borg_resume_relaunch_hook >/dev/null 2>&1 &&
        borg_resume_relaunch_hook "$_rid" "$_cause" "$_f"; then
        if [ -f "$_f" ]; then
            _st="$(jq -r .state "$_f" 2>/dev/null)"
            case "$_st" in
                new | scheduled | deferred)
                    # A hook that deferred the record itself (cap, shell unproven) keeps that deferral.
                    [ "${_RR_DEFERRED:-0}" = 1 ] && [ "$_st" = deferred ] && return 0
                    _rg_to "$_f" relaunching hook_no_transition
                    _rg_log "relaunch hook left $_rid in $_st; forced to relaunching"
                    ;;
            esac
        fi
        return 0
    fi
    _rg_defer "$_f" no_pane
    return 1
}

# Hand the process_death records of the current group (all gates passed) to the relaunch path; the remaining
# records stay the group. A second record of a session that already has one relaunching does not call the hook again.
_rg_dispatch_dead() { # <sid>
    local _f _keep="" _d _o _busy=0
    _d="$(borg_resume_dir)"
    for _o in "$_d"/pending/*.json; do
        [ -f "$_o" ] || continue
        jq -e --arg s "$1" '.sid == $s and .state == "relaunching"' "$_o" >/dev/null 2>&1 && _busy=1
    done
    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        if [ "$(jq -r .class "$_f")" != process_death ]; then
            _keep="${_keep}${_f}"$'\n'
        elif [ "$_busy" = 1 ]; then
            _rg_to "$_f" relaunching relaunch_sibling
        elif _rg_dead_owner "$_f"; then
            _busy=1
            _RG_NINJ=$((_RG_NINJ + 1))
        fi
    done <<EOF
$_RG_GROUP
EOF
    _RG_GROUP="${_keep%$'\n'}"
}

# Static pass for one record. Appends "sid<US>file" to _RG_READY when it should be considered for injection.
_rg_static() { # <file>
    local _f="$1" _now _age _base _reason _cons _day _cont _runat
    _rg_fields "$_f" || return 0
    case "$_f_state" in new | scheduled | deferred) ;; *) return 0 ;; esac
    borg_resume_valid_sid "$_f_sid" || return 0
    # A record without a class is malformed (never written by the watcher): leave it alone.
    case "$_f_class" in "" | null) return 0 ;; esac
    _now="$(_rc_now)"
    _rg_weekly "$_f" || return 0
    [ "$_f_ra" -le "$_now" ] || return 0
    [ "$(jq -r '.gate_next // 0' "$_f")" -le "$_now" ] || return 0

    if _reason="$(_rg_superseded "$_f")"; then
        _rg_to "$_f" superseded "$_reason"
        _rg_log "superseded $_f_rid ($_reason)"
        return 0
    fi

    _age="$(_rg_int BORG_RESUME_MAX_AGE_HOURS 48)"
    _base="$_f_ra"
    # run_at (set by `borg resume run`) rebases the age clock and the 7-day ceiling.
    _runat="$(jq -r '.run_at // 0' "$_f" 2>/dev/null)"
    case "$_runat" in "" | *[!0-9]*) _runat=0 ;; esac
    [ "$_runat" -gt "$_base" ] && _base="$_runat"
    [ "$_runat" -gt "$_f_fs" ] && _f_fs="$_runat"
    if [ "$_f_class" = usage_limit ] && [ "$_f_reset" != "-" ]; then
        if [ $((_now - _f_fs)) -gt 604800 ]; then
            _rg_to "$_f" expired age_ceiling
            _rg_note "$_f" expired "Resume $_f_rid expired (older than 7 days). Retry by hand: borg resume run $_f_rid"
            return 0
        fi
        [ $((_now - _base)) -gt $((_age * 3600)) ] && _base=$((_now - _age * 3600))
    fi
    if [ $((_now - _base)) -gt $((_age * 3600)) ]; then
        _rg_to "$_f" expired age
        _rg_note "$_f" expired "Resume $_f_rid expired (older than ${_age}h). Retry by hand: borg resume run $_f_rid"
        return 0
    fi

    _cons="$(_rg_counter "$_f_sid" consecutive)"
    _day="$(_rg_counter "$_f_sid" injections_today)"
    if [ "$_cons" -ge "$(_rg_int BORG_RESUME_MAX_CONSECUTIVE 3)" ]; then
        _rg_to "$_f" capped consecutive_cap
        _rg_note "$_f" capped \
            "Stopped after $_cons resumes without progress ($_f_rid). Force one with: borg resume run $_f_rid --force"
        return 0
    fi
    if [ "$_day" -ge "$(_rg_int BORG_RESUME_MAX_PER_DAY 12)" ]; then
        _rg_to "$_f" capped daily_cap
        _rg_note "$_f" capped "Daily resume cap reached ($_f_rid); it resets at midnight. Then: borg resume run $_f_rid"
        return 0
    fi

    _cont="$(jq -r '.in_container // false' "$(borg_resume_registry_file "$_f_sid")" 2>/dev/null)"
    if [ "$_cont" = true ]; then
        _rg_to "$_f" notify_only container_session
        _cont="drone up <project> --resume $_f_sid, or borg resume run $_f_rid"
        _rg_note "$_f" container "Container session needs a manual resume ($_f_rid): $_cont"
        return 0
    fi
    # S10 records whose owner is gone (process_death) join the group like any other, but _rg_run_group hands them to
    # the relaunch path (S11) only AFTER the dynamic gates, and never injects them.
    _RG_READY="${_RG_READY}${_f_sid}${_RG_SEP}${_f}"$'\n'
    return 0
}

# ---------------------------------------------------------------------------------------------
# dynamic gates
# ---------------------------------------------------------------------------------------------

_rg_active_sids() {
    local _f
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        jq -r --argjson n "$(_rc_now)" 'select(.state | IN("injecting", "injected", "confirmed"))
            // select(.state == "relaunching" and ((.state_log[-1][1] // 0) > $n - 3600)) | .sid' "$_f" 2>/dev/null
    done | sort -u
}

# Print the usage percent and return 0, or return 1 when unknown.
_rg_probe() {
    if _rg_isolated && [ -z "${BORG_RESUME_USAGE_CMD:-}" ]; then
        return 1
    fi
    borg_resume_probe 2>/dev/null
}

# True when borg-dispatch-guard.sh would deny Agent|Workflow right now (same signal, same fail-open reading).
_rg_dispatch_guard_denies() {
    local _s _last _pct _ts _ep _now _halt _ttl
    [ "${BORG_USAGE_HALT_ENABLED:-0}" = 1 ] || return 1
    _s="${BORG_USAGE_SAMPLES:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-samples.jsonl}"
    [ -f "$_s" ] || return 1
    _last="$(tail -n 1 "$_s" 2>/dev/null)"
    [ "$(printf '%s' "$_last" | jq -r '.status // ""' 2>/dev/null)" = ok ] || return 1
    _pct="$(printf '%s' "$_last" |
        jq -r 'if (.session_pct | type) == "number" then (.session_pct | floor) else "" end' 2>/dev/null)"
    case "$_pct" in "" | *[!0-9]*) return 1 ;; esac
    _ts="$(printf '%s' "$_last" | jq -r '.ts // ""' 2>/dev/null)"
    _ep="$(printf '%s' "$_ts" | jq -R -r 'try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0' 2>/dev/null)"
    case "$_ep" in "" | 0 | *[!0-9]*) return 1 ;; esac
    _now="$(_rc_now)"
    _ttl="$(_rg_int BORG_USAGE_HALT_TTL_SEC 300)"
    [ "$_now" -ge "$_ep" ] && [ $((_now - _ep)) -le "$_ttl" ] || return 1
    _halt="$(_rg_int BORG_USAGE_HALT_PCT 92)"
    [ "$_pct" -ge "$_halt" ]
}

# Run the injector (or its seam). Sets _RG_OUT and returns its exit code.
_rg_do_inject() { # <sid> <text>
    local _w _rc
    if _rg_isolated; then
        if [ -n "${BORG_RESUME_INJECT_CMD:-}" ]; then
            read -r -a _w <<<"$BORG_RESUME_INJECT_CMD"
            _RG_OUT="$("${_w[@]}" "$1" "$2" 2>/dev/null)"
            return $?
        fi
        if [ -z "${BORG_RESUME_TMUX_CMD:-}" ]; then
            _RG_OUT="defer no_tmux"
            return 10
        fi
    fi
    _RG_OUT="$(borg_inject_line "$1" "$2" 2>/dev/null)"
    _rc=$?
    return "$_rc"
}

# A pane left deferred for 10 minutes: notify ONCE, keep deferring (never inject anyway).
_rg_idle_watch() { # <lead-file>
    local _f="$1" _since _now _rid
    _now="$(_rc_now)"
    _rid="$(jq -r .rid "$_f")"
    _since="$(jq -r '.idle_since // empty' "$_f" 2>/dev/null)"
    if [ -z "$_since" ]; then
        _rw_update "$_f" --argjson now "$_now" '.idle_since = $now'
        return 0
    fi
    if [ $((_now - _since)) -ge "$(_rg_int BORG_RESUME_IDLE_NOTIFY_SEC 600)" ]; then
        _rg_note "$_f" idle_10min \
            "Pane unbound or not provably idle for 10 minutes ($_rid). Still retrying; cancel: borg resume cancel $_rid"
    fi
    return 0
}

# Map a non-zero borg_inject_line result onto the current group.
_rg_map_fail() { # <rc> <out>
    local _rc="$1" _out="$2" _reason _lead
    _reason="${_out#* }"
    _reason="${_reason//[^A-Za-z0-9_:=.%-]/_}"
    _reason="${_reason:0:60}"
    [ -n "$_reason" ] || _reason=unknown
    _lead="$(_rg_lead)"
    case "$_rc" in
        10)
            _rg_each _rg_defer "$_reason"
            case "$_reason" in paused | disabled) ;; *) _rg_idle_watch "$_lead" ;; esac
            ;;
        11)
            _rg_each _rg_to notify_only "$_reason"
            _rg_note "$_lead" inject_notify \
                "Could not resume safely ($_reason). Do it by hand: borg resume run $(jq -r .rid "$_lead")"
            ;;
        12) _rg_each _rg_defer disabled ;;
        2)
            _rg_each _rg_to failed bad_text
            _rg_note "$_lead" inject_error "Resume text was refused ($(jq -r .rid "$_lead")); see watch.log"
            ;;
        *) _rg_each _rg_defer inject_error ;;
    esac
    _rg_log "inject rc=$_rc reason=$_reason lead=${_lead##*/}"
}

# After a successful injection of the normal prompt: lead -> injected, followers follow it.
_rg_on_injected() { # <sid> <main-transcript> <lines-before-inject>
    local _lead _lrid _lines _f
    _lead="$(_rg_lead)"
    _lrid="$(jq -r .rid "$_lead")"
    # The baseline is the count taken BEFORE the injector ran, so a user record claude wrote at once is not hidden.
    _lines="${3:-$(_rg_lines "$2")}"
    _rg_to "$_lead" injected "" ".injected_at = \$now | .inject_lines = $_lines
        | .inject_tries = ((.inject_tries // 0) + 1) | del(.gate_reason, .idle_since)"
    while IFS= read -r _f; do
        [ -n "$_f" ] && [ "$_f" != "$_lead" ] || continue
        _rg_to "$_f" injected "" ".injected_at = \$now | .inject_lines = $_lines | .lead = \"$_lrid\"
            | del(.gate_reason, .idle_since)"
    done <<EOF
$_RG_GROUP
EOF
    _rw_state_ensure "$1"
    # consecutive counts every resume injection; it is reset only by measured progress or an ack (resume-watch.sh).
    _rw_update "$(_rw_state_file "$1")" '.injections_today += 1 | .resumed_total += 1 | .consecutive += 1'
    _RG_NINJ=$((_RG_NINJ + 1))
    _rg_log "injected $_lrid sid=$1"
}

# D3: one automatic /compact behind the flag. Returns 0 to go on with the normal prompt, 1 when handled.
# U12 (does /compact via send-keys work, and is the boundary recorded) is UNRUN: a missing boundary counts as a
# failure and two failures notify.
_rg_compact_step() { # <lead-file> <sid> <main-transcript>
    local _f="$1" _sid="$2" _t="$3" _st _fails _at _cl _now _rc _rid
    _now="$(_rc_now)"
    _rid="$(jq -r .rid "$_f")"
    _st="$(jq -r '.compact.state // "none"' "$_f")"
    _fails="$(jq -r '.compact.fails // 0' "$_f")"
    case "$_st" in
        done) return 0 ;;
        waiting)
            _at="$(jq -r '.compact.at // 0' "$_f")"
            _cl="$(jq -r '.compact.lines // 0' "$_f")"
            if tail -n +$((_cl + 1)) "$_t" 2>/dev/null | jq -R -n -e '[inputs | (try fromjson catch null)
                | select(type == "object" and ((.type == "system" and .subtype == "compact_boundary")
                                               or .isCompactSummary == true))] | length > 0' >/dev/null 2>&1; then
                _rw_update "$_f" '.compact.state = "done"'
                _rg_log "compact boundary seen for $(jq -r .rid "$_f")"
                return 0
            fi
            if [ $((_now - _at)) -ge "$(_rg_int BORG_RESUME_COMPACT_WAIT_SEC 120)" ]; then
                _fails=$((_fails + 1))
                if [ "$_fails" -ge 2 ]; then
                    _rg_each _rg_to notify_only compact_failed
                    _rg_note "$_f" compact_failed \
                        "Automatic /compact failed twice ($_rid). Compact by hand, then: borg resume run $_rid"
                else
                    _rw_update "$_f" --argjson n "$_fails" '.compact = {state: "none", fails: $n}'
                    _rg_each _rg_defer compact_retry
                fi
            else
                _rg_each _rg_defer compact_wait
            fi
            return 1
            ;;
        *)
            _rg_do_inject "$_sid" "/compact"
            _rc=$?
            if [ "$_rc" -ne 0 ]; then
                _rg_map_fail "$_rc" "$_RG_OUT"
                return 1
            fi
            _rw_update "$_f" --argjson now "$_now" --argjson l "$(_rg_lines "$_t")" --argjson n "$_fails" \
                '.compact = {state: "waiting", at: $now, lines: $l, fails: $n}'
            _rw_state_ensure "$_sid"
            _rw_update "$(_rw_state_file "$_sid")" '.injections_today += 1 | .resumed_total += 1'
            _RG_NINJ=$((_RG_NINJ + 1))
            _rg_each _rg_defer compact_wait
            _rg_log "compact sent for $(jq -r .rid "$_f")"
            return 1
            ;;
    esac
}

# Gate and, if every check passes, inject for the group in _RG_GROUP (lead first).
_rg_run_group() { # <sid>
    local _pre _sid="$1" _lead _lrid _limit=0 _f _cwd _pct _fails _n _msg _line _rc _t _active _nact _max _hm
    _lead="$(_rg_lead)"
    _lrid="$(jq -r .rid "$_lead")"
    _t="$(_rg_main_transcript "$_sid")"

    _cwd="$(jq -r '.cwd // .tmux.project_dir // empty' "$(borg_resume_registry_file "$_sid")" 2>/dev/null)"
    if [ -n "$_cwd" ] && [ -e "$_cwd/.borg/no-resume" ]; then
        _rg_each _rg_defer no_resume
        return 0
    fi
    if borg_resume_no_session_hooks; then
        _rg_each _rg_defer no_session_hooks
        return 0
    fi
    [ "$_RG_NINJ" -lt "$(_rg_int BORG_RESUME_MAX_PER_PASS 1)" ] || return 0

    # Concurrency: sessions already in injecting/injected/confirmed (this one does not count against itself).
    _active="$(_rg_active_sids)"
    _max="$(_rg_int BORG_RESUME_MAX_ACTIVE 2)"
    _nact=0
    if [ -n "$_active" ] && ! printf '%s\n' "$_active" | grep -qx -- "$_sid"; then
        _nact="$(printf '%s\n' "$_active" | grep -c .)"
    fi
    if [ "$_nact" -ge "$_max" ]; then
        _rg_each _rg_defer concurrency
        return 0
    fi

    # Dead owners (process_death) never get an injection; they go to the relaunch hook now that the gates passed.
    _rg_dispatch_dead "$_sid"
    [ -n "$_RG_GROUP" ] || return 0
    _lead="$(_rg_lead)"
    _lrid="$(jq -r .rid "$_lead")"

    # Prompt-too-long without the compact flag is notify-only (D3).
    if [ "$(jq -r .class "$_lead")" = prompt_too_long ] && ! resume_prompt_compact_enabled; then
        _rg_each _rg_to notify_only compact_disabled
        _rg_note "$_lead" ptl "Context too long, auto /compact is off ($_lrid). Compact, then: borg resume run $_lrid"
        return 0
    fi

    while IFS= read -r _f; do
        [ -n "$_f" ] && [ "$(jq -r .class "$_f")" = usage_limit ] && _limit=1
    done <<EOF
$_RG_GROUP
EOF

    # Headroom. Limit-class fails CLOSED; other classes proceed when the probe cannot answer.
    _hm="$(_rg_int BORG_RESUME_HEADROOM_MAX 90)"
    if _pct="$(_rg_probe)" && [ -n "$_pct" ]; then
        if [ "$_pct" -ge "$_hm" ]; then
            _rg_each _rg_defer headroom $(($(_rc_now) + 300))
            return 0
        fi
        [ "$_limit" = 1 ] && _rg_each _rg_probe_ok
    elif [ "$_limit" = 1 ]; then
        _fails="$(jq -r '(.probe_fails // 0) + 1' "$_lead")"
        _rw_update "$_lead" --argjson n "$_fails" '.probe_fails = $n'
        case "$_fails" in 1) _n=60 ;; 2) _n=120 ;; 3) _n=300 ;; *) _n=900 ;; esac
        _rg_each _rg_defer probe_failed $(($(_rc_now) + _n))
        if [ "$_fails" -ge 3 ]; then
            _rg_note "$_lead" probe_failed \
                "Cannot read usage, so the limit-class resume $_lrid stays deferred. Check: borg doctor"
        fi
        return 0
    fi

    if _rg_dispatch_guard_denies; then
        _rg_each _rg_defer dispatch_guard $(($(_rc_now) + 120))
        return 0
    fi

    if [ "$(jq -r .class "$_lead")" = prompt_too_long ]; then
        _rg_compact_step "$_lead" "$_sid" "$_t" || return 0
    fi

    # Render with the S6 renderer. It refuses a `deferred` record, so the lead is `injecting` first.
    _rg_to "$_lead" injecting
    _msg="$(borg_resume_prompt "$_lrid" 2>&1)"
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        case "$_rc:$_msg" in
            3:*interrupted*)
                _rg_each _rg_to cancelled interrupted_by_user
                return 0
                ;;
            3:*)
                _rg_each _rg_to notify_only render_notify_only
                _rg_note "$_lead" render "Nothing safe to inject for $_lrid; resume by hand: borg resume run $_lrid"
                return 0
                ;;
        esac
        _fails="$(jq -r '(.render_fails // 0) + 1' "$_lead")"
        _rw_update "$_lead" --argjson n "$_fails" '.render_fails = $n'
        if [ "$_fails" -ge 3 ]; then
            _rg_each _rg_to notify_only render_failed
            _rg_note "$_lead" render "Could not render the prompt for $_lrid; resume by hand: borg resume run $_lrid"
        else
            _rg_each _rg_defer render_failed $(($(_rc_now) + 60 * _fails))
        fi
        return 0
    fi
    _line="$(borg_resume_prompt "$_lrid" --line 2>/dev/null)" || _line=""
    if [ -z "$_line" ]; then
        _rg_each _rg_defer render_failed $(($(_rc_now) + 60))
        return 0
    fi
    _pre="$(_rg_lines "$_t")"
    _rg_do_inject "$_sid" "$_line"
    _rc=$?
    if [ "$_rc" -eq 0 ]; then
        _rg_on_injected "$_sid" "$_t" "$_pre"
    else
        _rg_map_fail "$_rc" "$_RG_OUT"
    fi
    return 0
}

_rg_probe_ok() { # <file>
    _rw_update "$1" 'del(.probe_fails)'
}

# ---------------------------------------------------------------------------------------------
# followers
# ---------------------------------------------------------------------------------------------

# A follower mirrors its lead: terminal and done states copy over; a lead that went back to deferred releases it.
_rg_sync_members() {
    local _f _lead _lf _ls _reason _d
    _d="$(borg_resume_dir)"
    for _f in "$_d"/pending/*.json; do
        [ -f "$_f" ] || continue
        _lead="$(jq -r '.lead // empty' "$_f" 2>/dev/null)"
        [ -n "$_lead" ] || continue
        _lf=""
        [ -f "$_d/pending/$_lead.json" ] && _lf="$_d/pending/$_lead.json"
        [ -z "$_lf" ] && [ -f "$_d/done/$_lead.json" ] && _lf="$_d/done/$_lead.json"
        if [ -z "$_lf" ]; then
            _rg_defer "$_f" lead_gone
            _rw_update "$_f" 'del(.lead)'
            continue
        fi
        _ls="$(jq -r .state "$_lf")"
        _reason="$(jq -r '.done_reason // empty' "$_lf")"
        case "$_ls" in
            injecting | injected | confirmed) ;;
            new | scheduled | deferred)
                _rg_defer "$_f" lead_retry
                _rw_update "$_f" 'del(.lead)'
                ;;
            *) _rg_to "$_f" "$_ls" "$_reason" ;;
        esac
    done
    return 0
}

# ---------------------------------------------------------------------------------------------
# entry points
# ---------------------------------------------------------------------------------------------

borg_resume_gate_due_pass() {
    local _f _ord _mode _lines _ready _sid _seen _l _lead
    _rg_shared_loaded || return 0
    _rg_sync_members
    borg_resume_paused && return 0
    _RG_READY=""
    _RG_NINJ=0
    _lines=""
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        case "$(jq -r .state "$_f" 2>/dev/null)" in new | scheduled | deferred) ;; *) continue ;; esac
        _mode="$(jq -r '.mode // empty' "$(borg_resume_registry_file "$(jq -r .sid "$_f")")" 2>/dev/null)"
        _ord=1
        [ "$_mode" = orchestrator ] && _ord=0
        _lines="${_lines}${_ord}	$(jq -r '.first_seen // 0' "$_f")	${_f}"$'\n'
    done
    [ -n "$_lines" ] || return 0
    _ready="$(printf '%s' "$_lines" | sort -t "$(printf '\t')" -k1,1n -k2,2n)"
    while IFS=$'\t' read -r _ord _l _f; do
        [ -n "$_f" ] && _rg_static "$_f"
    done <<EOF
$_ready
EOF
    [ -n "$_RG_READY" ] || return 0
    _seen=" "
    while IFS="$_RG_SEP" read -r _sid _f; do
        [ -n "$_sid" ] || continue
        case "$_seen" in *" $_sid "*) continue ;; esac
        _seen="${_seen}${_sid} "
        # Group: every ready record of the session, a prompt_too_long one leading, else the first.
        _RG_GROUP=""
        _lead=""
        while IFS="$_RG_SEP" read -r _l _ord; do
            [ "$_l" = "$_sid" ] || continue
            if [ "$(jq -r .class "$_ord")" = prompt_too_long ] && [ -z "$_lead" ]; then
                _lead="$_ord"
            fi
        done <<EOF
$_RG_READY
EOF
        [ -n "$_lead" ] || _lead="$_f"
        _RG_GROUP="$_lead"$'\n'
        while IFS="$_RG_SEP" read -r _l _ord; do
            [ "$_l" = "$_sid" ] && [ "$_ord" != "$_lead" ] && _RG_GROUP="${_RG_GROUP}${_ord}"$'\n'
        done <<EOF
$_RG_READY
EOF
        _RG_GROUP="${_RG_GROUP%$'\n'}"
        _rg_run_group "$_sid"
    done <<EOF
$_RG_READY
EOF
    return 0
}

# Does the pane bound to <sid> show a dialog? Never reaches a real tmux from an isolated state dir.
_rg_pane_dialog() {
    local _hit _pane
    if _rg_isolated && [ -z "${BORG_RESUME_TMUX_CMD:-}" ]; then
        return 1
    fi
    _hit="$(borg_inject_find_pane "$1" 2>/dev/null)" || return 1
    _pane="${_hit%%|*}"
    [ "$(borg_inject_pane_state "$_pane" 2>/dev/null)" = dialog ]
}

# The transcript the stall watchdog watches: the agent file for an agent scope, else the main transcript.
_rg_stall_transcript() { # <record> <sid> <main-transcript>
    local _scope _loc _sd
    _scope="$(jq -r '.scope // "main"' "$1" 2>/dev/null)"
    case "$_scope" in
        agent:*)
            _loc="$(_ri_locate "$2")"
            _sd="${_loc#*$'\t'}"
            if [ -n "$_sd" ] && [ -f "$_sd/subagents/agent-${_scope#agent:}.jsonl" ]; then
                printf '%s\n' "$_sd/subagents/agent-${_scope#agent:}.jsonl"
                return 0
            fi
            ;;
    esac
    printf '%s\n' "$3"
}

borg_resume_gate_confirm_pass() {
    local _f _st _rid _sid _t _lines _size _inj _il _now _since _wait _tag _la _ll _ls _tt _sf _stall _perm _ev _wt
    _rg_shared_loaded || return 0
    _now="$(_rc_now)"
    _wait="$(_rg_int BORG_RESUME_CONFIRM_WAIT_SEC 90)"
    _stall="$(_rg_int BORG_RESUME_STALL_MIN 10)"
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        _st="$(jq -r .state "$_f" 2>/dev/null)"
        case "$_st" in injecting | injected | confirmed) ;; *) continue ;; esac
        [ -z "$(jq -r '.lead // empty' "$_f")" ] || continue
        _rid="$(jq -r .rid "$_f")"
        _sid="$(jq -r .sid "$_f")"
        _t="$(_rg_main_transcript "$_sid")"
        _lines="$(_rg_lines "$_t")"
        _size=0
        [ -f "$_t" ] && _size="$(wc -c <"$_t" | tr -d ' ')"
        _RG_GROUP="$_f"

        if [ "$_st" = confirmed ]; then
            # Post-confirmation watchdog: confirmation is not progress. This is the ONLY stall owner (RECONCILE-6);
            # "moving" is defined once in resume-shared.sh (lines or bytes grew; a recent mtime is only a hint).
            _ll="$(jq -r '.last_lines // .confirmed_lines // empty' "$_f")"
            _ls="$(jq -r '.last_size // .confirmed_size // empty' "$_f")"
            _la="$(jq -r '.last_growth_at // .confirmed_at // empty' "$_f")"
            [ -n "$_la" ] || _la="$_now"
            _tt="$(_rg_stall_transcript "$_f" "$_sid" "$_t")"
            borg_resume_transcript_moving "$_tt" "${_ll:-0}" "$_ls" $((_stall * 60))
            case $? in
                0)
                    _rw_update "$_f" --argjson l "$_RS_LINES" --argjson z "$_RS_SIZE" --argjson n "$_now" \
                        '.last_lines = $l | .last_size = $z | .last_growth_at = $n'
                    continue
                    ;;
                2) continue ;;
            esac
            if [ $((_now - _la)) -ge $((_stall * 60)) ]; then
                _since="$(jq -r '.injected_at // .confirmed_at // .first_seen // 0' "$_f")"
                # Only a prompt NEWER than the last growth proves a stuck prompt (an answered one is not).
                case "$_la" in "" | *[!0-9]*) ;; *) [ "$_la" -le "$_since" ] || _since="$_la" ;; esac
                _perm=0
                if [ -f "$(borg_resume_events_file "$_sid")" ] && jq -e -R -n --argjson s "$_since" '
                    [inputs | fromjson? | select(type == "object" and .ev == "permission_prompt" and (.t // 0) >= $s)]
                    | length > 0' "$(borg_resume_events_file "$_sid")" >/dev/null 2>&1; then
                    _perm=1
                fi
                if [ "$_perm" = 1 ] || _rg_pane_dialog "$_sid"; then
                    _rg_to "$_f" stalled no_progress_after_prompt
                    _rg_note "$_f" stalled \
                        "Resumed session looks stuck at a prompt, idle ${_stall} min ($_rid). Check its window."
                    # A stalled resume made no progress: it counts toward the consecutive cap (as S10 did).
                    _sf="$(_rw_state_file "$_sid")"
                    [ -f "$_sf" ] && _rw_update "$_sf" '.consecutive += 1'
                fi
            fi
            continue
        fi

        # injecting / injected: confirmation needs evidence.
        _inj="$(jq -r '.injected_at // empty' "$_f")"
        [ -n "$_inj" ] || _inj="$(jq -r '[(.state_log // [])[]
            | select(.[0] == "injecting" or .[0] == "injected") | .[1]] | max // 0' "$_f")"
        _il="$(jq -r '.inject_lines // 0' "$_f")"
        _since="$(_rw_ack_since "$_f")"
        case "$_since" in "" | null | *[!0-9]*) _since="$_inj" ;; esac
        _tag="[borg-resume $_rid]"
        _ev=""
        if _rw_has_ack "$_sid" "$_rid" "$_since"; then
            _ev=ack
        elif [ -f "$_t" ] && [ -n "$(tail -n +$((_il + 1)) "$_t" | jq -R -r --arg tag "$_tag" '
            (try fromjson catch null) | select(type == "object" and .type == "user") | tojson
            | select(contains($tag)) | "y"' 2>/dev/null | head -n 1)" ]; then
            _ev=tag
        fi
        if [ -n "$_ev" ]; then
            # The baseline is taken from the file the watchdogs watch (the agent transcript for an agent scope), so
            # growth is compared like with like.
            _wt="$(_rg_stall_transcript "$_f" "$_sid" "$_t")"
            _lines="$(_rg_lines "$_wt")"
            _size=0
            [ -f "$_wt" ] && _size="$(wc -c <"$_wt" | tr -d ' ')"
            _rg_to "$_f" confirmed "" ".confirmed_at = \$now | .confirmed_lines = $_lines | .last_lines = $_lines
                | .confirmed_size = $_size | .last_size = $_size
                | .last_growth_at = \$now | .confirmed_by = \"$_ev\""
            _rg_log "confirmed $_rid by $_ev"
            continue
        fi
        if [ $((_now - _inj)) -ge "$_wait" ]; then
            # No evidence in the window: a no-progress resume. Re-verify and re-send once, then fail.
            if [ "$(jq -r '.inject_tries // 0' "$_f")" -ge 2 ]; then
                _rg_to "$_f" failed confirm_timeout
                _rg_note "$_f" failed "Resume never confirmed ($_rid). Check the window or retry: borg resume run $_rid"
            else
                _rg_defer "$_f" confirm_retry "$_now"
            fi
            _rg_log "no confirmation for $_rid"
        fi
    done
    _RG_GROUP=""
    return 0
}
