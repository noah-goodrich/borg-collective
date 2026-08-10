# Directive: Link Unification + Cross-Repo Chains + Attention Routing
*Filed: 2026-08-10 (supersedes the alert-layer-remediation scope filed earlier the same day)*

Independent work — no parent plan. Filed as a directive because `PROJECT_PLAN.md` is still occupied by the
Story-Lens P1 fix pending the merge of PR #104.

## Objective
Make `borg link` answer the question that actually governs Noah's day — **"what should I do next, given what is
blocking what across repos?"** — and make `/borg-link` a synthesis layer over it rather than a second
implementation. Then route subcritical hook signal into that display instead of into the session.

## The through-line
These look like two jobs and are one. Phase 2's D5 finding is that borg has exactly **one** in-session delivery
channel, so every signal it emits is by construction an interrupt. The fix for that is not smarter hooks — it is
somewhere else for non-urgent signal to land. `borg link` is that somewhere. So the display has to be worth
looking at *before* the interrupts can stop shouting.

## Prior art that constrains this
- **`docs/research/2026-07-28-dependency-graph-tool/recommendation.md`** — the chosen design (Option E, Frozen
  Atlas) for the *rich* cross-repo view. This directive is **not** that build. It is the CLI/skill layer, which
  must not contradict it: same `story.json` spine, same `blocked_by` edge model, same unblock-rank concept.
- **PR #104** — the Story-Lens, which is Option C, that design's pre-committed fallback.
- **Phase 2 playbook rules D1-D8**, in particular the corrected **D2**.

## The corrected D2 governs the layout
`borg link` is an **append-only medium**. The viewport auto-scrolls to the end of output; the eye lands at the
bottom, beside the prompt, and earlier lines have scrolled away. Therefore:
- Context, counts, and inventory print **first** — they scroll away harmlessly and stay recoverable by scrolling.
- The answer prints **last**, in the final 3-5 lines before the prompt.
- Decoration (the Borg cube) is **fine where it is** and should not be removed. Printed first, it occupies the
  cheapest region on the display. This reverses an earlier finding; see `04-empirical-test.md`.

## Acceptance Criteria

### Unification
- [ ] C1 — All `cmd_link` aliases are removed: `ls`, `status`, `hail`, `brief`, `briefing`, `refresh`. `borg
      link` is the only name.
  - Verify: `grep -nE '^\s+(ls|status|hail|brief|briefing|refresh)\)' borg.zsh` returns nothing in the top-level
    dispatch; `borg ls` exits non-zero with an unknown-command message.
- [ ] C2 — Every in-repo reference to the removed names is updated: `borg help`'s alias block,
      `skills/borg-switch/SKILL.md` (2 refs), and `CLAUDE.md`. `cmd_switch`'s internal `cmd_ls --porcelain` call
      either keeps working or is migrated deliberately — not left dangling.
  - Verify: `grep -rn 'borg ls\|borg status\|borg hail' --include='*.zsh' --include='*.md' --include='*.sh' .`
    returns only historical references in `docs/plans/assimilated/` and `.borg/checkpoints/`.
- [ ] C3 — `borg link --json` emits the full reconciled document, mirroring the `borg recon --json` contract.
  - Verify: `borg link --json | jq -e '.projects and .generated_at'` exits 0.
- [ ] C4 — `/borg-link` is rewritten as a synthesis layer over `borg link --json`, matching the `/borg-recon`
      pattern. The direct-file-read path survives **only** as an explicit fallback for when `borg` is not on
      PATH (the drone-container case that motivated the original design).
  - Verify: `SKILL.md` instructs running `borg link --json` first; the file-read section is clearly marked as
    the fallback and states its trigger condition.

### Cross-repo chains — the actual objective
- [ ] C5 — `borg link` surfaces cross-repo dependency chains, not just per-project status. A chain shows its
      members in order, which end Noah owns, and how many downstream items are idle because of it.
  - Verify: with fixture data containing a known A→B→C chain spanning three repos, the chain renders as one
    line with correct membership and a correct downstream count.
- [ ] C6 — The recommended next action is ranked by **downstream unblock count**, not by recency. Ties break on
      recency.
  - Verify: with fixture data where the most-recently-touched project unblocks nothing and an older one unblocks
    two items, `borg link` recommends the older one.
- [ ] C7 — Chain data derives from the existing `story.json` `blocked_by` edge model. No new schema, no second
      source of truth.
  - Verify: no new persisted file is introduced; the chain builder reads the merge-tree spine.

### Layout
- [ ] C8 — Output is bottom-anchored per the corrected D2: inventory first, answer in the final 3-5 lines.
  - Verify: `borg link | tail -5` contains the recommended next action and its command.
- [ ] C9 — Idle projects collapse to a count line rather than one row each, and the directive-title extraction
      no longer emits `---` for horizontal rules or frontmatter delimiters.
  - Verify: `borg link | sed 's/\x1b\[[0-9;]*m//g' | grep -c -- '---$'` returns 0; idle projects are not
    printed one-per-line.
- [ ] C10 — Re-measure against D1 and record the line count in the PR body whether or not it fits one screen.
      Baseline is **83**.
  - Verify: `borg link | wc -l`.

### Attention routing
- [ ] C11 — A non-interrupting channel exists: subcritical hook signal is written to a session-scoped log
      rather than injected into context, and surfaces in `borg link`.
  - Verify: a hook writing to the channel produces no `additionalContext`
    (`... | jq -e '.hookSpecificOutput.additionalContext'` exits non-zero) and its signal appears in
    `borg link`.
- [ ] C12 — `tool-count-nudge` no longer fires on a raw call count: it either fires on a condition that
      distinguishes a healthy session from a thrashing one, or it is retired to the C11 channel. **Retiring it
      is a success, not a failure.**
  - Verify: `grep -n 'COUNT >= 75' hooks/tool-count-nudge.sh` returns nothing; the replacement trigger is
    documented in the hook header.
- [ ] C13 — `pre-commit-remind` fires only when it has reason to believe `/simplify` has not run for the code
      being committed. Preserve the existing `PROJECT_PLAN.md` conditional — it is already the right pattern.
  - Verify: a commit in a session where `/simplify` has run produces no reminder.
- [ ] C14 — Regression: full bats suite passes, and every touched hook exits 0 on empty/malformed stdin.
  - Verify: `bats tests/*.bats` exits 0; `echo '' | hooks/<name>.sh; echo $?` returns 0 per touched hook.

## Scope Boundaries
- NOT building the Frozen Atlas (Option E). This is the CLI/skill layer. It must stay compatible with that
  design, not preempt it.
- NOT touching the three blocking guards (`bash-guard`, `borg-supabase-guard`, `borg-dispatch-guard`). They pass
  D4 cleanly — their correct response varies with the alert, which is what D4 exists to permit.
- NOT touching the seven silent/lifecycle hooks. They do not consume in-session attention.
- NOT removing the Borg cube. Corrected D2 exonerates it.
- NOT building an interrupt-rate ledger. D7 says the budget is real and unmeasured; measuring it is separate.
- If done early: ship, don't expand.

## Ship Definition
PR opened against main, CI green, `borg link` line count recorded in the PR body, all touched hooks verified
fail-open on bad input.

## Timeline
Two sessions. C1-C4 (unification) and C8-C10 (layout) are one; C5-C7 (chains) and C11-C13 (routing) are the
second. C5-C7 is the objective — if only one session happens, do that one.

## Risks
- **C5-C7 may reveal the registry is the wrong substrate.** `borg link` reads the registry, which has no
  dependency model; the chains live in `story.json`, which is populated by the merge-tree pipeline and currently
  only exists on the PR #104 branch. If the spine is not reachable from a clean main checkout, C5 blocks on
  merging #104 — surface that immediately rather than duplicating the model.
- **C12 may not have a good answer.** "Distinguishes a healthy session from a thrashing one" is easy to state
  and hard to compute from hook-visible state. If no honest signal exists, retire the nudge rather than invent a
  proxy that fails D6 the same way the call count does.
- **C1 has blast radius beyond this repo.** `borg ls` is muscle memory and may appear in personal scripts,
  aliases, or tmux bindings outside this repo. Consider a deprecation period that prints a pointer rather than
  failing outright — but that is a judgment call for Noah, not a default.
- **Hooks are fail-open by contract and silent when they break.** Every hook touched here runs on every session
  on this machine. C14 is not ceremony — `borg-link-down.sh` already hit exactly this failure mode once
  (CLAUDE.md, Learned).
