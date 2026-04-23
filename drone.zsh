#!/usr/bin/env zsh
# drone — The Borg Collective: project lifecycle manager
#
# Manages Docker Compose devcontainers, tmux windows, and Claude sessions.
# Forked from dev.sh and integrated with borg orchestration.
#
# Usage:
#   drone feature <project> <branch>  Create worktree + branch, launch Claude (Boris workflow)
#   drone up [project]           Start container + create tmux window
#   drone down [project]         Stop container + remove tmux window
#   drone claude [project]       Launch Claude Code in project window
#   drone sh [project]           Shell into project container
#   drone restart [project]      Restart containers + re-exec panes
#   drone rebuild [project]      Rebuild images (no cache) + restart
#   drone fix [project|--all]    Restore standard 2-pane layout
#   drone toggle [project]       Add/remove side pane (2-pane ↔ 3-pane)
#   drone status                 Show all active drones
#   drone help                   Command reference

set -e

PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# Tests and advanced users can prepend to PATH via BORG_DRONE_EXTRA_PATH.
[[ -n "${BORG_DRONE_EXTRA_PATH:-}" ]] && PATH="$BORG_DRONE_EXTRA_PATH:$PATH"
export PATH
hash -r 2>/dev/null || true

SESSION="${BORG_TMUX_SESSION:-borg}"
COMPOSE_FILE=".devcontainer/docker-compose.yml"
# drone always runs with the borg profile so borg-specific mounts are active.
# Override with COMPOSE_PROFILES= to test the team-portable (no borg) surface.
export COMPOSE_PROFILES="${COMPOSE_PROFILES:-borg}"
POSTGRES_COMPOSE="$HOME/.config/dotfiles/devcontainer/docker-compose.postgres.yml"
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_ROOT="${BORG_ROOT:-$HOME/dev}"

DRONE_SCRIPT_DIR="${0:A:h}"

# Host-side lifecycle hooks (.devcontainer/borg-hooks/{pre-up,post-down}.sh).
source "$DRONE_SCRIPT_DIR/lib/drone-hooks.zsh"

_run_pre_up()    { run_borg_hook "$1" "$2" pre-up.sh strict || die "pre-up.sh failed for $2"; }
_run_post_down() { run_borg_hook "$1" "$2" post-down.sh lenient; }

# Shared scaffolder preflight: absolutize project_dir, confirm it exists,
# refuse if .devcontainer/ is already populated. Sets _sp_dir to the absolute path.
_scaffold_preflight() {
    _sp_dir="$1"
    [[ "$_sp_dir" != /* ]] && _sp_dir="$PWD/$_sp_dir"
    [[ -d "$_sp_dir" ]] || die "Directory does not exist: $_sp_dir"
    [[ -d "$_sp_dir/.devcontainer" ]] && die ".devcontainer/ already exists in $_sp_dir"
    return 0
}

# postStartCommand suffix that recreates /workspace as a symlink to the real workspace
# so scripts hardcoding the old path still resolve. Empty when workspace is already /workspace.
_ws_symlink_snippet() {
    local workspace="$1"
    [[ "$workspace" == "/workspace" ]] && return 0
    printf '; sudo rm -rf /workspace 2>/dev/null; sudo ln -sfn %s /workspace' "$workspace"
}

# Build a docker compose exec command for a project's app service.
# Usage: build_exec_cmd <project_name> <compose_file> <service> <shell> <project_dir>
build_exec_cmd() {
    _read_devcontainer_exec_config "$5"
    if [[ -n "$_dc_user" ]]; then
        echo "docker compose -p $1 -f $2 exec -u $_dc_user -w $_dc_workspace $3 $4"
    else
        echo "docker compose -p $1 -f $2 exec -w $_dc_workspace $3 $4"
    fi
}

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

    # Look up in borg registry first (takes priority over relative paths
    # to avoid e.g. "snowfort" matching a subdirectory snowfort/snowfort/)
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

    # Argument is an existing path
    if [[ -d "$arg" ]]; then
        _proj_dir="$(cd "$arg" && pwd)"
        _proj_name="${_proj_dir##*/}"
        return 0
    fi

    # Try BORG_ROOT/<arg>
    if [[ -d "$BORG_ROOT/$arg" ]]; then
        _proj_dir="$BORG_ROOT/$arg"
        _proj_name="$arg"
        return 0
    fi

    die "Cannot find project '$arg'. cd to the project dir, or register it with: borg add <path>"
}

# ── Color helpers ─────────────────────────────────────────────────────────────

# Return the tmux color for a project (registry → hash fallback).
_drone_project_color() {
    local project="$1" color
    color=$(jq -r --arg p "$project" '.projects[$p].color // empty' "$BORG_DIR/registry.json" 2>/dev/null)
    if [[ -z "$color" ]]; then
        local -a palette=(cyan green yellow magenta blue red white)
        local hash=0 c
        for c in ${(s::)project}; do hash=$(( (hash * 31 + #c) % ${#palette} )); done
        color="${palette[$((hash + 1))]}"
    fi
    echo "$color"
}

# Apply a color to a named window in the drone tmux session.
_drone_apply_window_color() {
    local window="$1" color="$2"
    tmux set-option -t "$SESSION:$window" window-status-style "fg=$color" 2>/dev/null || true
    tmux set-option -t "$SESSION:$window" window-status-current-style "fg=colour0,bg=colour255,bold" 2>/dev/null || true
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

get_bottom_pane() {
    tmux list-panes -t "$SESSION:$1" -F '#{pane_top} #{pane_id}' 2>/dev/null \
        | sort -rn | head -1 | awk '{print $2}'
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

_read_devcontainer_field() {
    local project_dir="$1" field="$2"
    local dc_json="$project_dir/.devcontainer/devcontainer.json"
    [[ -f "$dc_json" ]] || return 0
    sed 's|^\s*//.*||' "$dc_json" | jq -r ".$field // empty"
}

# Read workspaceFolder and remoteUser from devcontainer.json in one jq pass.
# Sets _dc_workspace (default /workspace) and _dc_user (default empty = root).
_read_devcontainer_exec_config() {
    local project_dir="$1"
    local dc_json="$project_dir/.devcontainer/devcontainer.json"
    _dc_workspace="/workspace"
    _dc_user=""
    [[ -f "$dc_json" ]] || return 0
    local out
    out=$(sed 's|^\s*//.*||' "$dc_json" | jq -r '[.workspaceFolder // "/workspace", .remoteUser // ""] | @tsv') || return 0
    _dc_workspace="${out%%	*}"
    _dc_user="${out##*	}"
}

_devcontainer_hash() {
    local project_dir="$1"
    [[ -d "$project_dir/.devcontainer" ]] || { echo ""; return 0; }
    local base_id
    base_id=$(docker inspect devcontainer-base:local --format '{{.Id}}' 2>/dev/null || true)
    { find "$project_dir/.devcontainer" -type f | sort | xargs shasum 2>/dev/null
      printf '%s\n' "$base_id"
    } | shasum | awk '{print $1}'
}

_save_devcontainer_hash() {
    [[ -n "$_dc_hash" ]] || return 0
    mkdir -p "$_dc_hash_dir"
    echo "$_dc_hash" > "$_dc_hash_file"
}

run_initialize_command() {
    local project_dir="$1"
    local init_cmd
    init_cmd=$(_read_devcontainer_field "$project_dir" "initializeCommand") || return 0
    [[ -n "$init_cmd" ]] || return 0
    dbg "run_initialize_command: $init_cmd"
    local expanded="${init_cmd//\$\{localWorkspaceFolder\}/$project_dir}"
    eval "$expanded"
}

run_post_create_command() {
    local project_name="$1" project_dir="$2"
    local post_cmd
    post_cmd=$(_read_devcontainer_field "$project_dir" "postCreateCommand") || return 0
    [[ -n "$post_cmd" ]] || return 0
    local compose="$project_dir/$COMPOSE_FILE"
    local service
    service=$(get_service_name "$project_dir")
    _read_devcontainer_exec_config "$project_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    local sentinel="/tmp/.drone-created"
    local exists
    exists=$(docker compose -p "$project_name" -f "$compose" exec -T "${user_args[@]}" "$service" sh -c "test -f $sentinel && echo yes || echo no" 2>/dev/null) || exists="no"
    if [[ "$exists" == "no" ]]; then
        dbg "run_post_create_command: $post_cmd"
        docker compose -p "$project_name" -f "$compose" exec -T "${user_args[@]}" -w "$_dc_workspace" "$service" sh -c "$post_cmd"
        docker compose -p "$project_name" -f "$compose" exec -T "${user_args[@]}" "$service" sh -c "touch $sentinel"
    else
        dbg "run_post_create_command: sentinel exists, skipping"
    fi
}

run_post_start_command() {
    local project_name="$1" project_dir="$2"
    local post_cmd
    post_cmd=$(_read_devcontainer_field "$project_dir" "postStartCommand") || return 0
    [[ -n "$post_cmd" ]] || return 0
    dbg "run_post_start_command: $post_cmd"
    local compose="$project_dir/$COMPOSE_FILE"
    local service
    service=$(get_service_name "$project_dir")
    _read_devcontainer_exec_config "$project_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    docker compose -p "$project_name" -f "$compose" exec -T "${user_args[@]}" -w "$_dc_workspace" "$service" sh -c "$post_cmd"
}

# ── Window management ─────────────────────────────────────────────────────────

create_2pane_window() {
    local wname="$1" cmd="${2:-}" start_dir="${3:-$HOME}"
    dbg "create_2pane_window: '$wname' start_dir=$start_dir"

    local main
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        main=$(tmux new-session -d -s "$SESSION" -n "$wname" -c "$start_dir" -PF '#{pane_id}')
    else
        main=$(tmux new-window -t "$SESSION:" -n "$wname" -c "$start_dir" -PF '#{pane_id}')
    fi

    tmux set-option -t "$SESSION:$wname" automatic-rename off

    # Side-by-side 50/50 — left pane is the shell, right pane is the Claude pane.
    local right
    right=$(tmux split-window -h -p 50 -t "$main" -c "$start_dir" -PF '#{pane_id}')

    # Default focus to right pane (Claude pane)
    tmux select-pane -t "$right"

    if [[ -n "$cmd" ]]; then
        tmux send-keys -t "$main"  "$cmd" Enter
        tmux send-keys -t "$right" "$cmd" Enter
    fi

    dbg "create_2pane_window: done (main=$main right=$right)"
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

        if has_window "$project_name"; then
            info "Project '$project_name' already open."
            attach_or_switch "$project_name"
            return
        fi

        create_2pane_window "$project_name" "cd $project_dir" "$project_dir"
        tmux set-option -t "$SESSION:$project_name" @project_dir "$project_dir"
        _drone_apply_window_color "$project_name" "$(_drone_project_color "$project_name")"
        borg add "$project_dir" 2>/dev/null || true
        echo "$project_name" > "$project_dir/.borg-project"
        info "Project '$project_name' ready (local)."
        attach_or_switch "$project_name"
        return
    fi

    # ── Devcontainer path ─────────────────────────────────────────────────────

    ensure_postgres

    # Detect if devcontainer definition changed since last build
    local _dc_hash _dc_hash_dir _dc_hash_file _build_flag=""
    _dc_hash_dir="$BORG_DIR/devcontainer-hashes"
    _dc_hash_file="$_dc_hash_dir/${project_name}.hash"
    _dc_hash=$(_devcontainer_hash "$project_dir")
    if [[ -n "$_dc_hash" && "$(cat "$_dc_hash_file" 2>/dev/null)" != "$_dc_hash" ]]; then
        info "Devcontainer definition changed — rebuilding image."
        _build_flag="--build"
    fi

    # Window already exists — check health
    if has_window "$project_name"; then
        local panes
        panes=$(window_pane_count "$project_name")
        dbg "cmd_up: window '$project_name' exists with $panes panes"

        if [[ "$panes" != "2" ]]; then
            dbg "cmd_up: wrong pane count, killing window"
            tmux kill-window -t "$SESSION:$project_name"
            # Fall through to create new window
        else
            local container
            container=$(get_project_container "$project_dir")
            if [[ -z "$container" ]] || [[ -n "$_build_flag" ]]; then
                if [[ -n "$_build_flag" ]]; then
                    info "Rebuilding container for $project_name..."
                else
                    info "Container stopped. Restarting..."
                fi
                run_initialize_command "$project_dir"
                _run_pre_up "$project_dir" "$project_name"
                docker compose -p "$project_name" -f "$compose" up -d $_build_flag
                container=$(wait_for_container "$project_dir")
                _save_devcontainer_hash
                local shell service exec_cmd
                shell=$(get_shell "$container")
                service=$(get_service_name "$project_dir")
                exec_cmd=$(build_exec_cmd "$project_name" "$compose" "$service" "$shell" "$project_dir")
                run_post_create_command "$project_name" "$project_dir"
                run_post_start_command "$project_name" "$project_dir"
                resend_exec_to_panes "$project_name" "$exec_cmd"
            fi
            info "Project '$project_name' already running."
            _drone_apply_window_color "$project_name" "$(_drone_project_color "$project_name")"
            attach_or_switch "$project_name"
            return
        fi
    fi

    # Create new project window
    local container
    container=$(get_project_container "$project_dir")
    if [[ -z "$container" ]] || [[ -n "$_build_flag" ]]; then
        info "Starting containers for $project_name..."
        run_initialize_command "$project_dir"
        _run_pre_up "$project_dir" "$project_name"
        docker compose -p "$project_name" -f "$compose" up -d $_build_flag
        container=$(wait_for_container "$project_dir")
        mkdir -p "$_dc_hash_dir" && [[ -n "$_dc_hash" ]] && echo "$_dc_hash" > "$_dc_hash_file" || true
    fi

    local shell service exec_cmd
    shell=$(get_shell "$container")
    service=$(get_service_name "$project_dir")
    exec_cmd=$(build_exec_cmd "$project_name" "$compose" "$service" "$shell" "$project_dir")
    info "Container: $container  Service: $service  Shell: $shell"
    run_post_create_command "$project_name" "$project_dir"
    run_post_start_command "$project_name" "$project_dir"

    create_2pane_window "$project_name" "$exec_cmd" "$project_dir"
    tmux set-option -t "$SESSION:$project_name" @project_dir "$project_dir"
    _drone_apply_window_color "$project_name" "$(_drone_project_color "$project_name")"
    borg add "$project_dir" 2>/dev/null || true
    echo "$project_name" > "$project_dir/.borg-project"

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

    rm -f "$project_dir/.borg-project"

    if [[ -f "$compose" ]]; then
        info "Stopping containers for $project_name..."
        docker compose -p "$project_name" -f "$compose" down
        _run_post_down "$project_dir" "$project_name"
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

# ── drone restart / rebuild ───────────────────────────────────────────────────

# Shared container cycle: down → [build] → up → post-start → re-exec panes.
# mode=restart  skips the build step
# mode=rebuild  adds docker compose build --no-cache
_cycle_project() {
    local project_name="$1" project_dir="$2" mode="${3:-restart}"
    local compose="$project_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || { warn "$project_name: no $COMPOSE_FILE, skipping"; return 0; }

    # Transient down during restart/rebuild intentionally does NOT fire
    # post-down.sh — external stacks (e.g. Supabase) should persist across cycles.
    if [[ "$mode" == "rebuild" ]]; then
        info "Rebuilding $project_name (no cache)..."
        docker compose -p "$project_name" -f "$compose" down
        docker compose -p "$project_name" -f "$compose" build --no-cache
    else
        info "Restarting $project_name..."
        docker compose -p "$project_name" -f "$compose" down
    fi
    _run_pre_up "$project_dir" "$project_name"
    docker compose -p "$project_name" -f "$compose" up -d

    local container shell service exec_cmd
    container=$(wait_for_container "$project_dir")

    if [[ "$mode" == "rebuild" ]]; then
        local _dc_hash _dc_hash_dir _dc_hash_file
        _dc_hash_dir="$BORG_DIR/devcontainer-hashes"
        _dc_hash_file="$_dc_hash_dir/${project_name}.hash"
        _dc_hash=$(_devcontainer_hash "$project_dir")
        _save_devcontainer_hash
    fi
    shell=$(get_shell "$container")
    service=$(get_service_name "$project_dir")
    exec_cmd=$(build_exec_cmd "$project_name" "$compose" "$service" "$shell" "$project_dir")
    run_post_create_command "$project_name" "$project_dir"
    run_post_start_command "$project_name" "$project_dir"

    if has_window "$project_name"; then
        resend_exec_to_panes "$project_name" "$exec_cmd"
        info "$project_name: ${mode}ed, panes re-exec'd."
    else
        info "$project_name: ${mode}ed, no window to refresh."
    fi
}

_restart_project() { _cycle_project "$1" "$2" "restart"; }
_rebuild_project()  { _cycle_project "$1" "$2" "rebuild"; }

# Shared --all iterator: walks every non-host project window and calls op_func.
_foreach_project_window() {
    local op_func="$1" past_tense="$2"
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
        "$op_func" "$wname" "$pdir"
        count=$(( count + 1 ))
    done
    info "${past_tense} $count project(s)."
}

# Shared dispatch: handles --all, tmux current-window fallback, and named arg.
_cmd_cycle() {
    local mode="$1" arg="${2:-}"

    if [[ "$arg" == "--all" ]]; then
        local past_tense
        [[ "$mode" == "rebuild" ]] && past_tense="Rebuilt" || past_tense="Restarted"
        _foreach_project_window "_${mode}_project" "$past_tense"
        return
    fi

    if [[ -z "$arg" && -n "$TMUX" ]]; then
        local current_window pdir
        current_window=$(tmux display-message -p '#W')
        pdir=$(tmux show-option -t "$SESSION:$current_window" -v @project_dir 2>/dev/null) || true
        if [[ -n "$pdir" && -d "$pdir" ]]; then
            _cycle_project "${pdir##*/}" "$pdir" "$mode"
            return
        fi
    fi

    _drone_resolve "$arg"
    _cycle_project "$_proj_name" "$_proj_dir" "$mode"
}

cmd_restart() { _cmd_cycle "restart" "${1:-}"; }
cmd_rebuild()  { _cmd_cycle "rebuild" "${1:-}"; }

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

    # Send 'claude' to the bottom pane (highest pane_top value)
    local bottom_pane
    bottom_pane=$(get_bottom_pane "$project_name")
    info "Launching Claude in $project_name (bottom pane)..."
    tmux send-keys -t "$bottom_pane" "claude" Enter

    # Switch to the project window, focus + zoom Claude pane
    attach_or_switch "$project_name"
    _drone_apply_window_color "$project_name" "$(_drone_project_color "$project_name")"
    tmux select-pane -t "$bottom_pane"
    tmux resize-pane -Z -t "$bottom_pane"
}

# ── drone cortex ──────────────────────────────────────────────────────────────

cmd_cortex() {
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"

    dbg "cmd_cortex: project=$project_name dir=$project_dir"

    if ! has_window "$project_name"; then
        info "$project_name: no window found, running drone up first..."
        cmd_up "${1:-}"
    fi

    local bottom_pane
    bottom_pane=$(get_bottom_pane "$project_name")
    info "Launching Cortex in $project_name (bottom pane)..."
    tmux send-keys -t "$bottom_pane" "cortex" Enter
    tmux set-option -t "$SESSION:$project_name" @cortex_launched 1

    attach_or_switch "$project_name"
    _drone_apply_window_color "$project_name" "$(_drone_project_color "$project_name")"
    tmux select-pane -t "$bottom_pane"
    tmux resize-pane -Z -t "$bottom_pane"
}

# ── drone start ───────────────────────────────────────────────────────────────

cmd_feature() {
    local feature="${2:-}"
    [[ -z "$feature" ]] && die "Usage: drone feature <project> <branch>"
    _drone_resolve "${1:-}"
    local project_name="$_proj_name"
    local project_dir="$_proj_dir"
    local window_name="${project_name}-${feature}"
    local work_dir="${project_dir%/*}/${project_name}-${feature}"

    if has_window "$window_name"; then
        info "Already open: $window_name"
        attach_or_switch "$window_name"
        return
    fi

    if [[ ! -d "$work_dir" ]]; then
        if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$feature" 2>/dev/null; then
            git -C "$project_dir" worktree add "$work_dir" "$feature"
        else
            git -C "$project_dir" worktree add -b "$feature" "$work_dir"
        fi
        info "Worktree created: $work_dir (branch: $feature)"
    else
        info "Worktree exists: $work_dir"
    fi

    local compose="$work_dir/$COMPOSE_FILE"
    if [[ -f "$compose" ]]; then
        cmd_up "$work_dir"
    else
        create_2pane_window "$window_name" "cd $work_dir" "$work_dir"
        tmux set-option -t "$SESSION:$window_name" @project_dir "$work_dir"
        tmux set-option -t "$SESSION:$window_name" @project_name "$project_name"
        borg add "$work_dir" 2>/dev/null || true
        local bottom_pane
        bottom_pane=$(get_bottom_pane "$window_name")
        tmux send-keys -t "$bottom_pane" "claude" Enter
        attach_or_switch "$window_name"
        tmux select-pane -t "$bottom_pane"
        tmux resize-pane -Z -t "$bottom_pane"
    fi
    info "Started: $window_name"
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

    _read_devcontainer_exec_config "$project_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    exec docker compose -p "$project_name" -f "$compose" exec "${user_args[@]}" -w "$_dc_workspace" "$service" "${shell:-/bin/zsh}"
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
        if [[ "$pane_count" != "2" ]]; then
            warn "$wname: has $pane_count panes (expected 2), skipping"
            continue
        fi

        local H
        H=$(tmux display -t "$SESSION:$wname" -p '#{window_height}')

        # Restore top/bottom split: top ~75%, bottom ~25%
        local bottom_pane
        bottom_pane=$(get_bottom_pane "$wname")

        info "$wname: restoring layout (top 75% / bottom 25%)"
        tmux select-layout -t "$SESSION:$wname" even-vertical
        tmux resize-pane -t "$bottom_pane" -y $(( H * 25 / 100 ))
        local top_pane
        top_pane=$(tmux list-panes -t "$SESSION:$wname" -F '#{pane_top} #{pane_id}' 2>/dev/null \
            | sort -n | head -1 | awk '{print $2}')
        tmux select-pane -t "$top_pane"
    done
}

# ── drone toggle ──────────────────────────────────────────────────────────────

cmd_toggle() {
    local wname
    if [[ -n "${1:-}" ]]; then
        wname="$1"
    elif [[ -n "$TMUX" ]]; then
        wname=$(tmux display-message -p '#W')
    else
        die "Specify a project name or run from inside tmux."
    fi

    has_window "$wname" || die "No window '$wname' found."

    local pane_count
    pane_count=$(window_pane_count "$wname")

    if [[ "$pane_count" == "3" ]]; then
        # Kill the side pane (top row, rightmost = highest pane_left where pane_top=0)
        local side_pane
        side_pane=$(tmux list-panes -t "$SESSION:$wname" -F '#{pane_top} #{pane_left} #{pane_id}' \
            | awk '$1 == 0' | sort -k2 -rn | head -1 | awk '{print $3}')
        if [[ -n "$side_pane" ]]; then
            tmux kill-pane -t "$side_pane"
            info "$wname: side pane closed (2 panes)"
        fi
    elif [[ "$pane_count" == "2" ]]; then
        # Recreate side pane: split the top-left pane horizontally
        local main_pane
        main_pane=$(tmux list-panes -t "$SESSION:$wname" -F '#{pane_top} #{pane_id}' \
            | awk '$1 == 0' | head -1 | awk '{print $2}')
        if [[ -n "$main_pane" ]]; then
            local side
            side=$(tmux split-window -h -p 30 -t "$main_pane" -PF '#{pane_id}')
            # If this is a devcontainer project, exec into the container
            local pdir
            pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || true
            if [[ -n "$pdir" && -f "$pdir/$COMPOSE_FILE" ]]; then
                local container shell service exec_cmd
                container=$(get_project_container "$pdir") || true
                if [[ -n "$container" ]]; then
                    shell=$(get_shell "$container")
                    service=$(get_service_name "$pdir")
                    exec_cmd=$(build_exec_cmd "$wname" "$pdir/$COMPOSE_FILE" "$service" "$shell" "$pdir")
                    tmux send-keys -t "$side" "$exec_cmd" Enter
                fi
            elif [[ -n "$pdir" ]]; then
                tmux send-keys -t "$side" "cd $pdir" Enter
            fi
            info "$wname: side pane opened (3 panes)"
        fi
    else
        warn "$wname: unexpected pane count ($pane_count), skipping"
    fi
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
            raw=$(borg link "$wname" 2>/dev/null) || true
            borg_status=$(echo "$raw" | grep -m1 'Status:' | sed 's/.*Status:[[:space:]]*//' | tr -d '\n') || true
            [[ -n "$borg_status" ]] && borg_status="claude:$borg_status"
        fi

        local cortex_launched
        cortex_launched=$(tmux show-option -t "$SESSION:$wname" -v @cortex_launched 2>/dev/null) || cortex_launched=""
        [[ "$cortex_launched" == "1" ]] && borg_status+=" cortex:launched"

        printf "  %-20s %-30s %-20s %s\n" "$wname" "$pdir" "$container_status" "$borg_status"
    done
    echo
}

# ── drone scaffold --supabase ─────────────────────────────────────────────────

# Generate a Supabase-ready devcontainer from templates/supabase/, substituting
# __PROJECT_NAME__ / __PROJECT_NAME_UPPER__ / __WORKSPACE__. Runs `supabase init`
# in the project dir when supabase/ doesn't already exist. Refuses if
# .devcontainer/ or supabase/ already exists (no --force in v1).
_cmd_scaffold_supabase() {
    local project_dir="$1" workspace="$2"
    _scaffold_preflight "$project_dir"
    project_dir="$_sp_dir"
    local dc_dir="$project_dir/.devcontainer"

    [[ -d "$project_dir/supabase" ]] \
        && die "supabase/ already exists in $project_dir — refusing to overwrite"
    command -v supabase >/dev/null 2>&1 \
        || die "supabase CLI not found on PATH. Install: brew install supabase/tap/supabase"

    local project_name="${project_dir##*/}"
    local project_name_upper
    project_name_upper="${project_name:u}"
    project_name_upper="${project_name_upper//-/_}"

    local tmpl_dir="$DRONE_SCRIPT_DIR/templates/supabase"
    [[ -d "$tmpl_dir" ]] || die "Template directory missing: $tmpl_dir"

    info "Scaffolding Supabase devcontainer for '$project_name'..."
    mkdir -p "$dc_dir/borg-hooks"

    local ws_symlink
    ws_symlink=$(_ws_symlink_snippet "$workspace")

    _subst_template() {
        sed -e "s|__PROJECT_NAME__|$project_name|g" \
            -e "s|__PROJECT_NAME_UPPER__|$project_name_upper|g" \
            -e "s|__WORKSPACE__|$workspace|g" \
            -e "s|__WS_SYMLINK__|$ws_symlink|g" \
            "$1" > "$2"
    }

    _subst_template "$tmpl_dir/Dockerfile"          "$dc_dir/Dockerfile"
    _subst_template "$tmpl_dir/docker-compose.yml"  "$dc_dir/docker-compose.yml"
    _subst_template "$tmpl_dir/devcontainer.json"   "$dc_dir/devcontainer.json"
    cp "$tmpl_dir/borg-hooks/pre-up.sh"   "$dc_dir/borg-hooks/pre-up.sh"
    cp "$tmpl_dir/borg-hooks/post-down.sh" "$dc_dir/borg-hooks/post-down.sh"
    chmod +x "$dc_dir/borg-hooks/pre-up.sh" "$dc_dir/borg-hooks/post-down.sh"

    info "Running 'supabase init' in $project_dir..."
    (cd "$project_dir" && supabase init) || die "supabase init failed"

    # Confirm project_id in supabase/config.toml matches project_name. Supabase's
    # default is the directory name, which already matches, but sed-confirm to
    # be safe against future CLI changes.
    local config="$supabase_dir/config.toml"
    if [[ -f "$config" ]]; then
        local current_id
        current_id=$(grep -E '^project_id = ' "$config" | head -1 | sed -E 's/project_id = "([^"]+)"/\1/')
        if [[ -n "$current_id" && "$current_id" != "$project_name" ]]; then
            info "Aligning supabase project_id ($current_id → $project_name)..."
            sed -i.bak -E "s/^project_id = \"[^\"]+\"/project_id = \"$project_name\"/" "$config"
            rm -f "$config.bak"
        fi
    fi

    info "Scaffolded Supabase project in $project_dir"
    echo
    info "Next steps:"
    info "  1. drone up $project_name"
    info "  2. Create remote project: supabase login && supabase projects create $project_name"
    info "  3. Link: supabase link --project-ref <ref>"
}

# ── drone scaffold ────────────────────────────────────────────────────────────

cmd_scaffold() {
    local project_dir="" lang="none" workspace="" preset=""
    local workspace_explicit=0

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)     lang="${2:-none}"; shift 2 ;;
            --workspace) workspace="${2:-}"; workspace_explicit=1; shift 2 ;;
            --supabase) preset="supabase"; shift ;;
            *)          project_dir="$1"; shift ;;
        esac
    done

    [[ -z "$project_dir" ]] && die "Usage: drone scaffold <project-dir> [--supabase] [--lang python|node|none] [--workspace /workspaces/<project>]"

    # Default workspace from raw basename; the supabase branch runs its own preflight.
    if (( ! workspace_explicit )); then
        local _raw_basename="${project_dir%/}"
        _raw_basename="${_raw_basename##*/}"
        workspace="/workspaces/$_raw_basename"
    fi

    if [[ "$preset" == "supabase" ]]; then
        _cmd_scaffold_supabase "$project_dir" "$workspace"
        return
    fi

    _scaffold_preflight "$project_dir"
    project_dir="$_sp_dir"
    local dc_dir="$project_dir/.devcontainer"
    local project_name="${project_dir##*/}"
    mkdir -p "$dc_dir"

    # ── Dockerfile ────────────────────────────────────────────────────────
    local dockerfile_extra=""
    case "$lang" in
        python)
            dockerfile_extra='RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && pip install --break-system-packages uv'
            ;;
        node)
            dockerfile_extra='# Node.js already included in base image'
            ;;
        none|*)
            dockerfile_extra='# Add project-specific deps here if needed'
            ;;
    esac

    cat > "$dc_dir/Dockerfile" <<DOCKERFILE
# Extends the shared base devcontainer image.
# Base provides: zsh, neovim, tmux, git, ssh, node.js.
# claude-code (and cortex, if used) are installed via the claude_npm named
# volume in postCreateCommand so they upgrade without a full image rebuild.
#
# To rebuild the base locally:
#   docker build -f ~/.config/dotfiles/devcontainer/Dockerfile.base -t devcontainer-base:local .
FROM devcontainer-base:local

# npm global prefix — persisted in the claude_npm named volume so packages
# survive image rebuilds. Matches the volume mount point in docker-compose.yml.
ENV NPM_CONFIG_PREFIX=/home/dev/.npm-global
ENV PATH=/home/dev/.npm-global/bin:\$PATH

$dockerfile_extra

WORKDIR $workspace
DOCKERFILE

    # ── docker-compose.yml ────────────────────────────────────────────────
    # Profile split: ${project_name}-app (base, always starts, no borg mounts)
    # and ${project_name}-borg (extends base, adds borg mounts, profiles: [borg]).
    # drone sets COMPOSE_PROFILES=borg automatically; Cursor/team users start
    # ${project_name}-app by default and get a fully working container without
    # requiring host borg/claude config to be present.
    cat > "$dc_dir/docker-compose.yml" <<COMPOSE
services:
  # ── Base service — team-portable, no borg mounts ──────────────────────────
  ${project_name}-app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
    volumes:
      # project files
      - ..:${workspace}:cached
      # shell
      - ~/.config/dotfiles/zsh:/home/dev/.config/dotfiles/zsh:cached
      - ~/.config/zsh:/home/dev/.config/zsh:cached
      # editor
      - ~/.config/nvim:/home/dev/.config/nvim:cached
      # git + ssh — selective mounts only (see dotfiles/devcontainer/docker-compose.base.yml)
      - ~/.ssh/config:/home/dev/.ssh/config:ro
      - ~/.ssh/known_hosts:/home/dev/.ssh/known_hosts:ro
      - ~/.gitconfig:/home/dev/.gitconfig:cached
      - /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock
      # npm global packages (claude-code, cortex) — persists across rebuilds
      - claude_npm:/home/dev/.npm-global
    working_dir: ${workspace}
    user: dev
    command: sleep infinity
    environment:
      SSH_AUTH_SOCK: /run/host-services/ssh-auth.sock
    networks:
      - devnet

  # ── Borg-enabled service — extends base, adds borg mounts ─────────────────
  # Only starts when COMPOSE_PROFILES=borg (set automatically by drone up).
  ${project_name}-borg:
    extends:
      service: ${project_name}-app
    labels:
      - dev.role=app
    volumes:
      - ~/.claude:/home/dev/.claude:cached
      - ~/.config/borg:/home/dev/.config/borg:cached
      # host home read-only — postStartCommand copies .claude.json fresh each start
      - ~/:/host-home:ro
    profiles:
      - borg

volumes:
  claude_npm:  # persists npm globals (claude-code, cortex) across image rebuilds

networks:
  devnet:
    external: true
COMPOSE

    # ── devcontainer.json ─────────────────────────────────────────────────
    # npm install runs once (sentinel-guarded) and lands in the claude_npm volume.
    local post_create="ln -sf /home/dev/.config/dotfiles/zsh/.zshrc /home/dev/.zshrc; ln -sf /home/dev/.config/dotfiles/zsh/.p10k.zsh /home/dev/.p10k.zsh; npm install -g @anthropic-ai/claude-code 2>/dev/null || true"
    case "$lang" in
        python) post_create="$post_create; pip install -e '.[dev]'" ;;
        node)   post_create="$post_create; npm install" ;;
    esac

    local ws_symlink
    ws_symlink=$(_ws_symlink_snippet "$workspace")

    cat > "$dc_dir/devcontainer.json" <<DEVCONTAINER
{
  "name": "${project_name}",
  "dockerComposeFile": "docker-compose.yml",
  "service": "${project_name}-borg",
  "workspaceFolder": "${workspace}",
  "features": {},
  "postCreateCommand": "${post_create}",
  "postStartCommand": "sudo mkdir -p /Users && sudo ln -sfn /home/dev /Users/noah; sudo chmod a+rw /run/host-services/ssh-auth.sock 2>/dev/null || true; ln -sf /home/dev/.config/dotfiles/zsh/.zshrc /home/dev/.zshrc; ln -sf /home/dev/.config/dotfiles/zsh/.p10k.zsh /home/dev/.p10k.zsh; if [ -f /home/dev/.config/dotfiles/claude/code/CLAUDE.md ]; then cp /home/dev/.config/dotfiles/claude/code/CLAUDE.md /home/dev/.claude/CLAUDE.md; else echo 'borg: dotfiles/claude not mounted — CLAUDE.md not synced' >&2; fi; cp /host-home/.claude.json /home/dev/.claude.json 2>/dev/null || true${ws_symlink}",
  "shutdownAction": "stopCompose",
  "remoteUser": "dev",
  "updateRemoteUserUID": true
}
DEVCONTAINER

    info "Scaffolded .devcontainer/ in $project_dir"
    info "  Language: $lang"
    info "  Workspace: $workspace"
    echo
    info "Next steps:"
    info "  1. Verify base image exists: docker images devcontainer-base:local"
    info "  2. If missing, build it:"
    info "     docker build -f ~/.config/dotfiles/devcontainer/Dockerfile.base -t devcontainer-base:local ~/.config/dotfiles/devcontainer"
    info "  3. drone up $project_name"
}

# ── drone help ────────────────────────────────────────────────────────────────

cmd_help() {
    cat <<'EOF'

    _______________
   /|             /|
  / |            / |      drone — designation: project lifecycle
    |___________|  |
    |  |        |  |      "You will be assimilated."
    |  |________|__|
    | /         | /
    |/          |/

  COMMANDS
    feature <project> <branch>  Create worktree + branch, start window, launch Claude
    up [project]         Start container + create tmux window (uses $PWD if no arg)
    down [project]       Stop container + remove tmux window
    claude [project]     Launch Claude Code in project window (runs drone up if needed)
    cortex [project]     Launch Cortex Code in project window (runs drone up if needed)
    sh [project]         Shell into project container (exec docker compose exec)
    restart [project]    Restart containers + re-exec all panes
    restart --all        Restart all project containers
    rebuild [project]    Rebuild images (--no-cache) + restart + re-exec panes
    rebuild --all        Rebuild all project containers
    fix [project]        Restore standard 2-pane layout for project window
    fix --all            Restore layout for all windows
    toggle [project]     Add/remove side pane (2-pane ↔ 3-pane)
    scaffold <dir>       Generate .devcontainer/ (--lang python|node|none, --supabase)
    status               Show all active drones (containers + Claude status)
    help                 Show this message

  PROJECT RESOLUTION
    drone up             Uses current directory (backwards-compatible with dev.sh)
    drone up cairn       Looks up 'cairn' in borg registry, then $BORG_ROOT/cairn

  WINDOW LAYOUT
    Top    (75%): main editor / Claude session
    Bottom (25%): logs / output
    Toggle adds a top-right side terminal (30% split)

  ENVIRONMENT
    BORG_TMUX_SESSION    tmux session name (default: borg)
    BORG_ROOT            root directory for project lookup (default: ~/dev)
    BORG_DEBUG           set to any value for debug output

EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

dbg "dispatch: args='${*}'"
dbg "dispatch: SESSION=$SESSION"

case "${1:-}" in
    feature)    cmd_feature "${2:-}" "${3:-}" ;;
    up)         cmd_up "${2:-}" ;;
    down)       cmd_down "${2:-}" ;;
    claude)     cmd_claude "${2:-}" ;;
    cortex)     cmd_cortex "${2:-}" ;;
    sh)         cmd_sh "${2:-}" ;;
    restart)    cmd_restart "${2:-}" ;;
    rebuild)    cmd_rebuild "${2:-}" ;;
    fix)        cmd_fix "${2:-}" ;;
    toggle)     cmd_toggle "${2:-}" ;;
    scaffold)   shift; cmd_scaffold "$@" ;;
    status)     cmd_status ;;
    link)       exec borg link "${2:-${PWD##*/}}" "${@:3}" ;;
    help|-h)    cmd_help ;;
    *)          die "unknown command '${1}'. Run: drone help" ;;
esac
