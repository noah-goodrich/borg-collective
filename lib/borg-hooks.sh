#!/usr/bin/env bash
# lib/borg-hooks.sh — shared helpers for borg hook scripts (bash)

# Sync source file to destination using mtime comparison (copy strategy, no symlinks).
# Removes a stale symlink at dst before comparing. No-ops when dst is already current.
# Usage: _borg_sync_file <src> <dst>
# Returns: 0 always (errors suppressed — hook-safe).
_borg_sync_file() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || return 0
    [[ -L "$dst" ]] && rm -f "$dst"
    if [[ ! -f "$dst" ]] || [[ "$src" -nt "$dst" ]]; then
        cp "$src" "$dst" 2>/dev/null || true
    fi
}

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

# Append per-environment extension CLAUDE.md to ~/.claude/CLAUDE.md.
# Idempotent: strips and re-appends the extension block on each call so
# borg-link-down.sh can call it after every CLAUDE.md re-sync without duplicating.
_borg_apply_claude_extensions() {
    local dst="$HOME/.claude/CLAUDE.md"
    local ext_claude="${XDG_CONFIG_HOME:-$HOME/.config}/borg/extensions/CLAUDE.md"
    local marker="<!-- borg-extensions -->"

    [[ -f "$ext_claude" && -f "$dst" ]] || return 0

    # Strip any existing extension block (marker to EOF)
    if grep -q "$marker" "$dst" 2>/dev/null; then
        local tmp="$dst.ext.$$"
        awk -v m="$marker" '$0 == m {exit} {print}' "$dst" > "$tmp" && mv "$tmp" "$dst"
    fi

    # Append fresh extension block
    { printf '\n%s\n' "$marker"; cat "$ext_claude"; } >> "$dst"
}

# True when the current process is inside a container. Matches bash-guard's detection
# (Docker marker plus podman/buildah's /run/.containerenv) so all hooks classify origin
# consistently across runtimes.
_borg_is_container() {
    [[ -f /.dockerenv || -f /run/.containerenv ]]
}

# Fire a macOS user notification. Uses osascript, which posts via Apple-signed
# System Events and renders reliably on macOS 26. Replaced terminal-notifier 2.0.0,
# which was ad-hoc signed and silently dropped by Notification Center.
# Click-to-focus is not available here — tmux bell + `Ctrl+Space >` covers switching.
# Usage: _borg_osa_notify <title> <subtitle> <message>
_borg_osa_notify() {
    local title="$1" subtitle="$2" message="$3"
    # Escape backslash first, then double quote, for AppleScript string literal context.
    title="${title//\\/\\\\}";       title="${title//\"/\\\"}"
    subtitle="${subtitle//\\/\\\\}"; subtitle="${subtitle//\"/\\\"}"
    message="${message//\\/\\\\}";   message="${message//\"/\\\"}"
    local script="display notification \"$message\" with title \"$title\""
    [[ -n "$subtitle" ]] && script+=" subtitle \"$subtitle\""
    script+=" sound name \"Glass\""
    osascript -e "$script" 2>/dev/null || true
}

# Strip raw ASCII control characters that break jq parsing.
# Tab (0x09), LF (0x0A), CR (0x0D) are kept; jq escapes them in string values.
# Use as a pipe filter: `... | _borg_strip_ctl` or wrap a value: `_borg_strip_ctl <<<"$x"`
_borg_strip_ctl() {
    tr -d '\000-\010\013\014\016-\037'
}
