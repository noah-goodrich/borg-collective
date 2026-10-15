#!/usr/bin/env zsh
# lib/coco.zsh — session discovery from ~/.snowflake/cortex/conversations/
#
# Mirrors lib/claude.zsh for Cortex Code CLI (CoCo). Cortex 1.2.14 writes one `<uuid>.json` (metadata, one line,
# carrying `working_directory`, `session_type`, `last_updated`) and one `<uuid>.history.jsonl` (the transcript)
# per session into conversations/. It writes no `projects/` directory and no `session-log.md`; the readers of
# those two were the only consumers of them, so they went with them. Subagent sessions (`session_type`
# "subagent") are children of a main session and are skipped, so only a session a person started counts.
# A file that does not parse, or has no working_directory, is skipped silently.

# PATH is set by borg.zsh before sourcing this file

COCO_CONVERSATIONS_DIR="$HOME/.snowflake/cortex/conversations"

# The jq filter: a main session's working directory, else nothing.
_BORG_COCO_CWD_JQ='select(type == "object" and .session_type != "subagent" and (.working_directory | type) == "string")
    | .working_directory'

# Print the working directory of one conversation metadata file ("" when unusable).
_borg_coco_file_cwd() {
    jq -r "$_BORG_COCO_CWD_JQ" "$1" 2>/dev/null | head -n 1
}

# Find the most recently modified main session whose working directory is the repository path.
# Returns just the session UUID (no extension)
borg_coco_latest_session_id() {
    local repo="${1%/}" f cwd
    [[ -d "$COCO_CONVERSATIONS_DIR" ]] || return 0
    # (N) nullglob, (.) plain files, (om) newest first
    for f in "$COCO_CONVERSATIONS_DIR"/*.json(N.om); do
        cwd=$(_borg_coco_file_cwd "$f")
        if [[ -n "$cwd" && "${cwd%/}" == "$repo" ]]; then
            echo "${${f:t}%.json}"
            return 0
        fi
    done
    return 0
}

# Return full path to the history transcript for a session
borg_coco_session_jsonl() {
    local session_id="$2"
    echo "$COCO_CONVERSATIONS_DIR/${session_id}.history.jsonl"
}

# Return the latest history transcript path for a repository
borg_coco_latest_jsonl() {
    local repo="$1"
    local session_id
    session_id=$(borg_coco_latest_session_id "$repo")
    [[ -n "$session_id" ]] || return 0
    borg_coco_session_jsonl "$repo" "$session_id"
}

# Every distinct working directory a main session was started in, one absolute path per line.
borg_coco_scan_session_log() {
    [[ -d "$COCO_CONVERSATIONS_DIR" ]] || return 0
    local f cwd
    for f in "$COCO_CONVERSATIONS_DIR"/*.json(N.); do
        cwd=$(_borg_coco_file_cwd "$f")
        [[ "$cwd" == /* ]] && echo "${cwd%/}"
    done | sort -u
    return 0
}
