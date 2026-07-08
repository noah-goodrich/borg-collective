# Borg Orchestration Architecture (frozen spec)

Generated: 2026-07-07 · Status: STABLE — freeze these decisions so lighter models (Opus 4.8 / Sonnet) run the
harness without re-deriving the multi-agent philosophy. Routing lives in `agents/ROUTING.md`; this doc is the
other half — the handoff state-machine and the decisions that are settled. Grounded in the 2026-05-23 agent-teams
research (`docs/research/2026-05-23-agent-teams/analysis.md`, 16 source cards) and the current `agents/*.md`.

## The one-paragraph model

Borg is an **orchestrator-worker** system, NOT an inter-agent mesh. A single Conductor (the human-driven Claude
session at `BORG_ORCHESTRATOR_ROOT`) briefs, spawns, monitors, and synthesizes; specialist subagents do the work
and report back to the Conductor. Workers never talk to each other. This is the settled architecture — the
research, the AntStack 5-layer model, and the Cognition contrarian position all converge on it, and Anthropic's
experimental Agent Teams are deliberately NOT adopted at indie scale (token cost + experimental status).

## The Conductor (orchestrator)

There is no Conductor *agent file* — the Conductor is the main session whose CWD is exactly
`BORG_ORCHESTRATOR_ROOT` (default `~/dev`); `borg-hooks.sh` classifies the session by that CWD.

- **Owns:** morning briefing synthesis (registry.json + per-project `.borg/checkpoints/` + optional cairn
  context); priority scoring (`borg next`, one recommendation); work/life boundary speed-bumps; spawning +
  monitoring specialists; synthesizing lean return summaries.
- **Never does:** write `registry.json` (hook-excluded when CWD = root); **edit project files** — it briefs,
  spawns, monitors, synthesizes. Code changes go through workers in their own worktrees.
- **Is the dominant cost center** (~96% of session spend, driven by cache reads of the growing context every
  turn). The primary cost lever is keeping the Conductor context lean: delegate verbose reads to scouts, get
  distilled summaries back. (Framework-doc edits like this file are the narrow exception — they are the
  Conductor's own artifacts, not project code.)

## The handoff state-machine

```
Conductor receives a task
  │
  ├─ fully specified, no judgment?
  │     ├─ read-only search        → borg-scout      (Haiku/low,   ≤500 chars back)
  │     └─ mechanical change       → borg-grunt      (Haiku/low,   ≤300 chars back)
  │
  ├─ needs judgment, single concern?
  │     ├─ from-zero web research   → borg-researcher (Sonnet/med,  writes to a file, ≤500 back)
  │     ├─ blind adversarial review → borg-reviewer   (Sonnet/high, cold, ≤800 words)
  │     └─ implement / fix / test   → borg-nanoprobe  (Sonnet/med,  own worktree → PR, ≤500 back)
  │
  └─ genuinely open-ended, no writable brief (RARE)
        └─ claude / general-purpose (inherited session model — LAST RESORT, not a default)
```

Worker → Conductor is the only edge. There is no worker → worker edge. A worker that needs another worker's
output returns to the Conductor, which spawns the next.

## Frozen decisions (do not re-litigate without a new research pass)

1. **Orchestrator-worker only; no inter-agent messaging.** Workers report to the Conductor; they never message
   each other. Agent Teams stay off.
2. **Cost-ordered routing with explicit model tiers.** scout/grunt → Haiku; nanoprobe/researcher → Sonnet/med;
   reviewer → Sonnet/high; general-purpose → inherited (last resort). Gate conditions are fully specified in
   `ROUTING.md`.
3. **Session-model rule (post-2026-07-07).** The session default is now Opus 4.8; Fable 5 is opt-in. Inside a
   `Workflow` script, **every `agent()` call carries an explicit `model:`** — a missing one silently inherits the
   session model and is a bug. This supersedes the old "unspecified subagents run on Opus" assumption.
4. **Nanoprobe worktree protocol.** Create a worktree at `~/.local/state/borg/worktrees/<repo>/<slug>` → work
   and commit inside it → push branch + open PR → remove the worktree. Never place worktrees inside `.borg/`.
   `borg reap-worktrees` auto-cleans stale ones.
5. **Bounded termination.** Every loop/fan-out declares an explicit ceiling (e.g. `MAX_RETRIES=3`) before
   starting and hard-stops with a failure summary at the ceiling. Open-ended loops are a protocol violation.
6. **Lean-context return contracts.** grunt ≤300 chars; scout ≤500; nanoprobe/researcher ≤500; reviewer ≤800
   words. Never return raw file contents, full command output, diffs, or facts the Conductor already has.
7. **Orchestrator identity by CWD.** CWD == `BORG_ORCHESTRATOR_ROOT` ⇒ Conductor: never writes registry.json,
   never edits project files. Any other CWD is a project session.
8. **Container commands via `drone exec <project> -- <cmd>`.** Registry-by-name resolution is CWD-independent;
   relying on CWD for container routing is a protocol violation.
9. **SubagentStop → `~/.config/borg/agents.jsonl`.** One JSONL line per completion (id, agent_type,
   transcript_path, summary, status, finished_at, cwd). The worker's final message IS the logged summary, so it
   must be meaningful.
10. **Cairn-warm briefs.** When the Conductor includes a cairn knowledge block in a brief, the worker treats it
    as authoritative prior art and spot-checks rather than re-investigating — a cost lever against both sides
    re-deriving known facts.

## Open questions (NOT frozen — carry to a future decision)

- **No Conductor agent file / no unattended handoff protocol.** The Conductor is human-driven; overnight,
  past-session-limit multi-project orchestration has no defined handoff. See `[[unattended-agent-execution]]`.
- **Two divergent nanoprobe definitions.** The plugin copy (`claude-plugins/borg-collective/agents/`) has the
  scope gate + 5-read-before-write bound + `CLAUDE_CODE_MAX_OUTPUT_TOKENS:8000`; the main-repo copy lacks them,
  yet `borg setup` installs the main-repo copy to `~/.claude/agents/`. Reconcile: make the source-of-truth copy
  the one `borg setup` installs. See `[[borg-collective-source-of-truth]]`.
- **`borg-verify` skill** is in CLAUDE.md's skills table but missing from `docs/architecture.md`; its place in
  the shipping pipeline vs `/borg-assimilate` is undocumented.
- **Procedural-memory gap.** Neither cairn (episodic) nor Skills (semantic) capture "how Noah does things across
  sessions." Recommended-but-unadopted: an OpenMemory-style MCP.
- **Research-framework mapping.** The agent-teams research is GTM-scoped (4-tier delegation Tier 0–3); its
  transfer to the dev-orchestration tiers is implied but never formally mapped. `ROUTING.md` is the operational
  implementation; it does not cite the research framework.
