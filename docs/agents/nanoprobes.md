# Nanoprobes, drones and bounded termination

Rules moved verbatim from the top-level CLAUDE.md.

- **Nanoprobe orchestrator (drones vs nanoprobes)**: drones are persistent devcontainers (long-lived,
  one per repository); nanoprobes are ephemeral Claude Code subagents (`agents/borg-nanoprobe.md`)
  spawned by the orchestrator via the Agent tool with subagent_type `borg-collective:borg-nanoprobe` (do not pass model, effort or background; the agent frontmatter sets them) (no harness worktree
  isolation — `isolation: worktree` caused hard failures when the orchestrator CWD is not a git
  repo). **Nanoprobes manage their own git worktrees** when the orchestrator supplies a branch name:
  `git -C <repo_path> worktree add ~/.local/state/borg/worktrees/<repo>/<slug> -b <branch>`.
  All work and commits happen inside the worktree; on completion the nanoprobe removes it so the
  repo stays clean. `borg reap-worktrees` auto-cleans stale borg worktrees (merged branch or older
  than `BORG_REAP_STALE_HOURS`). Worktrees live under `~/.local/state/borg/worktrees/` (NOT inside
  `.borg/`, which is reserved for user checkpoints).
  The Queen session never edits repository files — it briefs, spawns, monitors, and synthesizes.
  Lifecycle is logged by `hooks/borg-nanoprobe-log.sh` (a `SubagentStop` hook) which appends one
  JSONL line per completion to `~/.config/borg/agents.jsonl` (`id`, `agent_type`, `transcript_path`,
  `summary` from `last_assistant_message`, hard-coded `status: "completed"`, `finished_at`, `cwd`).
  Claude Code internal agents (empty `agent_type`) are skipped by the `".+"` matcher and an in-hook guard.
  Inspect runs with `borg nanoprobes` (alias `np`) and pull transcripts with
  `borg nanoprobe-log <id-prefix>`. Claude Code loads the agent from the borg-collective plugin as
  `borg-collective:borg-nanoprobe`; `borg setup` removes the legacy `~/.claude/agents/` copies. For Cortex
  Code, `borg setup` installs every `agents/*.md` into `~/.snowflake/cortex/agents/` with its name rewritten to
  the same `borg-collective:borg-nanoprobe` (Cortex registers an agent under its exact `name:` and has no plugin
  namespace), so one name works in both CLIs. Cortex needs one-line `description:` values and full `model:` ids;
  `tests/agent_frontmatter.bats` pins both. Cortex ignores `effort:`: its subagents run at the session's effort
  (docs/agent-routing.md, "Cortex Code").
- **A PR adds its own stack row**: when a brief names a stack manifest (a file under `.stacks/`), the PR adds its own row in the same PR with `python3 -m borg_core.manifest.cli add-row` (`--name`, `--ref`, `--why`, `--status`), because `/borg-link-up` cannot do it for a nanoprobe: it needs a plan slug and a PR on the current branch, and nanoprobe worktrees never run it. A stack whose PRs skip this stays at zero rows and `borg link` shows nothing for the directive. The orchestrator adds the manifest name to every brief.
- **Bounded termination (agent loops)**: when fanning out nanoprobes or running any retry/until
  loop, set an explicit ceiling (max spawns / max iterations) up front and stop when hit. Never
  rely on judgment to exit loops — explicit stopping conditions only (e.g., `MAX_RETRIES=3`
  declared before the loop; hard-stop with a failure summary when reached).
