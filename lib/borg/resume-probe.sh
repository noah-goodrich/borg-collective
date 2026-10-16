#!/usr/bin/env bash
# resume-probe.sh -- borg-resume probe (slice S0c): the resume feature's OWN usage sample, independent of the
# usage guardian. Runs `claude -p /usage` through the ABSOLUTE claude binary (claude-bin.sh) so it works under
# launchd's minimal environment, parses "Current session: N% used", and caches the answer for 120s.
#
# borg_resume_probe prints N (0..100) and returns 0, or prints a message on stderr and returns 1.
# A usage-billed account (Enterprise seat) has no session limit: its /usage prints a cost summary ("Total cost:")
# and no "Current session:" line. That is a valid state, not a parse failure: the probe prints the word
# "unmetered" and returns 0. Callers must test for it before comparing the answer as a number.
# Test seam: BORG_RESUME_USAGE_CMD (a shell command whose stdout replaces the claude call), honoured only when
# BORG_RESUME_DIR is set. The claude call is bounded by BORG_RESUME_PROBE_TIMEOUT seconds (default 30).
# Cache: <borg_resume_dir>/usage-probe.json {"at":<epoch>,"session_pct":N} (unmetered: "session_pct":"unmetered"). Needs resume-paths.sh sourced.
# Bash 3.2 safe; never exits the caller.

BORG_RESUME_PROBE_TTL="${BORG_RESUME_PROBE_TTL:-120}"
BORG_RESUME_PROBE_TIMEOUT="${BORG_RESUME_PROBE_TIMEOUT:-30}"
case "$BORG_RESUME_PROBE_TIMEOUT" in "" | *[!0-9]*) BORG_RESUME_PROBE_TIMEOUT=30 ;; esac

borg_resume_probe() {
    local _dir _cache _now _at _pct _out _rc=0 _libdir _user _tmp _pid _ticks
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
            *[!0-9]* | "")
                if [ "$_pct" = unmetered ]; then
                    case "$_at" in "" | *[!0-9]*) ;; *)
                        if [ "$_at" -le "$_now" ] && [ $((_now - _at)) -lt "$BORG_RESUME_PROBE_TTL" ]; then
                            printf 'unmetered\n'
                            return 0
                        fi
                        ;;
                    esac
                fi
                ;;
            *)
                if [ "$_at" -le "$_now" ] && [ $((_now - _at)) -lt "$BORG_RESUME_PROBE_TTL" ]; then
                    printf '%s\n' "$_pct"
                    return 0
                fi
                ;;
        esac
    fi

    # The stub seam is honoured only in an isolated state dir (BORG_RESUME_DIR set), never in production.
    if [ -n "${BORG_RESUME_USAGE_CMD:-}" ] && [ -n "${BORG_RESUME_DIR:-}" ]; then
        _out="$(bash -c "$BORG_RESUME_USAGE_CMD" 2>&1)" || _rc=$?
    else
        # shellcheck source=/dev/null
        . "$_libdir/claude-bin.sh" 2>/dev/null
        if ! borg_resolve_claude_bin; then
            printf 'borg-resume probe: claude binary not found (set BORG_CLAUDE_BIN to an absolute path)\n' >&2
            return 1
        fi
        # claude -p /usage prints nothing and exits 0 when USER is unset, so self-heal it.
        _user="${USER:-}"
        [ -n "$_user" ] || _user="$(id -un 2>/dev/null)"
        # Bounded: macOS has no coreutils timeout, so poll the child and kill it on expiry.
        _tmp="$(mktemp "${TMPDIR:-/tmp}/borg-probe.XXXXXX")" || return 1
        USER="$_user" BORG_NO_SPEND_RECORD=1 BORG_NO_SESSION_HOOKS=1 "$BORG_CLAUDE_BIN" -p "/usage" >"$_tmp" 2>&1 </dev/null &
        _pid=$!
        _ticks=$((BORG_RESUME_PROBE_TIMEOUT * 5))
        while kill -0 "$_pid" 2>/dev/null; do
            if [ "$_ticks" -le 0 ]; then
                kill "$_pid" 2>/dev/null
                wait "$_pid" 2>/dev/null
                rm -f "$_tmp"
                printf 'borg-resume probe: claude -p /usage timed out after %ss\n' "$BORG_RESUME_PROBE_TIMEOUT" >&2
                return 1
            fi
            sleep 0.2
            _ticks=$((_ticks - 1))
        done
        wait "$_pid" || _rc=$?
        _out="$(cat "$_tmp")"
        rm -f "$_tmp"
    fi
    if [ "$_rc" -ne 0 ]; then
        printf 'borg-resume probe: claude exited %s for /usage\n' "$_rc" >&2
        return 1
    fi

    [ -z "${BORG_RESUME_PROBE_VERBOSE:-}" ] || printf "%s\n" "$_out" | grep -E "Current session: [0-9]+% used" | head -1 >&2
    _pct="$(printf '%s\n' "$_out" | grep -oE 'Current session: [0-9]+% used' | head -1 | sed -E 's/^Current session: ([0-9]+)% used$/\1/')"
    case "$_pct" in
        "" | *[!0-9]*)
            # No session line. A cost summary ("Total cost:") instead of limits is the unmetered shape.
            if printf '%s\n' "$_out" | grep -qE '^Total cost:'; then
                mkdir -p "$_dir" 2>/dev/null &&
                    printf '{"at":%s,"session_pct":"unmetered"}\n' "$_now" | borg_resume_write_atomic "$_cache" 2>/dev/null
                printf 'unmetered\n'
                return 0
            fi
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
