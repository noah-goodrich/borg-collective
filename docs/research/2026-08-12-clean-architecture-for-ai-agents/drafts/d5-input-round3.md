# D5 Round 3 (final, capped) blind-review input

This is a THIRD, independent blind review. Two prior rounds each found real problems and forced
revisions to earlier versions of this option set; the set below reflects both corrections plus a
fresh empirical spike run in direct response to the second round's demand to verify before deciding.
Review it cold. This project has an explicit rule capping this review at 3 rounds total — this is
the last one — so if you find a real problem, say so plainly rather than softening it because it's
the final round.

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

**Track A (technical mechanism):** `pylint-clean-architecture==1.5.2`'s layer resolver supports
directory-independent layer assignment via `module_map` (bare filename → layer) and
`base_class_map` (base-class name → layer) — not just the default `directory_map`. The actual
I/O-boundary enforcement check (`ResourceChecker`, W9004) resolves layer at whole-module (whole-file)
granularity — there is no function-level or decorator-scoped hook. `import-linter` operates on real
dotted module paths instead. Ruff has no custom-rule system at all (confirmed via Astral's own FAQ +
GH Discussion #8409). Ceiling: the finest enforceable unit today is one file (via `module_map`) or
one class (via `base_class_map`/`suffix_map`), not one function.

**Track B (real-world precedent):** `anthropics/claude-agent-sdk-demos` is verified (via live `gh
api` inspection) to be organized entirely by feature/example (`hello-world/`, `email-agent/`,
`research-agent/`, …), each self-contained, no shared technical-layer directories — primary,
directly-inspected evidence, not philosophy. No household-name Python CLI was found with an explicit
"we rejected Clean Architecture" essay, though PyOpenSci's own packaging guidance documents flat
layout as dominant for widely-used scientific/CLI packages. One single-source blog anecdote
(Gavhane, 2026) describes an agent breaking unrelated code in a heavily layered
(Controller→Service→Repository→DB) codebase — real but not corroborated by a second source.

**Evidence phase headline (already gated, verification-report.md PASS):** deep 4-layer Clean
Architecture carries a measured −9.1±1.6pp AI-agent correctness penalty (Constraint Decay, arXiv
2605.06445); mechanical enforcement of boundaries in general remains evidence-backed as necessary
(RepoComplianceBench: 0% unaided restraint-rule compliance); documentation quality/format has no
detectable effect on adherence once structure is present, but within-session compliance decays
~5.6%/function regardless (McMillan factorial study).

**First-draft critique (this session, pre-pivot):** a future session with no access to the reasoning
behind a layout would get "roughly half the conventions right by imitating the file layout" alone,
because the plugin enforces directory/suffix shape, not the semantic reasoning behind it.

## D2.5: Empirical spike (run after a prior review round asked for verification, not assumption)

A real two-command scratch package (`borg_core/cmda/`, `borg_core/cmdb/`, each with its own
`core.py`) was built and both candidate tools were run against it directly. Results, verbatim:

1. `pylint-clean-architecture`, configured with only `[tool.clean-arch.module_map] Domain =
   ["core.py"]` (no `allowed_prefixes`): flags a LEGITIMATE same-command import
   (`cmda/core.py` importing its own sibling `cmda/types.py`) as forbidden I/O
   (`W9004: Forbidden I/O access (import borg_core.cmda.types) in Domain layer`).
2. Adding `allowed_prefixes = ["borg_core"]` to the same config: the legitimate same-command import
   now passes cleanly. A real `subprocess.run(...)` call in the same file is still correctly flagged
   (`W9004: Forbidden I/O access (import subprocess) in Domain layer`) — the fix does not disable
   real I/O protection.
3. Same config as #2, but `cmda/core.py` also contains `from borg_core.cmdb.core import helper` (a
   cross-command import): pylint reports ZERO warnings for this line. The cross-command import is
   silently permitted.
4. `import-linter`, configured with an `Independence` contract listing `borg_core.cmda` and
   `borg_core.cmdb` as members, run against the SAME cross-command import from #3: reports it as
   broken — `borg_core.cmda is not allowed to import borg_core.cmdb: borg_core.cmda.core ->
   borg_core.cmdb.core (l.4)`.
5. Separately verified: `pylint-clean-architecture` is listed on PyPI as author `noah-goodrich`,
   Development Status "3 - Alpha," 4 releases total, all dated this month. `import-linter` is listed
   as maintained by a separate, independent author (`seddonym`) since 2022.

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

### Option B (revised, Round 3, empirically spiked): Vertical-slice per command + import-linter Independence contract
- **What it is:** One folder per command (e.g. `borg_core/recon/`), containing `core.py` (pure
  logic, tagged via `module_map`), `shell.py` (all I/O — subprocess, filesystem, network), and its
  test file, all colocated. Organize by FEATURE, matching Track B's verified Anthropic precedent.
  **Round 2 change:** `pylint-clean-architecture` alone is confirmed (direct source read, see Round
  1 D5 verdict above) to provide zero cross-command isolation — `module_map` resolves by bare
  filename, and its `DependencyChecker` unconditionally allows intra-layer imports. Option B now
  pairs it with `import-linter`'s `Independence` contract, verified present and confirmed by its own
  docstring to check "a set of modules do not depend on each other... even indirectly," keyed off
  real dotted module paths rather than a resolved layer label.
- **How it works:** `module_map` still tags any file literally named `core.py` as Domain-layer for
  the raw-I/O check (unchanged). A new `import-linter` config lists every `borg_core.<command>`
  package as an `Independence` contract member, so `recon`'s package importing from another
  command's package fails a SEPARATE, second check that `pylint-clean-architecture` cannot perform.
  Two tools, two distinct jobs: one polices "no raw I/O in core," the other polices "no reaching
  into a sibling command."
- **Pros:** Matches the one piece of directly-verified real-world precedent found (Anthropic's own
  `claude-agent-sdk-demos`); a future session can infer the pattern by opening ONE command's folder.
  Both tools are already-installed PyPI packages, not something built from scratch for this — but
  disclosed plainly, not evenly: `import-linter` is genuinely mature, independent tooling (maintained
  since 2022 by a separate author); `pylint-clean-architecture` is Noah's own single-maintainer,
  Alpha-status package (4 releases, all this month). That was already a load-bearing dependency of
  this same PROJECT_PLAN before this research question existed, so it is not NEW risk from choosing
  B — but the earlier framing of "no new bespoke tooling" undersold that half of the pairing is
  self-authored and young, and that should be a named, visible fact, not a hidden one.
  **Empirically verified, Round 3 (not just claimed):** built a real two-command scratch package and
  ran both tools against it. `pylint-clean-architecture` alone, correctly configured to be usable at
  all (`allowed_prefixes` set), silently permits a real cross-command import with zero warning —
  confirming it provides no genuine isolation once configured for real use. `import-linter`'s
  `Independence` contract, configured against the same two commands, correctly flagged that exact
  import (`borg_core.cmda.core -> borg_core.cmdb.core`) as broken. The composition is now proven to
  do what it claims, with command output, not just source-reading or argument.
- **Cons:** Still a two-file minimum per command, even for a trivially small one; whole-module
  granularity means `core.py` must be 100% free of I/O, no exceptions, including a single
  timestamp-generating shell call; requires configuring and maintaining TWO linter configs instead of
  one. **Confirmed, not just suspected:** `ResourceChecker`'s hardcoded internal-module allowlist
  (`domain`, `dto`, `use_cases`, `protocols`, `models`, `telemetry` — none of which match
  `core`/`shell`) means a plain `module_map` config, with no `allowed_prefixes` fix, flags a
  same-command sibling import as forbidden I/O — reproduced directly. Adding the fix
  (`allowed_prefixes = ["borg_core"]`) is REQUIRED for B to be usable at all, and that same fix is
  what removes the plugin's only (accidental) cross-command signal — which is exactly why the
  `import-linter` contract is not optional polish, it is the only thing providing real isolation once
  the plugin is configured to actually work.
- **Key tradeoffs:** Forces every command, however small, to pay a 2-file tax, now paired with a
  2-tool config tax. Correct, and now proven correct by direct test, but no longer "single knob, zero
  new config."
- **Feasibility:** High — both mechanisms, and their composition, are proven by direct spike (not
  claimed): built a real two-command scratch repo, ran both linters against a deliberately-crafted
  cross-command violation and a legitimate same-command import, confirmed the expected pass/fail
  outcome for each. No longer an open question by the time this ships.
- **Estimate:** Matches Part 3's existing C1-C7 estimate for the `recon` migration, plus ~0.5 session
  to wire the already-spiked `import-linter` config and `allowed_prefixes` fix into the real repo
  (not previously budgeted — a direct cost of the Round 2 correction, now de-risked by the spike).
- **Minimum viable version:** *`borg_core/recon/{core.py,shell.py,test_recon.py}`, `module_map`
  pointing `core.py` at Domain, `allowed_prefixes` covering intra-package imports, ship the one
  migrated command as the reference pattern. Add the `Independence` contract once a second command
  exists to actually test isolation against (same complexity-gating logic as Option F: no isolation
  contract has anything to isolate `recon` from until there is a second package).*

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

### Option G (added Round 2 per D5 Ideator; clarified Round 3 per D5 Round 2 Ideator): Dynamic/runtime I/O interception
- **What it is:** No forced `core.py`/`shell.py` file split — one file per command holds both logic
  and I/O. A pytest fixture or decorator marks specific functions as `@core`; at TEST-RUN TIME, that
  fixture monkeypatches `subprocess`, `os.system`, `socket`, `open`, etc. so any raw I/O call made
  from inside a `@core`-marked function's call stack raises immediately. Enforcement happens by
  executing the code, not by resolving a static layer label. **Clarification (Round 3):** this is
  orthogonal to per-command folders — `borg_core/recon/recon.py` can still exist as its own folder
  for feature-colocation (matching Track B's Anthropic precedent) and hold both `@core`-marked and
  ordinary functions in the SAME file; G only removes the core/shell FILE split, not the
  per-COMMAND folder structure.
- **How it works:** No new pylint checker, no `module_map`/`directory_map` config at all. A shared
  test-harness fixture (in `borg_core/testing.py` or similar) wraps forbidden built-ins for the
  duration of a marked test, and every command's test suite imports it.
- **Pros:** The one mechanism class in the full option set (A-G) that achieves TRUE function-level
  granularity — the exact ceiling Track A confirmed neither `pylint-clean-architecture` nor Ruff
  clears today — without writing a second bespoke static-analysis checker (Option C) and without any
  forced file split (Option B/A/D/F all pay a file-count or file-shape tax; this pays none). Verifies
  actual runtime behavior rather than approximating it via import-name string matching, which is
  what `ResourceChecker`'s hardcoded internal-module allowlist already does somewhat fragile-ly.
- **Cons:** Only as strong as test coverage — a `@core` function with no test exercising its
  violating path is not checked at all, unlike a static check that fires on every file regardless of
  test coverage. Does not enforce cross-command package isolation (a different property from raw-I/O
  policing) any more than `pylint-clean-architecture` does — it would need the same `import-linter`
  Independence contract addition Option B now carries for that specific concern. New test-harness
  code to write and trust, though smaller in surface than Option C's full custom checker.
- **Key tradeoffs:** Trades static, coverage-independent guarantees for finer granularity and zero
  file-structure tax. A genuinely different mechanism CLASS, not a variant of A-F.
- **Feasibility:** Medium — `unittest.mock.patch` / `monkeypatch` fixtures are well-understood,
  standard pytest patterns; no unproven new infrastructure, but unbuilt for this specific purpose.
- **Estimate:** 1-2 sessions to build and validate the shared fixture against one real command.
- **Minimum viable version:** *One `@core`-marking convention, one shared pytest fixture patching
  `subprocess.run`/`os.system`, proven against `recon`'s actual test suite before trusting it as the
  project-wide pattern.*

---


## Chosen option (Round 3, final)

The recommendation selects **Option B (revised, empirically spiked)** -- vertical-slice per command,
colocated core.py/shell.py pair, module_map + allowed_prefixes for the raw-I/O check, plus an
import-linter Independence contract for cross-command isolation (contract itself deferred until a
second command exists to isolate recon from; the mechanism is proven, not yet wired into the real
repo). Option F complexity-gate PRINCIPLE is stated in the pattern doc from day one (CI automation
deferred). Option G (dynamic/runtime I/O interception) is recorded as a deferred complementary layer,
not the primary mechanism, because its enforcement is coverage-gated rather than unconditional.
