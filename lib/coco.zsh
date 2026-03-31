#!/usr/bin/env zsh
# lib/coco.zsh — session discovery from ~/.snowflake/cortex/projects/
#
# Mirrors lib/claude.zsh for Cortex Code CLI (CoCo). All functions follow
# the identical pattern with borg_coco_* prefix and CoCo-specific paths.

# PATH is set by borg.zsh before sourcing this file

COCO_PROJECTS_DIR="$HOME/.snowflake/cortex/projects"
COCO_SESSION_LOG="$HOME/.snowflake/cortex/session-log.md"

# Convert /Users/noah/dev/cairn → -Users-noah-dev-cairn
borg_coco_encode_path() {
    local path="${1%/}"  # strip trailing slash
    echo "${path//\//-}"
}

# Return the ~/.snowflake/cortex/projects directory for a given project path
borg_coco_project_dir() {
    local path="$1"
    local encoded
    encoded=$(borg_coco_encode_path "$path")
    echo "$COCO_PROJECTS_DIR/$encoded"
}

# Find the most recently modified JSONL file for a project path
# Returns just the session UUID (no extension)
borg_coco_latest_session_id() {
    local path="$1"
    local dir
    dir=$(borg_coco_project_dir "$path")
    [[ -d "$dir" ]] || return 0
    # Use zsh glob qualifiers: (N) nullglob, (Om) sort by mod time desc, ([1]) first only
    local files=("$dir"/*.jsonl(NOm[1]))
    [[ ${#files[@]} -eq 0 ]] && return 0
    local fname="${files[1]:t}"   # :t = tail (basename)
    echo "${fname%.jsonl}"        # strip extension
}

# Return full path to the JSONL transcript for a session
borg_coco_session_jsonl() {
    local path="$1" session_id="$2"
    local dir
    dir=$(borg_coco_project_dir "$path")
    echo "$dir/${session_id}.jsonl"
}

# Return the latest JSONL transcript path for a project
borg_coco_latest_jsonl() {
    local path="$1"
    local session_id
    session_id=$(borg_coco_latest_session_id "$path")
    [[ -n "$session_id" ]] || return 0
    borg_coco_session_jsonl "$path" "$session_id"
}

# Parse ~/.snowflake/cortex/session-log.md and return unique project paths
# Format: "- 2026-03-17 08:25 | /path/to/project | session:uuid"
borg_coco_scan_session_log() {
    [[ -f "$COCO_SESSION_LOG" ]] || return 0
    /usr/bin/awk -F'|' '/^\-/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 ~ /^\//) print $2 }' \
        "$COCO_SESSION_LOG" | /usr/bin/sort -u
}

# Check if a project path has any CoCo sessions
borg_coco_has_sessions() {
    local path="$1"
    local dir
    dir=$(borg_coco_project_dir "$path")
    [[ -d "$dir" ]] && ls "$dir"/*.jsonl &>/dev/null
}
