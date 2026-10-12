#!/usr/bin/env bash
# resume-probe.sh -- borg-resume probe (slice S0c): the resume feature's OWN usage sample, independent of the
# usage guardian. Runs `claude -p /usage` through the ABSOLUTE claude binary (claude-bin.sh) so it works under
# launchd's minimal environment, parses "Current session: N% used", and caches the answer for 120s.
#
# borg_resume_probe prints N (0..100) and returns 0, or prints a message on stderr and returns 1.
# Stub the sampler with BORG_RESUME_USAGE_CMD (a shell command whose stdout replaces the claude call).
# Cache: <borg_resume_dir>/usage-probe.json {"at":<epoch>,"session_pct":N}. Needs resume-paths.sh sourced.
# Bash 3.2 safe; never exits the caller.

BORG_RESUME_PROBE_TTL="${BORG_RESUME_PROBE_TTL:-120}"

borg_resume_probe() {
    local _dir _cache _now _at _pct _out _rc=0 _libdir _user
    _libdir="${BORG_RESUME_LIBDIR:-${BASH_SOURCE[0]%/*}}"
    _dir="$(borg_resume_dir)"
    _cache="$_dir/usage-probe.json"
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) _now="$(date +%s)" ;;
        *) _now="$BORG_RESUME_NOW_EPOCH" ;;
    esac

    if [ -f "$_cache" ] && command -v jq >/dev/null 2>&1; then
        _at="$(jq -r '"\(.at // "")"' "$_cache" 2>/dev/null)"
        _pct="$(jq -r '"\(.session_pct // "")"' "$_cache" 2>/dev/null)"
        case "$_at$_pct" in
            *[!0-9]* | "") ;;
            *)
                if [ "$_at" -le "$_now" ] && [ $((_now - _at)) -lt "$BORG_RESUME_PROBE_TTL" ]; then
                    printf '%s\n' "$_pct"
                    return 0
                fi
                ;;
        esac
    fi

    if [ -n "${BORG_RESUME_USAGE_CMD:-}" ]; then
        _out="$(bash -c "$BORG_RESUME_USAGE_CMD" 2>&1)" || _rc=$?
    else
        # shellcheck source=/dev/null
        . "$_libdir/claude-bin.sh" 2>/dev/null
        if ! borg_resolve_claude_bin; then
            printf 'borg-resume probe: claude binary not found (set BORG_CLAUDE_BIN to an absolute path)\n' >&2
            return 1
        fi
        # claude -p /usage prints nothing and exits 0 when USER is unset (launchd), so self-heal it.
        _user="${USER:-}"
        [ -n "$_user" ] || _user="$(id -un 2>/dev/null)"
        _out="$(USER="$_user" BORG_NO_SPEND_RECORD=1 BORG_NO_SESSION_HOOKS=1 "$BORG_CLAUDE_BIN" -p "/usage" 2>&1)" || _rc=$?
    fi
    if [ "$_rc" -ne 0 ]; then
        printf 'borg-resume probe: claude exited %s for /usage\n' "$_rc" >&2
        return 1
    fi

    _pct="$(printf '%s\n' "$_out" | grep -oE 'Current session: [0-9]+% used' | head -1 | sed -E 's/^Current session: ([0-9]+)% used$/\1/')"
    case "$_pct" in
        "" | *[!0-9]*)
            printf 'borg-resume probe: could not parse "Current session: N%% used" from /usage output\n' >&2
            return 1
            ;;
    esac
    if [ "$_pct" -gt 100 ]; then
        printf 'borg-resume probe: could not parse a sane percentage (%s)\n' "$_pct" >&2
        return 1
    fi
    mkdir -p "$_dir" 2>/dev/null &&
        printf '{"at":%s,"session_pct":%s}\n' "$_now" "$_pct" | borg_resume_write_atomic "$_cache" 2>/dev/null
    printf '%s\n' "$_pct"
    return 0
}
