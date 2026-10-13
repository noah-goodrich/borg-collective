#!/usr/bin/env bash
# resume-close.sh -- deliberate-close marking for borg-resume (slice S3b).
#
# Sourced by bin/borg-resume after resume-paths.sh. `borg-resume mark-closed <project|sid> [project_dir]`
# appends a session_end event with reason prompt_input_exit (plus via=mark_closed) to the events file of each
# matching session, so the watcher treats a drone/borg teardown exactly like the user exiting the prompt.
# Callers only APPEND; the watcher owns every state transition. Bash 3.2 safe, jq required, always returns 0.
# Kill switch: BORG_RESUME_DISABLE=1 records nothing (the DISABLED sentinel only stops injection, so we still
# record, same as the hooks).
#
# Fold contract for the watcher (S7/S10): a via=mark_closed event is STICKY. A later session_end with reason
# other, or a trailing stop_failure, written by the dying claude must not override it; only a later
# session_start for the same sid clears it. Callers mark both before and after the kill; a mark is skipped
# when the last event for that sid is already a mark_closed, so repeats do not pile up.

# Print the session ids a target names, one per line. A registered session matches when its project equals the
# target, or (when a repository directory is given) its cwd or tmux.project_dir equals or is under that dir. Falls back
# to the target as a sid when it has a registry row or an events file. Unknown target prints nothing.
borg_resume_close_targets() {
    local _t="$1" _dir="${2:-}" _sid _hit=0 _files
    _dir="${_dir%/}"
    _files=("$(borg_resume_dir)"/sessions/*.json)
    if [ -f "${_files[0]}" ]; then
        while IFS= read -r _sid; do
            if borg_resume_valid_sid "$_sid"; then
                printf '%s\n' "$_sid"
                _hit=1
            fi
        done < <(jq -rs --arg p "$_t" --arg d "$_dir" '
            def under($x): ($d != "") and ($x | type == "string") and ($x == $d or ($x | startswith($d + "/")));
            .[] | select(type == "object")
            | select(.project == $p or under(.cwd) or under(.tmux.project_dir))
            | .session_id // empty' "${_files[@]}" 2>/dev/null)
    fi
    if [ "$_hit" = 0 ] && borg_resume_valid_sid "$_t" \
        && { [ -f "$(borg_resume_registry_file "$_t")" ] || [ -f "$(borg_resume_events_file "$_t")" ]; }; then
        printf '%s\n' "$_t"
    fi
    return 0
}

# True when the last event line of the file is already a mark_closed.
_borg_resume_last_is_mark() {
    [ -s "$1" ] || return 1
    [ "$(tail -n 1 "$1" 2>/dev/null | jq -r '.via // empty' 2>/dev/null)" = "mark_closed" ]
}

borg_resume_mark_closed() {
    local _t="${1:-}" _dir="${2:-}" _now _sid _line _ef _n=0
    borg_resume_disabled_env && return 0
    command -v jq >/dev/null 2>&1 || return 0
    [ -n "$_t" ] || return 0
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) _now="$(date +%s)" ;;
        *) _now="$BORG_RESUME_NOW_EPOCH" ;;
    esac
    while IFS= read -r _sid; do
        [ -n "$_sid" ] || continue
        _n=$((_n + 1))
        _ef="$(borg_resume_events_file "$_sid")"
        _borg_resume_last_is_mark "$_ef" && continue
        _line="$(jq -nc --argjson t "$_now" --arg sid "$_sid" \
            '{t: $t, ev: "session_end", sid: $sid, scope: "main", reason: "prompt_input_exit", via: "mark_closed"}' \
            2>/dev/null)"
        [ -n "$_line" ] && borg_resume_append_line "$_ef" "$_line"
    done < <(borg_resume_close_targets "$_t" "$_dir")
    [ "$_n" -gt 0 ] || printf 'borg-resume: mark-closed: no session matched %s\n' "$_t" >&2
    return 0
}
