#!/usr/bin/env zsh
# lib/state-root.zsh — THE zsh resolver for borg's machine-local operational state root.
#
# Contract (one definition per language, all three identical):
#
#   state root = ${XDG_STATE_HOME:-$HOME/.local/state}/borg     (blank XDG_STATE_HOME == unset)
#
# Siblings: borg_core/paths.py::state_root (Python) and lib/borg-hooks.sh::_borg_state_root (bash).
# borg.zsh sources only lib/*.zsh, so the zsh copy lives here. Written in bash/zsh-common syntax so
# the bats suite can also source it under bash. `:-` treats set-but-empty as unset, which is the
# blank rule.

# Usage: _borg_state_root     Prints the state root on one line.
_borg_state_root() {
    printf '%s/borg\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
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

# First 12 hex of sha256 over stdin (shasum on macOS, sha256sum elsewhere).
_borg_sha12() {
    { shasum -a 256 2>/dev/null || sha256sum; } | cut -c1-12
}

# Key naming one project DIRECTORY's machine-local state: <repo12>-<path12>, or local-<path12> outside a git
# repo. path12 = sha256 of the PHYSICAL directory path (pwd -P, no trailing slash); repo12 = sha256 of
# `git rev-parse --path-format=absolute --git-common-dir`. Per directory (worktrees of one repo can be in
# different statuses at once), namespaced by repo. Siblings, byte-identical: borg_core/paths.py::
# project_state_key and the other shell copy. Rationale lives in the Python docstring.
# Usage: _borg_project_state_key <dir> [repo]
# The optional 2nd arg (even empty) is the registry entry's `repo` field: it replaces the git fork, and
# empty means outside git (path-only key). Omit it to fork git. Python sibling: project_state_key(dir, repo).
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
    if [ "${2+set}" = set ]; then
        _repo="$2"
    else
        _repo="$(git -C "$_phys" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || _repo=""
    fi
    if [ -n "$_repo" ]; then
        printf '%s-%s\n' "$(printf '%s' "$_repo" | _borg_sha12)" "$(printf '%s' "$_phys" | _borg_sha12)"
    else
        printf 'local-%s\n' "$(printf '%s' "$_phys" | _borg_sha12)"
    fi
}

# <state root>/projects/<key>/state.json for a project directory. Creates nothing.
# Usage: _borg_project_state_file <dir> [repo]    (repo: see _borg_project_state_key)
_borg_project_state_file() {
    printf '%s/projects/%s/state.json\n' "$(_borg_state_root)" "$(_borg_project_state_key "${1:?_borg_project_state_file: dir required}" ${2+"$2"})"
}
