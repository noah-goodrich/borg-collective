# Upgrading borg on any machine

A runbook for bringing a machine from an older borg to the current release, or for installing borg on a fresh machine. It is written so that a person, or a Claude Code session with no other context, can follow it top to bottom. The GitHub release notes for each version describe what changed; this page holds the per-machine steps, and a future release that needs anything from you adds a row to the migration table in section 5 instead of rewriting the notes.

This page was last checked against release 0.9.13.

## 1. Who this is for and how to use it with Claude Code

Use this page if you run borg on more than one machine, if a machine fell behind, or if you are setting borg up somewhere new.

To have a Claude Code session do the work, start a fresh session on the target machine and give it the raw URL of this file and nothing else: https://raw.githubusercontent.com/noah-goodrich/borg-collective/main/docs/upgrading.md. This page is the whole brief.

If you are a Claude Code session that was handed this page: follow it top to bottom under the standing rules below. Do section 2, then section 3 on a fresh machine or section 4 on a machine that already has borg, then every row of section 5 that applies, then section 6. End by showing the person the output of the three commands in section 6, and give them the one thing in section 5 that only they can do (the 0.9.12 update order names it).

Standing rules for that session (a person following the page by hand should keep them too):

- Work through the page in order, one step at a time. Run each step as a plain command and show its output before moving on.
- Stop at the first failure and report it. Do not improvise a workaround.
- Never force-push and never discard local changes. If a step needs a file out of the way, stash it with a name (`git stash push -m "<what and why>"`) and say so.
- Ask before running `install.sh` on a machine that already has borg.
- The dotfiles installer (section 4, step 0) is the person's to run, never yours: it types into every tmux pane, including the one you are in.
- Never edit files outside the three checkouts (the borg-collective checkout, the plugin mirror checkout and the dotfiles checkout). The exceptions are the dotfiles installer that the person runs in section 4, step 0, and the stack migration in section 5, which moves manifest files inside the repositories that `borg link` names, using `borg stack migrate` only, and which asks the person before committing in each one.
- If a command prompts for input (for example `borg setup` asking for a git identity, or `install.sh` asking whether to install the plugin), stop and ask the person what to answer.

## 2. Facts to collect first

In the commands below, `<BORG>` is the borg-collective checkout, `<PLUGINS>` is the plugin mirror checkout (a clone of the claude-plugins repository), `<DOTFILES>` is the dotfiles checkout (normally `~/.config/dotfiles`), and `<MARKETPLACE>` is the name of the Claude Code marketplace that serves it. Collect these five facts before changing anything.

- Installed version: `borg version`. A good answer is a version number such as `0.9.5`. "command not found" means this is a fresh machine, so go to section 3.
- Where the installed borg lives: `command -v borg | xargs readlink -f`. A good answer is a path ending in `borg.zsh` inside a borg-collective checkout. The directory holding it is `<BORG>`. Pulling that checkout is what upgrades borg.
- Where the plugin mirror is and which marketplace serves it: `claude plugin list` and `claude plugin marketplace list`. In the first, find the `borg-collective@<MARKETPLACE>` entry; its `Read from:` line is the mirror directory, and its parent directory is `<PLUGINS>`. In the second, the same marketplace name appears with a `Source: Folder (...)` line pointing at `<PLUGINS>`. If the source is a GitHub repository instead of a folder, there is no local `<PLUGINS>` checkout to pull; see the troubleshooting entry for a stale marketplace.
- Whether either checkout has uncommitted changes: `git -C <BORG> status --short --branch` and `git -C <PLUGINS> status --short --branch`. A good answer is the branch name (normally `main`) with no file lines. Modified files under the `borg-collective/` directory of `<PLUGINS>` are expected and are handled in section 4. Any other modified file is the person's own work: leave it alone. If `<BORG>` is not on `main`, stop and ask.
- Where the dotfiles checkout is and whether it is current: `readlink ~/.config/tmux/tmux.conf`. A good answer ends in `dotfiles/tmux/tmux.conf`, and the directory above `tmux/` is `<DOTFILES>`. If it is not a link, the machine never ran the dotfiles installer: step 0 of section 4 still applies, after cloning `https://github.com/noah-goodrich/dotfiles` to `~/.config/dotfiles` if that directory is missing (it is a private repository, so `gh auth status` must succeed first; if it does not, ask the person to run `gh auth login`). Then run `git -C <DOTFILES> status --short --branch`. A good answer is `main` with no file lines. A modified `tmux/tmux.conf` is expected on a machine that ran an older `borg setup`, and step 0 handles it. Any other modified file is the person's own work: leave it alone.

## 3. Fresh machine

Requirements: macOS, zsh, git, tmux, jq, fzf, gh, Python 3.11 or newer, and the Claude Code CLI. See the Requirements section of the README for the list; `docs/work-machine-setup.md` covers prerequisites in more detail.

The dotfiles come first. Clone `https://github.com/noah-goodrich/dotfiles` to `~/.config/dotfiles` (a private repository: run `gh auth status` first and ask the person to run `gh auth login` if it fails), have the person run its installer as described in section 4, step 0, and then follow the identity steps in the dotfiles repository's own `docs/work-machine-setup.md` (the work email goes in `~/.gitconfig.local`, secrets go in the Keychain). Do that before step 1 below.

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

0. Bring the dotfiles current first. The dotfiles repository carries the tmux, Ghostty, zsh, git and Neovim config, the global `~/.claude/CLAUDE.md` rules and Cortex's `RULES.md`, and several recent borg features lean on it: clickable PR links need a tmux setting, the tmux status line shows the `borg next --line` glance, and the Cortex link rule lives in `RULES.md`. Older `borg setup` runs also edited the dotfiles tmux config in place, so pull dotfiles before borg.

   1. Run `git -C <DOTFILES> status --short --branch`. If `tmux/tmux.conf` is modified, stash it by name: `git -C <DOTFILES> stash push -m "pre-upgrade tmux binding appended by borg setup" -- tmux/tmux.conf`. The current dotfiles carries that binding itself, so nothing is lost. Leave every other local change alone.
   2. Run `git -C <DOTFILES> pull --ff-only`. If it refuses, stop and report.
   3. Copy the Claude settings aside with `cp ~/.claude/settings.json ~/.claude/settings.json.pre-dotfiles`. Current dotfiles no longer ships a settings template, so the installer should leave that file alone; older revisions overwrote `permissions` and `model` from one.
   4. Tell the person to run `bash <DOTFILES>/install.sh` themselves, in a terminal tab that is not a tmux pane running Claude Code, Cortex or an editor. It types `source ~/.zshrc` and Enter into every tmux pane, and it can take several minutes when Docker is installed, because it builds the base devcontainer image. It re-links the tmux, zsh, git, Neovim and Ghostty config and the global `~/.claude/CLAUDE.md` (a file that was in the way is moved to `~/.dotfiles-backup/<timestamp>/`), copies the dotfiles-owned hooks and slash commands into `~/.claude`, links Cortex's `RULES.md`, pulls `<PLUGINS>` and re-registers the plugin marketplace. It may print a jq error that names `claude/code/settings.json`, followed by "settings.json merged", and leave an empty `~/.claude/settings.json.tmp.<pid>`; both come from a retired merge step and are harmless. The machine's own git identity lives in `~/.gitconfig.local`, which the installer never overwrites; the dotfiles repository's `docs/work-machine-setup.md` says how to set it.
   5. If the person says the installer moved a `~/.snowflake/cortex/RULES.md` of their own into `~/.dotfiles-backup/`, ask whether any rule in it belongs in the dotfiles copy, because the linked file replaces it.
   6. Re-read the tmux config, then re-attach: `tmux source-file ~/.config/tmux/tmux.conf`, then detach (`Ctrl+Space d`) and attach again. tmux reads the hyperlink setting when a client attaches. Check with `tmux show-options -s | grep hyperlinks` (one line naming `xterm-ghostty:hyperlinks`) and, after re-attaching, `tmux list-clients -F '#{client_termfeatures}'` (the output contains `hyperlinks`).

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

c. Update every plugin installed from that marketplace, not only borg-collective. The marketplace checkout carries all of its plugins, and a release of the mirror can bump several at once. List what is installed, then update each entry whose name ends in `@<MARKETPLACE>`:

```
claude plugin list
claude plugin update borg-collective@<MARKETPLACE>
claude plugin update <OTHER-PLUGIN>@<MARKETPLACE>
claude plugin list
```

   Run the `update` line once per `<name>@<MARKETPLACE>` entry in the first listing (an entry's `Read from:` line also points into `<PLUGINS>`). Entries from other marketplaces are not yours to update here. The second listing should show each updated plugin at the version in its own `.claude-plugin/plugin.json` under `<PLUGINS>`. `claude plugin update` says to restart to apply; step e does that.

d. Refresh what borg installs, right away, before anything else runs against the registry. `borg setup` refreshes the hooks, the bin utilities and the tmux binding (a no-op once step 0 is done, because the dotfiles config already has it), migrates an old registry key (section 5), and rebuilds the local plugin mirror. When `cortex` is on `PATH` it also registers borg's Cortex hooks, copies borg's six agents into `~/.snowflake/cortex/agents/` and registers the skills with Cortex. Skills and agents ship through the plugin in the previous step. Run the installed `borg` from any directory, but never from a git worktree of borg-collective, because that registers skill paths under the worktree:

```
borg setup
```

e. Restart every open Claude Code session and every open Cortex session. A running session keeps the hooks and skills it loaded at start, so it can report the new version while still running old code. A resumed conversation (`claude --resume` or `claude --continue`) loads the new instruction and skill files but keeps the old context. For a fresh conversation, start `claude` without a resume flag, or open a managed window with `borg init` or `drone up`.

f. Check the install with `borg doctor`, then read what it should show in section 6.

Then do section 5 and section 6.

## 5. Post-upgrade migrations

Find the row for the version you started from. If you skipped several releases, do every row from your version up to the current one, oldest first.

| Upgrading from | Required steps |
|----------------|----------------|
| 0.9.5 or earlier | Stack manifests, below |
| Before 0.9.4, or never ran install.sh | Launchd agents, below |
| 0.9.6 | None |
| 0.9.7 | Registry key, below |
| 0.9.8 | 0.9.9 update order, below |
| 0.9.9 | 0.9.10 update order, below |
| 0.9.10 | 0.9.11 update order, below |
| 0.9.11 | 0.9.12 update order, below |
| 0.9.12 | 0.9.13 update order, below |
| 0.9.13 | None (current release) |

Cortex hooks: 0.9.7's `borg setup` registers borg's Cortex hooks in Cortex's `hooks.json`, where Cortex reads them; older versions wrote them to a file Cortex never read. The normal upgrade's `borg setup` step does it, nothing extra.

### Launchd agents (install.sh)

`install.sh` is the only installer of borg's launchd agents: the resume watcher, the notification daemon, the usage watch, the reaper, the PR watch and the memory gate. `borg setup` installs none of them, and section 4 never runs `install.sh`, so a machine whose previous install predates 0.9.4 (when the resume watcher shipped), or that was upgraded by this page without ever running `install.sh`, has no resume watcher. `borg doctor` shows this as FAIL rows for `resume-watch` and `resume-probe`. `borg setup` also prints a warning naming any shipped agent that is not loaded, that warning is the other way to find it.

1. Ask the person, then run the installer from the borg-collective checkout once. Answer `N` to the plugin prompt, because the plugin is handled in section 4:

```
run-in <BORG> ./install.sh
```

2. Run `borg doctor`. Every RESUME row should now be OK except `resume-guardian`, which stays a known warning (section 6). On a machine signed in with a subscription this clears both the `resume-watch` and the `resume-probe` FAIL rows: the probe reads the path of the Claude binary from the watcher's plist, so it cannot pass without it. On a usage-billed account (an Enterprise seat), `/usage` reports cost and has no session limit, so `resume-probe` shows `INFO`, not `OK`: limit-class resumes and the guardian's limit thresholds do not apply there, and every other resume path is unchanged. A `FAIL` on that row on any account still means the probe cannot read `/usage` at all.

### Updating to 0.9.13: update order

0.9.13 trims the context borg loads and makes borg's agents work in Cortex Code. No migration is needed. What changes after the plugin update and a restart: `/borg-link-up`, `/borg-plan` and `/borg-collective-review` are much shorter and read their detail files from the skill's `references/` folder only when a step needs them (about 5k tokens less after every compaction); the nudge after 75 tool calls now says to link up and start a fresh session; and on a machine with Cortex Code, `borg setup` registers the plan-mode hooks and copies borg's six agents into `~/.snowflake/cortex/agents/`, where Cortex loads them by their bare names (`borg-scout`, not `borg-collective:borg-scout`).

The path from 0.9.12 or earlier, in order (the commands are in section 4):

0. Bring the dotfiles current (section 4, step 0). Skip it only if you already did it as part of this same upgrade.
1. Pull the checkouts.
2. Run `claude plugin update` for borg-collective.
3. Run `borg setup`.
4. Restart every open Claude Code session and every open Cortex session.
5. On a machine with Cortex Code, run `ls ~/.snowflake/cortex/agents` and show the output: six files named `borg-*.md`.

### Updating to 0.9.12: update order

0.9.12 is the one owned next list release: `borg next`, `borg link` and the arrival brief read each repository's newest checkpoint whole, and the items under a `Waits on you:` line in its Blockers section become the person's rows. No file migration is needed and `--json` only gains keys. One thing is not automatic: a checkpoint written before 0.9.12 has no `Waits on you:` line, and the reader drops a Blockers bullet that has no such lead-in, so what waits on the person shows nothing until a newer checkpoint is written in the new form.

The path from 0.9.11 or earlier, in order (the commands are in section 4):

1. Pull the checkouts.
2. Run `claude plugin update` for borg-collective.
3. Run `borg setup`.
4. Restart every open Claude Code session.
5. This step is the person's, and you cannot do it for them: a slash command runs inside the session it is typed in. Tell them to open the Queen session (`borg init`), run `/borg-link-up` there, and do the same in any repository session whose latest checkpoint has something waiting on them. Do not write a checkpoint yourself.
6. Once they say it is done, run this and show the output. It prints project names and owners only, no row text, so it is safe to send on:

```
borg next --rows --json \
  | jq '{rows: [.rows[] | {project, owner}], hidden}'
```

A good answer lists the Queen's waiting items with owner `YOU`. If the Queen has things waiting and none show, the newest Queen checkpoint still has the old wording: run `/borg-link-up` in the Queen session again and check that its Blockers section carries a line that reads exactly `Waits on you:`.

### Updating to 0.9.11: update order

0.9.11 is the arrival brief release: a new SessionStart hook prints a four-line brief when a session starts or resumes in a repository. No migration is needed: the new `focus.since.head_moves` key in `--json` is additive.

The path from 0.9.10, in order (the commands are in section 4):

1. Pull the checkouts.
2. Run `claude plugin update` for borg-collective.
3. Run `borg setup`.
4. Restart every open Claude Code session, because a new SessionStart hook ships through the plugin and a running session does not load it.
5. On the next start, look for "SessionStart:startup says:" followed by the brief.

### Updating to 0.9.10: update order

0.9.10 is the doorways release: the Queen page is one screen, `/borg-link` paints it verbatim, and `borg next --line` gives a one-line glance. No migration is needed: `--json` is unchanged and the new `card` field is additive.

The path from 0.9.9, in order (the commands are in section 4):

1. Pull the checkouts.
2. Run `borg setup`.
3. Run `claude plugin update` for borg-collective, then restart every open Claude Code session. The `/borg-link` and `/borg-next` skills changed, and a running session keeps the old ones.
4. Optional: run `borg setup --statusline` to show `borg next --line` in the Claude Code status line. `borg setup --statusline=off` removes it.
5. Optional: add the tmux `status-right` string from `docs/agents/commands.md` to your tmux config.

### Updating to 0.9.9: update order

0.9.9 is the contract step of the registry key rename (below): the registry file uses only `repositories`, and the old `projects` key is no longer read. The order of the upgrade matters on a machine whose registry still has the old key.

The path from 0.9.8, in order (the commands are in section 4):

1. Pull both checkouts.
2. Update every plugin installed from the marketplace, borg-collective and any other (a mirror release can bump several at once).
3. Run `borg setup` right away. It renames the key and writes a timestamped backup first.
4. Restart every open Claude Code session.
5. Run `borg doctor` and compare it with the rows below.

Until setup has migrated the file, hooks and the notify daemon read the unmigrated file as empty, and every other borg and drone command refuses it with a pointer to the fix. `borg doctor` shows a FAIL row named `registry-key`. A machine that already migrated the registry in 0.9.8 has nothing extra to do for this; its `registry-key` row is OK from the start.

What changes for a session after the restart: the plugin ships one fewer borg skill, several borg skill descriptions are shorter, and the research plugin keeps a single front door, `/research`. A running session keeps the skills it loaded until it restarts.

What `borg doctor` should show after 0.9.9:

- `registry-key` is OK and names `repositories`.
- `resume-probe` is OK on a subscription account. On a usage-billed account (one whose `/usage` reports cost, not session limits, such as an Enterprise seat) it is INFO, "usage-billed account", not FAIL. A FAIL on that row on any account means `/usage` could not be read at all.
- `resume-watch` and `resume-log` are OK once `install.sh` has loaded the launchd agents (see "Launchd agents" above). `resume-log` can be WARN ("no watcher pass recorded yet") for the first minute after an install; run doctor again.
- `resume-guardian` is WARN and stays so. It says the usage guardian looks dead and that this is a warning only, because borg-resume runs its own probe.
- `resume-switch` is INFO, "off (injection allowed)", unless you paused resume on purpose.
- Any other WARN or FAIL row is worth reading.

Checks that the new behaviour works, with `borg link --overview` on a machine that has `gh` signed in:

- The GitHub track runs: it is not skipped, and the SIGNALS section has no line starting `sweep: adapter 'github'`. Rows under WAITING ON YOU carry their PR number as a link in terminals that render links.
- If the sweep still fails, that SIGNALS line now carries gh's own error text and names the repositories the failed request covered, where 0.9.8 only said it failed. Partial results are kept, so one slow request no longer blanks the rest. Fix what gh names (sign in with `gh auth login`, or wait out a rate limit).
- For a large registry, three knobs tune the sweep, set in the shell profile: `BORG_RECON_GITHUB_CHUNK` (repositories per request, default 5, at most 50), `BORG_RECON_GITHUB_JOBS` (requests in flight, default 8, at most 16) and `BORG_RECON_GITHUB_TIMEOUT` (seconds per request, default 6, at most 60). If requests time out, lower the chunk size first. `borg link` gives the whole sweep 10 seconds, so raising the timeout alone does not help there.
- The Queen session's startup roster folds repositories idle for 30 days or more into one count line. `BORG_QUEEN_IDLE_DAYS` changes the cutoff; a non-numeric value falls back to 30. The full list is always `borg link`.

Leftovers from earlier upgrades, each safe to repeat. `borg scan` skips temporary directories now, but an entry registered earlier stays: remove it with `borg rm <name>`. `borg reap` lists registry entries whose directory no longer exists, and `borg reap --drop-missing` removes exactly those entries from the registry and touches nothing on disk. `borg reap` also downgrades sessions with no live process to idle, which is what clears stale "waiting" rows.

### Registry key (`projects` to `repositories`)

The registry file (`~/.config/borg/registry.json`, or under `XDG_CONFIG_HOME`) keeps its repositories under a top-level key. The key moved from `projects` to `repositories` in three steps. Step one, in 0.9.6, made every reader accept both. Step two, in 0.9.8 as noah-goodrich/borg-collective#420, made every writer keep whichever key the file already has. Step three, in 0.9.9, drops the old key: from that release on, the old `projects` key is no longer read, and a new registry file is created with `repositories`.

The normal upgrade handles it. Section 4 runs `borg setup`, and `borg setup` renames the key for you. It is safe to repeat: when the file already has `repositories` it does nothing, and when it renames it writes a timestamped backup next to the file first (`registry.json.bak.<UTC stamp>`).

A registry file that still has only `projects` is never read as an empty registry and never overwritten. Every borg command that reads the registry stops with a message that starts "borg: registry file (<path>) still uses the retired 'projects' key, which is no longer read", names `borg setup` and `python3 -m borg_core.registry.cli migrate-key` as the fix, and changes nothing.

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

   Each affected repository is named in a warning that mentions `borg stack migrate`. If none is named, this migration is done. A registered path that is a subdirectory of a repository, not its top level, is skipped by `borg stack migrate`, by name ("not a git repository (or not the top level of one)"), and stays named by `borg link --overview` afterwards. This is the usual reason a machine still shows unmigrated manifests after running the migration. Fix it by registering the repository root and removing the subdirectory entry: `borg add <REPOSITORY-ROOT>`, then `borg rm <SUBDIRECTORY-NAME>` (names come from `borg link --overview`), then migrate and commit at the root.
2. For each named repository: if there is uncommitted work under its old `.borg/chains/` or `.borg/programs/` folder, commit or clean it first, because migrate skips a repository with uncommitted changes there. Ask the person if unsure.

3. Preview, then migrate. `<REPOSITORY>` is a registered name or a directory. Migrate moves the manifests into `.stacks/` and stages the move; it never commits.

```
borg stack migrate --dry-run <REPOSITORY>
borg stack migrate <REPOSITORY>
git -C <REPOSITORY> status --short
```

4. Review the status output, then ask the person and commit the move in that repository, for example with the message `chore: move stack manifests to .stacks/`.

5. If the repository's default branch already carries the migrated file, merge the default branch instead and delete the old copy.

6. Run `borg link --overview` again. The warning should be gone for each migrated repository. If the page still names a repository, re-read step 1: the entry is most likely a subdirectory registration, and migrate will not touch it until that is fixed.

## 6. Verify

Show the person the output of `borg version`, `claude plugin list | grep borg-collective` and `borg doctor`, all three, whether or not they pass.

- `borg version` prints the release you expect. The expected release is the content of the `VERSION` file in `<BORG>`.
- `borg doctor` is green. One warning is known and benign: a `resume-guardian` row that reads `usage guardian last active ...` (or `no usage-guardian.json`) is marked `WARN` and says it is a warning only, because borg-resume runs its own usage probe. On a usage-billed account `resume-probe` reads `INFO`, which is also correct. Any other `WARN` or `FAIL` row is worth reading. A `gh` row below the version floor means upgrading `gh`. The full list of rows to expect after 0.9.9 is in section 5.
- `borg link --overview` renders a page, with no unmigrated-manifest warnings and no `sweep: adapter 'github'` line under SIGNALS.
- In a Claude Code session started after the update, or from a shell with `claude plugin list`, the `borg-collective` plugin shows the same version as `borg version`.
- The dotfiles checkout is current: `git -C <DOTFILES> status --short --branch` shows `main` with no `behind`. On a machine with Cortex, `readlink ~/.snowflake/cortex/RULES.md` points into `<DOTFILES>/cortex/RULES.md`.
- tmux carries the hyperlink setting: `tmux show-options -s | grep hyperlinks` prints a line. A tmux server that was already running needs the re-attach in section 4, step 0.

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
- A plugin other than borg-collective is still on its old version, or a skill that was removed still appears. Only the plugins you updated by name were updated. Run `claude plugin list`, update every `<name>@<MARKETPLACE>` entry (section 4, step c), and restart.
- The dotfiles pull refuses. A file in `<DOTFILES>` is modified; the usual one is `tmux/tmux.conf`, edited in place by an older `borg setup`. Stash it by name (section 4, step 0) and pull again.
- The dotfiles installer typed `source ~/.zshrc` into a Claude Code or Cortex pane. That is what it does to every tmux pane. The line is harmless, and the person should run the installer from a plain terminal next time.
- Links in a Claude Code or Cortex session are still not clickable after the update. The tmux server has not re-read its config for the attached client. If `tmux show-options -s | grep hyperlinks` prints nothing, run `tmux source-file ~/.config/tmux/tmux.conf`; then detach and attach again.
