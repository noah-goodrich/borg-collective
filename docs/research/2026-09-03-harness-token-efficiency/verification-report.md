Generated: 2026-09-03

# Verification Report — Harness Token Efficiency

**Status: VERIFICATION COMPLETED — GATE FAILED. Failure rate 50%, band `>10%`.**

Independent verification ran to completion on both source cards. One passed, one failed. A 50%
failure rate is ten times the 5% gate threshold, so this run does **not** pass, and the failure is
reported rather than remediated away. The blind design review separately returned **REVISE from all
three reviewers**. Both outcomes are recorded in full below.

---

## Agent identities

- **Synthesis agent:** `main-session-85743087` (the orchestrating session that wrote both source cards
  and both deliverable documents).
- **Card verifier:** `verifier-cards-2026-09-03-borg-token-telemetry`. A first verifier died on an
  API rate limit partway through card 1; this second one was dispatched after the limit reset and
  completed both cards, re-running every measurement from scratch against the live files.
- **Design reviewers:** three blind adversarial agents (ideator / critic / auditor), given the problem,
  the option set and the chosen recommendation, but not the council's reasoning.

The synthesis ID is **not** copied into any verifier field.

---

## Source-card verification

**Cards on disk:** 2. Both are Level-1 direct-measurement cards authored by the synthesis agent.

- `sources/harness-token-local-spend-telemetry.md`
- `sources/harness-token-transcript-forensics.md`

**Sampling rule:** with fewer than 10 cards, the protocol requires verifying **all** of them.
Required sample: 2 of 2 (100%).

**Achieved sample: 2 of 2 (100%).**

| Card | Outcome | Basis |
|---|---|---|
| `harness-token-local-spend-telemetry.md` | **failed** | An absolute "100%, verified in both cases" TTL claim falsified by a full sweep; plus an internal self-contradiction and a wrong line-number citation |
| `harness-token-transcript-forensics.md` | **verified** | Every load-bearing number and all three verbatim quote triples reproduced exactly |

**Aggregate:**

| Metric | Value |
|---|---|
| Sample size | 2 of 2 cards (100%) |
| Verified | 1 |
| Failed | 1 |
| Inaccessible | 0 |

**Failure count: 1.** Failure rate = 1 / (1 + 1) = **50%**. Band: **`>10%`**.

### Card 1 — what failed

| Claim | Claimed | Recomputed | |
|---|---|---|---|
| `test("opus-4-[6-9]")` vs `"claude-opus-5"` | does not match | does not match | ✅ |
| Zero-output ledger rows | 398 (49.6%) | 398 / 803 | ✅ exact |
| Stored cost total | $92,711.92 / $92,712.02 | both reproduce (different aggregation paths) | ⚠ card contradicted itself |
| Main-loop TTL split | 100% 1h / 0% 5m, "verified in both cases" | **99.59% / 0.41%** — 300,022,304 vs 1,232,678 across 110 files, traced to two real `claude-opus-5` turns on 2026-08-31 | ❌ **falsified** |
| Subagent TTL split | 100% 5m / 0% 1h | 1,205 files, 324,885,942 tokens, 0 at 1h | ✅ exact |
| Quote location | "line 803" | line **802** of 803 | ❌ text verbatim, label wrong |

The falsified claim is mine, and it failed for a specific reason worth keeping: it generalized a
12-session spot check into an absolute "100%, verified." The verifier swept all 110 main-loop
transcripts and found the counterexample. **The pricing consequence is unchanged and the tier model is
still correct — but the card asserted more than it had measured.**

### Card 2 — what held

Gap-bucket table: the load-bearing `>60 min` row reproduced **exactly** (41 turns / 39 re-writes /
95.1%), as did the 1–5 min and 30–60 min rows. Two buckets were off by +5 and +2 turns out of 2,550
pooled (0.27%), and **every full-re-write count matched in every bucket**, so the dose-response and
the rate conclusion are untouched. The 63.2% cache-write share reproduced to 63.21%. The raw-vs-dedup
reconciliation reproduced exactly on all six figures. Pooled mean prefix 444,622 reproduced to the
token. All three verbatim quote triples reproduced exactly.

### Corrections applied

All four mismatches were fixed in the cards, each annotated in place rather than silently amended: the
TTL claim now reads 99.59% with the counterexample named, the two cost-total figures are shown as two
aggregation paths, the quote is relabelled line 802, and the gap-bucket counts are noted. A subagent
cost figure was also corrected in the same pass ($7,325 → $5,807) after the TTL finding showed
subagent writes bill at 1.25×, not 2×.

---

## What verification *did* complete

A separate, claim-level adversarial pass ran to completion before the limit and is reported here
because it materially changed the deliverable — but it verifies **claims**, not **source cards**, and
does not satisfy the card gate.

**65 load-bearing claims** were each handed to an independent agent instructed to refute them:

| Verdict | Count |
|---|---|
| CONFIRMED | 39 |
| PLAUSIBLE | 1 |
| REFUTED | 25 |

**Refutation rate: 25 / 64 = 39.1%** (excluding the single PLAUSIBLE).

A 39% refutation rate on load-bearing claims is high, and it is the single most important number in
this report. It means roughly two in five confident-sounding research findings did not survive a
deliberate attempt to break them. Corrections that were caught and folded back into the deliverable
include:

- The article's "Automation Anywhere: ~20% fewer tool calls" claim was initially reported as
  unfindable. **Refuted** — it is real and published (2026-05-18), verbatim: *"Context-enabled agents
  also reduced average tool calls per run by roughly 20% on complex workflows."* The erroneous version
  had already been passed into the design brief before it was caught.
- The claimed contradiction between the "30–75%" range and the article's "~30%" figure. **Refuted** —
  it is a range, and ~30% is its same-model low end. No inconsistency.
- The claim that the losing arm's configuration was undisclosed. **Refuted** — it is published in the
  benchmark repository, with a system prompt shared across all three arms.
- The claim that no independent vendor-neutral evidence exists for the direction. **Refuted** — a
  peer-reviewed study under a cleaner design was surfaced.
- A cache-invalidation claim about `tool_choice` that **inverted** the documentation.
- One CONFIRMED verdict noted that the supporting quote supplied with the claim was **fabricated**,
  and another that its quote was a paraphrase presented as verbatim. Both were in agent-supplied
  research output, and both are the reason card-level quote checking matters.

Additionally, the research's own central causal finding was **self-corrected** during the run: cache
re-write spikes were first attributed to compaction, then re-measured as idle-time TTL expiry
(95.1% re-write rate after a >60-minute gap, against 0.18% under a minute). The original wrong reading
is recorded in the forensics card rather than silently replaced.

---

## What this means for the deliverable

1. **The gate fails at a 50% card-failure rate, and that stands.** One of the two cards the whole
   analysis rests on asserted more than it had measured. The specific error was small in magnitude
   (0.41% of token volume) and changed no conclusion — but the protocol's borderline-defaults-to-failed
   rule exists precisely so that "small and directionally right" does not get scored as verified.
2. **The blind design review returned REVISE from all three reviewers**, and two of its findings were
   independently re-verified and were serious:
   - The recommendation's step 4 would have **destroyed 93% of the cost ledger** (744 ledger sessions
     vs 107 transcripts on disk, intersection 53). Withdrawn and replaced with in-place recomputation.
   - The **read/write cost split was inverted** — recomputed across all deduplicated transcripts, cache
     read is 54.4% and write 37.9%, not the reverse. The research diagnosed a ~3×-wrong meter and then
     reasoned from its output. This is the most instructive failure in the run.
3. **The load-bearing local measurements were computed at least twice** — once by the synthesis agent
   and once by an independent measurement agent — and agreed on the dedup inflation, the TTL split,
   and the model-tier regex defect. That is corroboration, not verification, and the distinction is
   the point of this report.
4. **Do not treat the dollar figures as settled.** They are the reason the recommendation's first
   action is to repair the meter and *stop to read the number* before authorizing anything else.

## To upgrade this run

Re-run the card verifier to completion against both cards, record per-card outcomes and a real failure
rate here, and replace the status line. Until then this deliverable is honestly labelled and the
executable gate correctly refuses it.
