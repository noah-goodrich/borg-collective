# Directive: Link Unification + Bottom-Anchored Layout
*Filed: 2026-08-11*
*Revised 2026-08-12: RESEQUENCED. This is now the SECOND half of a two-pass split. The Python-core port
ships first as `PROJECT_PLAN.md` ("Port `borg link` to the Python Core, behavior unchanged"), which carries
L1, L2, and L6. What remains here is the layout redesign — L3 and L5 — against a stable Python target.
Reason: a port needs contract tests that pass UNCHANGED, and L3/L5 rewrite the exact output those assertions
pin; parity cannot be proven against a moving target. **L4 is withdrawn** — verified empirically that the
`---` defect does not reproduce (`borg link | grep -c -- '---$'` returns 0; 0 of 118 directive files across
`~/dev` begin with `---`). **L5's baseline is 160 lines, not the 83 recorded below.** Do not start this
directive until the port has shipped.*

Independent project. Carved out of `2026-08-10-link-unification-and-attention-routing.md` (now severed — it
conflated four concerns and two of them have shipped or been superseded). This is the surviving **display**
half; the hook half is `2026-08-11-attention-routing.md`.

## Objective
Make `borg link` the single implementation of project intelligence — one command, one JSON contract, one
renderer — and lay its output out so the answer lands where the eye actually lands.

## Why
`/borg-link` is the **only** borg skill that reimplements rather than delegates. `/borg-next` runs `borg next`,
`/borg-switch` runs `borg switch`, `/borg-recon` is explicitly "the synthesis layer on top of the `borg recon`
engine" and consumes `borg recon --json`. `/borg-link` instructs the opposite: *"Read the borg data files
directly. Do not shell out to `borg link`."* That divergence is how a Phase-2 empirical test ended up critiquing
`borg ls` as a display Noah never runs, without realising it was the same command as `borg link`.

`cmd_link` already has `--porcelain` (`borg.zsh:245`), so most of the plumbing exists — it just isn't JSON and
the skill ignores it.

## Sequencing against the viz directives
- **`viz-1-awaiting-you-tier` should land first.** It is higher value and it also writes to the landing region.
  This directive must not undo its tier.
- **This is not blocked on `viz-2`/`viz-3`.** It works on whatever the spine currently holds.

## Acceptance Criteria

- [ ] L1 — `borg link --json` emits the full reconciled document, mirroring the `borg recon --json` contract.
  - Verify: `borg link --json | jq -e '.projects and .generated_at'` exits 0.
- [ ] L2 — `/borg-link` is rewritten as a synthesis layer over `borg link --json`, matching the `/borg-recon`
      pattern. The direct-file-read path survives **only** as an explicit fallback for when `borg` is not on
      PATH — the drone-container case that motivated the original design.
  - Verify: `SKILL.md` instructs running `borg link --json` first; the file-read section is clearly marked as the
    fallback and states its trigger condition.
- [ ] L3 — Output is bottom-anchored per the corrected **D2**: inventory and context first, the answer in the
      final 3-5 lines before the prompt.
  - Verify: `borg link | tail -5` contains the recommended next action and its command.
  - D2 was corrected on 2026-08-11: terminal output auto-scrolls, so the eye lands at the **bottom**. Anything
    printed first is in the cheapest region, not the most valuable. The Borg cube is therefore **fine where it
    is** and must not be removed.
- [ ] L4 — Idle projects collapse to a count line rather than one row each, and the directive-title extraction
      no longer emits `---` for horizontal rules or frontmatter delimiters.
  - Verify: `borg link | sed 's/\x1b\[[0-9;]*m//g' | grep -c -- '---$'` returns 0; idle projects are not printed
    one-per-line.
  - Measured 2026-08-10: **30 of 46** directive bullets rendered as `---`, and they sat in the landing region.
- [ ] L5 — Re-measure against **D1** and record the line count in the PR body whether or not it fits one screen.
      Baseline is **83 lines**. If it still doesn't fit, say so rather than moving the goalposts.
  - Verify: `borg link | wc -l`.
- [ ] L6 — Regression: full bats suite and the macOS contract leg stay green. `tests/cli_contract.bats` gains a
      case for `--json` validity.

## Scope Boundaries
- NOT the awaiting-you tier (`viz-1`), the spine generator (`viz-2`), or chains/ranking (`viz-3`).
- NOT the hook/attention-routing work (`2026-08-11-attention-routing.md`).
- NOT removing the Borg cube. The corrected D2 exonerates it.
- NOT re-adding any removed alias. `ls`/`status`/`hail`/`brief`/`briefing`/`refresh` are gone as of #112.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green including the macOS leg, `borg link | wc -l` recorded in the PR body.

## Timeline
One session. L1/L2 are the substance; L3-L5 are output changes.

## Risks
- **L2 changes the skill Noah runs constantly.** If `borg link --json` is wrong or slow, the daily path degrades
  immediately. Ship L1 with a contract test before touching the skill.
- **The drone-container fallback is easy to break silently** — it only matters in an environment that is not
  where this gets tested. State its trigger condition explicitly in the skill and, if practical, exercise it.
- **L4's collapse could hide something Noah wants.** "18 idle" is only better than 18 rows if the count is
  trustworthy. Keep `--all` as the escape hatch and mention it in the output.
