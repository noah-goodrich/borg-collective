# Fresh macOS Work Machine — Borg + Cairn Setup Runbook

**Target:** Apple Silicon macOS. Read every phase before running. Steps are in dependency order.
Copy-paste blocks chain with `&&` or `;` — `;` continues on failure (independent steps), `&&` stops on
failure (dependent sequences).

> Distribution model (context): **borg-collective ships in two forms that share one version (`v0.8.0`):**
> the **CLI** (via a Homebrew formula `Formula/borg-collective.rb`, or `install.sh`) and the **Claude Code
> plugin** (hooks/skills/agents, via the `noah-local` marketplace). The plugin version tracks the CLI
> version, so `borg --version` and `claude plugin list` should report the **same** number. **cairn ships
> as a GHCR container image** (Homebrew was rejected for cairn). Homebrew is also used for prerequisite
> tooling (jq, tmux, …).

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

## Phase 3 — borg-collective install + Claude Code plugin (v0.8.0)

The CLI and the plugin share version **v0.8.0**. `install.sh` is the recommended path (it installs the
borg + drone CLIs, LaunchAgents, and runs `borg setup`). A published **Homebrew tap** exists as a
CLI-only alternative:

```zsh
brew install noah-goodrich/borg-collective/borg-collective
# equivalently: brew tap noah-goodrich/borg-collective && brew install borg-collective
```

…but the tap installs only the `borg` CLI — you still need `./install.sh` / `borg setup` afterward for
hooks, drone, agents, and the plugin, so prefer `install.sh` on a fresh machine.

> ⚠ **Do not `brew uninstall borg-collective` casually.** It cascades and removes orphaned dependencies
> including **`jq`, `fzf`, and `oniguruma`** — and **borg depends on `jq`**, so this leaves borg broken.
> If you ever switch off the brew install, immediately run `brew install jq fzf` to restore the runtime
> deps.

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

`install.sh` installs `~/.local/bin/{borg,drone,borg-notifyd,borg-cortex-watch}` + LaunchAgents.
`borg setup` deploys hooks, skills, agents (incl. `borg-nanoprobe`), bin utilities, the tmux keybinding,
runs `borg scan`, and writes `~/.config/borg/config.zsh`.

```zsh
# 3c. Register the noah-local plugin marketplace (add to ~/.claude/settings.json if missing).
# Use YOUR real home path — on this work machine that's /Users/noahgoodrich/dev/claude-plugins.
#   "extraKnownMarketplaces": {
#     "noah-local": { "source": { "source": "directory", "path": "$HOME/dev/claude-plugins" },
#                     "autoUpdate": true }
#   }
# If Claude Code does not expand $HOME in settings.json, use the literal absolute path
# (e.g. /Users/noahgoodrich/dev/claude-plugins).

# 3d. Install the plugin — ONLY if you answered N to install.sh's "Install plugin now?" prompt in 3a.
# (the plugin owns hook registration — hooks don't fire without it)
claude plugin install borg-collective@noah-local
claude plugin list | grep borg-collective       # expect: borg-collective@noah-local  0.8.0 (== borg --version)
```

**[ASSUMPTION]** No `borg` command writes the marketplace entry; add it via Claude Code `/settings` or
by editing `~/.claude/settings.json` directly.

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
