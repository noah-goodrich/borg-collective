#!/usr/bin/env zsh
# lib/launchd-label.zsh — THE resolver for borg's launchd agent labels.
#
# Written in bash/zsh-common syntax on purpose (`local`, `[ ]`, printf, awk; no zsh-isms):
# borg.zsh sources it through the lib/*.zsh loop, install.sh sources it explicitly, and the bats
# suite sources it under bash to pin that it stays portable. There is exactly one copy of the
# prefix logic, and this is it. Anything that needs a label (installer, `borg doctor`, a test)
# calls _borg_launchd_label; nothing spells a label out by hand.
#
# Contract (shared with the dotfiles repo, which implements the same one for its own agents):
#
#   prefix  = $LAUNCHD_LABEL_PREFIX when set and non-blank,
#             else the first non-blank line of ${XDG_CONFIG_HOME:-$HOME/.config}/launchd-prefix,
#             else empty. Surrounding whitespace (including CR) is trimmed either way.
#   label   = <prefix>.borg.<agent>   when a prefix resolved
#           = borg.<agent>            when none did
#
# With `com.stillpoint-labs` in the prefix file the labels are byte-identical to the ones that
# were hardcoded before this file existed; with no file they are `borg.notifyd` and friends.
# Installed plist filename in ~/Library/LaunchAgents is always `<label>.plist`.

# Trim leading/trailing whitespace from stdin and print the first non-blank line.
_borg_launchd_trim() {
    awk 'NF { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print; exit }'
}

# Print the resolved prefix, or nothing when there is none. Exit 0 either way.
_borg_launchd_prefix() {
    local prefix="" prefix_file=""
    if [ -n "${LAUNCHD_LABEL_PREFIX:-}" ]; then
        prefix=$(printf '%s\n' "$LAUNCHD_LABEL_PREFIX" | _borg_launchd_trim)
    fi
    if [ -z "$prefix" ]; then
        prefix_file="${XDG_CONFIG_HOME:-$HOME/.config}/launchd-prefix"
        if [ -r "$prefix_file" ]; then
            prefix=$(_borg_launchd_trim < "$prefix_file")
        fi
    fi
    printf '%s\n' "$prefix"
    return 0
}

# Usage: _borg_launchd_label <agent>     e.g. _borg_launchd_label notifyd
# Prints `<prefix>.borg.<agent>` or `borg.<agent>`.
_borg_launchd_label() {
    local agent="$1" prefix=""
    if [ -z "$agent" ]; then
        echo "_borg_launchd_label: agent name required" >&2
        return 1
    fi
    prefix=$(_borg_launchd_prefix)
    if [ -n "$prefix" ]; then
        printf '%s.borg.%s\n' "$prefix" "$agent"
    else
        printf 'borg.%s\n' "$agent"
    fi
}
