#!/usr/bin/env bash
# resume-cli.sh -- the status, cancel and run verbs of borg-resume (slice S14).
#
# Sourced by bin/borg-resume after resume-paths.sh (and, for the watcher fold, by resume-watch.sh). Bash 3.2 safe,
# jq is the only non-coreutils dependency. Functions only; sourcing prints nothing. Needs resume-verbs.sh helpers
# (_bv_*), which it sources itself.
#
#   borg_resume_status [--json] [--all]       records grouped by state, kill-switch state, readable in a narrow pane
#   borg_resume_cancel <rid> | --session <sid> | --all
#   borg_resume_run <rid> [--force]           make a record due now and run ONE watcher pass; prints the gate decision
#   borg_resume_cli_fold <sid>                watcher side: fold `cancel` and `run` events of one session
#
# Single-writer rule: cancel and run only APPEND one fact to events/<sid>.jsonl; the watcher
# (borg_resume_cli_fold, called from borg_resume_watch_once) owns the transition. `run` then triggers one
# ordinary watcher pass, so the record still goes through the full S9 gate and the S8 idle proof: there is no
# bypass, and the DISABLED sentinel and BORG_RESUME_DISABLE=1 keep winning. pause and unpause are S1's and stay in
# bin/borg-resume.
#
# Event payloads (same shape as ack and defer, see resume-verbs.sh):
#   cancel: {"t":..,"ev":"cancel","sid":..,"scope":..,"rid":..,"reason":"user"}
#   run:    {"t":..,"ev":"run","sid":..,"scope":..,"rid":..,"reason":"force"?}
#
# Fold rules: cancel moves an ACTIVE record to the terminal `cancelled` (done_reason user_cancel); it stays in done/
# with its evidence uuid, which is what blocks the scan from re-creating it. run moves a new/scheduled/deferred
# record to scheduled with resume_at = min(resume_at, now) and drops gate_next; a terminal expired, capped,
# notify_only, stalled, failed or cancelled record in done/ is revived into pending/ the same way; done and
# superseded records are never revived. run stamps run_at (rebases the gate
# age clock and 7-day ceiling). run --force resets only consecutive, and only for a consecutive_cap record.
#
# Exit codes: 0 ok (or BORG_RESUME_DISABLE=1, a no-op with a message), 1 no such record / nothing to do / cannot
# write, 2 usage.

# shellcheck disable=SC2016
_RCLI_DIR="${BORG_RESUME_LIBDIR:-${BASH_SOURCE[0]%/*}}"
# shellcheck source=/dev/null
command -v _bv_record_event >/dev/null 2>&1 || . "$_RCLI_DIR/resume-verbs.sh" 2>/dev/null

_RCLI_TERMINAL="done superseded cancelled capped notify_only expired failed stalled"
_RCLI_ACTIVE="new scheduled deferred injecting injected confirmed"

_rcli_in() { # <word> <list>
    case " $2 " in *" $1 "*) return 0 ;; esac
    return 1
}

_rcli_off_message() {
    printf 'borg-resume: BORG_RESUME_DISABLE=1 is set: borg-resume is off entirely, nothing was queued\n'
}

# ---------------------------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------------------------

# Build the status document as JSON on stdout.
_rcli_status_json() { # <show-all 0|1>
    local _d _now _hours _files _regs _paused _off
    _d="$(borg_resume_dir)"
    _now="$(_bv_now)"
    _hours="${BORG_RESUME_STATUS_HOURS:-24}"
    case "$_hours" in "" | *[!0-9]*) _hours=24 ;; esac
    _paused=false
    borg_resume_paused && _paused=true
    _off=false
    borg_resume_disabled_env && _off=true
    local _g
    _files=()
    _regs=()
    for _g in "$_d"/pending/*.json "$_d"/done/*.json; do
        [ -f "$_g" ] && _files+=("$_g")
    done
    for _g in "$_d"/sessions/*.json; do
        [ -f "$_g" ] && _regs+=("$_g")
    done
    local _projects='{}' _recs='[]'
    if [ "${#_regs[@]}" -gt 0 ]; then
        _projects="$(jq -c -s 'map(select(.session_id != null) | {(.session_id): (.project // .tmux.window)})
            | add // {}' "${_regs[@]}" 2>/dev/null)"
    fi
    [ -n "$_projects" ] || _projects='{}'
    if [ "${#_files[@]}" -gt 0 ]; then
        _recs="$(jq -c -s '.' "${_files[@]}" 2>/dev/null)"
    fi
    [ -n "$_recs" ] || _recs='[]'
    jq -n -c --argjson recs "$_recs" --argjson proj "$_projects" --argjson now "$_now" --argjson hours "$_hours" \
        --argjson all "$1" --argjson paused "$_paused" --argjson off "$_off" '
        def active: IN("new", "scheduled", "deferred", "injecting", "injected", "confirmed");
        def order: {injecting: 0, injected: 1, confirmed: 2, scheduled: 3, new: 4, deferred: 5, stalled: 6,
                    failed: 7, capped: 8, expired: 9, notify_only: 10, cancelled: 11, superseded: 12, done: 13};
        [ $recs[] | select(type == "object" and (.rid | type) == "string")
          | ((.state_log // []) | last // []) as $last
          | {rid, sid, scope: (.scope // "main"), project: ($proj[.sid] // null), class: (.class // null),
             state: (.state // "unknown"), cause: (.cause // .error // null), resume_at: (.resume_at // null),
             due_in: (if (.resume_at // null) == null then null else .resume_at - $now end),
             last_reason: (.gate_reason // .done_reason // $last[2] // null),
             last_t: ($last[1] // .first_seen // 0), first_seen: (.first_seen // null)}
          | select($all == 1 or (.state | active) or (.last_t >= $now - $hours * 3600)) ]
        | sort_by([(.state as $s | order[$s] // 99), (.resume_at // 0), .rid]) as $r
        | {paused: $paused, disabled_env: $off, now: $now, counts: ($r | group_by(.state)
               | map({key: .[0].state, value: length}) | from_entries), records: $r}'
}

_rcli_status_text() { # <document-json>
    local _doc="$1" _head
    _head="running"
    case "$_doc" in *'"paused":true'*) _head="PAUSED (sentinel set: nothing injects, recording continues)" ;; esac
    case "$_doc" in *'"disabled_env":true'*) _head="DISABLED (BORG_RESUME_DISABLE=1: everything is off)" ;; esac
    printf 'borg-resume: %s\n' "$_head"
    printf '%s' "$_doc" | jq -r '
        def short($n): if . == null then "-" else tostring | .[0:$n] end;
        def when: if . == null then "-" else strflocaltime("%a %b %d %H:%M") end;
        def rel($d): if $d == null then "" elif ($d | fabs) < 5 then "now"
            else (($d | fabs) as $a
                  | (if $a < 120 then "\($a | floor)s" elif $a < 7200 then "\(($a / 60) | floor)m"
                     elif $a < 172800 then "\(($a / 3600) | floor)h" else "\(($a / 86400) | floor)d" end) as $s
                  | if $d > 0 then "in \($s)" else "\($s) ago" end) end;
        def active: IN("new", "scheduled", "deferred", "injecting", "injected", "confirmed");
        (if (.records | length) == 0 then "no records" else
            (reduce .records[] as $r ([]; if (length > 0 and .[-1].state == $r.state)
                then (.[-1].items += [$r]) else . + [{state: $r.state, items: [$r]}] end)
             | .[] | "", "\(.state) (\(.items | length))",
               (.items[] | "  \(.rid)  \(.project | short(20))  \(.class | short(16))",
                  (if .scope != "main" then "    scope  \(.scope | short(40))" else empty end),
                  "    cause  \(.cause | short(40))",
                  (if (.state | active) and .resume_at != null
                   then "    due    \(.resume_at | when) (\(rel(.due_in)))" else empty end),
                  (if .last_reason != null then "    last   \(.last_reason | short(44))" else empty end)))
         end)'
}

borg_resume_status() {
    local _json=0 _all=0 _a _doc
    for _a in "$@"; do
        case "$_a" in
            --json) _json=1 ;;
            --all) _all=1 ;;
            *) return 2 ;;
        esac
    done
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }
    _doc="$(_rcli_status_json "$_all")"
    [ -n "$_doc" ] || { printf 'borg-resume: cannot read the ledger\n' >&2; return 1; }
    if [ "$_json" -eq 1 ]; then
        printf '%s\n' "$_doc"
    else
        _rcli_status_text "$_doc"
    fi
}

# ---------------------------------------------------------------------------------------------
# cancel
# ---------------------------------------------------------------------------------------------

_rcli_no_record() {
    printf 'borg-resume: no such record: %s (list them with: borg resume status --all)\n' "$1" >&2
}

borg_resume_cancel() {
    local _rid="" _sid="" _all=0 _a _rf _st _n=0 _f
    while [ $# -gt 0 ]; do
        _a="$1"
        shift
        case "$_a" in
            --all) _all=1 ;;
            --session)
                [ $# -gt 0 ] || return 2
                _sid="$1"
                shift
                borg_resume_valid_sid "$_sid" || return 2
                ;;
            -*) return 2 ;;
            *)
                [ -z "$_rid" ] || return 2
                _rid="$_a"
                ;;
        esac
    done
    # Exactly one target form.
    if [ -n "$_rid" ]; then
        [ -z "$_sid" ] && [ "$_all" -eq 0 ] && _bv_valid_rid "$_rid" || return 2
    else
        [ -n "$_sid" ] || [ "$_all" -eq 1 ] || return 2
        [ -z "$_sid" ] || [ "$_all" -eq 0 ] || return 2
    fi
    if borg_resume_disabled_env; then
        _rcli_off_message
        return 0
    fi
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }

    if [ -n "$_rid" ]; then
        _rf="$(_bv_find_record "$_rid")" || { _rcli_no_record "$_rid"; return 1; }
        _st="$(jq -r .state "$_rf" 2>/dev/null)"
        if _rcli_in "$_st" "$_RCLI_TERMINAL"; then
            printf 'borg-resume: %s is already %s, nothing to cancel\n' "$_rid" "$_st"
            return 0
        fi
        _bv_record_event cancel "$_rid" "" user || {
            printf 'borg-resume: could not record the cancel for %s\n' "$_rid" >&2
            return 1
        }
        printf 'borg-resume: cancel requested for %s (was %s); the watcher applies it on its next pass\n' "$_rid" "$_st"
        return 0
    fi

    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        _st="$(jq -r .state "$_f" 2>/dev/null)"
        _rcli_in "$_st" "$_RCLI_ACTIVE" || continue
        [ -z "$_sid" ] || [ "$(jq -r .sid "$_f" 2>/dev/null)" = "$_sid" ] || continue
        _bv_emit cancel "$_f" "" user && _n=$((_n + 1))
    done
    if [ "$_n" -eq 0 ]; then
        printf 'borg-resume: no active records to cancel\n'
    else
        printf 'borg-resume: cancel requested for %s record(s); the watcher applies it on its next pass\n' "$_n"
    fi
    return 0
}

# ---------------------------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------------------------

_rcli_load_watcher() {
    local _l
    for _l in resume-classify.sh resume-inventory.sh resume-watch.sh resume-prompt.sh resume-gate.sh; do
        # shellcheck source=/dev/null
        . "$BORG_RESUME_LIBDIR/$_l" 2>/dev/null || return 1
    done
}

# Print what the gate decided for <rid> after the pass.
_rcli_decision() {
    local _rid="$1" _rf _line _st _gr _dr _cls _sid _sf _ra _now
    _rf="$(_bv_find_record "$_rid")" || { printf '%s: record not found after the pass\n' "$_rid"; return 0; }
    _line="$(jq -r '[.state, (.gate_reason // ""), (.done_reason // ""), (.class // ""), .sid, (.resume_at // 0)]
        | map(tostring) | join("\u001f")' "$_rf" 2>/dev/null)"
    IFS=$'\037' read -r _st _gr _dr _cls _sid _ra <<EOF
$_line
EOF
    _now="$(_bv_now)"
    case "$_st" in
        injecting | injected | confirmed)
            printf '%s: %s (the gate passed, the idle proof held and the resume line was sent)\n' "$_rid" "$_st"
            ;;
        deferred)
            printf '%s: deferred (%s), the gate keeps retrying; cancel with: borg resume cancel %s\n' \
                "$_rid" "${_gr:-waiting}" "$_rid"
            ;;
        scheduled | new)
            if borg_resume_paused; then
                printf '%s: due, but paused (DISABLED sentinel); nothing injects. Resume: borg resume unpause\n' \
                    "$_rid"
            elif [ "$_ra" -gt "$_now" ]; then
                printf '%s: queued; the watcher is busy and applies it on its next pass\n' "$_rid"
            else
                printf '%s: due, held by the gate this pass%s; see: borg resume status\n' "$_rid" "${_gr:+ ($_gr)}"
            fi
            ;;
        *)
            printf '%s: %s (%s)\n' "$_rid" "$_st" "${_dr:-${_gr:-no reason recorded}}"
            case "$_dr" in
                container_session)
                    printf 'container sessions cannot be injected from the host; by hand: claude --resume %s\n' \
                        "$_sid"
                    ;;
                consecutive_cap) printf 'force one more attempt with: borg resume run %s --force\n' "$_rid" ;;
            esac
            ;;
    esac
}

borg_resume_run() {
    local _rid="" _force="" _a _rf _st
    while [ $# -gt 0 ]; do
        _a="$1"
        shift
        case "$_a" in
            --force) _force=force ;;
            -*) return 2 ;;
            *)
                [ -z "$_rid" ] || return 2
                _rid="$_a"
                ;;
        esac
    done
    _bv_valid_rid "$_rid" || return 2
    if borg_resume_disabled_env; then
        _rcli_off_message
        return 0
    fi
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }
    _rf="$(_bv_find_record "$_rid")" || { _rcli_no_record "$_rid"; return 1; }
    _st="$(jq -r .state "$_rf" 2>/dev/null)"
    case "$_st" in
        done | superseded)
            printf 'borg-resume: nothing to resume: %s is %s\n' "$_rid" "$_st" >&2
            return 1
            ;;
        injecting | injected | confirmed)
            printf 'borg-resume: %s is already in flight (%s)\n' "$_rid" "$_st"
            return 0
            ;;
    esac
    _bv_record_event run "$_rid" "" "$_force" || {
        printf 'borg-resume: could not record the run request for %s\n' "$_rid" >&2
        return 1
    }
    _rcli_load_watcher || { printf 'borg-resume: cannot load the watcher libraries\n' >&2; return 1; }
    borg_resume_watch_once >/dev/null
    _rcli_decision "$_rid"
    return 0
}

# ---------------------------------------------------------------------------------------------
# watcher side: fold cancel and run events (called from borg_resume_watch_once, once per session per pass)
# ---------------------------------------------------------------------------------------------

# Revive or reschedule one record for a run event. $1 sid, $2 rid, $3 force flag.
_rcli_apply_run() {
    local _sid="$1" _rid="$2" _force="$3" _pf _df _now _st _prev="" _revived=0
    _now="$(_rc_now)"
    _pf="$(borg_resume_dir)/pending/$_rid.json"
    _df="$(borg_resume_dir)/done/$_rid.json"
    if [ -f "$_pf" ]; then
        [ "$(jq -r .sid "$_pf" 2>/dev/null)" = "$_sid" ] || return 0
        case "$(jq -r .state "$_pf" 2>/dev/null)" in new | scheduled | deferred) ;; *) return 0 ;; esac
    elif [ -f "$_df" ]; then
        [ "$(jq -r .sid "$_df" 2>/dev/null)" = "$_sid" ] || return 0
        _st="$(jq -r .state "$_df" 2>/dev/null)"
        case "$_st" in expired | capped | notify_only | stalled | failed | cancelled) ;; *) return 0 ;; esac
        _prev="$(jq -r '.done_reason // ""' "$_df" 2>/dev/null)"
        cp -f "$_df" "$_pf" 2>/dev/null || return 1
        _revived=1
    else
        return 0
    fi
    # run_at rebases the gate age clock (and the 7-day ceiling), so an age-expired record is not re-expired at once;
    # a record revived from done/ is due now rather than at its old resume_at.
    _rw_update "$_pf" --argjson now "$_now" --argjson rv "$_revived" '
        .state = "scheduled"
        | .resume_at = (if $rv == 1 then $now else ([(.resume_at // $now), $now] | min) end)
        | del(.gate_next, .gate_reason, .lead, .done_reason)
        | .run_at = $now
        | .run_count = ((.run_count // 0) + 1)
        | .state_log = ((.state_log + [["scheduled", $now, "run"]])[-40:])' || return 1
    rm -f "$_df" 2>/dev/null
    # --force only lifts the 3-consecutive cap, and only for a record that was stopped by it. The daily cap is hard:
    # injections_today is never touched here.
    if [ "$_force" = force ] && [ "$_prev" = consecutive_cap ]; then
        _rw_state_ensure "$_sid"
        _rw_update "$(_rw_state_file "$_sid")" '.consecutive = 0' || return 1
    fi
    _rw_log "run applied $_rid force=${_force:-no}"
    return 0
}

_rcli_apply_cancel() { # <sid> <rid>
    local _f _now
    _f="$(borg_resume_dir)/pending/$2.json"
    [ -f "$_f" ] || return 0
    [ "$(jq -r .sid "$_f" 2>/dev/null)" = "$1" ] || return 0
    _rcli_in "$(jq -r .state "$_f" 2>/dev/null)" "$_RCLI_ACTIVE" || return 0
    _now="$(_rc_now)"
    _rw_update "$_f" --argjson now "$_now" '.state = "cancelled" | .done_reason = "user_cancel"
        | .state_log = ((.state_log + [["cancelled", $now, "user_cancel"]])[-40:])' || return 1
    _rw_log "cancel applied $2"
    return 0
}

borg_resume_cli_fold() {
    local _sid="$1" _ef _sf _cursor _total _lines _line _n _ev _rid _reason _applied
    _ef="$(borg_resume_events_file "$_sid")"
    [ -f "$_ef" ] || return 0
    _sf="$(_rw_state_file "$_sid")"
    _cursor=0
    [ -f "$_sf" ] && _cursor="$(jq -r '.cli_cursor // 0' "$_sf" 2>/dev/null)"
    case "$_cursor" in "" | *[!0-9]*) _cursor=0 ;; esac
    _total="$(wc -l <"$_ef" | tr -d ' ')"
    [ "$_total" -gt "$_cursor" ] || return 0
    _lines="$(tail -n +$((_cursor + 1)) "$_ef" | head -n $((_total - _cursor)) |
        jq -c -R 'input_line_number as $n | (fromjson? // empty)
            | select(type == "object" and (.ev == "cancel" or .ev == "run") and (.rid | type) == "string")
            | . + {_n: $n}' 2>/dev/null)"
    if [ -z "$_lines" ]; then
        [ -f "$_sf" ] && _rw_update "$_sf" --argjson c "$_total" '.cli_cursor = $c'
        return 0
    fi
    _rw_state_ensure "$_sid"
    _applied=$_total
    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        _n="$(printf '%s' "$_line" | jq -r ._n)"
        _ev="$(printf '%s' "$_line" | jq -r .ev)"
        _rid="$(printf '%s' "$_line" | jq -r .rid)"
        _reason="$(printf '%s' "$_line" | jq -r '.reason // empty')"
        _bv_valid_rid "$_rid" || continue
        if [ "$_ev" = cancel ]; then
            _rcli_apply_cancel "$_sid" "$_rid" || { _applied=$((_cursor + _n - 1)); break; }
        else
            _rcli_apply_run "$_sid" "$_rid" "$_reason" || { _applied=$((_cursor + _n - 1)); break; }
        fi
    done <<EOF
$_lines
EOF
    _rw_update "$_sf" --argjson c "$_applied" '.cli_cursor = $c'
    return 0
}
