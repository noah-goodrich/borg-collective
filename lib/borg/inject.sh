#!/usr/bin/env bash
# inject.sh -- pane proof and positive-evidence injection for borg-resume (slice S8).
#
# Sourced (bash 3.2 safe, functions only, sourcing prints nothing). The one rule: inject ONLY with proof, never on
# absence of activity. borg_inject_line types a one-line prompt into a claude pane only when ALL of these hold:
#   1. the kill switch is off (BORG_RESUME_DISABLE unset; no DISABLED sentinel)
#   2. exactly one claude pane carries tmux pane option @borg_sid equal to the session id (no registry pane_id, no
#      window-name lookup, no rightmost-pane fallback)
#   3. the session is a host session (container sessions are never injectable) and the registry claude_pid is
#      alive, its start time matches claude_start, and it sits in the process tree of the pane
#   4. capture-pane classifies the pane idle_empty (composer present and empty, no dialog, nothing busy)
#   5. no attached tmux client had activity in the last BORG_RESUME_CLIENT_QUIET_SEC (30) seconds
#   6. the pane is in normal mode (pane_in_mode=0), not dead, and not synchronized with sibling panes; this is
#      re-checked immediately before the text is typed and again before Enter
# Then it types the text with send-keys -l, RE-CAPTURES and requires that text (compared with all whitespace
# removed, so a hard-wrapped long path still matches) in an otherwise empty composer, and only then sends a
# separate Enter. Any mismatch sends Ctrl+U, confirms the composer is empty again, and defers. There is no
# double-Enter retry (deliberate: borg-usage-watch sends a single Enter too; a second Enter could submit a draft).
# A failed tmux list-clients is treated as "human may be active" (defer), not as "no clients".
# Positive idle detection beyond the marker lists here is S9's pre-flight gate; the askuser/plan/resume_size
# fixtures are synthetic until real captures replace them (U17).
#
# Result protocol of borg_inject_line: one line on stdout, and an exit code.
#   0   "injected pane=<id>"     12  "disabled"            (BORG_RESUME_DISABLE=1: everything stops)
#   10  "defer <reason>"         2   "error bad_text"      (refused before touching tmux)
#   11  "notify <reason>"
# defer = keep the record deferred and re-check next pass; notify = tell the human, do not retry blindly.
#
# Public functions: borg_inject_classify_text, borg_inject_composer_text, borg_inject_pane_state,
# borg_inject_find_pane, borg_inject_bind_container, borg_inject_owner_check, borg_inject_human_active,
# borg_inject_line.
#
# Env (all optional; the stubs exist for tests): BORG_RESUME_TMUX_CMD (default tmux), BORG_RESUME_SENDKEYS_CMD
# (default "<tmux> send-keys"), BORG_RESUME_PANES_CMD (prints list-panes lines, pipe separated),
# BORG_RESUME_CLIENTS_CMD (prints client_activity epochs), BORG_RESUME_PANE_CMD_RE (claude process name regex),
# BORG_RESUME_NOW_EPOCH, BORG_RESUME_SEND_DELAY (0.3s between text and Enter, as borg-usage-watch), VERIFY_TRIES (6),
# BORG_RESUME_CLIENT_QUIET_SEC (30).
#
# Not here: the pre-flight gate and caps (S9), liveness (S10), relaunch (S11), launchd (S12).

if ! command -v borg_resume_paused >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    . "${BASH_SOURCE[0]%/*}/resume-paths.sh" 2>/dev/null || true
fi

_BI_RULE_RE='^[[:space:]]*(─){8,}[[:space:]]*$'
_BI_TAIL_LINES=30
# claude's process name, or the version string a native install reports (same match as borg-usage-watch).
_BI_CMD_RE='^(claude|[0-9]+\.[0-9]+\.[0-9]+)$'

# Run tmux (or the test stand-in) with the given arguments.
_bi_tmux() {
    local -a _t
    if [ -n "${BORG_RESUME_TMUX_CMD:-}" ]; then
        read -r -a _t <<<"$BORG_RESUME_TMUX_CMD"
    else
        _t=(tmux)
    fi
    "${_t[@]}" "$@"
}

# send-keys through the stub when set, else through tmux. Usage: _bi_sendkeys <send-keys args...>
_bi_sendkeys() {
    local -a _sk
    if [ -n "${BORG_RESUME_SENDKEYS_CMD:-}" ]; then
        read -r -a _sk <<<"$BORG_RESUME_SENDKEYS_CMD"
        "${_sk[@]}" "$@"
    else
        _bi_tmux send-keys "$@"
    fi
}

_bi_now() { printf '%s\n' "${BORG_RESUME_NOW_EPOCH:-$(date +%s)}"; }

# Remove ALL whitespace (comparison key for wrapped composer text).
_bi_squash() {
    local _q="${1//$'\xc2\xa0'/ }"
    _q="${_q//[[:space:]]/}"
    printf '%s' "$_q"
}

# Collapse runs of whitespace (including NBSP) and trim both ends.
_bi_norm() {
    local _ns="${1//$'\xc2\xa0'/ }"
    _ns="${_ns//$'\t'/ }"
    while [[ "$_ns" == *"  "* ]]; do _ns="${_ns//  / }"; done
    _ns="${_ns# }"
    printf '%s' "${_ns% }"
}

# Core classifier. Reads a pane capture on stdin and sets _BI_STATE and _BI_TEXT (composer text, when found).
_bi_classify() {
    local -a _all=() _tail=()
    local _l _n _i _start _first _p=-1 _lst=-1 _prev=-1 _reg _cmp _dial _after
    _BI_STATE=unknown
    _BI_TEXT=""
    while IFS= read -r _l || [ -n "$_l" ]; do _all[${#_all[@]}]="$_l"; done
    _n=${#_all[@]}
    while [ "$_n" -gt 0 ]; do
        _l="${_all[$((_n - 1))]}"
        [[ "$_l" =~ [^[:space:]] ]] && break
        _n=$((_n - 1))
    done
    [ "$_n" -gt 0 ] || return 0
    _start=$((_n - _BI_TAIL_LINES))
    [ "$_start" -lt 0 ] && _start=0
    _i=$_start
    while [ "$_i" -lt "$_n" ]; do
        _tail[${#_tail[@]}]="${_all[$_i]//$'\xc2\xa0'/ }"
        _i=$((_i + 1))
    done
    _n=${#_tail[@]}

    _i=0
    while [ "$_i" -lt "$_n" ]; do
        if [[ "${_tail[$_i]}" =~ $_BI_RULE_RE ]]; then
            _prev=$_p
            _p=$_i
        fi
        _i=$((_i + 1))
    done
    _lst=$_p
    # The region a dialog can live in: from the second-to-last rule down (the whole tail when fewer than two).
    _reg=0
    [ "$_prev" -ge 0 ] && _reg=$_prev
    _dial=0
    _i=$_reg
    while [ "$_i" -lt "$_n" ]; do
        _l="${_tail[$_i]}"
        case "$_l" in
            *"Esc to cancel"* | *"Enter to confirm"* | *"Enter to select"* | *"Tab to amend"* | \
                *"What do you want to do?"* | *"Usage limit reached"* | *"Resuming the full session"* | \
                *"Would you like to proceed"* | *"Do you want to "* | *"Ready to code?"* | *"Accessing workspace"* | \
                *"trust this folder"*)
                _dial=1
                ;;
        esac
        if [[ "$_l" =~ ^[[:space:]]*❯[[:space:]]+[0-9]+\. ]] || [[ "$_l" =~ ^[[:space:]]+[0-9]+\.[[:space:]] ]]; then
            _dial=1
        fi
        _i=$((_i + 1))
    done
    if [ "$_dial" -eq 1 ]; then
        _BI_STATE=dialog
        return 0
    fi
    _i=0
    while [ "$_i" -lt "$_n" ]; do
        case "${_tail[$_i]}" in
            *"esc to interrupt"* | *"Press up to edit queued messages"* | *"to send now"*)
                _BI_STATE=busy
                return 0
                ;;
        esac
        _i=$((_i + 1))
    done
    # Composer: the last two rules bracket it, the first line inside starts with the prompt glyph.
    [ "$_prev" -ge 0 ] && [ $((_lst - _prev)) -ge 2 ] || return 0
    _after=$((_n - 1 - _lst))
    [ "$_after" -le 4 ] || return 0
    _first="${_tail[$((_prev + 1))]}"
    [[ "$_first" =~ ^[[:space:]]*❯(.*)$ ]] || return 0
    _cmp="${BASH_REMATCH[1]}"
    _i=$((_prev + 2))
    while [ "$_i" -lt "$_lst" ]; do
        _cmp="${_cmp} ${_tail[$_i]}"
        _i=$((_i + 1))
    done
    _BI_TEXT="$(_bi_norm "$_cmp")"
    if [ -z "$_BI_TEXT" ]; then
        _BI_STATE=idle_empty
    else
        _BI_STATE=draft
    fi
    return 0
}

# stdin: a capture-pane dump. stdout: idle_empty | draft | dialog | busy | unknown.
borg_inject_classify_text() {
    _bi_classify
    printf '%s\n' "$_BI_STATE"
}

# stdin: a capture-pane dump. stdout: the composer text (empty when there is no composer or it is empty).
borg_inject_composer_text() {
    _bi_classify
    printf '%s\n' "$_BI_TEXT"
}

# Classify a live pane. Usage: borg_inject_pane_state <pane_id>. A capture failure is "unknown".
borg_inject_pane_state() {
    local _cap
    _cap="$(_bi_tmux capture-pane -p -t "$1" 2>/dev/null)" || {
        printf 'unknown\n'
        return 0
    }
    printf '%s\n' "$_cap" | borg_inject_classify_text
}

# List "pane_id|@borg_sid|pane_pid|pane_current_command" for every pane on the server.
_bi_list_panes() {
    if [ -n "${BORG_RESUME_PANES_CMD:-}" ]; then
        bash -c "$BORG_RESUME_PANES_CMD" 2>/dev/null
    else
        _bi_tmux list-panes -a -F '#{pane_id}|#{@borg_sid}|#{pane_pid}|#{pane_current_command}' 2>/dev/null
    fi
}

# The ONLY way an injection target is chosen: the claude pane whose @borg_sid equals <sid>.
# stdout "pane_id|pane_pid|command". Exit 0 found, 1 none, 2 more than one (ambiguous, never guessed).
borg_inject_find_pane() {
    local _sid="$1" _re="${BORG_RESUME_PANE_CMD_RE:-$_BI_CMD_RE}" _id _bound _pid _cmd _hit="" _n=0
    borg_resume_valid_sid "$_sid" || return 1
    while IFS='|' read -r _id _bound _pid _cmd; do
        [ -n "$_id" ] && [ -n "$_bound" ] && [ "$_bound" = "$_sid" ] || continue
        [[ "$_cmd" =~ $_re ]] || continue
        _hit="${_id}|${_pid}|${_cmd}"
        _n=$((_n + 1))
    done < <(_bi_list_panes)
    [ "$_n" -le 1 ] || return 2
    [ "$_n" -eq 1 ] || return 1
    printf '%s\n' "$_hit"
}

# Container-session binding rule (host side): set @borg_sid on the drone window's pane ONLY when the window whose
# @project_dir equals <repository_dir> holds exactly one claude pane. Two or more: stay unbound (rc 1), never pick
# the rightmost. The caller (S9/S10) must additionally prove the drone container is healthy and the transcript's
# recent writes fit before calling this. Binding does NOT make the session injectable: see borg_inject_line.
# Usage: borg_inject_bind_container <sid> <repository_dir>
borg_inject_bind_container() {
    local _sid="$1" _dir="$2" _re="${BORG_RESUME_PANE_CMD_RE:-$_BI_CMD_RE}" _id _pdir _cmd _bound _hit="" _hb="" _n=0
    borg_resume_valid_sid "$_sid" || return 1
    [ -n "$_dir" ] || return 1
    while IFS='|' read -r _id _pdir _bound _cmd; do
        [ -n "$_id" ] && [ "$_pdir" = "$_dir" ] || continue
        [[ "$_cmd" =~ $_re ]] || continue
        _hit="$_id"
        _hb="$_bound"
        _n=$((_n + 1))
    done < <(_bi_tmux list-panes -a -F '#{pane_id}|#{@project_dir}|#{@borg_sid}|#{pane_current_command}' 2>/dev/null)
    [ "$_n" -eq 1 ] || return 1
    # Never overwrite an existing binding.
    [ -z "$_hb" ] || [ "$_hb" = "$_sid" ] || return 1
    _bi_tmux set-option -p -t "$_hit" @borg_sid "$_sid" >/dev/null 2>&1 || return 1
    printf '%s\n' "$_hit"
}

# True when pid $1 is $2 or a descendant of it.
_bi_pid_under() {
    local _p="$1" _top="$2" _i=0
    while [ -n "$_p" ] && [ "$_p" -gt 1 ] 2>/dev/null && [ "$_i" -lt 64 ]; do
        [ "$_p" = "$_top" ] && return 0
        _p="$(ps -o ppid= -p "$_p" 2>/dev/null)"
        _p="${_p//[[:space:]]/}"
        _i=$((_i + 1))
    done
    return 1
}

# Ownership proof for a HOST session. Usage: borg_inject_owner_check <sid> <pane_pid>
# Exit 0 owned. Otherwise exit 1 and print the reason: no_jq no_registry container no_pid no_start pid_dead
# start_mismatch not_in_pane.
borg_inject_owner_check() {
    local _sid="$1" _ppid="$2" _reg _cont _pid _start _live
    command -v jq >/dev/null 2>&1 || { printf 'no_jq\n'; return 1; }
    _reg="$(borg_resume_registry_file "$_sid" 2>/dev/null)"
    [ -f "$_reg" ] || { printf 'no_registry\n'; return 1; }
    _cont="$(jq -r '.in_container // false' "$_reg" 2>/dev/null)"
    [ "$_cont" = "false" ] || { printf 'container\n'; return 1; }
    _pid="$(jq -r '.claude_pid // empty' "$_reg" 2>/dev/null)"
    case "$_pid" in "" | *[!0-9]*) printf 'no_pid\n'; return 1 ;; esac
    _start="$(jq -r '.claude_start // empty' "$_reg" 2>/dev/null)"
    _start="$(_bi_norm "$_start")"
    [ -n "$_start" ] || { printf 'no_start\n'; return 1; }
    kill -0 "$_pid" 2>/dev/null || { printf 'pid_dead\n'; return 1; }
    _live="$(LC_ALL=C ps -o lstart= -p "$_pid" 2>/dev/null)"
    _live="$(_bi_norm "$_live")"
    [ -n "$_live" ] || { printf 'pid_dead\n'; return 1; }
    [ "$_live" = "$_start" ] || { printf 'start_mismatch\n'; return 1; }
    _bi_pid_under "$_pid" "$_ppid" || { printf 'not_in_pane\n'; return 1; }
    return 0
}

# Exit 0 when an attached tmux client had activity within BORG_RESUME_CLIENT_QUIET_SEC (a human at the keys).
borg_inject_human_active() {
    local _quiet="${BORG_RESUME_CLIENT_QUIET_SEC:-30}" _now _a _out
    _now="$(_bi_now)"
    if [ -n "${BORG_RESUME_CLIENTS_CMD:-}" ]; then
        _out="$(bash -c "$BORG_RESUME_CLIENTS_CMD" 2>/dev/null)"
    else
        # A failing list-clients is unknown, not "no clients": report active so the caller defers.
        _out="$(_bi_tmux list-clients -F '#{client_activity}' 2>/dev/null)" || return 0
    fi
    while IFS= read -r _a; do
        case "$_a" in "" | *[!0-9]*) continue ;; esac
        [ $((_now - _a)) -lt "$_quiet" ] && return 0
    done <<<"$_out"
    return 1
}

# Is <sid> a container session per the registry? (A missing row is not a container.)
_bi_is_container() {
    local _reg
    command -v jq >/dev/null 2>&1 || return 1
    _reg="$(borg_resume_registry_file "$1" 2>/dev/null)"
    [ -f "$_reg" ] && [ "$(jq -r '.in_container // false' "$_reg" 2>/dev/null)" = "true" ]
}

# Positive proof the pane is safe to type into: exists, not dead, not in copy/other mode, not synchronized.
# Prints the failing reason (pane_gone, pane_dead, pane_in_mode, pane_synchronized, pane_unreadable) and returns 1.
_bi_pane_ok() {
    local _pane="$1" _id _mode _dead _sync _found=0 _out
    _out="$(_bi_tmux list-panes -a -F '#{pane_id}|#{pane_in_mode}|#{pane_dead}|#{pane_synchronized}' 2>/dev/null)" || {
        printf 'pane_unreadable\n'
        return 1
    }
    while IFS='|' read -r _id _mode _dead _sync; do
        [ "$_id" = "$_pane" ] || continue
        _found=1
        [ "$_dead" = "0" ] || { printf 'pane_dead\n'; return 1; }
        [ "$_mode" = "0" ] || { printf 'pane_in_mode\n'; return 1; }
        [ "$_sync" = "0" ] || { printf 'pane_synchronized\n'; return 1; }
    done <<<"$_out"
    [ "$_found" -eq 1 ] || { printf 'pane_gone\n'; return 1; }
    return 0
}

# Type <text> into <pane> and verify; submit only on a whitespace-insensitive match. Echoes defer/notify lines.
_bi_type_verify_submit() {
    local _pane="$1" _text="$2" _want _cap _st _try _why
    _want="$(_bi_squash "$_text")"
    _why="$(_bi_pane_ok "$_pane")" || { printf 'defer %s\n' "$_why"; return 10; }
    _st="$(borg_inject_pane_state "$_pane")"
    [ "$_st" = "idle_empty" ] || { printf 'defer pane_%s\n' "$_st"; return 10; }
    _bi_sendkeys -l -t "$_pane" "$_text" || { printf 'defer send_failed\n'; return 10; }
    # The composer repaints a moment after the keys land: poll a few times for the text before judging.
    _try=0
    while :; do
        sleep "${BORG_RESUME_SEND_DELAY:-0.3}" 2>/dev/null || true
        _cap="$(_bi_tmux capture-pane -p -t "$_pane" 2>/dev/null)"
        _bi_classify <<<"$_cap"
        _try=$((_try + 1))
        { [ "$_BI_STATE" = "draft" ] && [ "$(_bi_squash "$_BI_TEXT")" = "$_want" ]; } && break
        [ "$_try" -lt "${BORG_RESUME_VERIFY_TRIES:-6}" ] || break
    done
    if [ "$_BI_STATE" = "draft" ] && [ "$(_bi_squash "$_BI_TEXT")" = "$_want" ] && ! borg_inject_human_active; then
        if _why="$(_bi_pane_ok "$_pane")"; then
            _bi_sendkeys -t "$_pane" Enter || { printf 'defer send_failed\n'; return 10; }
            printf 'injected pane=%s\n' "$_pane"
            return 0
        fi
        printf 'notify clear_failed %s\n' "$_why"
        return 11
    fi
    # Verification failed (or a human is active): always clear, then require an empty composer before deferring.
    if ! _why="$(_bi_pane_ok "$_pane")"; then
        printf 'notify clear_failed %s\n' "$_why"
        return 11
    fi
    _bi_sendkeys -t "$_pane" C-u >/dev/null 2>&1
    sleep "${BORG_RESUME_SEND_DELAY:-0.3}" 2>/dev/null || true
    _st="$(borg_inject_pane_state "$_pane")"
    if [ "$_st" = "idle_empty" ]; then
        printf 'defer verify_failed\n'
        return 10
    fi
    printf 'notify clear_failed state=%s\n' "$_st"
    return 11
}

# Inject one line into the pane bound to <sid>, with positive proof or not at all.
# Usage: borg_inject_line <sid> <text>. See the result protocol in the header.
borg_inject_line() {
    local _sid="$1" _text="$2" _hit _rc _pane _ppid _why _st
    if borg_resume_disabled_env; then
        printf 'disabled\n'
        return 12
    fi
    borg_resume_valid_sid "$_sid" || { printf 'error bad_text\n'; return 2; }
    if [ -z "$_text" ] || [ "${#_text}" -gt 400 ] || [[ "$_text" == *[[:cntrl:]]* ]] || [[ "$_text" == -* ]]; then
        printf 'error bad_text\n'
        return 2
    fi
    if borg_resume_paused; then
        printf 'defer paused\n'
        return 10
    fi
    if _bi_is_container "$_sid"; then
        printf 'notify container_session\n'
        return 11
    fi
    _hit="$(borg_inject_find_pane "$_sid")"
    _rc=$?
    if [ "$_rc" -eq 2 ]; then
        printf 'defer ambiguous_pane\n'
        return 10
    fi
    if [ "$_rc" -ne 0 ] || [ -z "$_hit" ]; then
        printf 'defer no_pane\n'
        return 10
    fi
    IFS='|' read -r _pane _ppid _ <<<"$_hit"
    if ! _why="$(borg_inject_owner_check "$_sid" "$_ppid")"; then
        printf 'defer ownership:%s\n' "$_why"
        return 10
    fi
    if ! _why="$(_bi_pane_ok "$_pane")"; then
        printf 'defer %s\n' "$_why"
        return 10
    fi
    _st="$(borg_inject_pane_state "$_pane")"
    if [ "$_st" != "idle_empty" ]; then
        printf 'defer pane_%s\n' "$_st"
        return 10
    fi
    if borg_inject_human_active; then
        printf 'defer human_active\n'
        return 10
    fi
    _bi_type_verify_submit "$_pane" "$_text"
}
