# Fresh macOS Work Machine — Borg Setup Runbook

> **This is THE canonical work-machine reference** — fresh setup AND ongoing updates. The
> similarly-named `~/.config/dotfiles/docs/work-machine-setup.md` covers ONLY the dotfiles
> identity/config-sync slice (git email, Keychain-backed secrets, layered config) and points back here
> for everything else.

> **cairn decommissioned (2026-08-08):** cairn (the Postgres+pgvector knowledge-graph service formerly
> set up here) has been fully decommissioned — DB dropped, service/hooks/CLI removed, repo archived.
> Its corpus now lives in per-project `.borg/knowledge/*.md` markdown, grep-reachable with no service
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
> (`noah-local`), Ontra-specific / not-publicly-shareable ones in `claude-plugins-private` (`noah-private`,
> private GitHub repo). Skills must live in plugins — `borg setup` cleans hand-dropped non-borg skills out of
> `~/.claude/skills` (the borg-collective#64 stale-skill trap, fixed in v0.8.6 by the cleanup guard).

---

## Updating an existing machine (incremental sync)

Already set up? Skip the phases below and run this **one-block update flow** instead — it pulls dotfiles
and all three repos, redeploys borg, and finishes with `borg doctor` so you know the machine is actually
healthy, not just "pulled."

```zsh
# 1. Pull dotfiles first and re-run its installer (identity/config sync + LaunchAgents, incl.
#    the dev-postgres auto-start agent that local project databases depend on).
git -C ~/.config/dotfiles pull --ff-only && bash ~/.config/dotfiles/install.sh

# 2. Pull all three remaining repos on main, fast-forward only
git -C ~/dev/borg-collective pull --ff-only && git -C ~/dev/claude-plugins pull --ff-only && \
  git -C ~/dev/claude-plugins-private pull --ff-only

# 3. Redeploy borg (REQUIRED — see note). install.sh is interactive ("Install plugin now?"); either answer is fine.
cd ~/dev/borg-collective && ./install.sh        # or: borg setup

# 4. Verify borg CLI and plugin report the SAME version, then run the full health check
borg version && claude plugin list | grep borg-collective && borg doctor
```

- **Step 3 is required:** borg's CLI/libs run from the source clone (a pull refreshes those live), but hooks + the
  bash lib + skills + agents are **copied** into `~/.claude` and only refresh on `install.sh` / `borg setup`.
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
  doubt, check the mirror's last sync against `borg-collective`'s latest tag, not just the version string.
- **Step 4's `borg doctor` is the real health verification step** — it checks all four launchd agents
  (notifyd, cortex-wake, usage-watch, reap) for registration, exit status, and output freshness in one
  shot. A clean pull + `install.sh` with no `borg doctor` check is an unverified update; always finish
  with it.
- **Step 1 (dotfiles) closes a real gap:** the flow previously pulled borg-collective / claude-plugins /
  claude-plugins-private / cairn but never dotfiles, so LaunchAgent changes there (e.g. the dev-postgres
  auto-start agent) silently never landed on already-set-up machines.

> **2026-07-08:** additions picked up by a plain pull + setup = the `code-governance` plugin (capability-index +
> reconcile-req) and the distilled `research` skill.
> **2026-07-08 (later):** the private marketplace exists now — `claude-plugins-private` repo → `noah-private`
> marketplace → `noah-personal` plugin (Ontra-specific skills, e.g. `noah-weekly-status`). Clone + register per
> Phases 1 / 3c / 3e below.
> **2026-07-09:** `install.sh` now installs the `borg-usage-watch` LaunchAgent by default (opt out with
> `BORG_USAGE_WATCH=0 ./install.sh`) and verifies it produces a fresh sample after bootstrap. New command
> `borg doctor` checks all four launchd agents (notifyd, cortex-wake, usage-watch, reap) for registration,
> exit status, and output freshness — run it any time an agent seems blind or unhealthy.

### What's new since 2026-07-09

- **2026-08-08: cairn fully decommissioned.** The Postgres+pgvector knowledge-graph service (DB, container,
  hooks, CLI, and the `borg-collective#94` Stop-hook heartbeat) has been removed outright — not just
  disabled. Its corpus now lives in per-project `.borg/knowledge/*.md` markdown, grep-reachable with no
  service required; a fresh pull removes Phase 4 (below) entirely, there's nothing left to run. **If a
  session was already running when the pull landed, its Stop hook may still reference the deleted
  `borg-cairn-heartbeat.sh` and log a harmless "No such file or directory" — restart the Claude Code
  session after this pull to clear it; nothing else is affected.** See `CLAUDE.md`'s "Cairn decommission"
  entry under Learned for the full rationale (measured near-zero cross-project recall value).
- **2026-08-08: `borg sever` now stops the shared Supabase stack.** Fixed a gap (#110) where severing a
  project left the shared `supabase_*_stillpoint` containers running; `cmd_down` now calls
  `_borg_stop_shared_supabase` (idempotent, fail-open) as part of the sever flow. Nothing to run — behavior
  change only.
- **2026-07-27:** the update flow now pulls `~/.config/dotfiles` first (was missing) — its
  `install.sh` re-registers LaunchAgents, including the dev-postgres auto-start agent that local
  project databases need. This doc is now the single canonical work-machine reference (fresh setup
  AND updates); `~/.config/dotfiles/docs/work-machine-setup.md` covers only the dotfiles
  identity/config-sync slice.

  - **dotfiles #12:** dev-postgres auto-start LaunchAgent (delivered by the update flow's dotfiles
    pull + `install.sh`).
  - **borg-collective #94:** cairn heartbeat Stop hook + hail/link status callouts (rebuilt from
    source by `install.sh` / `borg setup`). **Superseded 2026-08-08** — the cairn heartbeat hook was
    removed outright in the decommission above; hail/link status callouts now read local
    `.borg/knowledge/*.md` instead.

- **borg-collective is now v0.8.9** (was 0.8.6 on 2026-07-09; `VERSION` file + plugin manifest both
  confirmed). The `claude-plugins` mirror of the plugin is rebuilt to match (0.8.9) with a full
  synthetic-session guard, so hooks stay quiet during internal `/usage` polling and other non-interactive
  probe sessions.
- **`bash-guard` security hardening** — closed four Tier-A pre-approval bypasses (`rm`/`chmod` token
  matching, force-push + settings-write normalization, wrapper-prefix and bare-`&` segment bypasses).
  Nothing to run — just be aware guard behavior changed if a previously-allowed one-liner now prompts.
- **`borg doctor` and the `borg-usage-watch` LaunchAgent** (introduced 2026-07-09, see note above) have
  since had bug fixes: bare 0%-session line parsing, a stderr-leak fix so `borg-link-down` never splices
  a shell error into its JSON output, and delivery-spike resolution for the usage guardian.
- **`drone scaffold --supabase-shared`** — a second, opt-in scaffold path for a shared-local-Supabase
  setup (join a fixed always-on Supabase Docker network instead of a per-project instance). Inert unless
  you explicitly use the `--supabase-shared` flag; does not change default `--supabase` behavior.

---

## Prerequisites to verify manually before running anything

- [ ] macOS with Xcode Command Line Tools (`xcode-select --install`).

---

## Phase 0 — Prerequisites: Homebrew, packages, Docker, Claude Code, gh

```zsh
# Install Homebrew (skip if already present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Required CLI tools for borg + general dev
brew install jq fzf tmux git gh ripgrep neovim fswatch

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

---

## Phase 1 — Clone repos

Expected layout under `~/dev/` — borg expects `BORG_ORCHESTRATOR_ROOT=$HOME/dev`.

```zsh
mkdir -p ~/dev
git clone https://github.com/noah-goodrich/borg-collective ~/dev/borg-collective
git clone https://github.com/noah-goodrich/dotfiles ~/.config/dotfiles
git clone https://github.com/noah-goodrich/claude-plugins ~/dev/claude-plugins

# PRIVATE repo (Ontra-specific skills) — requires the `gh auth login` from Phase 0 (or an SSH remote)
git clone https://github.com/noah-goodrich/claude-plugins-private ~/dev/claude-plugins-private

# Wire dotfiles symlinks (zshrc, tmux, secrets.zsh, CLAUDE.md)
bash ~/.config/dotfiles/install.sh
```

**[ASSUMPTION]** dotfiles `install.sh` sets up `~/.zshrc`, tmux config, and sources `secrets.zsh`. If
absent, `borg setup` warns about missing dotfiles but still proceeds.

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

# Optional / project-specific
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
`~/.local/bin/{borg,drone,borg-notifyd,borg-cortex-watch,borg-vinculum-watch,borg-usage-watch}` +
LaunchAgents. `borg setup` deploys hooks, skills, agents (incl. `borg-nanoprobe`), bin utilities, the
tmux keybinding, runs `borg scan`, and writes `~/.config/borg/config.zsh`.

The `borg-usage-watch` LaunchAgent samples `claude -p "/usage"` every 120s to observe session/week
usage percentages (observe-only — no checkpointing, no dispatch veto). It costs **$0**: verified via
`total_cost_usd: 0`, `num_turns: 0`, and zero tokens in its own transcript — it never invokes a model.
It is installed by default on every machine; set `BORG_USAGE_WATCH=0 ./install.sh` to opt out (this
also removes an already-bootstrapped agent so the flag takes effect on re-run).

```zsh
# 3c. Register BOTH plugin marketplaces (add to ~/.claude/settings.json if missing).
# Use YOUR real home path — on this work machine that's /Users/noahgoodrich/dev/....
#   "extraKnownMarketplaces": {
#     "noah-local":   { "source": { "source": "directory", "path": "$HOME/dev/claude-plugins" },
#                       "autoUpdate": true },
#     "noah-private": { "source": { "source": "directory", "path": "$HOME/dev/claude-plugins-private" },
#                       "autoUpdate": true }
#   }
# If Claude Code does not expand $HOME in settings.json, use the literal absolute path
# (e.g. /Users/noahgoodrich/dev/claude-plugins).

# 3d. Install the plugin — ONLY if you answered N to install.sh's "Install plugin now?" prompt in 3a.
# (the plugin owns hook registration — hooks don't fire without it)
# borg setup (already run in 3a) publishes the plugin package automatically, so this should succeed.
claude plugin install borg-collective@noah-local
claude plugin list | grep borg-collective       # expect: borg-collective@noah-local  0.8.9
borg version                                     # should print the same version number (e.g. 0.8.9)
```

> `borg setup` (run automatically by `install.sh`) publishes the plugin package into
> `$HOME/dev/claude-plugins/borg-collective/` and ensures the `borg-collective` entry is present in the
> marketplace manifest — so `claude plugin install borg-collective@noah-local` works on the first run
> without any manual marketplace editing.

```zsh
# 3e. Install the private personal plugin (Ontra-specific skills) from the noah-private marketplace.
claude plugin install noah-personal@noah-private
claude plugin list | grep noah-personal
```

> **Why plugins and not `~/.claude/skills`:** `borg setup` cleans non-borg skills out of `~/.claude/skills`
> (the borg-collective#64 stale-skill trap — a v0.8.6 guard now scopes the cleanup, but the rule stands).
> Hand-authored skills belong in a plugin repo: public → `claude-plugins` (`noah-local`), Ontra-specific or
> otherwise sensitive → `claude-plugins-private` (`noah-private`). Never park skills loose in `~/.claude/skills`.

---

## Phase 4 — cairn (decommissioned)

cairn was decommissioned on 2026-08-08: DB dropped, service/hooks/CLI removed, repo archived. Its
corpus now lives in per-project `.borg/knowledge/*.md` markdown (grep-reachable, no service required).
This phase is no longer part of setup.

> **Podman reminder:** the machine VM does **not** auto-start at login (unlike OrbStack) — run
> `podman machine start` after every reboot before running any local container workloads.

---

## Phase 5 — Verify everything

```zsh
borg link                                # project dashboard
borg add ~/dev                           # register orchestrator root if not auto-discovered
claude plugin list | grep borg-collective
borg next                                # recommendation engine
borg doctor                              # verify the 4 launchd agents (registered/exit/fresh output)
borg init                                # optional: morning briefing + orchestrator session
```

---

## Ongoing

- **Podman:** the machine VM does **not** auto-start at login — restart it after every reboot with
  `podman machine start` before running local container workloads. There is no login-item equivalent
  to OrbStack.
