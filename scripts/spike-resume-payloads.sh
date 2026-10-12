#!/usr/bin/env bash
# spike-resume-payloads.sh -- capture harness for the resume design (slice S0a).
#
# Records Claude Code hook payloads and tmux pane snapshots into a scratch dir so
# later slices can build fixtures from REAL data. It is a research tool:
#   - it is NEVER installed as a live hook by this repo;
#   - the `hook` subcommand always exits 0 and prints nothing, so it can never
#     block or alter a turn;
#   - everything written is scrubbed (user paths, home dir, message content).
#
# Subcommands:
#   hook <event>              read a hook payload on stdin, append it (scrubbed)
#   snap <pane> [label]       capture-pane of <pane> into the scratch dir (scrubbed)
#   settings [file]           write a TEMPORARY settings file wiring every candidate
#                             event to this script; prints its path. Use it with
#                             `claude --settings <file>`; nothing global is touched.
#   scrub                     filter stdin to stdout with the same scrubber
#   dir                       print the scratch dir
#
# Env:
#   BORG_SPIKE_DIR   scratch dir (default: ${TMPDIR:-/tmp}/borg-resume-spike)
#   BORG_SPIKE_KEEP_TEXT=1  keep message text verbatim (still path-scrubbed);
#                           default redacts text except usage-limit sentences.
#
# Bash 3.2 compatible. No set -e: failures must not propagate out of the hook.

_spike_self="${BASH_SOURCE[0]:-$0}"
_spike_dir="${BORG_SPIKE_DIR:-${TMPDIR:-/tmp}/borg-resume-spike}"

# Events the design wants to observe, with the matcher used for each.
_spike_events="StopFailure SessionStart SessionEnd SubagentStart SubagentStop Notification PreToolUse PostToolUse"

# Path scrubber: any /Users/<name>[/dev/<proj>]... collapses to /Users/noah/dev/example,
# the home dir (if set) is replaced first, and /private/tmp style session dirs are kept.
_spike_scrub_paths() {
    local home="${HOME:-}"
    if [ -n "$home" ] && [ "$home" != "/" ]; then
        sed -e "s#${home}#/Users/noah/dev/example#g" \
            -e 's#/Users/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g' \
            -e 's#/home/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g'
    else
        sed -e 's#/Users/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g' \
            -e 's#/home/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g'
    fi
}

# JSON scrubber: redact free-text fields unless they are usage-limit sentences
# (the reset text is the one thing the classifier needs verbatim).
_spike_scrub_json() {
    local keep="${BORG_SPIKE_KEEP_TEXT:-0}"
    jq -c --arg keep "$keep" '
      def limit: test("hit your .*limit|resets|rate.?limit|overloaded|server.?error|Prompt is too long"; "i");
      def redact: if ($keep == "1") or (type != "string") or limit then .
                  else "<scrubbed:\(length) chars>" end;
      walk(
        if type == "object" then
          with_entries(
            if (.key | IN("last_assistant_message","msg","message","prompt","content",
                          "text","description","tool_input","tool_response","result","title"))
            then .value |= (if type == "string" then redact
                            elif type == "object" or type == "array" then "<scrubbed:\(tojson | length) chars>"
                            else . end)
            else . end)
        else . end)
    ' 2>/dev/null | _spike_scrub_paths
}

_spike_hook() {
    local ev="${1:-unknown}" payload line ts
    payload="$(cat 2>/dev/null)"
    [ -n "$payload" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    mkdir -p "$_spike_dir" 2>/dev/null || return 0
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
    mkdir -p "$_spike_dir/panes" 2>/dev/null || return 0
    label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"
    out="$_spike_dir/panes/$(date +%s)-${label}.txt"
    if [ -n "${BORG_SPIKE_TMUX_SOCK:-}" ]; then
        tmux -L "$BORG_SPIKE_TMUX_SOCK" capture-pane -p -t "$pane" 2>/dev/null | _spike_scrub_paths >"$out"
    else
        tmux capture-pane -p -t "$pane" 2>/dev/null | _spike_scrub_paths >"$out"
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
    local acc='{"hooks":{}}'
    for ev in $_spike_events; do
        matcher=""
        case "$ev" in
            PreToolUse|PostToolUse) matcher="Agent|Workflow" ;;
            Notification) matcher="idle_prompt|permission_prompt|quota_auto_resume_.*" ;;
        esac
        acc="$(printf '%s' "$acc" | jq -c --arg ev "$ev" --arg m "$matcher" --arg cmd "$self hook $ev" \
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
        scrub)
            if [ "${BORG_SPIKE_TEXT:-0}" = "1" ]; then _spike_scrub_paths; else _spike_scrub_json; fi ;;
        dir) echo "$_spike_dir" ;;
        *) echo "usage: ${_spike_self##*/} hook <event>|snap <pane> [label]|settings [file]|scrub|dir" >&2 ;;
    esac
}

# The hook path must never fail the caller, whatever happens above.
if [ "${1:-}" = "hook" ]; then
    main "$@" >/dev/null 2>&1
    exit 0
fi
main "$@"
exit 0
