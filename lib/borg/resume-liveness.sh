#!/usr/bin/env bash
# resume-liveness.sh -- liveness detector for borg-resume (slice S10).
#
# Sourced by the watcher (lib/borg/resume-watch.sh) after resume-paths.sh, resume-classify.sh, resume-inventory.sh
# and the watcher itself; it uses the watcher's _rw_* helpers. Bash 3.2 safe. Functions only.
#
#   borg_resume_liveness_pass   called once per watcher pass, after the hook fold and the transcript scan.
#
# What it does, per session with a registry row touched inside the scan window:
#   1. Fold the session's events into an END STATE: open | deliberate | closed. A `via=mark_closed` session_end is
#      STICKY (lib/borg/resume-close.sh): a later session_end `other` or a trailing stop_failure written by the dying
#      claude does not override it; only a later session_start clears it. session_end with reason prompt_input_exit,
#      clear or logout is a deliberate end too. For a deliberate or closed session every not-yet-injected record is
#      cancelled (reason deliberate_end), whichever detector made it.
#   2. Derive OPEN WORK from the transcript tail: the last meaningful record is not a clean turn close and not an
#      interrupt marker (a synthetic error counts as open work even with a turn_duration after it, but the scan owns
#      that scope, so liveness adds nothing there), or an unfinished non-interrupted agent / workflow (S5 inventory).
#   3. Look for POSITIVE evidence of death, never mere silence: the registry claude_pid is gone or alive with a
#      different start time (pid reuse); or, with no pid facts, the pane bound by @borg_sid is at a shell. Unknown
#      (no facts, tmux answers nothing, conflicting panes) creates nothing. Container sessions are checked with a
#      docker ps (BORG_RESUME_DOCKER_CMD stub): container gone is notify-only, docker unreachable or unhealthy defers.
#   4. Create ONE record per (session, scope) through the watcher's own _rw_ingest, so the evidence-uuid idempotency
#      key holds. Dead plus open work is class process_death, resume_at = now + BORG_RESUME_LIVENESS_GRACE_SEC (300),
#      with an early notice (outbox line in notify.jsonl) carrying the cancel hint at minute 0. Causes: crash (pane
#      at a shell), pane_closed (D4), reboot (D1: staged BORG_RESUME_REBOOT_PER_HOUR=3 per hour, orchestrator first,
#      record and schedule only), tmux_down and container_down (notify_only). A session that is alive again before
#      its liveness-only record fires cancels it (reason recovered).
#   5. Workflows: manifest without result, journal `started` without `result`, journal idle
#      BORG_RESUME_WF_IDLE_SEC (300) with an owner proven dead -> workflow:<run> record; or the owner's transcript
#      ends in a rate_limit synthetic error -> a workflow:<run> usage_limit record (resume at the reset).
#   6. Stall watchdog (directive step 6): a `confirmed` record whose transcript has not grown for
#      BORG_RESUME_STALL_MIN (10) minutes and either a permission_prompt event arrived after confirmation or the
#      pane classifies as a dialog becomes `stalled` (terminal) with a notice naming the window.
#
# Notices are appended to $(borg_resume_dir)/notify.jsonl (an outbox; delivery is the gate/notifier slice, not here).
# Not here: relaunch (S11), the gate and injection (S9), launchd (S12).
#
# Env stubs for tests: BORG_RESUME_PANES_CMD (list-panes lines), BORG_RESUME_TMUX_CMD, BORG_RESUME_DOCKER_CMD,
# BORG_RESUME_BOOT_EPOCH. Tuning: BORG_RESUME_LIVENESS_GRACE_SEC, BORG_RESUME_REBOOT_PER_HOUR, BORG_RESUME_WF_IDLE_SEC,
# BORG_RESUME_STALL_MIN, BORG_RESUME_DOCKER_TIMEOUT_SEC (8).

# shellcheck disable=SC2016,SC2154
_RL_SHELL_RE='^-?(zsh|bash|sh|fish|dash|ksh|tcsh)$'
_rl_panes_loaded=0
_rl_panes_rc=1
_rl_panes_out=""
_rl_dk_loaded=0
_rl_dk_rc=1
_rl_dk_out=""
_rl_reboot_new=0

_rl_log() { _rw_log "liveness: $*"; }

_rl_int() { # <value> <default>
    case "$1" in "" | *[!0-9]*) printf '%s\n' "$2" ;; *) printf '%s\n' "$1" ;; esac
}

_rl_norm() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# Append one notice to the outbox. Usage: _rl_notify <kind> <sid> <rid> <message>
_rl_notify() {
    local _reg _proj _win _line
    _reg="$(borg_resume_registry_file "$2")"
    _proj="" _win=""
    if [ -f "$_reg" ]; then
        _proj="$(jq -r '.project // empty' "$_reg" 2>/dev/null)"
        _win="$(jq -r '.tmux.window // empty' "$_reg" 2>/dev/null)"
    fi
    _line="$(jq -n -c --argjson t "$(_rc_now)" --arg kind "$1" --arg sid "$2" --arg rid "$3" --arg p "$_proj" \
        --arg w "$_win" --arg m "${4:0:500}" \
        '{t: $t, kind: $kind, sid: $sid, rid: $rid, project: $p, window: $w, msg: $m}' 2>/dev/null)"
    [ -n "$_line" ] && borg_resume_append_line "$(borg_resume_dir)/notify.jsonl" "$_line"
    return 0
}

# ---------------------------------------------------------------------------------------------
# end state (deliberate ends, sticky close)
# ---------------------------------------------------------------------------------------------

# Prints open | deliberate | closed. Events are folded in file order.
_rl_end_state() {
    local _ef _out
    _ef="$(borg_resume_events_file "$1")"
    [ -f "$_ef" ] || { printf 'open\n'; return 0; }
    _out="$(jq -R -n -r 'reduce (inputs | fromjson? | select(type == "object")) as $e ("open";
        if $e.ev == "session_start" then "open"
        elif $e.ev == "session_end" then
            (if $e.via == "mark_closed" then "closed"
             elif . == "closed" then "closed"
             elif ($e.reason | IN("prompt_input_exit", "clear", "logout")) then "deliberate"
             else . end)
        else . end)' "$_ef" 2>/dev/null)"
    printf '%s\n' "${_out:-open}"
}

# Cancel every not-yet-injected record of a session that ended deliberately.
_rl_cancel_ended() {
    local _sid="$1" _f _now
    _now="$(_rc_now)"
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r --arg s "$_sid" 'select(.sid == $s and (.state | IN("new", "scheduled", "deferred"))) | .rid' \
            "$_f" 2>/dev/null)" ] || continue
        _rw_update "$_f" --argjson now "$_now" '.state = "cancelled" | .reason = "deliberate_end"
            | .state_log += [["cancelled", $now, "deliberate_end"]]' || continue
        _rw_n_closed=$((_rw_n_closed + 1))
        _rl_log "cancelled ${_f##*/} (deliberate end) sid=$_sid"
    done
    return 0
}

# Cancel liveness-only records of a session that turned out to be alive (recovered inside the grace).
_rl_cancel_recovered() {
    local _sid="$1" _f _now
    _now="$(_rc_now)"
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r --arg s "$_sid" 'select(.sid == $s and (.state | IN("new", "scheduled", "deferred"))
            and (.detected_by == ["liveness"])) | .rid' "$_f" 2>/dev/null)" ] || continue
        _rw_update "$_f" --argjson now "$_now" '.state = "cancelled" | .reason = "recovered"
            | .state_log += [["cancelled", $now, "recovered"]]' || continue
        _rw_n_closed=$((_rw_n_closed + 1))
        _rl_log "cancelled ${_f##*/} (session alive again) sid=$_sid"
    done
    return 0
}

_rl_has_liveness_record() {
    local _f
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r --arg s "$1" 'select(.sid == $s and (.state | IN("new", "scheduled", "deferred"))
            and (.detected_by == ["liveness"])) | .rid' "$_f" 2>/dev/null)" ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------------------------
# open work
# ---------------------------------------------------------------------------------------------

# Tail state of a transcript: open | clean | interrupt | error | none.
# The synthetic-error test comes BEFORE the clean-close test: an error followed by a turn_duration is not clean.
_rl_tail_state() {
    local _out _flag _rec
    [ -f "$1" ] || { printf 'none\n'; return 0; }
    _out="$(resume_last_meaningful_with_close "$1" 60 2>/dev/null)"
    [ -n "$_out" ] || { printf 'none\n'; return 0; }
    _flag="${_out%%$'\t'*}"
    _rec="${_out#*$'\t'}"
    if [ -n "$(resume_synthetic_error "$_rec" 2>/dev/null)" ]; then
        printf 'error\n'
    elif resume_record_is_interrupt "$_rec"; then
        printf 'interrupt\n'
    elif [ "$_flag" = true ]; then
        printf 'clean\n'
    elif printf '%s' "$_rec" | jq -e '.type == "assistant"
        and ([.message.content[]? | select(type == "object" and .type == "tool_use")] | length == 0)
        and .message.stop_reason == "end_turn"' >/dev/null 2>&1; then
        printf 'clean\n'
    else
        printf 'open\n'
    fi
}

# ---------------------------------------------------------------------------------------------
# evidence: processes, panes, docker
# ---------------------------------------------------------------------------------------------

_rl_lstart_epoch() {
    local _s
    _s="$(_rl_norm "$1")"
    [ -n "$_s" ] || return 1
    LC_ALL=C date -j -f '%a %b %e %T %Y' "$_s" +%s 2>/dev/null || LC_ALL=C date -d "$_s" +%s 2>/dev/null
}

_rl_boot_epoch() {
    local _b
    if [ -n "${BORG_RESUME_BOOT_EPOCH:-}" ]; then
        printf '%s\n' "$BORG_RESUME_BOOT_EPOCH"
        return 0
    fi
    _b="$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*sec = \([0-9]*\).*/\1/p')"
    [ -n "$_b" ] || _b="$(date -d "$(uptime -s 2>/dev/null)" +%s 2>/dev/null)"
    [ -n "$_b" ] || return 1
    printf '%s\n' "$_b"
}

# Load `list-panes` once per pass. rc != 0 means tmux answered nothing (server down).
_rl_panes_load() {
    [ "$_rl_panes_loaded" = 1 ] && return 0
    _rl_panes_loaded=1
    if [ -n "${BORG_RESUME_PANES_CMD:-}" ]; then
        _rl_panes_out="$(bash -c "$BORG_RESUME_PANES_CMD" 2>/dev/null)"
        _rl_panes_rc=$?
    else
        _rl_panes_out="$(_bi_tmux list-panes -a \
            -F '#{pane_id}|#{@borg_sid}|#{pane_pid}|#{pane_current_command}' 2>/dev/null)"
        _rl_panes_rc=$?
    fi
    return 0
}

# Pane bound to <sid>: prints claude | shell | other | none | ambiguous.
_rl_pane_kind() {
    local _sid="$1" _re="${BORG_RESUME_PANE_CMD_RE:-$_BI_CMD_RE}" _id _bound _pid _cmd _kind="none" _n=0
    while IFS='|' read -r _id _bound _pid _cmd; do
        [ -n "$_id" ] && [ -n "$_bound" ] && [ "$_bound" = "$_sid" ] || continue
        _n=$((_n + 1))
        if [[ "$_cmd" =~ $_re ]]; then
            _kind=claude
        elif [[ "$_cmd" =~ $_RL_SHELL_RE ]]; then
            _kind=shell
        else
            _kind=other
        fi
    done <<EOF
$_rl_panes_out
EOF
    [ "$_n" -le 1 ] || _kind=ambiguous
    printf '%s\n' "$_kind"
}

# Run a shell command line with a timeout. Sets _rl_dk_out and _rl_dk_rc (124 on timeout).
_rl_docker_load() {
    local _cmd _t _tmp _pid _i=0 _max
    [ "$_rl_dk_loaded" = 1 ] && return 0
    _rl_dk_loaded=1
    _cmd="${BORG_RESUME_DOCKER_CMD:-docker ps --filter label=dev.role=app --format '{{.Names}}|{{.Status}}'}"
    _t="$(_rl_int "${BORG_RESUME_DOCKER_TIMEOUT_SEC:-}" 8)"
    _max=$((_t * 10))
    _tmp="$(mktemp "${TMPDIR:-/tmp}/borg-rl.XXXXXX")" || { _rl_dk_rc=1; return 0; }
    bash -c "$_cmd" >"$_tmp" 2>/dev/null &
    _pid=$!
    while kill -0 "$_pid" 2>/dev/null; do
        if [ "$_i" -ge "$_max" ]; then
            kill "$_pid" 2>/dev/null
            wait "$_pid" 2>/dev/null
            _rl_dk_rc=124
            _rl_dk_out=""
            rm -f "$_tmp"
            return 0
        fi
        sleep 0.1
        _i=$((_i + 1))
    done
    wait "$_pid"
    _rl_dk_rc=$?
    _rl_dk_out="$(cat "$_tmp" 2>/dev/null)"
    rm -f "$_tmp"
    return 0
}

# Verdict for a session: alive | unknown | dead <cause> | defer <why>.
# Usage: _rl_verdict <pid> <start> <in_container> <project> <sid> <has_tmux_fact>
_rl_verdict() {
    local _pid="$1" _start="$2" _cont="$3" _proj="$4" _sid="$5" _hastmux="$6" _live _boot _sepoch _pk _line _hit=""
    if [ "$_cont" = true ]; then
        [ -n "$_proj" ] || { printf 'unknown\n'; return 0; }
        _rl_docker_load
        [ "$_rl_dk_rc" -eq 0 ] || { printf 'defer docker_unreachable\n'; return 0; }
        while IFS= read -r _line; do
            case "$_line" in *"$_proj"*) _hit="$_line" ;; esac
        done <<EOF
$_rl_dk_out
EOF
        if [ -z "$_hit" ]; then
            printf 'dead container_down\n'
            return 0
        fi
        case "$_hit" in
            *[Uu]nhealthy* | *[Rr]estarting* | *[Pp]aused*) printf 'defer docker_unhealthy\n' ;;
            *) printf 'unknown\n' ;;
        esac
        return 0
    fi

    case "$_pid" in
        "" | *[!0-9]*) _pid="" ;;
        0) _pid="" ;;
    esac
    if [ -n "$_pid" ] && [ -n "$_start" ]; then
        _live="$(_rl_norm "$(LC_ALL=C ps -o lstart= -p "$_pid" 2>/dev/null)")"
        if [ -n "$_live" ] && [ "$_live" = "$(_rl_norm "$_start")" ]; then
            printf 'alive\n'
            return 0
        fi
        # Dead. Refine the cause: a boot after the process started is a reboot (D1).
        _boot="$(_rl_boot_epoch)" && _sepoch="$(_rl_lstart_epoch "$_start")" &&
            [ -n "$_boot" ] && [ -n "$_sepoch" ] && [ "$_boot" -gt "$_sepoch" ] && {
            printf 'dead reboot\n'
            return 0
        }
        _rl_panes_load
        if [ "$_rl_panes_rc" -ne 0 ]; then
            printf 'dead tmux_down\n'
            return 0
        fi
        _pk="$(_rl_pane_kind "$_sid")"
        case "$_pk" in
            shell) printf 'dead crash\n' ;;
            none) printf 'dead pane_closed\n' ;;
            *) printf 'unknown\n' ;;
        esac
        return 0
    fi

    # No pid facts: only a bound pane can speak, and only when tmux answers.
    [ "$_hastmux" = true ] || { printf 'unknown\n'; return 0; }
    _rl_panes_load
    [ "$_rl_panes_rc" -eq 0 ] || { printf 'unknown\n'; return 0; }
    _pk="$(_rl_pane_kind "$_sid")"
    case "$_pk" in
        claude) printf 'alive\n' ;;
        shell) printf 'dead crash\n' ;;
        *) printf 'unknown\n' ;;
    esac
}

# ---------------------------------------------------------------------------------------------
# record creation
# ---------------------------------------------------------------------------------------------

# Create (once) a record for (sid, scope) through the watcher's ingest and decorate it.
# Usage: _rl_create <sid> <scope> <cause> <error> <text> <uuid>
_rl_create() {
    local _sid="$1" _scope="$2" _cause="$3" _err="$4" _text="$5" _uuid="$6" _f _before _rid _ra _msg _proj
    _before="$_rw_n_created"
    _rw_ingest "$_sid" "$_scope" liveness "$_err" "$_text" "$_uuid" "" "$(_rc_now)"
    [ "$_rw_n_created" -gt "$_before" ] || return 0
    _f="$(_rw_find_uuid "$_uuid")" || return 0
    _rid="$(jq -r .rid "$_f")"
    _ra="$(jq -r '.resume_at // empty' "$_f")"
    _rw_update "$_f" --arg c "$_cause" '.cause = $c' || return 0
    _proj="$(jq -r '.project // empty' "$(borg_resume_registry_file "$_sid")" 2>/dev/null)"
    if [ "$(jq -r .action "$_f")" = notify ]; then
        _msg="borg-resume: session ${_proj:-$_sid} ended with open work ($_cause) and cannot be relaunched"
        _msg="$_msg automatically; resume it by hand: claude --resume $_sid"
    else
        _msg="borg-resume: session ${_proj:-$_sid} ended with open work ($_cause, scope $_scope); will relaunch"
        _msg="$_msg with --resume at epoch ${_ra:-?} unless cancelled. Cancel: borg-resume mark-closed ${_proj:-$_sid}"
    fi
    _rl_notify early_notice "$_sid" "$_rid" "$_msg"
    [ "$_cause" = reboot ] && _rl_reboot_new=1
    return 0
}

# Staged relaunch after a reboot (D1): schedule only. Unstaged reboot records get slots spaced 3600/N apart
# (N = BORG_RESUME_REBOOT_PER_HOUR, 3), orchestrator first, then oldest first_seen. The first slot is the grace.
_rl_stage_reboot() {
    local _n _space _now _last _ra _f _rid _sid _orch _k _list _first
    _n="$(_rl_int "${BORG_RESUME_REBOOT_PER_HOUR:-}" 3)"
    [ "$_n" -ge 1 ] || _n=3
    _space=$((3600 / _n))
    _now="$(_rc_now)"
    _list=""
    _last=""
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r 'select(.cause == "reboot" and (.state | IN("scheduled", "new"))) | .staged // false' "$_f" \
            2>/dev/null)" = false ] || {
            _ra="$(jq -r 'select(.cause == "reboot" and .staged == true) | .resume_at // empty' "$_f" 2>/dev/null)"
            [ -n "$_ra" ] && { [ -z "$_last" ] || [ "$_ra" -gt "$_last" ]; } && _last="$_ra"
            continue
        }
        _sid="$(jq -r .sid "$_f")"
        _orch=1
        [ "$(jq -r '.mode // empty' "$(borg_resume_registry_file "$_sid")" 2>/dev/null)" = orchestrator ] && _orch=0
        _list="${_list}${_orch} $(jq -r '.first_seen // 0' "$_f") ${_f}"$'\n'
    done
    [ -n "$_list" ] || return 0
    _first=$((_now + $(_rl_int "${BORG_RESUME_LIVENESS_GRACE_SEC:-}" 300)))
    _k=0
    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _f="${_f#* * }"
        if [ -n "$_last" ]; then
            _ra=$((_last + _space))
            [ "$_ra" -ge "$_first" ] || _ra="$_first"
        else
            _ra="$_first"
        fi
        _rw_update "$_f" --argjson ra "$_ra" --argjson k "$_k" '.resume_at = $ra | .staged = true | .stage_slot = $k' ||
            continue
        _rid="$(jq -r .rid "$_f")"
        _rl_log "staged $_rid resume_at=$_ra slot=$_k"
        _last="$_ra"
        _k=$((_k + 1))
    done <<EOF
$(printf '%s' "$_list" | sort -k1,1n -k2,2n)
EOF
    return 0
}

# ---------------------------------------------------------------------------------------------
# per-session logic
# ---------------------------------------------------------------------------------------------

_rl_death_uuid() { # <scope> <pid> <start> <sid>
    local _h
    _h="$(printf '%s|%s' "$3" "$4" | cksum | tr -d ' ')"
    printf 'pd:%s:%s:%s\n' "${1//[^A-Za-z0-9_:-]/_}" "$2" "$_h"
}

_rl_session() {
    local _sid="$1" _end _reg _facts _pid _start _cont _proj _hastmux _loc _t _sd _ts _verdict _cause _inv
    local _scopes="" _scope _f _aid _wid _status _runid _jr _jmt _now _idle _uuid _wf_dead _owner_err _se _txt _wfs
    _cause=""
    _end="$(_rl_end_state "$_sid")"
    if [ "$_end" != open ]; then
        _rl_cancel_ended "$_sid"
        return 0
    fi
    _reg="$(borg_resume_registry_file "$_sid")"
    _facts="$(jq -r --arg s "$_RW_SEP" '[(.claude_pid // "" | tostring), (.claude_start // ""),
        (.in_container // false | tostring), (.project // ""), (.tmux != null | tostring)] | join($s)' \
        "$_reg" 2>/dev/null)"
    [ -n "$_facts" ] || return 0
    IFS="$_RW_SEP" read -r _pid _start _cont _proj _hastmux <<EOF
$_facts
EOF
    _now="$(_rc_now)"
    _loc="$(_ri_locate "$_sid")"
    _t="${_loc%%$'\t'*}"
    _sd="${_loc#*$'\t'}"
    _ts="$(_rl_tail_state "$_t")"

    # Open work, main first; agents and workflows only when main is not itself open.
    case "$_ts" in
        open) _scopes="main" ;;
    esac
    _wfs=""
    if [ -n "$_sd" ]; then
        _inv="$(borg_resume_inventory "$_sid" 2>/dev/null)"
        if [ "$_ts" != open ]; then
            _scopes="$(printf '%s' "$_inv" | jq -r '.agents[]? | select(.status == "running" or .status == "orphaned")
                | "agent:" + .agent_id')"
        fi
        _wfs="$(printf '%s' "$_inv" | jq -r '.workflows[]? | select(.status == "partial" or .status == "unfinished")
            | .run_id + " " + .manifest_id')"
    fi
    if [ -z "$_scopes" ] && [ -z "$_wfs" ] && ! _rl_has_liveness_record "$_sid"; then
        return 0
    fi

    _verdict="$(_rl_verdict "$_pid" "$_start" "$_cont" "$_proj" "$_sid" "$_hastmux")"
    case "$_verdict" in
        alive)
            _rl_cancel_recovered "$_sid"
            ;;
        defer*)
            _rl_log "deferred sid=$_sid (${_verdict#defer })"
            _rw_state_ensure "$_sid"
            _rw_update "$(_rw_state_file "$_sid")" --arg w "${_verdict#defer }" --argjson n "$_now" \
                '.liveness_deferred = {why: $w, at: $n}'
            return 0
            ;;
    esac

    if [ "${_verdict%% *}" = dead ]; then
        _cause="${_verdict#dead }"
        for _scope in $_scopes; do
            _uuid="$(_rl_death_uuid "$_scope" "$_pid" "$_start" "$_sid")"
            if [ "$_cause" = tmux_down ] || [ "$_cause" = container_down ]; then
                _rl_create "$_sid" "$_scope" "$_cause" "$_cause" "$_cause" "$_uuid"
            else
                _rl_create "$_sid" "$_scope" "$_cause" process_death "$_cause" "$_uuid"
            fi
        done
    fi

    # Workflows. Skipped for process death when main is already being relaunched (it resumes them).
    [ -n "$_wfs" ] || return 0
    _owner_err=""
    if [ "$_ts" = error ]; then
        _se="$(resume_last_meaningful_with_close "$_t" 60 2>/dev/null)"
        _se="$(resume_synthetic_error "${_se#*$'\t'}" 2>/dev/null)"
        [ "${_se%%$'\t'*}" = rate_limit ] && _owner_err="$_se"
    fi
    while IFS=' ' read -r _runid _wid; do
        [ -n "$_runid" ] || continue
        _jr="$_sd/subagents/workflows/$_wid/journal.jsonl"
        _jmt=0
        [ -f "$_jr" ] && _jmt="$(_ri_mtime "$_jr")"
        _idle=$((_now - _jmt))
        if [ -n "$_owner_err" ]; then
            _txt="${_owner_err#*$'\t'}"
            _txt="${_txt%$'\t'*}"
            _rl_create "$_sid" "workflow:$_runid" owner_limit rate_limit "$_txt" "wfl:$_runid:$_jmt"
        elif [ "${_verdict%% *}" = dead ] && [ "$_cause" != tmux_down ] && [ "$_cause" != container_down ] &&
            [ "$_idle" -ge "$(_rl_int "${BORG_RESUME_WF_IDLE_SEC:-}" 300)" ] && [ "$_ts" != open ]; then
            _uuid="$(_rl_death_uuid "workflow:$_runid" "$_pid" "$_start" "$_sid")"
            _rl_create "$_sid" "workflow:$_runid" "workflow_killed:$_cause" process_death "$_cause" "$_uuid"
        fi
    done <<EOF
$_wfs
EOF
    return 0
}

# ---------------------------------------------------------------------------------------------
# stall watchdog
# ---------------------------------------------------------------------------------------------

_rl_stall_pass() {
    local _f _sid _scope _at _cl _now _stall _loc _t _sd _file _lines _mt _pe _pane _pid _st _rid _win _why _sf
    _now="$(_rc_now)"
    _stall=$(($(_rl_int "${BORG_RESUME_STALL_MIN:-}" 10) * 60))
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r .state "$_f" 2>/dev/null)" = confirmed ] || continue
        _rid="$(jq -r .rid "$_f")"
        _sid="$(jq -r .sid "$_f")"
        _scope="$(jq -r .scope "$_f")"
        _at="$(jq -r '.confirmed_at // empty' "$_f")"
        case "$_at" in "" | *[!0-9]*) continue ;; esac
        [ $((_now - _at)) -ge "$_stall" ] || continue
        _loc="$(_ri_locate "$_sid")"
        _t="${_loc%%$'\t'*}"
        _sd="${_loc#*$'\t'}"
        _file="$_t"
        case "$_scope" in
            agent:*) _file="$_sd/subagents/agent-${_scope#agent:}.jsonl" ;;
        esac
        [ -f "$_file" ] || continue
        _mt="$(_ri_mtime "$_file")"
        [ $((_now - _mt)) -ge "$_stall" ] || continue
        _cl="$(jq -r '.confirmed_lines // empty' "$_f")"
        _lines="$(wc -l <"$_file" | tr -d ' ')"
        case "$_cl" in "" | *[!0-9]*) ;; *) [ "$_lines" -gt "$_cl" ] && continue ;; esac
        _rw_has_ack "$_sid" "$_rid" "$_at" && continue
        _why=""
        _pe="$(borg_resume_events_file "$_sid")"
        if [ -f "$_pe" ] && jq -e -R -n --argjson a "$_at" '[inputs | fromjson? | select(type == "object"
            and .ev == "permission_prompt" and (.t // 0) >= $a)] | length > 0' "$_pe" >/dev/null 2>&1; then
            _why="permission_prompt"
        else
            _rl_panes_load
            _pane="$(borg_inject_find_pane "$_sid" 2>/dev/null)" && {
                _pid="${_pane%%|*}"
                _st="$(borg_inject_pane_state "$_pid" 2>/dev/null)"
                [ "$_st" = dialog ] && _why="dialog"
            }
        fi
        [ -n "$_why" ] || continue
        _rw_update "$_f" --argjson now "$_now" --arg w "$_why" '.state = "stalled" | .done_reason = $w
            | .state_log += [["stalled", $now, $w]]' || continue
        _win="$(jq -r '.tmux.window // empty' "$(borg_resume_registry_file "$_sid")" 2>/dev/null)"
        _rl_notify stalled "$_sid" "$_rid" \
            "borg-resume: resume $_rid is stalled (${_why}); the session is waiting on you in window ${_win:-unknown}"
        _sf="$(_rw_state_file "$_sid")"
        [ -f "$_sf" ] && _rw_update "$_sf" '.consecutive += 1'
        _rl_log "stalled $_rid reason=$_why"
    done
    return 0
}

# ---------------------------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------------------------

borg_resume_liveness_pass() {
    local _d _f _sid _hours _cut
    command -v jq >/dev/null 2>&1 || return 0
    borg_resume_disabled_env && return 0
    if ! declare -F _bi_tmux >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        . "${BORG_RESUME_LIBDIR:?}/inject.sh" 2>/dev/null || return 0
    fi
    _rl_panes_loaded=0 _rl_dk_loaded=0 _rl_reboot_new=0
    _d="$(borg_resume_dir)"
    _hours="$(_rl_int "${BORG_RESUME_SCAN_HOURS:-}" 72)"
    _cut=$(($(_rc_now) - _hours * 3600))
    for _f in "$_d"/sessions/*.json; do
        [ -f "$_f" ] || continue
        _sid="${_f##*/}"
        _sid="${_sid%.json}"
        borg_resume_valid_sid "$_sid" || continue
        [ "$(_ri_mtime "$_f")" -ge "$_cut" ] || continue
        _rl_session "$_sid"
    done
    _rl_stage_reboot
    _rl_stall_pass
    return 0
}
