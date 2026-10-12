#!/usr/bin/env bash
# resume-close.sh -- deliberate-close marking for borg-resume (slice S3b).
#
# Sourced by bin/borg-resume after resume-paths.sh. `borg-resume mark-closed <project|sid>` appends a
# session_end event with reason prompt_input_exit (plus via=mark_closed) to the events file of each matching
# session, so the watcher treats a drone/borg teardown exactly like the user exiting the prompt. Callers only
# APPEND; the watcher owns every state transition. Bash 3.2 safe, jq required, always returns 0.
# Kill switch: BORG_RESUME_DISABLE=1 records nothing (the DISABLED sentinel only stops injection, so we still
# record, same as the hooks).

# Print the session ids a target names, one per line: registered sessions whose project matches, else the sid
# itself when it has a registry row or an events file. Prints nothing for an unknown target.
borg_resume_close_targets() {
    local _t="$1" _f _sid _hit=0
    for _f in "$(borg_resume_dir)"/sessions/*.json; do
        [ -f "$_f" ] || continue
        _sid="$(jq -r --arg p "$_t" 'select(.project == $p) | .session_id // empty' "$_f" 2>/dev/null)"
        if borg_resume_valid_sid "$_sid"; then
            printf '%s\n' "$_sid"
            _hit=1
        fi
    done
    if [ "$_hit" = 0 ] && { [ -f "$(borg_resume_registry_file "$_t")" ] || [ -f "$(borg_resume_events_file "$_t")" ]; }; then
        printf '%s\n' "$_t"
    fi
    return 0
}

borg_resume_mark_closed() {
    local _t="${1:-}" _now _sid _line
    borg_resume_disabled_env && return 0
    command -v jq >/dev/null 2>&1 || return 0
    borg_resume_valid_sid "$_t" || return 0
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) _now="$(date +%s)" ;;
        *) _now="$BORG_RESUME_NOW_EPOCH" ;;
    esac
    borg_resume_close_targets "$_t" | while IFS= read -r _sid; do
        [ -n "$_sid" ] || continue
        _line="$(jq -nc --argjson t "$_now" --arg sid "$_sid" \
            '{t: $t, ev: "session_end", sid: $sid, scope: "main", reason: "prompt_input_exit", via: "mark_closed"}' \
            2>/dev/null)"
        [ -n "$_line" ] && borg_resume_append_line "$(borg_resume_events_file "$_sid")" "$_line"
    done
    return 0
}
