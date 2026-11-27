#!/usr/bin/env bash
# resume-paths.sh -- state layout, kill switch and atomic write helpers for borg-resume.
#
# Sourced by bin/borg-resume. Bash 3.2 safe (macOS /bin/bash), no dependency beyond coreutils. Every function
# is fail-open: it returns non-zero on trouble and never exits, so a hook can never be blocked by the ledger.
#
# Layout under borg_resume_dir (BORG_RESUME_DIR overrides it, for tests):
#   DISABLED            sentinel: pause everything (the watcher honors it; recording continues)
#   sessions/<sid>.json hook-owned registry, written only by the session_start handler (tmp + mv)
#   events/<sid>.jsonl  append-only facts, one JSON object per line (hooks append only)
#   state/<sid>.json    watcher-owned counters (never written by a hook)
# One owner per file: that is what makes concurrent hook and watcher writes safe without a lock.

borg_resume_dir() {
    if [ -n "${BORG_RESUME_DIR:-}" ]; then
        printf '%s\n' "$BORG_RESUME_DIR"
    else
        printf '%s/borg/resume\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
    fi
}

# A session id becomes a filename, so accept only a conservative charset (UUIDs always pass).
borg_resume_valid_sid() {
    case "${1:-}" in
        "" | *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    [ "${#1}" -le 128 ]
}

borg_resume_events_file() { printf '%s/events/%s.jsonl\n' "$(borg_resume_dir)" "$1"; }
borg_resume_registry_file() { printf '%s/sessions/%s.json\n' "$(borg_resume_dir)" "$1"; }
borg_resume_sentinel() { printf '%s/DISABLED\n' "$(borg_resume_dir)"; }

# Kill switch, env half: BORG_RESUME_DISABLE=1 stops recording AND injecting.
borg_resume_disabled_env() {
    [ "${BORG_RESUME_DISABLE:-}" = "1" ]
}

# Kill switch, sentinel half: survives launchd where env cannot change. Recording continues, injecting stops.
borg_resume_paused() {
    [ -e "$(borg_resume_sentinel)" ]
}

# The hook-suppression flag, with the semantics of hooks/borg-link-down.sh: only the value 1 suppresses.
borg_resume_no_session_hooks() {
    [ "${BORG_NO_SESSION_HOOKS:-}" = "1" ]
}

# Append ONE line to a file. The line is written with a single printf (one write(2) on an O_APPEND fd), which
# POSIX makes atomic for lines under PIPE_BUF; callers cap every string field at 256 chars (msg at 600) so events
# stay well below the 4KB the platforms guarantee. A compact JSON line has no raw newline, so none is checked for.
# Usage: borg_resume_append_line <file> <line>
borg_resume_append_line() {
    local _f="$1" _line="$2"
    mkdir -p "${_f%/*}" 2>/dev/null || return 1
    { printf '%s\n' "$_line" >>"$_f"; } 2>/dev/null
}

# Atomically replace <file> with stdin: write a unique tmp beside it, then mv (rename is atomic in-dir).
# Usage: borg_resume_write_atomic <file> < content
borg_resume_write_atomic() {
    local _f="$1" _tmp
    mkdir -p "${_f%/*}" 2>/dev/null || return 1
    _tmp="${_f}.tmp.$$.${RANDOM}${RANDOM}"
    if { cat >"$_tmp"; } 2>/dev/null && mv -f "$_tmp" "$_f" 2>/dev/null; then
        return 0
    fi
    rm -f "$_tmp" 2>/dev/null
    return 1
}

# ---------------------------------------------------------------------------------------------
# Process start identity (#491). `ps -o lstart=` prints LOCAL time, so a system timezone change makes the same process
# print a different string. The stable identity is the start EPOCH, read under a pinned TZ=UTC. Registry rows now carry
# claude_start_epoch; rows written before that carry only the claude_start string (still accepted on read).
# ---------------------------------------------------------------------------------------------

# Start epoch of <pid> (timezone independent). Prints nothing and returns 1 when ps cannot answer.
# Usage: borg_resume_proc_epoch <pid>
borg_resume_proc_epoch() {
    local _s
    _s="$(TZ=UTC LC_ALL=C /bin/ps -o lstart= -p "$1" 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
    [ -n "$_s" ] || return 1
    TZ=UTC LC_ALL=C date -j -f '%a %b %e %T %Y' "$_s" +%s 2>/dev/null || TZ=UTC LC_ALL=C date -d "$_s" +%s 2>/dev/null
}

# Does <pid> still carry the recorded start? Prints same | different | unknown.
#   same       the start epoch matches (one second of tolerance), or a legacy string row matches verbatim
#   different  the pid is gone, or its epoch differs from the recorded one (pid reuse)
#   unknown    no proof either way: ps gave no answer for a live pid, or a legacy string row differs
# Usage: borg_resume_start_check <pid> <start_epoch> <start_string>
borg_resume_start_check() {
    local _pid="$1" _sep="$2" _str="$3" _live _d _loc
    _live="$(borg_resume_proc_epoch "$_pid")" || _live=""
    if [ -z "$_live" ]; then
        if kill -0 "$_pid" 2>/dev/null; then printf 'unknown\n'; else printf 'different\n'; fi
        return 0
    fi
    case "$_sep" in
        "" | *[!0-9]*) ;;
        *)
            _d=$((_live - _sep))
            [ "$_d" -lt 0 ] && _d=$((0 - _d))
            if [ "$_d" -le 1 ]; then printf 'same\n'; else printf 'different\n'; fi
            return 0
            ;;
    esac
    _str="$(printf '%s' "$_str" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
    [ -n "$_str" ] || { printf 'unknown\n'; return 0; }
    _loc="$(LC_ALL=C /bin/ps -o lstart= -p "$_pid" 2>/dev/null | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
    if [ "$_loc" = "$_str" ]; then
        printf 'same\n'
        return 0
    fi
    # A legacy string that differs may be the same process printed under another timezone, or a reused pid: the string
    # cannot tell them apart, so it is never proof of death. The next session_start rewrites the row with an epoch.
    printf 'unknown\n'
}
