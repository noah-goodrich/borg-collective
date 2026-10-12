#!/usr/bin/env bash
# spike-resume-payloads.sh -- capture harness for the resume design (slice S0a).
#
# Records Claude Code hook payloads and tmux pane snapshots into a scratch dir so
# later slices can build fixtures from REAL data. It is a research tool:
#   - it is NEVER installed as a live hook by this repo;
#   - the `hook` subcommand always exits 0 and prints nothing, so it can never
#     block or alter a turn;
#   - JSON payloads are written ONLY as the output of scripts/resume-skeleton.py
#     (--stdin), the single positive allowlist shared with the fixture extractor:
#     JSON structure, numbers, booleans, known keys, enum values from closed sets,
#     fake ids, fake paths and a usage-limit sentence built from closed sets (kind,
#     month, timezone) under a few text keys survive; every other string becomes "<str>"
#     and every unknown key "<key>". If python3 is missing or errors, the hook writes a
#     jq key skeleton instead (a fixed list of key names, every string "<str>");
#   - session ids become fixed fake ids, so payloads from different sessions are NOT
#     correlatable in the output;
#   - panes: EVERY line is redacted unless it matches an explicit allowlist of
#     dialog / limit / composer-chrome lines.
# Not guaranteed: that a number or boolean carries no information. Review output
# before committing anything; nothing here is committed automatically.
#
# Subcommands:
#   hook <event>              read a hook payload on stdin, append it (allowlisted)
#   snap <pane> [label]       capture-pane of <pane> into the scratch dir (allowlisted)
#   settings [file]           write a TEMPORARY settings file wiring every candidate
#                             event to this script; prints its path. Use it with
#                             `claude --settings <file>`; nothing global is touched.
#   scrub                     filter stdin JSON to stdout (extractor, else jq skeleton)
#   scrubpane                 filter stdin pane text to stdout with the pane allowlist
#   show                      print the captured payloads (jq -c, one per line)
#   dir                       print the scratch dir
#
# Env:
#   BORG_SPIKE_DIR   scratch dir (default: ${TMPDIR:-/tmp}/borg-resume-spike, mode 700)
#
# Bash 3.2 compatible. No set -e: failures must not propagate out of the hook.

_spike_self="${BASH_SOURCE[0]:-$0}"
_spike_dir="${BORG_SPIKE_DIR:-${TMPDIR:-/tmp}/borg-resume-spike}"

# Events the design wants to observe, with the matcher used for each.
_spike_events="StopFailure SessionStart SessionEnd SubagentStart SubagentStop Notification PreToolUse PostToolUse"

# Path scrubber, used for pane lines only (JSON paths are faked by the extractor).
_spike_scrub_paths() {
    local home="${HOME:-}" home_sed=()
    if [ -n "$home" ] && [ "$home" != "/" ]; then
        home_sed=(-e "s#${home}#/Users/noah/dev/example#g")
    fi
    sed ${home_sed[@]+"${home_sed[@]}"} \
        -e 's#/Users/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g' \
        -e 's#/home/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g'
}

# Fallback skeleton (no python3, or the extractor failed): structure only. Object keys
# outside a fixed list become "<key>"; every string becomes "<str>".
_spike_skeleton_jq() {
    jq -c '
      def known: ["hook_event_name","session_id","cwd","transcript_path","error",
        "error_details","last_assistant_message","source","agent_id","agent_type",
        "agent_transcript_path","notification_type","message","reason","tool_name",
        "stop_hook_active","permission_mode","model","prompt"];
      walk(if type == "object"
             then with_entries(.key |= (if IN(known[]) then . else "<key>" end))
           elif type == "string" then "<str>"
           else . end)' 2>/dev/null
}

# JSON scrubber: scripts/resume-skeleton.py is the single source of truth.
_spike_scrub_json() {
    local py="${_spike_self%/*}/resume-skeleton.py" in out
    in="$(cat 2>/dev/null)"
    if command -v python3 >/dev/null 2>&1 && [ -f "$py" ]; then
        out="$(printf '%s' "$in" | python3 -I "$py" --stdin 2>/dev/null)" && [ -n "$out" ] \
            && { printf '%s\n' "$out"; return 0; }
    fi
    printf '%s' "$in" | _spike_skeleton_jq
}

# Pane allowlist: a line survives only if, with box-drawing chars stripped and trimmed,
# it is blank, a rule, or exactly one of the known dialog / limit / composer-chrome
# lines. Everything else (conversation text, commands, file names) becomes <redacted>.
_spike_pane_ok() {
    local t="$1"
    local kinds='weekly|session|daily|monthly|Opus|Sonnet|Haiku|weekly Opus|weekly Sonnet|weekly Haiku'
    local months='Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec'
    local zones='UTC|America/(New_York|Chicago|Denver|Phoenix|Los_Angeles|Anchorage|Toronto|Vancouver|Sao_Paulo)|Europe/(London|Dublin|Paris|Berlin|Madrid|Amsterdam)|Asia/(Tokyo|Seoul|Shanghai|Singapore|Kolkata|Dubai)|Australia/(Sydney|Melbourne)|Pacific/Auckland'
    local lim="You.ve hit your ($kinds) limit( . resets ((($months) [0-9]{1,2} at )?[0-9]{1,2}(:[0-9]{2})?[ap]m)( \\(($zones)\\))?)?"
    local choice='(❯ )?[1-9]\. (Yes|No|Stop and wait for limit to reset|Upgrade your plan|Switch to extra usage|Yes, and don.t ask again this session)'
    local chrome='Welcome to Claude Code|\? for shortcuts|[>❯]|Bash command|Do you want to proceed\?|What do you want to do\?|Esc to cancel|Enter to confirm|Press Enter to continue|(⏵⏵ )?(accept edits|plan mode|bypass permissions) on( \(shift\+tab to cycle\))?'
    [ -z "$t" ] && return 0
    [[ "$t" =~ ^($lim|$choice|$chrome)$ ]]
}

_spike_scrub_pane() {
    local line t
    while IFS= read -r line || [ -n "$line" ]; do
        t="$(printf '%s' "$line" | sed -E -e 's/(│|╭|╮|╰|╯|─|━|═|┌|┐|└|┘|├|┤)+/ /g' -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//')"
        if _spike_pane_ok "$t"; then
            printf '%s\n' "$line" | _spike_scrub_paths
        else
            printf '<redacted>\n'
        fi
    done
}

_spike_mkdir() {
    mkdir -p "$1" 2>/dev/null && chmod 700 "$1" 2>/dev/null
}

_spike_hook() {
    local ev="${1:-unknown}" payload line ts
    payload="$(cat 2>/dev/null)"
    [ -n "$payload" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    _spike_mkdir "$_spike_dir" || return 0
    ts="$(date +%s 2>/dev/null)"
    line="$(printf '%s' "$payload" | _spike_scrub_json)"
    [ -n "$line" ] || return 0
    printf '%s\n' "$line" | jq -c --arg ev "$ev" --arg t "$ts" \
        '{t: ($t|tonumber? // 0), ev: $ev, payload: .}' >>"$_spike_dir/payloads.jsonl" 2>/dev/null
    return 0
}

_spike_snap() {
    local pane="${1:-}" label="${2:-snap}" out
    [ -n "$pane" ] || { echo "usage: snap <pane> [label]" >&2; return 0; }
    command -v tmux >/dev/null 2>&1 || { echo "tmux not found" >&2; return 0; }
    _spike_mkdir "$_spike_dir" && _spike_mkdir "$_spike_dir/panes" || return 0
    label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"
    out="$_spike_dir/panes/$(date +%s)-${label}.txt"
    if [ -n "${BORG_SPIKE_TMUX_SOCK:-}" ]; then
        tmux -L "$BORG_SPIKE_TMUX_SOCK" capture-pane -p -t "$pane" 2>/dev/null | _spike_scrub_pane >"$out"
    else
        tmux capture-pane -p -t "$pane" 2>/dev/null | _spike_scrub_pane >"$out"
    fi
    echo "$out"
    return 0
}

_spike_settings() {
    local out="${1:-$_spike_dir/settings.spike.json}" ev matcher self
    command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; return 1; }
    mkdir -p "${out%/*}" 2>/dev/null
    self="$_spike_self"
    case "$self" in /*) ;; *) self="$PWD/$self" ;; esac
    local qself acc='{"hooks":{}}'
    qself="$(printf '%q' "$self")"
    for ev in $_spike_events; do
        matcher=""
        case "$ev" in
            PreToolUse|PostToolUse) matcher="Agent|Workflow" ;;
            Notification) matcher="idle_prompt|permission_prompt|quota_auto_resume_.*" ;;
        esac
        acc="$(printf '%s' "$acc" | jq -c --arg ev "$ev" --arg m "$matcher" --arg cmd "$qself hook $ev" \
            '.hooks[$ev] = [ ({hooks: [{type: "command", command: $cmd, timeout: 5}]}
                              + (if $m == "" then {} else {matcher: $m} end)) ]')"
    done
    printf '%s\n' "$acc" | jq . >"$out"
    echo "$out"
}

main() {
    local cmd="${1:-}"
    [ "$#" -gt 0 ] && shift
    case "$cmd" in
        hook) _spike_hook "$@" ;;
        snap) _spike_snap "$@" ;;
        settings) _spike_settings "$@" ;;
        scrub) _spike_scrub_json ;;
        scrubpane) _spike_scrub_pane ;;
        show) jq -c . "$_spike_dir/payloads.jsonl" 2>/dev/null ;;
        dir) echo "$_spike_dir" ;;
        *) echo "usage: ${_spike_self##*/} hook <event>|snap <pane> [label]|settings [file]|scrub|scrubpane|show|dir" >&2 ;;
    esac
}

# The hook path must never fail the caller, whatever happens above.
if [ "${1:-}" = "hook" ]; then
    main "$@" >/dev/null 2>&1
    exit 0
fi
main "$@"
exit 0
