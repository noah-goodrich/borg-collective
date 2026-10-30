# The Borg Collective — Repository Handoff

## What This Is

AI development orchestration framework. Two CLIs — `borg` (orchestration) and `drone` (repository
lifecycle) — that coordinate parallel Claude Code sessions across repositories and containers.
Cross-session knowledge persists via user-authored checkpoints (`.borg/checkpoints/`) and Claude
Code's own project-memory system — see "Cairn decommission" in docs/agents/learned.md for why a separate
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
- Before editing `borg.zsh`, `drone.zsh`, anything under `lib/` or `bin/`, or window-name code, read `docs/agents/cli-rules.md` and `docs/agents/learned.md`.
- Before naming anything repository or project in code (`borg_core/`, `lib/`, `hooks/`, `bin/`), help text or messages, read the Vocabulary rule in `docs/agents/cli-rules.md`.
- Before editing `_borg_print_briefing` or `borg link --brief`, read `docs/agents/link-brief.md`.
- Before spawning or editing a nanoprobe, or fanning out agents, read `docs/agents/nanoprobes.md`.
- To look up a command or flag, read `docs/agents/commands.md`; to find a file, read `docs/agents/files.md`.
- For what is shipped and the current release, read `docs/agents/implemented.md`.
- For history moved out of this file, read `docs/agents/learned.md`, heading 'Moved from CLAUDE.md 2026-10-30'.

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| claude | `claude` | LLM debriefs (Sonnet), the Queen session |
| cortex | `cortex` | Cortex Code CLI (CoCo) — optional, detected at install |

## Architecture Rules

- Logic goes in a testable core. Shell is a wrapper. New modules ship with tests in the same commit.
- Prior decisions live in `.borg/checkpoints/` and `docs/plans/assimilated/`: grep them before assuming something is undocumented. `.borg/knowledge/` is a decommissioned export that nothing reads.
- **Schema evolution is ALWAYS expand → migrate → contract, everywhere, no exceptions.** Add the new form and accept both; migrate every existing instance; only then remove the old form or tighten the validator. Never the other order.
- **Migrate only what the SURVIVING validator rejects.** An artifact that fails only the validator being deleted needs no migration; the contraction resolves it.
- **Direction matters:** expand→migrate→contract governs data the new rules reject, not data the old ones did.

## Style Rules

- Code and code comments wrap at 120 (ruff/pylint enforce it for Python). Markdown and text prose is NOT hard-wrapped: one line per paragraph or bullet. Existing wrapped paragraphs keep their wrap when edited. Never wrap tables, fenced code or URLs. Commit bodies wrap at 72. PR bodies, PR/issue/review comments, any `gh` body, release notes, chat replies and pandoc/epub input are never hard-wrapped. Markdown files read in a terminal or editor keep every table row and every fenced-block line (mocks, code, diagrams) within 72 columns: table cells are a few words, longer text goes in bullets below the table, and a table that needs more width becomes a list. GitHub-rendered text (PR bodies, comments) is exempt because GitHub wraps table cells.
- 4-space indentation (except YAML/Lua: 2-space)
- zsh functions over aliases for anything > 1 line
- No `$()` substitution in Bash tool calls
- No inline `#` comments in one-liner bash commands
- No temp scripts

