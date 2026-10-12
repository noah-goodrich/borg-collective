#!/usr/bin/env bash
# resume-classify.sh -- pure classification helpers for borg-resume (slice S2).
#
# Source this file; it defines functions only and never exits. Needs bash 3.2+ and jq.
# Everything that depends on the clock reads BORG_RESUME_NOW_EPOCH (falls back to `date +%s`),
# so tests are deterministic.
#
#   resume_classify_error ERROR [TEXT]       -> "<class> <action>"
#   resume_parse_reset TEXT                  -> epoch of the reset, rc 1 when unparseable
#   resume_plan ERROR TEXT [ATTEMPT] [TRUNC] -> "<class> <action> <resume_at|->"
#   resume_is_interrupt_marker TEXT          -> rc 0 when TEXT is an interrupt marker
#   resume_record_is_interrupt JSON          -> rc 0 for a user record carrying the marker
#   resume_record_is_bookkeeping JSON        -> rc 0 for a bookkeeping (non-meaningful) record
#   resume_last_meaningful_record FILE [N]   -> last meaningful record of the last N lines (60)
#   resume_last_meaningful_with_close FILE [N] -> "<true|false><TAB><record>"; true when a turn_duration
#                                                 (clean turn close) follows that record
#   resume_last_meaningful_line FILE [N]     -> its 1-based line number in FILE
#   resume_tail_interrupted FILE [N]         -> rc 0 when that record is an interrupt marker
#   resume_synthetic_error JSON              -> "<error><TAB><text><TAB><truncated>" or rc 1
#
# Classes: usage_limit | transient | max_output_tokens | prompt_too_long | notify_only
# Actions: resume | backoff | compact_resume | notify

_rc_now() {
    if [ -n "${BORG_RESUME_NOW_EPOCH:-}" ]; then
        printf '%s\n' "$BORG_RESUME_NOW_EPOCH"
    else
        date +%s
    fi
}

_rc_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------------------------------------
# error string -> class, action
# ---------------------------------------------------------------------------------------------

resume_classify_error() {
    local err text low
    err="$(_rc_lower "${1:-}")"
    text="${2:-}"
    low="$(_rc_lower "$text")"

    case "$low" in
        *"spend limit"* | *"spending limit"* | *"monthly limit"* | *"monthly spend"* | *"team budget"* | \
            *"budget limit"* | *"budget has been"*)
            echo "notify_only notify"
            return 0
            ;;
    esac

    case "$err" in
        rate_limit)
            echo "usage_limit resume"
            ;;
        overloaded | server_error | unknown | timeout | connection_lost | stream_stalled)
            echo "transient backoff"
            ;;
        max_output_tokens)
            echo "max_output_tokens resume"
            ;;
        invalid_request)
            case "$low" in
                *"prompt is too long"*) echo "prompt_too_long compact_resume" ;;
                *) echo "notify_only notify" ;;
            esac
            ;;
        authentication_failed | oauth_org_not_allowed | account_on_hold | verification_required | billing_error | \
            cloud_credential_error | model_not_found)
            echo "notify_only notify"
            ;;
        *)
            # Unknown kinds fail closed: notify a human rather than retry something unclassified.
            printf 'borg-resume: unknown error kind %q, failing closed to notify_only\n' "${1:-}" >&2
            echo "notify_only notify"
            ;;
    esac
}

# ---------------------------------------------------------------------------------------------
# reset-text parser
# ---------------------------------------------------------------------------------------------

# True when `date -d` is the GNU flavour (BSD date has no -d for relative dates).
_rc_gnu_date() { date -d @0 +%s >/dev/null 2>&1; }

# _rc_fmt_in_zone ZONE EPOCH FORMAT
_rc_fmt_in_zone() {
    if [ -z "$1" ]; then
        # no zone: the machine's local zone
        if _rc_gnu_date; then date -d "@$2" "+$3"; else date -r "$2" "+$3"; fi
    elif _rc_gnu_date; then
        TZ="$1" date -d "@$2" "+$3"
    else
        TZ="$1" date -r "$2" "+$3"
    fi
}

# _rc_epoch_in_zone ZONE YYYY-MM-DD HH:MM  -> epoch
_rc_epoch_in_zone() {
    if [ -z "$1" ]; then
        # no zone: the machine's local zone
        if _rc_gnu_date; then
            date -d "$2 $3:00" +%s 2>/dev/null
        else
            date -j -f "%Y-%m-%d %H:%M:%S" "$2 $3:00" +%s 2>/dev/null
        fi
    elif _rc_gnu_date; then
        TZ="$1" date -d "$2 $3:00" +%s 2>/dev/null
    else
        TZ="$1" date -j -f "%Y-%m-%d %H:%M:%S" "$2 $3:00" +%s 2>/dev/null
    fi
}

# Map the short zone labels the CLI prints to IANA names; pass IANA names through.
_rc_zone_name() {
    case "$1" in
        MT | MST | MDT) echo "America/Denver" ;;
        PT | PST | PDT) echo "America/Los_Angeles" ;;
        CT | CST | CDT) echo "America/Chicago" ;;
        ET | EST | EDT) echo "America/New_York" ;;
        UTC | GMT | Z) echo "UTC" ;;
        *) echo "$1" ;;
    esac
}

_rc_zone_ok() {
    case "$1" in
        "" | *[!A-Za-z0-9_/+-]* | *..*) return 1 ;;
        UTC) return 0 ;;
    esac
    [ -f "/usr/share/zoneinfo/$1" ] || [ -f "/var/db/timezone/zoneinfo/$1" ]
}

_rc_month_num() {
    case "$(_rc_lower "$1")" in
        jan*) echo 1 ;; feb*) echo 2 ;; mar*) echo 3 ;; apr*) echo 4 ;;
        may*) echo 5 ;; jun*) echo 6 ;; jul*) echo 7 ;; aug*) echo 8 ;;
        sep*) echo 9 ;; oct*) echo 10 ;; nov*) echo 11 ;; dec*) echo 12 ;;
        *) return 1 ;;
    esac
}

# The duration after "resets in": "3 hours", "45 minutes", "1 hour 30 minutes", "2 days". Parses the
# leading run of "<N> <unit>" pairs only; anything after it (a window note, say) is ignored.
_rc_parse_relative() {
    local rest="$1" total=0 found=0 n unit mult
    local re='^[ ,]*(and +)?([0-9]+) *(day|hour|hr|minute|min|second|sec)s?(.*)$'
    while [[ "$rest" =~ $re ]]; do
        n="${BASH_REMATCH[2]}"
        unit="${BASH_REMATCH[3]}"
        rest="${BASH_REMATCH[4]}"
        case "$unit" in
            day) mult=86400 ;;
            hour | hr) mult=3600 ;;
            minute | min) mult=60 ;;
            *) mult=1 ;;
        esac
        total=$((total + 10#$n * mult))
        found=1
    done
    [ "$found" -eq 1 ] || return 1
    echo $(($(_rc_now) + total))
}

resume_parse_reset() {
    local text low now zone zname hour min ampm mon day year date_s cand tmrw
    text="${1:-}"
    low="$(_rc_lower "$text")"
    now="$(_rc_now)"

    case "$low" in
        *"resets in "*)
            _rc_parse_relative "${low#*resets in }"
            return $?
            ;;
        *"reset in "*)
            _rc_parse_relative "${low#*reset in }"
            return $?
            ;;
    esac

    local re_abs='resets? +(at +)?(([a-z]{3})[a-z]* +([0-9]{1,2}),? +(at +)?)?([0-9]{1,2})(:([0-9]{2}))? *(am|pm)'
    [[ "$low" =~ $re_abs ]] || return 1
    mon="${BASH_REMATCH[3]}"
    day="${BASH_REMATCH[4]}"
    hour="${BASH_REMATCH[6]}"
    min="${BASH_REMATCH[8]:-00}"
    ampm="${BASH_REMATCH[9]}"

    hour=$((10#$hour))
    [ "$hour" -ge 1 ] && [ "$hour" -le 12 ] || return 1
    [ $((10#$min)) -lt 60 ] || return 1
    if [ "$ampm" = "am" ]; then
        [ "$hour" -eq 12 ] && hour=0
    else
        [ "$hour" -lt 12 ] && hour=$((hour + 12))
    fi

    zone=""
    local re_zone='\(([^)]+)\)'
    if [[ "$text" =~ $re_zone ]]; then
        zone="${BASH_REMATCH[1]}"
    fi
    zname="$(_rc_zone_name "$zone")"
    if [ -n "$zone" ]; then
        _rc_zone_ok "$zname" || return 1
    else
        zname=""
    fi

    local hhmm
    hhmm="$(printf '%02d:%02d' "$hour" $((10#$min)))"
    year="$(_rc_fmt_in_zone "$zname" "$now" %Y)" || return 1

    if [ -n "$mon" ]; then
        local mnum
        mnum="$(_rc_month_num "$mon")" || return 1
        date_s="$(printf '%04d-%02d-%02d' "$year" "$mnum" $((10#$day)))"
        cand="$(_rc_epoch_in_zone "$zname" "$date_s" "$hhmm")" || return 1
        if [ "$cand" -le "$now" ]; then
            date_s="$(printf '%04d-%02d-%02d' $((year + 1)) "$mnum" $((10#$day)))"
            cand="$(_rc_epoch_in_zone "$zname" "$date_s" "$hhmm")" || return 1
        fi
    else
        date_s="$(_rc_fmt_in_zone "$zname" "$now" %Y-%m-%d)" || return 1
        cand="$(_rc_epoch_in_zone "$zname" "$date_s" "$hhmm")" || return 1
        if [ "$cand" -le "$now" ]; then
            tmrw="$(_rc_fmt_in_zone "$zname" $((now + 86400)) %Y-%m-%d)" || return 1
            cand="$(_rc_epoch_in_zone "$zname" "$tmrw" "$hhmm")" || return 1
        fi
    fi
    [ -n "$cand" ] || return 1
    echo "$cand"
}

# ---------------------------------------------------------------------------------------------
# plan: class + action + resume_at
# ---------------------------------------------------------------------------------------------

# Transient backoff steps in seconds; attempt 0-based. Past the last step: notify.
_rc_backoff_step() {
    case "$1" in
        0) echo 45 ;;
        1) echo 120 ;;
        2) echo 300 ;;
        3) echo 900 ;;
        *) return 1 ;;
    esac
}

resume_plan() {
    local err="${1:-}" text="${2:-}" attempt="${3:-0}" trunc="${4:-false}"
    local ca class action now reset step grace
    ca="$(resume_classify_error "$err" "$text")"
    class="${ca%% *}"
    action="${ca#* }"
    now="$(_rc_now)"
    grace="${BORG_RESUME_NATIVE_GRACE_SEC:-120}"
    case "$attempt" in '' | *[!0-9]*) attempt=0 ;; esac
    [ "$trunc" = "true" ] && attempt=0

    case "$class" in
        usage_limit)
            if reset="$(resume_parse_reset "$text")"; then
                echo "$class resume $((reset + grace))"
            elif step="$(_rc_backoff_step "$attempt")"; then
                echo "$class backoff $((now + step))"
            else
                echo "$class notify -"
            fi
            ;;
        transient)
            if step="$(_rc_backoff_step "$attempt")"; then
                echo "$class backoff $((now + step))"
            else
                echo "$class notify -"
            fi
            ;;
        max_output_tokens)
            echo "$class resume $((now + 15))"
            ;;
        prompt_too_long)
            echo "$class compact_resume $now"
            ;;
        *)
            echo "$class notify -"
            ;;
    esac
}

# ---------------------------------------------------------------------------------------------
# transcript helpers
# ---------------------------------------------------------------------------------------------

# Exact interrupt markers Claude Code writes as the text of a user record.
resume_is_interrupt_marker() {
    case "${1:-}" in
        "[Request interrupted by user]" | "[Request interrupted by user for tool use]") return 0 ;;
    esac
    return 1
}

# jq predicates shared by the record helpers. $r is one transcript record.
_RC_JQ_DEFS='
def texts: (.message.content // empty)
  | if type == "string" then [.] else [.[]? | select(type == "object" and .type == "text") | .text] end;
def is_interrupt: (.type == "user")
  and ([texts] | flatten
       | map(select(. == "[Request interrupted by user]" or . == "[Request interrupted by user for tool use]"))
       | length > 0);
def is_turn_close: .type == "system" and .subtype == "turn_duration";
def is_bookkeeping:
  (.type as $t
   | ["last-prompt","permission-mode","pr-link","cost-state","file-history-snapshot","attachment"]
   | index($t) != null)
  or (.type == "system" and .subtype == "stop_hook_summary")
  or is_turn_close;
'

resume_record_is_interrupt() {
    printf '%s' "${1:-}" | jq -e "$_RC_JQ_DEFS is_interrupt" >/dev/null 2>&1
}

# turn_duration is bookkeeping (skipped by last_meaningful_record: the real sleep-interrupted tail has one
# after the synthetic error). It is also the clean turn-close marker; resume_last_meaningful_with_close
# reports whether one follows the last meaningful record.
resume_record_is_clean_close() {
    printf '%s' "${1:-}" | jq -e "$_RC_JQ_DEFS is_turn_close" >/dev/null 2>&1
}

resume_record_is_bookkeeping() {
    printf '%s' "${1:-}" | jq -e "$_RC_JQ_DEFS is_bookkeeping" >/dev/null 2>&1
}

# "<close><TAB><lineno><TAB><json>" of the last meaningful record in the last N lines of FILE; close is
# 1 when a turn_duration record follows it, else 0.
_rc_last_meaningful() {
    local file="${1:-}" n="${2:-60}" total skip
    [ -f "$file" ] || return 1
    total="$(wc -l <"$file" | tr -d ' ')"
    # A final line without a trailing newline is not counted by wc -l.
    if [ -n "$(tail -c 1 "$file")" ]; then total=$((total + 1)); fi
    skip=$((total - n))
    [ "$skip" -lt 0 ] && skip=0
    tail -n "$n" "$file" | jq -R -r --argjson off "$skip" "$_RC_JQ_DEFS"'
        (try fromjson catch null) as $r
        | select($r != null and ($r | type) == "object")
        | if ($r | is_turn_close) then "C"
          elif ($r | is_bookkeeping) then empty
          else "M\t\(input_line_number + $off)\t\($r | tojson)" end' |
        awk -F '\t' '
            $1 == "M" { last = substr($0, 3); cc = 0 }
            $1 == "C" { cc = 1 }
            END { if (last != "") print cc "\t" last }'
}

resume_last_meaningful_record() {
    local out
    out="$(_rc_last_meaningful "$@")" || return 1
    [ -n "$out" ] || return 1
    out="${out#*$'\t'}"
    printf '%s\n' "${out#*$'\t'}"
}

resume_last_meaningful_line() {
    local out
    out="$(_rc_last_meaningful "$@")" || return 1
    [ -n "$out" ] || return 1
    out="${out#*$'\t'}"
    printf '%s\n' "${out%%$'\t'*}"
}

# "<true|false><TAB><record>": the last meaningful record plus trailing_clean_close.
resume_last_meaningful_with_close() {
    local out flag
    out="$(_rc_last_meaningful "$@")" || return 1
    [ -n "$out" ] || return 1
    flag=false
    [ "${out%%$'\t'*}" = "1" ] && flag=true
    out="${out#*$'\t'}"
    printf '%s\t%s\n' "$flag" "${out#*$'\t'}"
}

resume_tail_interrupted() {
    local rec
    rec="$(resume_last_meaningful_record "$@")" || return 1
    resume_record_is_interrupt "$rec"
}

# Synthetic API-error record -> "<error><TAB><text><TAB><truncatedAfterOutput>".
resume_synthetic_error() {
    printf '%s' "${1:-}" | jq -r -e 'select(.isApiErrorMessage == true)
        | [(.error // "unknown"),
           ([.message.content[]? | select(.type == "text") | .text] | join(" ")),
           ((.truncatedAfterOutput // false) | tostring)] | @tsv' 2>/dev/null
}
