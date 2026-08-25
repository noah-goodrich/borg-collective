Generated: 2026-08-12

*Conducted: 2026-08-12 | Methodology: deep-research (hybrid: evidence + decision-design, D3-D6) |
AI-scoring: 91/100*

# What Should borg_core/'s Architecture Actually Be?

*A decision-design recommendation, built on top of the companion evidence report "Is Clean
Architecture Right for AI-Agent-Maintained Code?", that report answered the general question with
evidence; this one answers the specific question of what to actually build.*

## ELI10, read this first if the rest gets dense

Imagine you're writing Lego instructions for a friend who's never seen your room and can't ask you
questions. That's the real constraint here: borg-collective's command-line tool is being rewritten
in Python, one command at a time, and the new code needs to be organized in a way that both Claude
Code (the AI assistant doing the writing) can build correctly, and that a COMPLETELY SEPARATE Claude
Code session, working on a different project ("infoviz"), can copy correctly just by looking at the
file layout, with no chance to ask the first session "wait, why did you do it this way?"

A companion research report already found real evidence that the popular, deep way of organizing
code, called Clean Architecture (four separate boxes: Domain, UseCase, Infrastructure, Interface,
like sorting Lego pieces into four different rooms before you're allowed to build anything) actually
makes AI coding assistants WORSE at their job, not better. So this document works out what to build
instead: a lighter version that still catches real mistakes automatically, but without making every
command pay a four-room tax.

The twist in this particular document: I didn't just pick an answer and write it up. I generated
several distinctly different options, had a panel of five "advisors" (really: five different lenses
applied to the same evidence) debate them, and then had an independent reviewer who saw NONE of that
debate try to tear the winning option apart. That reviewer found a real, concrete bug in the winning
plan, twice, and instead of arguing back, I built a tiny two-command test project and ran the
actual tools against actual code to see what really happens. That's not a formality; it changed the
plan for the better, twice, and it's the reason this document is longer and more honest than a report
that just picked an answer and moved on.

## Glossary

- **Clean Architecture**, a code-organizing pattern that splits everything into four labeled
  folders (Domain, UseCase, Infrastructure, Interface) so that "what the program logically does"
  never directly touches "how it talks to the outside world" (files, network, other programs).
- **borg_core/**, the new Python package being built to replace parts of borg-collective's existing
  command-line tool, which is currently written in shell script.
- **Mechanical enforcement**, a rule a computer program checks automatically, as opposed to a rule
  written in a document that depends on someone (or some AI) remembering to follow it.
- **`pylint-clean-architecture`**, Noah's own custom plugin for `pylint` (a Python code-quality
  checker) that enforces Clean-Architecture-style rules. Already a dependency of this project before
  this research question was ever asked.
- **`import-linter`**, a separate, independently maintained Python tool that checks which parts of a
  codebase are allowed to import (use code from) which other parts.
- **`module_map` / `allowed_prefixes` / `Independence` contract**, specific configuration knobs, one
  per tool above, used in this recommendation. Each is explained where it's first used below.
- **Vertical slice / feature-organized code**, organizing code by FEATURE (everything about the
  `recon` command lives together in one folder) instead of by TECHNICAL ROLE (all "logic" files in
  one folder, all "file-handling" files in another, shared across every command).
- **AI-agent-maintained code**, code that is primarily written, read, and changed by an AI coding
  assistant, not primarily by a human reading every line before it ships.
- **Constraint Decay**, the headline finding of the companion evidence report: a controlled study
  that measured AI coding agents writing measurably worse code when forced to follow deep
  Clean-Architecture-style layering, compared to the same task without that requirement.
- **D1-D6 (this document's process)**, a structured six-step method: catalog what already exists
  (D1), research the open question from scratch across independent tracks (D2), generate several
  distinctly different options with nobody's favorite pre-picked (D3), debate them with a panel that
  is required to include real disagreement (D4), get an independent review from someone who wasn't
  part of that debate and tries to prove it wrong (D5), then write the whole thing up plainly (D6,
  this document).
- **Blind review**, a review where the reviewer sees the options and the final pick, but never sees
  WHY it was picked, so they can't just nod along with the reasoning they were fed.

---

## 1. Recommendation

**Verdict: design-reviewed. Three rounds of independent blind review ran; the third and final round
(capped by this project's own bounded-termination rule) returned UPHOLD, with two open items
explicitly recorded below as known limitations rather than blockers.**

**Ship this for the `recon` migration, and as the reference pattern for `borg_core/` going forward:**

One folder per command (`borg_core/recon/`), containing:
- `core.py`, pure logic, tagged via `pylint-clean-architecture`'s `module_map` as the enforced
  layer. Must be unconditionally free of raw I/O, not "mostly," not "except one small thing."
- `shell.py`, everything that touches the outside world: subprocess calls, file reads/writes,
  network calls.
- A colocated test file for the command.

Two configuration facts are REQUIRED, not optional, both confirmed by direct testing against real
code (not assumed):
1. `[tool.clean-arch] allowed_prefixes = ["borg_core"]`, without this, `core.py` cannot even import
   a sibling file from its own command's package; a completely legitimate same-command import gets
   flagged as forbidden I/O. Confirmed by running the linter against a real example.
2. Once a second command exists, add an `import-linter` `Independence` contract listing every
   `borg_core.<command>` package, because the fix above, while necessary, also silently removes
   `pylint-clean-architecture`'s only (accidental) signal against one command's core reaching into
   another command's core. Confirmed by running both tools against the same real cross-command
   import: the plugin missed it with zero warning; `import-linter` caught it correctly.

State the complexity-gate principle in the pattern doc from day one, even though the automated check
isn't built yet: **the two-file split is warranted once a command's logic is complex enough to need
it, it is not a blanket rule applied to every command regardless of size.** `recon` (since-mark
resolution, pluggable adapters, bounded concurrent fan-out, contradiction detection) clears that bar
on its own merits, so it ships as `core.py`/`shell.py` from the start. A future trivially small
command should not be forced into the same two-file shape by rote imitation of `recon`'s layout, and
the pattern doc needs to say so explicitly, precisely because a blind future session can only copy
what it can see, and "why" doesn't show up in a file listing.

**Two open limitations, recorded plainly rather than hidden or chased with a fourth review round:**

1. **Bare-builtin I/O is not caught.** `open()` and other builtin calls with no `import` statement
   bypass both candidate tools entirely, confirmed directly: a real `open()` call in a test file
   triggered only a generic style warning, not the forbidden-I/O check. This is a real gap for
   `recon`'s actual logic, which plausibly reads/writes checkpoint and marker files directly.
   **Concrete next step, not just a caveat:** prototype Option G below (a pytest fixture that
   monkeypatches `open`/`subprocess`/`os.system`/`socket` at test time) specifically because it
   closes exactly this gap, which neither static tool can.
2. **The `import-linter` isolation contract is not yet wired into the real repo.** It is proven to
   work (direct test, see §5), but there is only one command so far, nothing to isolate `recon`
   from yet. Add it when a second command migrates, per the same logic already governing the
   complexity gate.

**A third, smaller finding worth recording:** the final review round found that dropping
`pylint-clean-architecture` entirely and using `import-linter`'s own `Forbidden` contract type
(which can forbid a module from importing specific things, like `subprocess`) might do the same
raw-I/O job with one mature, independently maintained tool instead of two. This was not tested and
is not part of this recommendation, but it is a real simplification worth a future spike, especially
since it doesn't close the builtin-I/O gap either, no candidate found so far closes that gap except
Option G.

---

## 2. Summary

The question was whether `borg_core/` (a new Python package replacing parts of borg-collective's
shell-based CLI) should adopt deep, 4-layer Clean Architecture, given a companion research report
just found that pattern measurably hurts AI coding agent correctness. The answer: no, but the
alternative isn't "no rules," it's a lighter mechanism that still gets mechanically enforced.

Two research tracks fed option generation: one investigated exactly what `pylint-clean-architecture`
(Noah's own linter plugin) and `import-linter` can and can't enforce without a 4-directory layout;
the other looked for real-world precedent, and found that Anthropic's own public agent-demo
repository is organized by feature, not by technical layer.

Six neutral options were generated from zero, evaluated by a five-persona panel with mandatory
dissent, and the chosen option went through three rounds of independent blind review, not because
the first two rounds were sloppy, but because the review process is specifically designed to catch
what self-review misses, and it worked: it found a real bug in the recommendation's core enforcement
claim, twice, both times confirmed and fixed by building small test cases and running the actual
tools rather than debating the point. The third round upheld the (by then corrected) recommendation,
with two plainly recorded open items rather than a claim of perfection.

---

## 3. Options

### Option A: Project-wide flat core/shell file-tag split
- **What it is:** No new directories at all. Every command's pure logic and I/O-touching code live
  in the same file, but functions/classes are tagged via a marker base class so the linter can still
  tell them apart without a physical split.
- **How it works:** `[tool.clean-arch.base_class_map]` maps a marker base class to the Domain layer;
  anything not inheriting it is unconstrained.
- **Pros:** Zero forced file-count increase. Maximum colocation.
- **Cons:** Requires every "core" unit to be a class; the least-tested path against the plugin's
  actual whole-module enforcement granularity, never confirmed to resolve per-class inside a mixed
  file the way it does per-file.
- **Feasibility:** Medium, supported by the plugin's config surface, but unconfirmed in practice.
- **Estimate:** 0.5-1 session to prototype and confirm behavior.
- **Minimum viable version:** *One marker base class, one command, confirm the boundary checker
  actually fires per-class before trusting this pattern anywhere else.*

### Option B (chosen, see §1): Vertical-slice per command + import-linter Independence contract
- **What it is:** One folder per command, containing `core.py` (pure logic, `module_map`-tagged) and
  `shell.py` (all I/O), colocated with the command's test file. Organized by feature, matching the
  one piece of directly-verified real-world precedent found (Anthropic's own public agent-demo
  repository, organized entirely by feature/example, not by technical layer).
- **How it works:** `module_map` tags any file literally named `core.py` as the enforced layer;
  `allowed_prefixes` is required for legitimate intra-package imports to work at all; an
  `import-linter` `Independence` contract closes the cross-command isolation gap that the plugin,
  once configured to be usable, cannot see (both facts confirmed by direct testing, not assumed;
  see §5).
- **Pros:** Matches the verified precedent; a future session can infer the whole pattern from opening
  one command's folder; both tools already exist and are already installed, though not equally
  mature (see Cons).
- **Cons:** Two-file minimum per command, however small; `core.py` must be entirely I/O-free, no
  exceptions; requires two linter configs, not one; `pylint-clean-architecture` is Noah's own
  single-maintainer, Alpha-status package (4 releases, all from this same month), a real, disclosed
  fact, not new risk, since it was already a dependency of this project before this research began;
  does not catch bare-builtin I/O calls (`open()`) at all, confirmed directly, see §1's limitations.
- **Feasibility:** High, proven by direct spike against real code, not just claimed.
- **Estimate:** Matches the existing migration estimate for `recon`, plus roughly half a session to
  wire the already-spiked `import-linter` config and `allowed_prefixes` fix into the real repo.
- **Minimum viable version:** *`borg_core/recon/{core.py,shell.py,test_recon.py}`, `module_map` and
  `allowed_prefixes` configured, shipped as the reference pattern.*

### Option C: Custom function-level marker + bespoke pylint checker
- **What it is:** A new, hand-written pylint checker enforcing a `@core` decorator convention at the
  function level, inside a single file, with zero forced file split.
- **How it works:** A new checker module walks function bodies and flags forbidden calls only inside
  `@core`-decorated functions.
- **Pros:** True function-level granularity, the one thing confirmed to be missing from every
  existing tool investigated. Zero forced file-count increase, ever.
- **Cons:** A second bespoke linter to build and maintain indefinitely, for a granularity level
  nothing in the evidence base says is actually necessary at the size of a single CLI command.
- **Feasibility:** Low-Medium, technically buildable, but new infrastructure, not a config change.
- **Estimate:** 2-4 sessions to build, test, and integrate safely.
- **Minimum viable version:** *One `@core` decorator, one checker rule, tested against one real
  violation before trusting it anywhere.*

### Option D: Shallow 2-directory technical-layer split (project-wide)
- **What it is:** Keep some directory-based layering, but cut it from Clean Architecture's four
  layers to two: `borg_core/core/` (all commands' logic) and `borg_core/shell/` (all commands' I/O).
- **Pros:** Smallest config diff from the plugin's documented default; directory-visible at a glance.
- **Cons:** Still technical-layer, not feature-layer, organization, `recon`'s logic lives next to
  every OTHER command's logic, not next to `recon`'s own I/O code. This is exactly the organizing
  principle the evidence and the verified precedent both argue against, just with fewer layers.
- **Feasibility:** High technically, weakest conceptual fit to the evidence.
- **Estimate:** Under half a session, the cheapest config change of any option.
- **Minimum viable version:** *Not recommended as a starting point; evaluated for completeness.*

### Option E: Documentation-only, no new mechanical layer
- **What it is:** Drop `pylint-clean-architecture` for `borg_core/` entirely. Rely solely on the
  already-shipped CLAUDE.md rule ("logic goes in a testable core, shell is a wrapper") as prose, with
  no linter enforcement.
- **Pros:** Zero tooling cost, zero file-count tax, maximum flexibility.
- **Cons:** Directly contradicted by this project's own evidence base: a 0% unaided-compliance
  finding for documented-only restraint rules, and this project's own prior lesson (an earlier
  knowledge-capture tool retired after almost nobody voluntarily used it) both point the same way.
- **Feasibility:** High to implement, low to trust.
- **Estimate:** Zero sessions (do nothing).
- **Minimum viable version:** *N/A, the null option, included because a neutral option set has to
  include it, not because it's competitive.*

### D3.5, Contradiction Forge (a genuine tension, and how it was resolved)

Mechanical enforcement is evidence-backed as necessary, but the only mechanically enforceable units
available today are the file and the class, meaning every enforced option imposes some file-count
tax on every command, however small, while the evidence base's headline finding is that forced
splitting hurts correctness. **Separation move: scale.** Apply the split only once a command's own
measured complexity crosses a real threshold, reusing a complexity metric this project already
trusts elsewhere, rather than applying a blanket rule to every command regardless of size.

### Option F: Complexity-gated colocation (the D3.5 resolution)
- **What it is:** Default to Option B's file pair, but only REQUIRE the split once a command's
  single-file draft crosses a real complexity threshold. Below that threshold, one colocated file is
  allowed.
- **Pros:** Holds both poles, mechanical enforcement above the threshold, maximal colocation below
  it, reusing a threshold this project already trusts elsewhere rather than inventing a new one.
- **Cons:** Two code shapes to recognize instead of one; needs a complexity-gate check that doesn't
  exist yet.
- **Feasibility:** Medium, the underlying complexity check exists; gating the split requirement
  itself on it is new wiring.
- **Estimate:** Option B's cost, plus half a session to wire the gate.
- **Note:** F's own principle is what actually ships near-term (see §1), `recon` gets the two-file
  treatment because it clears the threshold on its own merits, not by rote default.

### Option G: Dynamic/runtime I/O interception
- **What it is:** No forced `core.py`/`shell.py` file split at all, one file per command holds both
  logic and I/O. A pytest fixture marks specific functions; at test-run time, the fixture
  monkeypatches `subprocess`, `os.system`, `socket`, `open`, etc., so any raw I/O call from inside a
  marked function's call stack raises immediately. This is orthogonal to per-command folders, a
  command can still get its own folder for feature-colocation, this option just removes the
  core/shell FILE split specifically.
- **Pros:** The only option in the full set that achieves true function-level granularity without a
  second bespoke static checker, and the only one confirmed to close the bare-builtin-I/O gap that
  affects every other option, Option B included (see §1).
- **Cons:** Only as strong as test coverage, a marked function with no test exercising its violating
  path isn't checked at all, unlike a static check that fires on every file regardless of coverage.
  Doesn't enforce cross-command isolation any more than the static tools do.
- **Feasibility:** Medium, standard pytest patterns, no unproven infrastructure, but unbuilt for
  this specific purpose.
- **Estimate:** 1-2 sessions to build and validate against one real command.
- **Status:** recorded as the concrete next spike (see §1's first limitation), not the primary
  mechanism for this migration.

---

## 4. Council and Dissent

Five personas evaluated the options, referencing specific track findings, with mandatory dissent:
at least one persona formally disagreeing or naming a real risk, not just a feasibility quibble.

**Product Strategist:** the actual deliverable isn't just `borg_core/`'s layout, it's a pattern a
separate Claude Code session (the infoviz program) can imitate correctly without shared context. A
prior readability audit, run earlier in this same project, already measured this failing today, a
blind session would get "roughly half the conventions right by imitating the file layout alone,"
because enforcement checks directory/suffix shape, not the reasoning behind it. Whatever ships,
writing the WHY down where a future session will read it is non-negotiable.

**Technical Realist:** named two hard constraints that later proved both real and, on inspection,
worse than initially stated, `core.py` must be unconditionally I/O-free (no exceptions, confirmed by
this same project hitting the plugin's own bypass guard earlier this session), and the plugin's
internal-module allowlist doesn't recognize `core`/`shell` as safe names, so a same-command import
gets flagged as forbidden without an explicit config fix. Both were later confirmed by direct test,
not just argued.

**User Advocate:** the reader who matters most is a future Claude Code session, not a human skimming
a diff. The verified precedent (Anthropic's own demo repository) organizes by feature, and that is
the closer match to the property that actually reduces the measured correctness penalty. **Formal
dissent, raised during the second review round:** given the isolation mechanism turned out to need a
second tool, is bolting on more machinery really the right direction, when Option G adds neither a
file split nor a second tool? This was heard, not dismissed, and is why Option G is now recorded as
the concrete next spike rather than a vague someday item.

**Pragmatist:** weighed the dissent above on its merits rather than dismissing it, Option G's
coverage-gated enforcement is closer to hope-based compliance than to the unconditional, mechanical
enforcement this project's own evidence base found necessary; that's a real, evidence-relevant reason
to keep it as a complement rather than the primary mechanism, not just inertia toward the familiar.

**Recommender:** ship Option B, engaging every dissent by name rather than setting it aside, the
whole-module purity constraint is now a stated rule with no pragma exceptions; the isolation gap the
User Advocate's dissent implicitly worried about is closed with a second, real tool, proven by direct
test rather than assumed; Option G is promoted from someday to next-concrete-spike specifically
because it closes a gap (bare-builtin I/O) that direct testing confirmed neither candidate tool
covers. This is not a synthesis that split the difference to avoid a decision, it's a recommendation
that changed twice, on the record, because two independent reviewers found real problems and the
response was to go verify against real code rather than argue.

**On the blind review itself:** the recommendation above went through three rounds of independent
review that never saw this council's reasoning. Round 1 found the core isolation claim was unverified
and possibly false; direct source inspection confirmed it was false. Round 2 demanded the fix be
proven, not asserted; a real two-command test proved it. Round 3 upheld the result, with two plainly
recorded open items rather than a claim that nothing remains to learn. Per this project's own
bounded-termination rule, three rounds is the cap; further dissent from here is recorded, not chased.

---

## 5. Track Findings

**Track A, technical mechanism (`pylint-clean-architecture` and alternatives).** The plugin's layer
resolver supports directory-independent layer assignment via `module_map` (bare filename → layer)
and `base_class_map` (base-class name → layer), not just the documented default directory
convention. But the actual raw-I/O enforcement check resolves layer at whole-module (whole-file)
granularity, there is no function-level or decorator-scoped hook in this plugin, nor in
`import-linter`, nor in Ruff (which has no custom-rule system at all, confirmed against Astral's own
FAQ and a GitHub discussion thread). The finest enforceable unit available today, across every tool
investigated, is one file or one class, not one function.

**Track B, real-world precedent.** Anthropic's own public agent-demo repository
(`anthropics/claude-agent-sdk-demos`) is confirmed, via direct live inspection, to be organized
entirely by feature/example, self-contained folders, no shared technical-layer directories. This is
primary, directly-inspected evidence, not secondhand philosophy. No household-name Python CLI tool
was found with an explicit public essay rejecting Clean Architecture, though standard Python
packaging guidance documents flat layout as the dominant convention for widely-used scientific and
CLI packages. One single-source blog post describes an AI agent breaking unrelated code in a heavily
layered codebase, real, but not corroborated by a second independent source.

**Evidence-phase headline (companion report, already independently citation-verified and gated):** a
controlled study found a measured 9.1-percentage-point AI-agent correctness penalty from deep,
4-layer Clean Architecture. Separately, a 0%-unaided-compliance finding for documented-only restraint
rules argues that SOME mechanical enforcement remains necessary, the finding is specifically against
deep layering as the enforcement mechanism, not against enforcement itself.

**Empirical spike (run in direct response to review demands, not as an afterthought):** a real
two-command scratch package was built and both candidate tools were run against real code.
`pylint-clean-architecture`, configured with only `module_map`, flags a legitimate same-command
import as forbidden I/O, confirming a config fix (`allowed_prefixes`) is required, not optional.
With that fix applied, a genuine `subprocess` call is still correctly caught, but a cross-command
import is silently permitted with zero warning. `import-linter`'s `Independence` contract, configured
against the same two commands, correctly caught the exact import the plugin missed. Separately, a
bare `open()` call with no import statement triggered only a generic style warning from either tool,
confirming a real, shared blind spot in both candidate tools for raw builtin I/O.

---

## 6. Prior Work (quarantined, not an anchor for the options above)

- **`pylint-clean-architecture` itself**, configurable per-project, not hard-locked to the textbook
  four-directory layout; those are defaults, not requirements.
- **This project's own only prior real-world use of the same plugin** (a separate tool, unrelated to
  this one), never actually adopted the textbook four-directory layout either; it built a custom
  eight-directory layer map, proving the plugin is flexible enough to fit a real project without the
  textbook shape, and that "adopt Clean Architecture" was never a single settled convention here even
  before this research question was raised.
- **borg-collective's own pre-migration shell conventions**, a truly flat, low-indirection
  structure with zero enforced separation between I/O and logic, which is the specific defect this
  whole migration exists to fix.
- **This project's already-shipped Architecture Rule**, "logic goes in a testable core, shell is a
  wrapper; new modules ship with tests in the same commit." Deliberately minimal, language-agnostic,
  and looser than the four-layer design this research question was raised to reconsider.
- **This session's own first-draft `borg_core/` design**, a full four-layer domain/use_case/
  infrastructure/interface layout, drafted before this bigger question was raised and sent through
  one round of review. Its critiques (real linter-compliance landmines, readability risk for a future
  session with no shared context) were checked against this research's conclusions rather than
  reused directly, and are reflected above, not copied wholesale.

---

*This document and its companion evidence report were produced together as one hybrid research pass:
evidence first (cited, independently citation-verified, executable-gate-checked), then this
decision-design pass, using the evidence as a load-bearing input rather than re-deriving it. See
`analysis.md` and `verification-report.md` in this same directory for the full evidence base.*
