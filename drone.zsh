#!/usr/bin/env zsh
# drone — The Borg Collective: repository lifecycle manager
#
# Manages Docker Compose devcontainers, tmux windows, and Claude sessions.
# Forked from dev.sh and integrated with borg orchestration.
#
# Usage:
#   drone feature <repository> <branch>  Create worktree + branch, launch Claude (Boris workflow)
#   drone up [repository] [--resume <sid>]  Start container + create tmux window (relaunch claude --resume)
#   drone down [repository]      Stop container + remove tmux window
#   drone claude [repository]    Launch Claude Code in repository window
#   drone sh [repository]        Shell into repository container
#   drone exec [repository] -- ...  Run non-interactive command inside container
#   drone restart [repository]   Restart containers + re-exec panes
#   drone rebuild [repository]   Rebuild images (no cache) + restart
#   drone fix [repository|--all]    Restore standard 2-pane layout
#   drone toggle [repository]    Add/remove side pane (2-pane ↔ 3-pane)
#   drone pane <direction>       Split the calling pane top|bottom|left|right (two panes max; reuse unzooms)
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
BORG_ORCHESTRATOR_ROOT="${BORG_ORCHESTRATOR_ROOT:-$HOME/dev}"

DRONE_SCRIPT_DIR="${0:A:h}"

# Host-side lifecycle hooks (.devcontainer/borg-hooks/{pre-up,post-down}.sh).
source "$DRONE_SCRIPT_DIR/lib/drone-hooks.zsh"
source "$DRONE_SCRIPT_DIR/lib/state-root.zsh"
# Shared registry-key guard (borg_registry_guard): a registry with only the retired `projects` key fails loudly.
source "$DRONE_SCRIPT_DIR/lib/reaper.sh"
# borg-resume ledger layout (borg_resume_dir, borg_resume_valid_sid): the same definitions the hooks use.
source "$DRONE_SCRIPT_DIR/lib/borg/resume-paths.sh"

_run_pre_up()    { run_borg_hook "$1" "$2" pre-up.sh strict || die "pre-up.sh failed for $2"; }
_run_post_down() { run_borg_hook "$1" "$2" post-down.sh lenient; }

# Shared scaffolder preflight: absolutize repository_dir, confirm it exists,
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

# Build a docker compose exec command for a repository's app service.
# Usage: build_exec_cmd <repository_name> <compose_file> <service> <shell> <repository_dir>
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

# Source repository secrets if present (Docker Compose needs API keys)
[[ -f "$HOME/.config/dotfiles/zsh/secrets.zsh" ]] && source "$HOME/.config/dotfiles/zsh/secrets.zsh" || true

# ── Repository resolution ─────────────────────────────────────────────────────

# Resolve a repository name/path argument to name + absolute dir.
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
        reg_path=$(jq -r --arg p "$arg" '.repositories[$p].path // empty' "$registry" 2>/dev/null) || true
        if [[ -n "$reg_path" && -d "$reg_path" ]]; then
            _proj_dir="$reg_path"
            _proj_name="$arg"
            return 0
        fi
        # Not a repository name: it may be a repository's SHORT tmux window name (registry `tmux_window`).
        local reg_repository
        reg_repository=$(_drone_repository_for_window "$arg")
        reg_path=""
        [[ -n "$reg_repository" ]] && reg_path=$(jq -r --arg p "$reg_repository" '.repositories[$p].path // empty' "$registry" 2>/dev/null) || true
        if [[ -n "$reg_path" && -d "$reg_path" ]]; then
            _proj_dir="$reg_path"
            _proj_name="$reg_repository"
            return 0
        fi
    fi

    # Argument is an existing path
    if [[ -d "$arg" ]]; then
        _proj_dir="$(cd "$arg" && pwd)"
        _proj_name="${_proj_dir##*/}"
        return 0
    fi

    # Try BORG_ORCHESTRATOR_ROOT/<arg>
    if [[ -d "$BORG_ORCHESTRATOR_ROOT/$arg" ]]; then
        _proj_dir="$BORG_ORCHESTRATOR_ROOT/$arg"
        _proj_name="$arg"
        return 0
    fi

    die "Cannot find repository '$arg'. cd to the repository dir, or register it with: borg add <path>"
}

# ── Window names (registry-owned) ─────────────────────────────────────────────

# Run the registry CLI with borg's config surface in the child's ENVIRONMENT. drone.zsh assigns
# SESSION/BORG_DIR without export, and a python3 child sees none of them (docs/agents/learned.md, "A shell
# variable is not an environment variable"), so every default is applied here, in the wrapper.
# borg_core is resolved script-relative via DRONE_SCRIPT_DIR, never via cwd or $BORG_HOME.
_drone_registry_py() {
    BORG_DIR="$BORG_DIR" \
    BORG_REGISTRY="${BORG_REGISTRY:-$BORG_DIR/registry.json}" \
    BORG_TMUX_SESSION="$SESSION" \
    PYTHONSAFEPATH=1 \
    PYTHONPATH="$DRONE_SCRIPT_DIR${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m borg_core.registry.cli "$@"
}

# The repository's tmux window name, derived-and-stored on first use (`window-name --derive`: an
# explicit choice is respected). Fail-open: any failure (no python, repository not in the registry)
# prints the repository name, which is the pre-registry behaviour.
_drone_window_name() {
    local repository="$1" out
    out=$(_drone_registry_py window-name "$repository" --derive 2>/dev/null) || out=""
    print -r -- "${out:-$repository}"
}

# Reverse lookup: the repository whose registry `tmux_window` equals $1 (empty when none).
_drone_repository_for_window() {
    local registry="${BORG_REGISTRY:-$BORG_DIR/registry.json}"
    [[ -f "$registry" ]] || return 0
    jq -r --arg w "$1" '[.repositories // {} | to_entries[] | select(.value.tmux_window == $w) | .key][0] // empty' \
        "$registry" 2>/dev/null || true
}

# Whether the registry knows repository $1.
_drone_registered() {
    local registry="${BORG_REGISTRY:-$BORG_DIR/registry.json}"
    [[ -f "$registry" ]] || return 1
    jq -e --arg p "$1" '.repositories[$p] != null' "$registry" >/dev/null 2>&1
}

# Registry key for $1, which may be a repository name or a short window name; $1 itself if unknown.
_drone_repository_of() {
    local reg_repository
    if _drone_registered "$1"; then print -r -- "$1"; return 0; fi
    reg_repository=$(_drone_repository_for_window "$1")
    print -r -- "${reg_repository:-$1}"
}

# The LIVE tmux window for a repository: the short name OR the long (repository) name, so windows opened
# before the short names existed keep working. Prints it; returns 1 when neither is live.
_drone_find_window() {
    local repository="$1" wname="$2"
    if has_window "$wname"; then print -r -- "$wname"
    elif has_window "$repository"; then print -r -- "$repository"
    else return 1
    fi
}

# Window for a command-line argument in either form (repository, short name, or a literal live window).
_drone_arg_window() {
    local arg="$1" repository wname live
    if has_window "$arg"; then print -r -- "$arg"; return 0; fi
    repository=$(_drone_repository_of "$arg")
    wname=$(_drone_window_name "$repository")
    live=$(_drone_find_window "$repository" "$wname") || live="$wname"
    print -r -- "$live"
}

# Register $repository if it is not already, then put its window name back. `borg add` rewrites
# tmux_window (to the repository name, or null) because it knows nothing of short names, and names a
# repository by its folder basename unless told otherwise -- so an existing entry is never re-added
# (a monorepo subfolder registered as `widgets` would grow a `widget-kit` twin), and a new one is
# added under the name drone was given. Fail-open.
_drone_register() {
    local repository_dir="$1" repository="$2" wname="$3"
    _drone_registered "$repository" || borg add "$repository_dir" --name "$repository" 2>/dev/null || true
    [[ "$wname" == "$repository" ]] || _drone_registry_py window-name "$repository" --set "$wname" >/dev/null 2>&1 || true
}

# ── Color helpers ─────────────────────────────────────────────────────────────

# Return the tmux color for a repository (registry → hash fallback).
_drone_repository_color() {
    local repository="$1" color
    color=$(jq -r --arg p "$repository" '.repositories[$p].color // empty' "$BORG_DIR/registry.json" 2>/dev/null)
    if [[ -z "$color" ]]; then
        local -a palette=(cyan green yellow magenta blue red white)
        local hash=0 c
        for c in ${(s::)repository}; do hash=$(( (hash * 31 + #c) % ${#palette} )); done
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

# The label value docker compose stamps for `-p <name>` (compose-go project name normalization):
# lowercased, only [a-z0-9_-] kept. A name that normalizes to empty matches nothing.
_compose_project_label() {
    local n="${(L)1}"
    print -r -- "${n//[^a-z0-9_-]/}"
}

# Both lookups take the REPOSITORY name (the one passed to `docker compose -p`), never the folder basename.
# Usage: get_repository_container <repository_name> <repository_dir>
get_repository_container() {
    local name
    name=$(_compose_project_label "$1")
    docker ps --filter "label=com.docker.compose.project=$name" \
              --filter "label=dev.role=app" \
              --format '{{.Names}}' 2>/dev/null | head -1
}

# Usage: get_service_name <repository_name>
get_service_name() {
    local name
    name=$(_compose_project_label "$1")
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
    # -F: a window name is data, never a pattern (see lib/registry.zsh's reap overlay).
    tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qxF "$1"
}

window_pane_count() {
    tmux list-panes -t "$SESSION:$1" 2>/dev/null | wc -l | tr -d ' '
}

get_bottom_pane() {
    tmux list-panes -t "$SESSION:$1" -F '#{pane_top} #{pane_id}' 2>/dev/null \
        | sort -rn | head -1 | awk '{print $2}'
}

get_left_pane() {
    # Returns the leftmost pane — in the host-first side-by-side layout this is
    # always the Claude/AI pane.
    tmux list-panes -t "$SESSION:$1" -F '#{pane_left} #{pane_id}' 2>/dev/null \
        | sort -n | head -1 | awk '{print $2}'
}

# Count every window except 'host'. The Queen's window (named queen or orchestrator) counts on purpose: while it
# is open, cmd_down's "No repositories left" branch never runs `tmux kill-session`, which would close the Queen.
repository_window_count() {
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
    local repository_dir="$1" field="$2"
    local dc_json="$repository_dir/.devcontainer/devcontainer.json"
    [[ -f "$dc_json" ]] || return 0
    sed 's|^\s*//.*||' "$dc_json" | jq -r ".$field // empty"
}

# Read workspaceFolder and remoteUser from devcontainer.json in one jq pass.
# Sets _dc_workspace (default /workspace) and _dc_user (default empty = root).
_read_devcontainer_exec_config() {
    local repository_dir="$1"
    local dc_json="$repository_dir/.devcontainer/devcontainer.json"
    _dc_workspace="/workspace"
    _dc_user=""
    [[ -f "$dc_json" ]] || return 0
    local out
    out=$(sed 's|^\s*//.*||' "$dc_json" | jq -r '[.workspaceFolder // "/workspace", .remoteUser // ""] | @tsv') || return 0
    _dc_workspace="${out%%	*}"
    _dc_user="${out##*	}"
}

_devcontainer_hash() {
    local repository_dir="$1"
    [[ -d "$repository_dir/.devcontainer" ]] || { echo ""; return 0; }
    local base_id
    base_id=$(docker inspect devcontainer-base:local --format '{{.Id}}' 2>/dev/null || true)
    { find "$repository_dir/.devcontainer" -type f | sort | xargs shasum 2>/dev/null
      printf '%s\n' "$base_id"
    } | shasum | awk '{print $1}'
}

_save_devcontainer_hash() {
    [[ -n "$_dc_hash" ]] || return 0
    mkdir -p "$_dc_hash_dir"
    echo "$_dc_hash" > "$_dc_hash_file"
}

run_initialize_command() {
    local repository_dir="$1"
    local init_cmd
    init_cmd=$(_read_devcontainer_field "$repository_dir" "initializeCommand") || return 0
    [[ -n "$init_cmd" ]] || return 0
    dbg "run_initialize_command: $init_cmd"
    local expanded="${init_cmd//\$\{localWorkspaceFolder\}/$repository_dir}"
    eval "$expanded"
}

run_post_create_command() {
    local repository_name="$1" repository_dir="$2"
    local post_cmd
    post_cmd=$(_read_devcontainer_field "$repository_dir" "postCreateCommand") || return 0
    [[ -n "$post_cmd" ]] || return 0
    local compose="$repository_dir/$COMPOSE_FILE"
    local service
    service=$(get_service_name "$repository_name")
    _read_devcontainer_exec_config "$repository_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    local sentinel="/tmp/.drone-created"
    local exists
    exists=$(docker compose -p "$repository_name" -f "$compose" exec -T "${user_args[@]}" "$service" sh -c "test -f $sentinel && echo yes || echo no" 2>/dev/null) || exists="no"
    if [[ "$exists" == "no" ]]; then
        dbg "run_post_create_command: $post_cmd"
        docker compose -p "$repository_name" -f "$compose" exec -T "${user_args[@]}" -w "$_dc_workspace" "$service" sh -c "$post_cmd"
        docker compose -p "$repository_name" -f "$compose" exec -T "${user_args[@]}" "$service" sh -c "touch $sentinel"
    else
        dbg "run_post_create_command: sentinel exists, skipping"
    fi
}

run_post_start_command() {
    local repository_name="$1" repository_dir="$2"
    local post_cmd
    post_cmd=$(_read_devcontainer_field "$repository_dir" "postStartCommand") || return 0
    [[ -n "$post_cmd" ]] || return 0
    dbg "run_post_start_command: $post_cmd"
    local compose="$repository_dir/$COMPOSE_FILE"
    local service
    service=$(get_service_name "$repository_name")
    _read_devcontainer_exec_config "$repository_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    docker compose -p "$repository_name" -f "$compose" exec -T "${user_args[@]}" -w "$_dc_workspace" "$service" sh -c "$post_cmd"
}

# ── Window management ─────────────────────────────────────────────────────────

create_2pane_window() {
    local wname="$1" main_cmd="${2:-}" start_dir="${3:-$HOME}" right_cmd="${4-__SAME__}"
    # If $4 is unset (legacy callers), default right pane to the same command as the main pane.
    [[ "$right_cmd" == "__SAME__" ]] && right_cmd="$main_cmd"
    dbg "create_2pane_window: '$wname' start_dir=$start_dir"

    local main
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        main=$(tmux new-session -d -s "$SESSION" -n "$wname" -c "$start_dir" -PF '#{pane_id}')
    else
        main=$(tmux new-window -t "$SESSION:" -n "$wname" -c "$start_dir" -PF '#{pane_id}')
    fi

    tmux set-option -t "$SESSION:$wname" automatic-rename off

    # Side-by-side 50/50 — left pane is the Claude pane, right pane is the shell.
    local right
    right=$(tmux split-window -h -p 50 -t "$main" -c "$start_dir" -PF '#{pane_id}')

    # Default focus to left pane (Claude pane)
    tmux select-pane -t "$main"

    [[ -n "$main_cmd"  ]] && tmux send-keys -t "$main"  "$main_cmd"  Enter
    [[ -n "$right_cmd" ]] && tmux send-keys -t "$right" "$right_cmd" Enter

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
    local name="$1" dir="$2"
    dbg "wait_for_container: polling (max 30s)..."
    local i=0 max=30
    while (( i < max )); do
        local c
        c=$(get_repository_container "$name" "$dir")
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

# The claude launch line for a repository pane. An optional session id appends --resume <sid>; callers
# validate it first (borg_resume_valid_sid), so it never needs quoting here.
_drone_claude_cmd() {
    local cmd="claude --model ${BORG_CLAUDE_MODEL:-opus} --effort ${BORG_CLAUDE_EFFORT:-xhigh}"
    [[ -n "${1:-}" ]] && cmd="$cmd --resume $1"
    print -r -- "$cmd"
}

# ── drone up ─────────────────────────────────────────────────────────────────

cmd_up() {
    # Usage: drone up [repository] [--resume <sid>]   (the flag may come before or after the repository)
    local _arg_repository="" resume_sid="" _seen_resume=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --resume)
                [[ $# -ge 2 ]] || die "Usage: drone up [repository] --resume <session-id>"
                resume_sid="$2"; _seen_resume=1; shift 2 ;;
            --resume=*)
                resume_sid="${1#--resume=}"; _seen_resume=1; shift ;;
            -*) die "drone up: unknown option '$1'" ;;
            *)  _arg_repository="$1"; shift ;;
        esac
    done
    if (( _seen_resume )); then
        [[ "$resume_sid" != -* ]] && borg_resume_valid_sid "$resume_sid" || die "drone up: invalid session id for --resume"
    fi
    local claude_cmd
    claude_cmd=$(_drone_claude_cmd "$resume_sid")

    _drone_resolve "$_arg_repository"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"
    local compose="$repository_dir/$COMPOSE_FILE"

    dbg "cmd_up: repository=$repository_name dir=$repository_dir"

    # The window name is registry-owned. A brand-new repository must be registered first or there is
    # nothing to derive from; an existing entry is never re-added here (borg add rewrites tmux_window).
    _drone_registered "$repository_name" || borg add "$repository_dir" --name "$repository_name" 2>/dev/null || true
    local wname live
    wname=$(_drone_window_name "$repository_name")
    live=$(_drone_find_window "$repository_name" "$wname") || live=""
    dbg "cmd_up: window name '$wname' live='$live'"

    local has_devcontainer=0
    [[ -f "$compose" ]] && has_devcontainer=1

    if (( ! has_devcontainer )); then
        # ── No devcontainer: plain local window ──────────────────────────────
        dbg "cmd_up: no .devcontainer, creating local window"

        if [[ -n "$live" ]]; then
            info "Repository '$repository_name' already open."
            [[ -n "$resume_sid" ]] && warn "window already open; --resume ignored (close it first)"
            attach_or_switch "$live"
            return
        fi

        # Host-first: left pane runs claude, right pane is a shell at repository_dir.
        create_2pane_window "$wname" "$claude_cmd" "$repository_dir" ""
        tmux set-option -t "$SESSION:$wname" @project_dir "$repository_dir"
        _drone_apply_window_color "$wname" "$(_drone_repository_color "$repository_name")"
        _drone_register "$repository_dir" "$repository_name" "$wname"
        echo "$repository_name" > "$repository_dir/.borg-project"
        info "Repository '$repository_name' ready (local)."
        attach_or_switch "$wname"
        return
    fi

    # ── Devcontainer path ─────────────────────────────────────────────────────

    ensure_postgres

    # The compose files bind-mount the host resume ledger. Create it first: a missing bind source is
    # created by Docker as root, which the host-side watcher could not then write.
    mkdir -p "$(borg_resume_dir)" 2>/dev/null || true

    # Detect if devcontainer definition changed since last build
    local _dc_hash _dc_hash_dir _dc_hash_file _build_flag=""
    _dc_hash_dir="$(_borg_state_root)/devcontainer-hashes"
    _dc_hash_file="$_dc_hash_dir/${repository_name}.hash"
    _dc_hash=$(_devcontainer_hash "$repository_dir")
    if [[ -n "$_dc_hash" && "$(cat "$(_borg_operational_file "devcontainer-hashes/${repository_name}.hash")" 2>/dev/null)" != "$_dc_hash" ]]; then
        info "Devcontainer definition changed — rebuilding image."
        _build_flag="--build"
    fi

    # Window already exists — check health
    if [[ -n "$live" ]]; then
        local panes
        panes=$(window_pane_count "$live")
        dbg "cmd_up: window '$live' exists with $panes panes"

        if [[ "$panes" != "2" ]]; then
            dbg "cmd_up: wrong pane count, killing window"
            tmux kill-window -t "$SESSION:$live"
            # Fall through to create new window
        else
            local container
            container=$(get_repository_container "$repository_name" "$repository_dir")
            if [[ -z "$container" ]] || [[ -n "$_build_flag" ]]; then
                if [[ -n "$_build_flag" ]]; then
                    info "Rebuilding container for $repository_name..."
                else
                    info "Container stopped. Restarting..."
                fi
                run_initialize_command "$repository_dir"
                _run_pre_up "$repository_dir" "$repository_name"
                docker compose -p "$repository_name" -f "$compose" up -d $_build_flag
                container=$(wait_for_container "$repository_name" "$repository_dir")
                _save_devcontainer_hash
                run_post_create_command "$repository_name" "$repository_dir"
                run_post_start_command "$repository_name" "$repository_dir"
                # Host-side panes are immune to container restart — no re-exec needed.
            fi
            info "Repository '$repository_name' already running."
            [[ -n "$resume_sid" ]] && warn "window already open; --resume ignored (close it first)"
            _drone_apply_window_color "$live" "$(_drone_repository_color "$repository_name")"
            attach_or_switch "$live"
            return
        fi
    fi

    # Create new repository window
    local container
    container=$(get_repository_container "$repository_name" "$repository_dir")
    if [[ -z "$container" ]] || [[ -n "$_build_flag" ]]; then
        info "Starting containers for $repository_name..."
        run_initialize_command "$repository_dir"
        _run_pre_up "$repository_dir" "$repository_name"
        docker compose -p "$repository_name" -f "$compose" up -d $_build_flag
        container=$(wait_for_container "$repository_name" "$repository_dir")
        mkdir -p "$_dc_hash_dir" && [[ -n "$_dc_hash" ]] && echo "$_dc_hash" > "$_dc_hash_file" || true
    fi

    local service
    service=$(get_service_name "$repository_name")
    info "Container: $container  Service: $service"
    run_post_create_command "$repository_name" "$repository_dir"
    run_post_start_command "$repository_name" "$repository_dir"

    # Host-first: both panes are host shells at $repository_dir.
    # Left (Claude) pane auto-launches `claude`; right pane stays as a shell prompt.
    create_2pane_window "$wname" "$claude_cmd" "$repository_dir" ""
    tmux set-option -t "$SESSION:$wname" @project_dir "$repository_dir"
    _drone_apply_window_color "$wname" "$(_drone_repository_color "$repository_name")"
    _drone_register "$repository_dir" "$repository_name" "$wname"
    echo "$repository_name" > "$repository_dir/.borg-project"

    dbg "cmd_up: windows: $(tmux list-windows -t "$SESSION" -F '  #I: #W (#{window_panes} panes)' 2>/dev/null)"

    info "Repository '$repository_name' ready."
    attach_or_switch "$wname"
}

# ── drone down ────────────────────────────────────────────────────────────────

# Deliberate close: tell borg-resume this repository was torn down on purpose. Best-effort and silent; it can never
# fail the teardown. borg-resume itself honors BORG_RESUME_DISABLE. BORG_RESUME_BIN overrides the binary (tests).
_drone_mark_closed() {
    local bin="${BORG_RESUME_BIN:-$DRONE_SCRIPT_DIR/bin/borg-resume}"
    [[ -x "$bin" ]] || return 0
    "$bin" mark-closed "$1" "${2:-}" >/dev/null 2>&1 || true
    return 0
}

cmd_down() {
    _drone_resolve "${1:-}"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"
    local compose="$repository_dir/$COMPOSE_FILE"

    _drone_mark_closed "$repository_name" "$repository_dir"
    dbg "cmd_down: repository=$repository_name dir=$repository_dir"

    local live
    if tmux has-session -t "$SESSION" 2>/dev/null \
        && live=$(_drone_find_window "$repository_name" "$(_drone_window_name "$repository_name")"); then
        info "Removing window '$live'."
        tmux kill-window -t "$SESSION:$live"
    fi

    rm -f "$repository_dir/.borg-project"

    if [[ -f "$compose" ]]; then
        info "Stopping containers for $repository_name..."
        docker compose -p "$repository_name" -f "$compose" down
        _run_post_down "$repository_dir" "$repository_name"
    fi

    # Second mark: a dying claude may have written its own session_end after the first one (sticky-close rule).
    _drone_mark_closed "$repository_name" "$repository_dir"

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        local remaining
        remaining=$(repository_window_count)
        dbg "cmd_down: $remaining repository windows remaining"
        if (( remaining == 0 )); then
            info "No repositories left. Stopping postgres and killing session."
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
_cycle_repository() {
    local repository_name="$1" repository_dir="$2" mode="${3:-restart}"
    local compose="$repository_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || { warn "$repository_name: no $COMPOSE_FILE, skipping"; return 0; }

    # Transient down during restart/rebuild intentionally does NOT fire
    # post-down.sh — external stacks (e.g. Supabase) should persist across cycles.
    if [[ "$mode" == "rebuild" ]]; then
        info "Rebuilding $repository_name (no cache)..."
        docker compose -p "$repository_name" -f "$compose" down
        docker compose -p "$repository_name" -f "$compose" build --no-cache
    else
        info "Restarting $repository_name..."
        docker compose -p "$repository_name" -f "$compose" down
    fi
    _run_pre_up "$repository_dir" "$repository_name"
    docker compose -p "$repository_name" -f "$compose" up -d

    local container
    container=$(wait_for_container "$repository_name" "$repository_dir")

    if [[ "$mode" == "rebuild" ]]; then
        local _dc_hash _dc_hash_dir _dc_hash_file
        _dc_hash_dir="$(_borg_state_root)/devcontainer-hashes"
        _dc_hash_file="$_dc_hash_dir/${repository_name}.hash"
        _dc_hash=$(_devcontainer_hash "$repository_dir")
        _save_devcontainer_hash
    fi
    run_post_create_command "$repository_name" "$repository_dir"
    run_post_start_command "$repository_name" "$repository_dir"

    # Host-side panes are immune to container restart — no pane refresh needed.
    info "$repository_name: ${mode}ed."
}

_restart_repository() { _cycle_repository "$1" "$2" "restart"; }
_rebuild_repository() { _cycle_repository "$1" "$2" "rebuild"; }

# The Queen's window is "queen" since the rename; sessions started before it keep "orchestrator".
_is_non_repository_window() { [[ "$1" == "queen" || "$1" == "orchestrator" || "$1" == "host" ]]; }

# Shared --all iterator: walks every repository window (not host, queen or orchestrator) and calls op_func.
# Pinned, with `fix --all`, by tests/drone_all_skips_queen.bats.
_foreach_repository_window() {
    local op_func="$1" past_tense="$2"
    tmux has-session -t "$SESSION" 2>/dev/null || die "No $SESSION tmux session running."

    local windows
    windows=(${(f)"$(tmux list-windows -t "$SESSION" -F '#W')"})

    local count=0
    for wname in $windows; do
        _is_non_repository_window "$wname" && continue
        local pdir
        pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || true
        if [[ -z "$pdir" ]]; then
            warn "$wname: no @project_dir set, skipping"
            continue
        fi
        # The op takes a REPOSITORY name (docker compose -p, hooks), never a window name.
        "$op_func" "$(_drone_repository_of "$wname")" "$pdir"
        count=$(( count + 1 ))
    done
    info "${past_tense} $count repository(ies)."
}

# Shared dispatch: handles --all, tmux current-window fallback, and named arg.
_cmd_cycle() {
    local mode="$1" arg="${2:-}"

    if [[ "$arg" == "--all" ]]; then
        local past_tense
        [[ "$mode" == "rebuild" ]] && past_tense="Rebuilt" || past_tense="Restarted"
        _foreach_repository_window "_${mode}_repository" "$past_tense"
        return
    fi

    if [[ -z "$arg" && -n "$TMUX" ]]; then
        local current_window pdir
        current_window=$(tmux display-message -p '#W')
        pdir=$(tmux show-option -t "$SESSION:$current_window" -v @project_dir 2>/dev/null) || true
        if [[ -n "$pdir" && -d "$pdir" ]]; then
            _cycle_repository "$(_drone_repository_of "$current_window")" "$pdir" "$mode"
            return
        fi
    fi

    _drone_resolve "$arg"
    _cycle_repository "$_proj_name" "$_proj_dir" "$mode"
}

cmd_restart() { _cmd_cycle "restart" "${1:-}"; }
cmd_rebuild()  { _cmd_cycle "rebuild" "${1:-}"; }

# ── drone claude ──────────────────────────────────────────────────────────────

cmd_claude() {
    _drone_resolve "${1:-}"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"

    dbg "cmd_claude: repository=$repository_name dir=$repository_dir"

    # If no window exists, drone up creates it AND auto-launches claude in the right pane.
    local wname
    wname=$(_drone_window_name "$repository_name")
    if ! wname=$(_drone_find_window "$repository_name" "$wname"); then
        info "$repository_name: no window found, running drone up first..."
        cmd_up "${1:-}"
        wname=$(_drone_window_name "$repository_name")
        wname=$(_drone_find_window "$repository_name" "$wname") || true
    fi

    # Reattach: only send `claude` if the pane is at a shell prompt — avoids
    # typing "claude" into a running Claude REPL.
    local claude_pane current_cmd
    claude_pane=$(get_left_pane "$wname")
    current_cmd=$(tmux display-message -p -t "$claude_pane" '#{pane_current_command}' 2>/dev/null)
    case "$current_cmd" in
        zsh|bash|sh|fish|dash|"")
            info "Launching Claude in $repository_name..."
            tmux send-keys -t "$claude_pane" "claude --model ${BORG_CLAUDE_MODEL:-opus} --effort ${BORG_CLAUDE_EFFORT:-xhigh}" Enter
            ;;
        *)
            info "Claude pane already busy ($current_cmd) — focusing without relaunch."
            ;;
    esac

    # Switch to the repository window, focus + zoom Claude pane
    attach_or_switch "$wname"
    _drone_apply_window_color "$wname" "$(_drone_repository_color "$repository_name")"
    tmux select-pane -t "$claude_pane"
    tmux resize-pane -Z -t "$claude_pane"
}

# ── drone cortex ──────────────────────────────────────────────────────────────

cmd_cortex() {
    _drone_resolve "${1:-}"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"

    dbg "cmd_cortex: repository=$repository_name dir=$repository_dir"

    local wname
    wname=$(_drone_window_name "$repository_name")
    if ! wname=$(_drone_find_window "$repository_name" "$wname"); then
        info "$repository_name: no window found, running drone up first..."
        cmd_up "${1:-}"
        wname=$(_drone_window_name "$repository_name")
        wname=$(_drone_find_window "$repository_name" "$wname") || true
    fi

    local claude_pane
    claude_pane=$(get_left_pane "$wname")
    info "Launching Cortex in $repository_name (left pane)..."
    tmux send-keys -t "$claude_pane" "cortex" Enter
    tmux set-option -t "$SESSION:$wname" @cortex_launched 1

    attach_or_switch "$wname"
    _drone_apply_window_color "$wname" "$(_drone_repository_color "$repository_name")"
    tmux select-pane -t "$claude_pane"
    tmux resize-pane -Z -t "$claude_pane"
}

# ── drone feature ──────────────────────────────────────────────────────────────

cmd_feature() {
    local feature="${2:-}"
    [[ -z "$feature" ]] && die "Usage: drone feature <repository> <branch>"
    _drone_resolve "${1:-}"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"
    local window_name="${repository_name}-${feature}"
    local work_dir="${repository_dir%/*}/${repository_name}-${feature}"

    if has_window "$window_name"; then
        info "Already open: $window_name"
        attach_or_switch "$window_name"
        return
    fi

    if [[ ! -d "$work_dir" ]]; then
        if git -C "$repository_dir" show-ref --verify --quiet "refs/heads/$feature" 2>/dev/null; then
            git -C "$repository_dir" worktree add "$work_dir" "$feature"
        else
            git -C "$repository_dir" worktree add -b "$feature" "$work_dir"
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
        tmux set-option -t "$SESSION:$window_name" @project_name "$repository_name"
        borg add "$work_dir" 2>/dev/null || true
        local claude_pane
        claude_pane=$(get_left_pane "$window_name")
        tmux send-keys -t "$claude_pane" "claude --model ${BORG_CLAUDE_MODEL:-opus} --effort ${BORG_CLAUDE_EFFORT:-xhigh}" Enter
        attach_or_switch "$window_name"
        tmux select-pane -t "$claude_pane"
        tmux resize-pane -Z -t "$claude_pane"
    fi
    info "Started: $window_name"
}

# ── drone sh ──────────────────────────────────────────────────────────────────

cmd_sh() {
    _drone_resolve "${1:-}"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"
    local compose="$repository_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || die "No $COMPOSE_FILE found in $repository_dir"

    local service
    service=$(get_service_name "$repository_name")
    [[ -n "$service" ]] || die "No running app container found for $repository_name. Run: drone up $repository_name"

    _read_devcontainer_exec_config "$repository_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")
    exec docker compose -p "$repository_name" -f "$compose" exec "${user_args[@]}" -w "$_dc_workspace" "$service" "${shell:-/bin/zsh}"
}

# ── drone exec ────────────────────────────────────────────────────────────────

# Run a non-interactive command inside the repository's devcontainer.
# Usage: drone exec [repository] -- <cmd> [args...]
#
# Container-down behavior is fail-loud-and-self-heal: if the container is not
# running, prints a clear message, brings the container up (no tmux work), and
# retries the command exactly once. Exit code passes through.
cmd_exec() {
    local repository_arg=""
    if [[ "${1:-}" == "--" ]]; then
        :
    elif [[ -n "${1:-}" ]]; then
        repository_arg="$1"
        shift
    fi
    [[ "${1:-}" == "--" ]] || die "Usage: drone exec [repository] -- <cmd> [args...]"
    shift
    [[ $# -gt 0 ]] || die "Usage: drone exec [repository] -- <cmd> [args...]"

    _drone_resolve "$repository_arg"
    local repository_name="$_proj_name"
    local repository_dir="$_proj_dir"
    local compose="$repository_dir/$COMPOSE_FILE"

    [[ -f "$compose" ]] || die "No $COMPOSE_FILE found in $repository_dir"

    _read_devcontainer_exec_config "$repository_dir"
    local -a user_args=()
    [[ -n "$_dc_user" ]] && user_args=(-u "$_dc_user")

    local container service
    container=$(get_repository_container "$repository_name" "$repository_dir")
    if [[ -z "$container" ]]; then
        warn "$repository_name: container down — running drone up"
        ensure_postgres
        run_initialize_command "$repository_dir"
        _run_pre_up "$repository_dir" "$repository_name"
        docker compose -p "$repository_name" -f "$compose" up -d
        container=$(wait_for_container "$repository_name" "$repository_dir")
        run_post_create_command "$repository_name" "$repository_dir"
        run_post_start_command "$repository_name" "$repository_dir"
    fi
    service=$(get_service_name "$repository_name")
    [[ -n "$service" ]] || die "$repository_name: no app service found"

    docker compose -p "$repository_name" -f "$compose" exec -T "${user_args[@]}" -w "$_dc_workspace" "$service" "$@"
}

# ── drone fix ─────────────────────────────────────────────────────────────────

cmd_fix() {
    tmux has-session -t "$SESSION" 2>/dev/null || die "No $SESSION tmux session running."

    local targets=()
    if [[ "${1:-}" == "--all" ]]; then
        local -a all_windows=(${(f)"$(tmux list-windows -t "$SESSION" -F '#W')"})
        local w
        for w in $all_windows; do
            _is_non_repository_window "$w" || targets+=("$w")
        done
    elif [[ -n "${1:-}" ]]; then
        targets=("$(_drone_arg_window "$1")")
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
        wname=$(_drone_arg_window "$1")
    elif [[ -n "$TMUX" ]]; then
        wname=$(tmux display-message -p '#W')
    else
        die "Specify a repository name or run from inside tmux."
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
            # If this is a devcontainer repository, exec into the container
            local pdir
            pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || true
            if [[ -n "$pdir" && -f "$pdir/$COMPOSE_FILE" ]]; then
                local container shell service exec_cmd pname
                pname=$(_drone_repository_of "$wname")
                container=$(get_repository_container "$pname" "$pdir") || true
                if [[ -n "$container" ]]; then
                    shell=$(get_shell "$container")
                    service=$(get_service_name "$pname")
                    exec_cmd=$(build_exec_cmd "$pname" "$pdir/$COMPOSE_FILE" "$service" "$shell" "$pdir")
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

# ── drone pane ────────────────────────────────────────────────────────────────

cmd_pane() {
    local direction="${1:-}"
    [[ -n "$direction" ]] || die "Specify a direction: top, bottom, left, or right."

    local flags
    case "$direction" in
        top)    flags="-v -b" ;;
        bottom) flags="-v" ;;
        left)   flags="-h -b" ;;
        right)  flags="-h" ;;
        *)      die "Invalid direction '$direction'. Use: top, bottom, left, or right." ;;
    esac

    [[ -n "$TMUX" ]] || die "Not inside a tmux session. Run 'drone pane' from within tmux."

    # Split the CALLING pane, not the active one. tmux sets $TMUX_PANE in every process it
    # starts inside a pane, so an agent running here targets its own window even when the
    # user is looking at a different one. Without -t, split-window and '#W' both resolve to
    # whatever window currently has focus (2026-09-23: a draft opened in the wrong drone).
    local target="${TMUX_PANE:-}"
    [[ -n "$target" ]] || target=$(tmux display-message -p '#{pane_id}')

    local wname
    wname=$(tmux display-message -t "$target" -p '#W')

    # Two panes per window, period (Noah, 2026-09-23). If a side pane already exists, reuse
    # it: print its id and stop, so the caller sends its command there instead of splitting.
    local existing
    existing=$(tmux list-panes -t "$target" -F '#{pane_id}' | grep -vx "$target" | head -1)
    if [[ -n "$existing" ]]; then
        local zoomed note=""
        zoomed=$(tmux display-message -t "$target" -p '#{window_zoomed_flag}')
        if [[ "$zoomed" == "1" ]]; then
            # Zoom is a toggle: only call it when the flag says the side pane is hidden.
            tmux resize-pane -Z -t "$target"
            note=", unzoomed"
        fi
        info "$wname: reusing existing side pane $existing (two panes per window$note)"
        print -- "$existing"
        return 0
    fi

    local new_pane
    new_pane=$(tmux split-window ${=flags} -t "$target" -PF '#{pane_id}')

    # If this is a devcontainer repository, exec into the container (same logic as cmd_toggle);
    # otherwise just cd into the repository dir.
    local pdir
    pdir=$(tmux show-option -t "$SESSION:$wname" -v @project_dir 2>/dev/null) || true
    if [[ -n "$pdir" && -f "$pdir/$COMPOSE_FILE" ]]; then
        local container shell service exec_cmd pname
        pname=$(_drone_repository_of "$wname")
        container=$(get_repository_container "$pname" "$pdir") || true
        if [[ -n "$container" ]]; then
            shell=$(get_shell "$container")
            service=$(get_service_name "$pname")
            exec_cmd=$(build_exec_cmd "$pname" "$pdir/$COMPOSE_FILE" "$service" "$shell" "$pdir")
            tmux send-keys -t "$new_pane" "$exec_cmd" Enter
        fi
    elif [[ -n "$pdir" ]]; then
        tmux send-keys -t "$new_pane" "cd $pdir" Enter
    fi

    info "$wname: new pane opened ($direction)"
}

# ── drone scaffold --supabase ─────────────────────────────────────────────────

# Generate a Supabase-ready devcontainer from templates/supabase/, substituting
# __PROJECT_NAME__ / __PROJECT_NAME_UPPER__ / __WORKSPACE__. Runs `supabase init`
# in the repository dir when supabase/ doesn't already exist. Refuses if
# .devcontainer/ or supabase/ already exists (no --force in v1).
_cmd_scaffold_supabase() {
    local repository_dir="$1" workspace="$2"
    _scaffold_preflight "$repository_dir"
    repository_dir="$_sp_dir"
    local dc_dir="$repository_dir/.devcontainer"

    [[ -d "$repository_dir/supabase" ]] \
        && die "supabase/ already exists in $repository_dir — refusing to overwrite"
    command -v supabase >/dev/null 2>&1 \
        || die "supabase CLI not found on PATH. Install: brew install supabase/tap/supabase"

    local repository_name="${repository_dir##*/}"
    local repository_name_upper
    repository_name_upper="${repository_name:u}"
    repository_name_upper="${repository_name_upper//-/_}"

    local tmpl_dir="$DRONE_SCRIPT_DIR/templates/supabase"
    [[ -d "$tmpl_dir" ]] || die "Template directory missing: $tmpl_dir"

    info "Scaffolding Supabase devcontainer for '$repository_name'..."
    mkdir -p "$dc_dir/borg-hooks"

    local ws_symlink
    ws_symlink=$(_ws_symlink_snippet "$workspace")

    _subst_template() {
        sed -e "s|__PROJECT_NAME__|$repository_name|g" \
            -e "s|__PROJECT_NAME_UPPER__|$repository_name_upper|g" \
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

    info "Running 'supabase init' in $repository_dir..."
    (cd "$repository_dir" && supabase init) || die "supabase init failed"

    # Confirm project_id in supabase/config.toml matches repository_name. Supabase's
    # default is the directory name, which already matches, but sed-confirm to
    # be safe against future CLI changes.
    local config="$supabase_dir/config.toml"
    if [[ -f "$config" ]]; then
        local current_id
        current_id=$(grep -E '^project_id = ' "$config" | head -1 | sed -E 's/project_id = "([^"]+)"/\1/')
        if [[ -n "$current_id" && "$current_id" != "$repository_name" ]]; then
            info "Aligning supabase project_id ($current_id → $repository_name)..."
            sed -i.bak -E "s/^project_id = \"[^\"]+\"/project_id = \"$repository_name\"/" "$config"
            rm -f "$config.bak"
        fi
    fi

    info "Scaffolded Supabase repository in $repository_dir"
    echo
    info "Next steps:"
    info "  1. drone up $repository_name"
    info "  2. Create remote project: supabase login && supabase projects create $repository_name"
    info "  3. Link: supabase link --project-ref <ref>"
}

# ── drone scaffold --supabase-shared ────────────────────────────────────────────

# Generate a devcontainer that JOINS the always-on shared stillpoint Supabase
# stack (network `supabase_network_stillpoint`) instead of creating a
# per-repository network + running its own `supabase init`/`start`. Does NOT
# alter --supabase semantics — this is a wholly separate opt-in path.
_cmd_scaffold_supabase_shared() {
    local repository_dir="$1" workspace="$2" schema="$3"
    _scaffold_preflight "$repository_dir"
    repository_dir="$_sp_dir"
    local dc_dir="$repository_dir/.devcontainer"

    local repository_name="${repository_dir##*/}"
    local repository_name_upper
    repository_name_upper="${repository_name:u}"
    repository_name_upper="${repository_name_upper//-/_}"

    # Schema defaults to the repository name (schema-per-app convention); pass
    # --schema explicitly if the repository's schema already differs.
    [[ -z "$schema" ]] && schema="${repository_name//-/_}"

    local tmpl_dir="$DRONE_SCRIPT_DIR/templates/supabase-shared"
    [[ -d "$tmpl_dir" ]] || die "Template directory missing: $tmpl_dir"

    info "Scaffolding shared-Supabase devcontainer for '$repository_name' (schema: $schema)..."
    mkdir -p "$dc_dir/borg-hooks"

    local ws_symlink
    ws_symlink=$(_ws_symlink_snippet "$workspace")

    _subst_template() {
        sed -e "s|__PROJECT_NAME__|$repository_name|g" \
            -e "s|__PROJECT_NAME_UPPER__|$repository_name_upper|g" \
            -e "s|__WORKSPACE__|$workspace|g" \
            -e "s|__WS_SYMLINK__|$ws_symlink|g" \
            -e "s|__SCHEMA__|$schema|g" \
            "$1" > "$2"
    }

    _subst_template "$tmpl_dir/Dockerfile"          "$dc_dir/Dockerfile"
    _subst_template "$tmpl_dir/docker-compose.yml"  "$dc_dir/docker-compose.yml"
    _subst_template "$tmpl_dir/devcontainer.json"   "$dc_dir/devcontainer.json"
    cp "$tmpl_dir/borg-hooks/pre-up.sh"   "$dc_dir/borg-hooks/pre-up.sh"
    cp "$tmpl_dir/borg-hooks/post-down.sh" "$dc_dir/borg-hooks/post-down.sh"
    chmod +x "$dc_dir/borg-hooks/pre-up.sh" "$dc_dir/borg-hooks/post-down.sh"

    _scaffold_append_claude_md "$repository_dir" "$schema"

    info "Scaffolded shared-Supabase repository in $repository_dir"
    echo
    info "Joins the ALWAYS-ON shared stillpoint stack (network: supabase_network_stillpoint)."
    info "The shared stack is started/stopped independently — see stillpoint repo."
    info "Next steps:"
    info "  1. drone up $repository_name"
}

# Append the "Local Supabase — ONE shared stack" doc block to the scaffolded
# repository's CLAUDE.md, substituting the real schema. Creates CLAUDE.md if it
# doesn't exist yet; otherwise appends with a blank-line separator. Idempotent:
# a no-op if the block (matched by its heading) is already present.
_scaffold_append_claude_md() {
    local repository_dir="$1" schema="$2"
    local claude_md="$repository_dir/CLAUDE.md"
    local heading="## Local Supabase — ONE shared stack (never boot a per-project stack)"

    if [[ -f "$claude_md" ]] && grep -qF "$heading" "$claude_md"; then
        info "CLAUDE.md already has the shared-Supabase block — skipping"
        return 0
    fi

    local block
    block=$(cat <<EOF
$heading

Local dev for every Stillpoint repository shares a SINGLE always-on Supabase stack owned by the
\`stillpoint\` repo — one Postgres (\`supabase_db_stillpoint\` / gateway \`supabase_kong_stillpoint\`)
with a schema per app. This repository's rows live under the \`$schema\` schema via \`search_path\`, never
\`public\`. The devcontainer attaches to the external network \`supabase_network_stillpoint\`;
\`.devcontainer/borg-hooks/pre-up.sh\` brings the shared stack up once (idempotent) on \`drone up\`.
This repository has NO local stack of its own.

The API URL (\`supabase_kong_stillpoint:8000\`) only serves auth, storage, and realtime on the
\`public\` schema — the shared stack's PostgREST exposes just \`public\` and \`graphql_public\`. This
repository's own \`$schema\` schema is reachable through the DB URL only. Expanding exposed schemas is a
deliberate change in the \`stillpoint\` repo's \`supabase/config.toml\` plus a shared-stack restart —
never something to do from this repo.

**Never run these from this repo** — they boot or kill a COMPETING local stack that collides on
ports 54321/54322 and takes the shared stack down for every repository:

- \`supabase start\` · \`supabase stop\` · \`supabase db reset\` — boot/kill the local stack
- \`docker stop|kill|rm\` of any \`supabase_*_stillpoint\` container

A PreToolUse guard (\`borg-supabase-guard.sh\`) blocks the above from any non-\`stillpoint\` directory.
To reset or reseed LOCAL data, do it from the \`stillpoint\` repo (\`~/dev/stillpoint\`), which owns the
stack. Commands against **Supabase Cloud** (\`supabase db push\`, \`supabase migration …\` with
\`--project-ref\`) are unaffected.
EOF
)

    if [[ -f "$claude_md" ]]; then
        printf '\n%s\n' "$block" >> "$claude_md"
    else
        printf '%s\n' "$block" > "$claude_md"
    fi
    info "Appended shared-Supabase block to CLAUDE.md"
}

# ── drone scaffold ────────────────────────────────────────────────────────────

cmd_scaffold() {
    local repository_dir="" lang="none" workspace="" preset="" schema=""
    local workspace_explicit=0

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)     lang="${2:-none}"; shift 2 ;;
            --workspace) workspace="${2:-}"; workspace_explicit=1; shift 2 ;;
            --supabase) preset="supabase"; shift ;;
            --supabase-shared) preset="supabase-shared"; shift ;;
            --schema)   schema="${2:-}"; shift 2 ;;
            *)          repository_dir="$1"; shift ;;
        esac
    done

    [[ -z "$repository_dir" ]] && die "Usage: drone scaffold <repository-dir> [--supabase|--supabase-shared [--schema <name>]] [--lang python|node|none] [--workspace /workspaces/<repository>]"

    # Default workspace from raw basename; the supabase branches run their own preflight.
    if (( ! workspace_explicit )); then
        local _raw_basename="${repository_dir%/}"
        _raw_basename="${_raw_basename##*/}"
        workspace="/workspaces/$_raw_basename"
    fi

    if [[ "$preset" == "supabase" ]]; then
        _cmd_scaffold_supabase "$repository_dir" "$workspace"
        return
    fi

    if [[ "$preset" == "supabase-shared" ]]; then
        _cmd_scaffold_supabase_shared "$repository_dir" "$workspace" "$schema"
        return
    fi

    _scaffold_preflight "$repository_dir"
    repository_dir="$_sp_dir"
    local dc_dir="$repository_dir/.devcontainer"
    local repository_name="${repository_dir##*/}"
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
            dockerfile_extra='# Add repository-specific deps here if needed'
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
    # Profile split: ${repository_name}-app (base, always starts, no borg mounts)
    # and ${repository_name}-borg (extends base, adds borg mounts, profiles: [borg]).
    # drone sets COMPOSE_PROFILES=borg automatically; Cursor/team users start
    # ${repository_name}-app by default and get a fully working container without
    # requiring host borg/claude config to be present.
    cat > "$dc_dir/docker-compose.yml" <<COMPOSE
services:
  # ── Base service — team-portable, no borg mounts ──────────────────────────
  ${repository_name}-app:
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
    volumes:
      # repository files
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
  # Host-first Claude: ~/.claude is no longer mounted; Claude runs on the host
  # and dispatches into this container via \`drone exec\`.
  ${repository_name}-borg:
    extends:
      service: ${repository_name}-app
    labels:
      - dev.role=app
    volumes:
      - ~/.config/borg:/home/dev/.config/borg:cached
      # borg-resume ledger (append-only events from in-container hooks). Only this dir, never ~/.claude.
      - ~/.local/state/borg/resume:/home/dev/.local/state/borg/resume
    profiles:
      - borg

volumes:
  claude_npm:  # persists npm globals (claude-code, cortex) across image rebuilds

networks:
  devnet:
    external: true
COMPOSE

    # ── devcontainer.json ─────────────────────────────────────────────────
    # Host-first Claude: container is a `drone exec` target; claude itself runs
    # on the host. postCreateCommand only sets up dev shell + language deps.
    local post_create="ln -sf /home/dev/.config/dotfiles/zsh/.zshrc /home/dev/.zshrc; ln -sf /home/dev/.config/dotfiles/zsh/.p10k.zsh /home/dev/.p10k.zsh"
    case "$lang" in
        python) post_create="$post_create; pip install -e '.[dev]'" ;;
        node)   post_create="$post_create; npm install" ;;
    esac

    local ws_symlink
    ws_symlink=$(_ws_symlink_snippet "$workspace")

    cat > "$dc_dir/devcontainer.json" <<DEVCONTAINER
{
  "name": "${repository_name}",
  "dockerComposeFile": "docker-compose.yml",
  "service": "${repository_name}-borg",
  "workspaceFolder": "${workspace}",
  "features": {},
  "postCreateCommand": "${post_create}",
  "postStartCommand": "sudo mkdir -p /Users && sudo ln -sfn /home/dev /Users/noah; sudo chmod a+rw /run/host-services/ssh-auth.sock 2>/dev/null || true; ln -sf /home/dev/.config/dotfiles/zsh/.zshrc /home/dev/.zshrc; ln -sf /home/dev/.config/dotfiles/zsh/.p10k.zsh /home/dev/.p10k.zsh${ws_symlink}",
  "shutdownAction": "stopCompose",
  "remoteUser": "dev",
  "updateRemoteUserUID": true
}
DEVCONTAINER

    info "Scaffolded .devcontainer/ in $repository_dir"
    info "  Language: $lang"
    info "  Workspace: $workspace"
    echo
    info "Next steps:"
    info "  1. Verify base image exists: docker images devcontainer-base:local"
    info "  2. If missing, build it:"
    info "     docker build -f ~/.config/dotfiles/devcontainer/Dockerfile.base -t devcontainer-base:local ~/.config/dotfiles/devcontainer"
    info "  3. drone up $repository_name"
}

# ── drone help ────────────────────────────────────────────────────────────────

cmd_help() {
    cat <<'EOF'

    _______________
   /|             /|
  / |            / |      drone — designation: repository lifecycle
    |___________|  |
    |  |        |  |      "You will be assimilated."
    |  |________|__|
    | /         | /
    |/          |/

  COMMANDS
    feature <repository> <branch>  Create worktree + branch, start window, launch Claude
    up [repository]      Start container + create tmux window (uses $PWD if no arg)
    up [repository] --resume <sid>
                         Same, relaunching claude --resume <sid>. Compose files bind-mount the host
                         resume ledger; an existing drone gets the mount only after drone down + up
    down [repository]    Stop container + remove tmux window
    claude [repository]  Launch Claude Code in repository window (runs drone up if needed)
    cortex [repository]  Launch Cortex Code in repository window (runs drone up if needed)
    sh [repository]      Shell into repository container (interactive)
    exec [repository] -- <cmd>
                         Run a non-interactive command inside the devcontainer
                         (fail-loud-and-self-heal if container is down)
    restart [repository] Restart containers + re-exec all panes
    restart --all        Restart all repository containers
    rebuild [repository] Rebuild images (--no-cache) + restart + re-exec panes
    rebuild --all        Rebuild all repository containers
    fix [repository]     Restore standard 2-pane layout for repository window
    fix --all            Restore layout for all repository windows
    toggle [repository]  Add/remove side pane (2-pane ↔ 3-pane)
    pane <direction>     Split the calling pane top|bottom|left|right (devcontainer-aware); a window holds
                         two panes, so with a side pane open it reuses that pane (unzooming the window if
                         it is zoomed, so the side pane is visible) and prints its id
    scaffold <dir>       Generate .devcontainer/ (--lang python|node|none, --supabase, --supabase-shared)
    help                 Show this message

  REPOSITORY RESOLUTION
    drone up             Uses current directory (backwards-compatible with dev.sh)
    drone up troth       Looks up 'troth' in borg registry, then $BORG_ORCHESTRATOR_ROOT/troth

  WINDOW LAYOUT
    Top    (75%): main editor / Claude session
    Bottom (25%): logs / output
    Toggle adds a top-right side terminal (30% split)

  ENVIRONMENT
    BORG_TMUX_SESSION    tmux session name (default: borg)
    BORG_ORCHESTRATOR_ROOT  workspace root for repository lookup (default: ~/dev)
    BORG_DEBUG           set to any value for debug output

EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

dbg "dispatch: args='${*}'"
dbg "dispatch: SESSION=$SESSION"

# A registry that still has only the retired `projects` key must fail loudly here, not read as empty.
case "${1:-}" in
    help|-h|scaffold) ;;
    *) borg_registry_guard "${BORG_REGISTRY:-$BORG_DIR/registry.json}" || exit 1 ;;
esac

case "${1:-}" in
    feature)    cmd_feature "${2:-}" "${3:-}" ;;
    up)         shift; cmd_up "$@" ;;
    down)       cmd_down "${2:-}" ;;
    claude)     cmd_claude "${2:-}" ;;
    cortex)     cmd_cortex "${2:-}" ;;
    sh)         cmd_sh "${2:-}" ;;
    exec)       shift; cmd_exec "$@" ;;
    restart)    cmd_restart "${2:-}" ;;
    rebuild)    cmd_rebuild "${2:-}" ;;
    fix)        cmd_fix "${2:-}" ;;
    toggle)     cmd_toggle "${2:-}" ;;
    pane)       cmd_pane "${2:-}" ;;
    scaffold)   shift; cmd_scaffold "$@" ;;
    link)       exec borg link "${2:-${PWD##*/}}" "${@:3}" ;;
    help|-h)    cmd_help ;;
    *)          die "unknown command '${1}'. Run: drone help" ;;
esac
