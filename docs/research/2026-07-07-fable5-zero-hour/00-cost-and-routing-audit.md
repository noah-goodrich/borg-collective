# Zero-Hour Cost & Routing Audit

Generated: 2026-07-07 · Author: Fable 5 (main loop) · Scope: borg-collective / claude-plugins / cairn harness

This is the "token cost optimization" workstream of the Fable-5 zero-hour plan, promoted to first because it is
the thing actively hurting (repeated limit trips this session) and because fixing it makes every other
workstream cheaper. ELI10 first, then the specifics.

## ELI10

You hired the most expensive expert in the building (Fable 5) and, without meaning to, put them at the front
desk answering every phone call — including "where's the stapler?" That is what `settings.json` does today: it
makes Fable 5 the **orchestrator**, so every keystroke and every simple task is billed at the top rate. Worse,
when the orchestrator hands work to a *team* of helpers through the `Workflow` tool, the helpers copy the boss's
pay grade unless you say otherwise — so a "team of 30" is 30 Fable-5 salaries. That happened repeatedly today.

The fix is two moves: (1) put a cheaper, still-excellent manager at the front desk (Opus 4.8) and call Fable 5
in deliberately for the hard thinking; (2) make every workflow helper carry an explicit, cheaper pay grade.

## The two leaks (evidence)

**Leak 1 — the orchestrator itself runs on Fable 5.** `~/.claude/settings.json` line 104:
`"model": "claude-fable-5[1m]"`. The main loop dominates a session's cost (per the token-cost skill's own
measurement, ~96% of spend is main-loop: thinking-as-output + cache reads of the growing context, re-billed
every turn). So "even simple tasks route through Fable 5" is literally true — the whole session is Fable 5, and
Fable 5 is now the **most expensive tier** ($10 in / $50 out per MTok; cache read $1), pricier than Opus 4.8
($5 / $25; cache $0.50).

**Leak 2 — Workflow `agent()` calls inherit the session model.** The `Agent` tool routes to borg specialists
that carry their own cheap `model:` frontmatter (grunt/scout = Haiku, nanoprobe/researcher/reviewer = Sonnet) —
that path was already correct. But the `Workflow` tool's `agent(prompt, opts)` spawns a generic worker that
inherits the session model unless `opts.model` is set. `ROUTING.md` never mentioned this, so it silently ran
Fable 5. This session's evidence: the portfolio-research workflows spawned ~40+ agents across recon, six
evidence tracks, four verification/audit rounds, and synthesis — **all on Fable 5** — with per-run agent
context footprints of 348k, 539k, 1.08M, 692k, 100k, 719k, and 431k tokens. That is the "frightful rate," and
it tripped three session limits and one weekly limit in a single research project.

## Fixes

**Fix A — orchestrator model (the biggest lever; needs Noah's call on timing).** Change the `settings.json`
default from `claude-fable-5[1m]` to `claude-opus-4-8`. Editing the file affects the NEXT session only (not
this one), so it does not interrupt today's Fable work, and it lands Opus as the default exactly when the
research is handed to "Opus/Sonnet tomorrow." Fable stays one keystroke away (`/model claude-fable-5[1m]`) for
deliberate high-reasoning bursts. Timing caveat that is Noah's to weigh: if Fable is still under the
subscription plan for a defined window and leaves for pay-per-use after, there is a rational case to *extract*
Fable value now (heavy use is plan-covered) and flip to Opus at the cutover — the opposite sequencing. This
depends on the plan economics only Noah can see, so it is surfaced as a decision, not auto-applied.

**Fix B — ROUTING.md now covers the Workflow tool. [APPLIED]** Added a "Model routing inside Workflow scripts"
section: every `agent()` call must carry an explicit `model:` (haiku = mechanical/read-only, sonnet =
analysis/writing/review, sonnet+high = gate/verify), with inheriting the session model reserved for the rare
stage that genuinely cannot be briefed. Refreshed the stale cost table (was mid-2025 "Opus $15/$75"; now
current, and names Fable 5 as the most-expensive inherited default). This is the durable guardrail that stops
Leak 2 from recurring.

**Fix C — a workflow-authoring rule in Noah's global CLAUDE.md (proposed).** The existing "Subagent Rules" and
"Session hygiene" sections govern the `Agent` tool and context leanness but say nothing about the `Workflow`
tool. Add a short "Workflow model routing" rule mirroring Fix B so the discipline is enforced from the harness
config, not just the plugin doc. Drafted in `01-claude-md-workflow-rule.md`; apply via the update-config skill.

## What "good" looks like next session

- Orchestrator on Opus 4.8 (or Fable 5 only when deliberately chosen).
- Every workflow `agent()` call tagged: Haiku for the readers/extractors, Sonnet for the writers/reviewers,
  Fable/Opus inherited only for the one genuinely open-ended stage.
- Gate/verify stages on Sonnet-high (rigor comes from the blind setup + high effort, not the top tier).
- Estimated effect on a research-scale run: the ~40-agent Fable fan-out that tripped four limits becomes a
  mostly-Haiku/Sonnet fan-out — order-of-magnitude cheaper per the cost table — with Fable/Opus reserved for
  the handful of judgment stages.
