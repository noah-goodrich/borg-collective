#!/usr/bin/env bash
# resume-relaunch.sh -- relaunch of a dead session and the resume dialog, for borg-resume (slice S11).
#
# Sourced by lib/borg/resume-gate.sh. Bash 3.2 safe, jq required, functions only; sourcing prints nothing.
#
#   borg_resume_relaunch_group <sid>   reached from the S9 gate via borg_resume_relaunch_hook (a process_death record
#                                      is handed over in the dispatch step), AFTER every gate check (supersede, age,
#                                      caps, concurrency, headroom, dispatch guard) and BEFORE the prompt is rendered.
#                                      Return 0 = the session is alive and verified, go on with the normal flow
#                                      (render + S8 injection). Return 1 = this slice handled the group (deferred,
#                                      notify_only, cancelled).
#
# It acts only for records whose cause is a dead process: crash, pane_closed, reboot (and workflow_killed:<those>),
# which S10 recorded. It never relaunches a deliberate stop (S10 end state closed/deliberate, trailing interrupt
# marker). Container sessions never get here (the gate makes them notify-only; U9 container identity is unproven).
#
# Launch (host sessions only; never builds a shell string from transcript or payload text):
#   - the sid must match the UUID regex; the cwd must be an existing directory, free of control characters, that is a
#     registered repository dir, a known git worktree of it, or under BORG_RESUME_CWD_ALLOW (colon list, default
#     $HOME/dev); anything else is notify_only
#   - pane gone, tmux up:    tmux new-window -d -P -- <login-shell> -l -c "exec \"$@\"" borg-resume <claude>
#                            --resume <sid>
#                            (argv form; the login shell gives claude the user env, which a tmux server started from
#                            launchd lacks. zsh -l reads .zprofile/.zshenv, NOT .zshrc: exports living only in .zshrc
#                            are not seen. The server-global env of a launchd-started server stays minimal; both are
#                            S16 smoke-test items.)
#   - tmux server gone:      tmux new-session -d ... (same argv form)
#   - pane alive at a shell: NOTHING is typed into it (an empty prompt cannot be proven from a capture). A new window
#                            is opened and the old shell pane is unbound from the sid.
#   The claude binary is the absolute path from lib/borg/claude-bin.sh. cwd, window and session names containing #
#   are rejected or neutralised (tmux expands formats in -c/-n/-s).
# After launch the new pane gets @borg_sid=<sid> and the screen is polled BEFORE anything else happens:
#   - resume-size dialog (U17 UNCAPTURED, fixture is synthetic): notify_only with the exact manual command by default.
#     BORG_RESUME_ANSWER_SIZE_DIALOG=1 opts in to answering it with the FULL-session option (D11): the digit alone
#     when the option is not highlighted, or Enter alone when it already is. Never a digit followed by Enter; a dialog
#     still showing afterwards is notify_only. Do not enable until a real capture replaces the fixture.
#   - trust-folder prompt, permission prompt, any other dialog, or a screen that never settles: notify_only, the pane
#     is left for the human, nothing is typed
#   - verified = a session_start event with source resume arrived for the SAME sid after the launch AND the pane is
#     still bound to that sid. A pane re-bound to a different session id means the session forked: failure
#     (notify_only, the new id is recorded as forked_to). Deviation from the directive's "switch to the manifest
#     script path": the slice brief treats a different id as failure.
# Only a verified session continues to the gate's normal flow; this file never injects a prompt.
#
# Caps: BORG_RESUME_MAX_RELAUNCH_PER_HOUR (3, orchestrator first through the gate's ordering); every relaunch also
# counts against the S9 session counters (consecutive, injections_today); concurrency was checked by the gate.
# A verified relaunch bumps those counters twice (here, then in the gate injection): deliberately conservative.
#
# Env: BORG_RESUME_RELAUNCH_TRIES (45) x BORG_RESUME_RELAUNCH_POLL_SEC (2) is the verification window (90s);
# BORG_RESUME_CWD_ALLOW; tests use BORG_RESUME_TMUX_CMD and BORG_CLAUDE_BIN.

# shellcheck disable=SC2016
_RR_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=/dev/null
command -v borg_resolve_claude_bin >/dev/null 2>&1 || . "$_RR_DIR/claude-bin.sh" 2>/dev/null

_RR_UUID_RE='^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'
_RR_FULL_RE='^[[:space:]]*(❯)?[[:space:]]*([0-9]+)\.[[:space:]]+Resume[[:space:]]full[[:space:]]session'
_rr_pane=""
_rr_fork=""
_rr_res=""

_rr_log() { _rw_log "relaunch: $*"; }

_rr_int() { # <value> <default>
    case "$1" in "" | *[!0-9]*) printf '%s\n' "$2" ;; *) printf '%s\n' "$1" ;; esac
}

# Does this record cause call for a relaunch?
_rr_cause_applies() {
    case "${1#workflow_killed:}" in crash | pane_closed | reboot) return 0 ;; esac
    return 1
}

_rr_cwd_ok() { # <cwd> <registry-file>
    local _cwd="$1" _reg="$2" _a _allow _pd
    [ -n "$_cwd" ] && [ -d "$_cwd" ] || return 1
    case "$_cwd" in /*) ;; *) return 1 ;; esac
    case "$_cwd" in *\#* | *[[:cntrl:]]* | */../* | */.. ) return 1 ;; esac
    _allow="${BORG_RESUME_CWD_ALLOW:-${HOME:-/nonexistent}/dev}"
    local _ifs="$IFS"
    IFS=:
    for _a in $_allow; do
        IFS="$_ifs"
        [ -n "$_a" ] || continue
        case "$_cwd" in "$_a" | "$_a"/*) return 0 ;; esac
    done
    IFS="$_ifs"
    _pd="$(jq -r '.tmux.project_dir // empty' "$_reg" 2>/dev/null)"
    if [ -n "$_pd" ]; then
        [ "$_cwd" = "$_pd" ] && return 0
        git -C "$_pd" worktree list --porcelain 2>/dev/null | grep -Fxq -- "worktree $_cwd" && return 0
    fi
    return 1
}

# Relaunches inside the last hour. Prints the count; _rr_oldest holds the oldest epoch among them.
_rr_oldest=0
_rr_recent_n=0
_rr_recent() {
    local _f _now _n=0 _t _s
    _f="$(borg_resume_dir)/relaunch.log"
    _now="$(_bi_now)"
    _rr_oldest=0
    _rr_recent_n=0
    [ -f "$_f" ] || return 0
    while read -r _t _s; do
        case "$_t" in "" | *[!0-9]*) continue ;; esac
        [ $((_now - _t)) -lt 3600 ] || continue
        [ "$_rr_oldest" -ne 0 ] && [ "$_rr_oldest" -le "$_t" ] || _rr_oldest="$_t"
        _n=$((_n + 1))
    done <"$_f"
    _rr_recent_n="$_n"
}

_rr_ledger() { # <sid>
    local _f
    _f="$(borg_resume_dir)/relaunch.log"
    borg_resume_append_line "$_f" "$(_bi_now) $1"
    if [ "$(wc -l <"$_f" | tr -d ' ')" -gt 400 ]; then
        tail -n 200 "$_f" >"$_f.trim.$$" 2>/dev/null && mv -f "$_f.trim.$$" "$_f"
    fi
    return 0
}

# Panes bound to <sid>: sets _rr_n and _rr_kind (claude | shell | other), _rr_pane (id of the last one).
_rr_n=0
_rr_kind=none
_rr_find() {
    local _sid="$1" _id _bound _pid _cmd _re="${BORG_RESUME_PANE_CMD_RE:-$_BI_CMD_RE}"
    _rr_n=0 _rr_kind=none _rr_pane=""
    while IFS='|' read -r _id _bound _pid _cmd; do
        [ -n "$_id" ] && [ -n "$_bound" ] && [ "$_bound" = "$_sid" ] || continue
        _rr_n=$((_rr_n + 1))
        _rr_pane="$_id"
        if [[ "$_cmd" =~ $_re ]]; then
            _rr_kind=claude
        elif [[ "$_cmd" =~ $_RL_SHELL_RE ]]; then
            _rr_kind=shell
        else
            _rr_kind=other
        fi
    done <<EOF
$(_bi_list_panes)
EOF
}

# The sid a pane is bound to right now (empty when none).
_rr_bound() { # <pane-id>
    local _id _bound _pid _cmd
    while IFS='|' read -r _id _bound _pid _cmd; do
        [ "$_id" = "$1" ] && { printf '%s' "$_bound"; return 0; }
    done <<EOF
$(_bi_list_panes)
EOF
    return 1
}

_rr_started() { # <sid> <since>: a session_start with source resume at or after <since>
    local _ef
    _ef="$(borg_resume_events_file "$1")"
    [ -f "$_ef" ] || return 1
    jq -R -n -e --argjson s "$2" '[inputs | fromjson? | select(type == "object" and .ev == "session_start"
        and .reason == "resume" and (.t // 0) >= $s)] | length > 0' "$_ef" >/dev/null 2>&1
}

# Handled-outcome helpers (all operate on the current group).
_rr_notify_only() { # <reason> <message>
    _rg_each _rg_to notify_only "$1"
    _rg_note "$(_rg_lead)" relaunch "$2"
    _rr_log "notify_only $1 sid=$_rr_sid"
}

_rr_sid=""
_rr_cmdline="" # exact manual command, set by borg_resume_relaunch_group

# Recognize the resume-size dialog and answer it with the FULL-session option. 0 answered, 1 not recognized.
_rr_answer_size() { # <pane> <capture>
    local _cap="$2" _line _num="" _cur=0 _n=0
    case "$_cap" in *"Resuming the full session"*) ;; *) return 1 ;; esac
    while IFS= read -r _line; do
        if [[ "$_line" =~ $_RR_FULL_RE ]]; then
            _n=$((_n + 1))
            _num="${BASH_REMATCH[2]}"
            _cur=0
            [ -n "${BASH_REMATCH[1]}" ] && _cur=1
        fi
    done <<EOF
$_cap
EOF
    [ "$_n" -eq 1 ] && [ -n "$_num" ] || return 1
    if [ "$_cur" -eq 1 ]; then
        _bi_sendkeys -t "$1" Enter >/dev/null 2>&1 || true
    else
        _bi_sendkeys -t "$1" -l "$_num" >/dev/null 2>&1 || true
    fi
    return 0
}

# Poll the new pane until the session is verified or a stop condition. Echoes ok | <reason>.
_rr_watch() { # <sid> <pane> <since>
    local _sid="$1" _pane="$2" _since="$3" _tries _poll _i=0 _cap _st _answered=0 _b
    _tries="$(_rr_int "${BORG_RESUME_RELAUNCH_TRIES:-}" 45)"
    _poll="$(_rr_int "${BORG_RESUME_RELAUNCH_POLL_SEC:-}" 2)"
    _rr_fork=""
    while [ "$_i" -lt "$_tries" ]; do
        _i=$((_i + 1))
        _b="$(_rr_bound "$_pane")" || { _rr_res=pane_exited; return 0; }
        if [ -n "$_b" ] && [ "$_b" != "$_sid" ]; then
            _rr_fork="$_b"
            _rr_res=forked
            return 0
        fi
        _cap="$(_bi_tmux capture-pane -p -t "$_pane" 2>/dev/null)" || _cap=""
        _st="$(printf '%s\n' "$_cap" | borg_inject_classify_text)"
        if [ "$_st" = dialog ]; then
            case "$_cap" in
                *"trust this folder"* | *"Accessing workspace"*) _rr_res=trust_prompt; return 0 ;;
                *"Resuming the full session"*)
                    [ "${BORG_RESUME_ANSWER_SIZE_DIALOG:-0}" = 1 ] || { _rr_res=resume_size_dialog; return 0; }
                    [ "$_answered" -eq 0 ] || { _rr_res=resume_dialog_stuck; return 0; }
                    _rr_answer_size "$_pane" "$_cap" || { _rr_res=unrecognized_dialog; return 0; }
                    _answered=1
                    ;;
                *"Do you want to "* | *"Would you like to proceed"* | *"What do you want to do?"*)
                    _rr_res=permission_prompt
                    return 0
                    ;;
                *) _rr_res=unrecognized_dialog; return 0 ;;
            esac
        elif _rr_started "$_sid" "$_since"; then
            _rr_res=ok
            return 0
        fi
        [ "$_poll" -gt 0 ] && sleep "$_poll"
    done
    _rr_res=no_verification
}

# The shell that wraps claude so it runs with the user's login environment (a tmux server started from launchd has a
# minimal one). Only zsh and bash, whose `-l -c 'exec "$@"'` form is known to work; anything else falls back.
_rr_login_shell() {
    local _s
    for _s in "${BORG_RESUME_LOGIN_SHELL:-}" "${SHELL:-}" /bin/zsh /bin/bash; do
        case "$_s" in /*) ;; *) continue ;; esac
        case "${_s##*/}" in zsh | bash) [ -x "$_s" ] && { printf '%s' "$_s"; return 0; } ;; esac
    done
    return 1
}

# Start claude in a NEW window or session, never by typing into an existing pane (a shell prompt cannot be proven
# empty from a screen capture). Sets _rr_pane. Returns 0 started, 1 failed.
_rr_launch() { # <sid> <cwd> <claude-bin> <name> <session>
    local _sid="$1" _cwd="$2" _bin="$3" _name="$4" _sess="$5" _out _sh
    local -a _argv
    _argv=("$_bin" --resume "$_sid")
    if _sh="$(_rr_login_shell)"; then
        _argv=("$_sh" -l -c 'exec "$@"' borg-resume "$_bin" --resume "$_sid")
    fi
    if _bi_tmux list-panes -a -F '#{pane_id}' >/dev/null 2>&1 &&
        _bi_tmux has-session -t "=$_sess" >/dev/null 2>&1; then
        _out="$(_bi_tmux new-window -d -P -F '#{pane_id}' -t "=$_sess:" -c "$_cwd" -n "$_name" -- \
            "${_argv[@]}" 2>/dev/null)" || return 1
    else
        _out="$(_bi_tmux new-session -d -P -F '#{pane_id}' -s "$_sess" -c "$_cwd" -n "$_name" -- \
            "${_argv[@]}" 2>/dev/null)" || return 1
    fi
    _out="${_out%%$'\n'*}"
    case "$_out" in %[0-9]*) ;; *) return 1 ;; esac
    _rr_pane="$_out"
    return 0
}

borg_resume_relaunch_group() {
    local _sid="$1" _f _cause="" _c _reg _cwd _proj _name _sess _old _recent _since _res _fb _cap
    local _lead _lrid _t _loc
    # Does any record of the group call for a relaunch?
    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _c="$(jq -r '.cause // empty' "$_f" 2>/dev/null)"
        _rr_cause_applies "$_c" && { _cause="$_c"; break; }
    done <<EOF
$_RG_GROUP
EOF
    [ -n "$_cause" ] || return 0
    _lead="$(_rg_lead)"
    _lrid="$(jq -r .rid "$_lead")"
    _rr_sid="$_sid"
    _reg="$(borg_resume_registry_file "$_sid")"

    # Deliberate stops are never relaunched. Fail closed when the S10 helpers are missing.
    if ! declare -F _rl_end_state >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        . "${BORG_RESUME_LIBDIR:-$_RR_DIR}/resume-liveness.sh" 2>/dev/null
    fi
    if ! declare -F _rl_end_state >/dev/null 2>&1 || ! declare -F _rl_tail_state >/dev/null 2>&1; then
        _rg_each _rg_defer relaunch_unavailable
        return 1
    fi
    if [ "$(_rl_end_state "$_sid")" != open ]; then
        _rg_each _rg_to cancelled deliberate_end
        return 1
    fi
    _loc="$(_ri_locate "$_sid")"
    _t="${_loc%%$'\t'*}"
    if [ "$(_rl_tail_state "$_t")" = interrupt ]; then
        _rg_each _rg_to cancelled interrupted_by_user
        return 1
    fi

    # Alive and owned: nothing to relaunch, the normal flow (and its pane proof) takes over.
    _rr_find "$_sid"
    if [ "$_rr_kind" = claude ] && [ "$_rr_n" -eq 1 ]; then
        borg_inject_owner_check "$_sid" "$(_bi_list_panes | awk -F'|' -v p="$_rr_pane" '$1 == p {print $3}')" \
            >/dev/null 2>&1 && return 0
    fi

    # Validation. The exact manual command is built with %q and never executed by us.
    _cwd="$(jq -r '.cwd // empty' "$_reg" 2>/dev/null)"
    printf -v _rr_cmdline 'cd %q && claude --resume %q' "${_cwd:-.}" "$_sid"
    if [[ ! "$_sid" =~ $_RR_UUID_RE ]]; then
        _rr_notify_only bad_sid "Cannot relaunch $_lrid automatically (unexpected session id). By hand: $_rr_cmdline"
        return 1
    fi
    if [ "$(jq -r '.in_container // false' "$_reg" 2>/dev/null)" = true ]; then
        _proj="$(jq -r '.project // empty' "$_reg" 2>/dev/null)"
        _rr_notify_only container_session "Container session $_lrid: drone up ${_proj:-<repository>} --resume $_sid"
        return 1
    fi
    if ! _rr_cwd_ok "$_cwd" "$_reg"; then
        _rr_notify_only bad_cwd "Cannot relaunch $_lrid automatically (directory not allowed). By hand: $_rr_cmdline"
        return 1
    fi
    case "$_rr_kind:$_rr_n" in
        claude:* | other:* | *:[2-9]*)
            _rr_notify_only pane_occupied "A pane for $_lrid is still in use; left alone. By hand: $_rr_cmdline"
            return 1
            ;;
    esac
    if ! borg_resolve_claude_bin; then
        _rr_notify_only no_claude "Cannot find the claude binary to relaunch $_lrid. By hand: $_rr_cmdline"
        return 1
    fi

    # Hourly cap (D1). Orchestrator first comes from the gate's ordering of due records.
    _rr_recent
    _recent="$_rr_recent_n"
    if [ "$_recent" -ge "$(_rr_int "${BORG_RESUME_MAX_RELAUNCH_PER_HOUR:-}" 3)" ]; then
        _rg_each _rg_defer relaunch_cap $((_rr_oldest + 3600))
        _rr_log "hourly cap ($_recent) sid=$_sid"
        return 1
    fi

    _proj="$(jq -r '.project // empty' "$_reg" 2>/dev/null)"
    _name="$(jq -r '.tmux.window // .project // empty' "$_reg" 2>/dev/null)"
    _sess="$(jq -r '.tmux.session // empty' "$_reg" 2>/dev/null)"
    [ -n "$_name" ] || _name="${_sid:0:8}"
    [ -n "$_sess" ] || _sess=borg
    _name="${_name//\#/_}"
    _sess="${_sess//\#/_}"
    _old=""
    [ "$_rr_kind" = shell ] && _old="$_rr_pane"
    _since="$(_bi_now)"
    if ! _rr_launch "$_sid" "$_cwd" "$BORG_CLAUDE_BIN" "$_name" "$_sess"; then
        _rr_notify_only launch_failed "Relaunch of $_lrid failed to start. By hand: $_rr_cmdline"
        return 1
    fi
    # The dead session's old shell pane (if any) stops claiming the sid; the new window owns it.
    [ -z "$_old" ] || _bi_tmux set-option -p -u -t "$_old" @borg_sid >/dev/null 2>&1
    # Counted from here on, whatever happens next: a relaunch is an expensive resume.
    _rr_ledger "$_sid"
    _rw_state_ensure "$_sid"
    _rw_update "$(_rw_state_file "$_sid")" '.injections_today += 1 | .resumed_total += 1 | .consecutive += 1'
    # Bind the pane unless the SessionStart hook already did (it may even have bound a forked id: never overwrite).
    _fb="$(_rr_bound "$_rr_pane")" || _fb=""
    [ -n "$_fb" ] || _bi_tmux set-option -p -t "$_rr_pane" @borg_sid "$_sid" >/dev/null 2>&1

    _rr_watch "$_sid" "$_rr_pane" "$_since"
    _res="$_rr_res"
    if [ "$_res" = ok ]; then
        _rw_update "$_lead" --argjson now "$(_rc_now)" --arg p "$_rr_pane" --arg c "$_cause" \
            '.relaunch = {at: $now, pane: $p, cause: $c}'
        _rr_log "relaunched sid=$_sid pane=$_rr_pane cause=$_cause"
        return 0
    fi
    _fb=""
    [ -n "$_rr_fork" ] && _fb=" (it forked to session $_rr_fork)"
    [ -n "$_rr_fork" ] && _rw_update "$_lead" --arg n "$_rr_fork" '.forked_to = $n'
    _cap="Relaunched $_lrid but could not verify the same session: $_res$_fb. Pane left for you. By hand: $_rr_cmdline"
    _rr_notify_only "relaunch_$_res" "$_cap"
    return 1
}

# Gate hook (RECONCILE-6): called by _rg_dispatch_dead <rid> <cause> <file> for ONE process_death record, only from
# _rg_run_group and only after every gate passed. Returns 0 when this path took ownership of the record (relaunched and
# verified -> relaunching, or handled: notify_only, cancelled, deferred with _RR_DEFERRED=1), 1 when it does not apply
# (the gate then defers the record with no_pane). The relaunch bumps the S9 counters once (a second tick comes with
# the injection).
_RR_DEFERRED=0
borg_resume_relaunch_hook() { # <rid> <cause> <file>
    local _rid="$1" _cause="$2" _f="$3" _saved="${_RG_GROUP:-}" _rc _st
    _RR_DEFERRED=0
    _rr_cause_applies "$_cause" || return 1
    [ -f "$_f" ] || return 1
    _RG_GROUP="$_f"
    borg_resume_relaunch_group "$(jq -r .sid "$_f" 2>/dev/null)"
    _rc=$?
    _RG_GROUP="$_saved"
    _st="$(jq -r .state "$_f" 2>/dev/null)"
    if [ "$_rc" -eq 0 ]; then
        _rg_to "$_f" relaunching relaunched
    elif [ "$_st" = deferred ]; then
        _RR_DEFERRED=1
    fi
    return 0
}

# ---------------------------------------------------------------------------------------------
# S16: hand a relaunched session on to the normal gate flow.
#
# The relaunch hook leaves a record in `relaunching` after a VERIFIED same-session relaunch, and nothing else ever moved
# it: the revived claude sat at an empty composer with no prompt and the record was stuck. This pass, called at the top
# of the gate's due pass, flips every `relaunching` record of a session whose pane is now proven alive and owned back to
# `scheduled` (due now, `relaunched: true`). The gate then treats it like any other record: the dead-owner dispatch
# skips it, the S6 prompt is rendered and borg_inject_line (full pane proof) types it. The relaunch already bumped the
# S9 counters; the injection bumps them once more, one tick per action. A session that is not alive and owned yet stays
# `relaunching` (the S9 concurrency window ignores it after an hour).
borg_resume_relaunched_pass() {
    local _f _sid _now _seen=" " _ports
    _now="$(_rc_now)"
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r .state "$_f" 2>/dev/null)" = relaunching ] || continue
        [ "$(jq -r '.relaunched // false' "$_f" 2>/dev/null)" = false ] || continue
        _sid="$(jq -r .sid "$_f" 2>/dev/null)"
        case "$_seen" in
            *" $_sid=no "*) continue ;;
            *" $_sid=yes "*) ;;
            *)
                _rr_find "$_sid"
                _ports=""
                [ "$_rr_kind" = claude ] && [ "$_rr_n" -eq 1 ] &&
                    _ports="$(_bi_list_panes | awk -F'|' -v p="$_rr_pane" '$1 == p {print $3}')"
                if [ -n "$_ports" ] && borg_inject_owner_check "$_sid" "$_ports" >/dev/null 2>&1; then
                    _seen="${_seen}${_sid}=yes "
                else
                    _seen="${_seen}${_sid}=no "
                    continue
                fi
                ;;
        esac
        _rw_update "$_f" --argjson now "$_now" '.relaunched = true | .resume_at = $now | .state = "scheduled"
            | .state_log += [["scheduled", $now, "relaunched"]]'
        _rr_log "session alive and owned again, handed to the gate: ${_f##*/}"
    done
    return 0
}
