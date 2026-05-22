# Borg Next-Level Research Brief

**Date**: 2026-05-22
**Methodology**: Deep research pipeline (CREDIBLE + PRISMA-style pre-registration). 17 sources
evaluated across 5 categories: practitioner posts, official docs, academic papers, competitive
READMEs/blogs, and aggregate telemetry research. All sources 2025–2026. Quantitative claims
spot-checked against primary sources — one notable discrepancy: Ruflo's claimed "84.8%
SWE-bench" does not appear in the actual GitHub README; adoption metrics are present but not
independently verified.

---

## Section 1: Competitive Landscape Snapshot

The field has stratified into three tiers. Borg sits in a unique position across all of them.

### Tier 1 — Single-Project Claude Code Frameworks (direct ecosystem competitors)

These are all "make one Claude Code session better for one project." None do cross-project
coordination.

| Framework | Orchestration Model | Context Strategy | Memory | Standout | Gap vs. Borg |
|-----------|--------------------|--------------------|--------|----------|-------------|
| **gstack** (Garry Tan/YC, 50k stars in 16 days) | "23-person team": 9 role modes + Conductor (up to 10 parallel sessions) | Role-scoped windows — each specialist sees only what's relevant | None | Role specialization | No cross-project, no lifecycle hooks, no knowledge graph |
| **Superpowers** | Single centralized brain, 7-stage TDD pipeline (brainstorm→spec→plan→tests→impl→review→finalize) | One large context managed centrally until full | Session memory patterns | TDD discipline enforced structurally | No multi-project, no cairn-style persistence |
| **GSD** | Per-phase orchestrators, state handoff via Markdown/XML | Fresh orchestrator picks up from disk state ("context rot" prevention) | Disk-only | Marathon sessions; context never degrades | Single project, no hooks ecosystem |
| **Hermes Agent** | Autonomous orchestration, task decomposition, multi-agent with human-in-the-loop checkpoints | Planning + persistent memory across steps | Persistent cross-step | Most autonomous; retry logic + escalation | Single project; steep setup; debugging hard |
| **Ruflo** | Queen-led swarm hierarchy, 27 hooks, 100+ agents | HNSW vector DB (AgentDB), cross-session RVF persistence | Yes (vector) | Cross-session memory architecture | Single project; claimed metrics unverified; complex |

**Borg's unique position**: Every one of these operates within a single project. Borg is the only
framework that does cross-project registry, context switching, morning briefing across projects,
and multi-project nanoprobe orchestration. This is genuinely uncontested territory.

### Tier 2 — Autonomous Coding Agents (different threat model)

Devin (67% PR merge rate, $20/month + $2.25/ACU), OpenHands (open source, $18.8M Series A,
adopted by Apple/Google/Amazon), SWE-agent (Princeton) — these own a single task end-to-end in
a sandboxed environment. Not direct competition. Borg's nanoprobe pattern is the closest analog,
running inside your dev environment rather than in the cloud.

### Tier 3 — General Multi-Agent Frameworks

LangGraph (stateful, controllable graphs), CrewAI (role-based, rapid prototyping, added Flows
for production in 2025), AutoGen/AG2 (event-driven GroupChat, v0.4 rewrite). These are
infrastructure, not developer workflow tools. No one is combining these with a Claude Code
session lifecycle manager — that's an open integration surface.

### Native Claude Code: Agent Teams (v2.1.32+)

This is the most important competitive signal. Anthropic shipped a native multi-agent
coordination layer that borg doesn't integrate with yet:

- **TeammateIdle hook**: fires when a teammate is about to go idle — exit 2 to keep working
- **TaskCreated / TaskCompleted hooks**: gate task lifecycle
- **Shared task list** with file-locked claiming (prevents race conditions)
- **Mailbox**: direct inter-agent messaging
- **Subagent definitions as teammates**: `borg-nanoprobe.md` can be spawned as a teammate type

Currently experimental; tmux split-pane mode doesn't support Ghostty. Borg needs a strategy for
how it relates to Agent Teams before this graduates from experimental.

---

## Section 2: SME Signal Synthesis

**Simon Willison** describes "parallel agent psychosis" verbatim: "no dashboard or status board,
just spatial memory of which terminal window had which session." This is the exact problem borg
solves — Willison articulates it, borg fixes it. His Agentic Engineering Patterns piece also
surfaces: (1) TDD as the reliability floor for AI code, (2) prompt caching as the cost lever
for long-running systems, and (3) scheduled execution as an unmet need (Claude Code can't
trigger itself).

**Addy Osmani** frames the manager layer problem as five failures: merge conflicts from
uncoordinated parallel agents, ambiguity killing output quality, review becoming the bottleneck,
over-delegation of human decisions, and context overload from too many streams. His prescription:
structured task briefs with acceptance criteria, WIP limits, two-agent review workflows, and
`AGENTS.md` as the team charter. Borg has WIP limits and PROJECT_PLAN.md — closer than most,
but the two-agent review and structured brief-per-task are missing.

**Faros AI's 22,000-developer study** is the most important empirical data:

- Individual throughput: 98% more PRs merged, 154% larger PR size
- But: 91% longer review time, 9% more bugs, context switching increased 47%
- Organizational DORA metrics: flat — the gains evaporate at team level

The implication for borg: you're currently optimizing nanoprobe output speed. The actual
bottleneck is review throughput and bug rate. Every nanoprobe that ships code without a quality
gate makes the 9% bug increase worse. The highest-leverage borg addition is not more parallel
agents — it's better quality gates on existing agents.

**swyx's IMPACT model** (Intent, Models-with-tools, Planning, Authority, Control-flow, Memory)
maps onto borg cleanly:

- Intent ✅ (PROJECT_PLAN.md, acceptance criteria)
- Models-with-tools ✅ (nanoprobes have bash/read/edit/write)
- Planning ✅ (borg-plan, ExitPlanMode promotion)
- Authority ✅ (bash-guard, break-glass, permission model)
- Control-flow ✅ (orchestrator → nanoprobe delegation)
- Memory ⚠️ (cairn exists but is optional and manual — the weakest leg)

**blakecrosley's harness guide** provides the most technically concrete benchmark. A 47-story
production study shows false completion rate drops from 35% to 4% with a full harness (hooks +
quality gates + multi-agent review). The key pattern borg doesn't yet implement: the **evidence
gate** — completion requires cited evidence (file paths, test output), not "I believe it works."

**agor.live's progression model** places the field at seven stages. Borg is at Stage 5
(Multi-Agent Tooling) with partial Stage 6 (Agent Orchestration). Stage 7 (Meta-Orchestration:
supervisor agents managing agents via schedules, trigger chains, resource containment) is the
near-term horizon for the whole field.

---

## Section 3: Gap Analysis

Ranked by estimated impact on development velocity, not by implementation effort.

### Gap 1 — Memory is manual and leaky (CRITICAL)

Cairn exists but requires `/borg-link-up` to write a checkpoint and is described as "optional."
Sessions that end abruptly, get compacted, or run via nanoprobe contribute nothing to the
knowledge graph. Mem0.ai's context engineering research shows adaptive cross-session memory is
the single biggest differentiator between tools that compound value over time and those that
restart cold every session.

Every session currently ends with knowledge evaporating unless the user manually invokes
`/borg-link-up`. That's a discipline requirement — and discipline requirements fail under ADHD
constraints and time pressure.

**What's missing**: automatic cairn write at SessionStop, with structured extraction (decisions
made, patterns discovered, gotchas encountered) rather than a raw checkpoint dump.

### Gap 2 — No real-time visibility into in-flight nanoprobes (HIGH)

`borg ls` shows project status. `borg nanoprobes` shows *completed* runs. Neither shows what's
happening right now. Willison explicitly named this as the central UX failure of parallel agent
workflows: "spatial memory of which terminal window" is not a system.

With 3 nanoprobes running in parallel, there's currently no way to see: what tool they're on,
how many tool calls they've made, whether they hit an error, or estimated time to done — without
switching tmux windows manually.

**What's missing**: `borg watch` — a live TUI showing in-flight agent status. The data exists
in the worktree and JSONL logs; it's a display problem.

### Gap 3 — Quality gates are nudges, not gates (HIGH)

`pre-commit-remind.sh` asks if you ran `/simplify`. `tool-count-nudge.sh` suggests `/borg-review`
after 75 calls. Both are advisory.

The blakecrosley study shows false completion rate drops from 35% to 4% when quality gates are
enforced rather than suggested. Nanoprobes are the highest-risk surface — they run autonomously
and their output lands in a PR. A nanoprobe that claims "done" without test output or file
citations is the failure mode behind Faros's 9% bug increase.

**What's missing**: A validation gate in the SubagentStop hook. Before a nanoprobe's worktree
is considered complete: bats must pass, shellcheck must be clean, specific evidence must be
cited. The borg-assimilate skill does this manually — it needs a machine-enforced equivalent
at the nanoprobe boundary.

### Gap 4 — Agent Teams are ignored (MEDIUM-HIGH)

Claude Code v2.1.32 ships native agent coordination with `TeammateIdle`, `TaskCreated`, and
`TaskCompleted` hooks, a shared task list with file-locked claiming, and direct inter-agent
messaging. Borg's nanoprobe pattern predates this — nanoprobes only report results back to the
orchestrator (no inter-agent communication).

Agent Teams could replace or extend nanoprobes for intra-project parallel work, with borg
staying as the cross-project coordinator. The `borg-nanoprobe.md` agent definition already
exists in the format Agent Teams can consume as a teammate type.

**What's missing**: A borg strategy for Agent Teams, and registration of TeammateIdle /
TaskCreated / TaskCompleted hooks in `borg setup`.

### Gap 5 — No tiered model strategy (MEDIUM)

gstack's Conductor and wshobson/agents both use tiered model selection: Opus for
architecture/security decisions, Sonnet for implementation, Haiku for fast checks. Borg uses
the same model for everything — a borg-plan run and a shellcheck-validation nanoprobe both
consume the same tokens at the same cost.

Current pricing: Opus at 5× Sonnet cost. A borg-collective-review session that runs on Opus is
appropriate. A bats-runner nanoprobe that executes tests and reports pass/fail does not need
Opus.

**What's missing**: Model selection in nanoprobe spawn based on task type, using the `model`
parameter already supported by the Agent tool.

### Gap 6 — Spec-driven development is partial (MEDIUM)

The field has converged on a 4-phase gated pipeline: Specify → Plan → Tasks → Implement. Borg
has Plan (borg-plan + ExitPlanMode promotion) and partially Implement (nanoprobes). But Specify
is missing — there's no `borg-spec` that produces a machine-readable brief with acceptance
criteria that flows into borg-plan and then into nanoprobe task decomposition.

`PROJECT_PLAN.md` gets close, but it's the output of borg-plan, not the input to it. The spec
should exist before planning, and planning should be grounded in the spec.

**What's missing**: A `borg-spec` skill that interviews the user, produces a structured spec
(commands, testing, boundaries, success criteria in the Osmani format), and feeds it to borg-plan
as the source of truth.

### Gap 7 — Cross-project telemetry doesn't exist (LOWER)

Faros AI tracks: PR size trends, bug rate per developer, review time. Borg tracks: project
status (active/idle), uncommitted changes, checkpoints. No longitudinal data.

Over a month of borg usage, the data exists to answer: which projects have the longest
nanoprobe-to-merge cycles? Which skills are invoked most? Where does the tool-count-nudge most
often fire? This is latent in `agents.jsonl`, the registry, and session JSONL files — it's a
query problem, not a data problem.

**What's missing**: `borg stats [project|--all]` — aggregates from agents.jsonl + registry +
checkpoint timestamps.

---

## Section 4: Recommendations

Ordered by impact-to-effort ratio.

### Rec 1: Auto-write cairn at SessionStop

**What**: Modify `borg-link-up.sh` (the Stop hook) to always call cairn, not wait for
`/borg-link-up`. Extract three structured fields automatically: (1) what changed (from `git diff
--stat`), (2) any open blockers (from the last assistant message in the session JSONL), (3) next
recommended action. Write these to cairn as a session record regardless of whether a checkpoint
was manually written.

**Why it wins**: Closes the biggest gap with Ruflo/Hermes without requiring any user behavior
change. The data is already available at session stop — git diff, session JSONL, registry. Zero
new disciplines required.

**Implementation path**: `borg-link-up.sh` already reads session JSONL for the uncommitted-changes
warning. Extend to extract last 2-3 assistant turns and call `cairn write` with structured JSON.
If cairn is unavailable, fall through silently (it's already optional).

### Rec 2: `borg watch` — live in-flight visibility

**What**: A new `borg watch` command that refreshes every 5 seconds and shows: project name,
status, current session's tool call count, last tool used, time elapsed. For nanoprobes: worktree
path, spawned-at time, last activity from the worktree's git log.

**Why it wins**: Directly addresses the Willison "spatial memory" problem. The data is already
there — `borg nanoprobe-log` reads agents.jsonl, and tool-count-nudge.sh already writes per-session
counters to `/tmp`. `borg watch` is a display layer over existing data.

**Implementation path**: Add `cmd_watch` to `borg.zsh`. For nanoprobe in-flight status: check
`WORKTREE_PATH/.git/logs/HEAD` modification time as a "last activity" proxy. Interim: `watch -n5
borg ls`.

### Rec 3: Nanoprobe evidence gate (SubagentStop hook upgrade)

**What**: Upgrade `hooks/borg-nanoprobe-log.sh` from a logging hook to a validation hook. On
SubagentStop, before writing the completion record to `agents.jsonl`: (1) check if the worktree
has a clean bats run, (2) check if the last assistant message contains file path citations, (3)
check `git diff --stat` in the worktree has actual changes if the task was implementation. If any
check fails, inject `additionalContext` asking the nanoprobe to provide evidence.

**Why it wins**: Directly attacks the 9% bug increase (Faros) and the 35% false completion rate
(blakecrosley). Low effort — the hook already fires at the right moment.

**Implementation path**: SubagentStop hook receives `last_assistant_message` in its input JSON.
Parse for citation patterns (file paths matching `[a-zA-Z0-9_/-]+\.[a-z]+:\d+`). If none found
and task type is "implement", emit `additionalContext` requesting evidence. Always exits 0 (pushes
back once, never blocks permanently).

### Rec 4: Agent Teams hooks registration in `borg setup`

**What**: Add three new hook registrations to `install.sh` / `borg setup`:

- `TeammateIdle` → `hooks/teammate-idle.sh`: log to agents.jsonl, notify via borg-notify pattern
- `TaskCreated` → `hooks/task-quality-gate.sh`: validate task has acceptance criteria before
  creation (exit 2 if description < 20 words or has no success criteria)
- `TaskCompleted` → existing evidence gate pattern

Also add a `--teammate-mode tmux` suggestion to the borg setup output (already in tmux, split
panes work).

**Why it wins**: Makes borg the coordination layer for Agent Teams instead of being bypassed by
them. Borg's registry becomes the source of truth for both nanoprobe and teammate activity.

### Rec 5: Tiered model in nanoprobe dispatch

**What**: Add model inference to the orchestrator's nanoprobe spawn pattern based on task type:

- Planning/architecture tasks → `opus`
- Implementation tasks → `sonnet` (default)
- Validation/check tasks (bats runner, shellcheck reviewer) → `haiku`

**Why it wins**: 5× cost reduction on validation tasks. The `model` parameter is already
supported by the Agent tool.

**Implementation path**: Update `agents/borg-nanoprobe.md` to document the model selection
pattern. Add to orchestrator-mode CLAUDE.md: "When spawning a validation nanoprobe (bats,
shellcheck, link-check), use `model: haiku`."

### Rec 6: `borg-spec` skill

**What**: A new skill that produces a machine-readable spec before planning begins. Prompts:
(1) What is the goal in one sentence? (2) What commands verify it's done? (3) What are the hard
constraints? (4) What must never happen? Outputs a `SPEC.md` in the Osmani/GitHub Spec Kit format
(Commands, Testing, Boundaries, Success Criteria). `borg-plan` then reads `SPEC.md` as its
primary input.

**Why it wins**: Research analyzing 2,500+ agent configurations shows "most agent files fail
because they're too vague." Spec-first development directly attacks that root cause.

**Implementation path**: New `skills/borg-spec/SKILL.md`. Four-question interview, templated
output. Add to `borg-plan` SKILL.md: "If `SPEC.md` exists in the project root, read it before
proposing objectives."

---

## Section 5: Where Borg Already Leads

To calibrate: borg is ahead of the field on several dimensions that competitors haven't solved.

- **Cross-project orchestration**: genuinely uncontested. No other framework has a registry +
  morning briefing + cross-project nanoprobe pattern.
- **Security model**: bash-guard's 3-layer architecture (hard-block, container-aware install
  approval, RO intent classifier) is more sophisticated than anything in any competing framework.
- **Cognitive load design**: adhd-guardrails, work/life boundary enforcement, capacity warnings —
  no competitor touches this dimension.
- **Lifecycle hook completeness**: SessionStart + Stop + Notification + SubagentStop + PreToolUse
  + PostToolUse coverage is broader than gstack, Superpowers, GSD, or Hermes combined.
- **Checkpoint/handover system**: the SessionStart context injection from latest checkpoint is the
  most sophisticated session continuity pattern in the field. Ruflo claims RVF persistence but
  it's opaque; borg's is file-based and inspectable.

The gap is not breadth — it's depth on memory persistence and quality gates, plus one UX problem
(real-time visibility). Close those three and borg is the clear leader in its class.

---

## Sources

- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [MindStudio: Claude Code Workflow Patterns](https://www.mindstudio.ai/blog/claude-code-agentic-workflow-patterns)
- [MindStudio: gstack vs Superpowers vs Hermes](https://www.mindstudio.ai/blog/gstack-vs-superpowers-vs-hermes-claude-code-frameworks)
- [Pulumi: Claude Code Orchestration Frameworks](https://www.pulumi.com/blog/claude-code-orchestration-frameworks/)
- [Addy Osmani: Your AI coding agents need a manager](https://addyosmani.com/blog/coding-agents-manager/)
- [Addy Osmani: How to write a good spec for AI agents](https://addyosmani.com/blog/good-spec/)
- [Simon Willison: Agentic Engineering Patterns](https://simonw.substack.com/p/agentic-engineering-patterns)
- [Simon Willison: parallel-agents](https://simonwillison.net/tags/parallel-agents/)
- [agor.live: The Future of Software Engineering is Agent Orchestration](https://agor.live/blog/orchestration-layers)
- [Faros AI: The AI Productivity Paradox](https://www.faros.ai/blog/ai-software-engineering)
- [blakecrosley: Agent Architecture](https://blakecrosley.com/guides/agent-architecture)
- [Latent Space: Agent Engineering](https://www.latent.space/p/agent)
- [mem0.ai: Context Engineering Guide](https://mem0.ai/blog/context-engineering-ai-agents-guide)
- [Ruflo/Claude Flow GitHub](https://github.com/ruvnet/ruflo)
- [wshobson/agents GitHub](https://github.com/wshobson/agents)
- [arxiv: Towards Decoding Developer Cognition](https://arxiv.org/html/2501.02684v1)
- [Cerbos: The Productivity Paradox of AI Coding Assistants](https://www.cerbos.dev/blog/productivity-paradox-of-ai-coding-assistants)
