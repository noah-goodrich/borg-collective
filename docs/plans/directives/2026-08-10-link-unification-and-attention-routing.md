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

## The problem, observed live (2026-08-10)

The `1:orchestrator` tmux session is the case for this directive. After a week away, it spent 51 seconds of
model time reconstructing, by hand, a dependency picture that spanned the `infrastructure`,
`warehouse-permissions`, and `o-warehouse` repos plus Jira: an 8-step chain gated on `#2564`, a stacked-PR
restructure (`#2566` rebased onto `#2564`), a competing P0 (`PROJ-1365`, due 2026-09-01, migration not yet started),
and a correction retracting a dependency it had previously asserted.

**None of that was persisted.** It exists in a tmux scrollback. The next session reconstructs it again, and the
human spent "a good portion of today" doing the same reconstruction in parallel.

The capture principle from the cairn decommission applies directly (CLAUDE.md, Learned): *build capture that
derives from an artifact the agent already produces; never build capture that asks the agent to volunteer.* The
orchestrator's chain analysis **is** an artifact it already produces, every session, unprompted. Mining it into
the spine is derived capture. Adding a "please record your dependency findings" step would be volunteered
capture, and four shipped attempts at that pattern produced one real row in five months.

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
- [ ] C6 — **Two ranking axes, presented side by side, never collapsed into one number:** *most things unblocked*
      (downstream unblock count) and *highest stakes* (nearest hard deadline, weighted by remaining work). Where
      they disagree, show both and say they don't compete for the same hours.
  - Verify: with fixture data where project A unblocks 4 items and project B has a P0 due in 3 weeks at 0%
    complete, `borg link` surfaces **both**, labelled, rather than picking one.
  - **Falsified the original version of this criterion.** It read "ranked by downstream unblock count, ties break
    on recency." Observing the live `1:orchestrator` session showed recency is not the tiebreak and stakes is not
    a tiebreak at all — it is a co-equal axis. The orchestrator's own words: *"Most things unblocked → push
    #2564. Highest stakes → the keypair e2e. They don't compete for the same hours; the first is a git
    restructure, the second is a test run."* Deadlines are not currently in the model anywhere.
- [ ] C7 — Chain data derives from the existing `story.json` `blocked_by` edge model. No new schema, no second
      source of truth.
  - Verify: no new persisted file is introduced; the chain builder reads the merge-tree spine.
- [ ] C7a — **Staleness is surfaced, loudly.** `borg link` states how old the spine is and refuses to present
      chains as current when it exceeds a threshold.
  - Verify: with `story.json` older than the threshold, output carries an explicit staleness warning and the
    refresh command.
  - Rationale: the spine is dated **2026-07-28T16:15Z — 13 days stale** as of filing, which brackets a week of
    vacation exactly. It already spans repos and sources correctly (`keypair-migration` alone joins
    `o-warehouse#*`, `warehouse-permissions#*`, and Jira `DE-*`), but it has no knowledge of `infrastructure`
    #2564/#2566 — the exact PRs the orchestrator spent 51 seconds reconstructing by hand this morning. **A stale
    spine is worse than no spine, because it looks authoritative.**
- [ ] C7b — The edge model distinguishes **stacked-branch** dependencies from **blocked-by** dependencies.
  - Verify: fixture data with a stacked pair renders differently from a blocking pair.
  - Rationale: `#2566` is rebased onto `#2564` — that is a different relationship from "A blocks B," it implies a
    rebase-order constraint, and getting it wrong is expensive. From the orchestrator: *"a careless force-push
    has already cost you Kelly's fix once."*
- [ ] C7c — Edges carry **provenance** (which source asserted them, when), so a wrong edge can be found and
      corrected rather than silently propagated.
  - Verify: `borg link --json` includes a source and timestamp per edge.
  - Rationale: the orchestrator had to publish a correction — *"I told you the missing ontra-dms-
    AdministratorAccess profile was step 0 and gated everything. That was wrong."* That is a false edge in a
    mental graph, discovered late, with no way to check it. Provenance is what makes an edge falsifiable.

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
