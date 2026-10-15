# launchd labels and extension agents

Rules moved verbatim from the top-level CLAUDE.md. They live here rather than in launchd/ because a launchd/CLAUDE.md would be a seventh file in the plist directory, which tests/launchd_label.bats counts.

- **launchd labels are resolved, never spelled out**: `lib/launchd-label.zsh` is the one resolver.
  `_borg_launchd_label <agent>` returns `<prefix>.borg.<agent>` when a prefix resolves, else
  `borg.<agent>` (agents: notifyd, cortex-wake, usage-watch, reap, pr-watch, memory-gate). The
  prefix is `$LAUNCHD_LABEL_PREFIX` when set and non-blank, else the first non-blank line of
  `${XDG_CONFIG_HOME:-~/.config}/launchd-prefix` (whitespace trimmed), else none — the same
  contract the dotfiles repo uses for its own agents, so one file brands every LaunchAgent on the
  machine. `install.sh` resolves at install time and templates `{{LABEL}}` into each plist;
  `borg doctor` resolves at run time through the same function; the installed filename is always
  `~/Library/LaunchAgents/<label>.plist`. With `com.stillpoint-labs` in the file the labels are
  byte-identical to the pre-prefix hardcoded ones. `install.sh` also carries a ONE-TIME migration:
  when the resolved label differs from the legacy `com.stillpoint-labs.borg.<agent>`, it boots the
  legacy agent out and deletes its plist, because notifyd is KeepAlive and a rename would otherwise
  leave two daemons running. `tests/launchd_label.bats` pins all of this; `bin/` scripts refer to
  agents by name in comments and never carry a literal label.
  - **Extension agents (drop-in socket)**: borg's installer is the ONLY launchd installer on the
    machine. Drop `<name>.plist.tmpl` (file or symlink) into
    `${XDG_CONFIG_HOME:-~/.config}/borg/extensions/launchd/` and `install.sh` renders it through
    the same placeholders (`{{LABEL}}` `{{HOME}}` `{{USER}}` `{{LOG_DIR}}` `{{PATH_VALUE}}`) to
    `~/Library/LaunchAgents/<label>.plist` (a regular file), then bootout-if-loaded + bootstrap.
    Label = `_borg_launchd_ext_label <name>` = `<prefix>.<name>`, or `local.<name>` with no prefix.
    Absent/empty dir = one info line; a render that fails `plutil -lint` is skipped with a warn and
    never bootstrapped, and does not stop the others. `borg doctor` lists them, registration only.
    No legacy migration for extension labels — the operator retires pre-borg labels by hand, once.
