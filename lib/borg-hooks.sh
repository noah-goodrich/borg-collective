#!/usr/bin/env bash
# lib/borg-hooks.sh — shared helpers for borg hook scripts (bash)

# Resolve project name by walking up from CWD looking for a .borg-project marker.
# drone up writes this file so container sessions (where CWD is /development/...)
# can be mapped back to the correct registry key.
# Falls back to basename of the directory, which works for host sessions.
_borg_find_project() {
    local dir="$1"
    while [[ "$dir" != "/" && -n "$dir" ]]; do
        if [[ -f "$dir/.borg-project" ]]; then
            cat "$dir/.borg-project"
            return 0
        fi
        dir="${dir%/*}"
    done
    basename "$1"
}

# Strip raw ASCII control characters that break jq parsing.
# Tab (0x09), LF (0x0A), CR (0x0D) are kept; jq escapes them in string values.
# Use as a pipe filter: `... | _borg_strip_ctl` or wrap a value: `_borg_strip_ctl <<<"$x"`
_borg_strip_ctl() {
    tr -d '\000-\010\013\014\016-\037'
}
