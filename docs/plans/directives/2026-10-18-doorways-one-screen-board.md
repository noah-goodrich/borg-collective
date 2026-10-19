# Directive: Doorways, a one-screen board painted verbatim
*Filed: 2026-10-18*

- Plan-slug: `2026-10-18-doorways-one-screen-board`
- Status: Approved (Noah, 2026-10-18, via /borg-plan)
- Tracking issue: https://github.com/noah-goodrich/borg-collective/issues/439
- Research: `docs/research/2026-10-18-terminal-output/evaluation.md`

## Problem

Inside Claude Code you never see `borg link` itself.

- `/borg-link` pipes a jq projection of `borg link --json` to the model, and the model writes new prose every time. The CLI's layout never reaches the screen.
- The CLI page itself is not one screen. On 2026-10-18, `borg link --overview` printed 803 lines. STACKS and QUEUED took 93% of them, and 264 lines ran past 80 columns.
- The page contradicts itself:
  - `▸ NEXT  nobody looked` printed directly above a filled `▸ WAITING ON YOU`, while the STACKS header on the same page said `0 unresolved`.
  - The repository page for borg-collective said `nothing waits on you`, while `borg next --rows --json` held two YOU rows for that repository (#436 and #437).

A screen that contradicts itself costs more trust than any layout flaw, and a prose re-render cannot be contract-tested.

## Objective

borg's doorways become one-screen terminal text, built the same way on every run. You see that text verbatim inside Claude Code and Cortex Code, and each rung of the output ladder sits on a terminal surface that was measured on 2026-10-18.

## Decisions

- **The board path paints CLI text, and questions still get prose.** This reverses the rules in `skills/borg-link` ("Answer; do not re-render", "never re-render the CLI's table") for the board only.
  - Evidence (experiment X1): fenced blocks keep exact alignment at 80 and 100 columns in the fullscreen TUI. Skill `!` injection is not shown to the user, but the model can reproduce it.
  - Cost: the paint path drops the Bash call, and with it one full-context re-read per run. The link-up-prepare directive measured those turns at a median 350k-token context. The page is about 50 lines, against a jq projection of about 30 KB.
- **The closed vocabulary is the comms-delivery S6 house grammar.** S6 already says ADOPT for `borg link` and `/borg-next`, so this directive implements S6's grammar there. It does not start a third grammar.
- **The glance line reaches Claude Code through an opt-in `borg setup --statusline`** (Noah, 2026-10-18). `borg setup` never writes `statusLine` unasked. The tmux segment is documented for the dotfiles repo.
- **Pacing:** S1 ships on 2026-10-18. S2 to S5 start after the 2026-10-20 usage reset (Noah, 2026-10-18).

## Relationship to other directives

- `2026-08-11-viz-3-cross-repo-chains.md` stays the single spec for ordering, tiers and chains. This directive is presentation only: page budgets, vocabulary, legend and the paint path.
- `2026-10-05-board-chooser-and-trains-ux.md` keeps the screen shapes and trains (its AC5). This directive settles the glyph grammar that the board-chooser directive marked provisional.
- `2026-10-18-arrival-brief-on-sessionstart.md` (#437) is rung 1. It must read the same `borg next --rows` rows as AC4 here.
- Cortex plugin validation errors go to `2026-10-15-borg-in-cortex.md`, not here.

## Acceptance Criteria

- [x] **AC1: The page never contradicts itself.** Shipped in #438.
  - On a fixture where every manifest is swept and none is ready, `▸ NEXT` never says `nobody looked`. Find the cause on the live board first: why `render._next_tally` reports unlooked while the STACKS header says `0 unresolved`.
  - A repository page never prints `nothing waits on you` while `borg next --rows --json` holds a YOU row for that repository. It prints a count line pointing to `borg next` instead. The rule that the repository page is strictly about its own directory stays.
  - Verify: new cases in `borg_core/link/test_render.py`, failing before the fix. Then `borg link borg-collective` while a borg-collective PR waits on you.
- [x] **AC2: The page fits one screen.** Shipped in #440: the expand command is `borg link --overview --full`; live `borg link --overview` is 50 lines, widest line 100.
  - Outside REPOSITORIES, the Queen page is at most 30 lines however many stacks and directives exist. STACKS and QUEUED render as counts plus the command that expands them.
  - Every line is at most 100 visible columns.
  - A one-line legend names each glyph.
  - Status words come from one closed set defined once in code, and the legend and the contract test both read it.
  - All repositories stay on the board, because L4 idle-collapse was rejected.
  - Verify: a screen-contract test over fixtures with 1 and 40 stacks. Then `borg link --overview | wc -l` is at most 50 on the live registry.
- [x] **AC3: `/borg-link` paints the page verbatim.** Shipped in #441: the page is injected by one line, the `--json` path moved to `skills/borg-link/references/questions.md`, and the repository page is fitted to 100 columns in IN FOCUS. A line of exactly 100 columns wraps in a 100-column TUI (code-block gutter); it aligns at 104.
  - The skill injects the CLI page with `!` preprocessing, with color off. The model reproduces it in one fenced block and adds at most 2 lines below it.
  - The paint path makes no Bash call. Questions about the board still get prose.
  - Where injection is not expanded (Cortex), the skill falls back to one Bash call.
  - The reversal is recorded in `skills/borg-link/references/rationale.md`.
  - Verify: a contract in `tests/skill_borg_link.bats`, plus one tmux capture of the TUI.
- [ ] **AC4: One glance line.**
  - `borg next --line` prints one line of at most 80 columns. It reads cached rows only, makes no network call, and takes at most 100 ms at p95.
  - It names the same item as the board's first WAITING ON YOU row.
  - A statusline script, installed only by `borg setup --statusline`, and a documented tmux format string both use it.
  - Verify: bats with a timing bound, plus a parity test of `--line` against the board on the same fixture.
- [ ] **AC5: Chooser cards fit the preview box.**
  - In `/borg-next`, each AskUserQuestion option carries a preview card of at most 6 lines by 42 columns, ending in the exact command.
  - The card carries `next_step`, because option descriptions are hidden while previews show (X1).
  - Cortex has no previews, so it keeps descriptions.
  - Verify: a skill contract in bats, plus one tmux capture.
- [ ] **AC6: Nothing breaks.** This applies to every slice.
  - Full pytest and bats pass.
  - `--json` stays at `DOCUMENT_VERSION` 2 with no key removed.
  - `picture-fork.expected`, `picture-crossing.expected` and the `--porcelain` golden are unchanged.
  - Verify: `make test`, plus a PR diff that leaves those files untouched.

## Testability

- AC1, AC2 and AC4 keep their logic in `borg_core/link/render.py` and `borg_core/nextpick`. Each one lands its pytest first and the fix second.
- AC3 and AC5 are skill text, checked by bats contracts and one TUI capture each.
- The statusline script and the tmux string are thin shell over `borg next --line`.
- Every golden that AC2 regenerates gets a line-by-line review in its PR, never a blind regeneration.
- Fixtures are synthetic. The live board carries private-repository titles, and this repository is public.

## Slices (one PR each, merged on the owner's word)

1. S1: AC1, plus this directive, its stack row and the research record.
2. S2: AC2.
3. S3: AC3. Needs S2, because painting the 803-line page verbatim would be worse than today.
4. S4: AC4.
5. S5: AC5.

## Scope Boundaries

- NOT building ordering, tiers or chains (viz-3).
- NOT building trains (board-chooser AC5).
- NOT building the arrival brief (#437).
- NOT building an STE lint for model prose. The rules apply to CLI text only.
- NOT deciding required checks on main or native deny rules. Those are Noah's decisions, recorded in the research.
- NOT committing raw captures of the live board.
- If done early: ship, don't expand.

## Ship Definition

Each slice ships the same way:

1. Its PR's checks are all `pass` by `gh pr checks --json bucket`.
2. Noah leaves a review comment.
3. The PR merges.

The tracking issue lists every slice's PR.

## Timeline

Target: S1 on 2026-10-18. S2 to S5 in the week of 2026-10-20.

Estimated effort: about 3 sessions.

## Risks

- **Goldens.** Shrinking the page regenerates `test_render` goldens, and a blind regeneration would hide a regression.
- **Public repository.** The real board carries private-repository PR titles, so fixtures and captures must be synthetic or scrubbed.
- **Injection failure.** A non-zero exit inside skill `!` injection aborts the skill in Claude Code, and Cortex does not expand injection at all. The fallback needs its own test.
