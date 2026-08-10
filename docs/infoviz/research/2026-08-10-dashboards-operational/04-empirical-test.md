# Phase 2 Empirical Test — Applying D1-D8 to Borg's Own Operational Surfaces

**Date:** 2026-08-10
**Program mandate:** each sub-project ends by applying its findings to a real artifact + a comprehension check.
**Method:** apply the Phase-2 dashboards/operational playbook rules (D1-D8) to two in-house specimens, then run
the three-question comprehension check from `02-eli10-brief.md`.

## Specimens chosen

Two, because Track 1's question has two halves and they get different verdicts.

- **Primary — borg's alert/hook layer** (`hooks/*.sh`, 12 hooks). This is an alerting system: it decides what
  interrupts a working session. D4/D5/D6/D7 apply directly.
- **Secondary — `borg ls`** (`cmd_ls` in `borg.zsh`). This is a status display. D1/D2/D3 apply directly.

### A disclosure about ordering

**The primary specimen's defect was noticed before the D-rules were derived.** The tool-count nudge fired twice
and the pre-commit reminder three times during the session that planned this phase, and in every case the correct
response was one already taken. That observation is what motivated choosing this specimen, which is a
motivated-reasoning risk the Phase 2 planning review flagged explicitly. It is recorded here rather than hidden.
The mitigation: the critique below is written against the rule text as derived in
`03-design-principles-playbook-additions.md`, and where a rule *exonerates* a hook that felt annoying, it says so
(see bash-guard, and the partial credit to pre-commit-remind). The **secondary** specimen was measured only after
the rules were written, and its findings were not anticipated.

---

## Primary specimen: the hook layer

### Inventory

Twelve hooks. They fall into three groups by what they do to a session:

**Blocking guards** — `bash-guard`, `borg-supabase-guard`, `borg-dispatch-guard`.
Veto a tool call; the human/agent must change course.

**Unconditional nudges** — `tool-count-nudge`, `pre-commit-remind`.
Inject advisory text; never block.

**Silent / lifecycle** — `borg-link-down`, `borg-link-up`, `borg-notify`, `borg-memory-read-log`,
`borg-nanoprobe-log`, `borg-plan-promote`, `notify`.
Record state or fire host notifications; do not interrupt reasoning.

Only the first two groups consume attention in-session, so only they are tested against D4.

### D4 — the four-part interrupt test

**`bash-guard`, `borg-supabase-guard`, `borg-dispatch-guard` — PASS, cleanly.**
Urgent (the destructive call is about to run), actionable (change or abandon the command), requires judgment (the
right alternative depends entirely on intent), and actively user-visible (the operation is blocked). Critically,
the correct response **varies with the alert** — a blocked `rm -rf` and a blocked `supabase db reset` demand
different actions. These are what D4 was written to permit. That three of borg's loudest interrupts pass cleanly
is worth stating, because the rest of this section is negative.

**`tool-count-nudge` — FAIL, on three of four conditions.**
Mechanics (`hooks/tool-count-nudge.sh:17-18`): a per-session counter increments on every `PostToolUse`; at
`COUNT >= 75` it emits "SESSION CHECK-IN: 75+ tool calls this session. Consider running /borg-review… or
/borg-link-up…" and resets to 0. So it fires **every 75 tool calls**, indefinitely.

- *Urgent?* **No.** A call count is not a condition. Nothing is wrong at call 75 that was fine at call 74.
- *Actionable?* **No, in D4's strict sense.** The suggested actions are identical at call 75, 150, and 225. The
  hook has no visibility into whether the session is going well or badly, so the human cannot respond
  differently. This is D4's second clause exactly: *"If a page merely merits a robotic response, it shouldn't be
  a page."*
- *Requires human judgment?* **No.** The response is rote by construction.
- *Actively user-visible?* **No.** It reports on the monitoring system's own counter, not on any condition
  affecting the user's work.

This is also a **D6 violation**, and the clearest example of D6's corollary in the whole phase: a tool-call count
is a *proxy*, not a symptom. It fires identically whether the session is productive or thrashing — which is
precisely why it cannot be acted on differently. The symptom it is groping toward (*this session has lost the
plot*) is real and worth alerting on; the count is not a measurement of it.

**`pre-commit-remind` — FAIL on actionability, with partial credit.**
Mechanics (`hooks/pre-commit-remind.sh:12-20`): fires on every Bash call containing `git commit` (excepting
`--dry-run`), asking whether `/simplify` has been run.

- The hook **cannot observe whether `/simplify` actually ran.** It asks unconditionally, so the answer is "yes,
  already" on every well-run commit and the message carries no information. Rote response → D4 fail.
- **Partial credit, and it matters:** the hook *is* conditional in one respect — it appends the
  `/borg-assimilate` sentence only when `PROJECT_PLAN.md` exists in the cwd (line 18). That is a real, cheap
  condition on real state, and it is the shape the rest of the hook should take. The fix D4 implies is not
  deletion but **conditioning**: fire only when the session has touched code files and no `/simplify` has run.
  That version would pass all four clauses.
- Live evidence: it fired three times in the session that produced this document. On all three the answer was
  already yes or not-applicable.

### D5 — channel routing

**FAIL, structurally — and this is the finding with the most leverage.**

Borg has exactly **one** in-session delivery channel: inject text into the agent's context via
`additionalContext`. There is no queue tier and no display-on-request tier. Every signal the system wants to
emit is therefore, by construction, an interrupt.

D5's consequence is direct: with a single channel, D4 must be enforced on *every* signal, which is infeasible —
so subcritical signal inevitably leaks onto the interrupt path and degrades it. The SRE chapter's prescription
maps cleanly: "you should favor a dashboard that monitors all ongoing subcritical problems for the sort of
information that typically ends up in email alerts." Borg already **has** the dashboard — `borg ls` — and does
not use it as the destination for subcritical signal. The tool-count nudge is exactly the kind of ongoing,
non-urgent, ambient observation that belongs on a surface the human consults, not one that consults the human.

Building the queue/display tier is what would make D4 affordable for the nudges. Note that this is a design
finding, not a work order — remediation is explicitly out of scope for this phase.

### D7 — the attention budget

**AT RISK, unmeasured.** Twelve hooks, at least five of which can produce in-session output, with no accounting
of aggregate interrupt cost and no mechanism that would notice fatigue setting in. D7 says treat each added
alert as a withdrawal from a finite shared budget; borg has no ledger. The honest statement is that we do not
know the current interrupt rate per session and have never measured it.

Worth noting what D7's own confidence caveat forbids here: the Level 1 review's **four causes of alert fatigue
could not be read**, so this analysis cannot claim which specific cause borg is exhibiting. It can only say the
phenomenon is documented, generalizes beyond security operations, and that borg has no defense against it.

---

## Secondary specimen: `borg ls`

Measured after the rules were written. Figures are from a live run on 2026-08-10 with 20 registered projects.

### D1 — one screen

**FAIL, by a factor of roughly two.** The output is **83 lines**. A standard terminal shows 24-50. Few's
boundary condition applies verbatim: "If you must scroll around to see all the information, it has transgressed
the boundaries of a dashboard."

### D2 — scent at the top

**FAIL, and this is the most consequential finding for the display.** The first **8 lines** are ASCII-art of a
Borg cube plus the tagline "resistance is futile." That is the highest-scent region of the display — the region
D2 identifies as deciding whether anything below is read at all — spent entirely on decoration.

Worse, the answer to the top task is at the **bottom**. The observed row order runs `never` → `122d` → `62d` →
… → `9d` → `just now`, placing the most recently active projects last. Whatever the intended sort, for the task
"what needs me right now?" the display is inverted: the reader must traverse 20 rows of stale entries to reach
the live ones, and D2's finding is that most readers will have quit before then.

This is also where the **P7 tension flagged in `03-design-principles-playbook-additions.md` actually bites.**
Phase 1's P7 says embellishment is not automatically waste — Bateman et al. found better multi-week recall for
embellished charts. The Borg cube is exactly that kind of embellishment: it carries identity and it is part of
why the tool is pleasant to use. But D2 says it is not neutral — it occupies the region that determines whether
the rest is read. **Neither phase supplies a test that resolves this**, and this document declines to pick a
winner. What can be said without picking one: the cost is specific and locatable (8 of 83 lines, at the top),
and if the display were bounded to one screen per D1 the trade-off would be forced into the open rather than
absorbed by scrolling.

### D3 — exceptions, not inventory

**FAIL, measurably.** All **20 of 20** project rows display status `idle`. The status column has **zero
variance** — it is consuming a column's width and returning no information in this snapshot. D3's practical test
is exactly this computation, and the column fails it outright.

The directive section compounds it: **46 directive bullets** are rendered, of which **30 — 65% — display as
`---`**. Those are horizontal-rule or frontmatter delimiter lines being picked up by the H1-title extraction, not
real titles. So the largest single block of the display is majority noise, and it is noise that *looks* like
content. Under D2's foraging account this is worse than blank space: it presents as scent and does not repay
following it.

(The `---` rendering is a straightforward extraction bug, not a design flaw. It is recorded here because it is
what the display currently does, and because the D3 verdict does not depend on it — the status column fails
independently.)

### D8 — job count

**AT RISK.** `borg ls` is simultaneously a project inventory, a status monitor, a directive backlog viewer, and a
brand surface. D8 asks which existing job each added job degrades; the answer here is that the backlog view (46
lines) has crowded out the status view (20 lines) and both have pushed the display past D1's boundary. Held at
low confidence, per D8's Level 8 provenance — this is the question being asked, not a finding being asserted.

---

## Comprehension check (three-question test from the ELI10 brief)

Run against `borg ls` as it currently renders. Reasoned from the measured output, **not** from an instrumented
human trial — same caveat as Phase 1.

- **Check A — "What needs your attention right now?" → FAIL.** The predicted answer describes the *layout*
  ("a list of projects, most of them idle, and a long list of directives") rather than naming a specific thing
  needing attention. Nothing in the top 8 lines, and nothing in the first screen, identifies a target. The two
  `just now` projects are on lines ~30-31, below where D2 predicts most readers stop.
- **Check B — "How much of what you just saw was normal?" → PASS, accidentally.** A viewer would correctly say
  "almost all of it" — because all 20 rows read `idle`. The display does convey that nothing is exceptional, but
  it does so by showing 20 identical rows rather than by summarizing, which is the D3 failure restated. It gets
  the right answer through the wrong mechanism.
- **Check C — "Would you act differently on this interrupt now vs. an hour from now?" → FAIL for the nudges,
  PASS for the guards.** Applied to the hook layer: `tool-count-nudge` and `pre-commit-remind` yield identical
  responses regardless of timing; the three blocking guards do not fire at all unless a specific dangerous
  operation is imminent, at which point timing is the entire point.

**Net:** the blocking guards are well-designed alerts by Track 1's own standard and should be left alone. The two
unconditional nudges fail D4 for the same root reason — they fire on proxies rather than conditions — and the
absence of a non-interrupting channel (D5) is what makes that failure structural rather than incidental. The
status display fails D1, D2, and D3 independently of each other.

---

## Concrete findings, ordered by leverage

Recorded as findings, not work orders. **No hook or display code is changed by this phase** — that boundary was
set in the directive.

1. **D5 — there is no non-interrupting channel.** Everything else follows from this. A "session log" or an
   ambient section in `borg ls` that subcritical signal could be routed to would let the nudges stop
   interrupting without losing their content.
2. **D4/D6 — condition the nudges on state instead of on counts.** `pre-commit-remind` already demonstrates the
   pattern (it checks for `PROJECT_PLAN.md`); extending it to check whether `/simplify` has run, and replacing
   the tool-count trigger with something that distinguishes a healthy session from a thrashing one, would move
   both hooks from rote to actionable.
3. **D2 — the top 8 lines and the sort order are the display's biggest lever.** Surfacing "what needs you" above
   the fold, and reversing the row order so live projects lead, costs nothing structurally.
4. **D3 — collapse the idle rows and fix the `---` extraction.** 30 of 46 directive bullets are delimiter noise;
   20 of 20 status values are identical. Both are summarizable.
5. **D1 — once 3 and 4 land, check the line count again.** One screen is a cheap, falsifiable test and it is
   currently failing at ~83 lines.

## Method caveats

Critique derived from hook source (`hooks/tool-count-nudge.sh`, `hooks/pre-commit-remind.sh`, and the hook
inventory in `CLAUDE.md`) and from a live `borg ls` run captured on 2026-08-10 with 20 registered projects — not
from an instrumented human trial. The comprehension-check outcomes are reasoned predictions grounded in the
Phase-2 evidence (principally the information-foraging account of early abandonment and the SRE actionability
test), and should be confirmed with a real viewer when convenient. This matches the program's standing
"directional, re-verify" posture, and mirrors the same unresolved caveat carried by Phase 1's empirical test,
whose 5-second-story predictions also remain unverified against a human.

The `borg ls` figures are a single snapshot. Status variance in particular is a property of *this moment* — 20
idle projects on a quiet Sunday — and a run during active multi-project work would show a different distribution.
The D3 verdict rests on the display having no summarization mechanism regardless of distribution, not on the
snapshot alone; but the "zero variance" figure specifically should not be quoted as a standing property.
