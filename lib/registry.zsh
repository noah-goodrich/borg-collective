#!/usr/bin/env zsh
# lib/registry.zsh — registry CRUD for ~/.config/borg/registry.json
#
# Registry is a pure discovery index: path, source, tmux_window, summary,
# pinned, archived. Volatile session state (status, last_activity,
# claude_session_id, has_uncommitted_changes, waiting_reason, notify_origin)
# lives in per-project .borg/state.json files.
# Use borg_registry_with_state / borg_registry_get_with_state for reads that
# need volatile fields (borg ls, borg status, borg next, etc.).

# Source shared reaper predicate (single home; also sourced by lib/borg-hooks.sh).
source "${${(%):-%x}:A:h}/reaper.sh"

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"
BORG_LOCK="$BORG_DIR/.registry.lock"

borg_registry_init() {
    /bin/mkdir -p "$BORG_DIR"
    if [[ ! -f "$BORG_REGISTRY" ]]; then
        echo '{"projects":{}}' > "$BORG_REGISTRY"
    fi
}

# Atomic write — reject empty data, strip raw control chars that break jq parsing.
# Tab (0x09), LF (0x0A), CR (0x0D) are kept; jq escapes them in string values anyway.
_borg_registry_write() {
    local tmp="$BORG_REGISTRY.tmp.$$"
    /bin/cat | tr -d '\000-\010\013\014\016-\037' > "$tmp"
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
            summary: null
        }')

    borg_registry_merge "$project" "$json"
}

borg_registry_remove() {
    local project="$1"
    borg_registry_read | jq --arg p "$project" 'del(.projects[$p])' | _borg_registry_write
}

# Update status + last_activity timestamp in the project's state.json.
# Deprecated: prefer writing to state.json directly from hooks. Kept for
# backward-compat callers (e.g. tests).
borg_registry_set_status() {
    local project="$1" proj_status="$2"
    local now ppath cur new
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    ppath=$(borg_registry_read | jq -r --arg p "$project" '.projects[$p].path // ""')
    if [[ -z "$ppath" || "$ppath" == "null" ]]; then
        return 0
    fi
    cur=$(borg_state_read "$ppath")
    new=$(printf '%s' "$cur" | jq --arg s "$proj_status" --arg t "$now" \
        '.status = $s | .last_activity = $t')
    borg_state_write "$ppath" "$new"
}

# ─── Per-project state helpers (zsh) ─────────────────────────────────────────
# Mirrors the bash helpers in lib/borg-hooks.sh; keep signatures in sync.

borg_state_file() {
    printf '%s/.borg/state.json\n' "${1:?borg_state_file: dir required}"
}

# Read state.json; return '{}' when the file does not exist yet.
borg_state_read() {
    local sf
    sf=$(borg_state_file "$1")
    if [[ -f "$sf" ]]; then
        /bin/cat "$sf"
    else
        printf '{}\n'
    fi
}

# Atomic write — strip control chars, reject empty result, tmp+mv.
borg_state_write() {
    local dir="$1" json="$2"
    local sf
    sf=$(borg_state_file "$dir")
    /bin/mkdir -p "${sf:h}"
    local tmp="${sf}.tmp.$$"
    printf '%s' "$json" | tr -d '\000-\010\013\014\016-\037' > "$tmp"
    [[ -s "$tmp" ]] || { /bin/rm -f "$tmp"; return 1; }
    /bin/mv "$tmp" "$sf"
}

# Read the full registry and overlay each project's state.json fields on top.
# Returns the same JSON shape as borg_registry_read but with volatile fields
# (status, last_activity, claude_session_id, has_uncommitted_changes,
# waiting_reason, notify_origin) populated from state.json where it exists.
# Projects without a state.json retain whatever the registry holds for those
# fields (typically from legacy data or borg scan seeding).
#
# The reaper overlay runs last (display-path, non-destructive): any project that
# is active/waiting with no live-session evidence is downgraded to "idle" in the
# returned JSON only — state.json on disk is untouched. `borg reap` does the
# durable persist. Pass a non-empty BORG_NO_REAP to skip the overlay (used by
# `borg reap` itself, which needs the un-downgraded view to decide what to write).
borg_registry_with_state() {
    local raw result name ppath state
    raw=$(borg_registry_read)
    result="$raw"
    while IFS=$'\t' read -r name ppath; do
        [[ -z "$name" || -z "$ppath" || "$ppath" == "null" ]] && continue
        [[ -f "$ppath/.borg/state.json" ]] || continue
        state=$(/bin/cat "$ppath/.borg/state.json" 2>/dev/null || true)
        [[ -z "$state" ]] && continue
        result=$(printf '%s' "$result" | jq \
            --arg p "$name" \
            --argjson s "$state" \
            '(.projects[$p].status == "archived") as $arch |
             .projects[$p] += $s |
             if $arch then .projects[$p].status = "archived" else . end' \
            2>/dev/null) || result="$result"
    done < <(printf '%s' "$raw" \
        | jq -r '.projects | to_entries[] | [.key, (.value.path // "")] | @tsv' 2>/dev/null)
    # Default status to "idle" for any project that has neither a state.json nor a registry status
    result=$(printf '%s\n' "$result" | jq '.projects |= with_entries(.value.status //= "idle")')
    if [[ -z "${BORG_NO_REAP:-}" ]]; then
        result=$(printf '%s' "$result" | borg_reap_overlay)
    fi
    printf '%s\n' "$result"
}

# Like borg_registry_get but overlays state.json for the named project.
borg_registry_get_with_state() {
    local project="$1"
    borg_registry_with_state | jq -c --arg p "$project" '.projects[$p] // empty'
}

# ─── Reaper: downgrade stale active/waiting sessions to idle ──────────────────
# Snapshot of live tmux window names (one per line). Empty when tmux is down or
# the helper isn't loaded (registry.zsh may be sourced standalone by tests).
_borg_live_windows() {
    whence -w borg_tmux_windows &>/dev/null || return 0
    borg_tmux_windows 2>/dev/null || true
}

# Filter: read registry-with-state JSON on stdin, emit the same JSON with every
# reapable project's status downgraded to "idle". Non-destructive — operates on
# the JSON stream only. The original status is preserved under ._reaped_from so
# callers can report what was auto-downgraded.
borg_reap_overlay() {
    local json live_windows name tw st last live
    json=$(/bin/cat)
    live_windows=$(_borg_live_windows)
    # Emit a sentinel ("-") for any empty trailing field. zsh `read` with a
    # whitespace IFS (tab is whitespace) collapses consecutive separators, so an
    # empty tmux_window/last_activity column would shift all following fields
    # left. The jq default-then-sentinel keeps every column populated; the loop
    # maps the sentinels back to empty/derived values.
    while IFS=$'\t' read -r name tw st last; do
        [[ -z "$name" ]] && continue
        # tmux window defaults to the project name when the registry leaves it null
        [[ "$tw" == "-" || -z "$tw" || "$tw" == "null" ]] && tw="$name"
        [[ "$last" == "-" ]] && last=""
        live=0
        if [[ -n "$live_windows" ]] && printf '%s\n' "$live_windows" | /usr/bin/grep -qx "$tw"; then
            live=1
        fi
        if _borg_should_reap "$st" "$last" "$live"; then
            json=$(printf '%s' "$json" | jq \
                --arg p "$name" \
                --arg from "$st" \
                '.projects[$p]._reaped_from = $from | .projects[$p].status = "idle"' \
                2>/dev/null) || true
        fi
    done < <(printf '%s' "$json" | jq -r '
        .projects | to_entries[]
        | select(.value.status == "active" or .value.status == "waiting")
        | [.key,
           (if (.value.tmux_window // "") == "" then "-" else .value.tmux_window end),
           .value.status,
           (if (.value.last_activity // "") == "" then "-" else .value.last_activity end)]
        | @tsv' 2>/dev/null)
    printf '%s' "$json"
}

# Persist reaping to disk: for every project the reaper would downgrade, write
# status=idle into its state.json (atomic tmp+mv via borg_state_write). Emits one
# line per reaped project: "<name>\t<old-status>". Idempotent — a no-op on a
# project with no live window but already idle, and on live/recent sessions.
borg_reap_persist() {
    local overlaid name ppath from cur new count=0
    # Build the overlay against the *un-reaped* view so _reaped_from is populated.
    overlaid=$(BORG_NO_REAP=1 borg_registry_with_state | borg_reap_overlay)
    while IFS=$'\t' read -r name from; do
        [[ -z "$name" ]] && continue
        ppath=$(printf '%s' "$overlaid" | jq -r --arg p "$name" '.projects[$p].path // ""')
        [[ -z "$ppath" || "$ppath" == "null" ]] && continue
        [[ -f "$ppath/.borg/state.json" ]] || continue
        cur=$(borg_state_read "$ppath")
        new=$(printf '%s' "$cur" | jq '.status = "idle"')
        borg_state_write "$ppath" "$new" || continue
        printf '%s\t%s\n' "$name" "$from"
        count=$((count + 1))
    done < <(printf '%s' "$overlaid" | jq -r '
        .projects | to_entries[]
        | select(.value._reaped_from != null)
        | [.key, .value._reaped_from] | @tsv' 2>/dev/null)
    return 0
}

# Should this scanned path be skipped instead of registered as a new project?
# Skip when:
#   - empty path
#   - path is the workspace root itself (e.g. ~/dev)
#   - path no longer exists on disk (renamed / deleted folders)
#   - path is a subpath of an already-registered project (e.g. nested template dirs
#     that show up in session history because Claude was invoked from inside them)
# Returns 0 = skip, 1 = register.
borg_scan_path_should_skip() {
    local ppath="$1"
    [[ -n "$ppath" ]] || return 0
    [[ "$ppath" == "${BORG_ORCHESTRATOR_ROOT:-$HOME/dev}" ]] && return 0
    [[ -d "$ppath" ]] || return 0
    local rp
    while IFS= read -r rp; do
        [[ -z "$rp" ]] && continue
        [[ "$ppath" == "$rp"/* ]] && return 0
    done < <(jq -r '.projects[].path // empty' "$BORG_REGISTRY" 2>/dev/null)
    return 1
}
