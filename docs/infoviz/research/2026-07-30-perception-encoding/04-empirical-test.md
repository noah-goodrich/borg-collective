# Phase 1 Empirical Test — Applying P1-P7 to a Real Artifact

**Date:** 2026-07-30
**Program mandate:** each sub-project ends by applying its findings to a real artifact + a comprehension check.
**Method:** apply the Phase-1 perception/encoding playbook rules (P1-P7) to a real in-house visualization, then
run the 5-second-story test from the ELI10 brief (`02-eli10-brief.md`).

## Specimen chosen

**The Story-Lens hub view** — Hub v3 "Story-Lens" v0.1, the ownership-first merge-tree graph rendered by
`merge-tree/render_graph.py` on branch `feature/hub-story-lens` (borg-collective PR #104). It renders a
self-contained `graph.html` (inline SVG + vanilla JS) to `~/.local/state/borg/merge-tree/graph.html`.

This is the program's own designated "Story-Lens lab specimen" (referenced in the 2026-07-28 / 2026-07-29
checkpoints), so it is first in the task's preference order — no need to fall back to an Ontra dashboard or the
DE-1706 apex diagram.

It is an ideal test subject because it exercises nearly every Phase-1 rule at once:
- a **5-state meter** (the key quantity encoding) — P1/P2/P4,
- a **needs-you / urgency signal** that must be noticed — P3,
- **semantic zoom** across four levels (L0 project cards → L1 4-column state board → L2 detail slide-over →
  Isolate node-link DAG) — P6,
- deliberate, non-minimalist status chrome (color bands, badges, callouts) — P7.

### What the artifact is trying to say (intended message)

From the renderer docstring and the project brief it serves: *"Of your ~8 owned projects, here is the one that
needs you next, the single command to run next, and what (if anything) is blocking it."* The intended
top-priority quantity is **urgency / needs-you + the next action**, not the raw state counts.

### How it actually encodes (from the source)

- **Meter** (`meterHtml`, render_graph.py:446-450): a horizontal stacked bar, one segment per state
  (ready/in-flight/blocked/pending/done), segment sized by `flex-grow: <count>` inside a fixed-width track,
  colored `--ready`=green, `--flight`=amber, `--blocked`=red, `--pending`/`--done`=grey. Above it,
  `.meterlabs` prints the **exact integer count** per non-zero state in the matching color.
- **Needs-you signal:** a small pip glyph (`⚐`, `.pip`, gold `--you`) in the card title, plus a
  `.pcard.needsyou` gold left-border (3px) and a warm gradient wash on the card.
- **Ranking:** a numeric `.rank` badge (explicit position/order integer).
- **Next action:** `.nextact` line prefixed by a green triangle (`.tri`, `--ready`).
- **Blocked-by:** `.blockedby` callout — red text with a 2px red left-border.
- **Semantic zoom:** breadcrumb-driven view swaps L0→L1→L2 (`.crumbs`); the L2 slide-over animates
  (`transform .16s ease`, line 325); the Isolate DAG has drag-pan + wheel-zoom (`applyCam`, line 630) with a
  `0 = fit` reset and an on-canvas hint "drag to pan · wheel to zoom · 0 = fit · Esc = close".

## Rule-by-rule critique

### Rules it already satisfies

- **P2 (redundant cue) — PASS, and this is the artifact's strongest move.** The meter never relies on the
  color/length channel alone: every non-zero state prints its exact integer count in `.meterlabs` directly
  above the bar, and each segment carries a `title=` tooltip ("Blocked: 3"). This is exactly P2's prescription
  (top channel + direct label + exact-value-on-hover) and it rescues the meter from the P1/P4 problem below.
- **P5 (table vs. chart) — PASS by correct task-fit.** The L1 board and L2 slide-over are effectively tables
  (ranks, exact per-item state, commands to copy) — the right call for precision/lookup, per Remshard &
  Queenborough. The L0 meter is a chart, used for the at-a-glance "shape of the project" comparison. Table for
  lookup, chart for pattern: correct.
- **P6 (semantic zoom) — MOSTLY PASS.** Four navigable levels with an overview default, breadcrumbs for
  re-orientation, and details-on-demand. Two caveats (below): the L0→L1→L2 transitions are **instant view
  swaps, not animated zooms**, and the Isolate `0 = fit` reset jumps the camera. Cockburn/Karlson/Bederson's
  documented failure mode is exactly this cognitive discontinuity between pre- and post-zoom states. The
  wheel-zoom itself is continuous (fine); the breadcrumbs are the mitigation that keeps this a pass rather than
  a fail. Note: the L2 slide-over *does* animate (`.16s ease`) — so the pattern is already in the codebase and
  just isn't applied to the level jumps.
- **P7 (minimalism is not a virtue) — PASS.** The design deliberately keeps "useful chrome": state colors,
  rank badges, next-action commands, blocked callouts. It is not chasing a maximal data-ink ratio, and the
  extra ink is load-bearing (it carries the action, not decoration). Consistent with Elavsky's critique.

### Rules it violates (or is at risk on)

- **P1 (highest-ranked channel for the key quantity) — PARTIAL VIOLATION.** The meter encodes state counts by
  **length**, which is rank-2 (good) — but as a *stacked* bar, only the first (green/ready) segment shares a
  common baseline; every later segment (crucially **blocked**, in the middle) floats, so its length is hard to
  compare across projects. Worse, `flex-grow` normalizes each project's meter to the same total track width, so
  a segment's pixel length encodes a *proportion within that project*, not an absolute count — "3 of 6 blocked"
  and "8 of 16 blocked" render at the same width. Absolute magnitude is therefore only readable from the P2
  numeric labels, not from the P1 channel. The channel and the label disagree about what's being encoded.
- **P4 (loudest channel ↔ most important attribute) — VIOLATION, the headline finding.** The intended
  most-important attribute is **"this needs you / here's the next action."** But the loudest channel on the
  card is **red**, and red is assigned to **blocked** (the `.blockedby` callout + red meter segment). Red
  carries the strongest pre-attentive pull (danger/salience); the actual priority signal — the needs-you pip —
  is a single small gold glyph, and the next-action is a low-salience green triangle line. So the eye is pulled
  to "what's stuck" rather than "what to do next." A low(er)-priority attribute has grabbed the loudest
  channel. This is a textbook Munzner effectiveness-principle mismatch.
- **P3 (anomaly must pop, not merely be visible) — AT RISK.** The needs-you pip is *present and visible* but
  not *dissimilar enough from its neighbors* to survive an attentionally-loaded scan (Simons & Chabris): it is
  a small glyph competing against a full palette of green/amber/red meter segments and gold `--you` accents
  used elsewhere (e.g., the `.tg.on` toggle, `.ichip.you`). Gold is doing double duty, so "needs you" does not
  own a unique channel. Under load, a viewer can miss which card is the one that needs them.

## 5-second-story test result

Simulated per the ELI10 brief's protocol (show 5s, remove, ask "what's the one thing this wants you to know?"),
reasoned from the encoding above.

- **Check 1 — states the single most important comparison via the chosen channel: FAIL.** The 5s takeaway is
  "a stack of project cards with little colored bars, and some red." The viewer reads *state distribution* (the
  meter) and *risk* (red), not the intended "**this** project needs you, run **this** next." The priority
  message is not on the loudest channel (P4), so it loses the attention race.
- **Check 2 — can point to where to get more detail without being told: PASS.** Breadcrumbs + clickable cards +
  the Isolate hint make the zoom affordance visible within 5s. P6's affordance requirement is met even though
  the transitions aren't animated.
- **Check 3 — mentions the urgent/anomalous item unprompted: FAIL (partial).** Viewers reliably call out
  **red/blocked** items unprompted — but "blocked" is not the anomaly the design most wants noticed; the
  **needs-you** card is, and its gold pip does not pop (P3). The wrong anomaly wins attention.

**Net:** 1 of 3 pass. The artifact is well-built and P2/P5/P7-clean, but its *priority message* is being
out-shouted by its *risk coloring* — a P4 (channel-assignment) failure that then drags down the P1 and P3
checks.

## Concrete fixes (ordered by leverage)

1. **P4/P3 — give "needs you next" the loudest, unique channel.** Promote the primary next-action card to a
   distinct, reserved treatment that outranks red: e.g., a solid high-contrast accent bar + a bold "▶ DO NEXT"
   label at the top of the card, and stop reusing gold (`--you`) for unrelated toggles/chips so the needs-you
   signal owns its channel. Demote "blocked" red from a full callout to a smaller inline chip unless blocked is
   genuinely the top priority. Target: the eye lands on *the action*, not *the blockage*, in the first fixation.
2. **P1 — make the meter's key quantity a true shared-baseline length, or drop the ambiguity.** Either (a) keep
   the stacked bar but stop normalizing width — size the whole meter by total item count so cross-project
   length is comparable — or (b) pull the one quantity that actually matters (e.g., blocked count, or
   needs-you count) out into its own left-aligned, shared-baseline mini-bar. Keep the P2 numeric labels
   regardless.
3. **P6 — animate the level transitions.** The `.16s ease` transform already used on the L2 slide-over should
   also drive L0→L1→L2 and the Isolate `0 = fit` reset, so zoom feels continuous rather than a jump-cut
   (Cockburn et al.'s documented mitigation). Low cost — the pattern exists in the file already.

## Verdict

The Story-Lens is a strong, non-minimalist, redundancy-conscious design (P2/P5/P7 solid, P6 close) whose one
real defect is a **channel-priority inversion**: risk (red) is louder than the intended priority (needs-you /
next-action). Fixing the channel assignment (fix #1) is the single highest-leverage change and would flip
5-second-story checks 1 and 3 from FAIL to PASS.

### Method caveats

Critique derived from the renderer source (`render_graph.py` on `feature/hub-story-lens`) and the baked style
tokens/`meterHtml`/`applyCam` logic, plus the checked-in rendered `graph.html` in the merge-tree state dir —
not from an instrumented human 5-second trial. The 5-second-story outcomes are reasoned predictions grounded in
the Phase-1 evidence (esp. Simons & Chabris on inattentional blindness and the Cleveland-McGill/Munzner channel
ranking), and should be confirmed with a real viewer when convenient. This matches the program's "directional,
re-verify" posture on P2/P3/P7.
