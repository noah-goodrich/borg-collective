#!/usr/bin/env zsh
# lib/claude.zsh — session discovery from ~/.claude/projects/

# Ensure PATH is available when sourced in non-interactive contexts
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
CLAUDE_SESSION_LOG="$HOME/.claude/session-log.md"

# Convert /Users/noah/dev/cairn → -Users-noah-dev-cairn
borg_claude_encode_path() {
    local path="${1%/}"  # strip trailing slash
    echo "${path//\//-}"
}

# Return the ~/.claude/projects directory for a given project path
borg_claude_project_dir() {
    local path="$1"
    local encoded
    encoded=$(borg_claude_encode_path "$path")
    echo "$CLAUDE_PROJECTS_DIR/$encoded"
}

# Find the most recently modified JSONL file for a project path
# Returns just the session UUID (no extension)
borg_claude_latest_session_id() {
    local path="$1"
    local dir
    dir=$(borg_claude_project_dir "$path")
    [[ -d "$dir" ]] || return 0
    # Use zsh glob qualifiers: (N) nullglob, (Om) sort by mod time desc, ([1]) first only
    local files=("$dir"/*.jsonl(NOm[1]))
    [[ ${#files[@]} -eq 0 ]] && return 0
    local fname="${files[1]:t}"   # :t = tail (basename)
    echo "${fname%.jsonl}"        # strip extension
}

# Return full path to the JSONL transcript for a session
borg_claude_session_jsonl() {
    local path="$1" session_id="$2"
    local dir
    dir=$(borg_claude_project_dir "$path")
    echo "$dir/${session_id}.jsonl"
}

# Return the latest JSONL transcript path for a project
borg_claude_latest_jsonl() {
    local path="$1"
    local session_id
    session_id=$(borg_claude_latest_session_id "$path")
    [[ -n "$session_id" ]] || return 0
    borg_claude_session_jsonl "$path" "$session_id"
}

# Parse ~/.claude/session-log.md and return unique project paths
# Format: "- 2026-03-17 08:25 | /path/to/project | session:uuid"
borg_claude_scan_session_log() {
    [[ -f "$CLAUDE_SESSION_LOG" ]] || return 0
    /usr/bin/awk -F'|' '/^\-/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 ~ /^\//) print $2 }' \
        "$CLAUDE_SESSION_LOG" | /usr/bin/sort -u
}

# Check if a project path has any Claude sessions
borg_claude_has_sessions() {
    local path="$1"
    local dir
    dir=$(borg_claude_project_dir "$path")
    [[ -d "$dir" ]] && ls "$dir"/*.jsonl &>/dev/null
}
