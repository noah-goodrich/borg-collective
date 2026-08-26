# D3/D4 Draft — Options and Council (Round 3, post-second-D5-revise)

*Working draft. Not the final deliverable — no voice/scoring/epub pass yet.*

## Round 2 D5 verdict: REVISE, plus an empirical spike run in response

A second independent blind `borg-reviewer` pass (agent a1f90a89) reviewed the Round 2 choice cold
and again returned **revise**. Its three points, and how each was handled:

1. **Alpha-package disclosure (valid, adopted as-is):** `pylint-clean-architecture` is confirmed
   (reviewer checked PyPI directly) to be a single-maintainer, Alpha-status package with 4 releases,
   all from this same month, authored by the same person making this decision. This is true and was
   previously undisclosed in the option text. It is not new risk — Part 1 of this same PROJECT_PLAN
   already adopted this plugin as a dependency before this research question was ever raised — but
   the "no new bespoke tooling" framing should have named this instead of implying mature,
   independent, battle-tested tooling on both sides of the pairing. Fixed by rewording Option B's
   Pros below to disclose it plainly.
2. **"Run the two-tool spike before deciding, not after" (valid, acted on directly):** rather than
   debate this, I built the actual two-command scratch package the file admitted was still
   unverified and ran both tools against it for real. Results:
   - `pylint-clean-architecture` with only `module_map` configured: flags a legitimate SAME-command
     import (`cmda/core.py` importing its own sibling `cmda/types.py`) as forbidden I/O — confirming
     the Technical Realist's `allowed_prefixes` concern was not a hedge, it was a hard requirement.
   - Adding `allowed_prefixes = ["borg_core"]` (the fix) makes the legitimate same-command import
     pass — but **also silently permits the cross-command violation** (`cmda/core.py` importing
     `cmdb/core.py`) with zero warning, because the prefix allowlist doesn't distinguish one command
     package from another. `subprocess` is still correctly caught either way, so the fix doesn't
     disable real I/O protection, but it does disable ALL of `pylint-clean-architecture`'s
     (accidental, never-designed-in) cross-command signal.
   - `import-linter`'s `Independence` contract, configured with `borg_core.cmda` and `borg_core.cmdb`
     as members, correctly flags the exact same cross-command import
     (`borg_core.cmda.core -> borg_core.cmdb.core`) that the plugin, once made usable, misses.
   - **Conclusion, now behaviorally verified rather than assumed:** the two-tool composition is both
     necessary (plugin alone, correctly configured to be usable, provides zero cross-command
     isolation) and sufficient (import-linter catches exactly the gap) for what Option B claims.
     This directly answers both the Round 1 Critic and the Round 2 "verify before deciding" demand
     with real command output, not further argument.
3. **"G should rank above B" / missing folder+runtime-interception hybrid (heard, not adopted as
   the primary recommendation):** the reviewer's ranking doesn't engage the Pragmatist's Round 2
   counter-argument (a coverage-gated check is closer to the hope-based compliance this project's own
   headline evidence — RepoComplianceBench's 0% figure — argues against) and now that B's isolation
   gap is empirically closed rather than theoretical, the balance favors B further, not less. The
   fair part of this objection — that Option G doesn't require abandoning per-command folders, only
   the core/shell file split within them — is folded into Option G's own text below.

**Round cap.** Per this project's own bounded-termination convention (explicit stopping conditions
for retry loops, never open-ended judgment-based exit), this research caps D5 at 3 rounds total. One
more blind pass runs against this update; whatever its verdict, the Recommender's decision below is
final for this deliverable, with any remaining dissent recorded rather than chased indefinitely.

## Round 1 D5 verdict: REVISE (not upheld)

A blind `borg-reviewer` pass (agent a2d8f85d) reviewed the Round 1 choice (Option B, ungated) cold
and returned **revise**, with two objections and one missed-option flag:
1. **Critic:** Option B's claimed per-command isolation depends on `module_map` behavior Track A
   never actually confirmed — is it path-scoped or repo-global by bare filename?
2. **Auditor:** citing the Anthropic feature-organized precedent for B specifically over-claims (it
   supports A/C equally); and shipping B ungated, before F's complexity gate exists, risks exporting
   the exact forced-split anti-pattern the evidence phase warned against to the blind infoviz session.
3. **Ideator:** the option set never considered *dynamic/runtime* I/O-boundary enforcement (e.g. a
   pytest fixture that monkeypatches `subprocess`/`os`/etc. during test execution for `@core`-tagged
   functions) as a mechanism class distinct from every static-analysis option A-F.

**Direct verification, not adjudication.** Rather than debate the Critic's objection, I (the
orchestrating session) installed `pylint-clean-architecture==1.5.2` fresh into a throwaway venv and
read `layer_registry.py` and `checks/dependencies.py` directly. The objection is **confirmed true**,
and worse than stated:
- `layer_registry.py:169-171` — `module_map` resolution is `file_path.split("/")[-1]` against the
  map: **bare filename only, fully path-independent.** Every command's `core.py` resolves to the
  identical `Domain` layer label regardless of directory.
- `checks/dependencies.py:86-87` (`DependencyChecker`, W9001) — `if current_layer == imported_layer:
  return  # Intra-layer imports are OK`. Confirmed unconditional: two files that both resolve to
  `Domain` may import each other freely, with zero warning.
- **Conclusion:** `pylint-clean-architecture` provides **no cross-command isolation whatsoever**
  under `module_map` (Option B), `base_class_map` (Option A), or `directory_map` (Option D) — all
  three resolve to a bare layer name, and intra-layer imports are always allowed. The plugin only
  ever enforces "does Domain/UseCase code import a forbidden raw-I/O module," never "does this
  command's core reach into that command's core." Option B's original "Pros" claim of matching the
  Anthropic per-feature-isolation precedent was not delivered by the mechanism proposed to deliver
  it — the Critic's objection was correct, and the actual defect is more specific than the objection
  guessed (it's not "same-layer imports are typically unrestricted," it's a hardcoded, unconditional
  pass-through in this exact plugin's exact check).
- **A real fix exists and was verified, not assumed.** `import-linter` (already installed and
  inspected by Track A for a different reason) ships an **`Independence` contract**
  (`importlinter.contracts.independence`), confirmed present in the installed package and its
  docstring read directly: *"Independence contracts check that a set of modules do not depend on
  each other... even indirectly."* Unlike `pylint-clean-architecture`'s layer resolution,
  `import-linter` contracts key off **real dotted module paths**, so `borg_core.recon.*` and
  `borg_core.<other_command>.*` are distinguishable to it in a way they are not to
  `pylint-clean-architecture`. This is an existing, actively maintained tool already in the
  candidate set — not new bespoke tooling.

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

## D4: Internal Evaluation → Draft Recommendation (the council) — Round 2/3, post-D5 revise x2

**Product Strategist:** "The imitability goal hasn't changed, but the Round 2 correction sharpens it:
a blind session copying Round 1's Option B would have copied a pattern that LOOKS like it isolates
commands from each other and doesn't. That's worse than an ugly-but-honest pattern — it's a false
signal. Whatever ships now must make the isolation guarantee actually true, not just look true from
directory layout. The `import-linter` Independence contract addition is the right fix for exactly
that reason: it makes the pattern's implied promise real. Recommendation 6 (write the WHY down)
stands, unchanged, and now needs one more line: WHY two tools, not one — a future session needs that
reasoning as much as the file layout itself, per the readability audit's original finding."

**Technical Realist:** "The whole-module-purity constraint I raised in Round 1 stands unchanged, and
now there's a second hard constraint to name: `ResourceChecker`'s internal-module allowlist
(`domain`, `dto`, `use_cases`, `protocols`, `models`, `telemetry`) does not include `core` or `shell`
— confirmed directly in `checks/boundaries.py:126`. Left unconfigured, `core.py` importing anything
from `shell.py` or a shared internal type module in the same package will itself get flagged as a
forbidden import, before we even get to cross-command isolation. `allowed_prefixes` needs a
`borg_core` entry from day one, or the very first migrated command trips its own linter. This isn't
new risk introduced by Round 2 — it was always there — Round 1 just didn't surface it because Round
1 never got as far as testing the config against a real file."

**User Advocate (formal dissent):** "I want to name a real risk with just patching Option B and
moving on: we just learned that the 'no new tooling' framing was wrong, and the fix is to bolt on a
SECOND tool. That's the kind of accreting complexity this whole research exists to push back against
— Option G (dynamic/runtime I/O interception, per the D5 Ideator) is the only option in the full set
that adds NO forced file split and NO second linter config, and Constraint Decay's whole finding was
that forced structure, not enforcement itself, is what hurts correctness. I think G deserves to be
seriously weighed as the PRIMARY choice now, not filed as a future nice-to-have, precisely because
Option B just got more structurally expensive, not less."

**Pragmatist:** "Weighing the User Advocate's dissent on its merits, not dismissing it: G's real
weakness is that it's coverage-gated, not unconditional. A `@core` function's violating call is only
caught if a test actually exercises that specific path — which is structurally closer to 'hope the
tests catch it' than to a static check that fires on every file whether or not it's tested. This
project's own headline evidence (RepoComplianceBench: 0% unaided compliance) is specifically about
why hope-based enforcement fails; a coverage-dependent runtime check inherits a version of that same
weakness, even though it's mechanical once a test exists. B's two-tool combination, once correctly
configured, is unconditional — it fires on every file, tested or not. That's a real, evidence-
relevant reason to prefer B over G as the PRIMARY mechanism, not just inertia."

**Recommender:** "Ship Option B (revised): `core.py`/`shell.py` per command via `module_map`, PLUS an
`import-linter` Independence contract for cross-command isolation, PLUS an explicit `allowed_prefixes`
fix for intra-package imports — all three are now named, verified requirements, not assumptions. I
engage the User Advocate's dissent directly: Option G is a genuinely good idea and the Pragmatist's
coverage-gated objection is the correct reason to not make it the PRIMARY mechanism, but that
objection doesn't kill G as a complementary second layer — record it as a real, worthwhile future
enhancement (belt-and-suspenders on top of B), not a rejected option. On the Round 1 D5 Auditor's
second objection (shipping the ungated split risks exporting the wrong lesson to the blind infoviz
session): resolved by writing Option F's complexity-gate PRINCIPLE into the pattern doc immediately,
as a stated rule, even though the CI automation for the gate itself is deferred — a future session
reads the rule ('split once a command crosses the complexity threshold; don't split preemptively')
regardless of whether the check is automated yet. `recon` ships as `core.py`/`shell.py` because it
already clears that bar on its own merits, not because the rule was skipped. Scope for `recon`
specifically: Option B (revised) plus the stated (not-yet-automated) F principle; Option G recorded
as a deferred complementary layer; the `import-linter` contract itself is deferred until a second
command exists to actually isolate `recon` from, per the same logic Option F already established for
its own gate."

**Draft recommendation (Round 2):** Option B (revised, with `import-linter` Independence contract +
verified `allowed_prefixes` fix), F's complexity-gate principle stated in the pattern doc from day
one (automation deferred), Option G recorded as a deferred complementary runtime layer.

**Round 3 D5 verdict: UPHOLD**, with two items the reviewer explicitly sanctioned recording as open
limitations rather than blockers, since this is the capped final round: (1) the spike never tested
bare-builtin I/O (`open()`, no import statement) — checked directly afterward, confirmed as a REAL
gap: `open()` triggers only a generic style warning (`W1514`, missing encoding), not `W9004` — the
`ResourceChecker` only visits `Import`/`ImportFrom` AST nodes, never `Call` nodes, so builtin I/O
completely bypasses it. Both `pylint-clean-architecture` and `import-linter` share this blind spot,
since both are import-graph tools. This is exactly the gap Option G's runtime interception would
close (it patches `open`/`subprocess`/`os.system`/`socket` directly, not import statements) — G is
promoted from "someday" to "the concrete next spike," not because B is wrong, but because B alone
provably does not cover this case. (2) the near-term shipped plan (one command, complexity-gate
satisfied on its own merits) is what Option F's own MVP text already describes — the recommendation
is relabeled below to say so honestly instead of filing it as "B, F deferred" when the actual plan is
F's MVP realized through B's mechanism.

**Round 3 addendum (post-second-D5-revise, post-spike):** the Round 2 recommendation stands,
strengthened rather than weakened by the second review round. The alpha-package status of
`pylint-clean-architecture` is now named explicitly in Option B's Pros rather than left implicit —
a disclosure fix, not a design change, since the plugin was already a committed Part 1 dependency
before this research began. The "verify before deciding" demand was met directly: a real
two-command scratch package now proves, by command output, that (1) `pylint-clean-architecture`
alone cannot provide cross-command isolation once configured to be usable at all, and (2)
`import-linter`'s `Independence` contract catches exactly that gap. The case for ranking Option G
above B is heard and only partially adopted — G remains recorded as a deferred complementary layer,
not promoted to primary, because its coverage-gated enforcement is closer to the hope-based
compliance this project's own headline evidence (RepoComplianceBench) found fails, while B's
isolation gap is no longer theoretical, it is closed and proven. Per this deliverable's own
bounded-termination rule, this is the final D5 round regardless of its verdict; any further
dissent is recorded in §Recommendation, not chased with a fourth round.
