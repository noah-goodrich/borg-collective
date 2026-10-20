# borg link --brief

Rules moved verbatim from the top-level CLAUDE.md. They guard _borg_print_briefing in borg.zsh, a root file.

- **`--brief` is a presentation mode of the document, not a second path (AC1, 2026-08-27)**:
  `_borg_print_briefing` (borg.zsh) builds the `borg link` document ONCE — the same
  `_borg_py borg_core.link.cli --json` call every other dispatch arm makes, with `--all`/`--local`
  forwarded identically (`--local` pinned by subprocess count, `--all` by "--all puts archived
  projects in the prompt, and its absence keeps them out") — projects that JSON into the narrative
  prompt with one `jq`, and when the
  narrative fails pipes **those same bytes** back through `borg_core.link.cli --render-document`,
  a non-mode seam gated in `main()` above `_mode`. One sweep, one `generated_at`, two consumers. It
  used to be 177 lines of a second registry walk that never reached Python at all, which is why AC1
  stayed unticked with both verify clauses passing.
  **It IS still a different page, and the AC2 line above is qualified rather than rescued.** The
  narrative path prints prose: no cube, none of the seven `▸` sections. What the fold bought is that
  the prose is now a *rendering of the same document* rather than of a second board, and that the
  FALLBACK is the real page byte for byte. "Never a different page" holds for every invocation of
  `borg link` except `--brief`'s success path; do not read the AC2 line as covering it.
  Four rules follow. (1) **Never re-derive here.**
  A `borg_registry_with_state` call inside that function undoes the fold. (2) **Never rebuild for the
  fallback.** A second `--json` call would re-read the clock and re-sweep, so the page could disagree
  with the prompt it fell back from — two truth levels inside one invocation. **Nor may that render
  fail quietly**: a failed fallback page names the child's stderr on OUR stderr and returns non-zero,
  which `borg link --brief` propagates — pinned by "a failed fallback render names its reason on
  stderr and exits non-zero". (3) **The `claude -p` call stays in zsh.** `borg_core/proc.py` DEVNULLs
  stderr and returns `None` (not rc 124) on timeout, so moving it silently deletes two pinned
  contracts: the reason line's captured stderr, pinned by "fallback with nonzero exit prints a reason
  line naming the exit code", and the timeout branch, pinned by "--brief renders the document when
  claude times out" — which lives in the sweep suite, not the briefing one, because the timeout
  branch is only reachable where a sweep genuinely runs. (Named by CASE rather than by file:line: the
  two are in different suites and both files' numbers drift on every insertion.) (4) **Every
  scope-dependent list on the wire goes through
  the projection's `$breadth` binding**, which transcribes `render._scoped_rows`: `--json` always
  carries the registry-WIDE `directives`/`assimilated` (`cli.py`'s `need_aggregate`), and the human
  page narrows them to `focus` in repository scope — so a projection reading the top level
  unconditionally puts a different QUEUED count in the prompt than on the page it falls back to.
  That shipped once, measured at 141 aggregate directives against 0 focused, and is pinned by
  `tests/briefing.bats`'s "in repository scope the prompt's QUEUED/SHIPPED match the page's".
  Sweep parity is asserted by **subprocess count** in
  `tests/link_sweep.bats`, never by reading the arm.

## The arrival brief (SessionStart, `arrival.py`)

`render.next_action` is `_waiting_facts` plus `_next_action_line` with a `reserve` of columns for the owner tag, so the brief's `next` and `/borg-link`'s last line cannot disagree (`test_arrival.py` compares them on one fixture). The renderer is pure and on the Domain list; `arrival_hook.py` is the only impure part. The additive `focus.since.head_moves` (commit, merge or pull entries in the git dir's `logs/HEAD` after the newest checkpoint's filename stamp, read by `headlog.py`, no fork) is the one key added; `DOCUMENT_VERSION` stays 2. It counts moves of HEAD, not commits: one pull is one move. The hook's own rules are in `hooks/CLAUDE.md`.
