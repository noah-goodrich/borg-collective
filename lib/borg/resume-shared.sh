#!/bin/bash
# lib/borg/resume-shared.sh - helpers shared by the S9 gate (resume-gate.sh) and the S10 liveness detector
# (resume-liveness.sh), added by RECONCILE-6 so the two parallel slices agree. Sourced, never executed.
#
# 1. "Moving" is defined ONCE: borg_resume_transcript_moving. A transcript is moving when its line count OR its byte
#    size exceeds the baseline recorded at confirmation (a long line without a newline yet is still growth); a recent
#    mtime alone is only a secondary hint. The stall watchdog has exactly one owner, the S9 gate (directive S9:
#    "confirmation, retry, and the post-confirmation stall watchdog"); S10 does not stall records.
#
# 2. Notifications have ONE path: borg_resume_notify. It appends a bounded outbox line to notify.jsonl and delivers it
#    host-side (_borg_osa_notify, or BORG_RESUME_NOTIFY_CMD as a test seam), and the same event (kind + rid, or an
#    explicit key) is never logged or delivered twice. Callers that hold a record keep their own per-record notice
#    map; the outbox check is the cross-slice backstop.
#
# Needs resume-paths.sh (borg_resume_dir, borg_resume_append_line, borg_resume_registry_file) and resume-classify.sh
# (_rc_now). Bash 3.2 compatible.

_RS_DIR="${BASH_SOURCE[0]%/*}"
_RS_LINES=0
_RS_SIZE=0

_rs_int() { # <value> <default>
    case "$1" in "" | *[!0-9]*) printf '%s\n' "$2" ;; *) printf '%s\n' "$1" ;; esac
}

_rs_mtime() {
    local _m
    _m="$(stat -c %Y "$1" 2>/dev/null)" || _m="$(stat -f %m "$1" 2>/dev/null)" || _m=0
    _rs_int "$_m" 0
}

# borg_resume_transcript_moving <file> <baseline-lines> <baseline-size> <window-sec>
# Sets _RS_LINES and _RS_SIZE to the current values. Returns 0 when the transcript grew (lines or bytes over the
# baseline; an empty baseline is ignored), 2 when it did not grow but was modified within the window (a hint: not
# stalled yet, no growth clock reset), 1 when it is quiet. A missing file is quiet.
borg_resume_transcript_moving() {
    local _f="$1" _bl _bs _win _now _mt
    _bl="$(_rs_int "$2" "")"
    _bs="$(_rs_int "$3" "")"
    _win="$(_rs_int "$4" 600)"
    _RS_LINES=0
    _RS_SIZE=0
    [ -f "$_f" ] || return 1
    _RS_LINES="$(wc -l <"$_f" | tr -d ' ')"
    _RS_SIZE="$(wc -c <"$_f" | tr -d ' ')"
    [ -z "$_bl" ] || [ "$_RS_LINES" -le "$_bl" ] || return 0
    [ -z "$_bs" ] || [ "$_bs" = 0 ] || [ "$_RS_SIZE" -le "$_bs" ] || return 0
    _now="$(_rc_now)"
    _mt="$(_rs_mtime "$_f")"
    if [ "$_now" -ge "$_mt" ] && [ $((_now - _mt)) -lt "$_win" ]; then
        return 2
    fi
    return 1
}

# Keep the outbox bounded: past 2x BORG_RESUME_NOTIFY_KEEP (default 200) lines, keep the last KEEP.
_rs_trim_outbox() {
    local _keep _tmp
    _keep="$(_rs_int "${BORG_RESUME_NOTIFY_KEEP:-}" 200)"
    [ "$(wc -l <"$1" | tr -d ' ')" -gt $((_keep * 2)) ] || return 0
    _tmp="$1.trim.$$"
    if tail -n "$_keep" "$1" >"$_tmp" 2>/dev/null; then mv -f "$_tmp" "$1"; fi
    return 0
}

# Host-side delivery. BORG_RESUME_NOTIFY_CMD (test seam) is run as `<cmd> <title> <subtitle> <message>` when it is an
# executable path, else as a shell snippet with the three values as $1 $2 $3. Never fails the caller.
_rs_deliver() { # <subtitle> <message>
    local _c="${BORG_RESUME_NOTIFY_CMD:-}"
    if [ -n "$_c" ]; then
        if [ -x "$_c" ]; then
            "$_c" "Borg Resume" "$1" "$2" >/dev/null 2>&1 || true
        else
            bash -c "$_c" _ "Borg Resume" "$1" "$2" >/dev/null 2>&1 || true
        fi
        return 0
    fi
    [ -z "${BORG_RESUME_DIR:-}" ] || return 0
    # A subshell: sourcing borg-hooks.sh must not leak into the watcher.
    # shellcheck source=/dev/null
    ( . "$_RS_DIR/../borg-hooks.sh" >/dev/null 2>&1 &&
        _borg_osa_notify "Borg Resume" "$1" "$2" ) >/dev/null 2>&1 || true
    return 0
}

# borg_resume_notify <kind> <sid> <rid> <message> [key]
# The dedup key defaults to kind:rid (kind:sid when there is no rid). Returns 0 always.
borg_resume_notify() {
    local _kind="$1" _sid="$2" _rid="$3" _msg="$4" _key="${5:-}" _out _reg _proj _win _line _label
    if [ -z "$_key" ]; then
        _key="$_kind:${_rid:-$_sid}"
    fi
    _out="$(borg_resume_dir)/notify.jsonl"
    if [ -f "$_out" ] && jq -e -R -n --arg k "$_key" '[inputs | fromjson? | select(type == "object" and .key == $k)]
        | length > 0' "$_out" >/dev/null 2>&1; then
        return 0
    fi
    _reg="$(borg_resume_registry_file "$_sid")"
    _proj="" _win=""
    if [ -f "$_reg" ]; then
        _proj="$(jq -r '.project // empty' "$_reg" 2>/dev/null)"
        _win="$(jq -r '.tmux.window // empty' "$_reg" 2>/dev/null)"
    fi
    _line="$(jq -n -c --argjson t "$(_rc_now)" --arg kind "$_kind" --arg key "$_key" \
        --arg sid "$_sid" --arg rid "$_rid" --arg p "$_proj" --arg w "$_win" --arg m "${_msg:0:500}" \
        '{t: $t, kind: $kind, key: $key, sid: $sid, rid: $rid, project: $p, window: $w, msg: $m}' 2>/dev/null)"
    # The outbox line is written BEFORE delivery, so a crash can never double-notify.
    if [ -n "$_line" ]; then
        borg_resume_append_line "$_out" "$_line"
        _rs_trim_outbox "$_out"
    fi
    _label="${_win:-$_proj}"
    [ -n "$_label" ] || _label="${_sid:0:8}"
    _rs_deliver "$_label" "${_msg:0:500}"
    return 0
}
