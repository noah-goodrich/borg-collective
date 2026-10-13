#!/usr/bin/env bash
# resume-watch.sh -- watcher fold + scan for borg-resume (slice S7).
#
# Sourced by bin/borg-resume after resume-paths.sh, resume-classify.sh and resume-inventory.sh. Bash 3.2 safe.
# Functions only; sourcing prints nothing.
#
#   borg_resume_watch_once   one watcher pass: lock, fold hook events, scan transcripts/manifests, run the
#                            confirmed -> done rules, move terminal records to done/, apply ledger retention.
#
# The watcher OWNS every state transition and counter (pending/, done/, state/<sid>.json, watch.log). Two
# detectors feed it and converge on ONE record per (session, scope): hook events (the accelerator) and a
# transcript/manifest scan (ground truth). The idempotency key is the evidence uuid: an error whose uuid is
# already attached to any record, active or terminal, creates nothing. A later error with a new uuid merges
# into an ACTIVE record (new, scheduled, deferred, injecting, injected) and starts a fresh record when the
# existing one is confirmed or terminal.
#
# Deliberate ends (a trailing "[Request interrupted by user*]" marker as the last MEANINGFUL record) never
# create a record; an open not-yet-injected record for that scope is closed as cancelled with
# reason interrupted_by_user. The error test deliberately looks for a synthetic error record and not only at
# trailing_clean_close: an error followed by a turn_duration record is still an interruption.
#
# Not here (later slices): injection (S8), the pre-flight gate and supersede checks (S9), liveness of dead
# processes and panes (S10), launchd install (S12). The ack/defer verbs (S7b, lib/borg/resume-verbs.sh) append
# `ack` and `defer` events: an ack closes a confirmed record (_rw_has_ack), a defer reschedules (_rw_fold_defers).
#
# Env: BORG_RESUME_RETAIN_DAYS (14, floored at 4 so it always exceeds the 72h scan window),
# BORG_RESUME_CONFIRM_DONE_SEC (1800), BORG_RESUME_CONFIRM_PROGRESS_LINES (25), BORG_RESUME_SCAN_HOURS (72),
# BORG_RESUME_DEFER_SEC (900), BORG_RESUME_DEFER_MAX (3), BORG_RESUME_MAX_AGE_HOURS (48; defer ceiling).

# shellcheck disable=SC2016
_RW_ACTIVE='"new","scheduled","deferred","injecting","injected","confirmed"'
_RW_MERGEABLE='"new","scheduled","deferred","injecting","injected"'

_RW_SEP=$'\037'
_rw_n_created=0
_rw_n_merged=0
_rw_n_closed=0
_rw_n_done=0

_rw_log() {
    local _f
    _f="$(borg_resume_dir)/watch.log"
    mkdir -p "${_f%/*}" 2>/dev/null
    printf '%s %s\n' "$(_rc_now)" "$*" >>"$_f" 2>/dev/null
    return 0
}

# Rotate watch.log at 1MiB (one generation kept).
_rw_log_rotate() {
    local _f _sz
    _f="$(borg_resume_dir)/watch.log"
    [ -f "$_f" ] || return 0
    _sz="$(wc -c <"$_f" 2>/dev/null | tr -d ' ')"
    case "$_sz" in "" | *[!0-9]*) return 0 ;; esac
    if [ "$_sz" -gt 1048576 ]; then
        mv -f "$_f" "$_f.1" 2>/dev/null
    fi
    return 0
}

# ---------------------------------------------------------------------------------------------
# single-instance lock: mkdir is atomic; the pid inside is stale-checked
# ---------------------------------------------------------------------------------------------

_rw_lockdir() { printf '%s/.watch.lock\n' "$(borg_resume_dir)"; }

_rw_lock() {
    local _d _p _age
    _d="$(_rw_lockdir)"
    mkdir -p "${_d%/*}" 2>/dev/null || return 1
    if ! mkdir "$_d" 2>/dev/null; then
        _p="$(cat "$_d/pid" 2>/dev/null)"
        case "$_p" in
            "")
                # A holder that has not written its pid yet: young lock dirs are live, older ones are junk.
                _age=$(($(date +%s) - $(_ri_mtime "$_d")))
                [ "$_age" -lt 10 ] && return 1
                ;;
            *[!0-9]*) ;;
            *) kill -0 "$_p" 2>/dev/null && return 1 ;;
        esac
        rm -rf "$_d" 2>/dev/null
        mkdir "$_d" 2>/dev/null || return 1
    fi
    printf '%s\n' "$$" >"$_d/pid"
    return 0
}

_rw_unlock() {
    local _d
    _d="$(_rw_lockdir)"
    if [ "$(cat "$_d/pid" 2>/dev/null)" = "$$" ]; then
        rm -rf "$_d" 2>/dev/null
    fi
    return 0
}

# ---------------------------------------------------------------------------------------------
# record helpers
# ---------------------------------------------------------------------------------------------

# Rewrite a JSON file through jq: _rw_update <file> [jq args...] <filter>
_rw_update() {
    local _f="$1" _out
    shift
    _out="$(jq -c "$@" "$_f" 2>/dev/null)" || return 1
    [ -n "$_out" ] || return 1
    printf '%s\n' "$_out" | borg_resume_write_atomic "$_f"
}

# Newline-separated *.json files of a ledger subdir (pending or done).
_rw_files() {
    local _f
    for _f in "$(borg_resume_dir)/$1"/*.json; do
        [ -f "$_f" ] && printf '%s\n' "$_f"
    done
    return 0
}

_rw_all_files() {
    _rw_files pending
    _rw_files "done"
}

# First record file whose evidence holds this uuid, pending or done.
_rw_find_uuid() {
    local _u="$1" _files
    _files="$(_rw_all_files)"
    [ -n "$_files" ] || return 1
    printf '%s\n' "$_files" | tr '\n' '\0' | xargs -0 jq -r --arg u "$_u" '
        select(((.evidence.uuids // []) + [.evidence.uuid // empty]) | index($u) != null) | input_filename
    ' 2>/dev/null | head -n 1 | grep .
}

# The MERGEABLE record file for (sid, scope), if any. A confirmed record is excluded on purpose: it awaits its
# done rules and another record of the scope may be the real merge target.
_rw_find_active() {
    local _s="$1" _c="$2" _files
    _files="$(_rw_files pending)"
    [ -n "$_files" ] || return 1
    printf '%s\n' "$_files" | tr '\n' '\0' | xargs -0 jq -r --arg s "$_s" --arg c "$_c" "
        select(.sid == \$s and .scope == \$c and (.state | IN($_RW_MERGEABLE))) | input_filename
    " 2>/dev/null | head -n 1 | grep .
}

# A recent uuid-less notify_only record (hook-only evidence) in done/ for (sid, scope), if any.
_rw_find_uuidless_notify() {
    local _s="$1" _c="$2" _t="$3" _files
    _files="$(_rw_files "done")"
    [ -n "$_files" ] || return 1
    printf '%s\n' "$_files" | tr '\n' '\0' | xargs -0 jq -r --arg s "$_s" --arg c "$_c" --argjson t "$_t" '
        select(.sid == $s and .scope == $c and .state == "notify_only" and (.evidence.uuid == null)
               and ((.first_seen // 0) >= $t - 21600)) | input_filename
    ' 2>/dev/null | head -n 1 | grep .
}

# How many records (any state) exist for (sid, scope); drives the attempt counter.
_rw_count_key() {
    local _s="$1" _c="$2" _files
    _files="$(_rw_all_files)"
    if [ -z "$_files" ]; then echo 0; return; fi
    printf '%s\n' "$_files" | tr '\n' '\0' | xargs -0 jq -r --arg s "$_s" --arg c "$_c" '
        select(.sid == $s and .scope == $c) | 1' 2>/dev/null | wc -l | tr -d ' '
}

_rw_sha1() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 1; else sha1sum; fi
}

_rw_new_rid() {
    local _h _n=0 _rid
    while :; do
        _h="$(printf '%s|%s|%s|%s' "$1" "$2" "$3" "$_n" | _rw_sha1)"
        _rid="r_${_h:0:6}"
        if [ ! -e "$(borg_resume_dir)/pending/$_rid.json" ] && [ ! -e "$(borg_resume_dir)/done/$_rid.json" ]; then
            printf '%s\n' "$_rid"
            return 0
        fi
        _n=$((_n + 1))
    done
}

_rw_day() {
    date -u -r "$1" +%F 2>/dev/null || date -u -d "@$1" +%F 2>/dev/null
}

_rw_state_file() { printf '%s/state/%s.json\n' "$(borg_resume_dir)" "$1"; }

# Ensure state/<sid>.json exists with the counters of the directive and roll the day over.
_rw_state_ensure() {
    local _sid="$1" _f _now _day
    _f="$(_rw_state_file "$_sid")"
    _now="$(_rc_now)"
    _day="$(_rw_day "$_now")"
    if [ ! -f "$_f" ]; then
        jq -n -c --arg d "$_day" '{consecutive: 0, resumed_total: 0, injections_today: 0, day: $d,
            last_progress_lines: 0, hook_cursor: 0}' | borg_resume_write_atomic "$_f"
    fi
    _rw_update "$_f" --arg d "$_day" '
        (if .day != $d then .day = $d | .injections_today = 0 else . end)
        | .consecutive //= 0 | .resumed_total //= 0 | .injections_today //= 0 | .last_progress_lines //= 0
        | .hook_cursor //= 0'
}

# ---------------------------------------------------------------------------------------------
# ingest: ONE entry point for both detectors
# ---------------------------------------------------------------------------------------------

# _rw_ingest <sid> <scope> <source: hook|scan> <error> <text> <uuid-or-empty> <line-or-empty> <error-epoch-or-empty>
_rw_ingest() {
    local _sid="$1" _scope="$2" _src="$3" _err="${4:-unknown}" _text="${5:-}" _uuid="${6:-}" _line="${7:-}"
    local _ets="${8:-}" _now _plan _class _action _ra _f _rid _attempt _state _rt _dir _prev
    [ -n "$_err" ] || _err="unknown"
    _now="$(_rc_now)"
    # Plan and first_seen use the ERROR's own time: a late detection must not push an absolute reset a day out.
    case "$_ets" in "" | *[!0-9]*) _ets="$_now" ;; esac
    [ "$_ets" -le "$_now" ] || _ets="$_now"

    if [ -n "$_uuid" ]; then
        if _f="$(_rw_find_uuid "$_uuid")"; then
            # Already known. Convergence: record the second detector on a still-pending record.
            case "$_f" in
                */pending/*)
                    _prev="$(jq -r --arg s "$_src" \
                        '(.detected_by | index($s)) | if . == null then "no" else "yes" end' "$_f" 2>/dev/null)"
                    if [ "$_prev" = no ]; then
                        _rw_update "$_f" --arg s "$_src" '.detected_by = ((.detected_by + [$s]) | unique)'
                    fi
                    ;;
            esac
            return 0
        fi
        # A hook-only notify record (no uuid, already in done/) takes the scan's uuid instead of a twin.
        if _f="$(_rw_find_uuidless_notify "$_sid" "$_scope" "$_ets")"; then
            _rw_update "$_f" --arg s "$_src" --arg u "$_uuid" --argjson l "${_line:-null}" '
                .detected_by = ((.detected_by + [$s]) | unique)
                | .evidence.uuid = $u | .evidence.uuids = (((.evidence.uuids // []) + [$u]) | unique)
                | .evidence.transcript_line = (if $l == null then .evidence.transcript_line else $l end)'
            _rw_log "converged uuid=$_uuid into ${_f##*/}"
            return 0
        fi
    fi

    _attempt=0
    _f=""
    _f="$(_rw_find_active "$_sid" "$_scope")" || _f=""
    if [ -z "$_f" ]; then
        _attempt="$(_rw_count_key "$_sid" "$_scope")"
    else
        _attempt="$(jq -r '.attempt // 0' "$_f" 2>/dev/null)"
    fi
    _plan="$(BORG_RESUME_NOW_EPOCH="$_ets" resume_plan "$_err" "$_text" "$_attempt" 2>/dev/null)"
    _class="${_plan%% *}"
    _plan="${_plan#* }"
    _action="${_plan%% *}"
    _ra="${_plan#* }"
    case "$_ra" in "" | "-" | *[!0-9]*) _ra=null ;; esac
    _rt=""
    if [ "$_class" = usage_limit ]; then
        _rt="$(printf '%s' "$_text" | sed -n 's/.*\(resets [^"]*\)$/\1/p' | head -n 1)"
    fi
    [ -n "$_line" ] || _line=null

    if [ -n "$_f" ]; then
        # Merge into the ACTIVE record. A hook event with no new uuid only adds the detector.
        _rw_update "$_f" --arg src "$_src" --arg uuid "$_uuid" --arg class "$_class" --arg action "$_action" \
            --arg err "$_err" --arg rt "$_rt" --argjson ra "$_ra" --argjson line "$_line" --argjson now "$_now" '
            ($uuid != "") as $newerr
            | .detected_by = ((.detected_by + [$src]) | unique)
            | (if $newerr then
                  .evidence.uuids = (((.evidence.uuids // []) + [$uuid]) | unique)
                  | .evidence.uuid = (.evidence.uuid // $uuid)
                  | .evidence.transcript_line = (if $line == null then .evidence.transcript_line else $line end)
                  | .class = $class | .action = $action | .error = $err
                  | .reset_text = (if $rt == "" then null else $rt end)
                  | .resume_at = ([.resume_at, $ra] | map(select(. != null)) | max)
                  | (if $action == "notify" then
                        .state = "notify_only" | .state_log += [["notify_only", $now]] else . end)
               else . end)' || return 0
        _rw_n_merged=$((_rw_n_merged + 1))
        _rw_log "merged sid=$_sid scope=$_scope src=$_src uuid=${_uuid:-none} -> ${_f##*/}"
        return 0
    fi

    _rid="$(_rw_new_rid "$_sid" "$_scope" "$_now")"
    _state=scheduled
    _dir=pending
    if [ "$_action" = notify ]; then
        _state=notify_only
        _dir="done"
    fi
    jq -n -c --arg rid "$_rid" --arg sid "$_sid" --arg scope "$_scope" --arg class "$_class" --arg action "$_action" \
        --arg err "$_err" --arg rt "$_rt" --arg src "$_src" --arg uuid "$_uuid" --argjson line "$_line" \
        --argjson now "$_now" --argjson ets "$_ets" --argjson ra "$_ra" \
        --argjson attempt "$_attempt" --arg state "$_state" '
        {
            rid: $rid, sid: $sid, scope: $scope, class: $class, action: $action, error: $err,
            reset_text: (if $rt == "" then null else $rt end),
            detected_by: [$src],
            evidence: {transcript_line: $line, uuid: (if $uuid == "" then null else $uuid end),
                       uuids: (if $uuid == "" then [] else [$uuid] end)},
            first_seen: $ets, resume_at: $ra, attempt: $attempt,
            state: $state, state_log: [[$state, $now]], inject_tries: 0, notified: false
        }' | borg_resume_write_atomic "$(borg_resume_dir)/$_dir/$_rid.json" || return 0
    _rw_state_ensure "$_sid"
    _rw_n_created=$((_rw_n_created + 1))
    _rw_log "created $_rid sid=$_sid scope=$_scope class=$_class state=$_state src=$_src uuid=${_uuid:-none}"
    return 0
}

# Close a not-yet-injected ACTIVE record of the scope because the user ended it deliberately.
_rw_close_interrupted() {
    local _sid="$1" _scope="$2" _f _st _now
    _f="$(_rw_find_active "$_sid" "$_scope")" || return 0
    _st="$(jq -r .state "$_f" 2>/dev/null)"
    case "$_st" in
        new | scheduled | deferred) ;;
        *) return 0 ;;
    esac
    _now="$(_rc_now)"
    _rw_update "$_f" --argjson now "$_now" \
        '.state = "cancelled" | .reason = "interrupted_by_user"
         | .state_log += [["cancelled", $now, "interrupted_by_user"]]' || return 0
    _rw_n_closed=$((_rw_n_closed + 1))
    _rw_log "closed $(basename "$_f" .json) cancelled (interrupted_by_user) sid=$_sid scope=$_scope"
    return 0
}

# ---------------------------------------------------------------------------------------------
# detectors
# ---------------------------------------------------------------------------------------------

# Classify the tail of a transcript for (sid, scope). Prints one of:
#   error<US>error<US>text<US>uuid<US>line<US>epoch (US = unit separator 0x1f, so empty fields survive read)
#   | interrupt | none (transcript reachable, no error at its tail) | absent (no transcript to look at)
_rw_tail_verdict() {
    local _file="$1" _out _rec _se _e _tx _uuid _line _ts
    [ -f "$_file" ] || { printf 'absent\n'; return 0; }
    _out="$(resume_last_meaningful_with_close "$_file" 60 2>/dev/null)"
    [ -n "$_out" ] || { printf 'none\n'; return 0; }
    _rec="${_out#*$'\t'}"
    _se="$(resume_synthetic_error "$_rec" 2>/dev/null)"
    if [ -n "$_se" ]; then
        _e="${_se%%$'\t'*}"
        _tx="${_se#*$'\t'}"
        _tx="${_tx%$'\t'*}"
        _line="$(resume_last_meaningful_line "$_file" 60 2>/dev/null)"
        _uuid="$(printf '%s' "$_rec" | jq -r --arg l "$_line" '.uuid // ("L" + $l)' 2>/dev/null)"
        _ts="$(printf '%s' "$_rec" | jq -r '(.timestamp // empty) | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null)"
        printf 'error%s%s%s%s%s%s%s%s%s%s\n' "$_RW_SEP" "$_e" "$_RW_SEP" "$_tx" "$_RW_SEP" "$_uuid" "$_RW_SEP" \
            "$_line" "$_RW_SEP" "$_ts"
        return 0
    fi
    if resume_record_is_interrupt "$_rec"; then
        printf 'interrupt\n'
        return 0
    fi
    printf 'none\n'
}

# Apply a verdict to a scope.
_rw_apply_verdict() {
    local _sid="$1" _scope="$2" _src="$3" _v="$4" _kind _e _tx _uuid _line _ts
    _kind="${_v%%"$_RW_SEP"*}"
    case "$_kind" in
        error)
            IFS="$_RW_SEP" read -r _kind _e _tx _uuid _line _ts <<EOF
$_v
EOF
            _rw_ingest "$_sid" "$_scope" "$_src" "$_e" "$_tx" "$_uuid" "$_line" "$_ts"
            ;;
        interrupt) _rw_close_interrupted "$_sid" "$_scope" ;;
    esac
    return 0
}

# Hook path: fold new stop_failure events of one session. Transcripts are ground truth: when the transcript is
# reachable its tail decides (error -> the real uuid, interrupt marker -> nothing); otherwise the event alone
# makes a record without a uuid, which a later scan merges into.
_rw_fold_hooks() {
    local _sid="$1" _ef _sf _cursor _total _loc _t _sd _line _scope _aid _e _m _file _v _kind _lines _et _cut
    _cut=$(($(_rc_now) - ${BORG_RESUME_SCAN_HOURS:-72} * 3600))
    _ef="$(borg_resume_events_file "$_sid")"
    [ -f "$_ef" ] || return 0
    _sf="$(_rw_state_file "$_sid")"
    _cursor=0
    [ -f "$_sf" ] && _cursor="$(jq -r '.hook_cursor // 0' "$_sf" 2>/dev/null)"
    case "$_cursor" in "" | *[!0-9]*) _cursor=0 ;; esac
    _total="$(wc -l <"$_ef" | tr -d ' ')"
    [ "$_total" -gt "$_cursor" ] || return 0
    _lines="$(tail -n +$((_cursor + 1)) "$_ef" | head -n $((_total - _cursor)) |
        jq -c -R 'fromjson? | select(type == "object" and .ev == "stop_failure")' 2>/dev/null)"
    _loc="$(_ri_locate "$_sid")"
    _t="${_loc%%$'\t'*}"
    _sd="${_loc#*$'\t'}"
    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        _aid="$(printf '%s' "$_line" | jq -r '.agent_id // empty')"
        _e="$(printf '%s' "$_line" | jq -r '.error // "unknown"')"
        _m="$(printf '%s' "$_line" | jq -r '.msg // ""')"
        _scope=main
        _file="$_t"
        if [ -n "$_aid" ]; then
            _scope="agent:$_aid"
            _file=""
            [ -n "$_sd" ] && _file="$_sd/subagents/agent-$_aid.jsonl"
        fi
        _v="$(_rw_tail_verdict "$_file")"
        _kind="${_v%%"$_RW_SEP"*}"
        case "$_kind" in
            error | interrupt) _rw_apply_verdict "$_sid" "$_scope" hook "$_v" ;;
            absent)
                # No transcript to check: the event alone is the evidence, unless it is stale. A missing
                # agent_id is NOT taken to mean main when a transcript says otherwise (U1), see "none".
                _et="$(printf '%s' "$_line" | jq -r '.t // 0')"
                case "$_et" in "" | *[!0-9]*) _et=0 ;; esac
                if [ "$_et" -ge "$_cut" ]; then
                    _rw_ingest "$_sid" "$_scope" hook "$_e" "$_m" "" "" "$_et"
                else
                    _rw_log "dropped stale hook event sid=$_sid scope=$_scope t=$_et"
                fi
                ;;
            *) _rw_log "dropped hook event sid=$_sid scope=$_scope: transcript tail shows no error (scan decides)" ;;
        esac
    done <<EOF
$_lines
EOF
    # Only sessions with stop_failure facts get a cursor (and a state file); other events stay cheap to re-skip.
    if [ -n "$_lines" ]; then
        _rw_state_ensure "$_sid"
        _rw_update "$_sf" --argjson c "$_total" '.hook_cursor = $c'
    fi
    return 0
}

# Defer path (S7b): fold new `defer` events (written by `borg-resume defer`) of one session. A defer reschedules an
# ACTIVE record as `deferred` with resume_at = max(until, now, current resume_at) (default until: event time +
# BORG_RESUME_DEFER_SEC, 900): a defer only ever pushes later. The ceiling is the D2 age rule: first_seen + 7 days
# for limit-class records, first_seen + BORG_RESUME_MAX_AGE_HOURS (48) for everything else; the 48h expiry itself is
# S9's. Defers are bounded: each applied defer counts toward the session's `consecutive`, and once a record has
# BORG_RESUME_DEFER_MAX (3) defers the next one closes it `capped` instead of looping. A defer of a confirmed
# record drops the confirmation so the prompt can be injected again. Terminal records and unknown rids are
# ignored. Own cursor (defer_cursor): each event is applied once, and the cursor stops before a line whose update
# failed so it is retried next pass.
_rw_fold_defers() {
    local _sid="$1" _ef _sf _cursor _total _lines _line _rid _f _until _ev_t _reason _now _def _max _age _n _ok
    local _applied
    _ef="$(borg_resume_events_file "$_sid")"
    [ -f "$_ef" ] || return 0
    _sf="$(_rw_state_file "$_sid")"
    _cursor=0
    [ -f "$_sf" ] && _cursor="$(jq -r '.defer_cursor // 0' "$_sf" 2>/dev/null)"
    case "$_cursor" in "" | *[!0-9]*) _cursor=0 ;; esac
    _total="$(wc -l <"$_ef" | tr -d ' ')"
    [ "$_total" -gt "$_cursor" ] || return 0
    _lines="$(tail -n +$((_cursor + 1)) "$_ef" | head -n $((_total - _cursor)) |
        jq -c -R 'input_line_number as $n | (fromjson? // empty)
            | select(type == "object" and .ev == "defer" and (.rid | type) == "string") | . + {_n: $n}' 2>/dev/null)"
    if [ -z "$_lines" ]; then
        # No defer lines: still advance, so the file is not rescanned in full on every pass.
        [ -f "$_sf" ] && _rw_update "$_sf" --argjson c "$_total" '.defer_cursor = $c'
        return 0
    fi
    _now="$(_rc_now)"
    _def="${BORG_RESUME_DEFER_SEC:-900}"
    case "$_def" in "" | *[!0-9]*) _def=900 ;; esac
    _max="${BORG_RESUME_DEFER_MAX:-3}"
    case "$_max" in "" | *[!0-9]*) _max=3 ;; esac
    _age="${BORG_RESUME_MAX_AGE_HOURS:-48}"
    case "$_age" in "" | *[!0-9]*) _age=48 ;; esac
    _applied=$_total
    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        _n="$(printf '%s' "$_line" | jq -r ._n)"
        _rid="$(printf '%s' "$_line" | jq -r .rid)"
        borg_resume_valid_sid "$_rid" || continue
        _f="$(borg_resume_dir)/pending/$_rid.json"
        [ -f "$_f" ] || continue
        [ "$(jq -r .sid "$_f" 2>/dev/null)" = "$_sid" ] || continue
        case "$(jq -r .state "$_f" 2>/dev/null)" in
            new | scheduled | deferred | injecting | injected | confirmed) ;;
            *) continue ;;
        esac
        _ev_t="$(printf '%s' "$_line" | jq -r '.t // 0')"
        _until="$(printf '%s' "$_line" | jq -r '.until // empty')"
        _reason="$(printf '%s' "$_line" | jq -r '.reason // empty')"
        case "$_ev_t" in "" | *[!0-9]*) _ev_t="$_now" ;; esac
        case "$_until" in "" | *[!0-9]*) _until=$((_ev_t + _def)) ;; esac
        _rw_state_ensure "$_sid"
        _ok=1
        if [ "$(jq -r '.defer_count // 0' "$_f" 2>/dev/null)" -ge "$_max" ]; then
            _rw_update "$_f" --argjson now "$_now" '.state = "capped" | .done_reason = "defer_cap"
                | .state_log += [["capped", $now, "defer_cap"]]' &&
                _rw_update "$_sf" '.consecutive += 1' || _ok=0
            [ "$_ok" -eq 1 ] && _rw_log "defer cap reached, $_rid capped"
        else
            _rw_update "$_f" --argjson u "$_until" --argjson now "$_now" --argjson age "$_age" --arg r "$_reason" '
                (.first_seen // $now) as $fs
                | (if .class == "usage_limit" then $fs + 604800 else $fs + ($age * 3600) end) as $ceil
                | ([([$u, $now, (.resume_at // 0)] | max), $ceil] | min) as $ra
                | .state = "deferred" | .resume_at = $ra
                | .defer_count = ((.defer_count // 0) + 1)
                | .defer_reason = (if $r == "" then null else $r end)
                | del(.confirmed_at, .confirmed_lines)
                | .state_log += [["deferred", $now, (if $r == "" then "defer" else $r end)]]' &&
                _rw_update "$_sf" '.consecutive += 1' || _ok=0
            [ "$_ok" -eq 1 ] && _rw_log "defer applied $_rid until=$_until reason=${_reason:-none}"
        fi
        if [ "$_ok" -eq 0 ]; then
            _applied=$((_cursor + _n - 1))
            break
        fi
        _rw_n_merged=$((_rw_n_merged + 1))
    done <<EOF
$_lines
EOF
    _rw_state_ensure "$_sid"
    _rw_update "$_sf" --argjson c "$_applied" '.defer_cursor = $c'
    return 0
}

# Scan path for one session: main transcript, Agent-tool agents, workflows (finished ones included).
_rw_scan_session() {
    local _sid="$1" _loc _t _sd _f _aid _v _wid _path _seen _wj _status _runid _efile _eagents _skipped
    _loc="$(_ri_locate "$_sid")"
    _t="${_loc%%$'\t'*}"
    _sd="${_loc#*$'\t'}"
    [ -n "$_t" ] && _rw_apply_verdict "$_sid" main scan "$(_rw_tail_verdict "$_t")"
    [ -n "$_sd" ] || return 0

    for _f in "$_sd"/subagents/agent-*.jsonl; do
        [ -f "$_f" ] || continue
        _aid="${_f##*/agent-}"
        _aid="${_aid%.jsonl}"
        _rw_apply_verdict "$_sid" "agent:$_aid" scan "$(_rw_tail_verdict "$_f")"
    done

    _seen=" "
    for _path in "$_sd"/workflows/wf_*.json "$_sd"/subagents/workflows/wf_*; do
        [ -e "$_path" ] || continue
        _wid="${_path##*/}"
        _wid="${_wid%.json}"
        case "$_seen" in *" $_wid "*) continue ;; esac
        _seen="${_seen}${_wid} "
        _wj="$(_ri_workflow_json "$_sid" "$_sd" "$_wid")"
        [ -n "$_wj" ] || continue
        _status="$(printf '%s' "$_wj" | jq -r .status)"
        _runid="$(printf '%s' "$_wj" | jq -r .run_id)"
        case "$_status" in
            interrupted_by_user)
                _rw_close_interrupted "$_sid" "workflow:$_runid"
                continue
                ;;
        esac
        # An errored (not superseded) owned agent supplies the real error and uuid.
        _eagents="$(printf '%s' "$_wj" | jq -r '.agents[]?
            | select(.status == "errored" and (.superseded | not)) | .brief_ref.path')"
        _efile="$(printf '%s\n' "$_eagents" | head -n 1)"
        case "$_status" in
            finished_with_failures | partial | unfinished)
                _v=""
                [ -n "$_efile" ] && _v="$(_rw_tail_verdict "$_efile")"
                case "${_v%%"$_RW_SEP"*}" in
                    error) _rw_apply_verdict "$_sid" "workflow:$_runid" scan "$_v" ;;
                    *)
                        # Only a finished run that hides failures is a detection without an errored agent;
                        # partial/unfinished with no error is a dead-process question for the liveness slice.
                        # A step the user skipped or killed (its owner agent ended with the interrupt marker)
                        # is a deliberate end, not a failure to resume.
                        _skipped="$(printf '%s' "$_wj" | jq -r '
                            ([.steps[]? | select(.state == "unfinished") | .agent_id]) as $u
                            | [.agents[]? | select(.status == "interrupted_by_user"
                                   and (.agent_id as $a | $u | index($a) != null))]
                            | length')"
                        if [ "$_status" = finished_with_failures ] && [ "${_skipped:-0}" = 0 ]; then
                            _rw_ingest "$_sid" "workflow:$_runid" scan unknown \
                                "workflow finished with failed or null steps" "wf:$_runid" "" "" "$(_ri_mtime "$_path")"
                        fi
                        ;;
                esac
                ;;
        esac
    done
    return 0
}

# ---------------------------------------------------------------------------------------------
# confirmed -> done, terminal -> done/
# ---------------------------------------------------------------------------------------------

_rw_has_ack() {
    local _sid="$1" _rid="$2" _since="$3" _ef
    _ef="$(borg_resume_events_file "$_sid")"
    [ -f "$_ef" ] || return 1
    jq -e -R -n --arg r "$_rid" --argjson s "$_since" '[inputs | fromjson?
        | select(type == "object" and .ev == "ack" and .rid == $r and (.t // 0) >= $s)] | length > 0' \
        "$_ef" >/dev/null 2>&1
}

# An ack only counts when it is newer than the last injection attempt or defer of the record (state_log entries
# injecting, injected, deferred; first_seen when there are none), NOT than the watcher's first sighting of the
# confirmation: the S6 "already moved on" path acks within seconds, before the watcher flips the record.
_rw_ack_since() {
    jq -r '[(.state_log // [])[] | select(.[0] == "injecting" or .[0] == "injected" or .[0] == "deferred") | .[1]]
        | (max // .first_seen // 0)' "$1" 2>/dev/null
}

_rw_confirmed_pass() {
    local _f _rid _sid _scope _at _cl _now _lines _file _loc _t _sd _need _after _prog _reason _sf _since
    _now="$(_rc_now)"
    _need="${BORG_RESUME_CONFIRM_PROGRESS_LINES:-25}"
    _after="${BORG_RESUME_CONFIRM_DONE_SEC:-1800}"
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        [ "$(jq -r .state "$_f" 2>/dev/null)" = confirmed ] || continue
        _rid="$(jq -r .rid "$_f")"
        _sid="$(jq -r .sid "$_f")"
        _scope="$(jq -r .scope "$_f")"
        _loc="$(_ri_locate "$_sid")"
        _t="${_loc%%$'\t'*}"
        _sd="${_loc#*$'\t'}"
        _file="$_t"
        case "$_scope" in
            agent:*) _file="$_sd/subagents/agent-${_scope#agent:}.jsonl" ;;
        esac
        _lines=0
        [ -f "$_file" ] && _lines="$(wc -l <"$_file" | tr -d ' ')"
        _at="$(jq -r '.confirmed_at // empty' "$_f")"
        _cl="$(jq -r '.confirmed_lines // empty' "$_f")"
        if [ -z "$_at" ] || [ -z "$_cl" ]; then
            # Confirmation facts are written by the injector (S8); backfill from the first sighting.
            _at="${_at:-$_now}"
            _cl="${_cl:-$_lines}"
            _rw_update "$_f" --argjson at "$_at" --argjson cl "$_cl" '.confirmed_at //= $at | .confirmed_lines //= $cl'
        fi
        _prog=$((_lines - _cl))
        _reason=""
        _since="$(_rw_ack_since "$_f")"
        case "$_since" in "" | null | *[!0-9]*) _since="$_at" ;; esac
        if _rw_has_ack "$_sid" "$_rid" "$_since"; then
            _reason=ack
        elif [ "$_prog" -ge "$_need" ]; then
            _reason=progress
        elif [ $((_now - _at)) -ge "$_after" ]; then
            _reason=timeout
        fi
        [ -n "$_reason" ] || continue
        _rw_state_ensure "$_sid"
        _sf="$(_rw_state_file "$_sid")"
        if [ "$_reason" = timeout ]; then
            _rw_update "$_sf" '.consecutive += 1'
        else
            _rw_update "$_sf" --argjson l "$_lines" '.consecutive = 0 | .last_progress_lines = $l'
        fi
        _rw_update "$_f" --argjson now "$_now" --arg r "$_reason" \
            '.state = "done" | .done_reason = $r | .state_log += [["done", $now, $r]]'
        _rw_n_done=$((_rw_n_done + 1))
        _rw_log "confirmed -> done $_rid reason=$_reason"
    done
    return 0
}

# Move every record in a terminal state from pending/ to done/.
_rw_move_terminal() {
    local _f _st _dest
    for _f in "$(borg_resume_dir)"/pending/*.json; do
        [ -f "$_f" ] || continue
        _st="$(jq -r .state "$_f" 2>/dev/null)"
        case "$_st" in
            done | superseded | cancelled | capped | notify_only | expired | failed | stalled) ;;
            *) continue ;;
        esac
        _dest="$(borg_resume_dir)/done/${_f##*/}"
        mkdir -p "${_dest%/*}" 2>/dev/null
        if mv -f "$_f" "$_dest" 2>/dev/null; then
            touch "$_dest" 2>/dev/null
            _rw_log "moved ${_f##*/} to done ($_st)"
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------------------------
# retention
# ---------------------------------------------------------------------------------------------

_rw_retention() {
    local _days _cutoff _now _d _f _g _sid _rid _newest _m _seen _active
    _days="${BORG_RESUME_RETAIN_DAYS:-14}"
    case "$_days" in "" | *[!0-9]*) _days=14 ;; esac
    [ "$_days" -lt 4 ] && _days=4
    _now="$(_rc_now)"
    _cutoff=$((_now - _days * 86400))
    _d="$(borg_resume_dir)"

    for _f in "$_d"/done/*.json; do
        [ -f "$_f" ] || continue
        if [ "$(_ri_mtime "$_f")" -lt "$_cutoff" ]; then
            rm -f "$_f" && _rw_log "retention: removed done/${_f##*/}"
        fi
    done
    for _f in "$_d"/prompts/*.md; do
        [ -f "$_f" ] || continue
        _rid="${_f##*/}"
        _rid="${_rid%.md}"
        [ -e "$_d/pending/$_rid.json" ] && continue
        if [ "$(_ri_mtime "$_f")" -lt "$_cutoff" ]; then
            rm -f "$_f" && _rw_log "retention: removed prompts/${_f##*/}"
        fi
    done

    _active="$(_rw_files pending | tr '\n' '\0' | xargs -0 jq -r '.sid' 2>/dev/null | sort -u)"
    _seen=" "
    for _f in "$_d"/sessions/*.json "$_d"/events/*.jsonl "$_d"/state/*.json; do
        [ -f "$_f" ] || continue
        _sid="${_f##*/}"
        _sid="${_sid%.jsonl}"
        _sid="${_sid%.json}"
        case "$_seen" in *" $_sid "*) continue ;; esac
        _seen="${_seen}${_sid} "
        printf '%s\n' "$_active" | grep -qx -- "$_sid" && continue
        _newest=0
        for _g in "$_d/sessions/$_sid.json" "$_d/events/$_sid.jsonl"; do
            [ -f "$_g" ] || continue
            _m="$(_ri_mtime "$_g")"
            [ "$_m" -gt "$_newest" ] && _newest="$_m"
        done
        if [ "$_newest" -lt "$_cutoff" ]; then
            rm -f "$_d/sessions/$_sid.json" "$_d/events/$_sid.jsonl" "$_d/state/$_sid.json"
            _rw_log "retention: removed ledger files of $_sid"
        fi
    done
    return 0
}

# ---------------------------------------------------------------------------------------------
# one pass
# ---------------------------------------------------------------------------------------------

borg_resume_watch_once() {
    local _d _f _sid _hours _cut _now
    command -v jq >/dev/null 2>&1 || { printf 'borg-resume: jq is required\n' >&2; return 1; }
    borg_resume_disabled_env && return 0
    _d="$(borg_resume_dir)"
    mkdir -p "$_d" 2>/dev/null || return 1
    _rw_log_rotate
    if ! _rw_lock; then
        _rw_log "another watcher holds the lock; exiting"
        return 0
    fi
    trap '_rw_unlock' EXIT
    trap '_rw_unlock; exit 143' INT TERM

    _rw_n_created=0 _rw_n_merged=0 _rw_n_closed=0 _rw_n_done=0
    _now="$(_rc_now)"
    _hours="${BORG_RESUME_SCAN_HOURS:-72}"
    case "$_hours" in "" | *[!0-9]*) _hours=72 ;; esac
    _cut=$((_now - _hours * 3600))

    # S14 (lib/borg/resume-cli.sh): the cancel and run events are folded right after the defers.
    # shellcheck source=/dev/null
    if [ -n "${BORG_RESUME_LIBDIR:-}" ] && [ -f "$BORG_RESUME_LIBDIR/resume-cli.sh" ]; then
        . "$BORG_RESUME_LIBDIR/resume-cli.sh"
    else
        _rw_log "ERROR resume-cli.sh missing from ${BORG_RESUME_LIBDIR:-unset}: cancel and run events are NOT applied"
    fi
    for _f in "$_d"/events/*.jsonl; do
        [ -f "$_f" ] || continue
        _sid="${_f##*/}"
        _sid="${_sid%.jsonl}"
        borg_resume_valid_sid "$_sid" || continue
        _rw_fold_hooks "$_sid"
        _rw_fold_defers "$_sid"
        command -v borg_resume_cli_fold >/dev/null 2>&1 && borg_resume_cli_fold "$_sid"
    done
    for _f in "$_d"/sessions/*.json; do
        [ -f "$_f" ] || continue
        _sid="${_f##*/}"
        _sid="${_sid%.json}"
        borg_resume_valid_sid "$_sid" || continue
        [ "$(_ri_mtime "$_f")" -ge "$_cut" ] || continue
        _rw_scan_session "$_sid"
    done
    # S10 liveness detector (lib/borg/resume-liveness.sh): dead process or pane with open work, sticky close, stall
    # watchdog. Runs before the confirmed pass so a stall wins over the 30-minute timeout.
    if [ -n "${BORG_RESUME_LIBDIR:-}" ] && [ -f "$BORG_RESUME_LIBDIR/resume-liveness.sh" ]; then
        # shellcheck source=/dev/null
        . "$BORG_RESUME_LIBDIR/resume-liveness.sh" && borg_resume_liveness_pass
    fi
    # S9 gate (lib/borg/resume-gate.sh): confirmation before the confirmed rules, the pre-flight gate after them.
    command -v borg_resume_gate_confirm_pass >/dev/null 2>&1 && borg_resume_gate_confirm_pass
    _rw_confirmed_pass
    command -v borg_resume_gate_due_pass >/dev/null 2>&1 && borg_resume_gate_due_pass
    _rw_move_terminal
    _rw_retention
    if [ $((_rw_n_created + _rw_n_merged + _rw_n_closed + _rw_n_done)) -gt 0 ]; then
        _rw_log "pass: created=$_rw_n_created merged=$_rw_n_merged closed=$_rw_n_closed done=$_rw_n_done"
    fi
    printf 'borg-resume watch: created=%s merged=%s closed=%s done=%s\n' \
        "$_rw_n_created" "$_rw_n_merged" "$_rw_n_closed" "$_rw_n_done"
    trap - EXIT INT TERM
    _rw_unlock
    return 0
}
