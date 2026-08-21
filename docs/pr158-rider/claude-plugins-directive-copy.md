# Directive: Design-Doc and Brevity Skills

*Filed: 2026-08-20 · Status: Proposed · Parent: borg-collective/docs/plans/directives/2026-08-20-communication-program.md*

**tl;dr** — Every proposal, PR description, and long chat reply is shaped from scratch each time, so quality
depends on the agent remembering how Noah reads. Ship three skills in the noah-writing-voice / research-tools
family that make the format the default: a design-doc template, a brevity layer, and a PR-description
generator.

## Problem

Noah's work tooling (2026-08-19) converged on a template — Problem, Solution, Goals, Non-Goals, Alternatives
Considered — and a tl;dr discipline: one sentence of problem, one of solution, readable without context.
Nothing on the personal side encodes either. Naming note from research: the industry calls this shape a
**design doc** (Google lineage) or **RFC**; "TRD" elsewhere means a requirements spec, a different artifact
(industrialempathy.com/posts/design-docs-at-google, rust-lang.github.io/rfcs). Keep "TRD" as Noah's spoken
alias; name the skill `design-doc`.

## Solution

Three skills, one plugin family:

- **K1 — `design-doc`.** Scaffolds and reviews documents in the template: tl;dr (top), Problem, Solution,
  Goals, Non-Goals (falsifiable boundary statements), Alternatives Considered (load-bearing, each rejected
  option with the trade-off that killed it), Decisions requested. Length caps: 1-3 pages incremental, hard
  stop at the point a reader stops (industrialempathy). Status line kept current (Proposed/Accepted/
  Superseded), per ADR practice.
- **K2 — brevity layer.** Extend `noah-voice` (or sibling skill) with the distilled, unbranded method:
  front-load the one thing; one explicit why-it-matters line; depth goes to a linked "go deeper", never the
  body; bullets over prose past two facts; bold only figures and decisions; conditions before instructions;
  never flatten a real trade-off into a bullet (the documented Smart Brevity failure mode); chat replies end
  with the tl;dr, documents start with it. Sources recorded in the skill: developers.google.com/style/tone,
  /style/highlights; Smart Brevity method + CJR critique.
- **K3 — `pr-description`.** Generates PR bodies as: tl;dr (problem + solution sentences), chain position
  (which program/lane, what it blocks and is blocked by, from `.borg/programs` manifests when present),
  review map (the 2-3 files that carry the change), test evidence. Replaces freeform bodies.

## Acceptance criteria

- [ ] AC1 `/design-doc` produces the template with all seven sections and refuses to emit one without a
      tl;dr; the umbrella + delivery-surfaces directives (borg-collective, 2026-08-20) validate against it.
- [ ] AC2 The brevity rules are testable: the skill includes a checklist an agent can self-audit against,
      and `ai-scoring` keeps its existing floor on the output.
- [ ] AC3 `/pr-description` run against a real PR in this repo produces a body with all four blocks and
      correct chain position for a manifest-declared PR.
- [ ] AC4 All three ship through the normal plugin build; `claude plugin install` from noah-local loads them;
      CI green.

## Non-Goals

- No branded lingo ("Smart Brevity", "Axios-style") in any output.
- No rewrite of existing noah-writing-voice rules; K2 layers on top.
- No auto-posting of PR bodies; K3 writes text, humans post it.

## Alternatives Considered

- **One mega writing skill**: rejected; the three trigger in different moments (planning, replying,
  shipping) and a single skill would load its full weight on every turn.
- **Encode the rules only in CLAUDE.md/memory**: rejected; the audit showed volunteered discipline decays.
  Skills load mechanically at the moment of use.
- **Adopt an off-the-shelf TRD generator**: none found that encodes reading mechanics (tl;dr placement,
  landing region) rather than section headings alone.
