#!/usr/bin/env zsh
# borg — The Borg Collective: multi-session Claude Code manager
#
# Usage:
#   borg ls                   # list all tracked projects
#   borg switch [query]       # fzf picker → tmux window switch
#   borg status [project]     # detailed status for one project
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

BORG_HOME="${BORG_HOME:-${0:A:h}}"  # directory containing this script (for lib/, hooks/, skills/)
BORG_ROOT="${BORG_ROOT:-$HOME/dev}"  # workspace root where projects live
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
BORG_MAX_ACTIVE="${BORG_MAX_ACTIVE:-3}"
BORG_SESSION_WARN_HOURS="${BORG_SESSION_WARN_HOURS:-2}"
BORG_WORK_HOURS="${BORG_WORK_HOURS:-}"
BORG_WORK_DAYS="${BORG_WORK_DAYS:-}"
BORG_WORK_PROJECTS="${BORG_WORK_PROJECTS:-}"

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
    epoch_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null) || { echo "$ts"; return; }
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

# Count projects with status=waiting or status=active
_borg_active_count() {
    borg_registry_read | jq '[.projects[] | select(.status == "waiting" or .status == "active")] | length'
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

    local registry
    registry=$(borg_registry_read)
    local project_count
    project_count=$(echo "$registry" | jq '.projects | length')

    if (( project_count == 0 )); then
        info "No projects registered. Run: borg scan"
        return 0
    fi

    if (( project_count <= 1 && ! porcelain )); then
        echo -e "  ${DIM}Tip: run 'borg scan' to discover projects from session history${NC}"
    fi

    # Sort by: pinned DESC, status priority (waiting>active>idle>archived), last_activity
    local sorted_names
    sorted_names=$(echo "$registry" | jq -r '
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
        info "No projects to show. Run: borg ls --all"
        return 0
    fi

    if (( porcelain )); then
        local name entry source proj_status last summary
        while IFS= read -r name; do
            entry=$(echo "$registry" | jq -c --arg p "$name" '.projects[$p]')
            source=$(echo "$entry" | jq -r '.source // "cli"')
            proj_status=$(echo "$entry" | jq -r '.status // "unknown"')
            last=$(echo "$entry"   | jq -r '.last_activity // ""')
            summary=$(echo "$entry"| jq -r '.summary // ""')
            summary="${summary:0:80}"
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$source" "$proj_status" "$last" "$summary"
        done <<< "$sorted_names"
        return 0
    fi

    # Human-readable table
    echo ""
    echo -e "  ${DIM}_______________${NC}"
    echo -e "  ${DIM}/|             /|${NC}      ${BOLD}THE BORG COLLECTIVE${NC}"
    echo -e "  ${DIM}/ |            / |${NC}      ${DIM}resistance is futile${NC}"
    echo -e "  ${DIM}  |___________|  |${NC}"
    echo -e "  ${DIM}  |  |        |  |${NC}"
    echo -e "  ${DIM}  |  |________|__|${NC}"
    echo -e "  ${DIM}  | /         | /${NC}"
    echo -e "  ${DIM}  |/          |/${NC}"
    echo ""
    printf "${BOLD} %-20s %-4s %-12s %-12s %s${NC}\n" "PROJECT" "SRC" "STATUS" "LAST ACTIVE" "SUMMARY"
    printf '%0.s─' {1..90}; echo

    local name entry source proj_status last summary display status_color src_badge summary_short last_display pinned pin_mark status_display
    while IFS= read -r name; do
        entry=$(echo "$registry" | jq -c --arg p "$name" '.projects[$p]')
        source=$(echo "$entry"  | jq -r '.source // "cli"')
        proj_status=$(echo "$entry"  | jq -r '.status // "unknown"')
        last=$(echo "$entry"    | jq -r '.last_activity // ""')
        summary=$(echo "$entry" | jq -r '.summary // "(no summary)"')
        pinned=$(echo "$entry"  | jq -r '.pinned // false')
        display=$(echo "$entry" | jq -r 'if .display_name and .display_name != "" then .display_name else "" end')
        [[ -z "$display" ]] && display="$name"

        [[ "$pinned" == "true" ]] && pin_mark="*" || pin_mark=" "

        case "$proj_status" in
            active)  status_color="$GREEN" ;;
            waiting) status_color="$YELLOW" ;;
            idle)    status_color="$DIM" ;;
            *)       status_color="$NC" ;;
        esac

        status_display="$proj_status"
        [[ "$proj_status" == "waiting" ]] && status_display="waiting <<<"

        case "$source" in
            desktop) src_badge="[D]" ;;
            coco)    src_badge="[X]" ;;
            *)       src_badge="[C]" ;;
        esac

        summary_short="${summary:0:50}"
        [[ ${#summary} -gt 50 ]] && summary_short="${summary_short}..."

        last_display=$(_borg_relative_time "$last")

        printf "%s%-20s %-4s ${status_color}%-12s${NC} %-12s %s\n" \
            "$pin_mark" "$display" "$src_badge" "$status_display" "$last_display" "$summary_short"
    done <<< "$sorted_names"

    # Capacity warning
    local active_count
    active_count=$(_borg_active_count)
    if (( active_count > BORG_MAX_ACTIVE )); then
        echo
        warn "${BOLD}$active_count sessions need attention${NC} (limit: $BORG_MAX_ACTIVE)"
    fi
    echo
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
    entry=$(borg_registry_get "$project")

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
            --preview "borg status {1}" \
            --preview-window "right:45:wrap" \
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
    entry=$(borg_registry_get "$project")
    local tmux_window source summary last
    tmux_window=$(echo "$entry" | jq -r '.tmux_window // ""')
    source=$(echo "$entry" | jq -r '.source // "cli"')
    summary=$(echo "$entry" | jq -r '.summary // ""')
    last=$(echo "$entry" | jq -r '.last_activity // ""')

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
                if command -v cairn &>/dev/null; then
                    local cairn_brief
                    cairn_brief=$(_borg_timeout 3 cairn search "$project" --project "$project" --max 1 2>/dev/null) || true
                    [[ -n "$cairn_brief" ]] && echo -e "  ${CYAN}cairn:${NC} $cairn_brief"
                fi
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

        # Skip the workspace root itself (e.g. ~/dev) — not a real project
        if [[ "$ppath" == "$BORG_ROOT" ]]; then
            dbg "skipping workspace root: $ppath"
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
                status: "idle",
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
    # Auto-enable LLM summaries when cairn is unavailable, unless user said --no-llm
    if (( ! llm_explicit && ! use_llm )); then
        if ! command -v cairn &>/dev/null || \
           [[ -z "$(_borg_timeout 3 cairn search "any" --max 1 2>/dev/null)" ]]; then
            dbg "cairn unavailable or empty — auto-enabling LLM summaries"
            use_llm=1
        fi
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

cmd_add() {
    local ppath="${1:-$PWD}"
    ppath=$(realpath "$ppath" 2>/dev/null || echo "$ppath")
    local name
    name="${ppath##*/}"

    local tmux_window=""
    borg_tmux_window_exists "$name" && tmux_window="$name"

    local session_id
    session_id=$(borg_claude_latest_session_id "$ppath")

    # Seed last_activity from transcript mtime if a session exists
    local last_activity="null"
    if [[ -n "$session_id" ]]; then
        local jsonl
        jsonl=$(borg_claude_session_jsonl "$ppath" "$session_id")
        if [[ -f "$jsonl" ]]; then
            local mtime
            mtime=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$jsonl" 2>/dev/null) || mtime=""
            [[ -n "$mtime" ]] && last_activity="\"$mtime\""
        fi
    fi

    local json
    json=$(jq -n \
        --arg path "$ppath" \
        --arg source "cli" \
        --arg tmux_session "$BORG_TMUX_SESSION" \
        --argjson tmux_window "$([ -n "$tmux_window" ] && echo "\"$tmux_window\"" || echo 'null')" \
        --argjson session_id "$([ -n "$session_id" ] && echo "\"$session_id\"" || echo 'null')" \
        --argjson last_activity "$last_activity" \
        '{
            path: $path,
            source: $source,
            tmux_session: $tmux_session,
            tmux_window: $tmux_window,
            claude_session_id: $session_id,
            last_activity: $last_activity,
            status: "idle",
            summary: null
        }')

    borg_registry_merge "$name" "$json"
    info "Registered: $name"
    [[ -n "$session_id" ]] && info "Latest session: $session_id"
}

cmd_rm() {
    local project="${1:-}"
    [[ -z "$project" ]] && die "usage: borg rm <project>"
    borg_registry_has "$project" || die "project '$project' not in registry"
    borg_registry_remove "$project"
    info "Removed: $project"
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
    registry=$(borg_registry_read)

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
            pinned: (.value.pinned // false)
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

    local name proj_status summary waiting_reason last pinned
    name=$(echo "$top" | jq -r '.name')
    proj_status=$(echo "$top" | jq -r '.status')
    summary=$(echo "$top" | jq -r '.summary')
    waiting_reason=$(echo "$top" | jq -r '.waiting_reason')
    last=$(echo "$top" | jq -r '.last_activity')
    pinned=$(echo "$top" | jq -r '.pinned')

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

cmd_down() {
    info "Severing link to the Collective..."

    if ! borg_tmux_alive; then
        info "No borg tmux session running."
        return 0
    fi

    local windows
    windows=(${(f)"$(tmux list-windows -t "$BORG_TMUX_SESSION" -F '#W' 2>/dev/null)"})

    for wname in $windows; do
        [[ "$wname" == "orchestrator" || "$wname" == "host" ]] && continue
        local pdir
        pdir=$(tmux show-option -t "$BORG_TMUX_SESSION:$wname" -v @project_dir 2>/dev/null) || true
        if [[ -n "$pdir" ]]; then
            info "Stopping $wname..."
            drone down "$wname" 2>/dev/null || tmux kill-window -t "$BORG_TMUX_SESSION:$wname" 2>/dev/null || true
        else
            tmux kill-window -t "$BORG_TMUX_SESSION:$wname" 2>/dev/null || true
        fi
    done

    # Stop shared postgres
    local postgres_compose="$HOME/.config/dotfiles/devcontainer/docker-compose.postgres.yml"
    [[ -f "$postgres_compose" ]] && docker compose -f "$postgres_compose" down 2>/dev/null || true

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

        epoch_last=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last" +%s 2>/dev/null) || continue
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

cmd_hail() {
    local project="${1:-}"

    # No arg → full briefing across all projects (same as borg init shows)
    if [[ -z "$project" ]]; then
        _borg_print_briefing
        return
    fi

    # Specific project → detailed status + cairn knowledge
    cmd_status "$project"
    if command -v cairn &>/dev/null; then
        echo ""
        info "Cairn knowledge for $project:"
        _borg_timeout 5 cairn search "$project" --project "$project" --max 5 2>/dev/null || {
            warn "cairn search timed out or failed"
        }
    fi
}

cmd_search() {
    local query="" project=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --project|-p) project="$2"; shift 2 ;;
            *) query="${query:+$query }$1"; shift ;;
        esac
    done
    [[ -z "$query" ]] && die "usage: borg search <query> [--project <name>]"
    if ! command -v cairn &>/dev/null; then
        die "cairn not installed — see docs/quickstart.md for setup"
    fi
    if [[ -n "$project" ]]; then
        cairn search "$query" --project "$project"
    else
        cairn search "$query"
    fi
}

# Build orchestrator context string from registry + debriefs + cairn.
# Output goes to stdout; caller captures it.
_borg_print_briefing() {
    # Suppress xtrace — trace output pollutes the briefing when PS4 is empty.
    setopt LOCAL_OPTIONS
    set +x

    local registry cutoff active_names inactive_names payload name
    local proj_status last_activity summary waiting_reason rel_time
    local debrief_file briefing_prompt briefing fallback_text fields

    registry=$(borg_registry_read)

    cutoff=$(date -u -v-30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ")

    # Active: status=waiting (any age) OR last_activity within 30 days AND not archived
    # Sort: waiting first (oldest first = longest neglected), then by last_activity descending
    active_names=$(echo "$registry" | jq -r --arg cutoff "$cutoff" '
        (
            [.projects | to_entries[] |
             select(.value.status == "waiting" and .value.status != "archived")] |
            sort_by(.value.last_activity // "0000")
        ) + (
            [.projects | to_entries[] |
             select(.value.status != "waiting" and .value.status != "archived" and
                    (.value.last_activity != null and .value.last_activity >= $cutoff))] |
            sort_by(.value.last_activity // "0000") | reverse
        ) | .[].key
    ' 2>/dev/null || true)

    # Inactive: not archived, last_activity older than 30 days (or null), not waiting
    inactive_names=$(echo "$registry" | jq -r --arg cutoff "$cutoff" '
        .projects | to_entries |
        map(select(
            .value.status != "archived" and
            .value.status != "waiting" and
            (.value.last_activity == null or .value.last_activity < $cutoff)
        )) |
        sort_by(.value.last_activity // "0000") | reverse |
        .[].key
    ' 2>/dev/null || true)

    if [[ -z "$active_names" && -z "$inactive_names" ]]; then
        info "No projects in registry. Run: borg scan"
        return 0
    fi

    # Build LLM payload + fallback text in one pass (1 jq call per project)
    payload=""
    fallback_text=""
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        IFS=$'\t' read -r proj_status last_activity summary waiting_reason <<< \
            "$(echo "$registry" | jq -r --arg p "$name" \
                '.projects[$p] | [.status // "unknown", .last_activity // "", .summary // "", .waiting_reason // ""] | join("\t")')"
        rel_time=$(_borg_relative_time "$last_activity")

        payload+="PROJECT: $name
status: $proj_status
last_active: $rel_time
summary: $summary"
        [[ -n "$waiting_reason" && "$waiting_reason" != "null" ]] && \
            payload+="
waiting_reason: $waiting_reason"

        debrief_file="$BORG_DIR/debriefs/${name}.md"
        if [[ -f "$debrief_file" ]]; then
            payload+="
--- debrief ---
$(head -c 1500 "$debrief_file")
--- end debrief ---"
        fi
        payload+="

"

        # Pre-build fallback so we don't re-parse on failure
        fallback_text+="$(printf "  %-22s [%s, %s]\n" "$name" "$proj_status" "$rel_time")"
        if [[ -n "$summary" && "$summary" != "null" && "$summary" != "(no summary)" ]]; then
            fallback_text+=$'\n'"$(echo "    $summary" | fold -s -w 76 | sed '1!s/^/    /')"
        fi
        fallback_text+=$'\n'
    done <<< "$active_names"

    briefing_prompt="Generate a morning briefing for a developer. Output plain text for a terminal — no markdown, no headers, no bullet symbols.

For each project write exactly these lines (omit Blocked line if not waiting):
  <name>  [<status>, <relative_time>]
    Last: <one sentence — what was accomplished. Use debrief Outcome if available, else summary>
    Next: <one sentence — most important next action. Use debrief Next Steps #1 if available>
    Blocked: <waiting_reason>  ← only if status is waiting

After all projects, add one blank line then:
  Focus: <project_name> — <one sentence why it needs attention first>

Sort: waiting projects first, then by most recent activity. Keep each line under 80 chars.

PROJECTS:
$payload"

    echo ""
    info "Building morning briefing..."

    local claude_rc=0
    briefing=$(_borg_timeout 20 claude -p "$briefing_prompt" \
        --model claude-haiku-4-5-20251001 --no-session-persistence --bare 2>/dev/null) || claude_rc=$?

    # Gate on exit code; also catch the edge case where claude exits 0 with an auth error
    if [[ $claude_rc -ne 0 || "$briefing" == *"Not logged in"* ]]; then
        briefing=""
    fi

    if [[ -n "$briefing" ]]; then
        echo ""
        echo "$briefing"
    else
        echo ""
        printf "%s" "$fallback_text"
    fi

    # Inactive list (compact, single jq call)
    if [[ -n "$inactive_names" ]]; then
        echo ""
        echo -e "  ${DIM}Inactive (>30 days):${NC}"
        echo "$registry" | jq -r --arg cutoff "$cutoff" '
            .projects | to_entries |
            map(select(
                .value.status != "archived" and
                .value.status != "waiting" and
                (.value.last_activity == null or .value.last_activity < $cutoff)
            )) |
            sort_by(.value.last_activity // "0000") | reverse |
            .[] | [.key, .value.last_activity // ""] | join("\t")
        ' 2>/dev/null | while IFS=$'\t' read -r name last_activity; do
            rel_time=$(_borg_relative_time "$last_activity")
            echo -e "    ${DIM}$name  ($rel_time)${NC}"
        done
        echo -e "  ${DIM}Run 'borg hail <name>' for details.${NC}"
    fi
    echo ""
}

_borg_orchestrator_context() {
    local registry
    registry=$(borg_registry_read)
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

    # Most recent debriefs for top 3 priority projects
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

    local any_debrief=0
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local df="$BORG_DIR/debriefs/${name}.md"
        [[ -f "$df" ]] || continue
        if (( ! any_debrief )); then
            echo "Recent session debriefs:"
            any_debrief=1
        fi
        echo ""
        echo "=== $name ==="
        head -c 1500 "$df"
        echo ""
    done <<< "$top3"

    # Cairn cross-project knowledge (optional)
    if command -v cairn &>/dev/null; then
        local cairn_out
        cairn_out=$(_borg_timeout 5 cairn search "current work priorities" --max 3 2>/dev/null || true)
        if [[ -n "$cairn_out" ]]; then
            echo ""
            echo "Cairn knowledge:"
            echo "$cairn_out"
        fi
    fi
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

    # Print formatted briefing to terminal before launching orchestrator
    _borg_print_briefing

    local context
    context=$(_borg_orchestrator_context)

    local prompt
    prompt="We are the Borg. You are the orchestrator for this developer's work session.

== CURRENT STATE ==
$context
== END STATE ==

The developer has already seen the morning hail in their terminal.
Be ready to answer questions about any project, help them switch focus, or dive into work.
If they say 'go' or 'start' or 'engage', switch to the top-priority project."

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
        ( cd "$BORG_HOME" && "$@" )
        [[ -n "$cleanup_file" ]] && rm -f "$cleanup_file"
        return
    fi

    # Write a launcher script so tmux send-keys only types one short command
    local launcher="${TMPDIR:-/tmp}/borg-launch.$$.zsh"
    {
        echo '#!/usr/bin/env zsh'
        echo "cd ${(q)BORG_HOME}"
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
        .hooks[$evt] |= map(select(.hooks | all(.command != $cmd)))
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
    mkdir -p "$BORG_DIR/desktop" "$BORG_DIR/debriefs"
    mkdir -p "$CLAUDE_DIR" "$CLAUDE_HOOKS_DIR" "$CLAUDE_SKILLS_DIR"
    borg_registry_init

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

    # ── 3. Register hooks in settings.json ────────────────────────────────────
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        info "Registering hooks in Claude Code settings.json..."
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-start.sh"        "SessionStart" "borg-start.sh"
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-stop.sh"         "Stop"         "borg-stop.sh"
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/notify.sh"             "Notification"  "notify.sh"
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-notify.sh"       "Notification"  "borg-notify.sh"
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/pre-commit-remind.sh" "PreToolUse"   "pre-commit-remind.sh"
        _borg_register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/tool-count-nudge.sh" "PostToolUse"  "tool-count-nudge.sh"

        # Migration: remove old session-start.sh (merged into borg-start.sh)
        _borg_unregister_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/session-start.sh" "SessionStart" "session-start.sh"
        [[ -e "$CLAUDE_HOOKS_DIR/session-start.sh" ]] && rm "$CLAUDE_HOOKS_DIR/session-start.sh" \
            && info "  Removed old session-start.sh"
    else
        warn "No settings.json at $CLAUDE_SETTINGS"
        warn "Hooks installed but not registered. See README.md for manual registration."
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
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-start.sh"        "SessionStart" "borg-start.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-stop.sh"         "Stop"         "borg-stop.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/notify.sh"             "Notification"  "notify.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-notify.sh"       "Notification"  "borg-notify.sh"
        _borg_register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/pre-commit-remind.sh" "PreToolUse"   "pre-commit-remind.sh"

        info "Registering skills with CoCo..."
        for skill_dir in "$BORG_HOME/skills/"*/(N); do
            [[ -d "$skill_dir" ]] || continue
            local name="${skill_dir:t}"
            cortex skill add "$skill_dir" 2>/dev/null && info "  $name (cortex)" || warn "  $name: cortex skill add failed"
        done
    else
        info "Cortex Code CLI not found — skipping CoCo integration"
    fi

    # ── 4. Install skills ─────────────────────────────────────────────────────
    info "Installing skills..."

    # Clean up stale skills (removed from source)
    for existing in "$CLAUDE_SKILLS_DIR/"*/(N); do
        [[ -d "$existing" ]] || continue
        local ename="${existing:t}"
        [[ ! -d "$BORG_HOME/skills/$ename" ]] && rm -rf "$existing" && info "  Removed stale skill: $ename"
    done

    for skill_dir in "$BORG_HOME/skills/"*/(N); do
        [[ -d "$skill_dir" ]] || continue
        local name="${skill_dir:t}"
        local target="$CLAUDE_SKILLS_DIR/$name"

        # Copy (not symlink) so skills work inside devcontainers
        rm -rf "$target"
        cp -R "$skill_dir" "$target"
        info "  $name"
    done

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
    next [--switch]     What needs your attention? (--switch jumps there)
    ls [--all]          Dashboard: all projects sorted by urgency
    switch [query]      fzf picker → jump to project tmux window
    status [project]    Detailed status (defaults to current directory)
    hail [project]      Morning briefing (no arg) or project detail (with arg)
    search <query>      Search cairn knowledge graph (--project to filter)
    scan                Discover projects + refresh summaries
    add [path]          Register a project (defaults to $PWD)
    rm <project>        Unregister a project
    pin [project]       Mark as priority (sorts first, preferred by next)
    unpin [project]     Remove priority flag
    sever               Tear down everything: containers, windows, session
    regenerate          Archive stale projects (idle >48h)
    setup               Register Claude Code hooks, skills, and config
    help                Show this message

  HOTKEY
    Ctrl+Space >        Jump to most pressing project (runs: borg next --switch)

  SKILLS (use in Claude Code sessions)
    /borg-plan          Project planning (Claude proposes, you validate)
    /borg-review        Mid-session diagnostic + loop detection
    /borg-assimilate    Shipping checklist + execution (merge PR, archive plan)
    /borg-checkpoint    Manual session checkpoint with next-session entry point
    /borg-hail          Same as 'borg hail' — morning briefing or project detail
    /borg-ls            Same as 'borg ls' — project dashboard
    /borg-next          Same as 'borg next' — what needs attention
    /borg-status        Same as 'borg status' — single project detail
    /borg-switch        Same as 'borg switch' — jump to project
    /borg-search        Same as 'borg search' — search cairn knowledge
    /borg-refresh       Same as 'borg refresh' — regenerate summaries
    /adhd-guardrails    Compassionate constraints (always active)

  STATUS
    active              Drone is processing (green)
    waiting <<<         Drone needs your input (yellow)
    idle                Session ended (dim)
    archived            Hidden from default ls (shown with --all)

  CONFIG
    ~/.config/borg/config.zsh       Work/life boundaries, limits
    ~/.config/borg/registry.json    Session registry
    ~/.config/borg/debriefs/        Session debriefs (auto-generated)

  ENVIRONMENT
    BORG_TMUX_SESSION       tmux session name (default: borg)
    BORG_MAX_ACTIVE         Capacity warning threshold (default: 3)
    BORG_WORK_HOURS         e.g. "09:00-18:00" (empty to disable)
    BORG_WORK_PROJECTS      Comma-separated work project names
    BORG_DEBUG              Set to any value for debug output

  "We are the Borg. Your projects will be assimilated."

EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

borg_registry_init

case "${1:-help}" in
    init)     cmd_init ;;
    claude)   cmd_claude ;;
    next)     cmd_next "${@:2}" ;;
    ls)       cmd_ls "${@:2}" ;;
    switch)   cmd_switch "${@:2}" ;;
    status)   cmd_status "${@:2}" ;;
    hail|brief) cmd_hail "${@:2}" ;;
    search)   cmd_search "${@:2}" ;;
    scan)     cmd_scan "${@:2}" ;;
    add)      cmd_add "${@:2}" ;;
    rm)       cmd_rm "${@:2}" ;;
    pin)      cmd_pin "${@:2}" ;;
    unpin)    cmd_unpin "${@:2}" ;;
    refresh)  cmd_refresh "${@:2}" ;;
    sever|down)  cmd_down ;;
    regenerate|tidy)  cmd_tidy ;;
    setup)    cmd_setup ;;
    focus)    cmd_focus "${@:2}" ;;
    briefing) _borg_print_briefing ;;
    help|--help|-h) cmd_help ;;
    *)        die "unknown command '${1}'. Run: borg help" ;;
esac
