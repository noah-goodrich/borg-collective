# Fresh macOS Work Machine — Borg + Cairn Setup Runbook

**Target:** Apple Silicon macOS. Read every phase before running. Steps are in dependency order.
Copy-paste blocks chain with `&&` or `;` — `;` continues on failure (independent steps), `&&` stops on
failure (dependent sequences).

> Distribution model (context): **borg-collective ships in two forms that share one version:** the
> **CLI** (via `install.sh` from a source clone) and the **Claude Code plugin** (hooks/skills/agents, via
> the `noah-local` marketplace). The plugin version tracks the CLI version, so `borg version` and
> `claude plugin list` should report the **same** number. **cairn ships as a GHCR container image.**
> Homebrew is used only for prerequisite tooling (jq, tmux, fswatch, …), never for borg itself.
> **Personal skills ship as plugins too**, split across two marketplaces: public ones in `claude-plugins`
> (`noah-local`), Ontra-specific / not-publicly-shareable ones in `claude-plugins-private` (`noah-private`,
> private GitHub repo). Skills must live in plugins — `borg setup` cleans hand-dropped non-borg skills out of
> `~/.claude/skills` (the borg-collective#64 stale-skill trap, fixed in v0.8.6 by the cleanup guard).

---

## Updating an existing machine (incremental sync)

Already set up? Skip the phases below and run this update flow instead.

```zsh
# 1. Pull all four repos
git -C ~/dev/borg-collective pull --ff-only && git -C ~/dev/claude-plugins pull --ff-only && \
  git -C ~/dev/claude-plugins-private pull --ff-only && git -C ~/dev/cairn pull --ff-only

# 2. Redeploy borg (REQUIRED — see note). install.sh is interactive ("Install plugin now?"); either answer is fine.
cd ~/dev/borg-collective && ./install.sh        # or: borg setup

# 4. cairn — ONLY if its GHCR image bumped; otherwise no action.
cd ~/dev/cairn && ./bin/cairn-up

# 5. Verify borg CLI and plugin report the SAME version
borg version && claude plugin list | grep borg-collective
```

- **Step 2 is required:** borg's CLI/libs run from the source clone (a pull refreshes those live), but hooks + the
  bash lib + skills + agents are **copied** into `~/.claude` and only refresh on `install.sh` / `borg setup`.
- **Step 3 (Claude Code plugins) is automatic:** `code-governance`, `research-tools`, etc. auto-update from the pulled
  `~/dev/claude-plugins` via the `noah-local` marketplace (`autoUpdate: true`) — no extra step; verify with
  `claude plugin list`. Same for `noah-personal` from `~/dev/claude-plugins-private` via `noah-private`
  (`autoUpdate: true`).

> **2026-07-08:** additions picked up by a plain pull + setup = the `code-governance` plugin (capability-index +
> reconcile-req) and the distilled `research` skill.
> **2026-07-08 (later):** the private marketplace exists now — `claude-plugins-private` repo → `noah-private`
> marketplace → `noah-personal` plugin (Ontra-specific skills, e.g. `noah-weekly-status`). Clone + register per
> Phases 1 / 3c / 3e below.
> **2026-07-09:** `install.sh` now installs the `borg-usage-watch` LaunchAgent by default (opt out with
> `BORG_USAGE_WATCH=0 ./install.sh`) and verifies it produces a fresh sample after bootstrap. New command
> `borg doctor` checks all four launchd agents (notifyd, cortex-wake, usage-watch, reap) for registration,
> exit status, and output freshness — run it any time an agent seems blind or unhealthy.

---

## Prerequisites to verify manually before running anything

- [x] **VERIFIED (2026-06-11):** `ghcr.io/noah-goodrich/cairn:0.2.0` is **public and pulls cleanly**
      (multi-arch amd64+arm64), so Phase 4 Option A works as written — no action needed. (If it ever
      401/404s after a re-tag, re-set the package visibility to "Public" in GitHub → Packages; otherwise
      Option A falls back to the local source build in Option B.)
- [ ] macOS with Xcode Command Line Tools (`xcode-select --install`).

---

## Phase 0 — Prerequisites: Homebrew, packages, Docker, Claude Code, gh

```zsh
# Install Homebrew (skip if already present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Required CLI tools for borg + general dev
brew install jq fzf tmux git gh ripgrep neovim fswatch

# Docker runtime — choose ONE. OrbStack is recommended on Apple Silicon.
brew install --cask orbstack        # recommended
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
git clone https://github.com/noah-goodrich/cairn ~/dev/cairn
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

**Critical:** the Anthropic key (Python SDK + cairn boardroom/backfill) is stored as **`ANTHROPIC_SDK_KEY`**,
NOT `ANTHROPIC_API_KEY`. Claude Code itself uses your Max subscription and does not read this key.

```zsh
# Core (borg + cairn)
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
claude plugin list | grep borg-collective       # expect: borg-collective@noah-local  0.8.0
borg version                                     # should print the same version number (e.g. 0.8.0)
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

## Phase 4 — cairn bring-up

cairn is optional; borg degrades gracefully without it.

```zsh
# 4a. Docker network
docker network inspect devnet >/dev/null 2>&1 || docker network create devnet

# 4b. Bring up cairn (Option A GHCR image; auto-falls-back to local build via compose `build:` block)
cd ~/dev/cairn && ./bin/cairn-up

# 4c. Smoke test
curl -s http://localhost:8767/health | jq .        # expect {"status":"ok","db":"reachable",...}
curl -s http://localhost:8767/ready                # confirms embedding model + migrations loaded

# 4d. Install the cairn CLI (symlinks cli/cairn -> ~/.local/bin/cairn, idempotent)
cd ~/dev/cairn && make install-cli

# 4e. Remove the legacy dotfiles shim ONLY after the repo CLI is confirmed healthy
cairn health && rm ~/.config/dotfiles/zsh/bin/cairn && echo "Shim removed — repo CLI active."
```

`cairn-up` creates `devnet`, detects/starts `dev-postgres` (bundles one if absent), generates
`~/dev/cairn/.env` with a random `POSTGRES_PASSWORD`, runs `docker compose`, and polls `/ready` until the
~400 MB fastembed model loads (up to ~3 min first boot).

---

## Phase 5 — Verify everything

```zsh
borg ls                                  # project dashboard
borg add ~/dev                           # register orchestrator root if not auto-discovered
cairn health                             # liveness
cairn stats                              # record counts (0 on a fresh machine is fine)
claude plugin list | grep borg-collective
borg next                                # recommendation engine
borg doctor                              # verify the 4 launchd agents (registered/exit/fresh output)
borg init                                # optional: morning briefing + orchestrator session
```

---

## Ongoing

- cairn's `compose.yml` uses `restart: unless-stopped` — it auto-restarts after reboot as long as the
  Docker daemon starts at login (OrbStack: default yes; Docker Desktop: enable "Start at Login").
- Restart manually anytime: `cd ~/dev/cairn && ./bin/cairn-up`.

---

## Cairn — effective daily use

- **`cairn health`** — liveness; run when a hook warns "cairn unavailable". `/ready` confirms model +
  migrations after a restart.
- **`cairn stats`** — record counts by type; sanity-check that hooks are writing.
- **`cairn search "query"`** — semantic search across recorded knowledge (also via `borg search`).
- **`cairn record decision --id … --project … …`** — manual save; the `record_*` MCP tools do the same
  from inside a Claude Code session.
- **Hooks auto-record** — the Stop hook (`borg-link-up.sh`) writes a session debrief to cairn; run
  `/borg-link-up` before ending a session to flush the checkpoint and trigger it.
- **Optional + graceful** — borg probes `:8767/health` at hook time; if down, it warns and skips the
  write. `<project>/.borg/checkpoints/` is the always-present local fallback.
