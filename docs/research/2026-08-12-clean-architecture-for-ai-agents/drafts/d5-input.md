# D5 blind-review input — problem statement, option set, chosen option only

## Problem statement

`borg_core/` is a new Python package replacing borg-collective's zsh CLI logic, one command at a
time (starting with `recon`, an existing ~316-line shell implementation with since-mark resolution,
pluggable source adapters, bounded concurrent fan-out, and contradiction detection against
checkpoints). A prior research pass (already gated and shipped) found that deep 4-layer Clean
Architecture (Domain/UseCase/Infrastructure/Interface directories, one class per file) carries a
measured negative correctness effect for AI coding agents, while mechanical (not merely documented)
enforcement of core/shell boundaries remains evidence-backed as valuable. The question this
decision-design pass answers: given that finding, what should `borg_core/`'s actual file-layout and
enforcement mechanism be — for `recon` specifically, and as a repeatable pattern a SEPARATE Claude
Code session (a different project, "infoviz") can imitate correctly without shared context?

## D1 status

Prior work catalogued and quarantined; options below were generated from zero. Catalog:
`drafts/d1-prior-work-catalog.md` (5 items: the `pylint-clean-architecture` plugin itself,
`pytest-coverage-impact`'s actual 8-directory custom layer map, borg-collective's pre-migration flat
shell structure, the already-shipped CLAUDE.md Architecture Rule, and this session's own first
domain/use_case/infrastructure/interface draft plus its readability-audit critique).

## D2 track findings feeding option generation

**Track A (technical mechanism, agent a0cf4e63):** `pylint-clean-architecture==1.5.2`'s layer
resolver supports directory-independent layer assignment via `module_map` (bare filename → layer)
and `base_class_map` (base-class name → layer) — not just the default `directory_map`. But the
actual I/O-boundary enforcement check (`ResourceChecker`, W9004) resolves layer at **whole-module
(whole-file) granularity** — there is no function-level or decorator-scoped hook. `import-linter`
has the same file/module-path limitation. Ruff has no custom-rule system at all (confirmed via
Astral's own FAQ + GH Discussion #8409). Ceiling: the finest enforceable unit today is one file
(via `module_map`) or one class (via `base_class_map`/`suffix_map`), not one function.

**Track B (real-world precedent, agent aa1d2cc4):** `anthropics/claude-agent-sdk-demos` is
verified (via live `gh api` inspection) to be organized entirely by feature/example
(`hello-world/`, `email-agent/`, `research-agent/`, …), each self-contained, no shared
technical-layer directories — primary, directly-inspected evidence, not philosophy. No household-
name Python CLI was found with an explicit "we rejected Clean Architecture" essay, though
PyOpenSci's own packaging guidance documents flat layout as dominant for widely-used scientific/CLI
packages. One single-source blog anecdote (Gavhane, 2026) describes an agent breaking unrelated
code in a heavily layered (Controller→Service→Repository→DB) codebase — real but not corroborated
by a second source, flagged accordingly.

**Evidence phase headline (already gated, verification-report.md PASS):** deep 4-layer Clean
Architecture carries a measured −9.1±1.6pp AI-agent correctness penalty (Constraint Decay, arXiv
2605.06445); mechanical enforcement of boundaries in general remains evidence-backed as necessary
(RepoComplianceBench: 0% unaided restraint-rule compliance); documentation quality/format has no
detectable effect on adherence once structure is present, but within-session compliance decays
~5.6%/function regardless (McMillan factorial study).

**First-draft critique (this session, pre-pivot, agent ad8eceb0):** a future session with no access
to the reasoning behind a layout would get "roughly half the conventions right by imitating the
file layout" alone, because the plugin enforces directory/suffix shape, not the semantic reasoning
behind it — the written-down WHY matters as much as the layout choice.

---

## D3: Neutral candidate options

### Option A: Project-wide flat core/shell file-tag split
- **What it is:** No new directories at all. Every command's pure logic and I/O-touching code live
  in the SAME file, but functions are tagged via `base_class_map` (a marker base class, e.g. a
  no-op `class CoreLogic:` functions/classes inherit from) so the linter can still tell them apart
  without a physical split.
- **How it works:** `[tool.clean-arch.base_class_map]` maps a marker base class to the Domain
  layer; anything NOT inheriting it is unconstrained. Enforcement is class-level, not file-level.
- **Pros:** Zero forced file count increase. Maximum colocation.
- **Cons:** Requires every "core" unit to be a class (awkward for simple functions); Track A found
  no confirmation the DI/boundary checks resolve per-class inside a mixed file the same way they do
  per-file — this is the least-tested path against the plugin's actual (whole-module) enforcement
  granularity.
- **Key tradeoffs:** Trades enforcement certainty for colocation. Might silently under-enforce.
- **Feasibility:** Medium — plugin supports the config knob, but Track A's whole-module-granularity
  finding for the boundary checker specifically means this option's core promise (per-class
  enforcement inside one file) is unconfirmed, not demonstrated.
- **Estimate:** 0.5-1 session to prototype and confirm behavior against a throwaway file.
- **Minimum viable version:** *One marker base class, one command, confirm the boundary checker
  actually fires per-class before trusting this pattern anywhere else.*

### Option B: Vertical-slice per command (core.py/shell.py pair, colocated)
- **What it is:** One folder per command (e.g. `borg_core/recon/`), containing `core.py` (pure
  logic, tagged via `module_map`), `shell.py` (all I/O — subprocess, filesystem, network), and its
  test file, all colocated. Organize by FEATURE, matching Track B's verified Anthropic precedent.
- **How it works:** `module_map` tags any file literally named `core.py` as Domain-layer, forbidding
  disallowed imports; `shell.py` is unconstrained. No shared cross-command directory.
- **Pros:** Matches the one piece of directly-verified real-world precedent found (Anthropic's own
  `claude-agent-sdk-demos`); a future session can infer the pattern by opening ONE command's folder;
  buildable today with the plugin's existing, already-used `module_map` knob — no new tooling.
- **Cons:** Still a two-file minimum per command, even for a trivially small one; whole-module
  granularity means `core.py` must be 100% free of I/O, no exceptions, including a single
  timestamp-generating shell call.
- **Key tradeoffs:** Forces every command, however small, to pay a 2-file tax. Generalizes cleanly
  but doesn't flex for command size.
- **Feasibility:** High — no new tooling, config change only, directly demonstrated to work in
  `pytest-coverage-impact`'s existing (looser) use of the same plugin.
- **Estimate:** Matches Part 3's existing C1-C7 estimate for the `recon` migration; no added cost.
- **Minimum viable version:** *`borg_core/recon/{core.py,shell.py,test_recon.py}`, `module_map`
  pointing `core.py` at Domain, ship the one migrated command as the reference pattern.*

### Option C: Custom function-level marker + bespoke pylint checker
- **What it is:** Write a small, new astroid-based pylint checker (`visit_functiondef` /
  `visit_call`) that enforces a `@core` decorator convention at the FUNCTION level, inside a single
  file, with zero forced file split at all.
- **How it works:** A new checker module, maintained alongside `pylint-clean-architecture`, walks
  function bodies and flags forbidden calls only inside `@core`-decorated functions.
- **Pros:** True function-level granularity — the one thing Track A confirmed neither the existing
  plugin nor Ruff supports today. Zero forced file-count increase, ever.
- **Cons:** Second bespoke linter to build and maintain indefinitely; unproven; adds real ongoing
  engineering surface for a granularity level no evidence source says is actually necessary (every
  option here is being evaluated against command-sized units, which are already small).
- **Key tradeoffs:** Buys maximal colocation at the cost of owning new, unvalidated tooling.
- **Feasibility:** Low-Medium — technically buildable (astroid hooks are well documented) but is new
  infrastructure, not a config change, and nothing in the evidence base says function-level
  enforcement is needed versus file-level.
- **Estimate:** 2-4 sessions to build, test, and integrate a new checker safely.
- **Minimum viable version:** *A single `@core` decorator + one astroid visitor rule, tested against
  one real violation before trusting it anywhere.*

### Option D: Shallow 2-directory technical-layer split (project-wide)
- **What it is:** Keep SOME directory-based technical layering, but cut it from Clean
  Architecture's 4 layers to 2: `borg_core/core/` (all commands' pure logic) and
  `borg_core/shell/` (all commands' I/O), enforced via `directory_map`.
- **How it works:** Same mechanism as today's default `pylint-clean-architecture` config, just with
  2 directories mapped instead of 4.
- **Pros:** Familiar to anyone who has seen the plugin's default docs; smallest config diff from
  what already exists; directory-visible at a glance.
- **Cons:** Still technical-layer, not feature-layer, organization — `recon`'s core logic lives next
  to every OTHER command's core logic, not next to `recon`'s own shell code. This is exactly the
  organizing principle Track B's Anthropic precedent and the evidence phase's Recommendation both
  argue against, just with fewer layers. A future session opening `borg_core/core/recon.py` still
  has to jump to a different directory to find `recon`'s I/O half.
- **Key tradeoffs:** Cheapest to configure, but keeps the exact cross-directory navigation cost the
  research flagged as the problem, only shallower.
- **Feasibility:** High technically, but conceptually the weakest fit to the evidence.
- **Estimate:** <0.5 session — smallest config change of any option.
- **Minimum viable version:** *Not recommended as a starting point; included for completeness and to
  be evaluated, not pre-selected out.*

### Option E: Documentation-only, no new mechanical layer for `borg_core/`
- **What it is:** Drop `pylint-clean-architecture` for `borg_core/` entirely. Rely solely on the
  already-shipped CLAUDE.md Architecture Rule ("logic goes in a testable core, shell is a wrapper")
  as prose guidance, with no linter enforcement of the boundary.
- **How it works:** No config. Convention is stated once in `CLAUDE.md` and left to be followed.
- **Pros:** Zero tooling cost, zero file-count tax, maximum flexibility per command.
- **Cons:** Directly contradicted by this project's own evidence phase: RepoComplianceBench found
  0% unaided compliance with documented-only restraint rules; the McMillan factorial study found no
  adherence benefit from documentation quality/structure and ~5.6%/function within-session decay.
  This project's own prior lesson (the cairn decommission) is that unenforced conventions are not
  reliably followed. Including this option is required by the skill's neutral-options rule, not a
  suggestion it's competitive.
- **Key tradeoffs:** None worth taking — this option exists to be evaluated and killed on its
  merits, not adopted.
- **Feasibility:** High to implement, low to trust, given the evidence base this same research
  already gated and shipped.
- **Estimate:** 0 sessions (do nothing).
- **Minimum viable version:** *N/A — this is the null option.*

### D3.5: Contradiction Forge

**Genuine tension identified:** mechanical enforcement of I/O boundaries is evidence-backed as
necessary (Option E is weak specifically because it lacks this), but Track A confirms the *only*
mechanically enforceable units today are file and class — meaning every enforced option (A, B, C, D)
imposes SOME file-count or file-shape tax on every command, however small, while the evidence
phase's headline finding is that forced splitting hurts correctness. These two evidence-backed
conclusions pull against each other at small scale.

**Ideal Final Result:** every command is enforced AND a genuinely small command pays no split tax.

**Separation move: scale.** Apply the mechanical split only once a command's own measured
complexity crosses a real threshold — not unconditionally from the first line of every command.
This project already has a working, applied precedent for exactly this kind of threshold: Part 2's
`graph.py` refactor used a C901 cyclomatic-complexity gate (>10) to decide when a function *needed*
extraction, not a blanket rule that every function must be split regardless of size.

### Option F: Complexity-gated colocation (resolves the D3.5 tension)
- **What it is:** Default to Option B's `core.py`/`shell.py` pair, but only REQUIRE the split once a
  command's single-file draft crosses the same C901 complexity threshold (>10) already in use
  elsewhere in this repo. Below that threshold, one colocated file is allowed, with a lighter
  function-name-prefix convention (e.g. `_shell_*`) as a documented (not mechanically enforced)
  marker for the rare small command that needs a single I/O call.
- **Separation move used:** scale (complexity-threshold-gated), reusing an existing, already-proven
  metric rather than inventing a new one.
- **Pros:** Holds both poles — enforcement stays mechanical above the threshold, colocation stays
  maximal below it. Reuses tooling and a threshold this repo already trusts.
- **Cons:** Two code shapes to recognize instead of one (a trivially small command looks different
  from a complex one) — a future session must learn both, not just one pattern. Needs a CI/pre-commit
  wiring step (checking C901 against a not-yet-split file) that doesn't exist yet.
- **Key tradeoffs:** More conceptually correct, more moving parts; not yet proven simpler in
  practice for a codebase with only one migrated command so far.
- **Feasibility:** Medium — the C901 check exists and is already run (Part 2 precedent), but gating
  the *split requirement itself* on it is new wiring, not a reused config knob like Option B.
- **Estimate:** Option B's cost, plus 0.5-1 session to wire the complexity gate.
- **Minimum viable version:** *Ship Option B's pattern for `recon` (already complex enough to clear
  the threshold on its own merits per the recon.sh read-through), defer the gate itself until a
  second, genuinely small command tests the low end.*

---


## Chosen option

The draft recommendation selects **Option B** (vertical-slice per command, colocated core.py/shell.py
pair, module_map-tagged), scoped to ship for the recon migration now, with Option F (complexity-gated
colocation) recorded as an explicitly deferred refinement rather than a rejected idea, to revisit once
a second command migrates.
