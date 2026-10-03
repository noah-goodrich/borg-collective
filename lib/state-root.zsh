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
