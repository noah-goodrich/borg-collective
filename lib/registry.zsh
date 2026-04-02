#!/usr/bin/env zsh
# lib/registry.zsh — registry CRUD for ~/.config/borg/registry.json

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"
BORG_LOCK="$BORG_DIR/.registry.lock"

borg_registry_init() {
    /bin/mkdir -p "$BORG_DIR"
    if [[ ! -f "$BORG_REGISTRY" ]]; then
        echo '{"projects":{}}' > "$BORG_REGISTRY"
    fi
}

# Atomic write — reject empty data to prevent registry wipeouts
_borg_registry_write() {
    local tmp="$BORG_REGISTRY.tmp.$$"
    /bin/cat > "$tmp"
    if [[ ! -s "$tmp" ]]; then
        warn "registry write blocked: refusing to write empty file"
        /bin/rm -f "$tmp"
        return 1
    fi
    /bin/mv "$tmp" "$BORG_REGISTRY"
}

borg_registry_read() {
    borg_registry_init
    /bin/cat "$BORG_REGISTRY"
}

borg_registry_list() {
    borg_registry_read | jq -r '.projects | keys[]' 2>/dev/null
}

borg_registry_get() {
    local project="$1"
    borg_registry_read | jq -c --arg p "$project" '.projects[$p] // empty'
}

borg_registry_has() {
    local project="$1"
    borg_registry_read | jq -e --arg p "$project" '.projects | has($p)' &>/dev/null
}

# Set a single key on a project entry
borg_registry_set() {
    local project="$1" key="$2" value="$3"
    borg_registry_read | jq \
        --arg p "$project" \
        --arg k "$key" \
        --argjson v "$value" \
        '.projects[$p][$k] = $v' | _borg_registry_write
}

# Merge a JSON object into a project entry (upserts all fields)
borg_registry_merge() {
    local project="$1" json="$2"
    borg_registry_read | jq \
        --arg p "$project" \
        --argjson data "$json" \
        'if .projects[$p] then .projects[$p] += $data else .projects[$p] = $data end' \
        | _borg_registry_write
}

borg_registry_add() {
    local project="$1"
    local ppath="${2:-null}"
    local source="${3:-cli}"
    local tmux_session="${4:-null}"
    local tmux_window="${5:-null}"

    local json
    json=$(jq -n \
        --arg path "$ppath" \
        --arg source "$source" \
        --argjson tmux_session "$([ "$tmux_session" = "null" ] && echo 'null' || echo "\"$tmux_session\"")" \
        --argjson tmux_window "$([ "$tmux_window" = "null" ] && echo 'null' || echo "\"$tmux_window\"")" \
        '{
            path: (if $path == "null" then null else $path end),
            source: $source,
            tmux_session: $tmux_session,
            tmux_window: $tmux_window,
            claude_session_id: null,
            last_activity: null,
            status: "unknown",
            summary: null
        }')

    borg_registry_merge "$project" "$json"
}

borg_registry_remove() {
    local project="$1"
    borg_registry_read | jq --arg p "$project" 'del(.projects[$p])' | _borg_registry_write
}

# Update status + last_activity timestamp
borg_registry_set_status() {
    local project="$1" proj_status="$2"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    borg_registry_read | jq \
        --arg p "$project" \
        --arg s "$proj_status" \
        --arg t "$now" \
        '.projects[$p].status = $s | .projects[$p].last_activity = $t' | _borg_registry_write
}
