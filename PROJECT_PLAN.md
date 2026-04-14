# Project Plan: Borg Collective v0.7 — Work-Ready, Team-Portable, Always-On
*Established: 2026-04-14*

## Objective

Ship borg-collective v0.7 with: (a) a team-portable default devcontainer that works in Cursor
and Antigravity without borg-collective present, (b) a registry-backed shared base image with
Claude + Cortex installed upgradeably, (c) project-scoped visual identity and output namespacing,
(d) Cortex Code parity with Claude Code in `drone`, (e) CLAUDE.md copy-on-setup, (f) an always-
on skill for the read-permission rule, (g) per-environment and per-project extension overlays,
and (h) fixes for the plugin marketplace path bug and the neovim pathing issues.

## Acceptance Criteria

### Session 1 — Reliability fixes

- [x] **CLAUDE.md copy strategy** — `borg setup` writes `~/.claude/CLAUDE.md` as a file copy
  (not symlink). `borg-start.sh` integrity-checks and re-copies if stale. `drone.zsh:916`
  devcontainer postStartCommand copies instead of symlinking.
  - Verify: `file ~/.claude/CLAUDE.md` reports "ASCII text"; `borg setup` re-syncs after source
    changes; session start heals silently.

- [x] **Always-on read-permission skill** — `skills/no-unnecessary-read-perms/SKILL.md` created
  (≤100 token body, no `user-invocable`). `borg setup` installs it to Claude + Cortex skills.
  - Verify: skill appears in Active Skills list every session.

- [x] **Checkpoint persistence** — `skills/borg-checkpoint/SKILL.md` writes timestamped file at
  `<project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md` in addition to displaying summary.
  - Verify: `/borg-checkpoint` creates the file; re-running creates a new timestamped entry.

- [x] **/simplify before /borg-assimilate** — `skills/borg-assimilate/SKILL.md` has new Step 0
  requiring `/simplify` before evaluating criteria. Blocks on confirmation if skipped.
  - Verify: read updated SKILL.md; Step 0 references `/simplify`.

### Session 2 — Pathing bugs

- [ ] **Plugin marketplace path fix** — host-absolute path in `~/.claude/settings.json` for
  local plugin marketplace resolves inside containers via compatibility symlink in postStart.
  - Verify: `claude /doctor` in fresh container reports marketplace resolved.

- [ ] **Neovim pathing fix** — nvim opens without path errors in fresh container; lazy.nvim
  sync succeeds; LSP and treesitter resolve. (May require dotfiles-repo changes.)
  - Verify: `nvim --headless "+Lazy sync" "+q"` completes in container without errors.

### Session 3 — Ergonomics

- [ ] **Project session colors** — registry gains `color` field; `borg color <project> <name>`
  sets it; deterministic fallback via name hash. `drone up|claude|cortex` apply tmux window
  status color. New `lib/colors.zsh`.
  - Verify: `borg color wayfinderai-waypoint cyan && drone up` → tmux shows cyan window.

- [ ] **Cortex Code parity in drone** — `drone cortex [project]` launches Cortex Code mirroring
  `drone claude`. Color applied. `drone status` shows Cortex sessions.
  - Verify: `drone cortex wayfinderai-waypoint` opens Cortex window; stop hook fires on exit.

- [ ] **Verify Cortex reads Claude skills natively** — confirm or deny whether Cortex CLI reads
  `~/.claude/skills/` directly. If yes: remove `cortex skill add` loop (`borg.zsh:1822-1826`).
  - Verify: skill added to `~/.claude/skills/` appears in Cortex session without `cortex skill add`.

### Session 4 — Extensibility + output namespacing

- [ ] **Per-environment extension overlay** — `~/.config/borg/extensions/skills/*/` symlinked
  into Claude + Cortex skills dirs by `borg setup`. Extension hooks registered. Extension
  `config.zsh` sourced. Extension `CLAUDE.md` appended.
  - Verify: drop test skill in extensions dir, run `borg setup`, confirm skill resolves.

- [ ] **Per-project extension overlay** — `<project>/.borg/skills/*/` symlinked on session start
  by `borg-start.sh`; cleaned up on stop by `borg-stop.sh`.
  - Verify: skill in `.borg/skills/` appears in session; removed on exit.

- [ ] **Hybrid output location** — all per-project runtime state writes to `<project>/.borg/`
  (gitignored). Debriefs at `.borg/debriefs/`, checkpoints at `.borg/checkpoints/`, handovers
  at `.borg/handovers/`. `borg setup` appends `.borg/` to registered project `.gitignore`.
  - Verify: session debrief lands in `wayfinderai-waypoint/.borg/debriefs/<id>.md`; `.borg/` in
    project `.gitignore`.

### Session 5 — Team portability, part 1

- [ ] **Compose profile split** — default profile is team-portable (borg mounts under
  `profiles: [borg]`). `drone up` sets `COMPOSE_PROFILES=borg` automatically. Cursor/Antigravity
  users get a working container without borg mounts.
  - Verify: `COMPOSE_PROFILES= docker compose -f docker-compose.base.yml config` shows no borg
    mounts; `COMPOSE_PROFILES=borg` shows them.

- [ ] **Claude + Cortex installed upgradeably** — removed from Dockerfile bake; installed via
  named npm volume in postCreateCommand. Upgrades work inside container without rebuild.
  - Verify: `drone rebuild`, `claude --version` and `cortex --version` both work; version
    persists after rebuild.

### Session 6 — Team portability, part 2

- [ ] **`borg image build|push|pull`** — new `cmd_image` in `borg.zsh`. Config-driven registry
  (`BORG_IMAGE_REGISTRY`). Push requires `yes` confirmation showing resolved registry URL.
  - Verify: `borg image build` produces local image; push shows confirm prompt.

- [ ] **Regression** — `bats tests/*.bats` green; `shellcheck` green; end-to-end smoke test
  passes.
  - Verify: run the smoke test in `docs/v0.7-upgrade.md`.

## Scope Boundaries

- NOT building: Extension marketplace, cross-machine debrief sync, automated CI/CD for image
  builds, Docker-in-Docker, corporate proxy/CA cert support.
- NOT building: Migration of existing debriefs from global to per-project — manual only.
- NOT building: borg runtime inside containers. Borg stays host-side.
- If done early: Ship. Do not expand scope.

## Ship Definition

1. All criteria above verified green.
2. `bats tests/*.bats` and `shellcheck` pass.
3. `/simplify` run on changed files.
4. PR merged to main; VERSION bumped to `0.7.0`; Homebrew formula updated.
5. `borg image build` run on personal registry for dog-fooding.
6. PROJECT_PLAN.md archived to `docs/plans/assimilated/2026-04-14-v0.7-work-ready.md`.

## Timeline

6 sessions × ~3 hours. Session 1 criteria are complete; remaining sessions build on them.
Do not bundle sessions — each must end with a working `borg setup`.

## Risks

- CLAUDE.md clobbering root cause unknown; copy + session-start heal mitigates the symptom.
- Compose profile split is blast-radius-of-6; ship behind a `drone rebuild` nudge.
- Always-on skills budget: total ≤500 tokens/turn across all always-on skills.
- Cortex package name may not be what we expect; investigate before committing to install path.
