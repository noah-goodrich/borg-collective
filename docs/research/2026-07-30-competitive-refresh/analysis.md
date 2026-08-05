Generated: 2026-07-30

# Competitive Refresh — borg-collective vs. i-have-adhd and the 2026-Q3 landscape

Blind-review status: REVISE — borg-reviewer returned REVISE (keep Recs 4–6, fix 1–3). Objections
incorporated into §1 below; the pre-revision recommendations are preserved in §6 for audit trail.
Strongest objection sustained: recon's contradiction logic was just shipped (`ebf866a`, #46 Track 2),
so any "replace it" recommendation must first prove the shipped code is deficient — it does not yet.

## Glossary

- **borg pillar** — one of borg-collective's distinctive capabilities: nanoprobe fan-out, cairn
  knowledge graph, checkpoint handoff, recon fan-out, ADHD/boundary guardrails.
- **nanoprobe** — an ephemeral Claude Code subagent borg spawns via the Agent tool to do one task.
- **cairn** — borg's optional Postgres + pgvector knowledge graph (decisions, patterns, debriefs).
- **checkpoint** — a user-authored markdown session summary borg injects at the next session start.
- **recon fan-out** — borg's source-agnostic primitive that reconciles checkpoints against live
  sources (GitHub/Slack/etc.) and flags contradictions.
- **temporal knowledge graph** — a graph that marks a fact invalid with a timestamp instead of
  deleting it, so history and current truth both survive (Graphiti/Zep do this).
- **output-style skill** — a rules file that changes how an agent *phrases* answers, not what it does.

## 1. Recommendations (post-blind-review)

Ordered cheapest-to-be-wrong-about first, per the reviewer's ranking. Recs 4–6 upheld; 1–3 revised.

1. **Watch list — keep the quarterly scan warm (upheld).** claude-mem (highest handoff overlap;
   volatile star count 46k→89k), Anthropic Managed Agents Memory (cloud-only today; watch for a CLI
   backport that would threaten cairn), bernstein (deterministic/auditable fan-out), maestro-flow +
   total-agent-memory (independent cairn-shaped entrants), Ruflo (31.1k★, unverified). (§5-Track-2)
2. **Run ONE validation spike before any nanoprobe or fan-out decision (merged old Rec 1+5).** The
   reviewer correctly flagged that "stop investing, it's native" contradicted "re-test first" — so
   there is no standing recommendation to disinvest yet. Instead: directly read the native
   background-agents + `isolation:worktree` docs and test whether they now work when the orchestrator
   CWD is not a git repo (the exact failure that made nanoprobes manage their own worktrees per
   CLAUDE.md). Native limits churned within days in Jul 2026 (concurrency cap → nesting disabled →
   reinstated at depth-3) — that is platform *volatility*, not settled convergence. Only after the
   spike passes should investment in the custom fan-out mechanism be reduced. Do NOT adopt
   LangGraph/CrewAI as a substrate regardless. (§4, §5-Track-3)
3. **Adopt i-have-adhd's distribution pattern actively, not passively (strengthened old Rec 4).** It
   is a single-file output-style skill (14.2k★) orthogonal to borg's executive-function/boundary
   layer. Borrow the packaging insight *by applying it to borg*: extract `adhd-guardrails` (or a
   sub-skill) into a zero-infra, one-file, forkable, agent-agnostic skill that is independently
   installable — the shape that drove i-have-adhd's adoption. Also adopt its explicit escape-hatch
   rule-list and per-response "Step N of M" recap. Recommending i-have-adhd as a complementary install
   is a footnote, not the move. (§4, §5-Track-1)
4. **Graphiti: evaluate ONLY if the just-shipped contradiction logic proves deficient (downgraded old
   Rec 2).** The reviewer's strongest catch: recon's checkpoint-vs-source contradiction persistence
   shipped in `ebf866a` (#46 Track 2) essentially concurrent with this analysis. The prior "clearest
   stop-reinventing win" framing was wrong — you cannot recommend replacing code without first showing
   it is inadequate. Revised action: (a) let the shipped logic run and gather evidence of any actual
   deficiency at scale; (b) ONLY if a real gap appears, evaluate Graphiti — and weigh the cost of a
   Neo4j/FalkorDB dependency on an all-Postgres stack (plus a FalkorDB SSPL-license check) against the
   narrow, structured nature of checkpoint-vs-state reconciliation, which is not Graphiti's
   unstructured-entity-extraction sweet spot. Default expectation: keep the shipped code. (§4)
5. **claude-mem: only as a REPLACEMENT layer with an injection budget, never a fourth stack (downgraded
   old Rec 3).** borg already injects checkpoint + cairn context + presence at SessionStart; adding
   claude-mem's own auto-summary would stack a fourth injection and reintroduce the context-bloat the
   ADHD pillar exists to prevent. If pursued at all, the plan must (a) name the concrete hook ordering
   and a total SessionStart token budget, (b) have claude-mem *replace* borg's automatic
   "what-happened-last-session" injection rather than add to it, (c) specify the SQLite→cairn-Postgres
   ETL path, and (d) accept the single-maintainer bus-factor of depending on it for a core path.
   Absent that plan, do not pursue. (§4)
6. **Governance gate on any core-path dependency (new, from reviewer's missing-considerations).** Before
   Graphiti or claude-mem becomes load-bearing, require: a bus-factor/maintenance assessment, a license
   check (FalkorDB SSPL; Graphiti Apache-core claim is NOT yet independently confirmed), and a
   cost/effort estimate of the prototype vs. the maintenance burden of the code it would replace — the
   "is this actually a burden?" question the pre-revision draft asserted rather than answered.

## 2. Summary

The headline: **borg is not being out-competed; it is being partially absorbed by the platform, and
that is good news if borg pivots its investment.** Between the last discovery pass (~2026-04) and now,
Anthropic made the *parallel-fan-out* part of borg native. The correct response is not to defend that
turf but to lean into what stayed distinctive — and three of those pillars (ADHD/boundary enforcement,
recon's contradiction reconciliation, cairn's local opt-in graph) have no real off-the-shelf equal.

Two pillars are genuinely reinventing wheels and should lean on maintained libraries: recon's
contradiction logic (→ Graphiti's temporal edges) and the automatic half of session handoff (→
claude-mem). Neither is a rip-and-replace; both are scoped prototypes that keep borg's differentiated
schema/UX on top.

`i-have-adhd` — the specific project that prompted this — is a distribution lesson, not a threat. It
went viral (14.2k stars in ~2.5 months, driven by one X post) as a one-file, fork-friendly,
cross-agent output-style skill. It solves response *verbosity*; borg's adhd-guardrails solves human
*executive function*. They compose; they don't compete. The transferable insight is the packaging:
zero-infra, forkable, agent-agnostic markdown wins adoption.

Testability: most claims here are cheaply testable in-environment (a Graphiti prototype, a claude-mem
bake-off, a direct read of the background-agents docs) rather than requiring external evidence — the
recommendations are framed as scoped experiments, not committed swaps.

NO PRIMARY EVIDENCE — all findings are literature-derived predictions and vendor/repo-doc reads; no
head-to-head benchmark of cairn vs. Graphiti/claude-mem was run. Treat lean-on calls as hypotheses.

## 4. Analysis — borg vs. the field, by pillar

| borg pillar | Nearest 2026 overlap | Overlap | Verdict |
|---|---|---|---|
| Nanoprobe fan-out | Native background subagents (depth-3, 200-cap) | **High / converged** | Keep worktree hygiene + cairn logging + bounded-termination; stop investing in the mechanism |
| Checkpoint handoff | claude-mem (compress+inject); native agent-checkpointing (task-tree only) | **Medium** | Keep user-authored layer; bake-off claude-mem as the automatic under-layer feeding cairn |
| cairn knowledge graph | Managed Agents Memory (cloud-only); total-agent-memory; maestro-flow; Cognee | **Medium, rising** | Keep store/schema; swap ONLY recon's contradiction logic → Graphiti |
| recon fan-out | CCPM (GitHub-only, stalled); bernstein (deterministic) | **Low-Medium** | Keep — nothing does checkpoint-vs-source reconciliation; consider MCP-connector adapters |
| ADHD guardrails / boundaries / capacity | ravila4/claude-adhd-skills (stale 5mo); blog recipes | **Low** | Most durable, least-contested pillar; no enforced-mechanism competitor exists |
| Agent-Teams cross-session persistence | Anthropic closed #33764 "not planned" | — | Durable gap borg fills; unlikely to close natively |

Consensus zone: everyone agrees parallel worktree-isolated agents are valuable (Conductor, Crystal,
bernstein, native isolation all build it) — which validates borg's worktree work as real, not busywork.
Contested zone: automatic-vs-human session summarization (claude-mem's opaque compression vs. borg's
user-authored framing) — borg's choice is deliberate and defensible for the ADHD use case. Gap: no one
but borg reconciles a stored plan/checkpoint against live upstream state.

## 5. Research — findings by track

**Track 1 — i-have-adhd.** `ayghri/i-have-adhd`, created 2026-05-13, 14,176★/751 forks by 2026-07-30
(GitHub API-verified). A SKILL.md rules file (10 rules: action-first, numbered steps, capped lists,
state recap, no preamble) distributed as a plugin-marketplace entry, activated by `/i-have-adhd`.
Explicitly non-clinical ("No ADHD diagnosis needed"). Viral vector was a single X post by @jjacky, not
Reddit/HN (evidence gap noted). Ported by community to Codex/Cursor/Gemini/Qwen/Antigravity — a
cross-agent output-style de-facto standard. Naming-collision caution: a *separate* "adhd" repo
(UditAkhourii) is an unrelated tree-of-thought reasoning skill — do not conflate. Full record:
`.borg/research/i-have-adhd-2026-07-30.md`.

**Track 2 — landscape.** gstack 125k★ (still a persona/skill pack + isolated-browser Conductor; no
graph, no boundary layer). Citadel rebranded to "operating layer… persistent memory, routing, cost
telemetry, worktree fleets" (closest philosophical overlap; markdown-file memory, not pgvector).
claude-mem 89k★, now multi-harness (highest handoff overlap). CCPM stalled since March. Agent Teams
persistence closed "not planned." Native changelog Jun–Jul 2026 shipped background-by-default subagents,
depth-3 nesting, 200-cap, maturing `isolation:worktree`, beta agent-checkpointing, `/rewind`. New
entrants: bernstein (deterministic replay + signed lineage), omnigent (harness-agnostic meta), maestro-
flow (KG + multi-tool), pilotfish (model-tiering), Ruflo (31.1k★, unverified). Full record:
`scratchpad/claude-code-ecosystem-2026-07.md`.

**Track 3 — build-vs-lean-on.** cairn: keep Postgres/pgvector + schema; lean on Graphiti for the
temporal contradiction logic recon hand-rolls (clearest swap). nanoprobes: keep worktree lifecycle
(commercially validated by Conductor/Crystal); re-test native background agents; reject
LangGraph/CrewAI. checkpoints: native `/rewind` + agent-checkpointing solve a different altitude
(task-resume, not human context); claude-mem is the strongest lean-on for the automatic half. recon:
no equal; wrap MCP connectors as adapters if more sources are ever needed. Standards: MCP + SKILL.md
already aligned; A2A low relevance (all nanoprobes are one-owner, single trust boundary).

## 6. Methodology

Three parallel `borg-researcher` (Sonnet, web-enabled) tracks, from-zero per decision-design D2, with
the prior competitive-landscape memory walled off as D1 prior work. 66 sources across the three tracks,
all 2024–2026, GitHub numbers API-cross-checked. Bias-Guard: findings skew toward "borg is
differentiated" (agree) — the deliberate falsification lens was "what did Anthropic make native that
makes borg redundant," which surfaced the fan-out convergence (the strongest disconfirming finding, now
Recommendation 1). Limitations: no head-to-head benchmarks; Citadel/Ruflo star data unverified; no
direct HN thread; background-agents docs only partially fetched. This is a rapid-tier advisory
synthesis, not a full-tier independently-verified evidence base — UNVERIFIED beyond self-check plus one
blind adversarial review.

**Blind review (D5) — verdict REVISE, incorporated.** A cold `borg-reviewer` (no access to the drafting
reasoning) returned REVISE: uphold Recs 4–6, fix 1–3. Sustained objections and how §1 was changed:
(1) old Rec 1 "stop investing in fan-out" contradicted old Rec 5 "re-test first" → merged into a single
validation-spike-first recommendation (new Rec 2), convergence no longer asserted as settled; (2) old
Rec 2 recommended prototyping Graphiti to replace recon's contradiction logic, but that logic shipped in
`ebf866a` (#46 Track 2) concurrent with the analysis → downgraded to "evaluate only if the shipped code
proves deficient" (new Rec 4), default keep-the-shipped-code; (3) old Rec 3 would stack claude-mem as a
fourth SessionStart injection → downgraded to "replacement-with-budget-only, never additive" (new
Rec 5); (4) old Rec 4 was too passive → strengthened to "extract adhd-guardrails into the one-file
forkable shape" (new Rec 3); (5) added a governance/bus-factor/license gate (new Rec 6). The reviewer's
verbatim strongest objection is retained in the session record. Pre-revision recommendations are
recoverable from this file's git history.
