# borg_core/link/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md. Claude Code loads this file when a file under borg_core/link/ is read.

- **Checkpoints are UNION-READ across a repo group, never merged on disk**: `read_checkpoints` takes
  the group rather than a path, because `borg_core/link/shell.py`'s readers return filenames and
  name-sort them — so "the latest checkpoint" used to be a different document depending on which
  directory you asked about (measured: 4 stores for one repo, 3 filenames existing twice with
  different bodies, two of those written in the same minute by two sessions). **Do not consolidate
  the stores by moving files**: a merge-write is data loss on exactly those collisions. **Filename
  equality is not document equality, and this cuts both ways.** policy-repo gitignores
  `.borg/`, so its collisions are independent writes and both sides must survive, bylined
  (`2026-09-25-1704.md @policy-repo-atlas`). borg-collective TRACKS `.borg/checkpoints/` via
  its own `.gitignore` carve-out, so a worktree of it holds 115 colliding filenames of which **114
  are the same git-tracked document** — a union trusting filenames renders this repo's own page with
  114 duplicate rows and pushes the real history off it. So `core.dedupe_checkpoints` collapses rows
  by a CONTENT digest, the same fact `manifest.shell._manifest_identity` already hashes bodies for
  and for the same one-line reason: a git worktree is the live case. The hash is **lazy and
  bounded** — charged only once a filename has already been kept, each row hashed at most once, the
  walk stopped at the cap — so a collision-free group pays nothing and the 115-collision group costs
  ~19ms, not 230 reads. The byline appears only when the rows actually being printed span more than
  one repository; an unreadable body yields no identity and its row is KEPT, because a permissions
  error must not render as an empty history.
- **`borg link` is ONE renderer, not three (AC2)**: there is a single human renderer,
  `render.document()`, which iterates a module-level `SECTIONS` tuple — header, `▸ IN FOCUS`,
  `▸ REPOSITORIES`, `▸ STACKS`, `▸ QUEUED`, `▸ SHIPPED`, `▸ NEXT`, `▸ SIGNALS`, `▸ WAITING ON YOU` — with
  **no branch on mode or emptiness**, and since 2026-10-13 scope picks WHICH tuple (see the reversal
  below). (`▸ NEXT` is AC4's, inserted between SHIPPED and SIGNALS so the page
  reads history-then-future; adding it turned the spine test red on purpose, which AC2's directive
  chose over reserving an always-empty slot in advance.) `render.overview` and `render.deep` are
  deleted, and `--deep` is parsed and ignored (kept in the parser because borg.zsh's positional `link`
  arm — grep `_link_py_args=(--deep)`, the one live caller, serving every `borg link <repository>` and
  `drone link` — still passes it, and argparse exiting 2 there is a blank pane with nothing on stderr.
  Line pins are deliberately absent: four sites all said `borg.zsh:3111`, which matched neither main
  nor the branch that "corrected" it.) **AC2's rule — "scope changes which ROWS
  a section prints, never which sections exist; the contexts differ in breadth only" — WAS REVERSED
  2026-10-13 for repository scope, on purpose (Noah: the overview belongs to the Queen).** Standing in a
  worktree of `borg-collective`, `borg link` printed the whole `REPOSITORIES` board, the repository's pull
  requests and its STACKS, and led with a sibling worktree's checkpoint: a page about "here" that was about
  everywhere. Three root causes, each now closed: the checkpoint and summary reads were a repo-group UNION
  (`core.repo_sources`; `focus` now reads `worktree.own_source`, the directory alone), the board was
  scope-invariant, and the repository-level sections were keyed on the GitHub slug, which every worktree of a
  repository shares. Now `render._sections_for` picks one of two lists. The Queen
  (`scope.kind == "orchestrator"`: cwd equal to `BORG_ORCHESTRATOR_ROOT`, or `--overview` from anywhere) prints
  `SECTIONS`, and its board collapses worktrees under their repository (group by the registry `repo` key, via
  `worktree.repository_groups`) instead of counting each as a repository. Inside a registered path prints
  `REPOSITORY_SECTIONS`, STRICTLY that directory: a scope label (`<name> — worktree of <repo>` or `— main
  checkout`), identity (path, branch, worktree-of), live session and status, its OWN checkpoints, its own
  waiting row (the session row only, no repository PR rows), the next-action line, and one line pointing at
  `borg link --overview`. No board, no other worktree or repository, no STACKS, NEXT, QUEUED, SHIPPED, plan or
  SIGNALS. The vocabulary is fixed: a *repository* is the git repo, a *worktree* is a linked checkout
  registered on its own and carrying a project, and the orchestrator session is called the Queen in
  user-facing text while every internal name (`scope.kind` `orchestrator`, `BORG_ORCHESTRATOR_ROOT`, the
  `--json` keys) is unchanged. `--json` keeps EVERY key: the registry-wide ones are untouched and the human page
  simply stops rendering them in repository scope; the only values that changed are `focus.checkpoints`,
  `focus.checkpoint_head` and the summaries, which are now the directory's own, and the one key added is
  `focus.identity` (additive). `DOCUMENT_VERSION` stays 2: no pre-existing JSON key narrowed and
  `skills/borg-link/SKILL.md`'s version gate is untouched. Git identity is read from the git dir's own files
  (`commondir`, `HEAD`), not by forking git, because `--local`'s fork count is a pinned contract. A detached
  HEAD (the HEAD file is a bare commit id) prints `Branch: detached at <short sha>`; the sha rides in the additive
  `focus.identity.detached` key, and `branch` stays a branch name or empty.
  **A cwd that is neither the Queen root nor inside any registered path prints a short hint page, never the
  overview** (`render.UNREGISTERED_SECTIONS`, 2026-10-13): it says the directory is not a registered repository
  and offers `borg add` and `borg link --overview`, and exits 0. The wire keeps `scope.kind` `orchestrator` and
  adds `scope.unregistered: true` (present only when true); `--json` and `--porcelain` still carry the whole
  document from any cwd, and the human mode reads nothing (`cli._document`'s `hint_only` skips the sweep, the
  manifest glob and the aggregates). `--porcelain` stays scope-blind BY DESIGN (its golden is pinned), so it prints the whole
  registry table from any cwd and does not follow `scope.kind`: do not expect it to narrow in repository scope.
  `borg init` is the Queen launcher and always briefs with `--overview`.
  `borg link --brief` follows the page's breadth: at the Queen root the prompt is the board, in repository scope
  it is built only from that directory's identity, own checkpoint, own session row and next action (no other
  registry entry), and in an unregistered cwd it skips `claude -p` and prints the hint page.
- **The Queen's page is held to one screen (doorways S2, AC2)**: `render.PAGE_LINES` (30, counted outside `▸ REPOSITORIES`, blanks included) and `render.PAGE_COLUMNS` (98, every line, measured with `visible_len`). The compact page is `render.SECTIONS`; `render.FULL_SECTIONS` is the same spine with no budget, reached by `borg link --overview --full` (`document(doc, full=True)`). `--all` was checked first and is not "show everything": it only un-hides archived repositories. What the budget changes: STACKS and QUEUED are the note's count plus one `EXPAND_COMMAND` line, NEXT is one line of per-owner counts and `borg next`, SIGNALS prints `_SIGNALS_CAP` lines and the ladder's gap (always last), WAITING ON YOU prints `CHOOSER_OPTIONS` rows and ONE line counting the rest, the masthead is a wordmark and the legend (the cube is gone), the discovery tip moved to the end of the board, and the page ends on its last line. Every line is then cut by `_fit_line` at `PAGE_COLUMNS` with `…`, escape-safe. The board keeps every repository (idle collapse, L4, was rejected) and cuts a displayed name past `_NAME_CAP` so a destination state always fits; `--full` prints it whole. Two things are DEFINED ONCE and read by both the page and `test_screen_contract.py`: `GLYPH_LEGEND` (the legend line) and `STATUS_WORDS` (the closed set of status words), so the test restates neither. The budget never touches `--json` (`DOCUMENT_VERSION` stays 2), `REPOSITORY_SECTIONS` (the shared `_waiting_section` is byte-identical with `cap=None`), `--porcelain` or `picture.py`. A signal wider than the page is cut on the compact page and whole under `--full`.
- **`/borg-link` paints the page verbatim (doorways S3, AC3)**: `skills/borg-link/SKILL.md` injects `NO_COLOR=1 borg link $ARGUMENTS` with `!` preprocessing and the model copies it into one fenced block, so BOTH pages must be plain and one screen wide. `NO_COLOR` strips SGR and OSC-8 (`cli._page`); `test_screen_contract.py` pins zero ESC bytes and at most 100 columns in both scopes. The directory page is fitted in IN FOCUS only (`render._repository_chunk`): the checkpoint body, summary and leg are free text and are cut with `…`, while the pointer, WAITING ON YOU, `Path:` and `Worktree of:` hold commands and refs and are never cut. The TUI's code block has a gutter of about 2 columns, so `PAGE_COLUMNS` is 98 and a painted page fits a 100-column pane (a 100-wide line wrapped at 100 and aligned at 104, measured 2026-10-19). The `--json` path moved to `skills/borg-link/references/questions.md`; the reversal of "do not re-render" is in `references/rationale.md`.
- **`picture.py` is pure; `render.py` is the page**: the topological picture (columns, connectors,
  crossings, glyph seam, OSC-8 links, the `PICTURE_BUDGET` width) lives in `borg_core/link/picture.py`
  and does **no I/O of any kind** — it imports only `re`, `link.grid` and `manifest.core`, takes refs
  plus edges, and returns ANSI rows. `render.py` composes those rows into sections. The split is what
  lets the picture be pinned against `picture-{fork,crossing}.expected`, two HAND-AUTHORED fixtures
  that are never regenerated — an oracle that does not come from the implementation it checks. Keep
  it that way: a subprocess or a file read in `picture.py` destroys that property. **Both modules are
  now on `pyproject.toml`'s clean-arch Domain list** — `render.py` was added 2026-08-28 and was
  unclassified before that, which meant zero import enforcement while `make lint` printed 10.00/10
  (the checker returns early on a file it cannot classify). Each also has an AST import-walk test,
  because W9004's allow-list permits `pathlib`, `json` and `datetime`, so the linter is the coarser
  of the two gates.
- **The picture's width is measured on the `--json` side, checked nowhere pure**: `PICTURE_BUDGET`
  (68) is a constant, so `picture.max_row_width(manifests)` computes the widest row of whatever a
  caller holds, `cli._grid` stamps it as `grid.picture_width`, and `render._width_line` prints one
  `▸ SIGNALS` sentence when it is over. The comparison lives at the impure boundary on purpose:
  raising inside `picture.py` would take out the paths that swallow failure silently, and logging
  would end the purity the hand-authored oracles depend on. `grid.build_grid` cannot own the key —
  `picture.py` already imports `grid`, so the reverse is a cycle. Measure with `visible_len`, never
  `len`: the rows carry SGR and OSC-8 bytes.
- **The `borg link` parity harness's `render` leg was retired 2026-08-27 (AC2/S4)**:
  `bin/link-parity-harness render` byte-compared the current tree against the last zsh renderer at
  `ad99612`. After AC2 that oracle renders a *different document*, so the comparison is
  unreproducible by construction and would print the redesign back as one intended diff. `render`
  survives as a recognized argparse token that exits 2 with the reason and points at the goldens
  that replaced it — same "the artifact that implements the command owns the invariant" altitude as
  the `borg recon` gate below. The `primitives` leg is untouched and still live: its shell originals
  exist verbatim in the file, so it remains a real differential.
