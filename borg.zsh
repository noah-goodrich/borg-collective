#!/usr/bin/env zsh
# borg — The Borg Collective: multi-session Claude Code manager
#
# Usage:
#   borg link                 # overview of all tracked projects
#   borg link [project]       # deep dive on one project
#   borg switch [query]       # fzf picker → tmux window switch
#   borg scan                 # auto-discover projects from session history
#   borg add [path]           # manually register a project
#   borg rm <name>            # unregister a project

# Set a known-good PATH from scratch. Non-interactive zsh scripts invoked via shebang
# do not source /etc/zprofile or ~/.zshrc, so PATH can be empty or incomplete.
# We set it explicitly rather than appending to an unknown base.
PATH="${BORG_PATH_PREFIX:+$BORG_PATH_PREFIX:}$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
hash -r 2>/dev/null || true

set -e

BORG_VERSION="v0.8.9"
BORG_HOME="${BORG_HOME:-${0:A:h}}"  # directory containing this script (for lib/, hooks/, skills/)
BORG_ORCHESTRATOR_ROOT="${BORG_ORCHESTRATOR_ROOT:-$HOME/dev}"  # workspace root where projects live; orchestrator session runs here
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"

# Colors (same as dev.sh)
GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'  CYAN='\033[0;36m'
BOLD='\033[1m'  DIM='\033[2m'  NC='\033[0m'
info()  { echo -e "${GREEN}▸${NC} $*"; }
warn()  { echo -e "${YELLOW}▸${NC} $*"; }
die()   { echo -e "${RED}▸ ERROR:${NC} $*" >&2; exit 1; }
dbg()   { [[ -n "${BORG_DEBUG:-}" ]] && echo -e "${CYAN}  [dbg]${NC} $*" >&2 || true; }

# Source library modules
for _lib in "$BORG_HOME/lib"/*.zsh; do
    source "$_lib"
done

# Load optional config (work/life boundaries, limits)
BORG_CONFIG="$BORG_DIR/config.zsh"
[[ -f "$BORG_CONFIG" ]] && source "$BORG_CONFIG"
[[ -f "$BORG_DIR/extensions/config.zsh" ]] && source "$BORG_DIR/extensions/config.zsh"
BORG_MAX_ACTIVE="${BORG_MAX_ACTIVE:-3}"
BORG_SESSION_WARN_HOURS="${BORG_SESSION_WARN_HOURS:-2}"
BORG_WORK_HOURS="${BORG_WORK_HOURS:-}"
BORG_WORK_DAYS="${BORG_WORK_DAYS:-}"
BORG_WORK_PROJECTS="${BORG_WORK_PROJECTS:-}"
BORG_CORTEX_WAKES="${BORG_CORTEX_STATE:-$BORG_DIR/cortex-wakes.json}"

# ── Helpers ──────────────────────────────────────────────────────────────────

# Run a command with a timeout, falling back gracefully if `timeout` is unavailable.
_borg_timeout() {
    local secs=$1; shift
    if command -v timeout &>/dev/null; then
        timeout "$secs" "$@"
    else
        "$@"
    fi
}

# Convert ISO 8601 timestamp to relative time string ("2h ago", "yesterday", "3d ago")
_borg_relative_time() {
    local ts="$1"
    [[ -z "$ts" || "$ts" == "null" ]] && echo "never" && return
    local epoch_ts epoch_now diff
    epoch_ts=$(_borg_iso_to_epoch "$ts") || { echo "$ts"; return; }
    epoch_now=$(date +%s)
    diff=$(( epoch_now - epoch_ts ))
    if (( diff < 60 )); then echo "just now"
    elif (( diff < 3600 )); then echo "$(( diff / 60 ))m ago"
    elif (( diff < 86400 )); then echo "$(( diff / 3600 ))h ago"
    elif (( diff < 172800 )); then echo "yesterday"
    else echo "$(( diff / 86400 ))d ago"
    fi
}

# Check if current time is within work hours
_borg_is_work_hours() {
    [[ -z "$BORG_WORK_HOURS" ]] && return 0
    local range="$BORG_WORK_HOURS"
    local start_h="${range%%-*}" end_h="${range##*-}"
    local now_h=$(date +%H:%M)
    [[ "$now_h" > "$start_h" || "$now_h" == "$start_h" ]] && [[ "$now_h" < "$end_h" ]]
}

# Check if today is a work day
_borg_is_work_day() {
    [[ -z "$BORG_WORK_DAYS" ]] && return 0
    local today=$(date +%a)
    [[ ",$BORG_WORK_DAYS," == *",$today,"* ]]
}

# Check if a project is a work project
_borg_is_work_project() {
    [[ -z "$BORG_WORK_PROJECTS" ]] && return 1
    [[ ",$BORG_WORK_PROJECTS," == *",$1,"* ]]
}

# Prompt for work/life boundary confirmation. Returns 0 if allowed.
_borg_boundary_check() {
    local project="$1"
    if _borg_is_work_project "$project" && { ! _borg_is_work_hours || ! _borg_is_work_day; }; then
        local now_t=$(date +"%l:%M %p" | sed 's/^ //')
        echo -ne "${YELLOW}▸${NC} It's $now_t. ${BOLD}$project${NC} is a work project. Switch? [y/N] "
        read -rk1 reply
        echo
        [[ "$reply" == [yY] ]] && return 0 || return 1
    fi
    return 0
}

# Count projects with status=waiting or status=active (reads per-project state.json)
_borg_active_count() {
    borg_registry_with_state | jq '[.projects[] | select(.status == "waiting" or .status == "active")] | length'
}

# Read directives from a project's own docs/plans/directives/ directory.
# Argument: absolute path to the project root.
# Output: first line = count, subsequent lines = slug\ttitle
#
# NOTE: parameter is `ppath`, not `path`. zsh ties `path` to $PATH, so
# `local path=...` nukes command lookup inside the function (head/sed
# become "not found"). Same rule for all readers/collectors below.
_borg_read_directives() {
    local ppath="${1:-}" dir title f
    [[ -z "$ppath" || "$ppath" == "null" ]] && { echo "0"; return 0; }
    dir="$ppath/docs/plans/directives"
    [[ -d "$dir" ]] || { echo "0"; return 0; }
    local files=("$dir"/*.md(N))
    (( ${#files[@]} == 0 )) && { echo "0"; return 0; }
    echo "${#files[@]}"
    for f in "${files[@]}"; do
        title=$(head -1 "$f" | sed 's/^#* *//')
        printf '%s\t%s\n' "${${f:t}%.md}" "$title"
    done
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_ls() {
    local porcelain=0 show_all=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --porcelain) porcelain=1; shift ;;
            --all) show_all=1; shift ;;
            *) shift ;;
        esac
    done

    # Merge Desktop sessions into registry before listing
    borg_desktop_scan 2>/dev/null || true

    # `printf '%s' "$json" | jq`, NEVER `echo "$json" | jq`, EVERYWHERE IN THIS FUNCTION.
    # zsh's `echo` builtin expands backslash escapes by default (no BSD_ECHO), and a registry is
    # FULL of them: jq escapes every control character it serializes, so a summary containing a real
    # newline is stored as the two characters `\` `n`. `echo` turns that back into a raw 0x0A INSIDE
    # a JSON string literal, which jq then refuses --
    #   jq: parse error: Invalid string: control characters from U+0000 through U+001F must be escaped
    # -- and because borg.zsh runs under `set -e`, the whole of cmd_ls dies at the FIRST such
    # substitution. Measured, not assumed: with a `"summary": "top\nbottom"` in the registry,
    # `cmd_ls --porcelain` exits 5 having printed nothing; forced past errexit it prints the human
    # "No projects registered. Run: borg scan" line straight into fzf's stream, because the failed
    # jq left `project_count` empty and zsh arithmetic reads empty as 0.
    #
    # THIS FAILS BEFORE THE RECORD IS EVER BUILT, so it is the first half of the picker defect and
    # the flatten below is the second; fixing only the flatten fixes nothing observable.
    # `printf '%s'` is the idiom lib/registry.zsh already uses for exactly this reason.
    #
    # THE SAME `echo "$json" | jq` SPELLING APPEARS ELSEWHERE IN THIS FILE (cmd_status, cmd_next,
    # the reap/watch paths). Those are NOT touched here -- this round's scope is the picker feed --
    # and they are filed, not fixed.
    local registry
    registry=$(borg_registry_with_state)
    local project_count
    project_count=$(printf '%s' "$registry" | jq '.projects | length')

    if (( project_count == 0 )); then
        info "No projects registered. Run: borg scan"
        return 0
    fi

    if (( project_count <= 1 && ! porcelain )); then
        echo -e "  ${DIM}Tip: run 'borg scan' to discover projects from session history${NC}"
    fi

    # Sort by: pinned DESC, status priority (waiting>active>idle>archived), last_activity
    local sorted_names
    sorted_names=$(printf '%s' "$registry" | jq -r '
        .projects | to_entries |
        map(.value.name = .key) |
        map(select(if .value.status == "archived" then '$show_all' == 1 else true end)) |
        sort_by(
            (if .value.pinned == true then 0 else 1 end),
            (if .value.status == "waiting" then 0
             elif .value.status == "active" then 1
             elif .value.status == "idle" then 2
             else 3 end),
            (if .value.last_activity then .value.last_activity else "0" end)
        ) | .[].key
    ')

    if [[ -z "$sorted_names" ]]; then
        info "No projects to show. Run: borg link --all"
        return 0
    fi

    if (( porcelain )); then
        local name entry source proj_status last summary
        while IFS= read -r name; do
            entry=$(printf '%s' "$registry" | jq -c --arg p "$name" '.projects[$p]')
            source=$(printf '%s' "$entry" | jq -r '.source // "cli"')
            proj_status=$(printf '%s' "$entry" | jq -r '.status // "unknown"')
            last=$(printf '%s' "$entry" | jq -r '.last_activity // ""')
            summary=$(printf '%s' "$entry" | jq -r '.summary // ""')
            # FLATTEN THE THREE CONTROL CHARACTERS THAT REACH A RECORD, BEFORE THE 80-CHAR CUT.
            # `jq -r` prints the DECODED string, so once the parse above succeeds a summary's real
            # 0x09/0x0A/0x0D arrive here intact. This is a TSV record read back by `cmd_switch` with
            # `fzf --delimiter '\t' --with-nth 1,3,5` and then `cut -f1`: a 0x0A ends the record
            # early and makes the summary's tail a SECOND selectable row whose field 1 is prose,
            # which `cut -f1` hands to `_borg_do_switch` as a project name; a 0x09 shifts every
            # field right, so --with-nth shows the wrong status and date.
            #
            # WHY EXACTLY THESE THREE, read off lib/registry.zsh's scrub rather than guessed:
            # `_borg_registry_write` pipes through `tr -d '\000-\010\013\014\016-\037'`, deleting
            # 0x00-0x08, 0x0B, 0x0C and 0x0E-0x1F. Verified by piping a byte-per-code probe through
            # that exact `tr`: of the C0 whitespace only TAB, LF and CR survive to storage.
            #
            # BEFORE THE CUT, so the 80-char budget measures the characters the field carries. The
            # replacement is one character for one, so an already-clean summary is byte-identical
            # and no golden moves.
            #
            # LOCAL, NOT SHARED: grepped lib/*.zsh and lib/*.sh -- there is no existing flatten
            # helper to reuse, and borg_core/link/render.py's `_flatten_summary` is a separate
            # implementation on the other side of a process boundary. Introducing a chokepoint that
            # both sides route through is a design change this round is not scoped for.
            summary="${summary//[$'\t\n\r']/ }"
            summary="${summary:0:80}"
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$source" "$proj_status" "$last" "$summary"
        done <<< "$sorted_names"
        return 0
    fi

    # Human-readable table: DELETED (docs/plans/directives/2026-08-14-link-port-simplify-followups.md
    # AC1). cmd_ls's only caller in the repo is cmd_switch below, which always passes --porcelain
    # and returns above. The bare `ls` CLI dispatch arm that used to reach this branch was itself
    # removed 2026-08-10 (it now `die`s and points at `borg link`), so this fell truly unreachable
    # -- confirmed by grep across the whole repo (borg.zsh, drone.zsh, tests/) turning up no other
    # caller, not assumed.
}

cmd_status() {
    local project="${1:-}"

    if [[ -z "$project" ]]; then
        # Default to project matching current directory name
        project=$(basename "$PWD")
    fi

    if ! borg_registry_has "$project"; then
        die "project '$project' not in registry. Run: borg add [path]"
    fi

    local entry
    entry=$(borg_registry_get_with_state "$project")

    local source ppath proj_status last summary session_id tmux_window
    source=$(echo "$entry"     | jq -r '.source // "cli"')
    ppath=$(echo "$entry"      | jq -r '.path // "null"')
    proj_status=$(echo "$entry"     | jq -r '.status // "unknown"')
    last=$(echo "$entry"       | jq -r '.last_activity // "(never)"')
    summary=$(echo "$entry"    | jq -r '.summary // "(no summary)"')
    session_id=$(echo "$entry" | jq -r '.claude_session_id // "(unknown)"')
    tmux_window=$(echo "$entry"| jq -r '.tmux_window // "(none)"')

    echo -e "\n${BOLD}${project}${NC}"
    printf '%0.s─' {1..40}; echo
    echo -e "  ${DIM}Source:${NC}       $source"
    [[ "$ppath" != "null" ]] && echo -e "  ${DIM}Path:${NC}         $ppath"
    echo -e "  ${DIM}Status:${NC}       $proj_status"
    echo -e "  ${DIM}Last active:${NC}  $last"
    echo -e "  ${DIM}tmux window:${NC}  $tmux_window"
    echo -e "  ${DIM}Session ID:${NC}   $session_id"
    echo
    echo -e "  ${BOLD}Summary${NC}"
    echo -e "  $summary" | fold -s -w 70 | sed '1!s/^/  /'
    echo
}

cmd_switch() {
    local query="${*:-}"

    # If query matches exactly one project, skip fzf and switch directly
    if [[ -n "$query" ]]; then
        if borg_registry_has "$query"; then
            _borg_do_switch "$query"
            return $?
        fi
    fi

    # Build fzf input from porcelain listing
    local selection
    selection=$(cmd_ls --porcelain | \
        fzf --query "$query" \
            --prompt "borg> " \
            --header "Switch to project (Enter=switch, Esc=cancel)" \
            --delimiter '\t' \
            --with-nth 1,3,5 \
            2>/dev/null) || return 0

    local project
    project=$(echo "$selection" | cut -f1)
    [[ -z "$project" ]] && return 0

    _borg_do_switch "$project"
}

# Internal: switch to a project by name (tmux or show status)
# Usage: _borg_do_switch <project> [--silent]
#   --silent: suppress text output, use tmux display-message instead (for keybinding context)
_borg_do_switch() {
    local project="$1"
    local silent=0
    [[ "${2:-}" == "--silent" ]] && silent=1

    # Work/life boundary check (skip in silent/keybinding mode — Ctrl+Space > is itself a conscious action)
    if (( ! silent )); then
        _borg_boundary_check "$project" || return 0
    fi

    local entry
    entry=$(borg_registry_get_with_state "$project")
    # `printf '%s' "$entry" | jq`, NEVER `echo "$entry" | jq` — the SAME defect cmd_ls carried, in
    # the function cmd_switch hands its `cut -f1` selection to. zsh's `echo` expands backslash
    # escapes, and jq stores a summary's real newline as the two characters `\` `n`; `echo` turns
    # that back into a raw 0x0A inside a JSON string literal and jq refuses the document. Under
    # borg.zsh's `set -e` this function then dies before it switches anything.
    #
    # MEASURED, not assumed, on one sandbox registry (XDG_CONFIG_HOME redirected) whose alpha entry
    # carries `"summary": "top\nbottom"` and a `tmux_window`, with tmux stubbed via BORG_PATH_PREFIX:
    #   zsh -c "set -- help; source borg.zsh; _borg_do_switch alpha"
    # BEFORE: exit 5, NOTHING on stdout, `jq: parse error: Invalid string: control characters from
    # U+0000 through U+001F must be escaped` on stderr — no brief, no switch.
    # AFTER: exit 0, the brief prints (the summary's raw newline simply wraps it onto two lines,
    # which the brief can carry — unlike a TSV record), and the window is selected. So fixing only
    # cmd_ls shipped half a fix: a working picker whose selection crashed the switch.
    #
    # THE FALLBACK ARM IS STILL BROKEN AND THAT IS DELIBERATE. Drop the `tmux_window` from the same
    # registry and this function now survives all four feeds below and reaches `warn` + `cmd_status`
    # — which carries the identical `echo ... | jq` and dies there, exit 5. The same spelling also
    # survives in cmd_scan, cmd_next, cmd_tidy, _borg_print_briefing, _borg_orchestrator_context and
    # cmd_cortex_resume, and in lib/desktop.zsh's borg_desktop_scan. None of those are touched here
    # — this round's scope is the picker's immediate consumer — and they are filed, not fixed.
    local tmux_window source summary last
    tmux_window=$(printf '%s' "$entry" | jq -r '.tmux_window // ""')
    source=$(printf '%s' "$entry" | jq -r '.source // "cli"')
    summary=$(printf '%s' "$entry" | jq -r '.summary // ""')
    last=$(printf '%s' "$entry" | jq -r '.last_activity // ""')

    # If no registered window, try project name as window name
    if [[ -z "$tmux_window" || "$tmux_window" == "null" ]]; then
        if borg_tmux_window_exists "$project"; then
            tmux_window="$project"
            # Update registry so future calls are faster
            borg_registry_set "$project" "tmux_window" "\"$project\"" 2>/dev/null || true
        fi
    fi

    # Guard: tmux_window must not equal the session name (stale registry entry)
    if [[ "$tmux_window" == "$BORG_TMUX_SESSION" ]]; then
        warn "tmux_window for '$project' is '$tmux_window' (same as session name) — clearing stale entry"
        borg_registry_set "$project" "tmux_window" "null" 2>/dev/null || true
        tmux_window=""
    fi

    if [[ -n "$tmux_window" && "$tmux_window" != "null" ]]; then
        if (( silent )); then
            # In tmux keybinding context: switch first, then show brief as display-message
            borg_tmux_switch "$tmux_window" || true
            local msg="$project"
            [[ -n "$summary" && "$summary" != "null" ]] && msg="$project | ${summary:0:60}"
            tmux display-message "$msg" 2>/dev/null || true
        else
            # Auto-brief before switching (interactive context)
            if [[ -n "$summary" && "$summary" != "null" ]]; then
                echo -e "\n${DIM}─── $project ───${NC}"
                local rel_time
                rel_time=$(_borg_relative_time "$last")
                echo -e "  ${DIM}Last active:${NC} $rel_time"
                echo -e "  $summary" | fold -s -w 70 | sed '1!s/^/  /'
                echo
            fi
            info "Switching to $project ($tmux_window)"
            borg_tmux_switch "$tmux_window"
        fi
    elif [[ "$source" == "desktop" ]]; then
        if (( silent )); then
            tmux display-message "$project (Desktop session — open Claude Desktop)" 2>/dev/null || true
        else
            info "$project is a Desktop session — open Claude Desktop to continue"
            cmd_status "$project"
        fi
    else
        if (( silent )); then
            tmux display-message "borg: no tmux window for $project" 2>/dev/null || true
        else
            warn "No tmux window registered for $project"
            cmd_status "$project"
        fi
    fi
}

# Register all projects from a session log into the registry.
# Args: source label, session-id fn name, scan-log fn name, display label (optional)
# Appends to new_projects array in calling scope (zsh dynamic scoping).
_borg_scan_source() {
    local source="$1" get_session_id="$2" scan_log="$3" label="${4:-}"
    local ppath name tmux_window session_id tw_json sid_json json
    local la_json jsonl_path mtime

    while IFS= read -r ppath; do
        [[ -z "$ppath" ]] && continue
        name="${ppath##*/}"

        if borg_scan_path_should_skip "$ppath"; then
            dbg "scan: skipping $ppath"
            continue
        fi

        if borg_registry_has "$name"; then
            dbg "already registered: $name"
            continue
        fi

        tmux_window=""
        borg_tmux_window_exists "$name" && tmux_window="$name" || true
        session_id=$("$get_session_id" "$ppath") || session_id=""

        [[ -n "$tmux_window" ]] && tw_json="\"$tmux_window\"" || tw_json="null"
        [[ -n "$session_id" ]] && sid_json="\"$session_id\"" || sid_json="null"

        # Seed last_activity from transcript mtime
        la_json="null"
        if [[ -n "$session_id" ]]; then
            jsonl_path=$(borg_claude_session_jsonl "$ppath" "$session_id" 2>/dev/null) || jsonl_path=""
            if [[ -n "$jsonl_path" && -f "$jsonl_path" ]]; then
                mtime=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$jsonl_path" 2>/dev/null) || mtime=""
                [[ -n "$mtime" ]] && la_json="\"$mtime\""
            fi
        fi

        json=$(jq -n \
            --arg path "$ppath" \
            --arg source "$source" \
            --arg tmux_session "$BORG_TMUX_SESSION" \
            --argjson tmux_window "$tw_json" \
            --argjson session_id "$sid_json" \
            --argjson last_activity "$la_json" \
            '{
                path: $path,
                source: $source,
                tmux_session: $tmux_session,
                tmux_window: $tmux_window,
                claude_session_id: $session_id,
                last_activity: $last_activity,
                summary: null
            }')

        borg_registry_merge "$name" "$json"
        info "Registered: $name ($ppath)${label:+ $label}"
        new_projects+=("$name")
    done < <("$scan_log")
}

cmd_scan() {
    local use_llm=0 llm_explicit=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --llm) use_llm=1; llm_explicit=1; shift ;;
            --no-llm) use_llm=0; llm_explicit=1; shift ;;
            *) shift ;;
        esac
    done

    # ── Phase 1: Discover new projects ────────────────────────────────────────
    local new_projects=()

    info "Scanning Claude session history..."
    _borg_scan_source "cli" borg_claude_latest_session_id borg_claude_scan_session_log

    if type borg_coco_scan_session_log &>/dev/null; then
        info "Scanning Cortex Code session history..."
        _borg_scan_source "coco" borg_coco_latest_session_id borg_coco_scan_session_log "[CoCo]"
    fi

    borg_desktop_scan 2>/dev/null || true

    if (( ${#new_projects[@]} == 0 )); then
        info "No new projects found (already up to date)"
    fi

    # ── Phase 2: Refresh summaries for all registered projects ────────────────
    # LLM summaries default on (richer context, no external service to supplement it),
    # unless the user opts out with --no-llm.
    if (( ! llm_explicit && ! use_llm )); then
        use_llm=1
    fi

    info "Refreshing project summaries..."
    local llm_flag=""
    (( use_llm )) && llm_flag="--llm"

    # Read registry once, collect updates, write once
    local registry_json
    registry_json=$(borg_registry_read)
    local updated=0

    local projects name ppath session_id jsonl cur_activity file_mtime summary new_json
    projects=$(echo "$registry_json" | jq -r '.projects | keys[]')

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        ppath=$(echo "$registry_json" | jq -r --arg p "$name" '.projects[$p].path // ""')
        session_id=$(echo "$registry_json" | jq -r --arg p "$name" '.projects[$p].claude_session_id // ""')

        if [[ -z "$ppath" || "$ppath" == "null" ]]; then
            dbg "$name: no path, skipping refresh"
            continue
        fi

        if [[ -z "$session_id" || "$session_id" == "null" ]]; then
            session_id=$(borg_claude_latest_session_id "$ppath")
        fi

        if [[ -z "$session_id" ]]; then
            dbg "$name: no transcript found"
            continue
        fi

        jsonl=$(borg_claude_session_jsonl "$ppath" "$session_id")
        if [[ ! -f "$jsonl" ]]; then
            dbg "$name: transcript file not found"
            continue
        fi

        # Seed last_activity from transcript mtime if not already set
        cur_activity=$(echo "$registry_json" | jq -r --arg p "$name" \
            '.projects[$p].last_activity // ""')
        if [[ -z "$cur_activity" || "$cur_activity" == "null" ]]; then
            file_mtime=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$jsonl" 2>/dev/null) || file_mtime=""
            if [[ -n "$file_mtime" ]]; then
                registry_json=$(echo "$registry_json" | jq \
                    --arg p "$name" \
                    --arg t "$file_mtime" \
                    '.projects[$p].last_activity = $t') || true
                updated=1
            fi
        fi

        summary=$(python3 "$BORG_HOME/summarize.py" $llm_flag "$jsonl" 2>/dev/null) || summary=""

        if [[ -n "$summary" ]]; then
            new_json=$(echo "$registry_json" | jq \
                --arg p "$name" \
                --arg s "$summary" \
                --arg sid "$session_id" \
                '.projects[$p].summary = $s | .projects[$p].claude_session_id = $sid')
            if [[ -n "$new_json" ]]; then
                registry_json="$new_json"
                updated=1
                info "$name: summary updated"
            else
                warn "$name: jq failed updating summary, skipping"
            fi
        fi
    done < <(echo "$projects")

    if (( updated )); then
        echo "$registry_json" | _borg_registry_write
    fi
}

cmd_color() {
    local project="${1:-}" color="${2:-}"
    [[ -z "$project" || -z "$color" ]] && die "Usage: borg color <project> <color>"
    borg_registry_has "$project" || die "Unknown project: $project"
    borg_registry_set "$project" "color" "\"$color\""
    info "Color for $project → $color"
    if borg_tmux_window_exists "$project" 2>/dev/null; then
        _borg_apply_window_color "$project" "$color"
        info "Applied to live tmux window."
    fi
}

cmd_image() {
    local subcmd="${1:-help}"
    local registry="${BORG_IMAGE_REGISTRY:-}"
    local dotfiles_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
    local dockerfile="$dotfiles_dir/devcontainer/Dockerfile.base"
    local context="$dotfiles_dir/devcontainer"
    local local_tag="devcontainer-base:local"

    case "$subcmd" in
        build)
            info "Building $local_tag..."
            if [[ -n "$registry" ]]; then
                docker build -f "$dockerfile" -t "$local_tag" -t "$registry/devcontainer-base:latest" "$context"
                info "Tagged: $local_tag  $registry/devcontainer-base:latest"
            else
                docker build -f "$dockerfile" -t "$local_tag" "$context"
                info "Built: $local_tag (set BORG_IMAGE_REGISTRY in config.zsh to also tag for push)"
            fi
            ;;
        push)
            [[ -z "$registry" ]] && die "BORG_IMAGE_REGISTRY not set — add it to ~/.config/borg/config.zsh"
            local remote_tag="$registry/devcontainer-base:latest"
            echo ""
            warn "About to push to: $remote_tag"
            printf "  Type 'yes' to confirm: "
            read -r _confirm
            [[ "$_confirm" == "yes" ]] || die "Cancelled."
            docker push "$remote_tag"
            info "Pushed: $remote_tag"
            ;;
        pull)
            [[ -z "$registry" ]] && die "BORG_IMAGE_REGISTRY not set — add it to ~/.config/borg/config.zsh"
            local remote_tag="$registry/devcontainer-base:latest"
            info "Pulling $remote_tag..."
            docker pull "$remote_tag"
            docker tag "$remote_tag" "$local_tag"
            info "Pulled and tagged as $local_tag"
            ;;
        *)
            echo "Usage: borg image <build|push|pull>"
            echo ""
            echo "  build   Build $local_tag from dotfiles Dockerfile.base"
            echo "          If BORG_IMAGE_REGISTRY is set, also tags for push"
            echo "  push    Push to BORG_IMAGE_REGISTRY (requires confirmation)"
            echo "  pull    Pull from BORG_IMAGE_REGISTRY, tag as $local_tag"
            echo ""
            echo "  Set BORG_IMAGE_REGISTRY in ~/.config/borg/config.zsh"
            ;;
    esac
}

cmd_refresh() {
    # Deprecated: use 'borg scan' instead. Kept for backwards compatibility.
    cmd_scan --llm
}

cmd_focus() {
    # Merged into cmd_switch — focus is just switch with a direct argument
    cmd_switch "${@:-}"
}

cmd_next() {
    local do_switch=0
    [[ "${1:-}" == "--switch" ]] && do_switch=1

    # Merge Desktop sessions
    borg_desktop_scan 2>/dev/null || true

    local registry
    registry=$(borg_registry_with_state)

    # Score and sort projects: pinned +200, waiting +100, active +50, idle +10, no activity -50
    # Tiebreaker: waiting → oldest first (neglected longest); active/idle → newest first
    local top
    top=$(echo "$registry" | jq -r '
        .projects | to_entries |
        map(select(.value.status != "archived")) |
        map({
            name: .key,
            score: (
                (if .value.pinned == true then 200 else 0 end) +
                (if .value.status == "waiting" then 100
                 elif .value.status == "active" then 50
                 elif .value.status == "idle" then 10
                 else 0 end) +
                (if .value.last_activity == null then -50 else 0 end) +
                (if (.value.tmux_window != null and .value.tmux_window != "") then 5 else 0 end)
            ),
            status: .value.status,
            summary: (.value.summary // ""),
            waiting_reason: (.value.waiting_reason // ""),
            last_activity: (.value.last_activity // ""),
            pinned: (.value.pinned // false),
            path: (.value.path // "null")
        }) |
        sort_by(-.score, .last_activity) |
        first // empty
    ')

    if [[ -z "$top" || "$top" == "null" ]]; then
        if (( do_switch )); then
            tmux display-message "All clear — take a break" 2>/dev/null || true
        else
            echo -e "\n${GREEN}▸${NC} All clear. Take a break.\n"
        fi
        return 0
    fi

    local name proj_status summary waiting_reason last pinned ppath
    name=$(echo "$top" | jq -r '.name')
    proj_status=$(echo "$top" | jq -r '.status')
    summary=$(echo "$top" | jq -r '.summary')
    waiting_reason=$(echo "$top" | jq -r '.waiting_reason')
    last=$(echo "$top" | jq -r '.last_activity')
    pinned=$(echo "$top" | jq -r '.pinned')
    ppath=$(echo "$top" | jq -r '.path // "null"')

    # --switch mode: skip all output, switch immediately
    if (( do_switch )); then
        _borg_do_switch "$name" --silent
        return $?
    fi

    local rel_time
    rel_time=$(_borg_relative_time "$last")

    local pin_label=""
    [[ "$pinned" == "true" ]] && pin_label=" ${BOLD}[pinned]${NC}"

    local status_color
    case "$proj_status" in
        waiting) status_color="$YELLOW" ;;
        active)  status_color="$GREEN" ;;
        *)       status_color="$DIM" ;;
    esac

    echo -e "\n${GREEN}▸${NC} ${BOLD}Next up: $name${NC}  (${status_color}$proj_status${NC}, $rel_time)$pin_label"

    if [[ -n "$waiting_reason" && "$waiting_reason" != "null" ]]; then
        echo -e "  ${YELLOW}Needs:${NC} $waiting_reason"
    fi
    if [[ -n "$summary" && "$summary" != "null" ]]; then
        echo -e "  $summary" | fold -s -w 70 | sed '1!s/^/  /'
    fi

    # Directives for recommended project (from its own docs/plans/directives/)
    if [[ "$ppath" != "null" ]]; then
        local directive_output directive_count
        directive_output=$(_borg_read_directives "$ppath")
        directive_count=$(echo "$directive_output" | head -1)
        if (( directive_count > 0 )); then
            echo -e "\n  ${CYAN}Directives:${NC} $directive_count pending for $name"
            # tab-safe: slug (filename, never empty) is field 1 of 2; an empty title
            # (field 2, last) cannot shift anything after it.
            echo "$directive_output" | tail -n +2 | head -3 | while IFS=$'\t' read -r slug title; do
                [[ -z "$slug" ]] && continue
                echo -e "    ${DIM}- $title${NC}"
            done
        fi
    fi

    # Reaper notice — stale active/waiting sessions auto-downgraded to idle for this view
    local reaped_count
    reaped_count=$(echo "$registry" | jq '[.projects[] | select(._reaped_from != null)] | length')
    if (( reaped_count > 0 )); then
        echo -e "\n  ${DIM}($reaped_count stale session(s) auto-downgraded to idle — run 'borg reap' to persist)${NC}"
    fi

    # Capacity warning
    local active_count
    active_count=$(_borg_active_count)
    if (( active_count > BORG_MAX_ACTIVE )); then
        echo -e "\n  ${YELLOW}WARNING:${NC} $active_count sessions need attention (limit: $BORG_MAX_ACTIVE)"
    fi

    echo -e "\n  ${DIM}Ctrl+Space > to jump there${NC}\n"
}

cmd_pin() {
    local project="${1:-}"
    [[ -z "$project" ]] && project="${PWD##*/}"
    borg_registry_has "$project" || die "project '$project' not in registry"
    borg_registry_set "$project" "pinned" "true"
    info "Pinned: $project"
}

cmd_unpin() {
    local project="${1:-}"
    [[ -z "$project" ]] && project="${PWD##*/}"
    borg_registry_has "$project" || die "project '$project' not in registry"
    borg_registry_set "$project" "pinned" "false"
    info "Unpinned: $project"
}

# Durably reap stale active/waiting sessions to idle. A session is stale when it
# is active/waiting with no live tmux window AND no activity within
# BORG_REAP_STALE_HOURS (default 12). The read path (next/ls/capacity) already
# treats these as idle non-destructively; this command persists status=idle to
# the corresponding state.json files (atomic write).
cmd_reap() {
    local reaped name from count=0
    reaped=$(borg_reap_persist)
    if [[ -z "$reaped" ]]; then
        info "Nothing to reap — all active/waiting sessions are live or recent."
        return 0
    fi
    # tab-safe: name is field 1 of 2 (borg_reap_persist never emits an empty name); an empty
    # `from` (field 2, last) cannot shift anything after it.
    while IFS=$'\t' read -r name from; do
        [[ -z "$name" ]] && continue
        info "Reaped ${BOLD}$name${NC} ($from → idle) — no live session"
        count=$((count + 1))
    done <<< "$reaped"
    echo
    info "$count stale session(s) downgraded to idle (threshold: ${BORG_REAP_STALE_HOURS:-12}h)"
}

# Remove stale borg-managed nanoprobe worktrees for one or all registered repos.
# A worktree is stale when its branch is merged into the default branch OR when it
# is older than BORG_REAP_STALE_HOURS (default 12h). Only worktrees under
# ~/.local/state/borg/worktrees/ are ever touched. Uncommitted-change worktrees are
# always skipped.
#
# Usage:
#   borg reap-worktrees            # reap across all registered repos
#   borg reap-worktrees <project>  # reap for one registered project
cmd_reap_worktrees() {
    local target_project="${1:-}"
    local repo_paths=()

    if [[ -n "$target_project" ]]; then
        local ppath
        ppath=$(borg_registry_get "$target_project" | jq -r '.path // empty' 2>/dev/null)
        [[ -n "$ppath" ]] || die "unknown project '$target_project'"
        repo_paths=("$ppath")
    else
        while IFS= read -r ppath; do
            [[ -n "$ppath" ]] && repo_paths+=("$ppath")
        done < <(borg_registry_read | jq -r '.projects[].path // empty' 2>/dev/null)
    fi

    if (( ${#repo_paths[@]} == 0 )); then
        info "No registered projects found."
        return 0
    fi

    local total=0
    local repo wt reason
    for repo in "${repo_paths[@]}"; do
        [[ -d "$repo" ]] || continue
        # tab-safe: wt (worktree path) is field 1 of 2 and never empty; reason (field 2,
        # last, always one of two hardcoded strings) cannot shift anything after it.
        while IFS=$'\t' read -r wt reason; do
            [[ -z "$wt" ]] && continue
            info "Reaped worktree ${BOLD}${wt##*/}${NC} in ${repo##*/} (${reason})"
            total=$((total + 1))
        done < <(_borg_reap_worktrees "$repo")
    done

    if (( total == 0 )); then
        info "No stale borg worktrees found."
    else
        echo
        info "$total stale worktree(s) removed (threshold: ${BORG_REAP_STALE_HOURS:-12}h)"
    fi
}

# Return 0 if a checkpoint was written within the last THRESHOLD hours, 1 otherwise.
_borg_has_recent_checkpoint() {
    local pdir="$1" threshold_hours="${2:-8}"
    local cp_dir="$pdir/.borg/checkpoints"
    [[ -d "$cp_dir" ]] || return 1
    local latest
    latest=$(ls -t "$cp_dir"/*.md 2>/dev/null | head -1)
    [[ -n "$latest" ]] || return 1
    local mtime now age
    # Was `stat -f %m` with no fallback — BSD-only, so this returned 1 on Linux/CI and every
    # caller read "no recent checkpoint" regardless of the actual mtime. Use the shared helper.
    mtime=$(_borg_file_mtime "$latest") || return 1
    now=$(date +%s)
    age=$(( (now - mtime) / 3600 ))
    (( age < threshold_hours ))
}

# Offer to run /borg-link-up in the Claude pane of a window, then wait for the
# checkpoint file to appear (up to TIMEOUT seconds) before returning.
_borg_offer_checkpoint() {
    local wname="$1" pdir="$2" timeout="${3:-120}" threshold_hours="${4:-8}"

    warn "$wname has no checkpoint from the last ${threshold_hours} hours."
    printf "  Run /borg-link-up in that session now? [Y/n] "
    local reply
    read -r reply
    [[ "$reply" =~ ^[Nn]$ ]] && return 0  # user declined — proceed with sever

    # Identify the Claude (rightmost) pane in the window.
    local claude_pane
    claude_pane=$(tmux list-panes -t "$BORG_TMUX_SESSION:$wname" \
        -F '#{pane_left} #{pane_id}' 2>/dev/null \
        | sort -rn | head -1 | awk '{print $2}')

    if [[ -z "$claude_pane" ]]; then
        warn "Could not find a pane in $wname — severing without checkpoint."
        return 0
    fi

    # Record the newest checkpoint before we trigger the skill.
    local cp_dir="$pdir/.borg/checkpoints"
    local before_newest
    before_newest=$(ls -t "$cp_dir"/*.md 2>/dev/null | head -1)

    info "Sending /borg-link-up to $wname (waiting up to ${timeout}s)..."
    tmux send-keys -t "$claude_pane" "/borg-link-up" Enter

    # Poll until a new checkpoint file appears or we time out.
    local deadline=$(( $(date +%s) + timeout ))
    while (( $(date +%s) < deadline )); do
        local newest
        newest=$(ls -t "$cp_dir"/*.md 2>/dev/null | head -1)
        if [[ -n "$newest" && "$newest" != "$before_newest" ]]; then
            info "Checkpoint saved. Proceeding with sever."
            return 0
        fi
        sleep 3
    done

    warn "Timed out waiting for checkpoint. Severing $wname anyway."
}

# Stop the shared stillpoint Supabase stack if it is running. Mirrors the
# idempotent running-check in templates/supabase-shared/borg-hooks/pre-up.sh.
# Fail-open on every path (no docker, no supabase CLI, missing config, stop
# error) so it can never block a sever.
_borg_stop_shared_supabase() {
    command -v docker >/dev/null 2>&1 || return 0

    local running
    running=$(docker inspect -f '{{.State.Running}}' supabase_db_stillpoint 2>/dev/null) || true
    [[ "$running" == "true" ]] || return 0

    local stillpoint_dir="${BORG_STILLPOINT_SUPABASE_DIR:-$HOME/dev/stillpoint}"
    if ! command -v supabase >/dev/null 2>&1 || [[ ! -d "$stillpoint_dir/supabase" ]]; then
        warn "Shared stillpoint Supabase stack is running but cannot be stopped automatically."
        warn "  Stop it manually: cd $stillpoint_dir && supabase stop"
        return 0
    fi

    info "Stopping shared stillpoint Supabase stack..."
    ( cd "$stillpoint_dir" && supabase stop ) 2>/dev/null \
        || warn "supabase stop failed — stop it manually: cd $stillpoint_dir && supabase stop"
}

cmd_down() {
    info "Severing link to the Collective..."

    if ! borg_tmux_alive; then
        info "No borg tmux session running."
        return 0
    fi

    local windows
    windows=(${(f)"$(tmux list-windows -t "$BORG_TMUX_SESSION" -F '#W' 2>/dev/null)"})
    local checkpoint_threshold_hours=8

    for wname in $windows; do
        [[ "$wname" == "orchestrator" || "$wname" == "host" ]] && continue
        local pdir
        pdir=$(tmux show-option -t "$BORG_TMUX_SESSION:$wname" -v @project_dir 2>/dev/null) || true
        if [[ -n "$pdir" ]]; then
            _borg_has_recent_checkpoint "$pdir" "$checkpoint_threshold_hours" \
                || _borg_offer_checkpoint "$wname" "$pdir" "" "$checkpoint_threshold_hours"
            info "Stopping $wname..."
            drone down "$wname" 2>/dev/null || tmux kill-window -t "$BORG_TMUX_SESSION:$wname" 2>/dev/null || true
        else
            tmux kill-window -t "$BORG_TMUX_SESSION:$wname" 2>/dev/null || true
        fi
    done

    # Stop shared postgres
    local postgres_compose="$HOME/.config/dotfiles/devcontainer/docker-compose.postgres.yml"
    [[ -f "$postgres_compose" ]] && docker compose -f "$postgres_compose" down 2>/dev/null || true

    # Stop the ALWAYS-ON shared stillpoint Supabase stack. Per-project
    # borg-hooks/post-down.sh intentionally never touches it (it is shared
    # across projects), so sever — the deliberate "tear down everything" —
    # is the one place that stops it explicitly. Fail-open: never block sever.
    _borg_stop_shared_supabase

    # Kill the tmux session
    tmux kill-session -t "$BORG_TMUX_SESSION" 2>/dev/null || true
    info "Disconnected from the Collective. You are Hugh now."
}

cmd_tidy() {
    local now_epoch=$(date +%s)
    local stale_threshold=$(( 48 * 3600 ))
    local candidates=()

    local registry
    registry=$(borg_registry_read)
    local name last epoch_last diff

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local entry
        entry=$(echo "$registry" | jq -c --arg p "$name" '.projects[$p]')
        local proj_status
        proj_status=$(echo "$entry" | jq -r '.status // "unknown"')
        [[ "$proj_status" == "archived" ]] && continue

        last=$(echo "$entry" | jq -r '.last_activity // ""')
        [[ -z "$last" || "$last" == "null" ]] && { candidates+=("$name (never active)"); continue; }

        epoch_last=$(_borg_iso_to_epoch "$last") || continue
        diff=$(( now_epoch - epoch_last ))
        if (( diff > stale_threshold )); then
            local rel
            rel=$(_borg_relative_time "$last")
            candidates+=("$name ($rel)")
        fi
    done < <(echo "$registry" | jq -r '.projects | keys[]')

    if (( ${#candidates[@]} == 0 )); then
        info "No stale projects. Everything is fresh."
        return 0
    fi

    echo -e "\n${BOLD}Stale projects${NC} (idle >48h):\n"
    local c
    for c in "${candidates[@]}"; do
        echo "  - $c"
    done

    echo -ne "\n${YELLOW}▸${NC} Archive all? [y/N] "
    read -rk1 reply
    echo

    if [[ "$reply" == [yY] ]]; then
        for c in "${candidates[@]}"; do
            local pname="${c%% (*}"
            borg_registry_set "$pname" "status" '"archived"'
            info "Archived: $pname"
        done
    else
        info "No changes."
    fi
}

# The narrative half of `borg link --brief`, and of `borg init`'s morning briefing.
#
# THIS FUNCTION BUILDS NO VIEW OF ITS OWN. It builds the ONE `borg link` document — the same
# `_borg_py borg_core.link.cli --json` every other dispatch arm builds — projects that JSON into the
# LLM prompt, and renders THOSE SAME BYTES through THAT SAME renderer when the narrative is
# unavailable. One invocation, one sweep, one clock read, two consumers.
#
# WHAT THIS REPLACED, AND WHY IT IS NOT COMING BACK (2026-08-27 directive "Fold `--brief` onto the
# document"): 177 lines that re-derived a board from `borg_registry_with_state` — its own 30-day
# active/inactive split, its own waiting-first sort, one `jq` per project for `status` /
# `last_activity` / `summary` / `waiting_reason` / `path`, its own `_borg_relative_time` call, its own
# `find .borg/checkpoints | sort -r | head -1`, and a hand-rolled fallback table. Every one of those
# fields is already on the document, computed once, with the staleness overlay applied. The second
# derivation WAS the defect: `borg link` and `borg link --brief` were two truth levels of one
# command, and `--brief` never reached the Python tier at all, so it could not see a sweep, a
# manifest, a gate or a ready set. If you find yourself reaching for `borg_registry_with_state` in
# here, the fold has been undone.
#
# ARGS: $1 = --all (0/1), $2 = --local (0/1), forwarded exactly as every other arm forwards them.
# `borg init` passes neither, so the morning briefing is orchestrator-breadth and SWEPT — a real cost
# change from the registry-only read it used to do, and the intended one.
#
# THE `claude -p` CALL STAYS IN zsh, AND THAT IS A CONSTRAINT RATHER THAN INERTIA. borg_core/proc.py
# is borg_core's only sanctioned fork; it hard-wires `stderr=subprocess.DEVNULL` and returns None
# (not rc 124) on timeout. Moving this invocation into Python would silently delete two shipped
# contracts — the reason line that names the exit code AND the captured stderr text it carries, and
# the timeout branch below. Only the PROMPT INPUT and the FALLBACK PAGE moved.
_borg_print_briefing() {
    # Suppress xtrace — trace output pollutes the briefing when PS4 is empty.
    setopt LOCAL_OPTIONS
    set +x

    local doc payload rows briefing_prompt briefing
    local fallback_reason=""
    # Non-zero ONLY when the fallback page itself failed to render; the narrative path never sets it.
    local render_rc=0
    local build_rc=0
    typeset -a _brief_py_args
    _brief_py_args=(--json)
    (( ${1:-0} )) && _brief_py_args+=(--all)
    (( ${2:-0} )) && _brief_py_args+=(--local)

    # A FAILED BUILD IS AS LOUD AS A FAILED RENDER, AND FOR THE SAME REASON. This branch used to
    # `warn` (which writes to STDOUT — see its definition beside `info`/`die` at the top of this
    # file) and `return 0`, so `borg link --brief` printed no page and reported success: the exact
    # state the comment on this function's `return` declares must never be reported as success, and
    # the silent-fallback shape docs/plans/directives/
    # 2026-08-10-briefing-fallback-and-summary-provenance.md Phase 1 exists to remove. The render
    # rung two screens down was fixed first; this is its sibling, and the two now behave
    # identically: reason on STDERR, the child's own stderr quoted in it, non-zero out.
    #
    # `|| build_rc=$?` REPLACES `|| doc=""` AND STILL DOES ITS JOB. Catching the status is mandatory,
    # not defensive habit: this file's top-of-script `set -e` (just above `BORG_VERSION=`) aborts
    # borg outright on any uncaught non-zero, a bare assignment from a command substitution inherits
    # the child's exit status, and `cli._die_json` exits 1 on a corrupt registry. The old
    # `|| doc=""` caught it and threw it away; `|| build_rc=$?` catches it AND gives the reason line
    # a number.
    local build_stderr_file="$BORG_DIR/briefing-build-stderr.log"
    doc=""
    doc=$(_borg_py borg_core.link.cli "${_brief_py_args[@]}" 2>"$build_stderr_file") || build_rc=$?
    if [[ -z "$doc" ]]; then
        local build_stderr=""
        [[ -s "$build_stderr_file" ]] && build_stderr=$(<"$build_stderr_file")
        # A build that exits 0 and prints nothing is still a failure with no page; give it a status.
        if (( build_rc == 0 )); then
            build_rc=1
        fi
        warn "Could not build the borg link document (exit $build_rc)${build_stderr:+: $build_stderr} — no briefing to give." >&2
        return $build_rc
    fi

    # The nothing-to-say short circuit, keyed off the DOCUMENT rather than a second registry read.
    # Kept rather than folded away because it is the one case where there is nothing for a narrative
    # to say, and paying `claude -p` to say it is pure waste.
    #
    # `.order`, NOT `.total_projects`, AND THE DIFFERENCE IS A REAL REGISTRY STATE. `core.assemble`
    # sets `total_projects` from the UNFILTERED project map ON PURPOSE (see its docstring: the page
    # must distinguish an empty registry from an all-archived one, which both emit `order: []`).
    # `.order` is the post-archived-filter list, and it is EXACTLY the list this function projects
    # into the prompt below — so it is the only count that answers "is there anything to narrate".
    # The deleted registry walk excluded archived entries too, so keying on `total_projects` silently
    # changed behaviour for an all-archived registry: the short circuit stopped firing and the
    # narrative paid for `claude -p` to describe a board with zero rows on it. `--all` puts archived
    # rows back in `.order`, so it opts back into a narrative, which is what asking for them means.
    rows=$(printf '%s' "$doc" | jq -r '(.order // []) | length' 2>/dev/null) || rows=0
    if [[ -z "$rows" || "$rows" == "0" || "$rows" == "null" ]]; then
        info "No projects in registry. Run: borg scan"
        return 0
    fi

    # ONE jq over the whole document, never one per project — and no `read` loop, so the \x1f
    # delimiter this function used to need is gone with it: JSON cannot field-shift an empty summary
    # into the next column. The projection is deliberately NARROWER than the document (~40KB raw,
    # 141 directive rows on the author's machine): it carries the board rows in `.order` (already
    # sorted, and the model is told not to re-sort), the sweep's provenance, `.grid.warnings`, each
    # manifest's READY set and gates, and the focused repository's checkpoint head.
    #
    # `.grid.warnings` IS NOT GARNISH. It is where every sweep, fetch and discovery failure surfaces,
    # and a prompt built without it lets the narrative describe a degraded sweep as a clean one —
    # the wrong-answer-under-a-confident-header failure this plan exists to remove.
    #
    # THE ONE INPUT THIS NARROWS, consciously: the old payload carried 1500 bytes of the newest
    # checkpoint for EVERY active project; the document carries `checkpoint_head` for the FOCUSED
    # repository only. Widening the wire to a per-project head is a v2→v3 bump with four coupled
    # SKILL.md edits, and re-reading checkpoints here would reinstate the second derivation this
    # function just lost. The grid's per-node provenance is the replacement input, which is exactly
    # the trade the 2026-08-27 directive argues for.
    #
    # `$breadth` IS render._scoped_rows, TRANSCRIBED — NOT A SECOND RULE. QUEUED and SHIPPED are the
    # only two scope-DEPENDENT lists on the wire, and `--json` always carries the registry-wide
    # aggregate regardless of scope (cli.py's `need_aggregate = mode == "json" or ...`, deliberately,
    # so skills/borg-link/SKILL.md's bare `--json | jq '.directives'` answers for the collective from
    # inside any repository). The HUMAN page narrows them at render time instead:
    # `render._scoped_rows` reads `doc.focus[key]` when `scope.kind == "repository"`. A projection
    # that read the top-level aggregate unconditionally handed the prompt "QUEUED: 141 open
    # directives" while the fallback page rendered from THOSE SAME BYTES said "nothing queued" —
    # measured on the author's registry, 141/3 aggregate against 0/0 focused. One invocation, two
    # answers: the exact failure class the fold exists to remove, reintroduced by the fold itself.
    # Bind the breadth ONCE, here, and read every scope-dependent list off it; if a third such list
    # ever lands on the wire, it goes through `$breadth` too rather than growing a rule of its own.
    #
    # jq's STDERR IS CAPTURED, NOT DISCARDED — see the empty-payload branch below for why. No
    # explicit truncation of the file: `2>` on the command substitution opens it O_TRUNC, exactly as
    # the `claude` call's own stderr capture does further down.
    local jq_stderr_file="$BORG_DIR/briefing-projection-stderr.log"
    payload=$(printf '%s' "$doc" | jq -r '
        . as $d
        | (if ($d.scope.kind // "") == "repository" then ($d.focus // {}) else $d end) as $breadth
        | [
            "SCOPE: \($d.scope.kind)"
              + (if (($d.scope.repository // "") | length) > 0 then " — \($d.scope.repository)" else "" end),
            "CAPACITY: \($d.capacity.active) active of \($d.capacity.limit)"
              + (if $d.capacity.over_limit then " (OVER LIMIT)" else "" end),
            "SWEEP: " + (if $d.grid.swept
                         then "sources swept since \($d.grid.since)"
                         else "NOT swept — every state below is what a manifest declares, not what was observed" end),
            "DECLARED REFS: \($d.grid.declared) declared, \($d.grid.unresolved) still unresolved"
          ]
          + (if (($d.grid.sources // []) | length) > 0
             then ["SOURCES:"] + ($d.grid.sources | map("  \(.source): \(.status), \(.count) items"))
             else [] end)
          + (if (($d.grid.warnings // []) | length) > 0
             then ["SWEEP WARNINGS — never describe a degraded sweep as a clean one:"]
                  + ($d.grid.warnings | map("  " + .))
             else [] end)
          + ["QUEUED: \(($breadth.directives // []) | length) open directives"]
          + (if (($breadth.assimilated // []) | length) > 0
             then ["SHIPPED RECENTLY:"] + ($breadth.assimilated | map("  \(.title // .slug)"))
             else [] end)
          + ["", "PROJECTS (already in priority order — most urgent first; do not re-sort):"]
          + ($d.order | map(. as $n | $d.projects[$n] as $p |
              (["PROJECT: \($n)",
                "status: \($p.status // "unknown")",
                "last_active: \($p.relative_activity // "never")",
                "summary: \($p.summary // "")"]
               + (if (($p.waiting_reason // "") | length) > 0
                  then ["waiting_reason: \($p.waiting_reason)"] else [] end)
               + (if (($p.summary // "") | length) == 0
                  then ["note: no summary on record — describe this one by state only, invent nothing"]
                  else [] end)
               + (if $n == ($d.scope.repository // "")
                  then ["note: this is the repository the user is standing in"] else [] end)
               + [""])
              | join("\n")))
          + (($d.grid.manifests // []) | map(. as $m |
              (["PROJECT MANIFEST: \($m.id) — \($m.desc // "")"]
               + (if ($m.ready.state // "unlooked") == "known"
                  then (if (($m.ready.refs // []) | length) > 0
                        then ($m.ready.refs | map(. as $r | $m.nodes[$r] as $node |
                                "  READY: \($r) — \($node.why // "") [\($node.state // "?"), \($node.state_source // "?")]"))
                        else ["  READY: nothing in this manifest is ready right now"] end)
                  else ["  READY: unlooked — the sweep did not resolve enough to say"] end)
               + (($m.gates // []) | map("  GATE (\(.kind)) at \(.ref)"
                    + (if ((.blocked_by // "") | length) > 0 then " — blocked by: \(.blocked_by)" else "" end)))
               + [""])
              | join("\n")))
          + (if $d.focus != null and ((($d.focus.checkpoint_head // "") | length) > 0)
             then ["--- latest checkpoint for \($d.focus.name) ---", $d.focus.checkpoint_head,
                   "--- end checkpoint ---", ""]
             else [] end)
          | join("\n")
    ' 2>"$jq_stderr_file") || payload=""
    local jq_stderr=""
    [[ -s "$jq_stderr_file" ]] && jq_stderr=$(<"$jq_stderr_file")

    # AN EMPTY PROJECTION IS A FALLBACK, NEVER A PROMPT. `doc` is non-empty and carries at least one
    # board row by the short circuit above, so a `payload` of zero bytes can only mean the projection
    # broke — a jq that is not installed, or a `$d.grid`/`$d.scope` shape the document no longer has.
    # Shipping it anyway sent `claude -p` the literal string "DOCUMENT:" followed by nothing, and the
    # model answered from an empty board: a confident narrative with no input, printed with NO reason
    # line, because `fallback_reason` was only ever set on `claude` failures. Fail to the real page
    # instead, and name the cause the same way every other branch of the ladder does — jq's own
    # stderr, captured for exactly this, rather than the `2>/dev/null` that used to discard it
    # alongside the exit status.
    if [[ -z "$payload" ]]; then
        fallback_reason="the document projection produced nothing"
        [[ -n "$jq_stderr" ]] && fallback_reason+=": ${jq_stderr}"
    fi

    IFS= read -r -d '' briefing_prompt <<EOF || true
Generate a morning briefing for a developer. Output plain text for a terminal — no markdown, no headers, no bullet symbols.

For each project write exactly these lines (omit Blocked line if not waiting):
  <name>  [<status>, <relative_time>]
    Last: <one sentence — what was accomplished. Use the latest checkpoint if there is one, else summary>
    Next: <one sentence — most important next action. Prefer a READY ref from a project manifest>
    Blocked: <waiting_reason>  ← only if status is waiting

After all projects, add one blank line then:
  Focus: <project_name> — <one sentence why it needs attention first>

The projects below are already in priority order — keep it. Keep each line under 80 chars.

PROVENANCE. Every state below carries its source. A node marked "declared" was typed into a manifest
by a human; one marked "swept" or "fetched" was observed on GitHub during this run. Never present a
declared state as an observed one. If SWEEP says NOT swept, or any SWEEP WARNING is present, say so
in one clause rather than describing the picture as current.

DOCUMENT:
$payload
EOF

    echo ""

    # THE WHOLE NARRATIVE HALF IS SKIPPED WHEN THERE IS NOTHING TO NARRATE FROM. A projection failure
    # is already a decided fallback; forking `claude -p` anyway would bill for a briefing built on an
    # empty DOCUMENT block and then throw the answer away — or worse, print it.
    briefing=""
    if [[ -z "$fallback_reason" ]]; then
        info "Building morning briefing..."

        # Capture stderr to a file under $BORG_DIR instead of /dev/null (was silent — see
        # docs/plans/directives/2026-08-10-briefing-fallback-and-summary-provenance.md). The fallback
        # path being taken with NO indication of why is the defect this whole function exists to fix.
        local claude_rc=0
        local claude_stderr_file="$BORG_DIR/briefing-stderr.log"
        briefing=$(_borg_timeout 20 claude -p "$briefing_prompt" \
            --model claude-haiku-4-5-20251001 --no-session-persistence --bare 2>"$claude_stderr_file") \
            || claude_rc=$?
        local claude_stderr=""
        [[ -s "$claude_stderr_file" ]] && claude_stderr=$(<"$claude_stderr_file")

        # Provenance: distinguish WHY the fallback fired, at minimum timeout / not-logged-in / any
        # other non-zero exit. `fallback_reason` is empty iff the narrative call actually succeeded.
        if [[ $claude_rc -eq 124 ]]; then
            fallback_reason="claude -p timed out after 20s"
            briefing=""
        elif [[ "$briefing" == *"Not logged in"* ]]; then
            # claude exits 0 on auth failure — the string match is the only signal.
            fallback_reason="claude not logged in (headless CLI has no usable credentials on this machine)"
            briefing=""
        elif [[ $claude_rc -ne 0 ]]; then
            fallback_reason="claude -p exited $claude_rc"
            [[ -n "$claude_stderr" ]] && fallback_reason+=": ${claude_stderr}"
            briefing=""
        elif [[ -z "$briefing" ]]; then
            fallback_reason="claude -p returned empty output"
        fi
    fi

    if [[ -n "$briefing" ]]; then
        echo ""
        echo "$briefing"
    else
        # THE FALLBACK IS THE DOCUMENT ITSELF, re-rendered from the SAME BYTES the prompt above was
        # built from -- never a rebuild. A second `_borg_py borg_core.link.cli` here would read the
        # clock again, sweep GitHub again and glob every manifest again, so the page the user finally
        # reads could carry a different `generated_at`, a different sweep mark and a different set of
        # PR states than the narrative that just failed. That is two truth levels inside ONE
        # invocation -- the exact defect the fold exists to remove, re-created one layer down.
        #
        # It also deletes the drift risk outright: there is no hand-rolled fallback table left to
        # diverge from the real page, because the fallback IS the real page.
        #
        # A FAILED FALLBACK RENDER IS THE LOUDEST FAILURE IN THIS FUNCTION, NOT THE QUIETEST. This
        # line used to end in `|| true`, which meant the ONE path that guarantees the user always
        # gets a page could print nothing and still exit 0 — the silent-fallback shape
        # docs/plans/directives/2026-08-10-briefing-fallback-and-summary-provenance.md Phase 1
        # exists to remove ("make the failure loud"), reintroduced at the last step of the ladder
        # that implements it. Every branch above names its cause; so does this one. The reason line
        # is redirected to STDERR because `warn` itself writes to STDOUT (see its definition beside
        # `info`/`die` at the top of this file) and at this point stdout is the page — a warning
        # spliced into it is indistinguishable from content.
        # `cli._render_document_from_stdin` deliberately catches nothing, so `main`'s single
        # exception boundary has already put `▸ ERROR: ...` on the child's stderr — that text is the
        # reason, captured the same way the `claude -p` and `jq` branches capture theirs.
        echo ""
        if [[ -n "$fallback_reason" ]]; then
            echo -e "  ${DIM}(narrative unavailable: $fallback_reason — showing the borg link document)${NC}"
            echo ""
        fi
        local render_stderr_file="$BORG_DIR/briefing-render-stderr.log"
        printf '%s' "$doc" | _borg_py borg_core.link.cli --render-document 2>"$render_stderr_file" \
            || render_rc=$?
        if (( render_rc != 0 )); then
            local render_stderr=""
            [[ -s "$render_stderr_file" ]] && render_stderr=$(<"$render_stderr_file")
            warn "Could not render the borg link document (exit $render_rc)${render_stderr:+: $render_stderr}" >&2
        fi
    fi
    echo ""
    # THE EXIT CODE CARRIES IT TOO. A caller that pipes or scripts `borg link --brief` cannot see the
    # stderr line; a non-zero status is the only signal it can act on, and "exited 0 having printed
    # no page" is precisely the state that must not be reported as success.
    return $render_rc
}

_borg_orchestrator_context() {
    local registry
    registry=$(borg_registry_with_state)
    local now
    now=$(date '+%Y-%m-%d %H:%M %Z')

    echo "Current time: $now"
    echo ""
    echo "Project registry:"
    echo "$registry" | jq -r '
        .projects | to_entries |
        sort_by(
            if .value.status == "waiting" then 0
            elif .value.status == "active" then 1
            elif .value.status == "idle" then 2
            else 3 end
        ) |
        .[] |
        "  \(.key) [\(.value.status // "unknown")] \(
            if .value.last_activity then .value.last_activity else "never" end
        ) — \(.value.summary // "(no summary)" | .[0:80])"
    '
    echo ""

    # Latest checkpoint for top 3 priority projects
    local top3
    top3=$(echo "$registry" | jq -r '
        .projects | to_entries |
        map(select(.value.status != "archived")) |
        sort_by(
            if .value.status == "waiting" then 0
            elif .value.status == "active" then 1
            elif .value.status == "idle" then 2
            else 3 end
        ) | .[0:3] | .[].key
    ')

    local any_checkpoint=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local ppath cp
        ppath=$(echo "$registry" | jq -r --arg p "$name" '.projects[$p].path // ""')
        [[ -n "$ppath" && -d "$ppath/.borg/checkpoints" ]] || continue
        cp=$(find "$ppath/.borg/checkpoints" -maxdepth 1 -name '*.md' 2>/dev/null | sort -r | head -1 || true)
        [[ -n "$cp" && -f "$cp" ]] || continue
        if (( ! any_checkpoint )); then
            echo "Latest checkpoints:"
            any_checkpoint=1
        fi
        echo ""
        echo "=== $name (${cp##*/}) ==="
        head -c 1500 "$cp"
        echo ""
    done <<< "$top3"
}

cmd_init() {
    # Ensure tmux session exists — borg init should just work
    if ! borg_tmux_alive; then
        info "Starting tmux session: $BORG_TMUX_SESSION"
        tmux new-session -d -s "$BORG_TMUX_SESSION" -n orchestrator
        tmux set-option -t "$BORG_TMUX_SESSION:orchestrator" automatic-rename off
    fi

    # Merge Desktop sessions before building briefing
    borg_desktop_scan 2>/dev/null || true

    # Print formatted briefing to terminal before launching orchestrator.
    #
    # TOLERATED HERE, AND ONLY HERE. `_borg_print_briefing` now returns non-zero on both of its
    # no-page rungs — the document failing to BUILD and the fallback page failing to RENDER — and
    # `borg link --brief` propagates that status. The briefing IS that command's
    # product. For `borg init` the briefing is a preamble and the product is the orchestrator session
    # below, so a failed page must not stop the session from launching. This is not a silent swallow:
    # the function has already named the cause on stderr before returning, which is the whole of the
    # 2026-08-10 directive's "make the failure loud". Dropping only the status is the deliberate part.
    _borg_print_briefing || true

    local context
    context=$(_borg_orchestrator_context)

    local prompt
    prompt="We are the Borg. You are the orchestrator for this developer's work session.

== CURRENT STATE ==
$context
== END STATE ==

The developer has already seen the morning hail in their terminal.
Be ready to answer questions about any project, help them switch focus, or dive into work.
If they say 'go' or 'start' or 'engage', switch to the top-priority project.

== ORCHESTRATION MODEL ==
When the developer asks for project work, spawn the \`borg-nanoprobe\` agent via the Agent tool
with \`background: true\`. Pass the project name, repo path, working branch, and task in the
invocation prompt. Do NOT use \`isolation: worktree\` — nanoprobes manage their own git worktrees
inside the target repo at \`~/.local/state/borg/worktrees/<repo>/<slug>\`. Never edit project
files from this orchestrator session — your role is to spawn / monitor / synthesize. The standard
flow is: brief the nanoprobe → spawn → wait for SubagentStop → report results. Use
\`borg nanoprobes\` to see recent runs and \`borg nanoprobe-log <id>\` to read a transcript.

Spend visibility: \`borg spend\` shows the main-vs-subagent cost split (main-loop %) and a trend —
use it to confirm the main-loop share is shrinking over time (numbers are for this machine only)."

    # Write prompt to file — avoids shell-escaping hell when passing through tmux send-keys
    local prompt_file="${TMPDIR:-/tmp}/borg-orchestrator-prompt.$$"
    printf '%s' "$prompt" > "$prompt_file"

    info "Hailing frequencies open — resume any time with: borg claude"
    _borg_launch_in_tmux "$prompt_file" claude --name "borg-orchestrator" --append-system-prompt-file "$prompt_file"
}

cmd_claude() {
    # Resume the most recent orchestrator session
    info "Resuming orchestrator..."
    _borg_launch_in_tmux claude --continue
}

# Launch a command inside the borg tmux session.
# If already in tmux, exec directly. Otherwise, write a launcher script
# and send it to the target pane (avoids shell-escaping multiline args).
# If the first arg is a temp file path (from cmd_init), it is cleaned up
# after claude exits.
_borg_launch_in_tmux() {
    local cleanup_file=""
    # If first arg looks like a temp prompt file, pull it out for cleanup
    if [[ "$1" == "${TMPDIR:-/tmp}"/borg-orchestrator-prompt.* ]]; then
        cleanup_file="$1"
        shift
    fi

    if [[ -n "${TMUX:-}" ]]; then
        ( cd "$BORG_ORCHESTRATOR_ROOT" && "$@" )
        [[ -n "$cleanup_file" ]] && rm -f "$cleanup_file"
        return
    fi

    # Write a launcher script so tmux send-keys only types one short command
    local launcher="${TMPDIR:-/tmp}/borg-launch.$$.zsh"
    {
        echo '#!/usr/bin/env zsh'
        echo "cd ${(q)BORG_ORCHESTRATOR_ROOT}"
        # Quote each arg properly for the launcher script
        printf '%q ' "$@"
        echo ""
        [[ -n "$cleanup_file" ]] && echo "rm -f ${(q)cleanup_file}"
        echo "rm -f ${(q)launcher}"
    } > "$launcher"
    chmod +x "$launcher"

    local target_pane
    target_pane=$(tmux list-panes -t "$BORG_TMUX_SESSION:{start}" -F '#{pane_id}' | head -1)
    tmux send-keys -t "$target_pane" "$launcher" Enter
    exec tmux attach-session -t "$BORG_TMUX_SESSION"
}

# Merge a borg-managed CLAUDE.md block into a target CLAUDE.md, preserving user content
# above and below. Delimited by HTML comment markers so the block is replaceable on re-run.
# If target doesn't exist and a personal seed is provided, seed from it first.
# Usage: _borg_merge_claude_md <borg_src> <target> [personal_seed]
_borg_merge_claude_md() {
    local borg_src="$1" target="$2" personal_seed="${3:-}"
    [[ -f "$borg_src" ]] || return 0

    local begin='<!-- BEGIN borg-managed -->'
    local end='<!-- END borg-managed -->'

    mkdir -p "$(dirname "$target")"
    [[ -L "$target" && ! -f "$target" ]] && rm -f "$target"
    if [[ ! -f "$target" && -n "$personal_seed" && -f "$personal_seed" ]]; then
        cp "$personal_seed" "$target"
    fi
    [[ -f "$target" ]] || : > "$target"

    local tmp="$target.borg.$$"
    # Strip existing borg-managed block AND trailing blank lines in one pass —
    # blank lines are buffered and only emitted when a non-blank follows, so
    # trailing blanks get dropped. Keeps the merge idempotent.
    awk -v b="$begin" -v e="$end" '
        $0 == b { skip=1; next }
        $0 == e { skip=0; next }
        skip    { next }
        /^$/    { pending++; next }
                { for (i=0; i<pending; i++) print ""; pending=0; print }
    ' "$target" > "$tmp"

    local out="$target.new.$$"
    {
        cat "$tmp"
        printf '\n%s\n' "$begin"
        cat "$borg_src"
        printf '%s\n' "$end"
    } > "$out" && mv "$out" "$target"
    rm -f "$tmp" "$out"
}

# Union-merge permissions.allow from a base settings file into a target settings file.
# Substitutes __DOTFILES_DIR__ in base before merging. Additive only — never removes entries.
# Usage: _borg_merge_settings_permissions <base> <target> <dotfiles_dir>
_borg_merge_settings_permissions() {
    local base="$1" target="$2" dotfiles_dir="${3:-}"
    [[ -f "$base" && -f "$target" ]] || return 0
    local base_json tmp
    base_json=$(sed "s|__DOTFILES_DIR__|${dotfiles_dir}|g" "$base")
    tmp="$target.tmp.$$"
    jq --argjson base "$base_json" \
        '(.permissions.allow // []) as $live |
         ($base.permissions.allow // []) as $new |
         .permissions.allow = ($live + $new | unique)' \
        "$target" > "$tmp" && mv "$tmp" "$target" || { rm -f "$tmp"; return 1; }
}

# Register a hook in a settings.json file. Skips if already registered.
# If registered but missing timeout, updates the entry.
# Usage: _borg_register_hook <settings_file> <hook_cmd> <event> <label>
_borg_register_hook() {
    local settings="$1" hook_cmd="$2" event="$3" label="$4"
    local timeout_val=10

    if jq -e --arg evt "$event" --arg cmd "$hook_cmd" \
        '.hooks[$evt] // [] | map(.hooks[]? | select(.command == $cmd)) | length > 0' \
        "$settings" &>/dev/null; then
        # Check if existing entry is missing timeout and fix it
        if jq -e --arg evt "$event" --arg cmd "$hook_cmd" \
            '.hooks[$evt] // [] | map(.hooks[]? | select(.command == $cmd and (.timeout == null))) | length > 0' \
            "$settings" &>/dev/null; then
            local tmp="$settings.tmp.$$"
            jq --arg evt "$event" --arg cmd "$hook_cmd" --argjson timeout "$timeout_val" '
                .hooks[$evt] |= map(
                    .hooks |= map(if .command == $cmd then .timeout = $timeout else . end)
                )
            ' "$settings" > "$tmp" && mv "$tmp" "$settings"
            info "  $event: $label (updated — added timeout)"
        else
            info "  $event: $label (already registered)"
        fi
        return
    fi

    local tmp="$settings.tmp.$$"
    jq --arg evt "$event" --arg cmd "$hook_cmd" --argjson timeout "$timeout_val" '
        if .hooks == null then .hooks = {} else . end |
        if .hooks[$evt] == null then .hooks[$evt] = [] else . end |
        .hooks[$evt] += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": $timeout}]}]
    ' "$settings" > "$tmp" && mv "$tmp" "$settings"
    info "  $event: $label (registered)"
}

# Remove a hook from a settings.json file by command string.
# Usage: _borg_unregister_hook <settings_file> <hook_cmd> <event> <label>
_borg_unregister_hook() {
    local settings="$1" hook_cmd="$2" event="$3" label="$4"

    if ! jq -e --arg evt "$event" --arg cmd "$hook_cmd" \
        '.hooks[$evt] // [] | map(.hooks[]? | select(.command == $cmd)) | length > 0' \
        "$settings" &>/dev/null; then
        return
    fi

    local tmp="$settings.tmp.$$"
    jq --arg evt "$event" --arg cmd "$hook_cmd" '
        .hooks[$evt] |= (
            map(.hooks |= map(select(.command != $cmd)))
            | map(select((.hooks | length) > 0))
        )
    ' "$settings" > "$tmp" && mv "$tmp" "$settings"
    info "  $event: $label (removed)"
}

cmd_setup() {
    local CLAUDE_DIR="$HOME/.claude"
    local CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
    local CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
    local CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
    local DOTFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

    # ── 0. First-time setup wizard ────────────────────────────────────────────
    # Detect first-time vs returning user. Only prompt when things are missing.

    # 0a. Dotfiles
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        echo ""
        warn "No dotfiles found at $DOTFILES_DIR"
        echo ""
        echo "  Borg works best with a dotfiles repo that configures your shell,"
        echo "  editor, git, and Claude Code. We can set up starter dotfiles for you."
        echo ""
        printf "  Set up starter dotfiles? [Y/n] "
        read -r _reply
        if [[ "${_reply:-Y}" =~ ^[Yy]$ ]]; then
            info "Installing starter dotfiles..."
            local starter_dotfiles="$BORG_HOME/dotfiles"
            if [[ ! -d "$starter_dotfiles" ]]; then
                die "Starter dotfiles not found at $starter_dotfiles"
            fi
            mkdir -p "$DOTFILES_DIR"
            cp -R "$starter_dotfiles"/* "$DOTFILES_DIR/"
            chmod +x "$DOTFILES_DIR/install.sh"
            info "Starter dotfiles copied to $DOTFILES_DIR"

            # Run dotfiles installer
            info "Running dotfiles installer..."
            bash "$DOTFILES_DIR/install.sh"
        else
            warn "Skipping dotfiles setup."
            warn "You can set up dotfiles later by copying $BORG_HOME/dotfiles to $DOTFILES_DIR"
        fi
    fi

    # 0b. Git identity
    local git_name git_email
    git_name="$(git config --global user.name 2>/dev/null || true)"
    git_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        echo ""
        info "Git identity not configured yet."
        if [[ -z "$git_name" ]]; then
            printf "  Your name (for git commits): "
            read -r git_name
            [[ -n "$git_name" ]] && git config --global user.name "$git_name"
        fi
        if [[ -z "$git_email" ]]; then
            printf "  Your email (for git commits): "
            read -r git_email
            [[ -n "$git_email" ]] && git config --global user.email "$git_email"
        fi
        [[ -n "$git_name" && -n "$git_email" ]] && info "Git identity set: $git_name <$git_email>"
    fi

    # 0c. Claude Code CLI
    if ! command -v claude &>/dev/null; then
        echo ""
        warn "Claude Code CLI not found."
        echo "  Install it with: npm install -g @anthropic-ai/claude-code"
        echo "  Then run 'borg setup' again to register hooks."
        echo ""
    fi

    # 0d. Tool checks
    local missing_tools=()
    command -v tmux    &>/dev/null || missing_tools+=(tmux)
    command -v jq      &>/dev/null || missing_tools+=(jq)
    command -v fzf     &>/dev/null || missing_tools+=(fzf)
    command -v nvim    &>/dev/null || missing_tools+=(neovim)

    if (( ${#missing_tools[@]} > 0 )); then
        echo ""
        warn "Recommended tools not found: ${missing_tools[*]}"
        if command -v brew &>/dev/null; then
            printf "  Install them via Homebrew? [Y/n] "
            read -r _reply
            if [[ "${_reply:-Y}" =~ ^[Yy]$ ]]; then
                info "Installing: ${missing_tools[*]}..."
                brew install "${missing_tools[@]}" 2>&1 | grep -E '(Installing|Already|Error)' || true
            fi
        else
            echo "  Install manually:"
            for tool in "${missing_tools[@]}"; do
                echo "    - $tool"
            done
        fi
    fi

    echo ""

    # ── 1. Runtime directories ────────────────────────────────────────────────
    info "Creating runtime directories..."
    mkdir -p "$BORG_DIR/desktop"
    mkdir -p "$CLAUDE_DIR" "$CLAUDE_HOOKS_DIR" "$CLAUDE_SKILLS_DIR"
    borg_registry_init

    # ── 1a. Merge borg-managed CLAUDE.md block ───────────────────────────────
    # Borg owns its rules (permissions, bash patterns, subagent rules) at
    # $BORG_HOME/config/claude/CLAUDE.md and merges them into ~/.claude/CLAUDE.md
    # inside a delimited block. User content above/below the markers is preserved,
    # so personal dotfiles don't need to carry borg-specific content anymore.
    # On a fresh setup with no ~/.claude/CLAUDE.md, we seed from the dotfiles copy
    # if present (personal content) before appending the borg block.
    local claude_md_borg="$BORG_HOME/config/claude/CLAUDE.md"
    local claude_md_seed="$DOTFILES_DIR/claude/code/CLAUDE.md"
    local claude_md_dst="$CLAUDE_DIR/CLAUDE.md"
    if [[ -f "$claude_md_borg" ]]; then
        _borg_merge_claude_md "$claude_md_borg" "$claude_md_dst" "$claude_md_seed"
        info "CLAUDE.md borg-managed block updated"
    fi

    # Apply per-environment extension CLAUDE.md (appended after base)
    local _ext_dir="$BORG_DIR/extensions"
    if [[ -f "$_ext_dir/CLAUDE.md" && -f "$claude_md_dst" ]]; then
        local _marker="<!-- borg-extensions -->"
        local _tmp="$claude_md_dst.ext.$$"
        awk -v m="$_marker" '$0 == m {exit} {print}' "$claude_md_dst" > "$_tmp" \
            && mv "$_tmp" "$claude_md_dst"
        { printf '\n%s\n' "$_marker"; cat "$_ext_dir/CLAUDE.md"; } >> "$claude_md_dst"
        info "CLAUDE.md extension appended"
    fi

    if [[ ! -f "$BORG_DIR/config.zsh" ]]; then
        info "Generating config.zsh with defaults..."
        cat > "$BORG_DIR/config.zsh" <<'CONF'
# ~/.config/borg/config.zsh — Machine-local borg configuration
# Sourced by borg.zsh at startup. Edit to match this machine's needs.

# Work/life boundaries (empty to disable)
# BORG_WORK_HOURS="09:00-18:00"

# Projects that count as "work" (comma-separated, for boundary checks)
# BORG_WORK_PROJECTS=""

# Max concurrent active sessions before capacity warning
BORG_MAX_ACTIVE=3

# tmux session name (default: borg)
# BORG_TMUX_SESSION="borg"

# Enable debug output (uncomment to enable)
# BORG_DEBUG=1
CONF
        info "  Edit ~/.config/borg/config.zsh to set work hours, limits, etc."
    fi

    # ── 2. Install hooks ──────────────────────────────────────────────────────
    # Copy (not symlink) so hooks work inside devcontainers where the bind-
    # mounted ~/.claude can't follow host-absolute symlink targets.
    info "Installing hooks..."
    chmod +x "$BORG_HOME/hooks/"*.sh

    for hook in "$BORG_HOME/hooks/"*.sh; do
        local name="${hook:t}"
        rm -f "$CLAUDE_HOOKS_DIR/$name"
        cp "$hook" "$CLAUDE_HOOKS_DIR/$name"
        chmod +x "$CLAUDE_HOOKS_DIR/$name"
        info "  $name"
    done

    # Copy shared hook lib so hooks can source it at runtime
    mkdir -p "$HOME/.claude/lib"
    for lib in "$BORG_HOME/lib/"*.sh; do
        cp "$lib" "$HOME/.claude/lib/${lib:t}"
    done

    # ── 3. De-dup: remove literal-path borg hook entries from Claude Code settings.json ──
    # Hook registration is now owned by the borg-collective plugin (hooks/hooks.json).
    # borg setup STOPS writing hooks into settings.json. It instead REMOVES the literal
    # ~/.claude/hooks/... entries it used to write, so the plugin can own them without
    # double-firing. Permissions and other settings.json keys are preserved.
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        info "De-duping Claude Code settings.json (removing literal-path borg hooks)..."

        # Remove all literal ~/.claude/hooks/... borg hook entries. These were registered
        # by previous versions of borg setup; the plugin now owns hook registration.
        local _dedup_hooks=(
            "\$HOME/.claude/hooks/borg-link-down.sh"
            "\$HOME/.claude/hooks/borg-link-up.sh"
            "\$HOME/.claude/hooks/notify.sh"
            "\$HOME/.claude/hooks/borg-notify.sh"
            "\$HOME/.claude/hooks/pre-commit-remind.sh"
            "\$HOME/.claude/hooks/bash-guard.sh"
            "\$HOME/.claude/hooks/borg-plan-promote.sh"
            "\$HOME/.claude/hooks/tool-count-nudge.sh"
            "\$HOME/.claude/hooks/borg-nanoprobe-log.sh"
            "\$HOME/.claude/hooks/notify.sh"
        )
        local _dedup_events=(
            "SessionStart"
            "Stop"
            "Notification"
            "Notification"
            "PreToolUse"
            "PreToolUse"
            "PreToolUse"
            "PostToolUse"
            "SubagentStop"
            "Stop"
        )
        local _n=${#_dedup_hooks[@]}
        local _i
        for (( _i=1; _i<=_n; _i++ )); do
            _borg_unregister_hook "$CLAUDE_SETTINGS" "${_dedup_hooks[$_i]}" "${_dedup_events[$_i]}" \
                "${_dedup_hooks[$_i]##*/}"
        done

        # Migration: remove old hook names (previous rename cycles)
        _borg_unregister_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/session-start.sh" "SessionStart" "session-start.sh"
        _borg_unregister_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-start.sh" "SessionStart" "borg-start.sh"
        _borg_unregister_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-stop.sh" "Stop" "borg-stop.sh"

        # Clean up stale hook files from previous borg setup runs
        local _stale_hooks=(session-start.sh borg-start.sh borg-stop.sh)
        for _sh in "${_stale_hooks[@]}"; do
            [[ -e "$CLAUDE_HOOKS_DIR/$_sh" ]] && rm "$CLAUDE_HOOKS_DIR/$_sh" \
                && info "  Removed stale hook file: $_sh"
        done

        # Migration: rename borg-checkpoint skill → borg-link-up skill
        [[ -d "$HOME/.claude/skills/borg-checkpoint" ]] && rm -rf "$HOME/.claude/skills/borg-checkpoint" \
            && info "  Removed old borg-checkpoint skill (→ borg-link-up)"

        local _settings_base="$BORG_HOME/config/claude/settings.base.json"
        if [[ -f "$_settings_base" ]]; then
            _borg_merge_settings_permissions "$_settings_base" "$CLAUDE_SETTINGS" "$DOTFILES_DIR"
            info "Permissions synced from borg base"
        fi

        local _claude_local="$BORG_DIR/claude-settings.local.json"
        if [[ ! -f "$_claude_local" ]]; then
            jq '{model: .model, enabledPlugins: (.enabledPlugins // {}), extraKnownMarketplaces: (.extraKnownMarketplaces // {})}' \
                "$CLAUDE_SETTINGS" > "$_claude_local"
            info "Generated $_claude_local (add machine-local overrides here)"
        fi
        info "  De-dup complete. Hooks are now owned by the borg-collective plugin."
        info "  If the plugin is not installed, run: claude plugin install borg-collective@noah-local"
    else
        warn "No settings.json at $CLAUDE_SETTINGS"
        warn "Hooks are managed by the borg-collective plugin. Install it to register hooks."
    fi

    # ── 3b. CoCo (Cortex Code) integration ───────────────────────────────────
    local COCO_DIR="$HOME/.snowflake/cortex"
    local COCO_SETTINGS="$COCO_DIR/settings.json"

    if command -v cortex &>/dev/null; then
        info "Cortex Code CLI detected — configuring CoCo integration..."
        mkdir -p "$COCO_DIR/hooks"
        [[ -f "$COCO_SETTINGS" ]] || echo '{}' > "$COCO_SETTINGS"

        for hook in "$BORG_HOME/hooks/"*.sh; do
            local name="${hook:t}"
            rm -f "$COCO_DIR/hooks/$name"
            cp "$hook" "$COCO_DIR/hooks/$name"
            chmod +x "$COCO_DIR/hooks/$name"
        done

        info "Registering hooks in CoCo settings.json..."
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-link-down.sh"   "SessionStart" "borg-link-down.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-link-up.sh"     "Stop"         "borg-link-up.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/notify.sh"             "Notification"  "notify.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-notify.sh"       "Notification"  "borg-notify.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/pre-commit-remind.sh"  "PreToolUse"   "pre-commit-remind.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/bash-guard.sh"         "PreToolUse"   "bash-guard.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-plan-promote.sh"  "PreToolUse"   "borg-plan-promote.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-nanoprobe-log.sh" "SubagentStop" "borg-nanoprobe-log.sh"

        # Migration: rename CoCo borg-start.sh/borg-stop.sh → borg-link-down.sh/borg-link-up.sh
        _borg_unregister_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-start.sh" "SessionStart" "borg-start.sh"
        _borg_unregister_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-stop.sh" "Stop" "borg-stop.sh"
        [[ -e "$COCO_DIR/hooks/borg-start.sh" ]] && rm "$COCO_DIR/hooks/borg-start.sh" || true
        [[ -e "$COCO_DIR/hooks/borg-stop.sh" ]] && rm "$COCO_DIR/hooks/borg-stop.sh" || true

        info "Registering skills with CoCo..."
        for skill_dir in "$BORG_HOME/skills/"*/(N); do
            [[ -d "$skill_dir" ]] || continue
            local name="${skill_dir:t}"
            cortex skill add "$skill_dir" 2>/dev/null && info "  $name (cortex)" || warn "  $name: cortex skill add failed"
        done

        local _coco_base="$BORG_HOME/config/cortex/settings.base.json"
        if [[ -f "$_coco_base" ]]; then
            _borg_merge_settings_permissions "$_coco_base" "$COCO_SETTINGS" "$DOTFILES_DIR"
            info "Cortex permissions synced from borg base"
        fi

        local _cortex_local="$BORG_DIR/cortex-settings.local.json"
        if [[ ! -f "$_cortex_local" ]]; then
            jq '{cortexAgentConnectionName: .cortexAgentConnectionName, theme: (.theme // "dark")}' \
                "$COCO_SETTINGS" > "$_cortex_local"
            info "Generated $_cortex_local (add Cortex machine-local overrides here)"
        fi
    else
        info "Cortex Code CLI not found — skipping CoCo integration"
    fi

    # ── 4. Skills + agents ship via the PLUGIN, not copies ────────────────────
    # Per the ratified 80/20 split (docs/plans/assimilated/
    # 2026-06-08-mechanism-layer-extraction-plugin-80-20-split.md, PR #41): the
    # distributable plugin is the deployment vehicle for skills and agents; the
    # ~/.claude copy loops that used to live here were the pre-plugin legacy path
    # and produced double-loading (2026-08-23 install audit, Gap 3). The build in
    # step 4a-ii below is the single-source mechanism. Cortex Code has no plugin
    # system, so CoCo skills still install from $BORG_HOME/skills via `cortex
    # skill add` (step 3) — that path is unaffected.
    info "Skills + agents ship via the borg-collective plugin (built in step 4a-ii)"

    # One-time migration sweep: remove the orphaned legacy copies so they stop
    # double-loading alongside the plugin registrations. Skills: only dirs bearing
    # the .borg-managed ownership marker — hand-authored neighbours (e.g. ducky/)
    # are untouched. Agents: only files whose name matches a source-repo agent.
    # Idempotent and safe to keep: on a machine that never ran the legacy loops,
    # both sweeps match nothing.
    for existing in "$CLAUDE_SKILLS_DIR/"*/(N); do
        [[ -d "$existing" && -f "$existing/.borg-managed" ]] || continue
        rm -rf "$existing"
        info "  Removed legacy skill copy: ${existing:t} (now plugin-provided)"
    done
    local CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    if [[ -d "$CLAUDE_AGENTS_DIR" && -d "$BORG_HOME/agents" ]]; then
        for agent_file in "$BORG_HOME/agents/"*.md(N); do
            [[ -f "$agent_file" ]] || continue
            local aname="${agent_file:t}"
            if [[ -f "$CLAUDE_AGENTS_DIR/$aname" ]]; then
                rm -f "$CLAUDE_AGENTS_DIR/$aname"
                info "  Removed legacy agent copy: $aname (now plugin-provided)"
            fi
        done
    fi

    # ── 4a-ii. Build + publish plugin (runs on every machine) ───────────────
    # Rebuilds the publishable plugin subset from this repo into the claude-plugins
    # directory, idempotently ensuring the marketplace.json entry is present.
    # On a fresh machine the target dir may not exist yet; build-plugin.sh creates it.
    # Safe to re-run — all phases are diff-guarded.
    local _plugin_build="$BORG_HOME/scripts/build-plugin.sh"
    if [[ -f "$_plugin_build" ]]; then
        info "Publishing borg-collective plugin to marketplace..."
        bash "$_plugin_build" 2>&1 | sed 's/^/  /' || warn "plugin build encountered errors — check output above"
    fi

    # ── 4b. Per-environment extensions ───────────────────────────────────────
    if [[ -d "$_ext_dir/skills" ]]; then
        info "Installing extension skills..."
        for skill_dir in "$_ext_dir/skills/"*/(N); do
            [[ -d "$skill_dir" ]] || continue
            local name="${skill_dir:t}"
            ln -sfn "$skill_dir" "$CLAUDE_SKILLS_DIR/$name"
            info "  $name (extension)"
            command -v cortex &>/dev/null \
                && cortex skill add "$skill_dir" 2>/dev/null || true
        done
    fi

    if [[ -d "$_ext_dir/hooks" ]]; then
        info "Installing extension hooks..."
        for hook in "$_ext_dir/hooks/"*.sh(N); do
            local name="${hook:t}"
            local event
            event=$(grep -m1 '^# borg-event:' "$hook" 2>/dev/null | awk '{print $NF}')
            cp "$hook" "$CLAUDE_HOOKS_DIR/$name"
            chmod +x "$CLAUDE_HOOKS_DIR/$name"
            if [[ -n "$event" && -f "$CLAUDE_SETTINGS" ]]; then
                _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/$name" "$event" "$name"
            fi
            info "  $name${event:+ ($event)}"
        done
    fi

    # ── 4c. Ensure .borg/state.json is gitignored + initialise state files ────
    info "Ensuring .borg/state.json is gitignored in registered projects..."
    while IFS= read -r _proj_path; do
        [[ -n "$_proj_path" && -d "$_proj_path" ]] || continue
        local _gi="$_proj_path/.gitignore"
        # Add .borg/state.json to .gitignore (NOT the entire .borg/ dir —
        # that would break the !.borg/checkpoints/ negation carve-out).
        if ! grep -qF '.borg/state.json' "$_gi" 2>/dev/null; then
            echo '.borg/state.json' >> "$_gi"
            info "  Added .borg/state.json to ${_proj_path##*/}/.gitignore"
        fi
        # Initialise an empty state.json if one doesn't exist yet.
        local _sf="$_proj_path/.borg/state.json"
        if [[ ! -f "$_sf" ]]; then
            mkdir -p "$_proj_path/.borg"
            echo '{"status":"idle","last_activity":null,"claude_session_id":null,"has_uncommitted_changes":false,"waiting_reason":null,"notify_origin":"host"}' \
                > "$_sf"
            info "  Initialised state.json for ${_proj_path##*/}"
        fi
    done < <(borg_registry_read | jq -r '.projects[].path // empty')

    # ── 5. Install bin/ utilities ────────────────────────────────────────────
    local CLAUDE_BIN_DIR="$CLAUDE_DIR/bin"
    if [[ -d "$BORG_HOME/bin" ]]; then
        info "Installing bin/ utilities..."
        mkdir -p "$CLAUDE_BIN_DIR"
        for util in "$BORG_HOME/bin/"*; do
            [[ -f "$util" ]] || continue
            local uname="${util:t}"
            cp "$util" "$CLAUDE_BIN_DIR/$uname"
            chmod +x "$CLAUDE_BIN_DIR/$uname"
            info "  $uname"
        done

        # Ensure ~/.claude/bin is in PATH for this session and future shells
        if [[ ":$PATH:" != *":$CLAUDE_BIN_DIR:"* ]]; then
            export PATH="$CLAUDE_BIN_DIR:$PATH"
            warn "$CLAUDE_BIN_DIR not in PATH. Add to ~/.zshrc:"
            warn "  export PATH=\"\$HOME/.claude/bin:\$PATH\""
        fi
    fi

    # ── 6. tmux keybinding ────────────────────────────────────────────────────
    local TMUX_CONF="$HOME/.config/tmux/tmux.conf"
    if [[ -f "$TMUX_CONF" ]]; then
        if ! grep -q "borg next" "$TMUX_CONF" 2>/dev/null; then
            info "Adding tmux keybinding: Ctrl+Space > (borg next --switch)"
            local borg_bin
            borg_bin=$(command -v borg 2>/dev/null || echo "$HOME/.local/bin/borg")
            printf '\n# Borg: jump to most pressing project (borg next --switch)\n' >> "$TMUX_CONF"
            printf "bind > run-shell \"%s next --switch 2>/dev/null || tmux display-message 'All clear — take a break'\"\n" \
                "$borg_bin" >> "$TMUX_CONF"
            tmux source-file "$TMUX_CONF" 2>/dev/null && info "tmux config reloaded" || true
        else
            info "tmux keybinding already configured"
        fi
    else
        warn "tmux.conf not found at $TMUX_CONF — add keybinding manually:"
        warn '  bind > run-shell "borg next --switch"'
    fi

    # ── 7. Bootstrap registry ─────────────────────────────────────────────────
    info "Bootstrapping registry from session history..."
    cmd_scan 2>&1 || warn "borg scan had issues (registry may still be empty)"

    # ── 8. Summary ─────────────────────────────────────────────────────────────
    echo ""
    info "Setup complete!"
    echo ""
    echo "  Status:"
    [[ -d "$DOTFILES_DIR" ]] && echo "    ✓ Dotfiles: $DOTFILES_DIR" \
                              || echo "    ✗ Dotfiles: not found"
    git config --global user.name &>/dev/null && echo "    ✓ Git: $(git config --global user.name) <$(git config --global user.email)>" \
                                              || echo "    ✗ Git: identity not set"
    command -v claude &>/dev/null && echo "    ✓ Claude Code: installed" \
                                  || echo "    ✗ Claude Code: not found"
    command -v tmux &>/dev/null && echo "    ✓ tmux: installed" \
                                || echo "    ✗ tmux: not found"
    command -v docker &>/dev/null && echo "    ✓ Docker: installed" \
                                  || echo "    ✗ Docker: not found"
    echo ""
    echo "  Next: borg init"
    echo ""
}

cmd_start() {
    local slug="${1:-}"
    [[ -z "$slug" ]] && die "usage: borg start <directive-slug>"

    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"

    local plan="$root/PROJECT_PLAN.md"
    [[ -f "$plan" ]] && die "already in-flight: $plan — assimilate or sever first"

    slug="${slug%.md}"
    local rel="docs/plans/directives/$slug.md"
    [[ -f "$root/$rel" ]] || die "no such directive: $root/$rel"

    if git -C "$root" ls-files --error-unmatch "$rel" &>/dev/null; then
        (cd "$root" && git mv "$rel" PROJECT_PLAN.md)
    else
        mv "$root/$rel" "$plan"
    fi
    info "in-flight: PROJECT_PLAN.md (was $rel)"
}

# cmd_store_secret: store a secret in macOS Keychain and wire it to secrets.zsh.
# Edits ~/.config/dotfiles/zsh/secrets.zsh (a separate repo) — see
# _borg_patch_secrets_file in lib/secrets.zsh for the expected file structure.
cmd_store_secret() {
    local name="${1:-}"
    [[ -n "$name" ]] || die "usage: borg store-secret <NAME>"

    # Must be run interactively — can't prompt for a hidden secret over a pipe
    [[ -t 0 ]] || die "borg store-secret must be run from an interactive terminal"

    command -v security &>/dev/null || die "security(1) not found — are you on macOS?"

    local secrets_file="${BORG_SECRETS_FILE:-$HOME/.config/dotfiles/zsh/secrets.zsh}"
    [[ -f "$secrets_file" ]] \
        || die "expected file at $secrets_file; set BORG_SECRETS_FILE to override"

    # ── 1. Prompt and store ──────────────────────────────────────────────────
    local _BORG_SECRET
    printf "Paste secret for %s (input hidden): " "$name"
    read -rs _BORG_SECRET
    echo ""
    if [[ -z "$_BORG_SECRET" ]]; then
        unset _BORG_SECRET
        die "empty secret — aborting"
    fi

    # SA5: never place the secret on argv (visible to `ps` for the write's duration).
    # `security -w` with no value reads it interactively; feeding via stdin keeps it off
    # the process table entirely.
    if ! printf '%s\n%s\n' "$_BORG_SECRET" "$_BORG_SECRET" | \
            security add-generic-password -s "$name" -a "$USER" -U -w 2>/dev/null; then
        unset _BORG_SECRET
        die "keychain write failed"
    fi
    info "stored $name in keychain"

    # ── 2. Verify ────────────────────────────────────────────────────────────
    # SA5: reveal no secret bytes — the old path echoed a 10-char prefix, which lands in any
    # scrollback/capture log. Length + name confirm the round-trip just as well.
    local _BORG_VERIFY
    if ! _BORG_VERIFY=$(security find-generic-password -s "$name" -a "$USER" -w 2>/dev/null); then
        unset _BORG_SECRET
        die "verification failed — could not read back from keychain"
    fi
    if [[ "$_BORG_VERIFY" != "$_BORG_SECRET" ]]; then
        unset _BORG_SECRET _BORG_VERIFY
        die "verification failed — keychain returned a different value"
    fi
    echo "  verified: $name (${#_BORG_VERIFY} chars) round-trips from the keychain"
    unset _BORG_SECRET _BORG_VERIFY

    # ── 3. Patch secrets.zsh ─────────────────────────────────────────────────
    _borg_patch_secrets_file "$name" "$secrets_file" \
        || die "failed to patch $secrets_file"
    info "wired $name in $secrets_file"

    # ── 4. Reload instructions (script context; caller must source manually) ─
    echo ""
    echo "  Run this to load the new var in your current shell:"
    echo "    source ~/.zshrc"
    echo ""
    info "done"
}

cmd_cortex_resume() {
    local target="${1:-}"
    [[ -f "$BORG_CORTEX_WAKES" ]] || die "no pending cortex wakes (state file missing)"

    local entries
    entries=$(jq -c '.wakes // []' "$BORG_CORTEX_WAKES")
    [[ "$entries" == "[]" || -z "$entries" ]] && die "no pending cortex wakes"

    local entry
    if [[ -z "$target" ]]; then
        entry=$(echo "$entries" | jq -c '.[0]')
    elif [[ "$target" == %* ]]; then
        entry=$(echo "$entries" | jq -c --arg p "$target" '[.[] | select(.pane_id == $p)][0]')
    else
        entry=$(echo "$entries" | jq -c --arg p "$target" '[.[] | select(.project == $p)][0]')
    fi
    [[ -n "$entry" && "$entry" != "null" ]] || die "no pending wake matching '$target'"

    local pane_id project session window pane_index
    # \x1f, not @tsv/tab: tab is IFS *whitespace*, so a run of consecutive tabs (an empty middle
    # field) collapses to ONE delimiter and shifts every field after it left. \x1f is a
    # non-whitespace IFS char, so adjacent delimiters always produce an empty field instead of
    # merging. This is the last site of the pattern — _borg_print_briefing carried the original
    # rationale until the 2026-08-27 fold deleted its `read` loop, so the reasoning lives here now
    # rather than as a cross-reference to a function that no longer demonstrates it.
    IFS=$'\x1f' read -r pane_id project session window pane_index < <(
        echo "$entry" | jq -r '[.pane_id,.project,.session,.window,.pane_index] | join("\u001f")'
    )

    # Re-resolve pane_id if the recorded one is gone (tmux server restart).
    if ! tmux list-panes -t "$pane_id" &>/dev/null; then
        local fresh
        fresh=$(tmux list-panes -t "$session:$window" -F '#{pane_id} #{pane_index}' 2>/dev/null \
            | awk -v idx="$pane_index" '$2 == idx { print $1; exit }')
        [[ -n "$fresh" ]] || die "pane $pane_id ($project) is gone and could not be re-resolved"
        pane_id="$fresh"
    fi

    tmux send-keys -t "$pane_id" "wake up!" Enter \
        || die "tmux send-keys failed for $pane_id ($project)"

    info "sent 'wake up!' to $project (pane $pane_id)"

    # Drop entry atomically.
    local tmp="$BORG_CORTEX_WAKES.tmp.$$"
    jq --arg p "$pane_id" --arg pr "$project" \
        '.wakes |= map(select(.pane_id != $p and .project != $pr))' \
        "$BORG_CORTEX_WAKES" > "$tmp" && mv "$tmp" "$BORG_CORTEX_WAKES"
}

cmd_nanoprobes() {
    local log="${XDG_CONFIG_HOME:-$HOME/.config}/borg/agents.jsonl"
    if [[ ! -s "$log" ]]; then
        info "No nanoprobes recorded yet."
        info "Spawn one via the Agent tool with agent_type=borg-nanoprobe; SubagentStop logs here."
        return 0
    fi

    # Newest first; format: short_id  agent_type  summary  finished_at
    _borg_reverse_lines "$log" | head -50 | jq -r '
        [
            (.id // "")[0:8],
            (.agent_type // "?"),
            ((.summary // "") | gsub("\n"; " ") | .[0:80]),
            (.finished_at // "")
        ] | join("\u001f")
    ' 2>/dev/null | while IFS=$'\x1f' read -r sid atype summary finished; do
        printf "  %-10s %-18s %-80s %s\n" "$sid" "$atype" "$summary" "$finished"
    done
}

cmd_nanoprobe_log() {
    local query="${1:-}"
    [[ -n "$query" ]] || die "usage: borg nanoprobe-log <id-or-prefix>"

    local log="${XDG_CONFIG_HOME:-$HOME/.config}/borg/agents.jsonl"
    [[ -s "$log" ]] || die "no nanoprobes recorded yet ($log)"

    # Find the newest matching JSONL entry by id prefix
    local entry
    entry=$(_borg_reverse_lines "$log" | jq -c --arg q "$query" \
        'select((.id // "") | startswith($q))' 2>/dev/null | head -1)

    [[ -n "$entry" ]] || die "no nanoprobe matching '$query'"

    local tpath
    tpath=$(printf '%s' "$entry" | jq -r '.transcript_path // ""' 2>/dev/null)

    if [[ -n "$tpath" && -f "$tpath" ]]; then
        cat "$tpath"
    else
        printf '%s\n' "$entry" | jq .
    fi
}

# Report main-vs-subagent spend from ~/.claude/token-spend.jsonl (the SessionEnd collector). The
# directive's actual ask is the main-loop % SHARE — so the goal "shrink the main-loop share" is
# observable over time — not just raw totals. Default output shows: all-time split with main %, a
# recent-sessions trend (newest first), and a by-project breakdown sorted by cost.
#
# CAVEAT (correctness trap): token-spend.jsonl has NO host/machine field. These numbers therefore
# reflect THIS MACHINE ONLY. The header and footer state this; do not aggregate across machines from
# this file alone.
cmd_spend() {
    # NOTE: token-spend.jsonl lives under ~/.claude (NOT XDG_CONFIG_HOME — that is agents.jsonl).
    local log="$HOME/.claude/token-spend.jsonl"

    local project="" by_model=0 last=15
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project|-p) project="$2"; shift 2 ;;
            --by-model)   by_model=1; shift ;;
            --last)       last="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -s "$log" ]]; then
        info "No spend recorded yet ($log)."
        info "The token-cost SessionEnd hook appends one record per session here."
        return 0
    fi

    # Optional --project filter (mirrors borg search --project).
    local filter='.'
    [[ -n "$project" ]] && filter="select(.project == \"$project\")"

    echo -e "${BOLD}Spend — main vs subagent split${NC} ${DIM}(this machine only; token-spend.jsonl has no host field)${NC}"
    [[ -n "$project" ]] && echo -e "${DIM}filtered to project: $project${NC}"
    echo

    # ── All-time totals + main-loop share ──
    jq -s -r --arg flt "$project" '
        [ .[] | select($flt == "" or .project == $flt) ] as $rows
        | ($rows | map(.main.est_cost_usd // 0) | add // 0)      as $main
        | ($rows | map(.subagents.est_cost_usd // 0) | add // 0) as $sub
        | ($main + $sub)                                         as $total
        | ($rows | length)                                       as $n
        | ($rows | map(.subagents.agent_count // 0) | add // 0)  as $agents
        | (if $total > 0 then ($main / $total * 100) else 0 end) as $mainpct
        | (if $total > 0 then ($sub  / $total * 100) else 0 end) as $subpct
        | "  sessions      \($n)  (\($agents) subagents)\n" +
          "  total         $\($total | .*100 | round / 100)\n" +
          "  main-loop     $\($main | .*100 | round / 100)  (\($mainpct | round)%)\n" +
          "  subagents     $\($sub  | .*100 | round / 100)  (\($subpct | round)%)"
    ' "$log"
    echo

    # ── Recent-sessions trend (newest first) — date, project, total, main % ──
    echo -e "${BOLD}Recent sessions${NC} ${DIM}(newest first, main % should trend down)${NC}"
    _borg_reverse_lines "$log" \
        | jq -r --arg flt "$project" '
            select($flt == "" or .project == $flt)
            | (.main.est_cost_usd // 0)      as $main
            | (.subagents.est_cost_usd // 0) as $sub
            | ($main + $sub)                 as $total
            | (if $total > 0 then ($main / $total * 100) else 0 end) as $mainpct
            | [ ((.ts // "")[0:10]),
                (.project // "?"),
                ($total | .*100 | round / 100),
                ($mainpct | round) ] | join("\u001f")
        ' 2>/dev/null \
        | head -n "$last" \
        | while IFS=$'\x1f' read -r date proj total mainpct; do
            printf "  %-10s  %-22s  \$%-8s  main %3s%%\n" "$date" "$proj" "$total" "$mainpct"
        done
    echo

    # ── By-project breakdown, sorted by cost desc ──
    echo -e "${BOLD}By project${NC} ${DIM}(cost desc)${NC}"
    jq -s -r --arg flt "$project" '
        [ .[] | select($flt == "" or .project == $flt) ]
        | group_by(.project)
        | map({
            project: .[0].project,
            total:   (map(.est_cost_usd // 0) | add // 0),
            main:    (map(.main.est_cost_usd // 0) | add // 0),
            n:       length
          })
        | sort_by(-.total)
        | .[]
        | [ .project,
            (.total | .*100 | round / 100),
            (if .total > 0 then (.main / .total * 100 | round) else 0 end),
            .n ] | join("\u001f")
    ' "$log" 2>/dev/null \
        | while IFS=$'\x1f' read -r proj total mainpct n; do
            printf "  %-22s  \$%-9s  main %3s%%  (%s sessions)\n" "$proj" "$total" "$mainpct" "$n"
        done

    # ── Optional per-model breakdown ──
    # by_model records hold only raw token counts (input/output/cache_creation/cache_read) — there
    # is NO per-model est_cost_usd. We compute cost from the cache-aware pricing table (USD per
    # million tokens) keyed by model tier, matching the token-cost SKILL. Cache reads are priced at
    # the read rate, NOT as fresh input.
    if (( by_model )); then
        echo
        echo -e "${BOLD}By model${NC} ${DIM}(layer · model · computed cost, USD/M pricing)${NC}"
        jq -s -r --arg flt "$project" '
            # Pricing per million tokens, by tier: [input, output, cache_creation, cache_read]
            # Pricing per million tokens, by tier: [input, output, cache_creation, cache_read].
            { "opus":   [15,   75,   18.75, 1.50],
              "sonnet": [3,    15,   3.75,  0.30],
              "haiku":  [0.25, 1.25, 0.31,  0.025] } as $price
            # Map a model id to a tier by substring; default to opus (most expensive — conservative).
            | def tier($m): if   ($m | test("haiku"))  then "haiku"
                            elif ($m | test("sonnet")) then "sonnet"
                            else "opus" end;
              def cost($u; $m): ($price[tier($m)]) as $p
                | (($u.input // 0) * $p[0]
                 + ($u.output // 0) * $p[1]
                 + ($u.cache_creation // 0) * $p[2]
                 + ($u.cache_read // 0) * $p[3]) / 1000000;
              [ .[] | select($flt == "" or .project == $flt) ] as $rows
            | ( [ $rows[] | .main.by_model // {} | to_entries[]
                  | {layer:"main", model:.key, cost:cost(.value; .key)} ]
              + [ $rows[] | .subagents.by_model // {} | to_entries[]
                  | {layer:"subagents", model:.key, cost:cost(.value; .key)} ] )
            | group_by([.layer, .model])
            | map({ layer:.[0].layer, model:.[0].model, cost:(map(.cost) | add // 0) })
            | sort_by(-.cost)
            | .[] | [ .layer, .model, (.cost | .*100 | round / 100) ] | join("\u001f")
        ' "$log" 2>/dev/null \
            | while IFS=$'\x1f' read -r layer model cost; do
                printf "  %-10s  %-26s  \$%s\n" "$layer" "$model" "$cost"
            done
        echo
        echo -e "${DIM}  note: per-model cost is recomputed from raw tokens (cache-aware); rounding may differ slightly from est_cost_usd.${NC}"
    fi

    echo
    echo -e "${DIM}Numbers reflect THIS MACHINE only — token-spend.jsonl carries no host field.${NC}"
}

# Print a file's mtime as a unix timestamp. `stat -c %Y` is GNU (Linux, and CI); `stat -f %m` is
# BSD (macOS). Return nonzero when neither works so callers can distinguish "cannot tell" from
# "very old" — collapsing those two is how a stat failure becomes a false staleness report.
#
# ORDER MATTERS, AND NOT FOR THE OBVIOUS REASON. Try GNU FIRST. On GNU, `-f` means "filesystem
# status", so `stat -f %m FILE` treats %m as an operand, PRINTS A FILESYSTEM BLOCK TO STDOUT
# ("File: ...", "ID: ...", "Block size: ..."), and only then exits 1. A `bsd || gnu` chain
# therefore captures that block CONCATENATED with the real answer, and the caller does arithmetic
# on "File: ... 1786418121" — which under `set -u` dies with "File: unbound variable". The reverse
# order is clean: BSD's `stat -c` fails with EMPTY stdout, so the fallback output stands alone.
# Parse an ISO-8601 "...Z" timestamp to a unix epoch, in UTC. `date -j -u -f` is BSD (macOS);
# `date -d` is GNU (Linux, and CI). BSD FIRST here — the opposite of _borg_file_mtime, and for a
# different reason: both forms fail with EMPTY stdout on the wrong platform, so either order is
# pollution-free, and BSD-first matches lib/reaper.sh, which already had this right.
#
# NOTE — THIS NORMALIZES A PRE-EXISTING 7-HOUR BUG, and could not avoid doing so. borg.zsh:67 and
# :1365 previously used `date -j -f` with NO `-u`, which parses a Z-suffixed UTC timestamp as LOCAL
# time. For 2020-01-01T00:00:00Z that yields 1577862000 instead of 1577836800 — off by the local UTC
# offset (7h at that date). Against a 12h staleness threshold that is more than half the budget, and
# it is the #98/#99 clock-skew cluster. Preserving it was not an option: BSD parses such a stamp as
# local and GNU parses it as UTC, so a portable helper that "kept existing behavior" would have made
# the two platforms disagree by 7 hours. UTC is both correct and the only self-consistent choice.
_borg_iso_to_epoch() {
    TZ=UTC date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null \
        || TZ=UTC date -d "$1" +%s 2>/dev/null
}

# Print a file's lines in reverse. `tail -r` is BSD (macOS); `tac` is GNU (Linux, and CI). Same
# split, and the same silent-failure risk, as _borg_file_mtime below: four call sites used bare
# `tail -r "$f" 2>/dev/null`, which on GNU emits NOTHING and exits nonzero with stderr suppressed —
# so `borg nanoprobes`, `nanoprobe-log`, `spend`, and `watch` all rendered empty on Linux while
# looking like "no records yet". Verified both fall through cleanly with EMPTY stdout on the other
# platform (macOS `tac` exits 127; GNU `tail -r` prints nothing), so unlike the #114 stat bug there
# is no risk of the failing branch's output concatenating with the real answer.
#
# BSD FIRST, and the order is load-bearing for a reason that is not correctness. borg runs on macOS;
# putting `tac` first meant every macOS render paid a failed fork+exec before falling back. That is
# invisible almost everywhere, but the now-retired `cmd_watch` re-rendered inside a 50ms polling
# loop, and the GNU-first ordering was enough to make its contract test fail on the CI macOS
# runner. The polling caller is gone; the ordering stays, because macOS is still the platform
# borg runs on and a failed fork+exec per render is still waste. Matches _borg_iso_to_epoch too.
_borg_reverse_lines() {
    tail -r "$1" 2>/dev/null || tac "$1" 2>/dev/null
}

_borg_file_mtime() {
    local f="$1" m=""
    m=$(stat -c "%Y" "$f" 2>/dev/null) && { print -r -- "$m"; return 0; }
    m=$(stat -f "%m" "$f" 2>/dev/null) && { print -r -- "$m"; return 0; }
    return 1
}

cmd_doctor() {
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/borg"
    local la_dir="$HOME/Library/LaunchAgents"

    # name  label-suffix  artifact-path (or "" for n/a)
    #
    # Only list an artifact for agents that write one on EVERY interval. notifyd and cortex-wake
    # are event-driven: their logs are written when something happens, so an old mtime means "a
    # quiet hour", not "broken". Checking freshness there reports a healthy agent as stale, and a
    # health check that cries wolf gets ignored.
    local -a agents=(
        "notifyd|com.stillpoint-labs.borg.notifyd|"
        "cortex-wake|com.stillpoint-labs.borg.cortex-wake|"
        "usage-watch|com.stillpoint-labs.borg.usage-watch|$state_dir/usage-samples.jsonl"
        "reap|com.stillpoint-labs.borg.reap|$data_dir/reap.stdout.log"
    )

    local overall_exit=0
    local list_output
    list_output=$(launchctl list 2>/dev/null) || list_output=""

    printf "${BOLD} %-14s %-10s %-8s %-10s %s${NC}\n" "AGENT" "REG" "EXIT" "FRESH" "STATUS"
    printf '%0.s─' {1..70}; echo

    local agent_line name label artifact
    for agent_line in "${agents[@]}"; do
        name="${agent_line%%|*}"
        local rest="${agent_line#*|}"
        label="${rest%%|*}"
        artifact="${rest#*|}"

        local reg_line="" reg="MISSING" exit_status="?" fresh="n/a"
        local agent_ok=1 agent_warn=0 hint=""

        reg_line=$(echo "$list_output" | grep -F "$label" | head -1) || reg_line=""
        if [[ -z "$reg_line" ]]; then
            reg="MISSING"
            agent_ok=0
            hint="not registered — re-run ./install.sh"
        else
            reg="yes"
            local pid=""
            pid=$(echo "$reg_line" | awk '{print $1}')
            exit_status=$(echo "$reg_line" | awk '{print $2}')
            [[ -z "$exit_status" ]] && exit_status="?"

            if [[ "$pid" == <-> ]]; then
                # A live PID means the agent is running right now. `launchctl`'s second column is
                # then the PREVIOUS instance's exit status — for a daemon that was restarted, that
                # is the signal we sent it (e.g. -15 = SIGTERM). Reporting FAIL there is a false
                # alarm about the corpse of an instance we killed ourselves.
                exit_status="run"
            elif [[ "$exit_status" == -* ]]; then
                # Negative = terminated by a signal, not a failed exit. Worth noticing, not a FAIL.
                agent_warn=1
                hint="terminated by signal (${exit_status#-}) — expected after a kickstart; check logs in $data_dir if it recurs"
            elif [[ "$exit_status" != "0" && "$exit_status" != "-" ]]; then
                agent_ok=0
                hint="last exit status $exit_status — check logs in $data_dir, then re-run ./install.sh"
            fi
        fi

        # Freshness: only evaluated when registered and an artifact path is defined.
        if [[ "$reg" == "yes" && -n "$artifact" ]]; then
            local plist="$la_dir/$label.plist"
            local interval=""
            if [[ -f "$plist" ]]; then
                interval=$(grep -A1 'StartInterval' "$plist" | grep -oE '[0-9]+' | head -1) || interval=""
            fi
            if [[ -z "$interval" ]]; then
                fresh="n/a"
            elif [[ ! -f "$artifact" ]]; then
                fresh="WARN"
                agent_warn=1
                [[ -z "$hint" ]] && hint="no output yet at $artifact"
            else
                local mtime="" now=0 age=0 max_age=0
                mtime=$(_borg_file_mtime "$artifact") || mtime=""
                if [[ -z "$mtime" ]]; then
                    # `stat` could not report an mtime. That is ignorance, not staleness — saying
                    # WARN here would be a confident wrong answer, which is the failure shape this
                    # command exists to catch.
                    fresh="n/a"
                else
                    now=$(date +%s)
                    age=$(( now - mtime ))
                    max_age=$(( interval * 3 ))
                    if (( age > max_age )); then
                        fresh="WARN"
                        agent_warn=1
                        [[ -z "$hint" ]] && hint="stale output ($artifact) — check logs, re-run ./install.sh"
                    else
                        fresh="OK"
                    fi
                fi
            fi
        fi

        local color="" status_word=""
        if (( ! agent_ok )); then
            color="$RED"; status_word="FAIL"; overall_exit=1
        elif (( agent_warn )); then
            color="$YELLOW"; status_word="WARN"
        else
            color="$GREEN"; status_word="OK"
        fi

        printf " %-14s %-10s %-8s %-10s ${color}%s${NC}\n" "$name" "$reg" "$exit_status" "$fresh" "$status_word"
        [[ -n "$hint" ]] && echo -e "   ${DIM}→ $hint${NC}"
    done
    echo

    # Headless `claude -p` reachability — the narrative half of `borg link --brief`. This is what
    # makes a dead LLM path a health-check finding instead of something noticed by reading thin
    # output (docs/plans/directives/2026-08-10-briefing-fallback-and-summary-provenance.md, defect
    # 1). NOT a launchd agent, so REG/FRESH are n/a here; EXIT carries the actual claude exit code.
    printf "${BOLD} %-14s %-10s %-8s %-10s %s${NC}\n" "CHECK" "REG" "EXIT" "FRESH" "STATUS"
    printf '%0.s─' {1..70}; echo
    local narrative_out narrative_rc=0 narrative_hint="" narrative_status="OK" narrative_color="$GREEN"
    narrative_out=$(_borg_timeout 10 claude -p "say ok" --model claude-haiku-4-5-20251001 \
        --no-session-persistence --bare 2>&1) || narrative_rc=$?
    if [[ $narrative_rc -eq 124 ]]; then
        narrative_status="WARN"; narrative_color="$YELLOW"
        narrative_hint="claude -p timed out — 'borg link --brief' will fall back to the borg link document"
    elif [[ "$narrative_out" == *"Not logged in"* ]]; then
        narrative_status="WARN"; narrative_color="$YELLOW"
        narrative_hint="claude not logged in headless (Keychain-only OAuth token on macOS) — expected on some machines, not a bug to chase; 'borg link --brief' falls back to the borg link document"
    elif [[ $narrative_rc -ne 0 ]]; then
        narrative_status="WARN"; narrative_color="$YELLOW"
        narrative_hint="claude -p exited $narrative_rc — 'borg link --brief' will fall back to the borg link document"
    fi
    printf " %-14s %-10s %-8s %-10s ${narrative_color}%s${NC}\n" "claude-cli" "n/a" "$narrative_rc" "n/a" "$narrative_status"
    [[ -n "$narrative_hint" ]] && echo -e "   ${DIM}→ $narrative_hint${NC}"
    echo

    # Clock skew: for each running drone container, compare its clock against the host's. A
    # skewed VM clock silently corrupts freshness/mtime checks elsewhere (this is how #98 hid) —
    # catching it here is cheap and proactive. Not a launchd agent, so it borrows the same table
    # columns: REG is whether we could reach the container's clock at all, EXIT carries the skew
    # in seconds (repurposed — there is no process exit code here), FRESH is n/a.
    local -a containers
    # `|| true` because a machine with no docker binary must not kill doctor under set -e —
    # the whole point of a health check is to keep reporting on the machines that are missing things.
    containers=(${(f)"$(docker ps --filter 'label=dev.role=app' --format '{{.Names}}' 2>/dev/null || true)"})
    containers=(${containers:#})

    if (( ${#containers[@]} > 0 )); then
        printf "${BOLD} %-14s %-10s %-8s %-10s %s${NC}\n" "CONTAINER" "REG" "SKEW" "FRESH" "STATUS"
        printf '%0.s─' {1..70}; echo

        local container host_epoch container_epoch skew
        for container in "${containers[@]}"; do
            local c_ok=1 c_warn=0 c_hint="" c_reg="yes" c_exit="n/a"

            host_epoch=$(date +%s)
            container_epoch=$(docker exec "$container" date +%s 2>/dev/null) || container_epoch=""

            if [[ -z "$container_epoch" || "$container_epoch" != <-> ]]; then
                c_reg="MISSING"
                c_ok=0
                c_hint="could not read clock via docker exec — is the container running?"
            else
                skew=$(( container_epoch - host_epoch ))
                (( skew < 0 )) && skew=$(( -skew ))
                c_exit="${skew}s"
                if (( skew > 120 )); then
                    c_warn=1
                    c_hint="clock skew ${skew}s vs host — restart the container/VM"
                fi
            fi

            local c_color="" c_status=""
            if (( ! c_ok )); then
                c_color="$RED"; c_status="FAIL"; overall_exit=1
            elif (( c_warn )); then
                c_color="$YELLOW"; c_status="WARN"
            else
                c_color="$GREEN"; c_status="OK"
            fi

            printf " %-14s %-10s %-8s %-10s ${c_color}%s${NC}\n" "$container" "$c_reg" "$c_exit" "n/a" "$c_status"
            [[ -n "$c_hint" ]] && echo -e "   ${DIM}→ $c_hint${NC}"
        done
        echo
    fi

    # Dependency version floors (SA1, 2026-08-21 security audit): a binary below a floor is a
    # NAMED failure here instead of silent CVE exposure. Floors exist only where a specific
    # advisory sets one — gh >= 2.97.0 closes CVE-2026-64652 (gh auth status leaks partial
    # fine-grained PATs below it). Add a jq floor when a fixed release ships for
    # CVE-2026-41256/39956; no fixed version exists as of 2026-08-22.
    printf "${BOLD} %-14s %-10s %-8s %-10s %s${NC}\n" "VERSION" "HAVE" "FLOOR" "" "STATUS"
    printf '%0.s─' {1..70}; echo
    local -a version_floors=("gh|2.97.0|CVE-2026-64652: gh auth status leaks partial tokens below 2.97.0 — brew upgrade gh")
    local floor_line v_bin v_floor v_why v_have
    for floor_line in "${version_floors[@]}"; do
        v_bin="${floor_line%%|*}"
        local v_rest="${floor_line#*|}"
        v_floor="${v_rest%%|*}"
        v_why="${v_rest#*|}"
        v_have=$(_borg_binary_version "$v_bin")
        local v_status="OK" v_color="$GREEN" v_hint=""
        if [[ -z "$v_have" ]]; then
            v_status="WARN"; v_color="$YELLOW"; v_have="absent"
            v_hint="$v_bin not found — floor not checkable on this machine"
        elif ! _borg_version_ge "$v_have" "$v_floor"; then
            v_status="FAIL"; v_color="$RED"; overall_exit=1
            v_hint="$v_why"
        fi
        printf " %-14s %-10s %-8s %-10s ${v_color}%s${NC}\n" "$v_bin" "$v_have" "$v_floor" "" "$v_status"
        [[ -n "$v_hint" ]] && echo -e "   ${DIM}→ $v_hint${NC}"
    done
    echo

    return $overall_exit
}

# First X.Y.Z-looking token of `<bin> --version`, or empty when the binary is absent.
_borg_binary_version() {
    local out
    out=$(command "$1" --version 2>/dev/null | head -1) || return 0
    echo "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Dotted-version compare: succeeds when $1 >= $2. Pure zsh, no sort -V dependency.
_borg_version_ge() {
    local -a have=(${(s:.:)1}) floor=(${(s:.:)2})
    local i
    for i in 1 2 3; do
        local h="${have[$i]:-0}" f="${floor[$i]:-0}"
        (( h > f )) && return 0
        (( h < f )) && return 1
    done
    return 0
}

# ── program manifests (PM6) ────────────────────────────────────────────────────
# borg program list|plan|sync — the sync coordinator over <project>/.borg/programs/*.json.
# The Python side (merge-tree/coordinator.py) is registry-free by design (Architecture Rules:
# testable core, shell wrapper) — THIS is the registry-resolving caller. Every registered project
# path becomes a --programs-dir, so `borg program list` sweeps the whole collective. Explicit
# --programs-dir args are passed through untouched and suppress the registry sweep.
cmd_program() {
    local action="${1:-list}"
    case "$action" in
        list|plan|sync) ;;
        *) die "usage: borg program list|plan|sync [--programs-dir <path>]... ; plan also takes --recon <file>" ;;
    esac
    # Guarded: zsh hard-errors a bare `shift` at $#==0 (unlike bash), and set -e makes that fatal —
    # which would kill the argless `borg program` the :-list default exists for.
    (( $# )) && shift

    typeset -a _prog_args
    local _explicit_dirs=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --programs-dir)
                [[ -n "${2:-}" ]] || die "borg program: --programs-dir needs a path"
                _prog_args+=(--programs-dir "$2"); _explicit_dirs=1; shift 2 ;;
            --recon)
                # argparse registers --recon on the plan subparser only; failing here beats
                # advertising a flag downstream then rejects.
                [[ "$action" == "plan" ]] || die "borg program: --recon is only valid with 'plan'"
                [[ -n "${2:-}" ]] || die "borg program: --recon needs a file (or -)"
                _prog_args+=(--recon "$2"); shift 2 ;;
            *)              die "unknown flag '$1' for borg program" ;;
        esac
    done

    if (( ! _explicit_dirs )); then
        [[ -f "$BORG_REGISTRY" ]] || die "no registry at $BORG_REGISTRY — run 'borg add <path>' first"
        local _proj_path
        while IFS= read -r _proj_path; do
            [[ -n "$_proj_path" ]] && _prog_args+=(--programs-dir "$_proj_path")
        done < <(jq -r '.projects[].path // empty' "$BORG_REGISTRY")
        (( ${#_prog_args[@]} )) || die "registry has no project paths — run 'borg add <path>' first"
    fi

    PYTHONPATH="$BORG_HOME${PYTHONPATH:+:$PYTHONPATH}" \
        python3 "$BORG_HOME/merge-tree/coordinator.py" "$action" "${_prog_args[@]}"
}

cmd_version() {
    local version_file="$BORG_HOME/VERSION"
    if [[ -f "$version_file" ]]; then
        tr -d '[:space:]' < "$version_file"
        printf '\n'
    else
        echo "$BORG_VERSION"
    fi
}

# ── recon fan-out ──────────────────────────────────────────────────────────────
# Source-agnostic "recon fan-out" primitive: sweep activity across pluggable source adapters since
# a mark, normalize to Items, reconcile against local .borg checkpoints, emit one reconciled doc.
# Fully migrated to Python (borg_core/recon/{core,shell,cli}.py) -- see the `recon)` case arm below
# and docs/plans/assimilated/2026-08-12-recon-migration-ledger.md. The judgment/synthesis layer is
# the /borg-recon skill.

cmd_help() {
    cat <<'EOF'

    _______________
   /|             /|      THE BORG COLLECTIVE
  / |            / |      resistance is futile
    |___________|  |
    |  |        |  |
    |  |________|__|
    | /         | /
    |/          |/

  COMMANDS
    init                Launch orchestrator: morning briefing + Claude session
    claude              Resume orchestrator session (continue most recent)
    link [project]      Overview (no arg) or deep dive (with project)
                          --local   Skip the source sweep — registry + manifests only, no network
                          --brief   Same document, same sweep, as prose — falls back to the page
                          --refresh Regenerate summaries
                          --all     Include archived projects
    next [--switch]     What needs your attention? (--switch jumps there)
    switch [query]      fzf picker → jump to project tmux window
    program <action>    Program-manifest coordinator over <project>/.borg/programs/*.json
                          list           Every declared program across registered projects
                          plan           Read-only three-way drift audit (borg / target / recon)
                          sync           Rewrite via borg's writer + dispatch to a sync target
                          --programs-dir <path>  Explicit roots (suppresses the registry sweep)
                          --recon <file> (plan only) recon/gather JSON for the reality check
    scan                Discover projects from session history
    add [path]          Register a project (defaults to $PWD)
    rm <project>        Unregister a project
    pin [project]       Mark as priority (sorts first, preferred by next)
    unpin [project]     Remove priority flag
    sever               Tear down everything: containers, windows, session
    regenerate          Archive stale projects (idle >48h)
    start <slug>        Promote a directive to PROJECT_PLAN.md (one in-flight per project)
    setup               Register Claude Code hooks, skills, and config
    version             Print the installed borg version (alias: --version, -V)
    store-secret <name> Store a secret in macOS Keychain and wire to secrets.zsh
    cortex-resume [proj] Force-wake a paused Cortex pane (no arg = first pending)
    nanoprobes          List recent nanoprobe (subagent) runs (alias: np)
    nanoprobe-log <id>  Show transcript for a nanoprobe run (id prefix matches)
    spend               Main-vs-subagent spend split + trend (this machine; --project/--by-model/--last)
    reap                Persist idle to stale active/waiting sessions (no live window)
    reap-worktrees [p]  Remove stale borg-managed nanoprobe worktrees (all repos or one)
    doctor              Verify the 4 launchd agents + headless claude -p reachability
    help                Show this message

  REMOVED
    2026-08-10 — ls, status, hail, brief, briefing, refresh were aliases for 'link'.
                 Six names for one command; 'borg link' is now the only one.
    2026-08-26 — recon retired as a human verb. 'borg link' sweeps every source itself, so
                 there is nothing a human still needs it for. The ENGINE is not retired:
                 'borg recon --json' and 'borg recon --adapters' are the machine surface
                 /borg-recon and merge-tree/gather.py consume, and both still work.

  HOTKEY
    Ctrl+Space >        Jump to most pressing project (runs: borg next --switch)

  SKILLS (use in Claude Code sessions)
    /borg-plan              Project planning + Collective review
    /borg-review            Mid-session diagnostic + loop detection
    /borg-assimilate        Shipping checklist + Collective review + execution
    /borg-collective-review Adversarial multi-persona review
    /borg-link-up           Flush session state to checkpoint (run before stopping)
    /borg-link              Same as 'borg link' — overview or deep dive
    /borg-next              Same as 'borg next' — what needs attention
    /borg-switch            Same as 'borg switch' — jump to project
    /borg-recon             Cross-source synthesis over 'borg recon --json' ('borg link' is the front door)
    /adhd-guardrails        Compassionate constraints (always active)

  STATUS
    active              Drone is processing (green)
    waiting <<<         Drone needs your input (yellow)
    idle                Session ended (dim)
    archived            Hidden from default ls (shown with --all)

  CONFIG
    ~/.config/borg/config.zsh       Work/life boundaries, limits
    ~/.config/borg/registry.json    Session registry
    <project>/.borg/checkpoints/    Per-project session checkpoints (via /borg-link-up)

  ENVIRONMENT
    BORG_TMUX_SESSION       tmux session name (default: borg)
    BORG_MAX_ACTIVE         Capacity warning threshold (default: 3)
    BORG_REAP_STALE_HOURS   Reap active/waiting after N idle hours (default: 12)
    BORG_WORK_HOURS         e.g. "09:00-18:00" (empty to disable)
    BORG_WORK_PROJECTS      Comma-separated work project names
    BORG_DEBUG              Set to any value for debug output
    BORG_SECRETS_FILE       Override path to secrets.zsh (default: ~/.config/dotfiles/zsh/secrets.zsh)

  "We are the Borg. Your projects will be assimilated."

EOF
}

cmd_vinculum() {
    local VINC_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/borg/vinculum"
    local as_label="" verb=""
    local -a rest=()
    local skip_next=0 found_verb=0

    for arg in "$@"; do
        if (( skip_next )); then
            as_label="$arg"
            skip_next=0
        elif [[ "$arg" == "--as" ]]; then
            skip_next=1
        elif (( ! found_verb )); then
            verb="$arg"
            found_verb=1
        else
            rest+=("$arg")
        fi
    done
    verb="${verb:-ls}"

    local sub_id
    if [[ -n "$as_label" ]]; then
        sub_id="$as_label"
    elif [[ -n "${TMUX_PANE:-}" ]]; then
        sub_id="pane-${TMUX_PANE#%}"
    else
        sub_id="host-$$"
    fi

    case "$verb" in
        pub)
            local ch="${rest[1]:-}"
            [[ -n "$ch" ]] || die "vinculum pub: missing <channel>"
            local body="${(j: :)rest[2,-1]}"
            local ch_dir="$VINC_DIR/$ch"
            mkdir -p "$ch_dir"
            local log="$ch_dir/log.jsonl"
            local uuid ts
            uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
            ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            jq -nc --arg id "$uuid" --arg ts "$ts" --arg from "$sub_id" --arg body "$body" \
                '{id: $id, ts: $ts, from: $from, body: $body}' >> "$log"
            ;;
        sub)
            local ch="${rest[1]:-}"
            [[ -n "$ch" ]] || die "vinculum sub: missing <channel>"
            local ch_dir="$VINC_DIR/$ch"
            mkdir -p "$ch_dir/cursors" "$ch_dir/meta"
            local log="$ch_dir/log.jsonl"
            [[ -f "$log" ]] || touch "$log"
            local cur_lines
            cur_lines="$(wc -l < "$log" | tr -d ' ')"
            local cursor_file="$ch_dir/cursors/$sub_id"
            local tmp_cursor="${cursor_file}.tmp.$$"
            printf '%s\n' "$cur_lines" > "$tmp_cursor"
            mv "$tmp_cursor" "$cursor_file"
            local sub_list="$ch_dir/subscribers"
            if ! grep -qxF "$sub_id" "$sub_list" 2>/dev/null; then
                printf '%s\n' "$sub_id" >> "$sub_list"
            fi
            info "Subscribed '$sub_id' to channel '$ch' (cursor at $cur_lines)"

            # ── Live delivery watcher ─────────────────────────────────────────
            local delivery_pane="${TMUX_PANE:-}"
            local meta_file="$ch_dir/meta/$sub_id"
            if [[ -z "$delivery_pane" ]]; then
                warn "vinculum: not in tmux — subscribed '$sub_id' for pull only (live delivery needs a tmux pane)"
            else
                # Idempotent: do not re-spawn if a live PID already exists
                local existing_pid=0
                if [[ -f "$meta_file" ]]; then
                    existing_pid="$(jq -r '.pid // 0' "$meta_file" 2>/dev/null || echo 0)"
                fi
                local do_spawn=1
                if (( existing_pid > 0 )) && kill -0 "$existing_pid" 2>/dev/null; then
                    do_spawn=0
                    dbg "vinculum sub: watcher already live for '$sub_id' on '$ch' (PID $existing_pid)"
                fi
                if (( do_spawn )); then
                    local watch_log="$VINC_DIR/$ch/watch-${sub_id}.log"
                    local watch_pid
                    nohup borg-vinculum-watch "$ch" --pane "$delivery_pane" --as "$sub_id" \
                        >> "$watch_log" 2>&1 &
                    watch_pid=$!
                    disown "$watch_pid" 2>/dev/null || true
                    local tmp_meta="${meta_file}.tmp.$$"
                    printf '{"pane":"%s","pid":%d}\n' "$delivery_pane" "$watch_pid" > "$tmp_meta"
                    mv "$tmp_meta" "$meta_file"
                    dbg "vinculum sub: spawned watcher PID $watch_pid → pane $delivery_pane"
                fi
            fi
            ;;
        unsub)
            local ch="${rest[1]:-}"
            [[ -n "$ch" ]] || die "vinculum unsub: missing <channel>"

            # Kill live watcher before removing subscriber record
            local meta_file_u="$VINC_DIR/$ch/meta/$sub_id"
            if [[ -f "$meta_file_u" ]]; then
                local watcher_pid=0
                watcher_pid="$(jq -r '.pid // 0' "$meta_file_u" 2>/dev/null || echo 0)"
                if (( watcher_pid > 0 )) && kill -0 "$watcher_pid" 2>/dev/null; then
                    kill "$watcher_pid" 2>/dev/null || true
                    dbg "vinculum unsub: killed watcher PID $watcher_pid for '$sub_id' on '$ch'"
                fi
                rm -f "$meta_file_u"
            fi

            local sub_list="$VINC_DIR/$ch/subscribers"
            if [[ -f "$sub_list" ]]; then
                local tmp_unsub="${sub_list}.tmp.$$"
                grep -vxF "$sub_id" "$sub_list" > "$tmp_unsub" 2>/dev/null || true
                mv "$tmp_unsub" "$sub_list"
            fi
            info "Unsubscribed '$sub_id' from channel '$ch'"
            ;;
        ls)
            local ch="${rest[1]:-}"
            if [[ -z "$ch" ]]; then
                if [[ ! -d "$VINC_DIR" ]]; then
                    info "No channels."
                    return 0
                fi
                local found=0 name="" n_msgs=0 n_subs=0 log_f="" sub_f="" ch_dir2=""
                setopt localoptions nullglob
                for ch_dir2 in "$VINC_DIR"/*/; do
                    [[ -d "$ch_dir2" ]] || continue
                    name="${${ch_dir2%/}##*/}"
                    n_msgs=0
                    n_subs=0
                    log_f="$ch_dir2/log.jsonl"
                    sub_f="$ch_dir2/subscribers"
                    [[ -f "$log_f" ]] && n_msgs="$(wc -l < "$log_f" | tr -d ' ')"
                    [[ -f "$sub_f" ]] && n_subs="$(wc -l < "$sub_f" | tr -d ' ')"
                    printf '  %-24s  %3d msgs  %2d subs\n' "$name" "$n_msgs" "$n_subs"
                    found=1
                done
                (( found )) || info "No channels."
            else
                local ch_dir="$VINC_DIR/$ch"
                if [[ ! -d "$ch_dir" ]]; then
                    info "Channel '$ch' does not exist."
                    return 0
                fi
                local log_f2="$ch_dir/log.jsonl"
                local total_msgs=0
                [[ -f "$log_f2" ]] && total_msgs="$(wc -l < "$log_f2" | tr -d ' ')"
                local sub_f2="$ch_dir/subscribers"
                if [[ ! -f "$sub_f2" ]]; then
                    info "Channel '$ch': no subscribers."
                    return 0
                fi
                local has_subs=0 sid="" cur_f="" cur=0 unread=0
                while IFS= read -r sid; do
                    [[ -z "$sid" ]] && continue
                    cur_f="$ch_dir/cursors/$sid"
                    cur=0
                    [[ -f "$cur_f" ]] && cur="$(tr -d '[:space:]' < "$cur_f")"
                    unread=$(( total_msgs - cur ))
                    (( unread < 0 )) && unread=0
                    local watcher_status="no watcher"
                    local meta_f_ls="$ch_dir/meta/$sid"
                    if [[ -f "$meta_f_ls" ]]; then
                        local w_pid=0
                        w_pid="$(jq -r '.pid // 0' "$meta_f_ls" 2>/dev/null || echo 0)"
                        if (( w_pid > 0 )) && kill -0 "$w_pid" 2>/dev/null; then
                            watcher_status="running (PID $w_pid)"
                        elif (( w_pid > 0 )); then
                            watcher_status="stopped (was PID $w_pid)"
                        fi
                    fi
                    printf '  %-32s  %3d unread  %s\n' "$sid" "$unread" "$watcher_status"
                    has_subs=1
                done < "$sub_f2"
                (( has_subs )) || info "Channel '$ch': no subscribers."
            fi
            ;;
        pull)
            local ch="" do_json=0
            for a in "${rest[@]}"; do
                if [[ "$a" == "--json" ]]; then
                    do_json=1
                elif [[ -z "$ch" ]]; then
                    ch="$a"
                fi
            done
            [[ -n "$ch" ]] || die "vinculum pull: missing <channel>"
            local ch_dir="$VINC_DIR/$ch"
            local log="$ch_dir/log.jsonl"
            if [[ ! -f "$log" ]]; then
                return 0
            fi
            local cur_f="$ch_dir/cursors/$sub_id"
            local cursor=0
            [[ -f "$cur_f" ]] && cursor="$(tr -d '[:space:]' < "$cur_f")"
            local total_msgs
            total_msgs="$(wc -l < "$log" | tr -d ' ')"
            if (( cursor < total_msgs )); then
                local line_num=$(( cursor + 1 ))
                if (( do_json )); then
                    sed -n "${line_num},\$p" "$log"
                else
                    sed -n "${line_num},\$p" "$log" | jq -r '.body'
                fi
            fi
            mkdir -p "$ch_dir/cursors"
            local tmp_cur="${cur_f}.tmp.$$"
            printf '%s\n' "$total_msgs" > "$tmp_cur"
            mv "$tmp_cur" "$cur_f"
            ;;
        help)
            echo "Usage: borg vinculum [--as <label>] <verb> [args]"
            echo ""
            echo "  pub <channel> <msg...>   Publish a message to a channel"
            echo "  sub <channel>            Subscribe this pane to a channel"
            echo "  unsub <channel>          Unsubscribe this pane from a channel"
            echo "  ls [channel]             List channels or a channel's subscribers + unread counts"
            echo "  pull <channel> [--json]  Pull unread messages (advances cursor)"
            echo ""
            echo "  --as <label>             Override subId (default: tmux pane or host-PID)"
            ;;
        *)
            die "vinculum: unknown verb '$verb'. Run: borg vinculum help"
            ;;
    esac
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

borg_registry_init

# Run a borg_core Python module with the config surface it needs.
#
# WHY THIS EXISTS. Every config variable borg.zsh owns is assigned WITHOUT `export` -- BORG_DIR
# (borg.zsh:24), BORG_MAX_ACTIVE and BORG_CORTEX_WAKES (borg.zsh:43-48), BORG_REGISTRY
# (lib/registry.zsh:15), BORG_TMUX_SESSION (lib/tmux.zsh:5), BORG_REAP_STALE_HOURS
# (lib/reaper.sh:11). They are shell variables, so an in-process zsh function sees them and a
# `python3 -m` CHILD sees none of them. That is not theoretical: it shipped. `borg recon` read
# BORG_REGISTRY from the environment with no fallback and therefore died with "no registry at " on
# every real invocation except `--adapters`, which returns before the check. It stayed invisible
# because every test that reaches the Python path puts BORG_REGISTRY in the environment itself
# (tests/test_helper/setup.bash exports it; the pytest suites monkeypatch it), so the inheritance
# path was never once exercised -- the same shape as the usage-watch and memory-gate blind spots in
# CLAUDE.md's Learned section.
#
# Defaults are applied HERE rather than passed through empty: a child reading
# `os.environ.get("BORG_REAP_STALE_HOURS", "12")` gets "" -- not "12" -- if the variable is exported
# empty, and int("") raises. An unset variable must arrive as its default or not at all.
#
# Deliberately a prefix assignment, not `export`: only the Python children get these, so hooks,
# `claude`, docker and every other child keep the environment they have today.
#
# Deliberately defined HERE, immediately above its only callers, rather than up in the Helpers
# section: inserting 30 lines at the top of this file silently shifts every `borg.zsh:<N>` reference
# in tests/cli_contract.bats and PROJECT_PLAN.md by 30. Nothing references a line below this point.
_borg_py() {
    BORG_DIR="$BORG_DIR" \
    BORG_REGISTRY="$BORG_REGISTRY" \
    BORG_MAX_ACTIVE="${BORG_MAX_ACTIVE:-3}" \
    BORG_REAP_STALE_HOURS="${BORG_REAP_STALE_HOURS:-12}" \
    BORG_TMUX_SESSION="${BORG_TMUX_SESSION:-borg}" \
    BORG_ORCHESTRATOR_ROOT="${BORG_ORCHESTRATOR_ROOT:-$HOME/dev}" \
    BORG_CORTEX_WAKES="$BORG_CORTEX_WAKES" \
    BORG_NO_REAP="$BORG_NO_REAP" \
    PYTHONPATH="$BORG_HOME${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m "$@"
}
# BORG_NO_REAP above is a BARE pass-through with NO `:-` default: borg_core/link/shell.py's
# reap_disabled() reads it with `bool(os.environ.get(...))`, so an exported-empty value is
# correctly falsy -- unlike BORG_REAP_STALE_HOURS, which must arrive as its default because
# `int("")` raises. This changes the environment of the existing recon/add/rm children too; that
# is safe because nothing else in borg_core reads BORG_NO_REAP, and cli_contract.bats's "the python3
# dispatch wrapper hands borg's config surface to the child" asserts only the PRESENCE of a fixed
# list of names. (Anchored by test name: line numbers in that file drift on every insertion.)

# The `--help` shape: full notice on STDOUT at exit 0, because a human who asked for help got it.
#
# INLINED, NOT A SHARED VAR (2026-08-26): the retirement gate moved to
# borg_core/recon/cli.py::main(), which carries its own copy of the lead sentence for the error
# path (`_RECON_RETIRED_LEAD` there). That left this `--help` printer as the sentence's ONLY
# consumer in this file, so the `_BORG_RECON_RETIRED_LEAD` shared var this used to read (whose
# whole reason to exist was keeping N>1 consumers from drifting) is gone -- one consumer can't
# drift from itself. The bats cases still only match the SUBSTRINGS "was retired" and "borg link",
# never the full literal, so this stays free to reword without touching a test or the Python copy.
_borg_recon_retired() {
    echo "'borg recon' was retired as a human command — 'borg link' sweeps every source itself."
    echo "Run: borg link"
    echo "usage (machine surface only): borg recon --json [--since ISO] [--projects a,b] [--sources github,..]"
    echo "                              borg recon --adapters"
}

# Phase 3 (A4+A5): the ONE dispatch point for every `borg link` shape. Collapses today's two parse
# layers (the top-level case arm's `--json` intercept plus cmd_link's own flag loop) into ONE loop
# with the SAME semantics. Does NOT `shift` -- the `link)` case arm strips the subcommand itself, so
# a caller can invoke this with no arguments at all.
#
# Flags recognised: --json, --porcelain, --brief|--llm (aliases), --refresh, --all, --local, and
# -h|--help. ANY other `-*` is silently swallowed (no die, exit 0) -- pinned by the case named
# "link tolerates an unknown flag and still renders the overview at exit 0" in cli_contract.bats;
# do NOT adopt recon's die-on-unknown-flag behavior here. A bare word sets the project, LAST-WINS
# (`link a b` deep-dives `b`). Precedence, strictly: help > json > porcelain > project(deep) >
# brief > overview -- this merges today's two layers, where the top arm intercepted `--json` first
# and cmd_link's own order was porcelain > project > brief > overview.
_borg_link_dispatch() {
    typeset _link_json=0 _link_porcelain=0 _link_brief=0 _link_refresh=0 _link_all=0 _link_local=0
    typeset _link_help=0
    typeset _link_project="" _link_arg
    typeset -a _link_py_args
    for _link_arg in "$@"; do
        case "$_link_arg" in
            --json)        _link_json=1 ;;
            --porcelain)   _link_porcelain=1 ;;
            --brief|--llm) _link_brief=1 ;;
            --refresh)     _link_refresh=1 ;;
            --all)         _link_all=1 ;;
            --local)       _link_local=1 ;;
            -h|--help)     _link_help=1 ;;                # MUST precede `-*)`: zsh case is first-match
            -*)            ;;                            # lenient, matching cmd_link's `-*) shift`
            *)             _link_project="$_link_arg" ;;  # last-wins, matching cmd_link
        esac
    done
    # --local MUST be matched explicitly here and forwarded on every arm. The lenient `-*)` arm two
    # lines up silently swallows unknown flags and exits 0 (pinned by the unknown-flag case in
    # cli_contract.bats), so a half-wired --local would fail OPEN -- the caller believes it opted
    # down, the flag is eaten, and the expensive path runs anyway with nothing to show it happened.

    # -h|--help is matched EXPLICITLY and answered before anything else runs. Until S4 it fell into
    # the lenient `-*)` arm above, was swallowed, and rendered the ASCII-cube overview -- which
    # post-S3 SWEEPS: measured 0.85s against 0.11s with --local, for a flag whose whole job is to
    # print one line. `-h` needs the same arm because the top-level `help|--help|-h)` matches on $1
    # only and `link)` forwards "${@:2}", so `borg link -h` reached the swallow too.
    #
    # NOT fixed by teaching `-*)` to imply --local. That arm's pinned property is that an unknown
    # flag carries NO semantics, and a silent --local there is invisible to every stdout assertion
    # in the suite (cli_contract.bats records by mutation that `link beta` and `link --local beta`
    # are byte-identical on stdout). The defect was that --help rendered the overview AT ALL, not
    # that it rendered it expensively.
    #
    # BEFORE the --refresh block below on purpose: `borg link --refresh --help` must not fire
    # `cmd_scan --llm` -- a real `claude` invocation -- on its way to printing one usage line.
    #
    # `return 0`, never the `exit 0` the `recon)` case arm uses: this is a FUNCTION, and an
    # in-process caller would be killed outright by an `exit`. `cmd_watch` was that caller until
    # AC4-era retirement; the rule outlives it, because `return` is right for EVERY in-process
    # caller and `exit` is right for none.
    #
    # The wording must not contain "unknown command" or "was removed": cli_smoke.bats's "borg link
    # --help prints usage and never reads as a removed verb" asserts this exact output carries
    # neither, so a helpful pointer at recon's retirement here turns that case red. That case is
    # the WORDING half only -- the LIVENESS half ("borg link is still dispatched", and its
    # cli_contract twin) was re-pointed at `borg link --local` when this arm landed, because an
    # early `return` here means `--help` no longer reaches any dispatch arm to prove alive.
    if (( _link_help )); then
        echo "usage: borg link [project] [--local] [--all] [--refresh] [--brief|--llm] [--json] [--porcelain]"
        echo "       --local skips the source sweep (registry + manifests only, no network)"
        return 0
    fi

    # The refresh scan runs once here (was five call sites, one per dispatch arm) instead of once
    # per branch below. The --json redirect (1>&2, so the scan's own chatter can't splice ahead of
    # the JSON document on stdout -- see the fd-duping note that used to sit next to this call) is
    # the only branch-dependent piece, so it stays keyed off _link_json rather than being lost in
    # the hoist.
    if (( _link_refresh )); then
        if (( _link_json )); then
            cmd_scan --llm 1>&2 || true
        else
            cmd_scan --llm
        fi
    fi

    if (( _link_json )); then
        # Diagnostics on the --json path go to STDERR. `warn` (borg.zsh:30) writes to STDOUT, and
        # the desktop pre-pass reaches it via borg_registry_merge -> _borg_registry_write
        # (lib/registry.zsh:31): one blocked write splices a colored "registry write blocked" line
        # ahead of the document and `jq` dies on it. `2>/dev/null` does NOT catch that -- the
        # warning is on fd 1. `1>&2 2>/dev/null` moves it to fd 2 and keeps today's stderr
        # suppression (VERIFIED: redirections apply left-to-right, so fd1 is duped from the
        # ORIGINAL fd2 before fd2 is reopened on /dev/null).
        #
        # The desktop pre-pass runs ONLY for the overview shape (no project positional). The deep
        # dive never scans and never writes the registry; running it for `--json <project>` would
        # add a registry WRITE to a path that has always been read-only. Deliberate, not an oversight.
        if [[ -z "$_link_project" ]]; then
            borg_desktop_scan 1>&2 2>/dev/null || true
        fi
        _link_py_args=(--json)
        (( _link_all )) && _link_py_args+=(--all)
        (( _link_local )) && _link_py_args+=(--local)
        [[ -n "$_link_project" ]] && _link_py_args+=(-- "$_link_project")
        _borg_py borg_core.link.cli "${_link_py_args[@]}"
        return 0
    fi

    if (( _link_porcelain )); then
        # Human arms keep the desktop pre-pass warning on STDOUT (today's behavior) -- do NOT reuse
        # the --json arm's `1>&2 2>/dev/null` redirect here; STEP 1 of cli_contract.bats's "link
        # --json stdout stays valid JSON when the registry write warning fires, and the focus path
        # never triggers it" asserts the human path really does splice the warning onto stdout.
        # (Anchored by test name: that file's line numbers drift on every insertion.)
        borg_desktop_scan 2>/dev/null || true
        # CRITICAL: do NOT forward the positional in porcelain mode. `link --porcelain nosuchproject`
        # exits 0 with the listing today; forwarding it would build a focus block and die instead.
        _link_py_args=(--porcelain)
        (( _link_all )) && _link_py_args+=(--all)
        (( _link_local )) && _link_py_args+=(--local)
        _borg_py borg_core.link.cli "${_link_py_args[@]}"
        return 0
    fi

    if [[ -n "$_link_project" ]]; then
        # The deep dive stays read-only and never scans -- no desktop pre-pass here, matching today.
        #
        # CORRECTED 2026-08-28: this comment used to call this "the fzf preview's arm", citing a
        # `--preview "borg link {1}"` in `cmd_switch`. There is no such flag: `cmd_switch`'s `fzf`
        # invocation carries `--query`, `--prompt`, `--header`, `--delimiter` and `--with-nth`, and
        # nothing else -- `grep -- '--preview' borg.zsh` matches only prose. The per-keypress hot
        # loop that justification described does not exist. What is still true, and is the whole
        # reason this arm matters, is that it is the ONLY live caller that passes `--deep`, and it
        # serves EVERY `borg link <project>` a human types plus `drone link`, whose dispatch arm
        # (`link)       exec borg link ...` in drone.zsh) forwards a bare positional straight here.
        # Treat it as user-facing, not as a hot loop.
        _link_py_args=(--deep)
        (( _link_local )) && _link_py_args+=(--local)
        _link_py_args+=(-- "$_link_project")
        _borg_py borg_core.link.cli "${_link_py_args[@]}"
        return 0
    fi

    if (( _link_brief )); then
        # --brief IS A PRESENTATION MODE OF THE DOCUMENT, not a second path (2026-08-27 directive
        # "Fold `--brief` onto the document"). _borg_print_briefing makes the SAME
        # `_borg_py borg_core.link.cli --json` call every arm above makes, projects that JSON into
        # the narrative prompt, and renders THOSE SAME BYTES when the narrative is unavailable. One
        # sweep, one clock read, two consumers. This arm used to return before any Python ran at all,
        # which made `borg link` and `borg link --brief` two truth levels of one command -- the
        # failure class AC1 exists to kill -- and it is why AC1 stayed unticked with both of its
        # verify clauses passing.
        #
        # --all and --local are forwarded exactly as every other arm forwards them, and NOTHING ELSE
        # IS. Do not add a --local of this arm's own: the directive names and rejects it -- it would
        # make the answer cheap and still leave it un-swept, which is the same lie with a smaller
        # bill, and harder to find because the two arms would then agree about cost and disagree only
        # about truth.
        #
        # `borg_desktop_scan` STAYS ITS OWN STATEMENT, above the call and never folded into it: it
        # reaches `warn`, which writes to STDOUT (see its `echo -e` definition beside `info`/`die` at
        # the top of this file — no `>&2` on it), and inside the `$(...)` that captures the document
        # that line would splice ahead of the JSON and kill `jq`.
        borg_desktop_scan 2>/dev/null || true
        # THE BRIEFING'S STATUS IS THIS ARM'S STATUS. `_borg_print_briefing` returns non-zero on BOTH
        # of its no-page rungs — the document failing to BUILD ("Could not build the borg link
        # document") and the fallback page failing to RENDER ("Could not render the borg link
        # document") — and in either case the user got no page, which `borg link --brief` must not
        # report as success. Captured explicitly rather than left to `set -e` so the propagation is
        # visible at the call site.
        local _brief_rc=0
        _borg_print_briefing "$_link_all" "$_link_local" || _brief_rc=$?
        return $_brief_rc
    fi

    borg_desktop_scan 2>/dev/null || true
    _link_py_args=()
    (( _link_all )) && _link_py_args+=(--all)
    (( _link_local )) && _link_py_args+=(--local)
    _borg_py borg_core.link.cli "${_link_py_args[@]}"
}

case "${1:-help}" in
    init)     cmd_init ;;
    claude)   cmd_claude ;;
    next)     cmd_next "${@:2}" ;;
    link)  _borg_link_dispatch "${@:2}" ;;
    switch)   cmd_switch "${@:2}" ;;
    recon)
        # Dispatches to the Python port (borg_core/recon/{core,shell,cli}.py). Inlined here, no
        # dispatch wrapper function for this arm, so `recon` is fully migrated per the migration
        # ledger -- see docs/plans/assimilated/2026-08-12-recon-migration-ledger.md. PYTHONPATH is
        # set explicitly rather than relying on cwd, since borg can be invoked from any directory.
        #
        # RETIRED 2026-08-26 AS A HUMAN VERB, ENGINE INTACT (AC1). `borg link` folds the same
        # fan-out into its own document, so the human digest has no reason to exist -- but
        # `--json` and `--adapters` have real machine consumers (skills/borg-recon/SKILL.md,
        # merge-tree/gather.py, evals/s4-k3/run.sh) and AC1 never asked for the engine to die.
        #
        # THE GATE LIVES IN borg_core/recon/cli.py::main(), not here. This arm's parse loop stays
        # ONLY for the two things argparse does not do: the `--list` alias for `--adapters`, and
        # dying on an unknown flag before a Python process is even spawned. See
        # docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md for why the gate
        # moved and the measurements behind it.
        shift
        typeset -a _recon_py_args
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --since)            _recon_py_args+=(--since "$2"); shift 2 ;;
                --sources)          _recon_py_args+=(--sources "$2"); shift 2 ;;
                --projects)         _recon_py_args+=(--projects "$2"); shift 2 ;;
                --json)             _recon_py_args+=(--json); shift ;;
                --adapters|--list)  _recon_py_args+=(--adapters); shift ;;
                -h|--help)          _borg_recon_retired; exit 0 ;;
                *) die "borg recon: unknown flag '$1' (see borg recon --help)" ;;
            esac
        done
        _borg_py borg_core.recon.cli "${_recon_py_args[@]}"
        ;;
    scan)     cmd_scan "${@:2}" ;;
    add)
        # Dispatches to the Python port (borg_core/registry/{core,shell,cli}.py). Inlined here, no
        # dispatch wrapper function for this arm, so `add` is fully migrated per the migration
        # ledger -- see docs/plans/assimilated/2026-08-12-recon-migration-ledger.md.
        shift
        _borg_py borg_core.registry.cli add "$@"
        ;;
    rm)
        # Dispatches to the Python port (borg_core/registry/{core,shell,cli}.py). See the `add)`
        # arm above and the migration ledger for the same rationale.
        shift
        _borg_py borg_core.registry.cli rm "$@"
        ;;
    color)    cmd_color "${@:2}" ;;
    image)    cmd_image "${@:2}" ;;
    pin)      cmd_pin "${@:2}" ;;
    unpin)    cmd_unpin "${@:2}" ;;
    sever|down)  cmd_down ;;
    regenerate|tidy)  cmd_tidy ;;
    setup)    cmd_setup ;;
    store-secret) cmd_store_secret "${@:2}" ;;
    start)    cmd_start "${@:2}" ;;
    focus)    cmd_focus "${@:2}" ;;
    cortex-resume) cmd_cortex_resume "${@:2}" ;;
    nanoprobes|np)  cmd_nanoprobes "${@:2}" ;;
    nanoprobe-log)  cmd_nanoprobe_log "${@:2}" ;;
    spend)          cmd_spend "${@:2}" ;;
    reap)           cmd_reap "${@:2}" ;;
    reap-worktrees) cmd_reap_worktrees "${@:2}" ;;
    doctor)         cmd_doctor "${@:2}" ;;
    program)        cmd_program "${@:2}" ;;
    vinculum|vinc)  cmd_vinculum "${@:2}" ;;
    version|--version|-V) cmd_version ;;
    help|--help|-h) cmd_help ;;
    # Removed 2026-08-10: ls/status/hail/brief/briefing/refresh were aliases for `link`. Six names
    # for one command meant the docs, the skills, and the research all disagreed about what to call
    # it. Point the muscle memory at the real name rather than failing bare.
    ls|status|hail|brief)
        die "'borg ${1}' was removed — it was an alias for 'link'. Run: borg link" ;;
    briefing) die "'borg briefing' was removed. Run: borg link --brief" ;;
    refresh)  die "'borg refresh' was removed. Run: borg link --refresh" ;;
    *)        die "unknown command '${1}'. Run: borg help" ;;
esac
