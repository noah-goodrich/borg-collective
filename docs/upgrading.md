# Upgrading borg on any machine

A runbook for bringing a machine from an older borg to the current release, or for installing borg on a fresh machine. It is written so that a person, or a Claude Code session with no other context, can follow it top to bottom. The GitHub release notes for each version describe what changed; this page holds the per-machine steps, and a future release that needs anything from you adds a row to the migration table in section 5 instead of rewriting the notes.

This page was last checked against release 0.9.8.

## 1. Who this is for and how to use it with Claude Code

Use this page if you run borg on more than one machine, if a machine fell behind, or if you are setting borg up somewhere new.

To have a Claude Code session do the work, start a fresh session on the target machine and paste the raw URL of this file, https://raw.githubusercontent.com/noah-goodrich/borg-collective/main/docs/upgrading.md, with one sentence:

```
Follow docs/upgrading.md on this machine, one step at a time, show
each command's output, stop at the first failure and report it.
```

Standing rules for that session (a person following the page by hand should keep them too):

- Run each step as a plain command and show its output before moving on.
- Stop at the first failure and report it. Do not improvise a workaround.
- Never force-push and never discard local changes. If a step needs a file out of the way, stash it with a name (`git stash push -m "<what and why>"`) and say so.
- Ask before running `install.sh` on a machine that already has borg.
- Never edit files outside the two checkouts (the borg-collective checkout and the plugin mirror checkout). The one exception is the stack migration in section 5, which moves manifest files inside the repositories that `borg link` names, using `borg stack migrate` only, and which asks the person before committing in each one.
- If a command prompts for input (for example `borg setup` asking for a git identity, or `install.sh` asking whether to install the plugin), stop and ask the person what to answer.

## 2. Facts to collect first

In the commands below, `<BORG>` is the borg-collective checkout, `<PLUGINS>` is the plugin mirror checkout (a clone of the claude-plugins repository), and `<MARKETPLACE>` is the name of the Claude Code marketplace that serves it. Collect these four facts before changing anything.

- Installed version: `borg version`. A good answer is a version number such as `0.9.5`. "command not found" means this is a fresh machine, so go to section 3.
- Where the installed borg lives: `command -v borg | xargs readlink -f`. A good answer is a path ending in `borg.zsh` inside a borg-collective checkout. The directory holding it is `<BORG>`. Pulling that checkout is what upgrades borg.
- Where the plugin mirror is and which marketplace serves it: `claude plugin list` and `claude plugin marketplace list`. In the first, find the `borg-collective@<MARKETPLACE>` entry; its `Read from:` line is the mirror directory, and its parent directory is `<PLUGINS>`. In the second, the same marketplace name appears with a `Source: Folder (...)` line pointing at `<PLUGINS>`. If the source is a GitHub repository instead of a folder, there is no local `<PLUGINS>` checkout to pull; see the troubleshooting entry for a stale marketplace.
- Whether either checkout has uncommitted changes: `git -C <BORG> status --short --branch` and `git -C <PLUGINS> status --short --branch`. A good answer is the branch name (normally `main`) with no file lines. Modified files under the `borg-collective/` directory of `<PLUGINS>` are expected and are handled in section 4. Any other modified file is the person's own work: leave it alone. If `<BORG>` is not on `main`, stop and ask.

## 3. Fresh machine

Requirements: macOS, zsh, git, tmux, jq, fzf, gh, Python 3.11 or newer, and the Claude Code CLI. See the Requirements section of the README for the list; `docs/work-machine-setup.md` covers prerequisites in more detail.

1. Clone both repositories side by side. borg builds its plugin mirror into `claude-plugins` under the workspace root, which is `~/dev` unless `BORG_ORCHESTRATOR_ROOT` says otherwise, so `~/dev` is the simplest choice.

```
mkdir -p ~/dev
git clone https://github.com/noah-goodrich/borg-collective \
  ~/dev/borg-collective
git clone https://github.com/noah-goodrich/claude-plugins \
  ~/dev/claude-plugins
```

2. Run `./install.sh` from inside the borg-collective checkout. It installs the `borg` and `drone` CLIs, the hooks, skills and agents, and the launchd agents, and it runs `borg setup`. It ends by offering to install the Claude Code plugin; answer `N`, because the marketplace is not registered yet. If it warns that `~/.local/bin` or `~/.claude/bin` is not on `PATH`, ask the person before editing their shell profile.

3. Register the plugin mirror as a marketplace and install the plugin.

```
claude plugin marketplace add ~/dev/claude-plugins
claude plugin marketplace list
claude plugin install borg-collective@<MARKETPLACE>
```

   The marketplace name is the name in `~/dev/claude-plugins/.claude-plugin/marketplace.json` (`jq -r .name` on that file prints it) and it is what `marketplace list` shows for the new entry. Use that name for `<MARKETPLACE>`.

4. Restart any open Claude Code session, then go to section 6.

## 4. Existing machine: the normal upgrade

Do these in order, after section 2.

a. Stash, never discard, any modified files inside the plugin mirror directory. They are generated files from an earlier local build of the mirror and they block the pull. Leave every other local change alone.

```
git -C <PLUGINS> status --short -- borg-collective
git -C <PLUGINS> stash push \
  -m "pre-upgrade generated mirror files" -- borg-collective
```

   If the first command prints nothing, skip the second. Tell the person what was stashed.

b. Pull both checkouts, fast-forward only. If either pull refuses, stop and report; do not merge or reset.

```
git -C <BORG> pull --ff-only
git -C <PLUGINS> pull --ff-only
```

c. Refresh what borg installs. `borg setup` refreshes the hooks, the bin utilities and the tmux binding, and rebuilds the local plugin mirror. Skills and agents ship through the plugin in the next step. Run it from any directory:

```
borg setup
```

d. Update the plugin, then check the version it reports:

```
claude plugin update borg-collective@<MARKETPLACE>
claude plugin list
```

e. Restart every open Claude Code session. A running session keeps the hooks and skills it loaded at start, so it can report the new version while still running old code. A resumed conversation (`claude --resume` or `claude --continue`) loads the new instruction and skill files but keeps the old context. For a fresh conversation, start `claude` without a resume flag, or open a managed window with `borg init` or `drone up`.

Then do section 5 and section 6.

## 5. Post-upgrade migrations

Find the row for the version you started from. If you skipped several releases, do every row from your version up to the current one, oldest first.

| Upgrading from | Required steps |
|----------------|----------------|
| 0.9.5 or earlier | Stack manifests, below |
| Before 0.9.4, or never ran install.sh | Launchd agents, below |
| 0.9.6 | None |
| 0.9.7 | Registry key, below |
| 0.9.8 | Registry key, below (`borg setup` does it) |

Cortex hooks: 0.9.7's `borg setup` registers borg's Cortex hooks in Cortex's `hooks.json`, where Cortex reads them; older versions wrote them to a file Cortex never read. The normal upgrade's `borg setup` step does it, nothing extra.

### Launchd agents (install.sh)

`install.sh` is the only installer of borg's launchd agents: the resume watcher, the notification daemon, the usage watch, the reaper, the PR watch and the memory gate. `borg setup` installs none of them, and section 4 never runs `install.sh`, so a machine whose previous install predates 0.9.4 (when the resume watcher shipped), or that was upgraded by this page without ever running `install.sh`, has no resume watcher. `borg doctor` shows this as FAIL rows for `resume-watch` and `resume-probe`. `borg setup` also prints a warning naming any shipped agent that is not loaded, that warning is the other way to find it.

1. Ask the person, then run the installer from the borg-collective checkout once. Answer `N` to the plugin prompt, because the plugin is handled in section 4:

```
run-in <BORG> ./install.sh
```

2. Run `borg doctor`. Every RESUME row should now be OK except `resume-guardian`, which stays a known warning (section 6). On a machine signed in with a subscription this clears both the `resume-watch` and the `resume-probe` FAIL rows: the probe reads the path of the Claude binary from the watcher's plist, so it cannot pass without it. On a usage-billed account (an Enterprise seat), `/usage` reports cost and has no session limit, so `resume-probe` shows `INFO`, not `OK`: limit-class resumes and the guardian's limit thresholds do not apply there, and every other resume path is unchanged. A `FAIL` on that row on any account still means the probe cannot read `/usage` at all.

### Registry key (`projects` to `repositories`)

The registry file (`~/.config/borg/registry.json`, or under `XDG_CONFIG_HOME`) keeps its repositories under a top-level key. The key moved from `projects` to `repositories` in three steps. Step one, in 0.9.6, made every reader accept both. Step two, in 0.9.8 as noah-goodrich/borg-collective#420, made every writer keep whichever key the file already has. Step three, the first release after 0.9.8, drops the old key: from that release on, the old `projects` key is no longer read, and a new registry file is created with `repositories`.

The normal upgrade handles it. Section 4 runs `borg setup`, and `borg setup` renames the key for you. It is safe to repeat: when the file already has `repositories` it does nothing, and when it renames it writes a timestamped backup next to the file first (`registry.json.bak.<UTC stamp>`).

A registry file that still has only `projects` is never read as an empty registry and never overwritten. Every borg command that reads the registry stops with this message and changes nothing:

```
borg: registry file (<path>) still uses the retired 'projects' key, which is no longer read; run `borg setup` or `python3 -m borg_core.registry.cli migrate-key` to rename it to 'repositories'
```

`borg doctor` shows the same condition as a FAIL row named `registry-key`. The python tools print the same sentence as an error. If you see it, rename the key by hand with the steps below. If you ran `borg setup` as part of the upgrade you will not see it.

1. Preview the change. It prints one line and writes nothing:

```
python3 -m borg_core.registry.cli migrate-key --dry-run
```

   Run it from the borg-collective checkout (`run-in <BORG> ...` or `cd` there first). "nothing to do" or "already uses 'repositories'" means the file is already migrated; skip to step 3.

2. Run it for real. It writes a timestamped backup next to the file first:

```
python3 -m borg_core.registry.cli migrate-key
```

3. Confirm the board still lists every repository and that doctor is clean:

```
borg link --overview
borg doctor
```

   If the board comes back empty, restore the backup it named (copy it over `registry.json`) and report; nothing else was changed.

### From 0.9.5 or earlier to 0.9.6: stack manifests

Since 0.9.6, borg reads stack manifests only from `<repository>/.stacks/`. A repository that still keeps them under `.borg/chains/` or `.borg/programs/` is no longer read. If you skip this step, that repository's stacks disappear from `borg link` (it prints a warning naming the repository instead) and stack commands see nothing there.

1. See which repositories are affected. `--overview` forces the cross-repository page from any directory:

```
borg link --overview
```

   Each affected repository is named in a warning that mentions `borg stack migrate`. If none is named, this migration is done. A registered path that is a subdirectory of a repository, not its top level, is skipped by name ("not a git repository (or not the top level of one)"). Re-register it at the repository root (or run migrate from the root), then migrate and commit there.

2. For each named repository: if there is uncommitted work under its old `.borg/chains/` or `.borg/programs/` folder, commit or clean it first, because migrate skips a repository with uncommitted changes there. Ask the person if unsure.

3. Preview, then migrate. `<REPOSITORY>` is a registered name or a directory. Migrate moves the manifests into `.stacks/` and stages the move; it never commits.

```
borg stack migrate --dry-run <REPOSITORY>
borg stack migrate <REPOSITORY>
git -C <REPOSITORY> status --short
```

4. Review the status output, then ask the person and commit the move in that repository, for example with the message `chore: move stack manifests to .stacks/`.

5. If the repository's default branch already carries the migrated file, merge the default branch instead and delete the old copy.

6. Run `borg link --overview` again. The warning should be gone for each migrated repository.

## 6. Verify

- `borg version` prints the release you expect. The expected release is the content of the `VERSION` file in `<BORG>`.
- `borg doctor` is green. One warning is known and benign: a `resume-guardian` row that reads `usage guardian last active ...` (or `no usage-guardian.json`) is marked `WARN` and says it is a warning only, because borg-resume runs its own usage probe. Any other `WARN` or `FAIL` row is worth reading. A `gh` row below the version floor means upgrading `gh`.
- `borg link --overview` renders a page, with no unmigrated-manifest warnings.
- In a Claude Code session started after the update, or from a shell with `claude plugin list`, the `borg-collective` plugin shows the same version as `borg version`.

## 7. Rollback

Rolling back is rare. The steps below return a machine to 0.9.5.

1. Check out the previous tag in the borg checkout and refresh what borg installs:

```
git -C <BORG> checkout v0.9.5
borg setup
```

2. Check out the matching commit of the plugin mirror, then update the plugin. The first command lists the mirror's version bumps, newest first; pick the commit whose subject says 0.9.5.

```
git -C <PLUGINS> log --oneline -5 \
  -- borg-collective/.claude-plugin/plugin.json
git -C <PLUGINS> checkout <COMMIT> -- borg-collective
claude plugin update borg-collective@<MARKETPLACE>
```

3. Restart open Claude Code sessions.

Version 0.9.5 reads stack manifests only from the old root. A rollback after the stack migration needs the migrated files moved back by hand: for each repository, move the files from `.stacks/` to `.borg/chains/` with `git mv`.

To return to the current release afterwards: `git -C <BORG> checkout main`, then section 4.

## 8. Troubleshooting

- The pull refuses because of modified mirror files. Those are generated files from an earlier local build. Stash them (section 4, step a) and pull again. Do not discard them.
- `claude plugin update` says there is nothing to do. The marketplace checkout was not pulled, so the update source is still the old version. Pull `<PLUGINS>` (section 4, step b) and run the update again. If the marketplace comes from a GitHub repository rather than a folder, run `claude plugin marketplace update <MARKETPLACE>` first.
- borg says `unknown command` after the pull. `PATH` points at a different checkout than the one you pulled. Run `command -v borg | xargs readlink -f`, then either pull that checkout or run `./install.sh` from the intended checkout, which re-points the `borg` link (ask first on a machine that already has borg).
- Hooks and skills still look old. The Claude Code session was started before the update. Restart it.
