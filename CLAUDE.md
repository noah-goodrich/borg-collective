# The Borg Collective — Repository Handoff

## What This Is

AI development orchestration framework. Two CLIs — `borg` (orchestration) and `drone` (repository
lifecycle) — that coordinate parallel Claude Code sessions across repositories and containers.
Cross-session knowledge persists via user-authored checkpoints (`.borg/checkpoints/`) and Claude
Code's own project-memory system — see "Cairn decommission" under Learned for why a separate
knowledge-graph service was retired.

## Architecture

```
borg (orchestrator)     drone (repository lifecycle)
  - Morning briefing      - Container up/down
  - Priority scoring      - tmux window management
  - Work/life boundaries  - Claude session launching
  - Checkpoint briefing   - 3-pane dev layout
```

Two independent tools that compose:
- **borg** — Session coordination, recommendations, boundaries. Runs on host.
- **drone** — Container lifecycle, tmux windows, pane layouts. Forked from dev.sh. Runs on host.

## Index: where the rest of this file went

Nested CLAUDE.md files load when you read a file in their directory. The `docs/agents/` files load only if you Read them, so the lines below say when.

- `hooks/CLAUDE.md`: hook language rule, Queen vs repository sessions, log retention, plan promotion, hook test-isolation lessons.
- Before editing `launchd/` or `install.sh`, read `docs/agents/launchd.md`: launchd labels and extension agents.
- `borg_core/link/CLAUDE.md`: the `borg link` renderer, picture purity and width, checkpoint union reads, parity harness.
- `borg_core/registry/CLAUDE.md`: a worktree is a view of a repo (the `repo` key).
- `borg_core/manifest/CLAUDE.md`: manifest roots.
- `borg_core/recon/CLAUDE.md`: recon fan-out and adapters.
- `borg_core/extensions/CLAUDE.md`: local extensions, the shim layer, `prefer-tool`.
- `borg_core/compass/CLAUDE.md`: the compass reader.
- `tests/CLAUDE.md`: test-environment lessons (git identity, platform premises).
- Before editing `borg.zsh` or `drone.zsh`, read `docs/agents/cli-rules.md` and `docs/agents/learned.md`.
- Before editing `_borg_print_briefing` or `borg link --brief`, read `docs/agents/link-brief.md`.
- Before spawning or editing a nanoprobe, or fanning out agents, read `docs/agents/nanoprobes.md`.
- To look up a command or flag, read `docs/agents/commands.md`; to find a file, read `docs/agents/files.md`.
- For what is shipped and the current release, read `docs/agents/implemented.md`.

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| claude | `claude` | LLM debriefs (Sonnet), the Queen session |
| cortex | `cortex` | Cortex Code CLI (CoCo) — optional, detected at install |

## Architecture Rules

- Logic goes in a testable core. Shell is a wrapper. New modules ship with tests in the same commit.
- Prior decisions live in `.borg/checkpoints/` and `docs/plans/assimilated/` — grep them before
  assuming something is undocumented. **`.borg/knowledge/` was removed from this list 2026-09-28 and
  its 1106 tracked files were NOT deleted.** It is the decommissioned cairn service's export (see
  the dotfiles `.gitignore`, which says so outright), and no code path has ever read it — so naming
  it here was a promise to every agent that nothing kept. Retiring a store means deleting the
  PROMISE, not the data: the files stay, greppable by anyone who wants them, and the reader census
  (`docs/state-census.md`) now stops caring about them because nothing claims anything about them.
  The full argument is in `docs/plans/directives/assets/2026-09-28-state-audit-adversarial.md`.
- **Schema evolution is ALWAYS expand → migrate → contract, everywhere, no exceptions.** Add the new
  form and accept both; migrate every existing instance; only then remove the old form or tighten the
  validator. Never the other order. Done this way a schema change cannot produce a regression,
  because no artifact is ever read by rules it was not written to satisfy — which is the whole reason
  it is a rule and not a preference. The tell that it was skipped: existing, untouched data suddenly
  failing validation with no write in between. When that happens the temptation is to weaken the
  validator, and weakening it is how two validators come to disagree in the first place (AC7 exists
  to end exactly that). "Additive first" is also why a port lands as a NEW path before any caller is
  repointed: `borg_core/manifest/shell.write_manifest` shipped 2026-09-01 accepting the strict
  validator while `coordinator.py` and `gather.py` still used the old one — that commit was the
  expand phase, and repointing them is the contract phase, which may not happen until the **57**
  shorthand ref occurrences in `merge-tree/test_coordinator.py` have been migrated to satisfy the
  stricter rules (that sequence has since run to the end: fixtures migrated, `coordinator.py` repointed,
  `merge-tree/programs.py` deleted, 2026-10-12). **Migrate only what the SURVIVING validator rejects.** An artifact that fails only
  the validator being deleted needs no migration at all — it is resolved by the contraction. The
  first draft of this rule listed `warehouse-rollout.json`'s `kind: "review"` as a prerequisite; it
  is clean under `core.validate` and fails only merge-tree's `GATE_KINDS` closure, which borg_core
  removed on purpose. "Migrating" it would have meant rewriting data BACKWARD to satisfy a dying
  rule, and five oracles pin that literal string. Direction matters: expand→migrate→contract governs
  data the new rules reject, not data the old ones did.

## Style Rules

- Code and code comments wrap at 120 (ruff/pylint enforce it for Python). Markdown and text prose is NOT hard-wrapped: one line per paragraph or bullet. Existing wrapped paragraphs keep their wrap when edited. Never wrap tables, fenced code or URLs. Commit bodies wrap at 72. PR bodies, PR/issue/review comments, any `gh` body, release notes, chat replies and pandoc/epub input are never hard-wrapped. Markdown files read in a terminal or editor keep every table row and every fenced-block line (mocks, code, diagrams) within 72 columns: table cells are a few words, longer text goes in bullets below the table, and a table that needs more width becomes a list. GitHub-rendered text (PR bodies, comments) is exempt because GitHub wraps table cells.
- 4-space indentation (except YAML/Lua: 2-space)
- zsh functions over aliases for anything > 1 line
- No `$()` substitution in Bash tool calls
- No inline `#` comments in one-liner bash commands
- No temp scripts

