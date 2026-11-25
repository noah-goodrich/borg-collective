#!/usr/bin/env bash
# usage-parse.sh -- one parser for `claude -p /usage`, shared by resume-probe.sh and bin/borg-usage-watch (#465).
#
# Claude Code changes the /usage layout between releases, so this parses by output SHAPE, never by version number.
# borg_usage_parse <text> prints one line "shape|session_pct|week_pct|resets_at" and always returns 0. Shapes:
#   session-line      "Current session: N% used [· resets T]" present: the session limit. pct is N.
#   unmetered         "Total cost:" cost summary and no limits: a usage-billed account (no session limit applies).
#   limits-breakdown  the newer "What's contributing to your limits usage?" page WITHOUT a session line. Its
#                     percentages are contribution shares, never the session limit, so pct stays empty.
#   unrecognized      none of the above: a format this parser has never seen. Callers must say so loudly.
# Every shape has a fixture under tests/fixtures/ (usage-output*.txt), so the next format change fails a test.
#
# Second source, for the limits-breakdown shape: the statusline JSON Claude Code pipes to a statusLine command carries
# rate_limits.five_hour.used_percentage (the session limit). bin/borg-statusline caches it (borg_usage_ratelimits_path);
# borg_usage_statusline_pct <now_epoch> prints "pct|resets" when that cache is fresh, else returns 1.
# Bash 3.2 safe; never exits the caller.

BORG_USAGE_STATUSLINE_MAX_AGE="${BORG_USAGE_STATUSLINE_MAX_AGE:-600}"

borg_usage_ratelimits_path() {
    printf '%s\n' "${BORG_USAGE_RATELIMITS_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/rate-limits.json}"
}

borg_usage_parse() {
    local _text="$1" _line _pct="" _week="" _resets="" _shape
    _line="$(printf '%s\n' "$_text" | grep -oE 'Current session: [0-9]+% used( · resets [^(]+)?' | head -1)" || _line=""
    if [ -n "$_line" ]; then
        _shape=session-line
        _pct="$(printf '%s\n' "$_line" | sed -E 's/^Current session: ([0-9]+)% used.*$/\1/')"
        _resets="$(printf '%s\n' "$_line" | sed -E -n 's/^Current session: [0-9]+% used · resets (.+)$/\1/p' | sed -E 's/ +$//')"
        _week="$(printf '%s\n' "$_text" | grep -oE 'Current week \(all models\): [0-9]+% used' | head -1 |
            sed -E 's/^Current week \(all models\): ([0-9]+)% used$/\1/')" || _week=""
    elif printf '%s\n' "$_text" | grep -qE '^Total cost:'; then
        _shape=unmetered
    elif printf '%s\n' "$_text" | grep -qF "What's contributing to your limits usage?"; then
        _shape=limits-breakdown
    else
        _shape=unrecognized
    fi
    printf '%s|%s|%s|%s\n' "$_shape" "$_pct" "$_week" "$_resets"
    return 0
}

# Prints "pct|resets_at|week_pct" from the statusline cache when it is fresh and sane, else returns 1.
borg_usage_statusline_pct() {
    local _now="${1:-}" _f _at _pct _resets _week
    case "$_now" in "" | *[!0-9]*) _now="$(date +%s)" ;; esac
    _f="$(borg_usage_ratelimits_path)"
    [ -f "$_f" ] && command -v jq >/dev/null 2>&1 || return 1
    _at="$(jq -r '.at // empty' "$_f" 2>/dev/null)"
    _pct="$(jq -r '.five_hour_pct // empty | floor' "$_f" 2>/dev/null)"
    _week="$(jq -r '.seven_day_pct // empty | floor' "$_f" 2>/dev/null)"
    _resets="$(jq -r '.five_hour_resets_at // empty' "$_f" 2>/dev/null)"
    case "$_at" in "" | *[!0-9]*) return 1 ;; esac
    case "$_pct" in "" | *[!0-9]*) return 1 ;; esac
    [ "$_pct" -le 100 ] || return 1
    [ "$_at" -le "$_now" ] && [ $((_now - _at)) -le "$BORG_USAGE_STATUSLINE_MAX_AGE" ] || return 1
    case "$_week" in *[!0-9]*) _week="" ;; esac
    printf '%s|%s|%s\n' "$_pct" "$_resets" "$_week"
}
