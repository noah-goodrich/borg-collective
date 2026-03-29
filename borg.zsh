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

set -e

# Ensure standard PATH is available in non-interactive zsh (e.g., when invoked as `zsh borg.zsh`)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

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

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_ls() {
    local porcelain=0
    [[ "${1:-}" == "--porcelain" ]] && porcelain=1

    # Merge Desktop sessions into registry before listing
    borg_desktop_scan 2>/dev/null || true

    local projects
    projects=$(borg_registry_list)

    if [[ -z "$projects" ]]; then
        info "No projects registered. Run: borg scan"
        return 0
    fi

    if (( porcelain )); then
        # Machine-readable: name\tsource\tstatus\tlast_activity\tsummary
        local name entry source status last summary
        while IFS= read -r name; do
            entry=$(borg_registry_get "$name")
            source=$(echo "$entry" | jq -r '.source // "cli"')
            status=$(echo "$entry" | jq -r '.status // "unknown"')
            last=$(echo "$entry"   | jq -r '.last_activity // ""')
            summary=$(echo "$entry"| jq -r '.summary // ""')
            summary="${summary:0:80}"
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$source" "$status" "$last" "$summary"
        done < <(echo "$projects")
        return 0
    fi

    # Human-readable table
    echo -e "\n${BOLD}The Borg Collective${NC} — ${DIM}resistance is futile${NC}\n"
    printf "${BOLD}%-20s %-4s %-10s %-20s %s${NC}\n" "PROJECT" "SRC" "STATUS" "LAST ACTIVE" "SUMMARY"
    printf '%0.s─' {1..90}; echo

    local name entry source status last summary display status_color src_badge summary_short last_display
    while IFS= read -r name; do
        entry=$(borg_registry_get "$name")
        source=$(echo "$entry"  | jq -r '.source // "cli"')
        status=$(echo "$entry"  | jq -r '.status // "unknown"')
        last=$(echo "$entry"    | jq -r '.last_activity // ""')
        summary=$(echo "$entry" | jq -r '.summary // "(no summary)"')
        display=$(echo "$entry" | jq -r 'if .display_name and .display_name != "" then .display_name else "" end')
        [[ -z "$display" ]] && display="$name"

        case "$status" in
            active)  status_color="$GREEN" ;;
            waiting) status_color="$YELLOW" ;;
            idle)    status_color="$DIM" ;;
            *)       status_color="$NC" ;;
        esac

        case "$source" in
            desktop) src_badge="[D]" ;;
            *)       src_badge="[C]" ;;
        esac

        summary_short="${summary:0:50}"
        [[ ${#summary} -gt 50 ]] && summary_short="${summary_short}..."

        last_display="never"
        if [[ -n "$last" ]]; then
            last_display="${last/T/ }"
            last_display="${last_display/Z/}"
        fi

        printf "%-20s %-4s ${status_color}%-10s${NC} %-20s %s\n" \
            "$display" "$src_badge" "$status" "$last_display" "$summary_short"
    done < <(echo "$projects")
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

    local source path status last summary session_id tmux_window
    source=$(echo "$entry"     | jq -r '.source // "cli"')
    path=$(echo "$entry"       | jq -r '.path // "null"')
    status=$(echo "$entry"     | jq -r '.status // "unknown"')
    last=$(echo "$entry"       | jq -r '.last_activity // "(never)"')
    summary=$(echo "$entry"    | jq -r '.summary // "(no summary — run: borg refresh)"')
    session_id=$(echo "$entry" | jq -r '.claude_session_id // "(unknown)"')
    tmux_window=$(echo "$entry"| jq -r '.tmux_window // "(none)"')

    echo -e "\n${BOLD}${project}${NC}"
    printf '%0.s─' {1..40}; echo
    echo -e "  ${DIM}Source:${NC}       $source"
    [[ "$path" != "null" ]] && echo -e "  ${DIM}Path:${NC}         $path"
    echo -e "  ${DIM}Status:${NC}       $status"
    echo -e "  ${DIM}Last active:${NC}  $last"
    echo -e "  ${DIM}tmux window:${NC}  $tmux_window"
    echo -e "  ${DIM}Session ID:${NC}   $session_id"
    echo
    echo -e "  ${BOLD}Summary${NC}"
    echo -e "  $summary" | fold -s -w 70 | sed '2~1s/^/  /'
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
_borg_do_switch() {
    local project="$1"
    local entry
    entry=$(borg_registry_get "$project")
    local tmux_window source
    tmux_window=$(echo "$entry" | jq -r '.tmux_window // ""')
    source=$(echo "$entry" | jq -r '.source // "cli"')

    if [[ -n "$tmux_window" && "$tmux_window" != "null" ]]; then
        info "Switching to $project ($tmux_window)"
        borg_tmux_switch "$tmux_window"
    elif [[ "$source" == "desktop" ]]; then
        info "$project is a Desktop session — open Claude Desktop to continue"
        cmd_status "$project"
    else
        warn "No tmux window registered for $project"
        cmd_status "$project"
    fi
}

cmd_scan() {
    info "Scanning Claude session history..."

    local new_projects=()
    local path name tmux_window session_id json

    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        name="${path##*/}"

        if borg_registry_has "$name"; then
            dbg "already registered: $name"
            continue
        fi

        # Detect matching tmux window
        tmux_window=""
        borg_tmux_window_exists "$name" && tmux_window="$name" || true

        session_id=$(borg_claude_latest_session_id "$path") || session_id=""

        local tw_json sid_json
        [[ -n "$tmux_window" ]] && tw_json="\"$tmux_window\"" || tw_json="null"
        [[ -n "$session_id" ]] && sid_json="\"$session_id\"" || sid_json="null"

        json=$(jq -n \
            --arg path "$path" \
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
        info "Registered: $name ($path)"
        new_projects+=("$name")
    done < <(borg_claude_scan_session_log)

    # Also scan Desktop session reports
    borg_desktop_scan 2>/dev/null || true

    if (( ${#new_projects[@]} == 0 )); then
        info "No new projects found (already up to date)"
    fi
}

cmd_add() {
    local path="${1:-$PWD}"
    path=$(realpath "$path" 2>/dev/null || echo "$path")
    local name
    name="${path##*/}"

    local tmux_window=""
    borg_tmux_window_exists "$name" && tmux_window="$name"

    local session_id
    session_id=$(borg_claude_latest_session_id "$path")

    local json
    json=$(jq -n \
        --arg path "$path" \
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
    local target="${1:-}"
    local projects

    if [[ "$target" == "--all" || -z "$target" ]]; then
        projects=$(borg_registry_list)
    else
        projects="$target"
    fi

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local entry path session_id jsonl
        entry=$(borg_registry_get "$name")
        path=$(echo "$entry" | jq -r '.path // ""')
        session_id=$(echo "$entry" | jq -r '.claude_session_id // ""')

        if [[ -z "$path" || "$path" == "null" ]]; then
            warn "$name: no path (Desktop session?), skipping"
            continue
        fi

        # Use recorded session ID, or discover latest
        if [[ -z "$session_id" || "$session_id" == "null" ]]; then
            session_id=$(borg_claude_latest_session_id "$path")
        fi

        if [[ -z "$session_id" ]]; then
            warn "$name: no transcript found at $path"
            continue
        fi

        jsonl=$(borg_claude_session_jsonl "$path" "$session_id")
        if [[ ! -f "$jsonl" ]]; then
            warn "$name: transcript not found: $jsonl"
            continue
        fi

        local summary
        summary=$(python3 "$BORG_ROOT/summarize.py" "$jsonl" 2>/dev/null) || summary="(summarizer error)"

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

cmd_help() {
    cat <<'EOF'

  borg — The Borg Collective

  Your sessions will be assimilated.

  COMMANDS
    ls                  List all tracked projects (status, last active, summary)
    switch [query]      fzf picker → jump to project tmux window
    status [project]    Detailed status for one project (defaults to current dir)
    scan                Auto-discover projects from Claude session history
    add [path]          Register a project (defaults to current directory)
    rm <project>        Unregister a project
    refresh [project]   Regenerate summary from latest transcript (omit for all)
    focus [project]     Alias for: switch <project>
    help                Show this message

  ENVIRONMENT
    BORG_TMUX_SESSION   tmux session name to use (default: dev)
    BORG_DEBUG          Set to any value to enable debug output

  CONFIG
    ~/.config/borg/registry.json    Session registry
    ~/.config/borg/desktop/         Claude Desktop session reports

  HOOKS (wire into ~/.claude/settings.json)
    hooks/borg-stop.sh      Stop event: updates status + generates summary
    hooks/borg-notify.sh    Notification event: updates status + macOS alert

EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

borg_registry_init

case "${1:-help}" in
    ls)       cmd_ls "${@:2}" ;;
    switch)   cmd_switch "${@:2}" ;;
    status)   cmd_status "${@:2}" ;;
    scan)     cmd_scan ;;
    add)      cmd_add "${@:2}" ;;
    rm)       cmd_rm "${@:2}" ;;
    refresh)  cmd_refresh "${@:2}" ;;
    focus)    cmd_focus "${@:2}" ;;
    help|--help|-h) cmd_help ;;
    *)        die "unknown command '${1}'. Run: borg help" ;;
esac
