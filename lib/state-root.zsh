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
