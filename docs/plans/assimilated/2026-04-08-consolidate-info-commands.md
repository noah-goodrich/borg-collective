# Plan: Consolidate Info Commands + Adversarial Review Skill
*Established: 2026-04-08*
*Shipped: 2026-04-08 — committed to main*

## Context

The borg-collective CLI has 5+ overlapping information commands (`ls`, `status`, `hail`, `refresh`, `briefing`) that
each show slightly different slices of the same data. None of them read from the newly organized `docs/plans/directives/`
or `docs/plans/assimilated/` directories. The user wants a single Borg-themed command that handles both overview and
deep-dive, plus an adversarial review pattern ("The Collective") formalized into borg-plan and borg-assimilate.
Additionally, `borg-stop.sh` crashes in devcontainers because `$USER` is unbound.

## Three Deliverables

### 1. `borg link` — Consolidated Information Command

**Name rationale:** "Link" = the Borg neural link connecting drones to the collective consciousness. Short (4 chars),
thematic, intuitive for both modes: "link to the collective" (overview) / "link to drone cairn" (deep dive).

**Command surface:**
- `borg link` — overview of all projects (replaces `ls`, `hail` no-arg)
- `borg link <project>` — deep dive on one project (replaces `status`, `hail <project>`)
- `borg link --brief` — LLM narrative briefing (the current `_borg_print_briefing` behavior)
- `borg link --refresh` — regenerate summaries (replaces `refresh` / `scan --llm`)
- `borg link --porcelain` — machine-readable output (preserves scripting compat)
- `drone link` — alias to `borg link <current-project>` (resolves from $PWD)

**Overview mode** (`borg link`, no arg):
1. Registry table (reuse sorted rendering from current `cmd_ls`, lines 144-238)
2. Directives badge: "N directives pending" with titles from `docs/plans/directives/*.md`
3. Recent assimilations: last 3 shipped from `docs/plans/assimilated/*.md`
4. Capacity warning (existing)
5. If `--brief`: append LLM narrative from `_borg_print_briefing()`

**Deep-dive mode** (`borg link <project>`):
1. Registry entry (reuse from current `cmd_status`, lines 254-276)
2. PROJECT_PLAN.md: if exists at project path, show objective + criteria checklist
3. Last debrief: first ~20 lines of `$BORG_DIR/debriefs/<project>.md`
4. Directives mentioning this project (grep project name in directive files)
5. Recent assimilations for this project
6. Cairn knowledge (existing pattern, 5s timeout)

**Legacy aliases** in dispatch table: `ls`, `status`, `hail`, `brief`, `briefing`, `refresh` all route to `cmd_link`.

**Kill old skills:** Delete `skills/borg-ls/`, `skills/borg-status/`, `skills/borg-hail/`, `skills/borg-refresh/`.
Create single `skills/borg-link/SKILL.md`.

**Update `cmd_next()`** (line 629): After computing top project, show relevant directives count + titles.

### 2. The Collective — Adversarial Review Skill

**New skill:** `skills/borg-collective-review/SKILL.md`

**Core Cast (always present, 6 voices):**
- **The Scope Hawk** (80/20 enforcer) — cuts scope, focuses on max value / min effort
- **The Craftsperson** (quality/testing) — no half-assing, test-driven, no silent failures
- **The Performance Engineer** — efficiency, unnecessary work, resource waste
- **The Readability Advocate** — understandable by non-brilliant engineers tomorrow
- **The User Advocate** (UX/dogfooding) — "will someone actually enjoy using this?"
- **The Adult** (mediator) — applies 80/20 to the review itself, makes the final call

**Rotating Specialist (1 per session, chosen by context):**
- **The Security Auditor** — selected when touching auth, APIs, secrets, user data
- **The Ops Engineer** — selected when touching CI/CD, deployment, infrastructure
- **The Devil's Advocate** — default if no specialist fits; questions fundamental premises
- **The Historian** — selected for refactors, rewrites, "v2" work; "we tried this before..."

The skill instructs Claude to pick the most relevant specialist based on what's being reviewed. If none fits strongly,
The Devil's Advocate gets the seat (the anti-echo-chamber default).

**Format:** Each core persona speaks 2-4 sentences, the rotating specialist speaks 2-4 sentences, and The Adult
synthesizes all perspectives into 2-3 actionable items. Total: 20-30 lines.

**Integration:**
- `skills/borg-plan/SKILL.md` — add step between "Before You Start" and "The Conversation": run Collective review on
  codebase before proposing objectives
- `skills/borg-assimilate/SKILL.md` — add step between criterion evaluation and ship decision: run Collective review on
  deliverable before shipping
- `skills/borg-review/SKILL.md` — optional: invoke Collective when diagnostic reveals significant concerns

### 3. $USER Fix in borg-stop.sh

**Problem:** Line 18 uses `$USER` for macOS Keychain lookup, but `set -u` (nounset) causes "unbound variable" crash in
devcontainers where `$USER` isn't set and `security` (macOS Keychain CLI) doesn't exist.

**Fix:** Guard the Keychain block — only attempt it when `security` command exists (macOS only). Replace line 17-19:

```bash
BORG_DEBRIEF_KEY="${ANTHROPIC_API_KEY:-${ANTHROPIC_SDK_KEY:-}}"
if [[ -z "$BORG_DEBRIEF_KEY" ]] && command -v security >/dev/null 2>&1; then
    BORG_DEBRIEF_KEY=$(security find-generic-password -a "${USER:-unknown}" -s "ANTHROPIC_SDK_KEY" -w 2>/dev/null || true)
fi
```

Two-layer defense: (1) skip if `security` not available (Linux/containers), (2) default `$USER` to prevent unbound even
on macOS edge cases.

## Files to Modify

| File | Changes |
|------|---------|
| `borg.zsh` | New `cmd_link()`, `_borg_link_overview()`, `_borg_link_deep()`, `_borg_read_directives()`, `_borg_read_assimilated()`. Update `cmd_next()`. Update dispatch table. Update `cmd_help()`. |
| `drone.zsh` | Add `link)` to dispatch table — resolves current project, calls `borg link <project>`. |
| `hooks/borg-stop.sh` | Guard `$USER` / `security` on line 17-19. |
| `skills/borg-assimilate/SKILL.md` | Fix archive path (`docs/plans/` → `docs/plans/assimilated/`). Add Collective review step. |
| `skills/borg-plan/SKILL.md` | Add Collective review step before proposing objectives. |
| `skills/borg-review/SKILL.md` | Optional Collective integration for significant concerns. |
| `skills/borg-collective-review/SKILL.md` | **New file** — The Collective personas and discussion format. |
| `skills/borg-link/SKILL.md` | **New file** — consolidated info skill. |
| `skills/borg-ls/` | **Delete** |
| `skills/borg-status/` | **Delete** |
| `skills/borg-hail/` | **Delete** |
| `skills/borg-refresh/` | **Delete** |

## Implementation Order

1. Fix `$USER` in `hooks/borg-stop.sh` (one-liner, unblocks container sessions)
2. Add helpers: `_borg_read_directives()`, `_borg_read_assimilated()` in `borg.zsh`
3. Build `cmd_link()` with `_borg_link_overview()` and `_borg_link_deep()`
4. Update dispatch table in `borg.zsh` (add `link`, alias old commands)
5. Update `cmd_next()` to show directives
6. Add `link` dispatch in `drone.zsh`
7. Update `cmd_help()` in `borg.zsh`
8. Fix archive path in `skills/borg-assimilate/SKILL.md`
9. Create `skills/borg-collective-review/SKILL.md`
10. Create `skills/borg-link/SKILL.md`
11. Update `skills/borg-plan/SKILL.md` with Collective integration
12. Update `skills/borg-assimilate/SKILL.md` with Collective integration
13. Update `skills/borg-review/SKILL.md` with optional Collective integration
14. Delete old skills: `borg-ls`, `borg-status`, `borg-hail`, `borg-refresh`
15. Run `borg setup` to deploy

## Verification

1. `borg link` — shows project table + directives count + recent assimilations
2. `borg link borg-collective` — shows deep dive with registry, debrief, directives, assimilated
3. `borg link --brief` — shows LLM narrative briefing
4. `borg link --refresh` — regenerates summaries
5. `borg ls` / `borg status` / `borg hail` — all route to `cmd_link` (backward compat)
6. `drone link` — resolves current project, shows deep dive
7. `borg next` — shows directives relevant to recommended project
8. Stop a devcontainer session (snowfort) — no `$USER` crash
9. Run existing bats tests: `bash -c 'cd /Users/noah/dev/borg-collective && bats tests/'`

## Scope Boundaries

- NOT changing: `borg scan` discovery logic (just absorbing its `--llm` refresh into `link --refresh`)
- NOT changing: `borg init` / `borg claude` / `borg switch` / `borg search`
- NOT building: project-specific directive association via frontmatter (use grep for now)
- NOT caching: directives/assimilated reads are fast filesystem scans, no caching needed
- If done early: ship, don't expand.

## Risks

- `_borg_print_briefing()` is ~140 lines and tightly coupled to `cmd_hail` — extracting it cleanly requires care
- Old skills deletion could break sessions that have them cached — `borg setup` must run to clean up
- The Collective review adds ~15-25 lines to every plan/assimilate invocation — acceptable overhead but worth noting
