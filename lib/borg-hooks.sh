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

# Classify the session by its working directory.
# Returns the literal string "orchestrator" when $1 exactly matches
# $BORG_ORCHESTRATOR_ROOT (default $HOME/dev), "project" otherwise. Exact
# match only — descendant directories of the workspace root are project
# sessions. Trailing slashes on both sides are trimmed before comparison.
# Side-effect free; safe to call from any hook.
# Usage: _borg_session_mode <cwd>
_borg_session_mode() {
    local cwd="$1"
    local root="${BORG_ORCHESTRATOR_ROOT:-$HOME/dev}"
    # Trim any trailing slashes so "/Users/noah/dev/" matches "/Users/noah/dev"
    while [[ "$cwd" == */ && "$cwd" != "/" ]]; do cwd="${cwd%/}"; done
    while [[ "$root" == */ && "$root" != "/" ]]; do root="${root%/}"; done
    if [[ "$cwd" == "$root" ]]; then
        printf 'orchestrator\n'
    else
        printf 'project\n'
    fi
}

# ─── Per-project state helpers ───────────────────────────────────────────────
# Volatile session state (status, last_activity, claude_session_id,
# has_uncommitted_changes, waiting_reason, notify_origin) lives in
# <project_dir>/.borg/state.json. This keeps the shared registry as a pure
# discovery index — only stable identity fields (path, source, tmux_window,
# summary, pinned, archived) remain there.

# Machine-local operational state root: ${XDG_STATE_HOME:-$HOME/.local/state}/borg (blank == unset).
# Siblings: lib/state-root.zsh and borg_core/paths.py::state_root -- keep all three identical.
_borg_state_root() {
    printf '%s/borg\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

# First 12 hex of sha256 over stdin (shasum on macOS, sha256sum elsewhere).
_borg_sha12() {
    { shasum -a 256 2>/dev/null || sha256sum; } | cut -c1-12
}

# Key naming one project DIRECTORY's machine-local state: <repo12>-<path12>, or local-<path12> outside a git
# repo. path12 = sha256 of the PHYSICAL directory path (pwd -P, no trailing slash); repo12 = sha256 of
# `git rev-parse --path-format=absolute --git-common-dir`. Per directory (worktrees of one repo can be in
# different statuses at once), namespaced by repo. Siblings, byte-identical: borg_core/paths.py::
# project_state_key and the other shell copy. Rationale lives in the Python docstring.
# Usage: _borg_project_state_key <dir>
_borg_project_state_key() {
    local _d="${1:?_borg_project_state_key: dir required}" _phys _repo _tail="" _base _anc
    while [ "${#_d}" -gt 1 ] && [ "${_d%/}" != "$_d" ]; do _d="${_d%/}"; done
    # A missing directory still resolves like Python's realpath: physicalise the deepest existing ancestor.
    _anc="$_d"
    while [ -n "$_anc" ] && [ ! -d "$_anc" ]; do
        _base="${_anc##*/}"
        _tail="/$_base$_tail"
        case "$_anc" in
            */*) _anc="${_anc%/*}" ;;
            *) _anc="." ;;
        esac
    done
    _phys="$(cd "${_anc:-/}" 2>/dev/null && pwd -P)" || _phys="$_d"
    [ "$_phys" = "/" ] && _phys=""
    _phys="$_phys$_tail"
    [ -n "$_phys" ] || _phys="/"
    _repo="$(git -C "$_phys" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || _repo=""
    if [ -n "$_repo" ]; then
        printf '%s-%s\n' "$(printf '%s' "$_repo" | _borg_sha12)" "$(printf '%s' "$_phys" | _borg_sha12)"
    else
        printf 'local-%s\n' "$(printf '%s' "$_phys" | _borg_sha12)"
    fi
}

# <state root>/projects/<key>/state.json for a project directory. Creates nothing.
# Usage: _borg_project_state_file <dir>
_borg_project_state_file() {
    printf '%s/projects/%s/state.json\n' "$(_borg_state_root)" "$(_borg_project_state_key "${1:?_borg_project_state_file: dir required}")"
}

# Resolve an operational file for READING: the state root's copy if it exists, else the old
# config-dir location ($BORG_DIR, else ${XDG_CONFIG_HOME:-$HOME/.config}/borg). Expand phase of the
# config -> state-root move: readers accept both before any writer moves. Neither existing prints
# the OLD path, so callers' absent handling is unchanged. Reader-only; writers must not call this.
# Usage: _borg_operational_file <name>     (name may contain a subdir, e.g. recon/last-run)
_borg_operational_file() {
    local _new
    _new="$(_borg_state_root)/${1:?_borg_operational_file: name required}"
    if [ -e "$_new" ]; then
        printf '%s\n' "$_new"
    else
        printf '%s/%s\n' "${BORG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/borg}" "$1"
    fi
}

# Log retention: cap an append-only log at BORG_LOG_CAP_BYTES, keeping ONE previous generation.
# Cap = 1 MiB: roughly 8,000 memory-hits rows or 2,000 agents.jsonl rows -- months of history at
# today's write rates, so a history reader loses nothing it uses, while the worst case per log is
# 2 MiB (file + .1). One generation, not N: the fewest moving parts that still bounds disk.
# Siblings: borg_core/retention.py::rotate_log (Python). Same contract: size >= cap rotates.
# Call it IMMEDIATELY BEFORE the append, so the live file exists again as soon as the write lands
# (tail -n 1 readers such as usage-samples.jsonl never see a missing file after a write).
# Usage: _borg_rotate_log <file> [cap_bytes]
# Returns: 0 always; silent on every path (fail-open -- a hook's stdout is JSON).
# Race: two concurrent writers may both rotate, costing at most the older generation.
_borg_rotate_log() {
    local _f="${1:-}" _cap="${2:-${BORG_LOG_CAP_BYTES:-1048576}}" _size
    { [ -n "$_f" ] && [ -f "$_f" ] && [ ! -L "$_f" ]; } 2>/dev/null || return 0
    case "$_cap" in ''|*[!0-9]*) _cap=1048576 ;; esac
    _size="$(wc -c < "$_f" 2>/dev/null | tr -d ' ')" || return 0
    case "$_size" in ''|*[!0-9]*) return 0 ;; esac
    [ "$_size" -ge "$_cap" ] 2>/dev/null || return 0
    { mv -f "$_f" "$_f.1"; } 2>/dev/null || true
    return 0
}

# Canonical path to a project's state file.
# Usage: _borg_state_file <project_dir>
_borg_state_file() {
    printf '%s/.borg/state.json\n' "${1:?_borg_state_file: dir required}"
}

# Read state.json; emit '{}' when the file does not exist yet.
# Usage: _borg_state_read <project_dir>
_borg_state_read() {
    local sf
    sf=$(_borg_state_file "$1")
    if [[ -f "$sf" ]]; then
        cat "$sf"
    else
        printf '{}\n'
    fi
}

# Return the canonical project directory for state.json. Prefers the registry's
# registered path for the project (so host-path state.json is used even from a
# container session). Falls back to CWD when the registry path is absent or the
# directory doesn't exist on disk.
# Reads $BORG_REGISTRY from the calling hook's environment.
# Usage: PROJ_DIR=$(_borg_resolve_proj_dir "$PROJECT" "$CWD")
_borg_resolve_proj_dir() {
    local project="$1" cwd="$2" rp
    if [[ -f "$BORG_REGISTRY" ]]; then
        rp=$(jq -r --arg p "$project" '.projects[$p].path // ""' "$BORG_REGISTRY" 2>/dev/null || true)
        [[ -n "$rp" && "$rp" != "null" && -d "$rp" ]] && { printf '%s\n' "$rp"; return; }
    fi
    printf '%s\n' "$cwd"
}

# Atomic write — strip control chars, reject empty result, tmp+mv.
# Usage: _borg_state_write <project_dir> <json>
_borg_state_write() {
    local dir="$1" json="$2"
    local sf
    sf=$(_borg_state_file "$dir")
    mkdir -p "${sf%/*}"
    local tmp="${sf}.tmp.$$"
    printf '%s' "$json" | tr -d '\000-\010\013\014\016-\037' > "$tmp"
    [[ -s "$tmp" ]] || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$sf"
}

# Reaper predicate: sourced from lib/reaper.sh (single home shared with registry.zsh).
#
# This file is sourced by BOTH bash hooks and the zsh binaries bin/borg-notifyd and
# bin/borg-cortex-watch. zsh has no BASH_SOURCE, so a bare "${BASH_SOURCE[0]}" expanded to
# nothing there, sourced "/reaper.sh", and killed both agents with exit 127 on every fire --
# while `launchctl list` reported them registered. zsh sets $0 to the sourced file's path, and
# bash sets BASH_SOURCE[0], so the ":-" default covers both (verified under `set -u` in each).
source "$(dirname "${BASH_SOURCE[0]:-$0}")/reaper.sh"

# Snapshot of live tmux window names (one per line). Empty when tmux is down.
# Honors BORG_TMUX_SESSION (default "borg"), matching lib/tmux.zsh.
_borg_live_windows() {
    local session="${BORG_TMUX_SESSION:-borg}"
    command -v tmux >/dev/null 2>&1 || return 0
    tmux has-session -t "$session" 2>/dev/null || return 0
    tmux list-windows -t "$session" -F '#W' 2>/dev/null || true
}
