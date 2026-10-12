#!/usr/bin/env bash
# resume-verbs.sh -- the ack and defer verbs of borg-resume (slice S7b).
#
# Sourced by bin/borg-resume after resume-paths.sh. Bash 3.2 safe, jq is the only non-coreutils dependency.
#
#   borg_resume_ack <rid>
#   borg_resume_defer <rid> [<until>] [--until <until>] [--reason <word>]
#
# Both verbs only APPEND one fact to events/<sid>.jsonl (the sid comes from the record); the watcher owns every
# state transition and folds them (resume-watch.sh: ack -> _rw_has_ack, defer -> _rw_fold_defers). The syntax is
# exactly what the S6 prompt renderer tells the model to run: `borg-resume ack <rid>` and
# `borg-resume defer <rid> --reason <word>`; <until> is an extra for humans and the S9 gate.
#
# Event payloads (one compact JSON line each):
#   ack:   {"t":<epoch>,"ev":"ack","sid":"<sid>","scope":"<scope>","rid":"<rid>"}
#   defer: {"t":<epoch>,"ev":"defer","sid":"<sid>","scope":"<scope>","rid":"<rid>","until":<epoch>?,"reason":"<w>"?}
# <until> is an absolute epoch or a relative +N[smhd] resolved against the clock at call time.
#
# Exit codes: 0 recorded (or BORG_RESUME_DISABLE=1, a silent no-op), 1 no such record / cannot write, 2 usage.

_bv_now() {
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) date +%s ;;
        *) printf '%s\n' "$BORG_RESUME_NOW_EPOCH" ;;
    esac
}

_bv_valid_rid() {
    case "${1:-}" in
        "" | *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    [ "${#1}" -le 64 ]
}

# Record file for a rid: pending/ first, then done/.
_bv_find_record() {
    local _f
    for _f in "$(borg_resume_dir)/pending/$1.json" "$(borg_resume_dir)/done/$1.json"; do
        if [ -f "$_f" ]; then
            printf '%s\n' "$_f"
            return 0
        fi
    done
    return 1
}

# Resolve an until argument to an absolute epoch on stdout; non-zero when malformed.
_bv_parse_until() {
    local _u="$1" _n _unit _mul
    case "$_u" in
        +[0-9]*[smhd])
            _unit="${_u: -1}"
            _n="${_u#+}"
            _n="${_n%"$_unit"}"
            case "$_n" in "" | *[!0-9]*) return 1 ;; esac
            [ "${#_n}" -le 9 ] || return 1
            case "$_unit" in s) _mul=1 ;; m) _mul=60 ;; h) _mul=3600 ;; *) _mul=86400 ;; esac
            printf '%s\n' $(($(_bv_now) + 10#$_n * _mul))
            ;;
        "" | *[!0-9]*) return 1 ;;
        *)
            [ "${#_u}" -le 12 ] || return 1
            printf '%s\n' "$_u"
            ;;
    esac
}

# Append the event for record <rf>: _bv_emit <ev> <rf> [until] [reason]
_bv_emit() {
    local _ev="$1" _rf="$2" _until="${3:-}" _reason="${4:-}" _line
    _line="$(jq -c -n --arg ev "$_ev" --argjson t "$(_bv_now)" --arg until "$_until" --arg reason "$_reason" \
        --slurpfile r "$_rf" '
        ($r[0]) as $rec
        | select(($rec.sid | type) == "string")
        | {t: $t, ev: $ev, sid: $rec.sid, scope: ($rec.scope // "main"), rid: $rec.rid}
        + (if $until == "" then {} else {until: ($until | tonumber)} end)
        + (if $reason == "" then {} else {reason: $reason[0:64]} end)' 2>/dev/null)"
    [ -n "$_line" ] || return 1
    borg_resume_valid_sid "$(printf '%s' "$_line" | jq -r .sid)" || return 1
    borg_resume_append_line "$(borg_resume_events_file "$(printf '%s' "$_line" | jq -r .sid)")" "$_line"
}


# Find the record and append the event; one retry covers the watcher moving pending/ -> done/ between the two steps.
_bv_record_event() { # <ev> <rid> [until] [reason]
    local _rf _try=0
    while [ "$_try" -lt 2 ]; do
        if _rf="$(_bv_find_record "$2")" && _bv_emit "$1" "$_rf" "${3:-}" "${4:-}"; then
            return 0
        fi
        _try=$((_try + 1))
        sleep 0.1 2>/dev/null
    done
    return 1
}

borg_resume_ack() {
    local _rid="${1:-}"
    _bv_valid_rid "$_rid" && [ $# -eq 1 ] || return 2
    borg_resume_disabled_env && return 0
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }
    _bv_record_event ack "$_rid" || { printf 'borg-resume: could not record the ack for %s\n' "$_rid" >&2; return 1; }
    return 0
}

borg_resume_defer() {
    local _rid="${1:-}" _until="" _reason="" _a _resolved _have_until=0
    _bv_valid_rid "$_rid" || return 2
    shift
    while [ $# -gt 0 ]; do
        _a="$1"
        shift
        case "$_a" in
            --reason)
                [ $# -gt 0 ] || return 2
                _reason="$1"
                shift
                ;;
            --until)
                [ $# -gt 0 ] && [ "$_have_until" -eq 0 ] || return 2
                _until="$1"
                _have_until=1
                shift
                ;;
            -*) return 2 ;;
            *)
                [ "$_have_until" -eq 0 ] || return 2
                _until="$_a"
                _have_until=1
                ;;
        esac
    done
    if [ "$_have_until" -eq 1 ]; then
        _resolved="$(_bv_parse_until "$_until")" || return 2
        _until="$_resolved"
    fi
    # The caller is a model: never lose a defer over free text. Squash to the safe charset and cap the length.
    _reason="$(printf '%s' "$_reason" | tr -c 'A-Za-z0-9_.:-' '_' | cut -c1-64)"
    borg_resume_disabled_env && return 0
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }
    _bv_record_event defer "$_rid" "$_until" "$_reason" || {
        printf 'borg-resume: could not record the defer for %s\n' "$_rid" >&2
        return 1
    }
    return 0
}
