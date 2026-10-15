#!/usr/bin/env zsh
# lib/launchd-agents.zsh -- what `borg setup` says about launchd agents it does not install.
# Needs warn() (borg.zsh) and _borg_launchd_label (lib/launchd-label.zsh); borg.zsh sources both.

# Warn (never install) when a shipped launchd agent is not loaded. install.sh is the ONLY installer of the plists in
# $BORG_HOME/launchd/, and `borg setup` runs on machines that never ran it (docs/upgrading.md section 4), which left
# those machines with no resume watcher and `borg doctor` failing on it. Labels come from the one resolver. The gate
# is `launchctl` being on PATH, not uname: the binary exists only on macOS, and a test can stub it.
_borg_warn_unloaded_agents() {
    command -v launchctl &>/dev/null || return 0
    local plist agent missing=()
    for plist in "$BORG_HOME/launchd/"borg.*.plist(N); do
        agent="${${plist:t}#borg.}"
        agent="${agent%.plist}"
        launchctl list "$(_borg_launchd_label "$agent")" &>/dev/null || missing+=("$agent")
    done
    (( ${#missing[@]} )) || return 0
    warn "launchd agents not loaded: ${(j:, :)missing}. Run ./install.sh from the borg-collective checkout to install them (skip any you opted out of)."
    return 0
}
