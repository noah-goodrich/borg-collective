---
Severed: 2026-05-07
Reason: Replaced by 2026-05-07-nanoprobe-orchestrator.md after architectural review
        found Claude Code's native subagent infrastructure subsumes 60-70% of the
        proposed custom code.
Review: docs/plans/reviews/2026-05-07-agentic-orchestrator-review.md
---

# Directive: Agentic Orchestrator — Spawn-Monitor-Synthesize Pattern

*Created: 2026-05-03*

## What "Agentic" Means Here

"Agentic" in the AI engineering sense means: a system that can autonomously break a goal into
sub-tasks, delegate each to a capable executor, observe results, and adjust course — without a
human in the loop for every step.

For borg, this specifically means:

**Claude-as-orchestrator should NEVER execute project tasks inline.** Its job is:
1. **Spawn** — decompose work into scoped background agents with well-briefed prompts
2. **Monitor** — track what's running, what's blocked, what completed
3. **Synthesize** — report results back to the user as a coherent picture

This is distinct from what borg currently does, which is: open a Claude session in a project
directory and let Claude do everything interactively in that session. That's a single-threaded
assistant, not an orchestrator.

## Where Borg Currently Hits and Misses

### Hits (already working)
- `drone claude <project>` — launches Claude in a dedicated project window (delegation)
- `borg next` — prioritization without execution
- `borg hail` / `borg link` — status aggregation across projects
- Hooks (link-down/up) — inject context at session boundaries without Claude deciding when

### Misses (the gaps this directive addresses)

1. **No agent lifecycle tracking.** When a background agent is spawned (via the Agent SDK tool),
   there's no persistent record of: what was spawned, when, for which project, what it produced.
   The orchestrator can't answer "what's currently running?" without relying on memory.

2. **No structured agent briefing.** Each agent spawn is ad hoc — the orchestrator composes a
   prompt from scratch each time. There's no template ensuring agents get: repo path, context
   files to read, what to NOT touch, success criteria, and build/verify command.

3. **No synthesis layer.** When agents complete, results are reported verbatim in the conversation.
   The orchestrator doesn't aggregate, summarize, or score them against the project plan.

4. **No spawn-from-CLI path.** To spawn a project agent, you have to be in the orchestrator Claude
   session. There's no `borg spawn <project> "<task>"` CLI command.

5. **Cairn is unavailable.** The knowledge graph that was supposed to carry cross-session context
   isn't in PATH on the host. So agent briefs can't pull from prior session knowledge.

## Proposed Changes

### Phase 1 — Structured Agent Briefs (low-effort, high-impact)

Create a standard agent brief template at `lib/agent-brief-template.md` that all spawned agents
receive as preamble:

```markdown
## Agent Brief
- **Project:** {project_name}
- **Repo:** {repo_path}
- **Working branch:** {branch}
- **Read first:** {context_files}
- **Task:** {task_description}
- **Do NOT touch:** {off_limits}
- **Verify with:** {build_or_test_command}
- **Completion signal:** Commit to main OR report blocker
```

The orchestrator fills this template before spawning. Makes briefs reviewable and consistent.

### Phase 2 — Agent Spawn Registry

Add a lightweight JSON log at `~/.config/borg/agents.json` tracking:

```json
{
  "agents": [
    {
      "id": "<agent_id>",
      "project": "reveal-site",
      "task": "fix logo PNG",
      "spawned_at": "2026-05-03T19:45:00Z",
      "status": "running|completed|blocked",
      "result_summary": "..."
    }
  ]
}
```

New commands:
- `borg agents` — list active/recent agents with status
- `borg agent-log <id>` — show result summary for completed agent

### Phase 3 — `borg spawn` CLI command

```
borg spawn <project> "<task description>"
```

Looks up the project in the registry, opens a Claude session (or sends to existing one) with the
standard brief pre-filled, and logs it to `agents.json`.

### Phase 4 — Cairn fix (unblocks synthesis)

Fix cairn on host (see `2026-04-02-cairn-triage.md` directive). Once cairn is in PATH:
- Agent briefs can pull `cairn search "<project> recent decisions"` for context
- Completed agents write a cairn record summarizing what they did
- Orchestrator synthesis can reference cairn rather than just checkpoint files

## Acceptance Criteria

- [ ] `lib/agent-brief-template.md` exists and is used in orchestrator session for all agent spawns
- [ ] `~/.config/borg/agents.json` tracks spawned agents with status
- [ ] `borg agents` lists active/recent agents
- [ ] `borg spawn <project> "<task>"` opens a briefed Claude session and logs it
- [ ] Orchestrator Claude session CLAUDE.md updated: "never execute project work inline"

## Scope Boundaries

- NOT building: full agent-to-agent communication (agents don't report back to borg programmatically
  in v1 — human-in-the-loop synthesis is fine for now)
- NOT building: automated CI triggering from borg spawn (out of scope)
- NOT building: multi-agent coordination within a single project (one agent per project at a time)

## Implementation Order

Phase 1 → Phase 2 → Phase 3 → Phase 4. Phases 1-2 can be done in a single session.
Phase 3 adds CLI plumbing (~1 session). Phase 4 is blocked on cairn triage decision.
