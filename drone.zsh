#!/usr/bin/env zsh
# drone — The Borg Collective: project lifecycle manager
#
# Manages Docker Compose devcontainers, tmux windows, and Claude sessions.
# Forked from dev.sh and integrated with borg orchestration.
#
# Usage:
#   drone up [project]           Start container + create tmux window
#   drone down [project]         Stop container + remove tmux window
#   drone claude [project]       Launch Claude Code in project window
#   drone sh [project]           Shell into project container
#   drone restart [project]      Restart containers + re-exec panes
#   drone fix [project|--all]    Restore standard 3-pane layout
#   drone status                 Show all active drones
#   drone help                   Command reference

set -e

PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
hash -r 2>/dev/null || true

SESSION="${BORG_TMUX_SESSION:-borg}"
COMPOSE_FILE=".devcontainer/docker-compose.yml"
POSTGRES_COMPOSE="$HOME/.config/dotfiles/devcontainer/docker-compose.postgres.yml"
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_ROOT_DIR="${BORG_ROOT_DIR:-$HOME/dev}"

# Colors (same as borg.zsh)
GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'  CYAN='\033[0;36m'
BOLD='\033[1m'  DIM='\033[2m'  NC='\033[0m'
info() { echo -e "${GREEN}▸${NC} $*"; }
warn() { echo -e "${YELLOW}▸${NC} $*"; }
die()  { echo -e "${RED}▸ ERROR:${NC} $*" >&2; exit 1; }
dbg()  { [[ -n "${BORG_DEBUG:-}" ]] && echo -e "${CYAN}  [dbg]${NC} $*" >&2 || true; }

# Source project secrets if present (Docker Compose needs API keys)
[[ -f "$HOME/.config/dotfiles/zsh/secrets.zsh" ]] && source "$HOME/.config/dotfiles/zsh/secrets.zsh" || true

# ── Project resolution ────────────────────────────────────────────────────────

# Resolve a project name/path argument to name + absolute dir.
# Sets: _proj_name, _proj_dir
_drone_resolve() {
    local arg="${1:-}"

    if [[ -z "$arg" ]]; then
        # No argument: use current working directory
        _proj_dir="$(pwd)"
        _proj_name="${_proj_dir##*/}"
        return 0
    fi

    # Argument is an existing path
    if [[ -d "$arg" ]]; then
        _proj_dir="$(cd "$arg" && pwd)"
        _proj_name="${_proj_dir##*/}"
        return 0
    fi

    # Look up in borg registry
    local registry="$BORG_DIR/registry.json"
    if [[ -f "$registry" ]]; then
        local reg_path
        reg_path=$(jq -r --arg p "$arg" '.projects[$p].path // empty' "$registry" 2>/dev/null) || true
        if [[ -n "$reg_path" && -d "$reg_path" ]]; then
            _proj_dir="$reg_path"
            _proj_name="$arg"
            return 0
        fi
    fi

    # Try BORG_ROOT_DIR/<arg>
    if [[ -d "$BORG_ROOT_DIR/$arg" ]]; then
        _proj_dir="$BORG_ROOT_DIR/$arg"
        _proj_name="$arg"
        return 0
    fi

    die "Cannot find project '$arg'. cd to the project dir, or register it with: borg add <path>"
}

# ── Helpers ───────────────────────────────────────────────────────────────────

get_project_container() {
    local dir="${1:-$(pwd)}"
    local name="${dir##*/}"
    docker ps --filter "label=com.docker.compose.project=$name" \
              --filter "label=dev.role=app" \
              --format '{{.Names}}' 2>/dev/null | head -1 \
    || docker compose -p "$name" -f "$dir/$COMPOSE_FILE" ps --format '{{.Names}}' 2>/dev/null | head -1
}

get_service_name() {
    local dir="${1:-$(pwd)}"
    local name="${dir##*/}"
    docker ps --filter "label=com.docker.compose.project=$name" \
              --filter "label=dev.role=app" \
              --format '{{.Label "com.docker.compose.service"}}' 2>/dev/null | head -1
}

get_shell() {
    local c="$1"
    dbg "get_shell: probing shell in container '$c'"
    local s
    s=$(docker exec "$c" sh -c 'command -v zsh || command -v bash' 2>/dev/null) || s="/bin/sh"
    dbg "get_shell: found '$s'"
    echo "$s"
}

has_window() {
    tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$1"
}

window_pane_count() {
    tmux list-panes -t "$SESSION:$1" 2>/dev/null | wc -l | tr -d ' '
}

# Count project windows (all except 'host')
project_window_count() {
    tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -vcx 'host' | tr -d ' '
}

ensure_network() {
    if ! docker network inspect devnet &>/dev/null; then
        dbg "ensure_network: creating devnet"
        docker network create devnet
    fi
}

ensure_postgres() {
    ensure_network
    dbg "ensure_postgres: starting shared postgres"
    docker compose -f "$POSTGRES_COMPOSE" up -d
}

# ── Window management ─────────────────────────────────────────────────────────

create_3pane_window() {
    local wname="$1" cmd="${2:-}"
    dbg "create_3pane_window: '$wname'"

    local main
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        main=$(tmux new-session -d -s "$SESSION" -n "$wname" -PF '#{pane_id}')
    else
        main=$(tmux new-window -t "$SESSION" -n "$wname" -PF '#{pane_id}')
    fi

    local bottom side
    bottom=$(tmux split-window -v -p 25 -t "$main" -PF '#{pane_id}')
    side=$(tmux split-window -h -p 30 -t "$main" -PF '#{pane_id}')

    # Force 70/30 horizontal split on top panes
    local win_width
    win_width=$(tmux display -t "$main" -p '#{window_width}')
    tmux resize-pane -t "$main" -x $(( win_width * 70 / 100 ))

    tmux select-pane -t "$main"

    if [[ -n "$cmd" ]]; then
        tmux send-keys -t "$main"   "$cmd" Enter
        tmux send-keys -t "$side"   "$cmd" Enter
        tmux send-keys -t "$bottom" "$cmd" Enter
    fi

    dbg "create_3pane_window: done (main=$main side=$side bottom=$bottom)"
}

ensure_session() {
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        dbg "ensure_session: creating session with host window"
        create_3pane_window "host"
        return
    fi

    if ! has_window "host"; then
        dbg "ensure_session: host window missing, recreating"
        create_3pane_window "host"
        return
    fi

    local panes
    panes=$(window_pane_count "host")
    if [[ "$panes" != "3" ]]; then
        dbg "ensure_session: host has $panes panes (expected 3), recreating"
        tmux kill-window -t "$SESSION:host"
        create_3pane_window "host"
    fi
}

attach_or_switch() {
    local wname="$1"
    if [[ -n "$TMUX" ]]; then
        dbg "attach_or_switch: selecting window '$wname'"
        tmux select-window -t "$SESSION:$wname"
    else
        dbg "attach_or_switch: attaching to session, window '$wname'"
        tmux select-window -t "$SESSION:$wname"
        exec tmux attach-session -t "$SESSION"
    fi
}

wait_for_container() {
    local dir="$1"
    dbg "wait_for_container: polling (max 30s)..."
    local i=0 max=30
    while (( i < max )); do
        local c
        c=$(get_project_container "$dir")
        if [[ -n "$c" ]]; then
            dbg "wait_for_container: found '$c' after ${i}s"
            echo "$c"
            return 0
        fi
        dbg "wait_for_container: not up yet (${i}s elapsed)"
        sleep 1
        i=$(( i + 1 ))
    done
    die "Timed out waiting for container to start after ${max}s."
}

resend_exec_to_panes() {
    local wname="$1" exec_cmd="$2"
    dbg "resend_exec_to_panes: sending exec to all panes in '$wname'"
    local pane_ids
    pane_ids=(${(f)"$(tmux list-panes -t "$SESSION:$wname" -F '#{pane_id}')"})
    for pid in $pane_ids; do
        tmux send-keys -t "$pid" C-c
        tmux send-keys -t "$pid" "$exec_cmd" Enter
    done
}

# ── drone up ─────────────────────────────────────────────────────────────────

cmd_up() {
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"
    local compose="$project_dir/$COMPOSE_FILE"

    dbg "cmd_up: project=$project_name dir=$project_dir"

    local has_devcontainer=0
    [[ -f "$compose" ]] && has_devcontainer=1

    if (( ! has_devcontainer )); then
        # ── No devcontainer: plain local window ──────────────────────────────
        dbg "cmd_up: no .devcontainer, creating local window"
        ensure_session

        if has_window "$project_name"; then
            info "Project '$project_name' already open."
            attach_or_switch "$project_name"
            return
        fi

        create_3pane_window "$project_name" "cd $project_dir"
        tmux set-option -t "$SESSION:$project_name" @project_dir "$project_dir"
        borg add "$project_dir" 2>/dev/null || true
        info "Project '$project_name' ready (local)."
        attach_or_switch "$project_name"
        return
    fi

    # ── Devcontainer path ─────────────────────────────────────────────────────

    ensure_postgres
    ensure_session

    # Window already exists — check health
    if has_window "$project_name"; then
        local panes
        panes=$(window_pane_count "$project_name")
        dbg "cmd_up: window '$project_name' exists with $panes panes"

        if [[ "$panes" != "3" ]]; then
            dbg "cmd_up: wrong pane count, killing window"
            tmux kill-window -t "$SESSION:$project_name"
            # Fall through to create new window
        else
            local container
            container=$(get_project_container "$project_dir")
            if [[ -z "$container" ]]; then
                info "Container stopped. Restarting..."
                docker compose -p "$project_name" -f "$compose" up -d
                container=$(wait_for_container "$project_dir")
                local shell service exec_cmd
                shell=$(get_shell "$container")
                service=$(get_service_name "$project_dir")
                exec_cmd="docker compose -p $project_name -f $compose exec $service $shell"
                resend_exec_to_panes "$project_name" "$exec_cmd"
            fi
            info "Project '$project_name' already running."
            attach_or_switch "$project_name"
            return
        fi
    fi

    # Create new project window
    local container
    container=$(get_project_container "$project_dir")
    if [[ -z "$container" ]]; then
        info "Starting containers for $project_name..."
        docker compose -p "$project_name" -f "$compose" up -d
        container=$(wait_for_container "$project_dir")
    fi

    local shell service exec_cmd
    shell=$(get_shell "$container")
    service=$(get_service_name "$project_dir")
    exec_cmd="docker compose -p $project_name -f $compose exec $service $shell"
    info "Container: $container  Service: $service  Shell: $shell"

    create_3pane_window "$project_name" "$exec_cmd"
    tmux set-option -t "$SESSION:$project_name" @project_dir "$project_dir"
    borg add "$project_dir" 2>/dev/null || true

    dbg "cmd_up: windows: $(tmux list-windows -t "$SESSION" -F '  #I: #W (#{window_panes} panes)' 2>/dev/null)"

    info "Project '$project_name' ready."
    attach_or_switch "$project_name"
}

# ── drone down ────────────────────────────────────────────────────────────────

cmd_down() {
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"
    local compose="$project_dir/$COMPOSE_FILE"

    dbg "cmd_down: project=$project_name dir=$project_dir"

    if tmux has-session -t "$SESSION" 2>/dev/null && has_window "$project_name"; then
        info "Removing window '$project_name'."
        tmux kill-window -t "$SESSION:$project_name"
    fi

    if [[ -f "$compose" ]]; then
        info "Stopping containers for $project_name..."
        docker compose -p "$project_name" -f "$compose" down
    fi

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        local remaining
        remaining=$(project_window_count)
        dbg "cmd_down: $remaining project windows remaining"
        if (( remaining == 0 )); then
            info "No projects left. Stopping postgres and killing session."
            docker compose -f "$POSTGRES_COMPOSE" down 2>/dev/null || true
            tmux kill-session -t "$SESSION" 2>/dev/null || true
        fi
    else
        docker compose -f "$POSTGRES_COMPOSE" down 2>/dev/null || true
    fi
}

# ── drone restart ─────────────────────────────────────────────────────────────

_restart_project() {
    local project_name="$1" project_dir="$2"
    local compose="$project_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || { warn "$project_name: no $COMPOSE_FILE, skipping"; return 0; }

    info "Restarting $project_name..."
    docker compose -p "$project_name" -f "$compose" down
    docker compose -p "$project_name" -f "$compose" up -d

    local container shell service exec_cmd
    container=$(wait_for_container "$project_dir")
    shell=$(get_shell "$container")
    service=$(get_service_name "$project_dir")
    exec_cmd="docker compose -p $project_name -f $compose exec $service $shell"

    if has_window "$project_name"; then
        resend_exec_to_panes "$project_name" "$exec_cmd"
        info "$project_name: restarted, panes re-exec'd."
    else
        info "$project_name: container up, no window to refresh."
    fi
}

cmd_restart() {
    if [[ "${1:-}" == "--all" ]]; then
        _cmd_restart_all
        return
    fi

    local project_name project_dir

    # If no arg and we're in tmux, prefer @project_dir from current window
    if [[ -z "${1:-}" && -n "$TMUX" ]]; then
        local current_window
        current_window=$(tmux display-message -p '#W')
        local pdir
        pdir=$(tmux show-option -t "$SESSION:$current_window" -v @project_dir 2>/dev/null) || true
        if [[ -n "$pdir" && -d "$pdir" ]]; then
            _proj_dir="$pdir"
            _proj_name="${pdir##*/}"
            _restart_project "$_proj_name" "$_proj_dir"
            return
        fi
    fi

    _drone_resolve "${1:-}"
    _restart_project "$_proj_name" "$_proj_dir"
}

_cmd_restart_all() {
    tmux has-session -t "$SESSION" 2>/dev/null || die "No $SESSION tmux session running."

    local windows
    windows=(${(f)"$(tmux list-windows -t "$SESSION" -F '#W')"})

    local count=0
    for wname in $windows; do
        [[ "$wname" == "host" ]] && continue
        local pdir
        pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || true
        if [[ -z "$pdir" ]]; then
            warn "$wname: no @project_dir set, skipping"
            continue
        fi
        _restart_project "$wname" "$pdir"
        count=$(( count + 1 ))
    done
    info "Restarted $count project(s)."
}

# ── drone claude ──────────────────────────────────────────────────────────────

cmd_claude() {
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"

    dbg "cmd_claude: project=$project_name dir=$project_dir"

    # Ensure the project window is up; if not, bring it up first
    if ! has_window "$project_name"; then
        info "$project_name: no window found, running drone up first..."
        cmd_up "${1:-}"
    fi

    # Send 'claude' to the first pane of the project window
    local main_pane
    main_pane=$(tmux list-panes -t "$SESSION:$project_name" -F '#{pane_id}' | head -1)
    info "Launching Claude in $project_name..."
    tmux send-keys -t "$main_pane" "claude" Enter

    # Switch to the project window
    attach_or_switch "$project_name"
}

# ── drone sh ──────────────────────────────────────────────────────────────────

cmd_sh() {
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"
    local compose="$project_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || die "No $COMPOSE_FILE found in $project_dir"

    local service
    service=$(docker ps --filter "label=com.docker.compose.project=$project_name" \
                        --filter "label=dev.role=app" \
                        --format '{{.Label "com.docker.compose.service"}}' 2>/dev/null | head -1)
    [[ -n "$service" ]] || die "No running app container found for $project_name. Run: drone up $project_name"

    exec docker compose -p "$project_name" -f "$compose" exec "$service" /bin/zsh
}

# ── drone fix ─────────────────────────────────────────────────────────────────

cmd_fix() {
    tmux has-session -t "$SESSION" 2>/dev/null || die "No $SESSION tmux session running."

    local targets=()
    if [[ "${1:-}" == "--all" ]]; then
        targets=(${(f)"$(tmux list-windows -t "$SESSION" -F '#W')"})
    elif [[ -n "${1:-}" ]]; then
        targets=("$1")
    else
        targets=("$(tmux display -p '#{window_name}')")
    fi

    for wname in $targets; do
        local pane_count
        pane_count=$(window_pane_count "$wname")
        if [[ "$pane_count" != "3" ]]; then
            warn "$wname: has $pane_count panes (expected 3), skipping"
            continue
        fi

        local W H
        W=$(tmux display -t "$SESSION:$wname" -p '#{window_width}')
        H=$(tmux display -t "$SESSION:$wname" -p '#{window_height}')

        local top_h bottom_h main_w side_w
        top_h=$(( H * 75 / 100 ))
        bottom_h=$(( H - top_h - 1 ))
        main_w=$(( W * 70 / 100 ))
        side_w=$(( W - main_w - 1 ))

        local layout
        layout="${W}x${H},0,0[${W}x${top_h},0,0{${main_w}x${top_h},0,0,0,${side_w}x${top_h},$(( main_w + 1 )),0,2},${W}x${bottom_h},0,$(( top_h + 1 )),1]"

        info "$wname: restoring layout (${W}x${H} → top_h=$top_h main_w=$main_w)"
        tmux select-layout -t "$SESSION:$wname" "$layout"
        tmux select-pane -t "$(tmux list-panes -t "$SESSION:$wname" -F '#{pane_id}' | head -1)"
    done
}

# ── drone status ──────────────────────────────────────────────────────────────

cmd_status() {
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        echo "No $SESSION tmux session running."
        return
    fi

    local windows
    windows=(${(f)"$(tmux list-windows -t "$SESSION" -F '#W')"})

    printf "\n${BOLD}%-20s %-30s %-20s %s${NC}\n" "DRONE" "PATH" "CONTAINER" "STATUS"
    printf '%0.s─' {1..80}; echo

    for wname in $windows; do
        if [[ "$wname" == "host" ]]; then
            printf "  %-20s %s\n" "$wname" "(host shell)"
            continue
        fi

        local pdir container container_status borg_status
        pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || pdir="?"

        container=$(get_project_container "$pdir" 2>/dev/null) || container=""
        if [[ -n "$container" ]]; then
            container_status=$(docker ps --format '{{.Status}}' --filter "name=$container" 2>/dev/null)
        else
            container_status="no container"
        fi

        borg_status=""
        if command -v borg &>/dev/null; then
            local raw
            raw=$(borg status "$wname" 2>/dev/null) || true
            borg_status=$(echo "$raw" | grep -m1 'Status:' | sed 's/.*Status:[[:space:]]*//' | tr -d '\n') || true
            [[ -n "$borg_status" ]] && borg_status="claude:$borg_status"
        fi

        printf "  %-20s %-30s %-20s %s\n" "$wname" "$pdir" "$container_status" "$borg_status"
    done
    echo
}

# ── drone help ────────────────────────────────────────────────────────────────

cmd_help() {
    cat <<'EOF'

  drone — The Borg Collective: project lifecycle manager

  Your containers will be assimilated.

  COMMANDS
    up [project]         Start container + create tmux window (uses $PWD if no arg)
    down [project]       Stop container + remove tmux window
    claude [project]     Launch Claude Code in project window (runs drone up if needed)
    sh [project]         Shell into project container (exec docker compose exec)
    restart [project]    Restart containers + re-exec all panes
    restart --all        Restart all project containers
    fix [project]        Restore standard 3-pane layout for project window
    fix --all            Restore layout for all windows
    status               Show all active drones (containers + Claude status)
    help                 Show this message

  PROJECT RESOLUTION
    drone up             Uses current directory (backwards-compatible with dev.sh)
    drone up cairn       Looks up 'cairn' in borg registry, then $BORG_ROOT_DIR/cairn

  WINDOW LAYOUT
    Top-left  (70%): main editor / Claude session
    Top-right (30%): side terminal
    Bottom    (25%): logs / output

  ENVIRONMENT
    BORG_TMUX_SESSION    tmux session name (default: borg)
    BORG_ROOT_DIR        root directory for project lookup (default: ~/dev)
    BORG_DEBUG           set to any value for debug output

EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

dbg "dispatch: args='${*}'"
dbg "dispatch: SESSION=$SESSION"

case "${1:-}" in
    up)         cmd_up "${2:-}" ;;
    down)       cmd_down "${2:-}" ;;
    claude)     cmd_claude "${2:-}" ;;
    sh)         cmd_sh "${2:-}" ;;
    restart)    cmd_restart "${2:-}" ;;
    fix)        cmd_fix "${2:-}" ;;
    status)     cmd_status ;;
    help|-h)    cmd_help ;;
    *)          cmd_help ;;
esac
