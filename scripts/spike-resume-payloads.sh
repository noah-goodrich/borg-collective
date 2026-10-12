#!/usr/bin/env bash
# spike-resume-payloads.sh -- capture harness for the resume design (slice S0a).
#
# Records Claude Code hook payloads and tmux pane snapshots into a scratch dir so
# later slices can build fixtures from REAL data. It is a research tool:
#   - it is NEVER installed as a live hook by this repo;
#   - the `hook` subcommand always exits 0 and prints nothing, so it can never
#     block or alter a turn;
#   - it never writes secrets or conversation text. JSON: every free-text key is
#     redacted (see _spike_text_keys), only the exact usage-limit sentence and a few
#     fixed system messages survive, and any string that looks like a token or an
#     email is redacted whatever its key. Panes: EVERY line is redacted unless it
#     matches an explicit allowlist of dialog / limit / composer-chrome lines.
#     Paths and the home dir are collapsed.
#
# Subcommands:
#   hook <event>              read a hook payload on stdin, append it (scrubbed)
#   snap <pane> [label]       capture-pane of <pane> into the scratch dir (allowlisted)
#   settings [file]           write a TEMPORARY settings file wiring every candidate
#                             event to this script; prints its path. Use it with
#                             `claude --settings <file>`; nothing global is touched.
#   scrub                     filter stdin JSON to stdout with the JSON scrubber
#   scrubpane                 filter stdin pane text to stdout with the pane allowlist
#   show                      print the captured payloads (jq -c, one per line)
#   dir                       print the scratch dir
#
# Env:
#   BORG_SPIKE_DIR   scratch dir (default: ${TMPDIR:-/tmp}/borg-resume-spike, mode 700)
#   BORG_SPIKE_KEEP_TEXT=1  keep free-text values verbatim for `hook`/`scrub` (path- and
#                           secret-scrubbed only). Local debugging; never commit output.
#
# Bash 3.2 compatible. No set -e: failures must not propagate out of the hook.

_spike_self="${BASH_SOURCE[0]:-$0}"
_spike_dir="${BORG_SPIKE_DIR:-${TMPDIR:-/tmp}/borg-resume-spike}"

# Events the design wants to observe, with the matcher used for each.
_spike_events="StopFailure SessionStart SessionEnd SubagentStart SubagentStop Notification PreToolUse PostToolUse"

# Path scrubber: any /Users/<name>[/...] collapses to /Users/noah/dev/example, the home
# dir (if set) is replaced first. @@HOME@@ is a private marker for paths whose suffix
# was already rebuilt by the JSON scrubber; it is resolved last.
_spike_scrub_paths() {
    local home="${HOME:-}" users home_sed=()
    users='s#/Users/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g'
    if [ -n "$home" ] && [ "$home" != "/" ]; then
        home_sed=(-e "s#${home}#/Users/noah/dev/example#g")
    fi
    sed ${home_sed[@]+"${home_sed[@]}"} \
        -e "$users" \
        -e 's#/home/[A-Za-z0-9._-]*\(/[^" 	:,)]*\)\{0,\}#/Users/noah/dev/example#g' \
        -e 's#@@HOME@@#/Users/noah/dev/example#g'
}

# Free-text keys: their string values are redacted unless they are the exact
# usage-limit sentence (or a fixed system message). Objects/arrays under them are
# replaced wholesale.
_spike_text_keys='["last_assistant_message","msg","message","prompt","content","text",
  "description","tool_input","tool_response","result","title","error_details",
  "error_message","details","detail","reason","stderr","stdout","output","command",
  "query","input","summary","instructions","body","args","lastPrompt","last_prompt",
  "custom_title","customTitle","user_message","response","data","notification",
  "stack","trace","cause","file_path","path","url","name","label"]'

# JSON scrubber. Strict by construction:
#   - free-text keys (list above) are redacted;
#   - the limit keeper returns ONLY the matched usage-limit sentence, never the string
#     it was found in;
#   - any string anywhere that looks like a credential or an email is redacted;
#   - transcript_path keeps the /.claude/projects/<slug>/<sid>.jsonl shape.
_spike_scrub_json() {
    local keep="${BORG_SPIKE_KEEP_TEXT:-0}"
    jq -c --arg keep "$keep" --argjson tk "$_spike_text_keys" '
      def limit_re: "You[\u0027\u2019]ve hit your [A-Za-z]{3,12}( [A-Za-z]{3,12})? limit \u00b7 resets ([A-Z][a-z]{2} [0-9]{1,2} at )?[0-9]{1,2}(:[0-9]{2})?[ap]m( \\([A-Za-z_]+/[A-Za-z_]+\\))?";
      def canned: IN("Prompt is too long","Request timed out","Login expired \u00b7 Please run /login");
      def secretish: test("sk-[A-Za-z0-9_-]{6,}|ghp_[A-Za-z0-9]{6,}|AKIA[0-9A-Z]{8,}|xox[a-z]-[A-Za-z0-9-]{6,}|eyJ[A-Za-z0-9_-]{10,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}|(password|passwd|secret|token|api[_-]?key)[=: ]+[^ ]+"; "i");
      def keep_limit: (match(limit_re).string) // null;
      def redact: if (type != "string") then .
                  elif canned then .
                  else (keep_limit) // "<scrubbed:\(length) chars>" end;
      def tp: if type == "string" then
                (capture("/\\.claude/projects/[^/]*/(?<sid>[^/]*)\\.jsonl$") // null)
                | if . == null then "@@HOME@@" else "@@HOME@@/.claude/projects/-Users-noah-dev-example/\(.sid).jsonl" end
              else . end;
      walk(
        if type == "object" then
          with_entries(
            if (.key | IN($tk[])) and ($keep != "1")
            then .value |= (if type == "string" then redact
                            elif type == "object" or type == "array" then "<scrubbed:\(tojson | length) chars>"
                            else . end)
            elif (.key == "transcript_path" or .key == "agent_transcript_path") then .value |= tp
            elif (.value | type) == "string" and (.value | secretish) then .value = "<scrubbed:secret>"
            else . end)
        else . end)
    ' 2>/dev/null | _spike_scrub_paths
}

# Pane allowlist: a line survives only if, with box-drawing chars stripped and trimmed,
# it is blank, a rule, or exactly one of the known dialog / limit / composer-chrome
# lines. Everything else (conversation text, commands, file names) becomes <redacted>.
_spike_pane_ok() {
    local t="$1"
    local lim='You.ve hit your [A-Za-z]{3,12}( [A-Za-z]{3,12})? limit( . resets (([A-Z][a-z]{2} [0-9]{1,2} at )?[0-9]{1,2}(:[0-9]{2})?[ap]m)( \([A-Za-z_]+/[A-Za-z_]+\))?)?'
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
