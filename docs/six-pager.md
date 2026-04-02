# The Borg Collective: AI Development Orchestration Framework

*A narrative proposal for building a sustainable parallel AI development workflow that manages
cognitive load, enforces shipping discipline, and persists context across sessions.*

**Status: v2 complete** — This document reflects the final v2 architecture as of 2026-03-31.
See [Appendix E](#appendix-e-change-log) for revision history.

---

## 1. Introduction

Software development in 2026 has been transformed by AI coding agents. Tools like Claude Code, Cortex
Code CLI, and their peers allow individual developers to run three, five, or even ten parallel coding
sessions across projects. Boris Cherny, the creator of Claude Code, ships twenty to thirty pull requests
per day by running five simultaneous git worktrees. Teams at incident.io reduced a two-hour JavaScript
editor upgrade to ten minutes using four parallel Claude agents. The productivity ceiling has never been
higher.

The problem is sustainability. Managing parallel AI sessions creates a cognitive baseline — the mental
overhead of tracking where each session left off, what each one needs, and which one to attend to
next — that consumes working memory before any productive work begins. Research on context-switching
(Gloria Mark, UC Irvine) shows a twenty-three-minute recovery cost per interruption, measured on the
general population. Working memory is limited to roughly seven items (Miller's Law); four active sessions
consume four of those slots, leaving three for actual engineering.

For developers with ADHD or other neurodivergent conditions, these effects are amplified: the switching
cost is higher, the recovery less complete, and the novelty-seeking draw of new sessions creates
addiction patterns documented in the AI Addiction Scale (AIAS-21). But the underlying problem —
cognitive overload from parallel session management — affects every developer. ADHD makes it acute and
visible; for neurotypical developers, it manifests as gradual burnout over weeks and months.

This document proposes The Borg Collective, an AI development orchestration framework that solves a
specific problem: how does a developer manage parallel work streams across projects, tools, and contexts
without burning out, losing track of progress, or failing to ship? The answer is that tools must enforce
boundaries and persist context as aggressively as they remove friction.

---

## 2. Goals

Borg is measured against five objectives:

- **Decision paralysis elimination.** `borg next` answers "what should I do?" with a single
  recommendation and switches to that project. Target: context-switching decision time drops from
  minutes to zero (one hotkey). Research basis: accountability check-ins increase goal achievement from
  twenty-five to ninety-five percent (Edge Foundation).

- **Cognitive load management.** Capacity warnings, automatic archiving, and persistent session context
  reduce the mental overhead of tracking parallel sessions. Target: the developer's working memory is
  available for engineering, not bookkeeping. Research basis: working memory limits (Miller's Law),
  decision fatigue (Baumeister).

- **Work/life boundary enforcement.** Work projects gated after hours. Target: switching to a work
  project at 10 PM requires one explicit keystroke. Research basis: sustained overwork without recovery
  leads to burnout (Maslach Burnout Inventory); structured breaks prevent cognitive degradation.

- **Shipping discipline.** Every project can define locked acceptance criteria via `/borg-plan`. Claude
  proposes criteria; the developer validates. Once locked, scope changes require explicit confirmation.
  `/borg-ship` evaluates readiness with evidence. Target: every active project has a clear stopping
  point. Research basis: without explicit exit criteria, work expands to fill available time
  (Parkinson's Law applied to AI-assisted development).

- **Zero adoption friction.** Two commands (`borg`, `drone`), familiar CLI conventions, one installer.
  Target: working setup in under ten minutes. Research basis: adoption friction kills tools; external
  scaffolding must be easier to use than to skip.

---

## 3. Tenets

These principles are non-negotiable:

**External scaffolding, not willpower.** Every boundary must be enforced by the system, not remembered
by the developer. If it requires a human to "just remember to" do something, it will fail under
cognitive load. This is not an ADHD-specific constraint — it is a consequence of finite working memory
documented across cognitive psychology.

**Compose, do not rebuild.** Claude Code already provides worktrees, task tracking, skills, hooks,
context management, and agent teams. Borg builds only what these native features do not provide: session
orchestration, project lifecycle management, work/life boundaries, and cross-session knowledge
persistence. Anything Claude Code does natively, borg delegates to it.

**Skills are the portable unit of discipline.** CLAUDE.md is tool-specific. Skills are portable across
Claude Code and Cortex Code CLI, and propagate into devcontainers via bind mount. Any workflow pattern
worth encoding goes into a skill. This is Boris Cherny's insight: "If you do something more than once
a day, make it a skill."

**Claude does the thinking, developer validates.** Skills don't ask open-ended questions. They read the
codebase, form proposals, and present them for confirmation. The developer's cognitive load is reviewing
and adjusting, not generating from scratch.

**Speed bumps, not walls.** Boundaries are one-keystroke confirmations, not hard blocks. A developer who
wants to work at midnight presses "y." Hard blocks get disabled; speed bumps get internalized.

**Ship, then improve.** The irony of spending months perfecting a shipping-discipline tool that never
ships is the single most likely failure mode of this project.

---

## 4. Current State

Borg exists today as a working orchestration framework: approximately 765 lines of zsh, six custom
skills, three hooks, an installer, and comprehensive documentation. The v1 CLI (`borg next`, `borg ls`,
`borg switch`, etc.) is functional. Session lifecycle tracking via hooks works. Work/life boundaries are
implemented. The tmux hotkey (`Ctrl+Space >`) switches to the most pressing project.

### What works

- **Session tracking**: Hooks automatically update project status (active/waiting/idle) as Claude
  sessions start, wait, and stop.
- **Priority scoring**: `borg next` uses a weighted scoring system (pinned +200, waiting +100, active
  +50) to recommend what to work on.
- **Boundary enforcement**: Work projects gated after configured hours with one-keystroke confirmation.
- **Capacity warnings**: Alert when active sessions exceed the configured limit.
- **Skills**: Six custom skills installed — cognitive load guardrails, project planning, shipping
  checklist, mid-session review, session debrief, and enhanced checkpoint.

### What's in v2 (complete)

- **`drone` CLI**: Forked from `dev.sh` into the borg-collective repo. `drone up/down/claude/sh/restart/fix/status`
  manages the full project lifecycle.
- **`borg init` orchestrator**: Launches a Claude session with a morning briefing built from the
  registry, recent session debriefs, and cairn knowledge. `borg claude` re-enters the session.
- **LLM-powered debriefs**: Stop hook runs a Sonnet-powered analysis of the full session transcript
  (~$0.10/session). Produces structured records: objective, outcome, decisions, blockers, next steps.
  Stored at `~/.config/borg/debriefs/<project>.md` and auto-loaded as context on next session start.
- **Cairn integration**: Optional knowledge graph (PostgreSQL + pgvector). Session records committed on
  stop. Knowledge searched at session start and via `borg search`. Borg degrades gracefully without it.
- **tmux session**: Default renamed from `dev` → `borg`.

### What's been cut

- `summarize.py` (regex-based extraction) — replaced by LLM debriefs (deprecated, pending deletion)

---

## 5. Lessons Learned

**Lesson 1: Parsed summaries are useless.** The original `summarize.py` extracted goals from JSONL
transcripts using regex patterns. It produced output like "Goal: /exit exit." The last 200 lines of a
transcript are often tool results, not human-readable text. LLM-powered analysis of the full transcript
is worth the cost (~$0.10/session via Sonnet) because it replaces all future context re-derivation.

**Lesson 2: The tool must think for the developer, not ask them to think.** The first version of
`/borg-plan` asked open-ended questions: "What is the objective?" "What are the acceptance criteria?"
This puts the cognitive load on the developer — exactly the wrong direction. The revised version reads
the codebase, proposes criteria, and asks the developer to validate. Same outcome, fraction of the
mental effort.

**Lesson 3: Cognitive load is the universal problem, not ADHD.** The original framing was
ADHD-specific. In practice, every developer managing parallel AI sessions faces the same issues: working
memory consumed by context tracking, decision fatigue from pending sessions, and no natural stopping
points. ADHD amplifies these effects and makes them visible sooner, but the underlying mechanisms
(Miller's Law, Baumeister's decision fatigue, Maslach's burnout dimensions) are universal. Reframing
around cognitive load makes the tool relevant to every developer, not just those with clinical
diagnoses.

**Lesson 4: Multiple CLIs multiply cognitive load.** Having separate tools (`borg`, `dev.sh`, `claude`)
with different conventions forces the developer to maintain a mental model of which tool does what. The
unified `borg` + `drone` model reduces this to two commands with consistent patterns.

**Lesson 5: Cairn solves the persistence problem.** Session context is ephemeral — it's lost on
compaction, context overflow, or session end. A knowledge graph that persists decisions, patterns, and
session debriefs across sessions and projects means the developer (and Claude) never starts from zero.
The cost of running LLM analysis at session stop is justified by eliminating re-derivation costs in all
future sessions.

---

## 6. Strategic Priorities

### Phase 1: Skills ✓

Six skills installed and working:
- `/borg-plan` — Project planning (Claude proposes, developer validates)
- `/borg-ship` — Shipping checklist with evidence
- `/borg-review` — Mid-session diagnostic with loop detection
- `/borg-debrief` — Structured session analysis
- `/borg-checkpoint` — Manual checkpoint
- Cognitive load guardrails (always-on)

### Phase 2: drone CLI ✓

Forked `dev.sh` into `drone.zsh`. Commands: `drone up`, `drone down`, `drone claude`, `drone sh`,
`drone restart`, `drone fix`, `drone status`. tmux session default renamed from `dev` to `borg`.

### Phase 3: Hook integration ✓

Stop hook runs Sonnet debrief async against full transcript. Start hook injects debrief as
`additionalContext` via `hookSpecificOutput`. `summarize.py` deprecated.

### Phase 4: Orchestrator ✓

`borg init` generates context from registry + debriefs + cairn via `_borg_orchestrator_context` and
launches `claude --append-system-prompt`. `borg claude` re-enters with `--continue`.

### Phase 5: Cairn integration ✓

Stop hook commits session record to cairn after debrief is written. Start hook merges cairn knowledge
into session context alongside debrief. `borg search` wraps `cairn search`. `borg hail` uses
`cairn search --project`. All cairn calls degrade silently if cairn is unavailable.

### Phase 6: Documentation ✓

Six-pager, architecture, CLAUDE.md, cheatsheet, quickstart, and README updated to reflect v2 final
state. All references to in-progress work removed.

---

## Appendix A: Research Citations

See `docs/research.md` for the complete citation index organized by domain: cognitive load and working
memory, context-switching costs, decision fatigue, burnout, AI addiction risk, shipping discipline,
Claude Code best practices, skills ecosystem, and devcontainer workflows.

## Appendix B: Architecture

See `docs/architecture.md` for system design, data flow, registry schema, hook lifecycle, and skills
integration.

## Appendix C: Quick Reference

See `docs/cheatsheet.md` for the single-page command reference.

## Appendix D: Getting Started

See `docs/quickstart.md` for installation and first-run guide.

## Appendix E: Change Log

| Date | Change |
|------|--------|
| 2026-03-29 | Original proposal: ADHD-specific framing, three phases (make it work, boundaries, cognitive load management). v1 shell CLI with regex-based summarizer. |
| 2026-03-30 | Major revision: reframed from ADHD-specific to universal cognitive load. Added v2 architecture (borg + drone + cairn). Added six skills (borg-plan, borg-ship, borg-review, borg-debrief, borg-checkpoint, cognitive guardrails). Added orchestrator concept (borg init). Added LLM debriefs replacing regex extraction. Cairn integration as optional knowledge persistence. Scope still WIP. |
| 2026-03-31 | v2 complete: Implemented all six phases. Hook integration (Phase 3): async Sonnet debrief on stop, debrief + cairn context injection on start. Orchestrator (Phase 4): borg init + borg claude with --append-system-prompt. Cairn integration (Phase 5): session commits on stop, knowledge search on start, borg search command. Docs cleanup (Phase 6): all references updated to final state. |
