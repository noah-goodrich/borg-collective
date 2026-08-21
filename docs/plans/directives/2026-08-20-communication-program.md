# Directive: The Communication Program (umbrella)

*Filed: 2026-08-20 · Status: Accepted 2026-08-20 · Owner: Noah*

**tl;dr** — Work state and technical writing reach Noah as walls of text he must skim, scroll-hunt, and
re-derive by hand. Fix it with three layers: writing standards enforced by skills, delivery surfaces that put
documents and maps where he already looks, and derived data underneath so both stay true without manual upkeep.

## Problem

Three measured facts and one observed one:

- The 2026-08-20 completion audit: 97% of checkpoints hand-restate plan position; 47% of the non-backlog open
  board is already done and nothing records it. State reaches Noah only through prose he re-reads.
- Long chat replies fail mechanically: he waits for streaming to finish, skims up to find the start, reads down
  typing feedback, and loses his place if he submits early. Terminal eyes land at the bottom (same finding as
  viz-1's landing-region rule).
- Web dashboards pull him out of terminal context; four viz PRs shipped supply with zero consumers.
- The same problem reproduced on the work machine (TRD/PR tooling, 2026-08-19): format alone did not fix
  surfacing.

## Solution

Three layers, each its own child directive:

1. **Standards** (claude-plugins, `2026-08-20-design-doc-and-brevity-skills.md`): design-doc template
   (tl;dr, Problem, Solution, Goals, Non-Goals, Alternatives Considered), brevity principles distilled from
   the Google developer style guide and Smart Brevity (unbranded), PR descriptions with a two-sentence tl;dr.
2. **Surfaces** (borg-collective, `2026-08-20-comms-delivery-surfaces.md`): `borg show` opens a doc in the
   window's nvim side pane; `borg chains` regenerates the linked PR-chain map; chat contract: short body,
   tl;dr at the bottom, `file:line` references as jump links.
3. **Data**: the directive-state deriver (audit recommendation #1) and PR #158's declared edges. Both exist
   as filed work; this program consumes them, it does not duplicate them.

Prototypes shipped with this filing: the live PR-chain artifact (linked in the child directive) and this
document set itself, delivered via the side pane.

## Goals

- Any proposal is triaged in under 2 minutes from its tl;dr + Goals alone.
- One command regenerates the chain map from live data; every node links to its PR.
- Documents open beside the conversation without Noah touching vim.
- Chat replies follow the contract by default, enforced by skill, not memory alone.

## Non-Goals

- No new knowledge database, no Obsidian conversion (see Alternatives).
- No GitHub Projects boards, no second backlog surface.
- No auto-posting to GitHub; humans trigger publishes.
- Not a redesign of the viz renderer; the chain map is cards and links, not the Frozen Atlas.

## Alternatives Considered

- **Adopt GitHub harder (Projects, Issues).** Partial yes. PRs and their descriptions are derived capture and
  already work; generate descriptions with tl;dr and chain position (standards layer). Projects boards are
  another volunteered surface, the exact shape the audit showed rots (36 shipped-unarchived directives, 0/44
  checkbox flips). Skip boards; revisit issues-as-mirror only after the state deriver exists.
- **Convert to Obsidian.** No. Cairn died on volunteered capture; an Obsidian vault as a second write surface
  is the same failure with a nicer editor. But the cheap version costs nothing: checkpoints and plans are
  already markdown with wikilinks, so pointing Obsidian at the existing folders as a read-only lens is a
  30-minute experiment Noah can run if a reading gap remains after the surfaces land. Conversion is rejected;
  the lens experiment is allowed and owned by Noah.
- **Web dashboard as the primary surface.** Rejected: takes him out of terminal context; reserve artifacts for
  what interactivity earns (linked graphs).
- **Status quo plus discipline.** Rejected by evidence: four voluntary-capture surfaces produced one real row
  in five months; discipline does not survive contact.

## Decisions requested

- [x] Approve the two child directives as filed. (Noah, 2026-08-20 — borg:5 building K1-K3.)
- [x] GitHub: PR descriptions + declared chains yes, Projects boards no, issues deferred. (Noah, 2026-08-20.)
- [x] Obsidian: no conversion; optional read-only lens experiment, Noah-owned. (Noah, 2026-08-20.)

## Ship definition

Both child directives assimilated; one week of real use in which every substantive deliverable arrived via a
side-pane doc or linked map rather than a long chat reply.
