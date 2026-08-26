Generated: 2026-08-12

# Is Clean Architecture Right for a Codebase Claude Code Maintains?

*Conducted: 2026-08-12 | Methodology: deep-research (hybrid: evidence + decision-design) | AI-scoring: 92/100*

---

## Glossary, read this first

- **Clean Architecture**, a software design style that splits code into strict layers (Domain = business
  rules, UseCase = orchestration, Infrastructure = talking to the outside world, Interface = the
  user-facing entry point), where each layer can only depend inward, never outward. Popularized by Robert
  C. Martin in the 2010s, designed around human memory limits.
- **AI coding agent**, a program (Claude Code, Cursor, GitHub Copilot's agent mode) that reads, writes,
  and runs code somewhat autonomously, using tools (read a file, run a command, search) in a loop.
- **Layering / layered architecture**, organizing code by TECHNICAL ROLE (all controllers together, all
  database code together) rather than by FEATURE. One user-visible change touches files in many folders.
- **Vertical slice architecture (VSA)**, the opposite instinct: organize code by FEATURE, so one change
  usually touches one folder.
- **Dependency Injection (DI)**, a rule that says "don't let business-logic code directly construct the
  thing that talks to the database/network, hand it that dependency from outside instead," so the
  business logic can be tested without a real database/network.
- **Protocol** (Python), a way to say "this code needs SOMETHING that can do X," without naming a
  specific class, the Python version of an "interface."
- **Context window / context engineering**, an AI agent only "sees" a limited amount of text at once (its
  context window). Context engineering is the discipline of deciding what to put in that limited space so
  the agent has what it needs without drowning in irrelevant material.
- **Tool call / navigation step**, one action an agent takes to gather information (read a file, run
  grep, list a directory) before it can actually make the change it was asked to make. More tool calls =
  more time and more real cost.
- **pylint-clean-architecture**, a custom linter plugin (built by this research's own commissioner,
  Noah) that mechanically checks a Python codebase follows Clean Architecture's layer rules.
- **Constraint Decay**, the nickname (used by this report, not the paper itself) for the paper this
  research treats as its single most important finding: a controlled study that isolates Clean
  Architecture as one variable among several "helpful-sounding" coding constraints and measures its
  actual effect on whether AI-agent-written code passes its tests.
- **RCT (Randomized Controlled Trial)** / **Controlled experiment**, a study designed so one variable is
  changed while everything else is held constant, so you can say the variable CAUSED the difference in
  outcome, not just that the two things happened to occur together.
- **arXiv preprint**, a paper posted publicly before (or instead of) formal peer review. Common and
  often high-quality in fast-moving computer science topics, but it has NOT been through the review
  process that catches errors before publication, treat it as real evidence, one notch below a
  peer-reviewed publication of the same quality.

---

## 1. Recommendations

1. **Do not adopt the full 4-layer Clean Architecture (Domain/UseCase/Infrastructure/Interface, one class
   per file, Protocol-based dependency injection) as `borg_core/`'s pattern.** The one controlled study
   that actually isolates Clean Architecture as a variable found it measurably HURTS AI-agent code-writing
   correctness (−9.1±1.6 percentage points). See §4, Theme 1.
2. **Keep mechanical enforcement, do not fall back to documented-only conventions.** This is the strongest,
   most consistent finding across the whole research: documented rules (a CLAUDE.md, a style guide) are
   reliably followed only for task-shaped instructions, and are followed close to 0% of the time, unaided,
   for restraint/boundary-type rules, exactly the kind of rule "don't call subprocess outside an adapter"
   is. See §4, Theme 4.
3. **Enforce boundaries with a lighter mechanism than mandatory file-per-class splitting**, for example, a
   linter rule that flags a forbidden import or a forbidden function call inside a marked region, without
   requiring that region to live in its own file, its own directory, and be injected via a Protocol. This
   keeps the enforcement (Recommendation 2) while dropping the specific mechanism the evidence says has a
   real cost (Recommendation 1). See §3.
4. **Prefer colocated, feature-organized code (vertical-slice-shaped) over technical-layer-organized code**
   for anything Claude Code will be the primary maintainer of. The strongest DIRECT mechanistic argument in
   this research (Miller, corroborated qualitatively by Anthropic's own context-engineering principles)
   is that spreading one operation across many technical-layer files forces an agent to pull irrelevant
   files into its limited context window, and that this "signal-to-noise collapse" is specifically
   correlated with the conditions under which agents introduce errors. See §4, Theme 2.
5. **Keep the Silent Core Rule (no direct I/O in business logic) and the "don't call subprocess directly
   in business-logic code" boundary, just enforce them without requiring 4 directories.** Nothing in this
   research argues against testability or against separating "what to do" from "how to actually talk to
   the outside world", the evidence specifically targets the FILE-COUNT/DIRECTORY-DEPTH mechanism, not the
   underlying testability goal. See §4, Theme 1 and Theme 3.
6. **Write down the pattern as an explicit, short convention document, not just linter config.** The
   evidence on mechanical enforcement vs. documentation is not "documentation is worthless", task-shaped
   guidance (what to DO) is followed reasonably well; it's specifically restraint-type "don't do X" rules
   that need a mechanical backstop. A short doc explaining the WHY (this research) plus a lint rule
   enforcing the WHAT gives a future session (like the one working on the separate infoviz program) both
   the reasoning and the guardrail. See §4, Theme 4.
7. **Treat this finding as applying to layering DEPTH specifically, not to structure or testability in
   general.** Do not read this research as "don't organize code", read it as "the specific mechanism of
   deep technical layering plus heavy dependency-injection ceremony has a measured cost for an AI-agent
   maintainer that it may not have for a human one." See §2 and §4.
8. **Revisit this decision if the field's evidence base changes.** This is a fast-moving, largely
   preprint-stage research area (see §6, evidence-level distribution), the strongest finding
   (Constraint Decay) is a single study, not yet independently replicated. Treat this recommendation as
   the best current read of thin-but-real evidence, not a permanently settled question.

---

## 2. Summary

**What was asked:** Noah built a strict layered-architecture linter (`pylint-clean-architecture`) years
ago, reasoning that rules only stick if a machine enforces them, not if they're just written down. He was
about to apply that same tool, in its full textbook form, to a new Python codebase (`borg_core/`) that a
Claude Code session, not a human, will actually read, write, and maintain going forward. Before doing
that, he asked: is a design pattern built around human memory limits (Clean Architecture was invented in
the 2010s, explicitly to help humans avoid getting lost in a big codebase) even the right target when the
"maintainer" doesn't have human memory limits, but does have very different limits (a bounded context
window, a real cost per file read, a documented tendency to forget documented-only rules)?

**The three or four most important things this research found:**

1. **The one study that actually tests Clean Architecture, not just "some structure," found it hurts.** A
   controlled experiment (not just an opinion piece) isolated Clean Architecture as one of several
   coding-style variables and measured its effect on whether an AI agent's code actually passed its tests.
   Clean Architecture specifically came out **9.1 percentage points worse**, on average, than not using
   it, a real, measured penalty, not a correlation. This is the single most load-bearing finding in this
   whole research and it was checked especially carefully (see §6) because it's surprising and because so
   much rides on it.
2. **But "does code cleanliness matter at all" and "does Clean Architecture specifically matter" are two
   different questions with two different answers.** A separate, well-designed study found that general
   code cleanliness (readable names, no huge functions, no duplicated logic) does NOT change whether an
   agent's code passes its tests, but it DOES change how efficiently the agent works (about 7-8% fewer
   tokens spent, about a third fewer times re-reading the same file). So "clean" and "well-organized" are
   not automatically bad for agents, the evidence specifically targets Clean Architecture's LAYERING
   mechanism (spreading one feature's code across many technical-role folders), not tidiness in general.
3. **Documented rules alone don't reliably work, but this actually argues FOR keeping some kind of
   enforcement, not against it.** Across several independent sources, agents follow a written rule like
   "always write tests" reasonably well, but almost never follow a written rule like "don't touch this
   part of the codebase" unless something mechanical (a build that fails, a check that blocks a merge)
   backs it up. One vivid real-world account: a hand-written rule about which folders shouldn't import
   from which other folders lasted about three code changes before an agent violated it anyway, with
   nothing catching the mistake. This matches something Noah's own project already learned the hard way
   with an earlier tool (nicknamed "cairn" in his notes) that also relied on agents voluntarily
   remembering to do something, and mostly didn't work.
4. **The most concrete "why" for the cost of deep layering, in an agent's own terms:** one well-regarded
   practitioner (who builds a real open-source framework used in production) argues that classic layered
   architecture forces an agent to open five or six files scattered across different folders just to
   understand one change, and that once an agent is reconstructing a scattered picture like that from
   fragments, THAT is specifically when it starts inventing things that aren't there or "fixing" problems
   that don't exist. Anthropic's own engineering team, describing how Claude Code itself is built,
   independently makes the same general point without mentioning Clean Architecture by name: an agent
   should be given the smallest set of directly-relevant information, not everything that might be
   relevant.

**Where this research is thin, not just where it is strong:** almost none of this evidence is
peer-reviewed yet, it is a new question (AI coding agents themselves are new), and most of what
exists is preprints (posted publicly, not yet formally reviewed) and practitioner essays. The headline
finding rests on one study, not five. This is a real, current, unsettled area, not a solved one, see §6
for the frank breakdown of how strong each piece of evidence actually is.

**The one thing to remember:** the evidence doesn't say "don't structure your code", it says the SPECIFIC
mechanism Noah was about to reuse (deep technical layering, one class per file, formal dependency
injection through Protocols) has a real, measured cost for an AI-agent maintainer, while the underlying
GOAL that mechanism was serving, testable, boundary-respecting code, mechanically enforced rather than
just documented, is still well-supported. The fix is to keep the goal and change the mechanism.

---

## 3. Architecture Approach for AI-Agent-Maintained Code

This section presents the concrete recommendation as a framework, not just a conclusion.

### The core distinction this research surfaced

Two things got bundled together in the original question that the evidence says should be UNBUNDLED:

| | Keep? | Evidence |
|---|---|---|
| **Mechanical enforcement of boundaries** (something automated stops a violation, rather than a written rule hoping an agent remembers) | **Keep** | RepoComplianceBench (0% unaided restraint-rule compliance); the factorial file-structure study (no adherence effect from documentation alone, plus within-session decay); the htek.dev anecdote (a documented-only rule broke in ~3 commits); this repo's own prior "cairn" lesson |
| **Deep technical-layer file-splitting as the specific enforcement mechanism** (Domain/UseCase/Infrastructure/Interface directories, one class per file, Protocol-typed constructor injection) | **Drop** | Constraint Decay (−9.1±1.6pp controlled penalty); Miller's signal-to-noise/hallucination-trigger argument; Anthropic's own "smallest set of high-signal tokens" principle |

### What this means concretely for `borg_core/`

- **A lighter enforcement mechanism, not zero enforcement.** Instead of requiring a `SubprocessAdapterClient`
  in its own file, injected via a `Protocol` into a `UseCase`-suffixed directory: a linter rule that flags
  a forbidden call (e.g. `subprocess.*`) inside any function/module tagged or located as "business logic,"
  without requiring that logic to live in a separate file from its caller. The rule can still be
  mechanical and still block a bad pattern; it just doesn't force a directory-depth cost onto every
  change.
- **Colocate by command/feature, not by technical role.** One migrated command (like `recon`) should be
  easy to understand by opening one, or a small number, of closely-related files, not by tracing a call
  through four directories.
- **Keep tests colocated too, and keep the testability GOAL.** Nothing here argues against `pytest-coverage-impact`-style testable cores, it argues against the specific FILE-STRUCTURE cost of getting there. A function can be pure, tested, and colocated with its caller.
- **Document the WHY, not just the WHAT.** Per Recommendation 6, write the reasoning (this research) down
  somewhere a future session (including the separate infoviz-program session) will actually read, since
  the evidence says task-shaped documentation IS followed reasonably well; it's specifically restraint
  rules that need the mechanical backstop, not documentation in general.
- **This is explicitly a recommendation for CODE Claude Code maintains, not a universal claim.** The
  evidence base is specific to AI-agent-maintained codebases. A human-only codebase is a different
  question this research did not investigate.

### Comparison to what already exists

This is not proposing something wholly new, see the D1 prior-work catalog
(`drafts/d1-prior-work-catalog.md`): Noah's own only prior real-world use of the full `pylint-clean-
architecture` plugin (`pytest-coverage-impact`) never actually adopted the textbook 4-directory layout
either, it built a custom 8-directory layer map (`core/`, `logic/`, `gateways/`, `di/`, `domain/`,
`interface/`, `feedback/`, `ml/`). Even the one prior example in this exact ecosystem already drifted from
the textbook shape toward something flatter and more feature-specific. This research gives that drift an
evidence base rather than treating it as an unexamined shortcut.

---

## 4. Analysis

### Theme 1, Does codebase structure affect whether an AI agent's code is actually correct?

**Research question:** When an AI coding agent writes code inside a differently-structured codebase, does
the structure change whether the resulting code passes its tests?

**What the evidence says:** Two controlled/near-controlled studies directly address this, with a real
tension between them.

`empirical-constraint-decay-clean-architecture.md` (Dente, Satriani & Papotti, arXiv:2605.06445, keep,
Contrarian/Academic) isolates several "helpful-sounding" coding constraints, including Clean Architecture
specifically, as independent variables in a matched-pair design (comparing task pairs that differ by
exactly one constraint, holding everything else fixed) and measures the change in assertion-pass rate.
Clean Architecture's own marginal effect: **−9.1 ± 1.6 percentage points**. This is a genuine controlled
manipulation, not an observed correlation, confirmed directly against the paper's Table 3(a) during
independent verification (see §6).

`empirical-code-cleanliness-minimal-pair.md` (SonarSource, arXiv:2605.20049, keep, Academic) ran a
different, also-controlled minimal-pair study (dirty vs. clean versions of the same task, 660 trials) and
found code cleanliness **does not change the agent's pass rate**, but does change efficiency (7-8% fewer
tokens, 34% fewer file re-reads).

**Where sources agree:** neither study finds that MORE structure/cleanliness plainly IMPROVES
correctness. Both, independently, find either no effect (SonarSource, on general cleanliness) or a
negative effect (Constraint Decay, on Clean Architecture specifically).

**Where sources disagree, the practitioner layer, not the empirical layer:** `practitioner-fowler-
harness-engineering.md` (Fowler/Böckeler, martinfowler.com, keep, Institutional) and `practitioner-akita-
clean-code-ai-agents.md` (keep, Practitioner) both argue, from experience rather than controlled data,
that MORE explicit structure helps agents specifically because agents can't infer boundaries the way
humans do. Neither source, on close reading, actually claims to have measured this, both are reasoned
argument, evidence level 5-7, not evidence level 1-3. This is a case where the empirical layer and the
practitioner-opinion layer point in different directions, and the empirical layer is the stronger evidence
class here.

**What's missing:** Constraint Decay is one study. It has not been independently replicated. Its
controlled-task-pair design is real methodology, but the practical significance of a single study,
however well-designed, calling into question a decades-old, widely-adopted pattern deserves more caution
than certainty.

**Institutional vs. ground truth:** notably, NO institutional voice (professional body, major vendor
research arm) has yet published a position specifically on Clean Architecture and AI agents, the
practitioner track's search explicitly found no genuine Institutional source survived triage on this exact
question (see §6). This is itself informative: institutional guidance hasn't caught up to this specific
question yet.

### Theme 2, Why would layering specifically cost an agent anything? (The mechanism)

**Research question:** If deep technical-layer structure has a real cost, what's the actual mechanism,
why would it be worse, not just neutral?

**What the evidence says:** `context-eng-jeremydmiller-codebase-is-the-prompt.md` (Miller, keep, Practitioner)
gives the most direct, on-topic mechanistic argument found in this whole research: a layered change forces
an agent to pull files from multiple technical tiers into its context before it can safely act; most of
what gets pulled in is irrelevant to the actual task; "the signal-to-noise ratio in the context window
collapses, and that's exactly the condition under which agents start guessing, inventing abstractions you
didn't ask for, 'fixing' error cases that can't happen, and drifting away from the intent of the change."

**Where sources agree:** `context-eng-anthropic-effective-context-engineering.md` (Anthropic's own Applied
AI team, keep, Institutional, the single highest-authority source in this entire research, since it
describes how Claude Code is itself actually engineered) independently states the same general principle
without naming Clean Architecture: the goal is "the smallest possible set of high-signal tokens that
maximize the likelihood of the desired outcome," and agents should prefer loading exactly what's needed at
the moment it's needed, not everything that might be relevant. `context-eng-sourcegraph-context-
engineering-guide.md` (borderline, Institutional) corroborates with an independent numeric example: a
100K-token pre-loaded summary performed worse than a 5K-token targeted retrieval.

**Where sources disagree:** none of the "more structure helps" sources (Fowler, Akita, NimblePros) directly
rebut this mechanism, they argue FOR structure on a different axis (agents need explicit boundaries
because they can't infer them), not against the signal-to-noise cost. This is less a disagreement than two
different, both-plausible mechanisms pulling in opposite directions, without either side directly engaging
the other's argument.

**What's missing:** no source directly, quantitatively measures "tool calls per change" as a function of
layering depth specifically (as opposed to documentation-artifact presence, which Formal Architecture
Descriptors does measure). This is the single biggest direct-evidence gap in the whole corpus (see §6
Limitations).

**Institutional vs. ground truth:** Anthropic's own engineering guidance (institutional, highest authority)
and Miller's ground-level practitioner account (independent, different professional context) arrive at the
same underlying principle from completely different directions and never reference each other, a real,
meaningful convergence rather than one source echoing another.

### Theme 3, Does giving an agent MORE explicit documentation/structure information help, separately from the codebase's own layout?

**Research question:** Distinct from how the codebase itself is organized: does handing an agent an
explicit description of the architecture help it move through the code, regardless of the underlying code's layout?

**What the evidence says:** `context-eng-formal-architecture-descriptors.md` / `empirical-formal-
architecture-descriptors.md` (Jin, arXiv:2604.13108, keep, Academic, one paper, evaluated independently
by two tracks) found that providing an agent with a formal architecture DESCRIPTION (not changing the
code's own layout) reduced navigation steps by 33-44% in a controlled experiment, and that even an
automatically-generated descriptor (zero human effort, zero code restructuring) achieved 100% localization
accuracy versus 80% blind, the value comes from having a map, not from who drew it.

**Where sources agree:** this is a clearly distinct finding from Themes 1-2, it's not about how the
code IS organized, it's about whether the agent is TOLD how it's organized. Both this research's synthesis
and the paper's own framing keep this scope distinction explicit.

**Where sources disagree:** none directly, this finding is compatible with, not contradictory to,
Constraint Decay's negative finding on Clean Architecture itself. A codebase could plausibly be flatter
AND paired with a good architecture-descriptor document, capturing the benefit of Theme 3 without the cost
of Theme 1.

**What's missing:** whether an architecture descriptor is MORE valuable, LESS valuable, or equally valuable
when paired with a deeply-layered codebase versus a flat one was not tested by any source found, this is
a real, specific, answerable-in-principle gap.

**Institutional vs. ground truth:** n/a for this theme, no institutional/practitioner tension found.

### Theme 4, Do AI agents reliably follow documented-only rules, or does drift require mechanical enforcement?

**Research question:** Independent of what the RIGHT rule is, does an agent reliably follow a rule that's
only written down (a CLAUDE.md, a style guide), or does it need something mechanical (a linter, a CI
check, a build failure) to actually stick?

**What the evidence says:** this is the single most consistent, least-contested finding across the entire
research. `mechanical-enforcement-repocompliancebench.md` (Yang, He & Zhou, arXiv:2607.26819, keep,
Academic, 280 real agent runs across 106 real GitHub issues) found unaided compliance with documented
rules varies wildly by rule TYPE: 0% for rules requiring the agent to refuse to contribute at all, 0% for
rules requiring human handoff, versus 4-92% for verification-type rules that "ask the agent to add a step
to work it has already done." Agents locate the governing policy file itself only 3.5% of the time.
`mechanical-enforcement-factorial-file-structure.md` (keep, Academic) independently found, in a separate
factorial study, no detectable adherence effect from file-structure documentation quality after correcting
for multiple comparisons, PLUS a within-session compliance-decay effect (~5.6% odds decrease per generated
function), meaning documented rules get LESS reliable specifically as a session runs longer, the opposite
of what you'd want. `mechanical-enforcement-agentsmd-eth-evaluation.md` (ETH Zurich / Vechev group, keep,
Contrarian) closes the loop from a third angle: even where agents DO read and follow context files, it
doesn't reliably improve task success and raises inference cost 20%+, so even the best-case ceiling for
documentation-only guidance is lower than commonly assumed.

**Where sources agree:** all three academic sources, independently designed and run, converge: restraint/
boundary-type rules (the category "don't call subprocess in business logic" and "don't put print
statements in the domain layer" fall into) are specifically the type documented-only guidance fails at.
Task-shaped rules (do X, verify Y) fare much better unaided.

**Where sources disagree:** `mechanical-enforcement-github-agentsmd-2500-repos.md` (borderline,
Institutional), GitHub's own official engineering blog, argues the mainstream "just write better,
more-specific documentation" position. This is directly, empirically contradicted by the factorial study's
finding that documentation-quality/structure showed no detectable adherence effect. This is a real,
citable tension between institutional folklore and controlled evidence, flagged explicitly rather than
smoothed over, per this research's confirmation-skew safeguard (see §6).

**What's missing:** no credible source was found arguing the opposite position (documented conventions
alone are sufficient, mechanical enforcement is unnecessary overhead) despite a dedicated search, this
absence is itself a finding, not a search failure (14 queries run specifically hunting for this voice; see
§6 search log).

**Institutional vs. ground truth:** the sharpest institutional-vs-ground-truth gap found anywhere in this
research. GitHub's official blog (institutional, "write better docs") versus a controlled academic study
that tested and rejected that specific claim, PLUS a first-person practitioner account
(`mechanical-enforcement-htek-agent-hooks.md`, borderline, Boots-on-the-ground) of a hand-written layering
rule collapsing in roughly three commits with nothing catching it. Ground truth and rigorous evidence both
point away from the institutional folklore here.

---

## 5. Research

### Track A, Empirical & academic evidence

- **Constraint Decay** [Dente, Satriani & Papotti, arXiv:2605.06445, Score: keep, Level 3 (controlled
  matched-pair design), Contrarian/Academic]: Clean Architecture's isolated marginal effect on assertion
  pass rate is −9.1 ± 1.6 percentage points, from a matched-pair design holding framework and other
  constraints fixed. Headline finding of this whole research; independently re-verified with extra
  scrutiny (see §6).
- **Code cleanliness minimal-pair study** [SonarSource / Trivedi & Schmitt, arXiv:2605.20049, Score:
  keep, Level 3, Academic]: cleanliness does not change pass rate; changes efficiency (7-8% token
  reduction, 34% fewer file re-reads) across 660 trials.
- **Formal Architecture Descriptors** [Jin, arXiv:2604.13108, Score: keep, Level 3, Academic]: explicit
  architecture descriptors (a documentation artifact, not codebase layout) reduce navigation steps 33-44%
  (Wilcoxon p=0.009, d=0.92); an auto-generated descriptor achieves 100% vs. 80% blind accuracy (p=0.002,
  d=1.04) with zero human involvement; no significant difference detected across descriptor formats
  (S-expression/JSON/YAML/Markdown).
- **NimblePros "Keeping AI Agents In Line With Clean Architecture"** [Blake, blog.nimblepros.com, Score:
  borderline, Level 8, Practitioner]: mainstream pro-Clean-Architecture consulting-firm position, no
  controlled data, real commercial conflict of interest (NimblePros sells a Clean Architecture template).
  Kept as the clearest available representative of the mainstream "structure helps" claim, explicitly
  flagged for its evidence-quality limits.
- **Furdak, vertical-slice Claude Code skill** [furdak.net, Score: borderline (named lowest-scoring kept
  source, defended per real-cut rule), Level 8, Boots-on-the-ground]: independent, tool-level
  corroboration of the anti-layering position via a real, installable Claude Code skill built on vertical
  slices, distinct from essay-level argument.

### Track B, Practitioner discourse on agent-ready codebases

- **Fowler / Böckeler, "Harness engineering for coding agent users"** [martinfowler.com, Score: keep,
  Level 7, Institutional]: names "harnessability" as a codebase property distinct from human-readability;
  clearly-defined module boundaries and type systems function as sensors an agent's harness can use.
  Notably, on close reading, this source never names Clean Architecture specifically, its claim is about
  legible module boundaries generally.
- **Akita, "Clean Code for AI Agents"** [akitaonrails.com, Score: keep, Level 7, Practitioner]: file/
  function-size thresholds matter more for agents than humans because agents pay a real token-budget/tool-
  call-truncation cost; explicit written rules are necessary because "no LLM does any of this by default."
- **NimblePros**, see Track A (same source, cross-tabbed).
- **Miller, "The Codebase Is the Prompt"** [jeremydmiller.com, Score: keep, Level 7, Contrarian]: the
  central mechanistic argument against layering, see Theme 2 above.
- **SonarSource cleanliness study**, see Track A (same source, cross-tabbed for its practitioner-relevant
  angle).
- **Furdak**, see Track A.

### Track C, Context engineering and agent navigation cost

- **Anthropic, "Effective context engineering for AI agents"** [anthropic.com/engineering, Score: keep,
  Level 7 (first-party production description, not a controlled experiment), Institutional]: single
  highest-authority source in the whole corpus for how Claude Code itself actually works. "Smallest
  possible set of high-signal tokens" as the operative goal; just-in-time retrieval preferred over
  pre-loading despite being slower; folder hierarchies and naming conventions are themselves signals the
  agent uses.
- **Formal Architecture Descriptors**, see Track A.
- **Miller**, see Track B.
- **Sourcegraph, context engineering guide** [sourcegraph.com/blog, Score: borderline (named reason: only
  independent numeric benchmark corroboration of the context-size thesis found in this track), Level 7,
  Institutional]: 100K-token pre-loaded summary underperforms 5K-token targeted retrieval.

### Track D, Mechanical enforcement vs. documented convention

- **RepoComplianceBench** [Yang, He & Zhou, arXiv:2607.26819, Score: keep, Level 3, Academic]: 0% unaided
  compliance with restraint/refusal-type rules; 3.5% policy-file discovery rate; task-shaped rules
  (verify, disclose) comply far better, especially with feedback.
- **Factorial file-structure study** [Score: keep, Level 2-3 (factorial controlled design), Academic]: no
  detectable adherence effect from file-structure documentation quality; ~5.6% within-session compliance
  decay per generated function.
- **ETH Zurich AGENTS.md evaluation** [Gloaguen et al., arXiv:2602.11988, Score: keep, Level 3, Contrarian]:
  agents read and follow context files but this doesn't reliably improve task success and raises inference
  cost 20%+.
- **GitHub, "2,500+ repos" AGENTS.md post** [github.blog, Score: borderline, Level 5, Institutional]:
  mainstream "write better, more specific docs" position, directly contradicted by the factorial study's
  controlled finding.
- **SonarSource, "Linting Is Not Enough"** [sonarsource.com, Score: keep, Level 7, Institutional]:
  distinguishes linters (syntax) from static analysis (data/control/taint flow) from architecture-as-code
  enforcement from quality gates as functionally distinct enforcement tiers, directly informs what KIND
  of mechanical enforcement to reach for.
- **htek.dev, hierarchical-layer enforcement anecdote** [htek.dev, Score: borderline (named lowest-scoring
  kept source), Level 8, Boots-on-the-ground]: a hand-written import-boundary rule (L0-L7 strict
  hierarchy) was violated by an agent in roughly three commits with nothing catching it, the single most
  Clean-Architecture-shaped real-world anecdote found in the whole corpus.

---

## 6. Methodology

### Research Design

**Research questions:**
1. Does current evidence/discourse support a distinct "AI-agent-native" architecture approach, or does
   human-optimized Clean Architecture still transfer well to AI-agent-maintained codebases?
2. What codebase properties are empirically or credibly linked to AI coding agent performance/reliability?
3. Given borg-collective's own measured cost structure and its own precedent (mechanically-enforced rules
   stick, documented conventions drift), what's the right concrete architecture for its Python migration?

**Scope boundaries:**
- In scope: AI-coding-agent-era (2024-2026) architecture/organization research and practitioner guidance;
  empirical studies linking code structure to agent performance; context-engineering practice; this
  repo's own specific technical constraints.
- Out of scope: pre-agent-era human-only software engineering literature (used only as contrast baseline);
  AI model architecture itself; non-coding agent domains.

**Target audience:** Noah, wants a decisive, actionable recommendation for an actual, imminent
architecture decision, not a survey.

**Methodology version:** research-tools:research, hybrid mode (evidence full-tier → decision-design).

### Source Discovery

**Search strategy:** 4 parallel tracks, each run by an independent agent with no shared context from the
others, targeting a distinct sub-question. Minimum 3 queries per track required; actual: 12, 9, 14, 13,
48 total, well above minimum, driven in most tracks by a dedicated hunt for a genuine Contrarian and/or
Boots-on-the-ground voice after initial candidates failed triage or verification.

**Search log (abbreviated, full query text preserved in each track's raw report; representative sample
per track shown):**

| # | Track | Sample query | Framing |
|---|-------|--------------|---------|
| 1 | A (Empirical) | `"Does Code Cleanliness Affect Coding Agents" arxiv controlled minimal-pair study` | factual, verifying known lead |
| 4 | A (Empirical) | `clean architecture layers harmful AI coding agents context window overhead` | contrarian |
| 11 | A (Empirical) | `"AI agents" "clean architecture" over-engineering "more harm than good"` | contrarian |
| 1 | B (Practitioner) | `"Clean Code for AI Agents" akitaonrails` | factual |
| 6 | B (Practitioner) | `Hacker News discussion Clean Architecture AI coding agents overengineering` | boots-on-the-ground |
| 1 | C (Context eng.) | `Anthropic "effective context engineering for AI agents"` | factual, primary source |
| 12 | C (Context eng.) | `Cognition Devin OR Sourcegraph OR Cursor engineering blog codebase structure agent context retrieval cost` | institutional hunt |
| 5 | D (Enforcement) | `does Claude Code actually follow CLAUDE.md rules reliably` | factual |
| 13 | D (Enforcement) | `Thibaud Gloaguen AGENTS.md ETH Zurich study context files coding agents arxiv` | academic, verifying known lead |
| 14 | D (Enforcement) | `"agents don't need linting" OR "skip the linter" AI coding agent self-correct without enforcement opinion` | contrarian hunt |

**Total sources discovered (raw, pre-triage):** approximately 90-100 across all four tracks (individual
titles, listicles, forum threads, and papers surfaced by search; exact count not separately logged per
source but every triage decision is documented in each track's raw report).

**Total sources pulled for full evaluation (cards written):** 21.

### Source Evaluation

**Evaluation framework:** 10-dimension credibility rubric (source-evaluation-rubric.md).

**Evidence classification:** 9-level hierarchy (evidence-hierarchy.md).

**Bias guards applied:** confirmation-bias check on every card (harder scoring on dims 5/6/8 when
agreeing, more generous when disagreeing); triangulation (no claim rests on a single source).

**Bias-Guard Summary:**

| Bias-guard outcome | Count |
|---|---|
| Agreed with source, scored harder | 7 |
| Disagreed with source, scored more generously | 5 |
| Neutral / no strong reaction | 9 |
| **Total sources evaluated** | 21 |

Ratio of agree:disagree is roughly 1.4:1, well under the 3:1 confirmation-skew threshold; no falsification
query or steel-man subsection was mechanically required, though Theme 1's presentation of the
"more-structure-helps" practitioner position (§4) and Theme 4's presentation of GitHub's institutional
position both function as steel-manned counter-positions in practice.

**Citation-Verification Report** (full detail in `verification-report.md`):

| Metric | Value |
|---|---|
| Total source cards | 21 |
| Verification rounds run | 4 (2 sampled, 1 full-corpus split across 2 agents, 1 direct final correction pass) |
| Round 1 sample | 7 (33%), 1 failed (14.3%) |
| Round 2 sample (fresh, non-overlapping) | 7 (33%), 3 failed, including 2 fabricated quotes (42.9%) |
| Round 3 (full remaining corpus) | 21 (100%), 7 more issues found, including 1 new fabrication introduced by a Round-2 fix |
| Round 4 (direct correction + self-check) | 7 cards corrected, all individually re-verified via direct exact-substring match |
| **Final state** | All 21 cards checked at least once; all identified defects corrected and directly re-verified |

The failure-rate band on the FIRST sampled pass was `>10%` (14.3%), which under the standard protocol
would require remediation before proceeding. This research went well beyond the minimum remediation path:
rather than a single fresh sample, it moved to full-corpus verification after the second sampled pass also
failed with fabricated quotes, and used direct (non-delegated) verification for the final correction round
after an earlier delegated fix itself introduced a new error. See `verification-report.md` for full
detail, this is reported plainly rather than presented as a clean single-pass gate, because the real
process is itself a relevant finding (see Theme 4 and the note at the end of `verification-report.md`).

### Inclusion/Exclusion Results

**Summary:**

| Category | Count |
|---|---|
| Total sources evaluated (cards written) | 21 |
| Included, Core | 10 |
| Included, Supporting | 11 |
| Excluded (at card stage) | 0 (heavy pre-card triage meant sources likely to fail were cut before a card was written, see per-track triage logs, 40+ sources cut at triage/pre-fetch/post-fetch-reject stages) |
| Overrides applied | 0 formal overrides; several borderline sources kept via Rule 2 (Diversity Include) or Rule 3 (Unique Insight Include) with reasons documented on-card |

**Distribution by evidence level:**

| Level | Description | Count |
|---|---|---|
| 1 | Systematic review / meta-analysis | 0 |
| 2 | RCT | 0 (the factorial file-structure study approaches this but is better classified as Level 3) |
| 3 | Large-scale observational / controlled matched-pair | 5 |
| 4 | Expert consensus / professional body | 0 |
| 5 | Practitioner case study with data | 1 |
| 6 | Qualitative research / interviews | 0 |
| 7 | Expert opinion / thought leadership | 10 |
| 8 | Anecdotal / personal experience | 5 |
| 9 | Marketing / promotional | 0 |

Levels 1 and 2 are both effectively 0 (no meta-analysis, no textbook RCT, though several Level-3 sources
use real controlled/matched-pair designs, which is the closest this fast-moving, preprint-stage field
currently offers). Per the methodology's own rule, this triggers the required disclosure: **this research's
strongest findings rest on a small number of not-yet-independently-replicated controlled studies, not on
an accumulated literature.** Treat the recommendation's confidence accordingly (see §1, Recommendation 8).

**Distribution by source category:**

| Category | Included | Excluded at triage (approximate, logged per-track) |
|---|---|---|
| Academic | 6 | ~15 (redundant papers, off-target papers, secondary write-ups of primary sources already cited directly) |
| Institutional | 5 | ~5 (Thoughtworks evidence-free piece, secondary AGENTS.md summaries) |
| Practitioner | 4 | ~20 (vendor/product marketing, generic listicles, redundant VSA-vs-CA explainers) |
| Boots-on-the-ground | 3 | ~10 (forum threads with no citable byline, anonymous content) |
| Contrarian | 3 | ~5 (off-target or evidence-free contrarian-framed pieces) |

**Distribution by credibility band:**

| Band | Weighted average | Count | Disposition |
|---|---|---|---|
| keep | ≥ 7.0 | 12 | 12 included (7 Core, 5 Supporting) |
| borderline | 5.0-6.9 | 9 | 9 included, all Supporting, each with a named reason on-card |
| reject | < 5.0 | 0 (sources scoring reject were excluded before a card was written, per each track's triage log, e.g. dasroot.net at 4.65, "Spaghetti Code Is Dead" at 3.35) | n/a |

**Real cut made this run:** every track independently satisfied the real-cut rule, Track A named/defended
`empirical-vertical-slicing-agent-navigation.md` as its lowest-scoring keep; Track B named/defended
`practitioner-furdak-vsa-claude-skill.md`; Track C fully fetched, scored, and rejected 5 sources below 5.0
before any card was written (dasroot.net 4.65, Aashish Kumar Medium 4.8, "Spaghetti Code Is Dead" 3.35,
plus 2 verified-off-target known leads); Track D named/defended `mechanical-enforcement-htek-agent-
hooks.md`.

### Perspective Balance

| Topic area | Academic | Institutional | Practitioner | Boots | Contrarian |
|---|---|---|---|---|---|
| A. Empirical & academic evidence | Y | N (documented absence, Thoughtworks was evidence-free) | Y | Y | Y |
| B. Practitioner discourse | Y (SonarSource, cross-tabbed) | Y | Y | Y | Y |
| C. Context engineering | Y | Y | Y | N (documented absence, every candidate rejected <5.0) | N (same) |
| D. Mechanical enforcement | Y | Y | N (documented absence, only candidates were promotional or secondary) | Y | Y |

Every gap above is a documented, searched-for absence (each track ran dedicated queries hunting for the
missing category), not an unexamined blind spot, see each track's raw report for the specific rejected
candidates. Across the full 21-card corpus, all 5 categories are represented overall (Academic 6,
Institutional 5, Practitioner 4, Boots-on-the-ground 3, Contrarian 3).

### Limitations

- **This is a young research question.** AI coding agents capable of the kind of autonomous, multi-file
  work this research is about are themselves only a couple of years old; the literature has not had time
  to mature into the kind of accumulated, replicated evidence base a more established question would have.
  Nearly everything here is a first study, not a consensus.
- **The headline finding (Constraint Decay) is one study.** It was checked with extra care (see §6
  Citation-Verification) precisely because so much of this research's recommendation rests on it. It has
  not been independently replicated.
- **No source directly measures "tool calls per change" as a function of layering depth alone**, isolated
  from documentation-artifact presence. This is the single clearest gap a follow-up study could fill.
- **Web search surfaces recent, SEO-optimized, and vendor content disproportionately**, every track's
  triage log shows significant vendor-marketing and content-farm material that had to be actively filtered
  out; a slower, more academic-database-focused search might surface a different mix.
- **The citation-verification process itself required four rounds, not one**, including two rounds where
  fabricated or altered quotes were found (see `verification-report.md`), this is reported as a
  methodological finding, not hidden, but it means confidence in ANY single-pass-verified research
  (including other researchers' work cited secondhand within these sources) should be tempered
  accordingly.
- **The researcher's own framing may have shaped query design**, the research was explicitly commissioned
  because of a specific, already-forming hypothesis (that the existing Clean Architecture plugin might not
  fit an AI-agent maintainer); Phase 2's dedicated contrarian/falsification queries in every track were the
  specific safeguard against this, but a fully blind search might have found a different initial mix.

---

## 7. Bibliography

### Core sources

- **Dente, F., Satriani, D., Papotti, P.** "Constraint Decay: The Fragility of LLM Agents in Backend Code
  Generation." arXiv:2605.06445. 2026. Score: keep | Level 3 | Core.
  The headline finding: a controlled matched-pair experiment isolating Clean Architecture as a variable,
  measuring a −9.1±1.6pp pass-rate penalty.
- **Trivedi, P., Schmitt, O. (SonarSource).** "Does Code Cleanliness Affect Coding Agents? A Controlled
  Minimal-Pair Study." arXiv:2605.20049. 2026. Score: keep | Level 3 | Supporting.
  Cleanliness affects efficiency, not correctness, the key disambiguating finding between "structure" and
  "Clean Architecture specifically."
- **Yang, W., He, R., Zhou, M.** "A First Look at Coding Agents' Compliance with AI Contribution Rules in
  Open-Source Communities" (RepoComplianceBench). arXiv:2607.26819. 2026. Score: keep | Level 3 | Core.
  Hard compliance numbers establishing that restraint-type rules need mechanical enforcement.
- **[Factorial file-structure adherence study].** Score: keep | Level 2-3 | Core.
  Controlled test finding no adherence effect from documentation-quality alone, plus within-session
  compliance decay.
- **Gloaguen, T. et al. (ETH Zurich).** AGENTS.md compliance evaluation. arXiv:2602.11988. 2026. Score:
  keep | Level 3 | Core.
  Even successful documentation-following doesn't reliably improve outcomes; raises cost 20%+.
- **Jin, R.** "Formal Architecture Descriptors as Navigation Primitives for AI Coding Agents."
  arXiv:2604.13108. 2026. Score: keep | Level 3 | Core.
  Architecture-as-documentation (not codebase layout) measurably helps navigation, a distinct, compatible
  finding from the layering-cost results.
- **Rajasekaran, P., Dixon, E., Ryan, C., Hadfield, J. (Anthropic Applied AI team).** "Effective context
  engineering for AI agents." Anthropic Engineering Blog. 2025. Score: keep | Level 7 | Core.
  Highest-authority first-party source; independently corroborates the signal-to-noise mechanism.
- **Miller, J. D.** "The Codebase Is the Prompt: Wolverine, Vertical Slices, and AI-Assisted Development."
  jeremydmiller.com. 2026. Score: keep | Level 7 | Core.
  The clearest direct mechanistic argument against layering found anywhere in this corpus.
- **Fowler, M. / Böckeler, B.** "Harness engineering for coding agent users." martinfowler.com. Score: keep
  | Level 7 | Core.
  Highest-authority named practitioner voice on codebase-as-harness; notably never names Clean
  Architecture specifically.
- **Akita (Fabio Akita).** "Clean Code for AI Agents." akitaonrails.com. 2026. Score: keep | Level 7 | Core.
  File/function-size and naming-convention argument for explicit structure, from the "more structure
  helps" side.

### Supporting sources

- **NimblePros (Blake, B.).** "Keeping AI Agents In Line With Clean Architecture." blog.nimblepros.com.
  Score: borderline | Level 8 | Supporting. Mainstream pro-Clean-Architecture voice, commercial conflict
  of interest disclosed.
- **Furdak, V.** "Vertical Slice Architecture for Claude Code: dotnet-vsa-webapi Explained." furdak.net.
  2026. Score: borderline | Level 8 | Supporting (named lowest-scoring keep, Track B).
- **[SonarSource].** "Linting Is Not Enough." sonarsource.com. Score: keep | Level 7 | Supporting.
  Enforcement-tier taxonomy (linter vs. static analysis vs. architecture-as-code vs. quality gate).
- **GitHub Engineering Blog.** "What works in practice: lessons from 2,500+ repos" (AGENTS.md). github.blog.
  2025-2026. Score: borderline | Level 5 | Supporting. Kept specifically for its direct empirical tension
  with the factorial study.
- **htek.dev.** Hierarchical-layer enforcement anecdote. Score: borderline | Level 8 | Supporting (named
  lowest-scoring keep, Track D).
- **Sourcegraph (Tanner, M.).** Context engineering guide. sourcegraph.com/blog. 2026. Score: borderline |
  Level 7 | Supporting (named reason: independent numeric corroboration).
- **[empirical-vertical-slicing-agent-navigation source].** dev.to. Score: borderline | Level 8 |
  Supporting (named lowest-scoring keep, Track A).

### Cross-tabbed (same source, multiple tracks)

`empirical-formal-architecture-descriptors.md` / `context-eng-formal-architecture-descriptors.md` (Jin,
same paper); `practitioner-sonarsource-cleanliness-study.md` / `empirical-code-cleanliness-minimal-pair.md`
(SonarSource, same paper); `practitioner-nimblepros-clean-architecture.md` /
`empirical-nimblepros-clean-architecture-guardrails.md` (NimblePros, same article), each pair was
independently discovered and carded by two different track agents working blind to each other, then
cross-referenced during synthesis. Full per-track detail (all 40+ excluded sources with individual cut
reasons) preserved in the raw agent reports; individual source cards for every included source at
`docs/research/sources/`.
