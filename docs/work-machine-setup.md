# Fresh macOS Work Machine — Borg Setup Runbook

> **This is THE canonical work-machine reference** — fresh setup AND ongoing updates. The
> similarly-named `~/.config/dotfiles/docs/work-machine-setup.md` covers ONLY the dotfiles
> identity/config-sync slice (git email, Keychain-backed secrets, layered config) and points back here
> for everything else.

> **cairn decommissioned (2026-08-08):** cairn (the Postgres+pgvector knowledge-graph service formerly
> set up here) has been fully decommissioned — DB dropped, service/hooks/CLI removed, repo archived.
> Its corpus now lives in per-repository `.borg/knowledge/*.md` markdown, grep-reachable with no service
> required. Any cairn references below are historical.

**Target:** Apple Silicon macOS. Read every phase before running. Steps are in dependency order.
Copy-paste blocks chain with `&&` or `;` — `;` continues on failure (independent steps), `&&` stops on
failure (dependent sequences).

> Distribution model (context): **borg-collective ships in two forms that share one version:** the
> **CLI** (via `install.sh` from a source clone) and the **Claude Code plugin** (hooks/skills/agents, via
> the `noah-local` marketplace). The plugin version tracks the CLI version, so `borg version` and
> `claude plugin list` should report the **same** number.
> Homebrew is used only for prerequisite tooling (jq, tmux, fswatch, …), never for borg itself.
> **Personal skills ship as plugins too**, split across two marketplaces: public ones in `claude-plugins`
> (`noah-local`), employer-specific / not-publicly-shareable ones in `claude-plugins-private` (`noah-private`,
> private GitHub repo). Skills must live in plugins — `borg setup` cleans hand-dropped non-borg skills out of
> `~/.claude/skills` (the borg-collective#64 stale-skill trap, fixed in v0.8.6 by the cleanup guard).

---

## Updating an existing machine (incremental sync)

Already set up? Skip the phases below and run this **one-block update flow** instead — it pulls dotfiles
and all three repos, redeploys borg, and finishes with `borg doctor` so you know the machine is actually
healthy, not just "pulled."

```zsh
# 1. Pull dotfiles first and re-run its installer (config sync
#    only; it registers no LaunchAgents - see bullets below).
git -C ~/.config/dotfiles pull --ff-only && bash ~/.config/dotfiles/install.sh

# 2. Pull all three remaining repos on main, fast-forward only
git -C ~/dev/borg-collective pull --ff-only && git -C ~/dev/claude-plugins pull --ff-only && \
  git -C ~/dev/claude-plugins-private pull --ff-only

# 3. Redeploy borg (REQUIRED — see note). install.sh is interactive ("Install plugin now?"); either answer is fine.
cd ~/dev/borg-collective && ./install.sh        # or: borg setup

# 4. Verify borg CLI and plugin report the SAME version, then run the full health check
borg version && claude plugin list | grep borg-collective && borg doctor
```

- **Step 3 is required:** borg's CLI/libs run from the source clone (a pull refreshes those live), but hooks and
  bin utilities are **copied** into `~/.claude` and only refresh on `install.sh` / `borg setup`. `borg setup` also
  builds the plugin that carries the skills, agents and hook registration; `claude-plugins` is a live directory
  source, so keep its checkout on `main`.
- **Claude Code plugins are *supposed to* update automatically:** `code-governance`, `research-tools`, etc. should
  auto-update from the pulled `~/dev/claude-plugins` via the `noah-local` marketplace (`autoUpdate: true`). Same for
  `noah-personal` from `~/dev/claude-plugins-private` via `noah-private` (`autoUpdate: true`). **But `autoUpdate` is
  best-effort, not guaranteed** — it has been observed to silently not fire, leaving a plugin stuck on an old
  version. **Step 4's version-parity check is the gate, not a formality:**
  ```zsh
  borg version && claude plugin list | grep borg-collective
  ```
  If the CLI and plugin versions don't match, force it: `claude plugin update borg-collective@noah-local`
  (substitute the relevant plugin/marketplace pair for `code-governance`/`research-tools`/`noah-personal`). This
  works regardless of how `install.sh`'s "Install plugin now?" prompt was answered in Step 3 — it isn't gated on
  having answered `y`. **A Claude Code restart is required for the update to take effect** — an already-running
  session can report the new version while its hooks/skills are still the old code loaded at session start.
- **`claude-plugins` mirror can drift behind `borg-collective` source:** the plugin is built from a synced mirror,
  not the canonical source repo. If the mirror lags a merge to `borg-collective`, `claude plugin list` can report a
  version that *looks* like parity while the plugin is actually missing a newly shipped hook/skill/agent. When in
  doubt, verify parity by checking that the installed plugin contains `hooks/borg-agent-model-guard.sh`, not the
  version string alone.
- **`borg setup` rebuilds that mirror on every run** (`scripts/build-plugin.sh` writes into
  `~/dev/claude-plugins/borg-collective/`). A `DRIFT` warning means the committed mirror is behind source; the
  local rebuild is correct but uncommitted. After the install, check `git -C ~/dev/claude-plugins status`, and
  restore or stash that directory before the next pull if the machine must not diverge.
- **Step 4's `borg doctor` is the real health verification step** — it checks the launchd agents for
  registration, exit status, and output freshness, plus a live headless `claude -p` call (log in to `claude`
  first), per-container clock skew, and a version-floor table that fails when `gh` is older than 2.97.0 (run
  `brew upgrade gh`). It can exit 1. A clean pull + `install.sh` with no `borg doctor` check is an unverified
  update; always finish with it.
- **Step 1 (dotfiles) syncs config only.** Its `install.sh` no longer registers LaunchAgents. The optional agents
  (dev-postgres auto-start, `claude-tcc-heal`) ship as `.plist.tmpl` templates: symlink the ones you want into
  `~/.config/borg/extensions/launchd/` before running borg's `./install.sh`, which renders and installs them.

> **2026-07-08:** additions picked up by a plain pull + setup = the `code-governance` plugin (capability-index +
> reconcile-req) and the distilled `research` skill.
> **2026-07-08 (later):** the private marketplace exists now — `claude-plugins-private` repo → `noah-private`
> marketplace → `noah-personal` plugin (employer-specific skills, e.g. `noah-weekly-status`). Clone + register per
> Phases 1 / 3c / 3e below.
> **2026-07-09:** `install.sh` installs the `borg-usage-watch` LaunchAgent by default (opt out with
> `BORG_USAGE_WATCH=0 ./install.sh`) and verifies it produces a fresh sample after bootstrap. `borg doctor`
> checks the launchd agents plus the rows described above — run it any time an agent seems blind or unhealthy.

### What's new (setup-relevant, as of 2026-10-12)

- **Python 3.11+ is now required.** `borg next` and `borg link` import `datetime.UTC` and fail with an
  `ImportError` on the Xcode CLT python 3.9. Phase 0 installs `python@3.13`.
- **Model tiers and routing.** Queen and drone launches pin `--model`/`--effort`, and the plugin's
  Agent/Workflow model guards deny untyped spawns. See Phase 3 for the account requirements and kill switches.
- **Dotfiles `install.sh` registers no LaunchAgents.** Optional agents are `.plist.tmpl` templates symlinked
  into `~/.config/borg/extensions/launchd/`; borg's `install.sh` renders them. Labels follow
  `<prefix>.borg.<agent>` (see Phase 3).
- **`borg doctor` is stricter.** It adds a live headless `claude -p` row, container clock-skew rows and a
  version-floor table (`gh` >= 2.97.0), and it can exit 1.
- **`borg sever` is retired.** Use `borg down`, which tears down every tmux window, the shared Postgres and the
  shared Supabase stack.
- **cairn is gone (2026-08-08).** Nothing to run; its corpus lives in per-repository `.borg/knowledge/*.md`. A
  session started before the pull may log a harmless "No such file or directory" from the deleted
  `borg-cairn-heartbeat.sh` Stop hook — restart Claude Code to clear it.
- **Plugin version equals `borg --version`.** `bash-guard` has been hardened against pre-approval bypasses, so a
  previously-allowed one-liner may now prompt.
- **`drone scaffold --supabase-shared`** is an opt-in path that joins the shared always-on Supabase network; the
  default `--supabase` behavior is unchanged.

---

## Prerequisites to verify manually before running anything

- [ ] macOS with Xcode Command Line Tools (`xcode-select --install`).

---

## Phase 0 — Prerequisites: Homebrew, packages, Docker, Claude Code, gh

```zsh
# Install Homebrew (skip if already present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Required CLI tools for borg + general dev
brew install jq fzf tmux git gh ripgrep neovim fswatch python@3.13

# Container runtime — choose ONE. This work machine runs Podman (docker is a thin client over
# podman-machine-default). Podman does NOT auto-start at login — see Phase 4 and "Ongoing".
brew install podman && podman machine init && podman machine start   # current work-machine runtime
# brew install --cask orbstack      # alternative — auto-starts at login on Apple Silicon
# brew install --cask docker        # alternative

# Claude Code CLI (Node first)
brew install node && npm install -g @anthropic-ai/claude-code

# Authenticate GitHub CLI (needed for gh + GH_TOKEN)
gh auth login
```

> **borg needs python3 >= 3.11.** `borg next` and `borg link` import `datetime.UTC`, so they die with an
> `ImportError` on the Xcode CLT python 3.9. `borg.zsh` rebuilds `PATH` from scratch
> (`$HOME/.local/bin:/opt/homebrew/bin:...:/usr/bin`), so the Homebrew python above wins automatically; a pyenv or
> corporate python is invisible to borg unless you set `BORG_PATH_PREFIX` to its bin directory.

---

## Phase 1 — Clone repos

Expected layout under `~/dev/` — borg expects `BORG_ORCHESTRATOR_ROOT=$HOME/dev`.

```zsh
mkdir -p ~/dev
git clone https://github.com/noah-goodrich/borg-collective ~/dev/borg-collective
git clone https://github.com/noah-goodrich/dotfiles ~/.config/dotfiles
git clone https://github.com/noah-goodrich/claude-plugins ~/dev/claude-plugins

# PRIVATE repo (employer-specific skills) — requires the `gh auth login` from Phase 0 (or an SSH remote)
git clone https://github.com/noah-goodrich/claude-plugins-private ~/dev/claude-plugins-private

# Wire dotfiles symlinks (zshrc, tmux, secrets.zsh, CLAUDE.md)
bash ~/.config/dotfiles/install.sh
```

**[ASSUMPTION]** dotfiles `install.sh` sets up `~/.zshrc`, tmux config, and sources `secrets.zsh`. If
absent, `borg setup` warns about missing dotfiles but still proceeds.

When `claude` is installed, dotfiles `install.sh` also registers the `noah-local` marketplace and installs every
plugin in `~/dev/claude-plugins` — this runs here, before `borg setup` builds the borg-collective mirror. So
`claude-plugins` must already be cloned and `claude` installed (Phase 0) before this step; `noah-private` still
needs 3c and 3e. The dotfiles `CLAUDE.md` imports `@~/.claude/borg-managed.md`, which only `borg setup` writes, so
that import dangles harmlessly until Phase 3 completes. The `bash-guard` and notify hooks also come only from
`borg setup`.

---

## Phase 2 — Keychain secrets

Convention: Keychain **SERVICE = ENV_VAR** (uppercase, underscores). You supply all values.

**Critical:** the Anthropic key (used by Python SDK scripts) is stored as **`ANTHROPIC_SDK_KEY`**,
NOT `ANTHROPIC_API_KEY`. Claude Code itself uses your Max subscription and does not read this key.

```zsh
# Core (borg)
security add-generic-password -s "ANTHROPIC_SDK_KEY" -a "$USER" -w "<your-anthropic-api-key>" -U
security add-generic-password -s "GOOGLE_API_KEY"    -a "$USER" -w "<your-google-api-key>" -U   # optional

# Work: Jira
security add-generic-password -s "JIRA_API_TOKEN" -a "$USER" -w "<token>" -U
security add-generic-password -s "JIRA_USERNAME"  -a "$USER" -w "<email>" -U
security add-generic-password -s "JIRA_URL"       -a "$USER" -w "<https://yourco.atlassian.net>" -U

# Work: Nexus corporate PyPI — all three together wire PIP_INDEX_URL to the internal mirror
security add-generic-password -s "NEXUS_HOST"     -a "$USER" -w "<nexus.yourco.com>" -U
security add-generic-password -s "NEXUS_USERNAME" -a "$USER" -w "<token-name>" -U
security add-generic-password -s "NEXUS_TOKEN"    -a "$USER" -w "<token>" -U

# Optional / repository-specific
security add-generic-password -s "SNOWFLAKE_PAT"         -a "$USER" -w "<pat>" -U
security add-generic-password -s "SUPABASE_ACCESS_TOKEN" -a "$USER" -w "<token>" -U
```

```zsh
source ~/.zshrc
echo "ANTHROPIC_SDK_KEY length: ${#ANTHROPIC_SDK_KEY}"   # verify it resolves
```

---

## Phase 3 — borg-collective install + Claude Code plugin

`install.sh` is the only supported install path: it installs the borg + drone CLIs, LaunchAgents, and
runs `borg setup` (hooks, skills, agents, tmux keybinding, plugin). There is no Homebrew formula for
borg itself — Homebrew is used only for the prerequisite tooling installed back in Phase 0.

```zsh
# 3a. Install borg + drone CLIs (also runs `borg setup` automatically).
# NOTE: install.sh is INTERACTIVE — it ends with "Install plugin now? [y/N]".
#   Answer y  -> it installs the Claude Code plugin for you; then SKIP Phase 3d.
#   Answer N  -> install the plugin manually in Phase 3d.
cd ~/dev/borg-collective && ./install.sh

# Ensure BOTH ~/.local/bin AND ~/.claude/bin are on PATH (the installer wants both).
echo 'export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# 3b. Re-run setup once dotfiles are confirmed (idempotent)
borg setup
```

> install.sh may warn that `~/.claude/bin` is **not on PATH** even after the export above — this is a
> **false positive**: the installer checks the *current* shell before the new `.zshrc` is sourced. Verify
> with `echo $PATH | tr ':' '\n' | grep -E '\.claude/bin|\.local/bin'` after `source ~/.zshrc`; if both
> appear, ignore the warning.

`install.sh` installs
`~/.local/bin/{borg,drone,borg-notifyd,borg-cortex-watch,borg-vinculum-watch,borg-usage-watch,borg-memory-gate}`
+ LaunchAgents. `borg setup` deploys hooks and bin utilities, builds the plugin that carries skills and agents
(incl. `borg-nanoprobe`) and hook registration, adds the tmux keybinding, runs `borg scan`, and writes
`~/.config/borg/config.zsh` and `~/.claude/borg-managed.md`.

LaunchAgent labels are `<prefix>.borg.<agent>`. The prefix comes from `$LAUNCHD_LABEL_PREFIX` or the first line of
`~/.config/launchd-prefix`; with neither, the label is plain `borg.<agent>` (resolver: `lib/launchd-label.zsh`).
`install.sh` also:

- installs `borg-memory-gate` with a daily agent;
- writes the `pr-watch` agent but does not arm it — set `BORG_PR_WATCH_ENABLED=1` to bootstrap it;
- renders any `.plist.tmpl` extension templates from `~/.config/borg/extensions/launchd/` (extension labels are
  `<prefix>.<name>`, or `local.<name>` with no prefix);
- migrates legacy-labelled agents to the resolved label.

`borg setup` can also offer to `brew install` missing recommended tools (jq, fzf, neovim) — answer `Y`.

The `borg-usage-watch` LaunchAgent samples `claude -p "/usage"` every 120s to observe session/week
usage percentages (observe-only — no checkpointing, no dispatch veto). It costs **$0**: verified via
`total_cost_usd: 0`, `num_turns: 0`, and zero tokens in its own transcript — it never invokes a model.
It is installed by default on every machine; set `BORG_USAGE_WATCH=0 ./install.sh` to opt out (this
also removes an already-bootstrapped agent so the flag takes effect on re-run).

```zsh
# 3c. Register BOTH plugin marketplaces (add to ~/.claude/settings.json if missing).
# Use YOUR real home path — on this work machine that's /Users/<user>/dev/....
#   "extraKnownMarketplaces": {
#     "noah-local":   { "source": { "source": "directory", "path": "$HOME/dev/claude-plugins" },
#                       "autoUpdate": true },
#     "noah-private": { "source": { "source": "directory", "path": "$HOME/dev/claude-plugins-private" },
#                       "autoUpdate": true }
#   }
# If Claude Code does not expand $HOME in settings.json, use the literal absolute path
# (e.g. /Users/<user>/dev/claude-plugins).

# 3d. Install the plugin — ONLY if you answered N to install.sh's "Install plugin now?" prompt in 3a.
# (the plugin owns hook registration — hooks don't fire without it)
# borg setup (already run in 3a) publishes the plugin package automatically, so this should succeed.
claude plugin install borg-collective@noah-local
claude plugin list | grep borg-collective       # same version as below
borg version                                     # must match the plugin
```

> `borg setup` (run automatically by `install.sh`) rebuilds the plugin package into
> `$HOME/dev/claude-plugins/borg-collective/` on every run and ensures the `borg-collective` entry is present in
> the marketplace manifest — so `claude plugin install borg-collective@noah-local` works on the first run
> without any manual marketplace editing. The plugin version equals `borg --version`. After Phase 3, run
> `claude plugin update borg-collective@noah-local` and restart Claude Code so the freshly built plugin loads.
>
> A `DRIFT` warning from the build means the committed mirror is behind source; the local rebuild is correct but
> uncommitted. Run `git -C ~/dev/claude-plugins status` after the install, and restore or stash that directory
> before the next pull if the machine must not diverge. Verify parity by checking that the installed plugin
> contains `hooks/borg-agent-model-guard.sh`, not by the version string alone.

> **Model tiers and routing.** The account needs Opus at `xhigh` effort, plus Sonnet and Haiku. `borg init`,
> `borg claude` and drone launches run `claude --model ${BORG_CLAUDE_MODEL:-opus} --effort
> ${BORG_CLAUDE_EFFORT:-xhigh}`, so keep Claude Code current enough to accept `--effort`. The plugin hook
> `hooks/borg-agent-model-guard.sh` denies Agent spawns that are untyped, `general-purpose`, `Explore`, `Plan` or
> not in the allowed list, and the Workflow guard fails closed. Kill switches: `BORG_AGENT_MODEL_GUARD=0` and
> `BORG_WORKFLOW_MODEL_GUARD=0`. Both guards need `python3` and fail open without it.

```zsh
# 3e. Install the private personal plugin (employer-specific skills) from the noah-private marketplace.
claude plugin install noah-personal@noah-private
claude plugin list | grep noah-personal
```

> **Why plugins and not `~/.claude/skills`:** `borg setup` cleans non-borg skills out of `~/.claude/skills`
> (the borg-collective#64 stale-skill trap — a v0.8.6 guard now scopes the cleanup, but the rule stands).
> Hand-authored skills belong in a plugin repo: public → `claude-plugins` (`noah-local`), employer-specific or
> otherwise sensitive → `claude-plugins-private` (`noah-private`). Never park skills loose in `~/.claude/skills`.

---

## Phase 4 — cairn (decommissioned)

cairn was decommissioned on 2026-08-08: DB dropped, service/hooks/CLI removed, repo archived. Its
corpus now lives in per-repository `.borg/knowledge/*.md` markdown (grep-reachable, no service required).
This phase is no longer part of setup.

> **Podman reminder:** the machine VM does **not** auto-start at login (unlike OrbStack) — run
> `podman machine start` after every reboot before running any local container workloads.

---

## Phase 5 — Verify everything

```zsh
borg link                                # the front door page
borg add ~/dev                           # register the Queen's root
claude plugin list | grep borg-collective
borg next                                # recommendation engine
borg doctor                              # agents, claude -p, clock, gh floor
borg init                                # optional: launch the Queen
```

---

## Ongoing

- **Podman:** the machine VM does **not** auto-start at login — restart it after every reboot with
  `podman machine start` before running local container workloads. There is no login-item equivalent
  to OrbStack.
