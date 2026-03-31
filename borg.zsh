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
#   borg refresh [project]    # regenerate summary from latest transcript
#   borg focus [project]      # alias for: borg switch <project>

# Set a known-good PATH from scratch. Non-interactive zsh scripts invoked via shebang
# do not source /etc/zprofile or ~/.zshrc, so PATH can be empty or incomplete.
# We set it explicitly rather than appending to an unknown base.
PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
hash -r 2>/dev/null || true

set -e

BORG_ROOT="${0:A:h}"  # directory containing this script
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"

# Colors (same as dev.sh)
GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'  CYAN='\033[0;36m'
BOLD='\033[1m'  DIM='\033[2m'  NC='\033[0m'
info()  { echo -e "${GREEN}▸${NC} $*"; }
warn()  { echo -e "${YELLOW}▸${NC} $*"; }
die()   { echo -e "${RED}▸ ERROR:${NC} $*" >&2; exit 1; }
dbg()   { [[ -n "${BORG_DEBUG:-}" ]] && echo -e "${CYAN}  [dbg]${NC} $*" >&2 || true; }

# Source library modules
for _lib in "$BORG_ROOT/lib"/*.zsh; do
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
    echo -e "\n${BOLD}The Borg Collective${NC} — ${DIM}resistance is futile${NC}\n"
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
    summary=$(echo "$entry"    | jq -r '.summary // "(no summary — run: borg refresh)"')
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
                    cairn_brief=$(timeout 3 cairn search "$project" --project "$project" --max 1 2>/dev/null) || true
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

cmd_scan() {
    info "Scanning Claude session history..."

    local new_projects=()
    local ppath name tmux_window session_id json

    while IFS= read -r ppath; do
        [[ -z "$ppath" ]] && continue
        name="${ppath##*/}"

        if borg_registry_has "$name"; then
            dbg "already registered: $name"
            continue
        fi

        # Detect matching tmux window
        tmux_window=""
        borg_tmux_window_exists "$name" && tmux_window="$name" || true

        session_id=$(borg_claude_latest_session_id "$ppath") || session_id=""

        local tw_json sid_json
        [[ -n "$tmux_window" ]] && tw_json="\"$tmux_window\"" || tw_json="null"
        [[ -n "$session_id" ]] && sid_json="\"$session_id\"" || sid_json="null"

        json=$(jq -n \
            --arg path "$ppath" \
            --arg source "cli" \
            --arg tmux_session "$BORG_TMUX_SESSION" \
            --argjson tmux_window "$tw_json" \
            --argjson session_id "$sid_json" \
            '{
                path: $path,
                source: $source,
                tmux_session: $tmux_session,
                tmux_window: $tmux_window,
                claude_session_id: $session_id,
                last_activity: null,
                status: "idle",
                summary: null
            }')

        borg_registry_merge "$name" "$json"
        info "Registered: $name ($ppath)"
        new_projects+=("$name")
    done < <(borg_claude_scan_session_log)

    # Also scan Desktop session reports
    borg_desktop_scan 2>/dev/null || true

    if (( ${#new_projects[@]} == 0 )); then
        info "No new projects found (already up to date)"
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

    local json
    json=$(jq -n \
        --arg path "$ppath" \
        --arg source "cli" \
        --arg tmux_session "$BORG_TMUX_SESSION" \
        --argjson tmux_window "$([ -n "$tmux_window" ] && echo "\"$tmux_window\"" || echo 'null')" \
        --argjson session_id "$([ -n "$session_id" ] && echo "\"$session_id\"" || echo 'null')" \
        '{
            path: $path,
            source: $source,
            tmux_session: $tmux_session,
            tmux_window: $tmux_window,
            claude_session_id: $session_id,
            last_activity: null,
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
    local target="" use_llm=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) target="--all"; shift ;;
            --llm) use_llm=1; shift ;;
            *) target="$1"; shift ;;
        esac
    done

    local projects
    if [[ "$target" == "--all" || -z "$target" ]]; then
        projects=$(borg_registry_list)
    else
        projects="$target"
    fi

    local llm_flag=""
    (( use_llm )) && llm_flag="--llm"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local entry ppath session_id jsonl
        entry=$(borg_registry_get "$name")
        ppath=$(echo "$entry" | jq -r '.path // ""')
        session_id=$(echo "$entry" | jq -r '.claude_session_id // ""')

        if [[ -z "$ppath" || "$ppath" == "null" ]]; then
            warn "$name: no path (Desktop session?), skipping"
            continue
        fi

        # Use recorded session ID, or discover latest
        if [[ -z "$session_id" || "$session_id" == "null" ]]; then
            session_id=$(borg_claude_latest_session_id "$ppath")
        fi

        if [[ -z "$session_id" ]]; then
            warn "$name: no transcript found at $ppath"
            continue
        fi

        jsonl=$(borg_claude_session_jsonl "$ppath" "$session_id")
        if [[ ! -f "$jsonl" ]]; then
            warn "$name: transcript not found: $jsonl"
            continue
        fi

        local summary
        summary=$(python3 "$BORG_ROOT/summarize.py" $llm_flag "$jsonl" 2>/dev/null) || summary="(summarizer error)"

        if [[ -n "$summary" ]]; then
            borg_registry_read | jq \
                --arg p "$name" \
                --arg s "$summary" \
                --arg sid "$session_id" \
                '.projects[$p].summary = $s | .projects[$p].claude_session_id = $sid' \
                | _borg_registry_write
            info "$name: summary updated"
        fi
    done < <(echo "$projects")
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
        echo -e "\n${GREEN}▸${NC} All clear. Take a break.\n"
        return 0
    fi

    local name proj_status summary waiting_reason last pinned
    name=$(echo "$top" | jq -r '.name')
    proj_status=$(echo "$top" | jq -r '.status')
    summary=$(echo "$top" | jq -r '.summary')
    waiting_reason=$(echo "$top" | jq -r '.waiting_reason')
    last=$(echo "$top" | jq -r '.last_activity')
    pinned=$(echo "$top" | jq -r '.pinned')

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

    if (( do_switch )); then
        _borg_do_switch "$name" --silent
    fi
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

cmd_brief() {
    local project="${1:-}"
    [[ -z "$project" ]] && project="${PWD##*/}"

    if command -v cairn &>/dev/null; then
        info "Querying cairn for $project..."
        timeout 5 cairn search "$project" --project "$project" --max 5 2>/dev/null || {
            warn "cairn search timed out or failed"
            cmd_status "$project"
        }
    else
        cmd_status "$project"
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
        cairn_out=$(timeout 5 cairn search "current work priorities" --max 3 2>/dev/null || true)
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
        tmux new-session -d -s "$BORG_TMUX_SESSION"
    fi

    # Merge Desktop sessions before building briefing
    borg_desktop_scan 2>/dev/null || true

    info "Building morning briefing..."
    local context
    context=$(_borg_orchestrator_context)

    local prompt
    prompt="You are the Borg orchestrator for this developer's work session.

== CURRENT STATE ==
$context
== END STATE ==

Start with a concise morning briefing:
1. Flag anything waiting for input first — these are urgent
2. Summarize what's in progress
3. Give ONE recommendation: what to work on first and why

Then ask if they want to switch to it. Keep the briefing under 10 lines."

    info "Launching orchestrator — resume any time with: borg claude"
    _borg_launch_in_tmux claude --name "borg-orchestrator" --append-system-prompt "$prompt"
}

cmd_claude() {
    # Resume the most recent orchestrator session from BORG_ROOT
    info "Resuming orchestrator..."
    _borg_launch_in_tmux claude --continue
}

# Launch a command inside the borg tmux session.
# If already in tmux, exec directly. Otherwise, send to pane 0 of the first
# window and attach.
_borg_launch_in_tmux() {
    if [[ -n "${TMUX:-}" ]]; then
        cd "$BORG_ROOT"
        exec "$@"
    fi

    local target_pane
    target_pane=$(tmux list-panes -t "$BORG_TMUX_SESSION:{start}" -F '#{pane_id}' | head -1)
    tmux send-keys -t "$target_pane" "cd $BORG_ROOT && $*" Enter
    exec tmux attach-session -t "$BORG_TMUX_SESSION"
}

cmd_help() {
    cat <<'EOF'

  borg — The Borg Collective

  Your sessions will be assimilated.

  COMMANDS
    init                Launch orchestrator: morning briefing + Claude session
    claude              Resume orchestrator session (continue most recent)
    next [--switch]     What needs your attention? (--switch jumps there)
    ls [--all]          Dashboard: all projects sorted by urgency
    switch [query]      fzf picker → jump to project tmux window
    status [project]    Detailed status (defaults to current directory)
    brief [project]     Project briefing from cairn (defaults to current dir)
    search <query>      Search cairn knowledge graph (--project to filter)
    scan                Auto-discover projects from session history
    add [path]          Register a project (defaults to $PWD)
    rm <project>        Unregister a project
    pin [project]       Mark as priority (sorts first, preferred by next)
    unpin [project]     Remove priority flag
    refresh [--all]     Regenerate summaries (--llm for AI-powered)
    tidy                Archive stale projects (idle >48h)
    focus [project]     Alias for: switch <project>
    help                Show this message

  HOTKEY
    Ctrl+Space >        Jump to most pressing project (runs: borg next --switch)

  STATUS
    active              Claude is processing (green)
    waiting <<<         Claude finished, needs your input (yellow)
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

  SKILLS
    /adhd-guardrails        Compassionate constraints (always active)
    /checkpoint-enhanced    Session summary + next-session entry point

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
    brief)    cmd_brief "${@:2}" ;;
    search)   cmd_search "${@:2}" ;;
    scan)     cmd_scan ;;
    add)      cmd_add "${@:2}" ;;
    rm)       cmd_rm "${@:2}" ;;
    pin)      cmd_pin "${@:2}" ;;
    unpin)    cmd_unpin "${@:2}" ;;
    refresh)  cmd_refresh "${@:2}" ;;
    tidy)     cmd_tidy ;;
    focus)    cmd_focus "${@:2}" ;;
    help|--help|-h) cmd_help ;;
    *)        die "unknown command '${1}'. Run: borg help" ;;
esac
