# Directive: Binding Implementation Spec for AC2 — The Topological Grid as the One Renderer
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-25-link-front-door-hardened-spec*
*Filed: 2026-08-26*

**tl;dr** — `render.document(doc)` becomes the single human entry point: a fixed **seven-section spine** whose `▸`
headers are byte-identical in both contexts, where `scope` narrows the ROW SET of the four scope-dependent sections and
never the board, and where the topological picture is a new pure `borg_core/link/picture.py` fed by `parents` /
`children` / `seq` newly carried on every grid node. Every empty section — the modal no-manifest
repository included — renders its header plus exactly one diagnostic placeholder line, which is the
same rule that makes AC2's "differ in
breadth only" mechanically assertable. **`DOCUMENT_VERSION` stays 2 and `skills/borg-link/SKILL.md`'s version gate and
deep-dive whitelist are untouched.** A first-pass design was reviewed blind by three adversarial lenses and returned
twelve blockers; this spec is that design with every blocker's fix folded in, plus five repairs grafted from the losing
designs. The picture's width is bounded by a `PICTURE_BUDGET = 68` invariant asserted against a measured golden, not
against a config string.

---

## 1. The ten decisions

### Q1 — One render entry point

**Decision.** `borg_core/link/render.py` exposes exactly two public callables:

```python
def document(doc: dict) -> str      # THE ONE HUMAN ENTRY POINT
def porcelain(doc: dict) -> str     # machine TSV, UNCHANGED byte for byte
```

`overview(doc)` (`render.py:272`) and `deep(doc)` (`render.py:329`) are **deleted**. Their bodies survive, transcribed
verbatim, as the private section builders `_board_section` and `_focus_section`. `document()`'s body iterates a
module-level `SECTIONS` tuple and joins; it contains no branch on scope, mode, or emptiness.

`--porcelain` is explicitly **outside** "everywhere". It is not a renderer — it is a TSV serializer feeding fzf's
*input list* (`borg.zsh:262` builds the picker input with `cmd_ls --porcelain`, and `borg.zsh:264-269` consumes it with
`--delimiter '\t' --with-nth 1,3,5`). Box-drawing in that stream breaks `borg switch` outright, and it is the same class
of surface as `--json`, which AC2 also does not claim. Leaving `render.porcelain` untouched means
`tests/fixtures/link/link-porcelain.golden` never regenerates and the named case *"contract: link --porcelain prints
nothing at all on an empty registry"* stays green with zero edits — one named consumer saved rather than broken.

`--deep` collapses into repository scope. `_mode()` returns `json | porcelain | human` only. The `--deep` flag stays in
`_build_parser` (`cli.py:258`), **parsed and ignored**, with a comment saying why:
`_borg_link_dispatch`'s positional arm (`borg.zsh:3110-3117`) passes `--deep` on the fzf preview's path,
`bin/link-parity-harness` and
`~/.claude/bin/link-parity-harness` carry byte-copies, and an implementer who deletes the argument makes argparse exit 2
where both `drone status` and the fzf preview swallow the failure silently. The collapse is correct because `scope_for`
(`core.py:341-342`) already resolves `borg link <project>` to `{kind: repository, repository: <project>}` — the document
already says everything `--deep` said, so keeping it as a mode would be a third context with the same data, which is
exactly what "differ in breadth only" forbids.

### Q2 — Where breadth is applied

**Decision: (b), the document stays registry-wide; the renderer narrows — with two corrections the first-pass design
got wrong.**

`DOCUMENT_VERSION` **stays 2**. `core.assemble`'s docstring (`core.py:631-636`) says the bump is owed the moment a
*pre-existing key* narrows. Under this spec none does.

Gating in `cli._document` changes as follows, and the ordering is binding:

```python
scope = core.scope_for(...)                                   # unchanged, cli.py:194-200

need_focus = mode != "porcelain" and (bool(project) or scope["kind"] == "repository")
focus = _focus(project or scope.get("repository") or "", overlaid, moment) if need_focus else None
#      ^ COMPUTED HERE, ABOVE the aggregate block -- see B1/B7 below.

need_aggregate = mode == "json" or (mode != "porcelain" and scope["kind"] == "orchestrator")
cortex_pending = [] if mode == "porcelain" else shell.cortex_pending(now=moment)
```

Three properties, each of which one of the three lenses independently found the first pass violating:

1. **`--json` is scope-independent.** `need_aggregate` fires on `mode == "json"` in *every* scope, so
   `.directives`/`.assimilated` on the machine wire are byte-compatible with v2 from any cwd. This is the actual
   precondition for not bumping the version. `skills/borg-link/SKILL.md:32-33` runs a bare `borg link --json | jq
   ".directives |= (...)"`, and only `borg-collective` carries a `.borg-project` marker, so SKILL.md:74's "no marker +
   no argument → overview" routes that call from *inside* whatever repository the session is in. Scope-gating it would
   report "Queued: 0 directives" for the whole collective at `.version == 2`, which SKILL.md:184 maps to "CLI path.
   Never fall back." A wrong answer, not a missing one.
2. **A requested positional always resolves focus.** `scope_for` (`core.py:341`) honours a positional only when it is
   *in the registry*; an unregistered name falls through to cwd and yields `kind: "orchestrator"`. A purely
   scope-derived `need_focus` therefore deletes the `ProjectNotFound` path for `borg link ghost` from any cwd outside a
   registered repository — exit 0 with a full board instead of exit 1. `bool(project) or ...` preserves it.
3. **Focus follows scope, not argv.** `_focus` short-circuits on an empty positional (`cli.py:56-57`). Gating on scope
   while still passing `project` makes `cd <repo> && borg link` — the modal human invocation — render the IN FOCUS
   placeholder, no `Status:` line, and empty QUEUED/SHIPPED for a repository with directives on disk. Passing
   `project or scope["repository"]` is the fix, and §4's harness renders repository context **both** ways against the
   same golden so no future edit can un-fix it.

**REPOSITORIES is deliberately scope-invariant.** Narrowing the board to the scoped repository breaks three consumers
that read it precisely for a cross-project list: `skills/borg-switch/SKILL.md:9` (`borg link --local --all`, from a
project session's cwd), `borg.zsh:2225`'s 5s `borg watch` redraw, and the fzf preview's own orientation. So "breadth"
is the row set of **IN FOCUS, CHAINS, QUEUED, SHIPPED** — never the board, never the section list, never the order.
`--all` remains the only control over the board's rows. The scoped repository's row is marked with a trailing
`{CYAN}◀{NC}`.

**Latency, against the two hot loops.** `drone.zsh:964` and `borg.zsh:266` both pass a NAME, so both are repository
scope, so both skip the 14-project `directives`/`assimilated` glob exactly as `deep` does today, and read the one
project's collectors the focus block already reads. The `focus`-above-aggregates hoist is load-bearing here: for a tmux
window name that is not a registry key, `_focus` raises before any glob runs, which is today's cost (immediate
`ProjectNotFound`). Net delta on both hot loops: **zero**, plus one small file read (`cortex_pending`, ~40 lines,
`shell.py:760-786`).

### Q3 — Column assignment

**`picture.assign_columns(levels, parents_of, children_of, seq_of) -> dict[str, int]`.** Pure, deterministic, one
top-down pass.

**Precompute.**

- `level_of[ref]` from `levels` — the index IS the level (`manifest_core.levels`, `core.py:829-866`).
- An edge whose parent's level is `>=` its child's level is only producible by `_rank_nodes`' cycle-breaking
  (`core.py:785-826`). Such edges are **excluded** from every step below and recorded in `back_edges`.
- `span_end(n) = max([level(n)] + [level(c) for c in children_of(n) if level(c) > level(n)])`. Computable before any
  column is assigned, which is what breaks the apparent circularity in reserving a skip-level segment.
- `used: dict[int, set[int]]`, initially empty.

**For each level `L`, in increasing order:**

Place the level's nodes in this order — nodes with an already-placed parent first, keyed
`(primary_parent_column, seq, ref)`; then parentless nodes keyed `(seq, ref)` — where `primary_parent(n)` is the parent
minimising `(column, seq, ref)`.

For each node `n`:

1. **Join centering.** If `n` has ≥ 2 placed parents: `preferred = sorted(parent_columns)[len(parent_columns) // 2]`
   (the lower median).
2. **Chain inheritance.** Else if `n` has exactly one placed parent: `preferred = column(primary_parent)`.
3. Else `preferred = None`.

Take `preferred` when `preferred is not None and preferred not in used[L]`; otherwise take the smallest non-negative
integer not in `used[L]`.

On placing `n` in column `k`:

```python
for j in range(L, max(span_end(n), L + 1)):
    used[j].add(k)
```

The `max(..., L + 1)` is **binding, not cosmetic**. `span_end(leaf) == level(leaf)`, so the naive
`range(L, span_end(n))` is empty for any childless node and never marks that node's own column used at its own level. A
fork whose children are all leaves — the modal live shape the moment anyone authors `after` on an open frontier — then
places every child in column 0, two nodes claiming one cell. Neither live manifest nor the mock's fork reaches it
(all three of the mock's fork children have children), which is exactly why it needs its own fixture and its own test.

**Why `seq`, and why it is not `ref`.** `seq` is each row's index in `manifest_core.lanes()`' flattened order, already
computed at `grid.py:641-643`. `levels()` publishes within-level order as **ascending ref** (`core.py:841-845`).
Measured on the live `stillpoint/.borg/programs/ingle-t1-cutover.json`: level 0 is
`[stillpoint#37 (cutover), stillpoint#54 (contract)]` — cutover first — while level 2 is
`[ingle#341 (contract), stillpoint#39 (cutover)]` and level 3 is `[reveal#59 (contract), stillpoint#40 (cutover)]` —
contract first — and level 4 swaps back. Placement by within-level index therefore crosses the two lanes four times in
an 8-row picture with no edge crossing anything. Inheritance pins a chain to one column for its whole life; `seq`
breaks the ties inheritance leaves, and it is the only rule that reproduces the approved mock's fork column order
(`platform#420, warehouse#87, infra#12` — ascending ref gives `infra#12` column 0). `seq` is additive inside `.grid`,
which SKILL.md's deep-dive whitelist already admits wholesale, so it costs no version bump and no skill edit.

**Complexity.** `O(V + E + V·C)`, `C` = widest level; the free-column scan is the only non-linear part. Both live
manifests are tens of operations.

**Live manifests.** `borg-collective/.borg/programs/viz-program.json`: 3 refs, 3 levels, one parent each, every
inheritance succeeds → **one column, 3 rows, zero rails**. `stillpoint/.borg/programs/ingle-t1-cutover.json`
(verified by running `declared_refs`/`derive_edges`/`levels` against the live file): 14 refs, **8 levels, 2 columns**;
`contract` holds one column for its 6 rows and `cutover` the other for its 8, no rails anywhere, no lane swap.

### Q4 — Connectors

**Characters:** `│ ─ ├ ┤ ┬ ┴ ┼ ┌ ┐ └ ┘` and nothing else. Selection is a 4-bit lookup,
`_BOX[(up, right, down, left)] -> char`, never a per-case branch.

**Geometry** (fixed-width, one width per manifest):

| name | value |
|---|---|
| `INDENT` | 4 |
| `ID_WIDTH` | 4, fixed (`n1` … `n999`, left-justified) |
| `W` | longest **short ref** in this manifest (see below) |
| `CELL` | `1 (glyph) + 1 (drift slot) + ID_WIDTH + 1 (sep) + W` = `W + 7` |
| `GUTTER` | 2 |
| `PITCH` | `CELL + GUTTER` = `W + 9` |
| column `k` glyph offset | `INDENT + k * PITCH` |
| `PICTURE_BUDGET` | 68 visible columns, asserted |

Every emitted line is `rstrip`ped of trailing spaces before its `"\n"`.

**Short refs.** The picture cell carries `repo#num`, built from `manifest_core.parse_ref`'s 3-tuple; the detail heading
carries the full `owner/repo#num`. This is the approved mock's own rule (`chains-dag-mock.md:16` renders
`platform#400`; `:76` says "Details carry the full ref so `gp` opens the PR from there"), and it is what keeps the live
two-lane picture inside the budget: full refs put `stillpoint-labs/stillpoint#57` at 29 characters and a two-column line
at 79, against a 45-column fzf preview. `picture.short_refs(manifest_grid)` returns the short forms **unless** two
distinct owners share a repo name inside that manifest, in which case it returns full refs for the whole manifest — a
collision would otherwise render two different PRs as the same cell text.

**Edge drawing between level `L` and `L+1`.** An edge `(p, c)` with `level(c) > level(p) + 1` occupies `col(p)` at every
boundary from `level(p)→level(p)+1` through `level(c)-2→level(c)-1`, and **jogs at the last boundary only**
(`level(c)-1→level(c)`). No edge is ever drawn as a diagonal across more than one boundary.

Classify the segments crossing the boundary: `STRAIGHT` when `from_col == to_col`, `JOGGING` otherwise.

- **No jogging segment** → emit ONE stem row: `│` at every crossing column.
- **At least one** → emit **stem, rail, stem**, with two *different* column sets:
  - pre-rail stem = `{from_col of every crossing segment}`
  - post-rail stem = `{to_col of every crossing segment}`

  Stating one set for both rows is the defect that renders `│ │ │` above a fan-out where the mock shows a single `│`.

**Rail row.** `involved = {from_col, to_col} over JOGGING segments`; span `[min(involved), max(involved)]`. For each
column `k` in the span:

- `up(k) = 1` iff some jogging segment has `from_col == k`
- `down(k) = 1` iff some jogging segment has `to_col == k`
- `left(k) = 1` iff `k > min`, `right(k) = 1` iff `k < max`
- **`crossing(k)`** iff `k not in involved` *and* some STRAIGHT segment crosses at `k`

`crossing(k)` → emit **`│`** (the `─` fill continues on both sides: `──│──`). Otherwise `k in involved` →
`_BOX[(up, right, down, left)]`. Otherwise → `─`.

The crossing arm is binding and is the one thing a pure 4-bit mask cannot express: a reserved pass-through interior to a
rail span has `up = down = 1` and, with the fill supplying `left = right = 1`, renders `┼` — which asserts a dependency
that does not exist. Constructed reproduction: rows `a/r#1`; `a/p#2`, `a/q#3`, `a/s#4` each `after: [a/r#1]`; `a/z#5`
`after: [a/p#2, a/s#4]`; `a/w#6` `after: [a/z#5, a/q#3]`. `a/q#3`'s pass-through sits interior to the `L1→L2` rail and
would read as merging into `a/z#5`, which it does not. Neither the approved mock nor either live manifest reaches this
(in both, every pass-through is a rail *endpoint*), so it gets its own fixture and its own test.

**The approved mock's fork case, rendered by these rules** (`W = 12`, `CELL = 19`, `PITCH = 21`, glyph offsets 4 / 25 /
46, line width 65 ≤ 68; SGR and OSC-8 elided):

```
    ✔ n1   platform#400
    │
    ├────────────────────┬────────────────────┐
    │                    │                    │
    ○ n2   platform#420  ○ n3   warehouse#87  ○ n4   infra#12
    │                    │                    │
    ○ n5   platform#431  ○ n6   warehouse#93  │
    │                    │                    │
    └────────────────────┼────────────────────┘
                         │
                         ○ n7   infra#77
```

**CONFIRMED byte-identical to `chains-dag-mock.md:16-26` in every connector row and at every column offset.** The
mock's pitch is also 21 (`1 + 1 + 2 + 2 + 12` cell, 3-space gutter); ours is `1 + 1 + 4 + 1 + 12` with a 2-space gutter.
Same 20 dashes on each run, same `├ ┬ ┐` fan-out (verified cell by cell: col0 `up=1,down=1,right=1` → `├`; col1
`down=1,left=1,right=1` → `┬`; col2 `down=1,left=1` → `┐`), same `└ ┼ ┘` join (col0 `up=1,right=1` → `└`; col1
`up=1,down=1,left=1,right=1` → `┼`; col2 `up=1,left=1` → `┘`), same stem/rail/stem cadence, same lone pass-through `│`
beside the `n5`/`n6` row, same node ids `n1..n7` on the same nodes.

**Two stated differences, both required by the spec text the mock itself carries.** (i) The id field is 4 wide, not 2,
so `n10`+ align — the mock's own later render (`chains.md:36-64`) reaches `n17`. (ii) `●` and `◌` are AC4's; AC2 renders
`○` for every open node (Q5). The mock's *column order* is reproduced exactly — the first-pass design's "deviation (ii)"
is retired by `seq`.

### Q5 — Glyphs without AC4

**Decision.** AC2 renders four glyphs from a total function with **no readiness input**, and its vocabulary line says
`○ open`, never "waiting" — because AC2 cannot know which open nodes are waiting either.

```python
def state_glyph(node: dict) -> str:
    state = node["state"]
    if state == manifest_core.STATE_MERGED:  return GLYPH_MERGED     # ✔  GREEN
    if state == manifest_core.STATE_CLOSED:  return GLYPH_CLOSED     # ✗  DIM
    if node.get("draft") is True:            return GLYPH_DRAFT      # ◌  DIM   (dead in AC2)
    if state == manifest_core.STATE_OPEN:
        return GLYPH_READY if node.get("ready") is True else GLYPH_OPEN   # ● / ○
    return GLYPH_OPEN                                                 # DEFAULT ARM
```

**Drift** is a separate character in the cell's second slot: `!` (RED) replaces the space between glyph and id when a
node is `merged` and any declared parent is not, plus one `drift:` line in that node's detail block naming the parent
and its state.

**AC4's renderer-side change is zero.** It emits `ready: true` from `grid.py` and the `●` branch lights up. `is True`
rather than truthiness is the jq-`//` rule CLAUDE.md records: a missing key and a JSON `false` must read identically,
and a string `"true"` must not. The `●` and `◌` branches ship **dead but tested** — pytest calls `state_glyph` with the
fields present and asserts the glyph — so the coverage floor holds and AC4 flips DATA, not CODE. The same mechanism
defers the glance strip's `>` next-marker, which AC2 omits entirely.

`✗` is a **named addition** to the ratified `✔ ● ○ ◌` set. The github adapter emits three tokens
(`grid.DECLARABLE_STATES`, `grid.py:68`) and the ratified set covers two; without `✗` an abandoned PR renders
identically to a merged one. Truthfulness beats glyph-set purity.

`◌` is unreachable in AC2 because `grid.py` does not emit `draft`. Recorded, not hidden: `isDraft` is already selected
by `_FETCH_NODE` (`grid.py:323`) and emitting it is a one-line AC4-or-later change.

**AC4's golden blast radius, stated honestly.** Both new goldens regenerate. `link-grid-repository` contains `n2/n3/n4`
(open under merged `n1`); `link-grid-orchestrator` contains those *and* `n9` (open under merged `n8`). The first-pass
claim that exactly one golden moves is false against its own fixtures. The four non-grid goldens carry no picture and
do not move.

**Rejected:** reserving an eighth, always-empty section slot for AC4's yours-vs-mine so its diff is a pure append. A
section that renders only a placeholder in every context for a whole release is the exact "reads as broken" failure Q10
exists to prevent. AC4 inserts `YOURS / MINE` between SHIPPED and SIGNALS, the spine test goes red, and that red is the
reviewable event we want.

### Q6 — The `Status:` line and the porcelain TSV

**Both survive with zero consumer edits, and the invariant is structural rather than lexical.**

**Porcelain.** `render.porcelain` is not touched. `_document(mode="porcelain")` narrows nothing, computes no focus, no
aggregates and no `cortex_pending`. `link-porcelain.golden` does not regenerate.

**`Status:`.** IN FOCUS is **section 2 of 7 — above REPOSITORIES and above CHAINS** — and reuses the same
`_label("Status:", status)` call that produces today's line (`render.py:353`), character for character. So
`drone.zsh:964-965`'s `borg link --local "$wname" | grep -m1 'Status:' | sed 's/.*Status:[[:space:]]*//'` is unchanged
and correct.

IN FOCUS sits above the board *deliberately*, and this is a correction to the first-pass ordering. Post-AC2 the page
carries two classes of text the renderer does not control: board summaries (free text from checkpoint debriefs) and PR
titles off the wire. A PR literally titled `fix: Status: line in drone`, or a summary containing `Status:`, poisons
`grep -m1` and renders a stranger's PR title as a session status — a wrong answer under a confident header. Putting
IN FOCUS first makes the extraction correct **by construction against all wire-sourced text**, with no scrubbing rule a
future field can escape. Two supporting invariants: the grid's vocabulary uses `state:` and never `Status:`, and the
board's column header stays `STATUS` (uppercase, colonless).

The fixture deliberately contains a PR titled `chore(auth): Status: normalise the rollout report` so the ordering
invariant has teeth (§4, case B5).

**What changes in the bats cases:** *nothing* in the three named ones. *"link --porcelain prints nothing at all on an
empty registry"*, *"link \<project\> deep dive wraps and indents a summary longer than 70 columns"* and *"drone status
can still extract Status: from the deep dive"* are **not edited** — an edited assertion is not a compatibility proof,
and leaving them untouched turns them into the strongest regression gate available in a commit that is already breaking
every golden. New cases are added *beside* them.

**What changes in `drone.zsh`: nothing, deliberately.** Migrating `:964` onto
`borg link --local --porcelain | awk -F'\t' '$1==w{print $3}'` — one process for the whole loop instead of N, and ~168
fewer `listdir`s per `drone status` — is the right long-term shape and is filed as a parented follow-up. It does not
land in the same commit as its producer.

### Q7 — The golden harness

**Fixtures**, all under `/Users/noah/dev/borg-collective/tests/fixtures/link/`:

| path | what |
|---|---|
| `manifests/auth-hardening.json` | the approved mock's fork, full refs, row-level `after: [refs]`, one gate |
| `manifests/warehouse-rollout.json` | linear, declares rows only in `acme/warehouse`, carries the drift node and the closed node |
| `sweep-acme.json` | `{"since": "2026-05-28", "tracks": [ … one github track with items … ]}` — the fan-out's OUTPUT shape |
| `fetch-acme.json` | `{"nodes": {ref: {state, title}}}` covering every ref the sweep track omits, so zero nodes resolve unknown |
| `picture-fork.expected` | hand-authored character grid, transcribed from `chains-dag-mock.md`, **never writable by `BORG_UPDATE_GOLDEN`** |
| `picture-crossing.expected` | hand-authored, the B6 pass-through-interior-to-a-rail case |
| `link-grid-repository.golden` | NEW |
| `link-grid-orchestrator.golden` | NEW |

Recording the fan-out's **output** rather than the finished grid keeps the Item validator, the resolve ladder, level
assignment and the per-source receipt all in production code (`shell.py:475-502` documents the shape). A fixture of the
finished grid would prove that JSON round-trips.

**Wiring.** A new helper `_assert_link_grid_golden` in `tests/cli_contract.bats` exports **both** seams, **including on
the `BORG_UPDATE_GOLDEN` path**:

```bash
export BORG_LINK_SWEEP_FIXTURE="${LINK_GOLDEN_DIR}/sweep-acme.json"
export BORG_LINK_FETCH_FIXTURE="${LINK_GOLDEN_DIR}/fetch-acme.json"
```

`shell.sweep` reads its seam as its first statement (`shell.py:555-557`) and `shell.start_fetch` reads its own before
anything can fork (`shell.py:669-671`), so zero subprocesses run on either network path.
`BORG_RECON_ADAPTER_PATH` stays pointed at `setup_temp_dirs`' real empty directory (`setup.bash:54`) as belt and braces.

`_assert_link_golden` itself is **not** given the sweep seam, and `setup_temp_dirs` is **not** changed. The four
non-grid goldens have no manifests, so their only sweep-derived text is the deterministic
`sweep: no recon adapters found on <TMP>/no-adapters` warning — which is the live tripwire for
`setup.bash`'s adapter neutralization, and globally exporting a sweep fixture would delete it from every other link
test.

**The scrub gains a second expression.** `shell.py:501` and `shell.py:633` emit
`sweep: replayed from fixture {path} -- no adapter ran` and its fetch twin with the **absolute** path, and those land in
SIGNALS. The fixtures sit under `$BATS_TEST_DIRNAME/fixtures/link/`, **not** under `$BATS_TEST_TMPDIR`, so the existing
single `sed` (`cli_contract.bats:1608`) does not cover them and both goldens would be green only on the authoring
machine:

```bash
sed -e "s|${BATS_TEST_TMPDIR}|<TMP>|g" -e "s|${BATS_TEST_DIRNAME}|<TESTS>|g" "$raw" > "$actual"
```

**A tripwire, before the diff and on the update path too.** A mistyped fixture path degrades to a named warning
(`shell.py:492-493`) and the first `BORG_UPDATE_GOLDEN=1` run freezes that degradation as the oracle — the checkpoint's
"a check pointed at the wrong thing does not fail, it reads as a pass," instance five. So `_assert_link_grid_golden`
runs `borg link --json` with the identical arguments and environment first, and hard-fails on:

```bash
jq -e '.grid.swept == true and .grid.since == "2026-05-28" and .grid.unresolved == 0
       and (.grid.fetch.resolved == .grid.fetch.requested) and (.grid.fetch.requested > 0)'
```

**One harness, both contexts, same fixtures.** `_link_build_grid_ws` git-inits two sandbox repos with real origins
(`https://github.com/acme/platform.git`, `.../acme/warehouse.git`), copies the two fixture manifests into
`<repo>/.borg/programs/`, writes a 7-project registry, mocks tmux, and exports
`BORG_ORCHESTRATOR_ROOT="$BATS_TEST_TMPDIR/ws"`.

- Repository context, positional: `borg link platform`.
- Repository context, cwd: `bash -c "cd '$ws/platform' && zsh '$BORG' link"` — **diffed against the same golden**.
- Orchestrator context: `bash -c "cd '$BORG_ORCHESTRATOR_ROOT' && zsh '$BORG' link"`.

### Q8 — `unknown` never entering `render.py`

**The rule is about vocabulary and source, not about the input domain — and it is restated so it can actually hold.**

The literal `"unknown"` is already in `render.py` **five times**, on lines this spec requires to stay byte-identical:
`:144` (`porcelain`, which Q6 promises not to touch), `:183` (comment), `:184` (`_overview_row`, transcribed into
`_board_section`), `:337` and `:340` (`deep`, transcribed into `_focus_section`). These are jq-parity fallbacks for a
**registry status** — a different field, a different question — and deleting any of them changes the bytes
`link-overview.golden`, `link-deep.golden` and `drone.zsh:964`'s Status column read. A blanket source-text grep cannot
coexist with the design and would fail on the commit that introduced it.

**Binding restatement, in five parts:**

1. `render.py` gains ONE module-level constant, `_JQ_ABSENT_STATUS = "unknown"`, documented as the registry-status jq
   fallback transcribed from `borg.zsh` and **explicitly not** the grid's state token. The four call sites use it
   (`f"({_JQ_ABSENT_STATUS})"` at `:340`). Bytes unchanged; no golden moves for this.
2. `picture.py` contains the literal **zero** times. Where the grid's token must be compared, the renderer imports the
   constant: `from borg_core.link import grid`, then `node["state_source"] == grid.STATE_SOURCE_UNKNOWN`
   (`grid.py:54`). The two modules therefore cannot drift, which a duplicated literal would allow.
3. `state_glyph` has **no** `unknown` branch — three named-state branches and a default arm. `unknown` takes it, and so
   does an injected Jira adapter's `in_progress` or a Slack adapter's `awaiting`. `resolve_state` takes a swept token
   verbatim without checking `DECLARABLE_STATES` (`grid.py:283-294`), so foreign tokens are a live path, not a
   hypothetical. One arm, one behaviour, no `KeyError`.
4. The detail block never prints an unresolved token. `state_word(node)` returns the CONDITION, derived from
   `state_source`, through a dict keyed on `grid.STATE_SOURCE_*`:
   - `swept` → `state:     from the sweep`
   - `fetched` → `state:     from a targeted fetch`
   - `declared` → `state:     from the manifest (declared, may be stale)`
   - `unknown` → `state:     nobody has an answer for this ref (not swept, not fetched, not declared)`

   This also corrects the first-pass mock's `state: github sweep`: **no adapter identity is on the wire.**
   `swept_items` merges every adapter's items first-writer-wins with no back-pointer (`grid.py:203-226`), and
   CLAUDE.md describes injected employer adapters as a live layer. Naming an adapter would be fabricated provenance on the
   one line whose entire job is provenance.
5. SIGNALS renders the COUNT as a sentence, never a token:
   `N of M declared refs unresolved — nobody looked`, from `grid.unresolved` / `grid.declared`, only when `N > 0`.

`--local` (the fzf preview, `drone status`, `borg watch`) opts down from both network rungs by design, so `unknown`
reaches the renderer on the hottest paths in the tree, several times a second. A renderer that crashed on it would take
out the preview pane and the status table. Both a **structural** and a **behavioural** test are required (§4, cases
P18/P19): the structural one alone passes if someone builds the string by concatenation; the behavioural one alone
passes if the renderer silently drops the node. The path is live, not theoretical — `viz-program.json` declares
`"status": "stacked"`, which is outside `DECLARABLE_STATES`.

### Q9 — OSC-8

**Sequence, exactly:**

```
\033]8;;{url}\033\\{text}\033]8;;\033\\
```

OSC 8, empty params, URL, **ST** (`ESC \`, `0x1B 0x5C`); the visible text; OSC 8 with an empty URL to close, ST. ST and
not BEL: ST is the specified terminator, Ghostty / iTerm2 / WezTerm / VTE all accept it, and BEL would put a literal
bell byte into two goldens.

**URL from `owner/repo#num`:** `https://github.com/{owner}/{repo}/issues/{num}`, built **only** from
`manifest_core.parse_ref`'s 3-tuple (`manifest/core.py:174`), never by string surgery on the raw ref. `/issues/` and
never `/pull/`, because GitHub redirects `/issues/<n>` to `/pull/<n>` for a PR — one form is correct for both and the
renderer never has to know which a ref is. This is Noah's global rule for every generated document, and it is also the
injection gate: `parse_ref`'s character class (`_REF_RE`, `manifest/core.py:119`) is the one `recon-adapter-github`
validates against before interpolating an owner into a GraphQL document, so no quote, brace or newline from a
hand-authored ref reaches a terminal escape sequence. An OSC-8 payload is interpreted by the emulator; an unvalidated
ref would be an escape-injection surface, not merely a broken link.

**A ref `parse_ref` rejects renders as PLAIN TEXT** — no link, no error line, no placeholder, no repair.
`picture.ref_url(ref)` returns `""`; `picture.link_ref(ref, text)` returns `text` unchanged. A fabricated URL would
silently link to the wrong repository, which is worse than no link. In practice such a ref cannot reach the renderer
(`validate` rejects it and `_load_manifest` drops the whole file), so the arm exists to keep the function total and is
covered by a pytest case rather than left unexercised.

**Both the picture cell and the detail heading are links.** The cell links the short ref, the heading the full ref.

**Alignment.** OSC-8 sequences are zero-width but they are BYTES. Padding is computed on the VISIBLE text and the wrap
applied after:

```python
cell = glyph + drift + node_id.ljust(ID_WIDTH) + " " + link_ref(ref, short) + " " * (W - len(short))
```

`picture.visible_len(text)` strips SGR and OSC-8 and exists so a test can assert it. This is the single most likely
alignment bug in the design, which is why it gets its own invariant test rather than a comment.

### Q10 — The empty-manifest case (the modal case)

**THE EMPTY-SECTION RULE, and it is the same rule that makes "differ in breadth only" testable.**

Every section always renders its header line. A section with no rows renders its header **plus exactly one** dim
placeholder line, prefixed `  — `, naming what would fill it and the one command that would.

For a repository with **no manifest** — 13 of ~14 registered repositories — section for section:

| section | what renders |
|---|---|
| *(header)* | the cube, plus the discovery tip when `total_projects <= 1` |
| `▸ IN FOCUS` | the full card: Source / Path / **Status:** / Last active / tmux window / Session ID, Summary, Active Plan, Recent Checkpoints, Latest Checkpoint |
| `▸ REPOSITORIES` | the context line, the table header, the 90-dash rule, and **every** registered row, this one marked `◀` |
| `▸ CHAINS` | header + ONE placeholder, chosen from the grid block's own self-describing fields |
| `▸ QUEUED` | this repository's directives, or `— nothing queued. Run /borg-plan to file one.` |
| `▸ SHIPPED` | this repository's assimilated plans, or `— nothing shipped yet.` |
| `▸ SIGNALS` | capacity + sweep/fetch warnings + the unresolved count, or `— nothing to report.` |

The three CHAINS placeholders are three different **diagnoses**, read off `grid.slug` / `grid.scope_kind` /
`grid.manifests` — fields `build_grid` carries precisely so "a consumer reading only this block can tell an empty grid
apart from an un-swept one apart from a wrong-repository one" (`grid.py:725-730`):

- `slug == ""` → `— this directory has no GitHub origin — nothing to scope a chain to.`
- `slug != ""`, repository scope, no selected manifest →
  `— no project manifest declares work in acme/ledger. Run /borg-plan to scaffold one.`
- orchestrator scope, no manifests anywhere →
  `— no project manifests in the registry yet. Run /borg-plan in any repository.`

A repository **with** a manifest renders the identical seven headers in the identical order; CHAINS carries a picture
and detail blocks instead of one line.

**The invariant is mechanically asserted.** `render.SECTIONS` is a module-level tuple of `(title, builder)` pairs whose
first entry has an empty title (the cube, which gets no `▸`). `document()` iterates it. The tests extract the ordered
list of `▸ `-prefixed titles from **both goldens** and require each to equal `tuple(t for t, _ in render.SECTIONS if t)`
— comparing against the *constant*, not against each other, because a header diff between two goldens goes green if both
drift together.

**Consequence, taken deliberately.** The `total_projects == 0` and all-archived early returns (`render.py:283-284`,
`:296-298`) are **gone**. Those two sentences become REPOSITORIES placeholders — `— No projects registered. Run: borg
scan` and `— No projects to show. Run: borg link --all` — verbatim, with only the leading `{GREEN}▸{NC}` dropped so
`▸ ` stays an unambiguous section marker. **Verified literally**: all six assertions on those sentences are substring
tests, so the change is free — `cli_contract.bats:927` (`[[ "$watch_output" == *"No projects registered"* ]]`), `:2093`,
`:2115`, `:2020` (a negative substring), and `test_render.py:35/38/39`. (`cli_contract.bats:1929` asserts on
`cmd_ls --porcelain`, the zsh path, and is unaffected.) The behaviour change is real — an empty registry now prints
seven headers instead of one line — and it is the point: a front door that renders one line reads as broken for exactly
the reason the plan's own risk section gives.

---

## 2. Literal rendered output

**Legend for the escape bytes:**

```
{B}=ESC[1m  {D}=ESC[2m  {G}=ESC[0;32m  {Y}=ESC[1;33m  {R}=ESC[0;31m  {C}=ESC[0;36m  {X}=ESC[0m
<url>TEXT</> = OSC-8:  ESC]8;;url ESC\  TEXT  ESC]8;; ESC\    (zero visible width)
```

In the picture rows the SGR wrapper around each glyph and the OSC-8 wrapper around each ref are ELIDED after their first
occurrence so the column math stays legible. Both are zero-width; padding is computed on visible text only.

### 2.1 Repository context — a repository WITH a manifest

Identical output from `borg link platform` and from `cd $ws/platform && borg link`. Both are rendered by the harness and
diffed against the same golden.

```
$ borg link platform

{D}  _______________{X}
{D}  /|             /|{X}      {B}THE BORG COLLECTIVE{X}
{D}  / |            / |{X}      {D}resistance is futile{X}
{D}    |___________|  |{X}
{D}    |  |        |  |{X}
{D}    |  |________|__|{X}
{D}    | /         | /{X}
{D}    |/          |/{X}

{B}▸ IN FOCUS{X}  {D}platform{X}
  {D}Source:{X}       cli
  {D}Path:{X}         <TMP>/ws/platform
  {D}Status:{X}       active
  {D}Last active:{X}  2026-08-26T14:30:00Z
  {D}tmux window:{X}  platform
  {D}Session ID:{X}   sess-platform-0007

  {B}Summary{X}
  Scoped keypair auth rollout.

  {B}Active Plan{X}
  {C}Objective:{X} Rotate every service onto scoped keypair auth, then flip enforcement.
  {C}Progress:{X} 1/4 criteria met

  {B}Recent Checkpoints{X}
    {C}2026-08-26-1430.md{X}

  {B}Latest Checkpoint{X}
  # Checkpoint
  base migration merged; the three forks are unblocked.

{B}▸ REPOSITORIES{X}  {D}the collective · 7 repositories · 2 need attention{X}
{B} PROJECT              SRC  STATUS       LAST ACTIVE  SUMMARY{X}
──────────────────────────────────────────────────────────────────────────────────────────
*platform             [C]  {G}active      {X} 2h ago       Scoped keypair auth rollout. {C}◀{X}
 warehouse            [D]  {Y}waiting <<< {X} yesterday    Key cutover blocked on the rollout run.
 infra                [X]  {G}active      {X} 3h ago       (no summary)
 ledger               [C]  {D}idle        {X} 30m ago      Nightly close reconciliation.
 atlas                [C]  {Y}waiting <<< {X} 5d ago       Waiting on a schema decision.
                       {C}⏸ resumes in 1h 12m{X}
 relay                [C]  {D}idle        {X} 2d ago       Relay has no summary yet.
 archive-tools        [C]  {D}idle        {X} never        Nothing here since the fork.

{B}▸ CHAINS{X}  {D}1 project · 7 refs · 0 unresolved · swept 2026-05-28{X}

  {B}auth-hardening{X}
  {D}Rotate every service onto scoped keypair auth, then flip enforcement on in one release.{X}
  {D}repos: acme/infra · acme/platform · acme/warehouse{X}
  {D}glance:{X} {G}✔{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X}

    {G}✔{X} n1   <https://github.com/acme/platform/issues/400>platform#400</>
    │
    ├────────────────────┬────────────────────┐
    │                    │                    │
    ○ n2   platform#420  ○ n3   warehouse#87  ○ n4   infra#12
    │                    │                    │
    ○ n5   platform#431  ○ n6   warehouse#93  │
    │                    │                    │
    └────────────────────┼────────────────────┘
                         │
                         ○ n7   infra#77

  {D}n1{X}    <https://github.com/acme/platform/issues/400>acme/platform#400</>  {G}MERGED{X}
      base migration
      {D}why:{X}       base migration
      {D}unlocks:{X}   acme/platform#420 · acme/warehouse#87 · acme/infra#12
      {D}state:{X}     from the sweep

  {D}n2{X}    acme/platform#420  {Y}OPEN{X}
      chore(auth): Status: normalise the rollout report
      {D}why:{X}       add auth scopes to the token service
      {D}waits on:{X}  acme/platform#400 (merged)
      {D}unlocks:{X}   acme/platform#431
      {D}state:{X}     from the sweep

  {D}n3{X}    acme/warehouse#87  {Y}OPEN{X}
      rotate the warehouse keypair
      {D}why:{X}       rotate the warehouse keypair
      {D}waits on:{X}  acme/platform#400 (merged)
      {D}unlocks:{X}   acme/warehouse#93
      {D}state:{X}     from a targeted fetch

  {D}n4{X}    acme/infra#12  {Y}OPEN{X}
      inventory services still on password auth
      {D}why:{X}       inventory services still on password auth
      {D}waits on:{X}  acme/platform#400 (merged)
      {D}unlocks:{X}   acme/infra#77
      {D}state:{X}     from the sweep

  {D}n5{X}    acme/platform#431  {Y}OPEN{X}
      enforce scopes on internal calls
      {D}why:{X}       enforce scopes on internal calls
      {D}waits on:{X}  acme/platform#420 (open)
      {D}unlocks:{X}   acme/infra#77
      {D}state:{X}     from the sweep

  {D}n6{X}    acme/warehouse#93  {Y}OPEN{X}
      cut consumers over to the new key
      {D}why:{X}       cut consumers over to the new key
      {D}waits on:{X}  acme/warehouse#87 (open)
      {D}unlocks:{X}   acme/infra#77
      {D}state:{X}     from a targeted fetch

  {D}n7{X}    acme/infra#77  {Y}OPEN{X}  {D}(join: 3 parents){X}
      flip enforcement flag, all services
      {D}why:{X}       flip enforcement flag, all services
      {D}waits on:{X}  acme/platform#431 (open) · acme/warehouse#93 (open) · acme/infra#12 (open)
      {D}unlocks:{X}   nothing — end of the chain
      {D}gate:{X}      verification — staged rollout run must pass
      {D}unparked:{X}  canary deploy green for 24h
      {D}state:{X}     from the sweep

{B}▸ QUEUED{X}  {D}2 directives{X}
    {D}- Scope keypair rotation to the warehouse tier{X}
    {D}- Retire password auth from the inventory service{X}

{B}▸ SHIPPED{X}
    {D}- Base migration for scoped tokens (2026-08-20){X}

{B}▸ SIGNALS{X}
  {D}— sweep: replayed from fixture <TESTS>/fixtures/link/sweep-acme.json -- no adapter ran{X}
  {D}— fetch: replayed from fixture <TESTS>/fixtures/link/fetch-acme.json -- no gh ran{X}
  {D}— 7 of 7 declared refs resolved.{X}

```

`waits on` / `unlocks` are rendered in **`seq` order** (declaration order), not sorted — the same key the picture uses,
so a reader's eye moves the same way in both. `node["parents"]` / `node["children"]` are emitted sorted by
`(seq, ref)` from `grid.py`; the renderer does not re-sort.

### 2.2 Orchestrator context

Run from the workspace root, `scope.kind == "orchestrator"`. The `▸` headers below are byte-identical to §2.1, in the
same order; only the row sets differ. That equality is what the spine test asserts.

```
$ borg link

{D}  _______________{X}
{D}  /|             /|{X}      {B}THE BORG COLLECTIVE{X}
{D}  / |            / |{X}      {D}resistance is futile{X}
{D}    |___________|  |{X}
{D}    |  |        |  |{X}
{D}    |  |________|__|{X}
{D}    | /         | /{X}
{D}    |/          |/{X}

{B}▸ IN FOCUS{X}
  {D}— no repository in focus. cd into one, or run borg link <name>.{X}

{B}▸ REPOSITORIES{X}  {D}the collective · 7 repositories · 2 need attention{X}
{B} PROJECT              SRC  STATUS       LAST ACTIVE  SUMMARY{X}
──────────────────────────────────────────────────────────────────────────────────────────
*platform             [C]  {G}active      {X} 2h ago       Scoped keypair auth rollout.
 warehouse            [D]  {Y}waiting <<< {X} yesterday    Key cutover blocked on the rollout run.
 infra                [X]  {G}active      {X} 3h ago       (no summary)
 ledger               [C]  {D}idle        {X} 30m ago      Nightly close reconciliation.
 atlas                [C]  {Y}waiting <<< {X} 5d ago       Waiting on a schema decision.
                       {C}⏸ resumes in 1h 12m{X}
 relay                [C]  {D}idle        {X} 2d ago       Relay has no summary yet.
 archive-tools        [C]  {D}idle        {X} never        Nothing here since the fork.

{B}▸ CHAINS{X}  {D}2 projects · 11 refs · 0 unresolved · swept 2026-05-28{X}

  {B}auth-hardening{X}
  {D}Rotate every service onto scoped keypair auth, then flip enforcement on in one release.{X}
  {D}repos: acme/infra · acme/platform · acme/warehouse{X}
  {D}glance:{X} {G}✔{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X} {Y}○{X}

    ✔ n1   platform#400
    │
    ├────────────────────┬────────────────────┐
    │                    │                    │
    ○ n2   platform#420  ○ n3   warehouse#87  ○ n4   infra#12
    │                    │                    │
    ○ n5   platform#431  ○ n6   warehouse#93  │
    │                    │                    │
    └────────────────────┼────────────────────┘
                         │
                         ○ n7   infra#77

    [ n1..n7 detail blocks — BYTE-IDENTICAL to §2.1; elided in this mock only, never by the
      renderer. Ids are global across the document, which is why the second manifest starts at n8. ]

  {B}warehouse-rollout{X}
  {D}Move the warehouse fleet onto the rotated keypair, one region at a time.{X}
  {D}repos: acme/warehouse{X}
  {D}glance:{X} {G}✔{X} {Y}○{X} {G}✔{X} {D}✗{X}

    ✔ n8   warehouse#61
    │
    ○ n9   warehouse#64
    │
    ✔{R}!{X}n10  warehouse#70
    │
    ✗ n11  warehouse#72

  {D}n8{X}    acme/warehouse#61  {G}MERGED{X}
      us-east region cutover
      {D}why:{X}       us-east region cutover
      {D}unlocks:{X}   acme/warehouse#64
      {D}state:{X}     from the sweep

  {D}n9{X}    acme/warehouse#64  {Y}OPEN{X}
      us-west region cutover
      {D}why:{X}       us-west region cutover
      {D}waits on:{X}  acme/warehouse#61 (merged)
      {D}unlocks:{X}   acme/warehouse#70
      {D}gate:{X}      decision — Kelly must sign off on the maintenance window
      {D}unparked:{X}  scheduling call on Thursday
      {D}state:{X}     from the sweep

  {D}n10{X}   acme/warehouse#70  {G}MERGED{X}
      eu region cutover
      {D}why:{X}       eu region cutover
      {R}drift:{X}     merged before its declared parent acme/warehouse#64, which is open
      {D}waits on:{X}  acme/warehouse#64 (open)
      {D}unlocks:{X}   acme/warehouse#72
      {D}state:{X}     from the sweep

  {D}n11{X}   acme/warehouse#72  {D}CLOSED{X}
      ap region cutover — superseded by the fleet-wide script
      {D}why:{X}       ap region cutover — superseded by the fleet-wide script
      {D}waits on:{X}  acme/warehouse#70 (merged)
      {D}unlocks:{X}   nothing — end of the chain
      {D}state:{X}     from a targeted fetch

{B}▸ QUEUED{X}  {D}9 directives{X}
    {D}- [platform] Scope keypair rotation to the warehouse tier{X}
    {D}- [platform] Retire password auth from the inventory service{X}
    {D}- [warehouse] Schedule the eu maintenance window{X}
    {D}- [atlas] Decide the tenant schema split{X}
    {D}- [ledger] Nightly close: move the reconciliation to the worker{X}

{B}▸ SHIPPED{X}
    {D}- [platform] Base migration for scoped tokens (2026-08-20){X}
    {D}- [warehouse] Region cutover runbook (2026-08-18){X}
    {D}- [ledger] Close-of-day parity harness (2026-08-17){X}

{B}▸ SIGNALS{X}
  {B}4 sessions need attention{X} (limit: 3)
  {D}— sweep: replayed from fixture <TESTS>/fixtures/link/sweep-acme.json -- no adapter ran{X}
  {D}— fetch: replayed from fixture <TESTS>/fixtures/link/fetch-acme.json -- no gh ran{X}
  {D}— 11 of 11 declared refs resolved.{X}

```

### 2.3 The empty-manifest repository — the modal case

`ledger` has a git origin (`acme/ledger`) and no manifest. Same seven headers, same order.

```
$ borg link ledger

{D}  _______________{X}
{D}  /|             /|{X}      {B}THE BORG COLLECTIVE{X}
{D}  / |            / |{X}      {D}resistance is futile{X}
{D}    |___________|  |{X}
{D}    |  |        |  |{X}
{D}    |  |________|__|{X}
{D}    | /         | /{X}
{D}    |/          |/{X}

{B}▸ IN FOCUS{X}  {D}ledger{X}
  {D}Source:{X}       cli
  {D}Path:{X}         <TMP>/ws/ledger
  {D}Status:{X}       idle
  {D}Last active:{X}  2026-08-26T14:00:00Z
  {D}tmux window:{X}  ledger
  {D}Session ID:{X}   (unknown)

  {B}Summary{X}
  Nightly close reconciliation.

{B}▸ REPOSITORIES{X}  {D}the collective · 7 repositories · 2 need attention{X}
{B} PROJECT              SRC  STATUS       LAST ACTIVE  SUMMARY{X}
──────────────────────────────────────────────────────────────────────────────────────────
*platform             [C]  {G}active      {X} 2h ago       Scoped keypair auth rollout.
 warehouse            [D]  {Y}waiting <<< {X} yesterday    Key cutover blocked on the rollout run.
 infra                [X]  {G}active      {X} 3h ago       (no summary)
 ledger               [C]  {D}idle        {X} 30m ago      Nightly close reconciliation. {C}◀{X}
 atlas                [C]  {Y}waiting <<< {X} 5d ago       Waiting on a schema decision.
                       {C}⏸ resumes in 1h 12m{X}
 relay                [C]  {D}idle        {X} 2d ago       Relay has no summary yet.
 archive-tools        [C]  {D}idle        {X} never        Nothing here since the fork.

{B}▸ CHAINS{X}  {D}0 projects · 0 refs · 0 unresolved · swept 2026-05-28{X}
  {D}— no project manifest declares work in acme/ledger. Run /borg-plan to scaffold one.{X}

{B}▸ QUEUED{X}
  {D}— nothing queued. Run /borg-plan to file one.{X}

{B}▸ SHIPPED{X}
  {D}— nothing shipped yet.{X}

{B}▸ SIGNALS{X}
  {D}— sweep: replayed from fixture <TESTS>/fixtures/link/sweep-acme.json -- no adapter ran{X}
  {D}— grid: 2 manifest(s) discovered, none declaring a row in acme/ledger{X}

```

The modal repository does not read as broken because the one empty section sits in a document whose other six sections
are strictly richer than what `borg link <project>` shows today: today's deep dive has no board and no chains at all, so
the no-manifest repository **gains** a board and a diagnosis and loses nothing.

---

## 3. Function decomposition

### `borg_core/link/picture.py` — NEW, pure

`import os` / `subprocess` / `open` / `time` / `datetime` / `isatty` are forbidden and **AST-asserted** (§4, P20).
`"picture.py"` is added to `[tool.clean-arch.module_map] Domain` in `pyproject.toml:84-85` — which that block's own
comment already commits to ("Any future pure-logic module split out of a `core.py` belongs on this list on the same
terms"). Without it the linter gives the file **zero** enforcement: `clean_architecture_linter`'s `_check_import`
returns early on an unclassified file, and classification is by filename against the inverted map.

```
Constants
  GLYPH_MERGED="✔" GLYPH_READY="●" GLYPH_OPEN="○" GLYPH_DRAFT="◌" GLYPH_CLOSED="✗"
  DRIFT_MARK="!"  INDENT=4  GUTTER=2  ID_WIDTH=4  PICTURE_BUDGET=68
  _BOX: dict[tuple[int,int,int,int], str]              # (up,right,down,left) -> box char

Topology (pure, plain data in)
  level_of(manifest_grid)                 -> dict[str,int]        # grid["levels"]; index IS the level
  ordering_pairs(nodes)                   -> list[tuple[str,str]] # node["parents"], both ends present,
                                                                  #   back edges dropped
  back_edges(nodes)                       -> list[tuple[str,str]] # what ordering_pairs dropped
  span_end(ref, level_of, children_of)    -> int
  assign_columns(levels, parents_of, children_of, seq_of) -> dict[str,int]      # Q3
    _placement_order(refs, parents_of, columns, seq_of) -> list[str]
    _preferred_column(ref, parents_of, columns, seq_of) -> int | None
    _free_column(used_at_level, preferred)              -> int
  node_ids(manifest_grids, columns_by_manifest) -> dict[str,str]  # GLOBAL n1..nN,
                                                                  #   (manifest index, level, column)

Rasterization
  short_refs(manifest_grid)               -> dict[str,str]        # repo#num, full on owner collision
  ref_width(short)                        -> int
  node_cell(node, node_id, short, width, drift) -> str
  boundary(level, columns, segments)      -> dict                 # arriving/leaving/involved/crossing
  stem_row(columns, width)                -> str
  rail_row(boundary, width)               -> str
  picture(manifest_grid, ids, columns)    -> list[str]            # stem / [stem,rail,stem] cadence
  glance_row(manifest_grid, ids)          -> str                  # glyphs only, NO ids
  detail_block(node, node_id, nodes, ids) -> list[str]

Vocabulary
  state_glyph(node) -> str        # Q5; reads optional node["ready"] / node["draft"]
  state_word(node)  -> str        # MERGED | OPEN | CLOSED, else "" (the token is never printed)
  state_line(node)  -> str        # Q8; keyed on grid.STATE_SOURCE_*, imported not literal
  drift_parents(node, nodes) -> list[str]
  osc8(url, text)   -> str        # Q9's exact sequence, ST terminator
  ref_url(ref)      -> str        # "" when manifest_core.parse_ref rejects
  link_ref(ref, text) -> str      # osc8(...) or `text` unchanged
  visible_len(text) -> int        # strips SGR + OSC-8; the padding/test primitive
```

### `borg_core/link/render.py` — rewritten around `document()`

```python
SECTION_MARK = "▸ "
SECTIONS: tuple[tuple[str, Callable[[dict], list[str]]], ...] = (
    ("",             _header_section),      # cube + discovery tip; no ▸ line
    ("IN FOCUS",     _focus_section),       # ABOVE the board: Q6's Status: invariant
    ("REPOSITORIES", _board_section),       # registry-wide in BOTH contexts
    ("CHAINS",       _grid_section),
    ("QUEUED",       _queued_section),
    ("SHIPPED",      _shipped_section),
    ("SIGNALS",      _signals_section),
)

def document(doc: dict) -> str          # THE ONE HUMAN ENTRY POINT: iterates SECTIONS, joins
def porcelain(doc: dict) -> str         # UNCHANGED byte for byte

_JQ_ABSENT_STATUS = "unknown"           # registry-status jq fallback; NOT the grid's token (Q8)
_section(title, body) -> list[str]      # header + body, or header + one placeholder
_placeholder(sentence) -> str           # "  {DIM}— <sentence>{NC}"
_scoped_directives(doc) -> list[dict]   # focus.directives in repository scope, .directives otherwise
```

**Retained unchanged (the parity surface — do not touch):** `_label`, `_fold_s`, `_summary_block`,
`_checkpoint_head_block`, `_status_color`, `_src_badge`, `_overview_summary_cut`, `_overview_row`, `_cube_lines`,
`_ship_date_suffix`, `_overview_capacity_block`, and every `_COL_*` / `_DEEP_LABEL_COL` width.
`_directives_lines` / `_assimilated_lines` lose their own header line (the section header replaces it) and keep their
bullet loop verbatim.

### `borg_core/link/grid.py` — additive wire keys only, `DOCUMENT_VERSION` stays 2

```
_grid_nodes:    node gains  "parents":  list[str]   ordering edges only, both ends inside the node set,
                                                    sorted by (seq, ref)
                            "children": list[str]   same
                            "seq":      int         index in lanes()' flattened order
                                                    (already computed at grid.py:641-643)
                NOT "ready", NOT "draft" -- those stay AC4's.
grid_manifest:  block gains "desc"  (manifest["desc"], through _grid_text)
                            "repos" (sorted unique manifest_core.ref_slug over row_refs)
```

### `borg_core/link/cli.py`

```
_mode(args)     -> "json" | "porcelain" | "human"
_build_parser   keeps --deep, parsed and ignored, with a comment naming the three copies that pass it
_run            the human arm calls render.document(doc) once and prints once
_document       focus computed ABOVE the aggregate block, from `project or scope["repository"]`
                need_focus     = mode != "porcelain" and (bool(project) or scope.kind == "repository")
                need_aggregate = mode == "json" or (mode != "porcelain" and scope.kind == "orchestrator")
                cortex_pending read unless porcelain
                BrokenPipeError caught in _run (never in render.py) -- see §5
```

---

## 4. Tests — every one with the mutation that turns it red

### `tests/cli_contract.bats`

| # | test name | mutation that turns it red |
|---|---|---|
| B1 | `contract: link renders the repository context byte-identically to its golden` | change any `_BOX` entry, any glyph constant, or `GUTTER` |
| B2 | `contract: link renders the repository context identically from the positional and from the cwd` | revert `_focus(project or scope["repository"] …)` to `_focus(project …)` — the cwd leg loses IN FOCUS, QUEUED and SHIPPED |
| B3 | `contract: link renders the orchestrator context byte-identically to its golden` | delete the `▸ IN FOCUS` placeholder, or make any section conditional |
| B4 | `contract: both link contexts render the same section headers in the same order` | reorder `SECTIONS`, or `return []` from any builder so `_section` emits nothing |
| B5 | `contract: exactly one Status: line in repository context and none in orchestrator context` | move IN FOCUS below CHAINS — the fixture PR titled `chore(auth): Status: normalise the rollout report` becomes a second hit |
| B6 | `contract: drone status extracts the session status, not a pull request title` | same move; the extraction returns the PR title instead of `active` |
| B7 | `contract: link <unregistered> dies non-zero from an orchestrator cwd too` | `need_focus = mode != "porcelain" and scope["kind"] == "repository"` — exit 0 with a full board |
| B8 | `contract: an unregistered positional dies before any aggregate collector runs` | move the `focus =` assignment back below the aggregate block; the timing/trace assertion fails |
| B9 | `contract: link --json carries every project's directives from inside a repository` | `need_aggregate = scope["kind"] == "orchestrator"` — `.directives` empties for the SKILL.md:32 call |
| B10 | `contract: borg link --local --all from inside a repository still lists every project` | apply `_scoped_names` to `_board_section` |
| B11 | `contract: the grid goldens replayed a populated sweep and a populated fetch` | mistype either fixture path in the helper; today that degrades silently and freezes |
| B12 | `contract: the grid goldens spawn zero gh and zero adapter subprocesses` | remove the `if fixture:` short-circuit from `shell.sweep` or `shell.start_fetch`; a mock `gh` on `BORG_PATH_PREFIX` appends to `$TRACE` |
| B13 | `contract: the grid goldens carry no absolute checkout path` | delete the `<TESTS>` expression from the helper's `sed` |
| B14 | `contract: every node id appears exactly twice in each grid golden` (word-boundary grep, `\bn1\b`) | delete a detail block, or number ids per manifest so `n1` appears four times |
| B15 | `contract: the fzf preview window is at least as wide as the widest picture row` — measures the widest `visible_len` in the orchestrator golden with `awk`, parses `N` out of `--preview-window "right:N:wrap"`, asserts `width <= N - 2` | narrow `borg.zsh:267` back to 45, or lengthen a fixture ref past the budget |
| B16 | `contract: link --local --deep <p> and link --local <p> render byte-identically` | delete `--deep` from `_build_parser` → argparse exits 2 and both legs go blank |
| — | *"contract: link --porcelain prints nothing at all on an empty registry"* | **UNCHANGED, not edited** — evidence that `porcelain` did not move |
| — | *"contract: link \<project\> deep dive wraps and indents a summary longer than 70 columns"* | **UNCHANGED** — evidence that `_summary_block`/`_fold_s` were transcribed, not rewritten |
| — | *"contract: drone status can still extract Status: from the deep dive"* | **UNCHANGED** — evidence that `_label("Status:", …)` survives |
| — | *"contract: link \<project\> dies non-zero on a project that is not registered"* (`:2299`) | **UNCHANGED** — evidence for B1 above |
| — | *"contract: link --json dies on an unknown project with empty stdout"* (`:2804`) | **UNCHANGED** |

### `borg_core/link/test_picture.py` — NEW

| # | test name | mutation |
|---|---|---|
| P1 | `test_a_linear_chain_is_one_column` | replace inheritance with "smallest free column" |
| P2 | `test_two_lanes_never_swap_columns_when_refs_sort_across_them` (the live `ingle-t1-cutover` level structure) | place by within-level index; the lanes cross at levels 2 and 4 |
| P3 | `test_a_fork_whose_children_are_all_leaves_still_spreads` | `range(L, span_end(n))` without the `max(…, L+1)` — both leaves take column 0 |
| P4 | `test_a_skip_level_edge_reserves_its_column_through_the_gap` | same |
| P5 | `test_a_join_lands_on_the_lower_median_of_its_parents` | `min(parent_columns)` |
| P6 | `test_declaration_order_breaks_within_level_ties_not_ascending_ref` | tie-break on `ref`; the mock's fork order inverts to `infra#12, platform#420, warehouse#87` |
| P7 | `test_a_cycle_broken_graph_places_every_node_and_draws_no_back_edge` | raise on a back edge instead of excluding it |
| P8 | `test_the_approved_mock_fork_and_join_rows` — `picture(...) == read("picture-fork.expected")` | any `_BOX` entry, any offset constant |
| P9 | `test_a_pass_through_interior_to_a_rail_is_not_drawn_as_a_join` — `picture-crossing.expected` | drop the `crossing(k)` arm → `┼` |
| P10 | `test_the_pre_rail_stem_carries_parents_and_the_post_rail_stem_carries_children` | one column set for both rows → `│ │ │` above the fan-out |
| P11 | `test_open_is_open_without_ready_and_ready_with_it` | delete the `node.get("ready") is True` branch |
| P12 | `test_draft_lights_up_from_an_absent_field` | delete the `draft` branch |
| P13 | `test_a_state_token_nobody_recognizes_takes_the_default_arm` (`grid.GRID_STATE_UNKNOWN`, `"in_progress"`, `"stacked"`) | replace the default arm with a dict lookup → `KeyError` |
| P14 | `test_a_merged_child_under_an_unmerged_parent_carries_the_drift_mark` | delete `drift_parents` |
| P15 | `test_the_url_is_always_the_issues_form` | `/pull/` |
| P16 | `test_the_sequence_terminates_with_ST_not_BEL` | `\a` |
| P17 | `test_a_ref_parse_ref_rejects_renders_as_plain_text` | fabricate a URL from the raw string |
| P18 | `test_neither_render_nor_picture_names_the_grid_unresolved_token` (structural: `"unknown"` appears at most once in `render.py` — the constant — and zero times in `picture.py`) | write `if node["state"] == "unknown"` anywhere |
| P19 | `test_a_node_nobody_answered_for_still_renders_its_id_and_names_the_condition` (behavioural) | drop the node instead of naming the condition |
| P20 | `test_render_and_picture_import_no_impure_module` (AST walk for `os`/`subprocess`/`open`/`time`/`datetime`/`isatty`) | add `os.environ.get("COLUMNS")` to `assign_columns` — today `make lint` stays green for an unclassified file |
| P21 | `test_visible_width_is_identical_with_and_without_hyperlinks` | pad on the raw string |
| P22 | `test_every_picture_row_in_both_fixture_manifests_fits_the_budget` | raise a fixture ref past `PICTURE_BUDGET` |
| P23 | `test_short_refs_fall_back_to_full_refs_when_two_owners_share_a_repo_name` | drop the collision check → two rows render the same cell text |

### `borg_core/link/test_render.py`

| # | test name | mutation |
|---|---|---|
| R1 | `test_render_exposes_exactly_one_human_entry_point` — `{n for n in vars(render) if not n.startswith("_") and callable(v) and v.__module__ == render.__name__} == {"document", "porcelain"}` | re-add `overview` or `deep` |
| R2 | `test_the_human_arm_names_render_document_exactly_once` (source text of `cli._run`) | add a second renderer call |
| R3 | `test_every_section_renders_its_header_in_both_contexts` | `return []` from any builder |
| R4 | `test_an_empty_section_renders_exactly_one_placeholder_line` | emit two, or emit none |
| R5 | `test_the_three_chains_placeholders_are_three_different_diagnoses` | collapse to one sentence |
| R6 | `test_empty_registry_and_all_archived_print_their_two_sentences` (adapted from `:35/:38/:39`) | swap the two sentences |
| R7 | `test_the_board_is_registry_wide_in_repository_scope` | filter board rows by `scope` |
| R8 | `test_queued_reads_focus_directives_in_repository_scope_and_the_aggregate_otherwise` | read `.directives` in both |
| — | `TestFoldS` (including `test_matches_real_fold_s_binary`) | **UNCHANGED** |

### `borg_core/link/test_cli.py`

| # | test name | mutation |
|---|---|---|
| C1 | `test_repository_scope_calls_no_aggregate_collector_on_the_human_path` (collectors monkeypatched to raise) | `need_aggregate = mode != "porcelain"` |
| C2 | `test_json_carries_the_aggregates_in_every_scope` | scope-gate the json path |
| C3 | `test_focus_follows_scope_when_no_positional_is_given` | `_focus(project, …)` |
| C4 | `test_an_unregistered_positional_raises_before_any_aggregate_collector_runs` | leave `focus =` below the aggregate block |
| C5 | `test_porcelain_computes_no_focus_no_aggregates_and_no_cortex_pending` | drop the porcelain guard |
| C6 | `test_deep_is_accepted_and_ignored` | delete `--deep` from the parser → `SystemExit(2)` |
| — | `:203`, `:216`, `:433` (ProjectNotFound) | **UNCHANGED** |

### `borg_core/link/test_grid.py`

| # | test name | mutation |
|---|---|---|
| G1 | `test_every_node_carries_its_parents_children_and_seq` | drop any of the three keys |
| G2 | `test_parents_and_children_carry_ordering_edges_only` (an `apex` manifest must not link) | use every edge kind instead of `ORDERING_EDGE_KINDS` |
| G3 | `test_a_manifest_block_carries_its_desc_and_repo_slugs` | drop `desc` or `repos` |
| G4 | `test_parents_and_children_are_sorted_by_seq_then_ref` | sort by `ref` alone |

---

## 5. Blocker-by-blocker binding fixes

| id | blocker | binding fix |
|---|---|---|
| **L1-B1 / L3-B1** | scope-derived `need_focus` deletes the `ProjectNotFound` path | `need_focus = mode != "porcelain" and (bool(project) or scope.kind == "repository")`, and `_focus(project or scope["repository"] or "")`. `cli_contract.bats:2299`, `:2804` and `test_cli.py:203/216/433` stay untouched as the evidence. New case B7. |
| **L1-B2 / L2-B3 / L3-B2** | `cd <repo> && borg link` loses IN FOCUS, `Status:`, QUEUED and SHIPPED; the harness cannot see it | focus follows scope (above). Repository context is rendered **twice** — positional and cwd — against the **same** golden (case B2). |
| **L1-B3 / L2-B2 / L3-B3** | scope-gating the aggregates narrows `.directives`/`.assimilated` on the `--json` wire at v2 | `need_aggregate = mode == "json" or (mode != "porcelain" and scope.kind == "orchestrator")`. `--json` pays the glob in every scope, exactly as `cli.py:202` does today; neither hot loop is `--json`. Case B9 pins it. |
| **L1-B4** | `_scoped_names` on the board breaks `borg switch`, `borg watch` and `borg link --local --all` | REPOSITORIES is scope-invariant; the scoped row is marked `◀`. Case B10. |
| **L1-B5** | reservation range is empty for a childless node; a leaf-only fork collapses to one column | `for j in range(L, max(span_end(n), L + 1))`. Case P3, plus the missing fixture. |
| **L1-B6** | the 4-bit mask renders a pass-through interior to a rail as `┼` — a dependency that does not exist | fifth bit, `crossing(k)`, rendered `│` with the `─` fill continuing on both sides. Case P9, `picture-crossing.expected`. |
| **L1-B7 / L3-B4** | one stem column set for both rows renders `│ │ │` above a fan-out | pre-rail stem = arriving columns, post-rail stem = leaving columns; the decomposition names both. Case P10. |
| **L2-B1** | `grep -n unknown render.py` returning nothing is refuted by the five occurrences the design promises to preserve | Q8's five-part restatement: one named constant, `picture.py` clean, the grid's token imported from `grid.py`, plus a structural **and** a behavioural test (P18, P19). The five pre-existing sites are enumerated here so no one "fixes" them. |
| **L2-B4** | `picture.py` outside `[tool.clean-arch.module_map]` gets zero enforcement; an `os.environ` read would ship green | add `"picture.py"` to `Domain` in `pyproject.toml:84-85`, plus the AST purity test P20 covering both modules. |
| **L2-B5** | `state: github sweep` fabricates adapter provenance the wire does not carry | `state_line` is keyed on `grid.STATE_SOURCE_*` and renders "from the sweep / from a targeted fetch / from the manifest (declared) / nobody has an answer". Mocks in §2 corrected. |
| **L3-B4** | both goldens are written by the implementation, so nothing ties the picture to the approved mock; "glyph sequences" survives every plausible rasterization bug | hand-authored `picture-fork.expected` and `picture-crossing.expected`, transcribed from `chains-dag-mock.md`, **not writable by `BORG_UPDATE_GOLDEN`**; `_assert_link_grid_golden` refuses to regenerate unless P8 and P9 pass. |
| **L3-B5** | a grep for `right:50%:wrap` asserts a config value, not that the picture fits; by the design's own arithmetic it does not fit | short refs in the cell (the mock's own rule, `chains-dag-mock.md:76`), full refs in the heading; `PICTURE_BUDGET = 68` asserted in P22; case B15 **measures** the widest golden row and compares it to the number parsed out of `borg.zsh:267`, which becomes `right:70:wrap`. Fixture: 65 columns. Live `ingle-t1-cutover`: 46. Live `viz-program`: 30. |
| **L3-B6** | the fixture seams degrade to a named warning that the golden then freezes as the oracle | the `jq -e` tripwire in `_assert_link_grid_golden`, run **before** the diff and **on the update path**; plus case B12's mock `gh` with a real `$TRACE`. |

### Non-blocking notes, dispositioned

- **`parents`/`children` order** — sorted by `(seq, ref)`, not by `ref`. Stated in `grid.py`, pinned by G4, matched by
  §2's `waits on` / `unlocks` lines.
- **`ID_WIDTH`** — fixed at 4, not derived, so a manifest's block is byte-identical whether the document holds 7 nodes
  or 11. Overflows at `n1000`; recorded, not guarded.
- **Node ids are global** — required so vim `*` finds exactly two hits across the whole document. A manifest at the same
  document position renders identical ids in both contexts, which is what §2.2's elision claims and case B1/B3 prove
  by construction. Ids are navigation handles, not vocabulary; the REF is the vocabulary and it is stable.
- **SIGPIPE** — `drone.zsh:964` pipes into `grep -m1`, which exits on the first match. The seven-section document is
  larger than today's deep dive and could exceed the 64KB pipe buffer, whereupon `_run`'s single `print` raises
  `BrokenPipeError` and Python prints a traceback that `drone` merges into the status table. Caught in `cli._run`,
  **never** in `render.py`, which stays pure.
- **`borg link <archived-project>`** — `core.visible_projects` filters archived out of `.projects` while `_focus` looks
  the project up in the full overlaid registry (`cli.py:52-53`, deliberate). `_board_section` must use `.get` plus a
  placeholder row, never `projects[name]` the way `render.porcelain:142` does, or repository scope on an archived
  project raises `KeyError` into `cli.main`'s broad except. Add the case.
- **`bin/link-parity-harness`** — the `render` leg is retired in this commit and the retirement is stated in the commit
  body: its oracle is the pre-AC2 zsh renderer at `ad99612` and is unreproducible by construction. The `primitives` leg
  stays green.
- **`borg link --deep` with no positional** — unreachable from `borg.zsh` (`_borg_link_dispatch` only passes `--deep`
  alongside a positional, `borg.zsh:3110-3117`); a user's `--deep` falls into the lenient `-*)` arm. Pinned by B16 in
  its reachable shape.

---

## 6. Files that change

| path | change |
|---|---|
| `borg_core/link/picture.py` | **NEW** — the pure topological picture |
| `borg_core/link/render.py` | rewritten around `document()`; `overview`/`deep` deleted; `porcelain` untouched |
| `borg_core/link/grid.py` | nodes gain `parents`/`children`/`seq`; manifest blocks gain `desc`/`repos` |
| `borg_core/link/cli.py` | `_mode` collapse, focus above the aggregates, scope-aware human gating, one render call, `BrokenPipeError` |
| `borg_core/link/test_picture.py` | **NEW** — P1–P23 |
| `borg_core/link/test_render.py` | R1–R8; `TestFoldS` untouched |
| `borg_core/link/test_grid.py` | G1–G4 |
| `borg_core/link/test_cli.py` | C1–C6; `:203`/`:216`/`:433` untouched |
| `tests/cli_contract.bats` | `<TESTS>` scrub in `_assert_link_golden`; new `_assert_link_grid_golden` + `_link_build_grid_ws`; cases B1–B16 |
| `tests/fixtures/link/link-overview.golden` | **REGENERATED** |
| `tests/fixtures/link/link-overview-all.golden` | **REGENERATED** |
| `tests/fixtures/link/link-deep.golden` | **REGENERATED** |
| `tests/fixtures/link/link-porcelain.golden` | **UNCHANGED** — listed so the reviewer checks that it did not move |
| `tests/fixtures/link/link-grid-repository.golden` | **NEW** |
| `tests/fixtures/link/link-grid-orchestrator.golden` | **NEW** |
| `tests/fixtures/link/manifests/auth-hardening.json` | **NEW** — the approved mock's fork, full refs, row-level `after:` |
| `tests/fixtures/link/manifests/warehouse-rollout.json` | **NEW** — linear; the drift node and the closed node |
| `tests/fixtures/link/sweep-acme.json` | **NEW** — recorded fan-out output; carries the `Status:`-poisoned PR title |
| `tests/fixtures/link/fetch-acme.json` | **NEW** — recorded targeted-fetch answers |
| `tests/fixtures/link/picture-fork.expected` | **NEW** — hand-authored, never regenerated |
| `tests/fixtures/link/picture-crossing.expected` | **NEW** — hand-authored, never regenerated |
| `pyproject.toml` | `[tool.clean-arch.module_map] Domain` gains `"picture.py"` |
| `borg.zsh` | ONE line: `:267` `--preview-window "right:45:wrap"` → `"right:70:wrap"` |
| `skills/borg-link/SKILL.md` | additive only: document `.grid` nodes' `parents`/`children`/`seq` and the manifest `desc`/`repos`; correct the "scope is context, not content" clause (`:121-124`) to say focus now follows scope. **No change to the `== 2` gate (`:87`), the `> 2` skew branch (`:88`), or the deep-dive whitelist (`:39`).** |
| `bin/link-parity-harness` | retire the `render` leg; keep `primitives` |
| `CLAUDE.md` | `borg link`'s one-renderer description + the `render.py` / `picture.py` split |
| `drone.zsh` | **DELIBERATELY UNCHANGED** — listed so the reviewer verifies the diff is empty; the `--porcelain` migration of `:964` is filed as a parented follow-up |
| `tests/link_sweep.bats` | **UNCHANGED** — its call-site greps and the `drone status` zero-subprocess case still hold |

**`DOCUMENT_VERSION` stays 2.** Cost in `skills/borg-link/SKILL.md`: zero coupled edits — the four edits
`core.py:631-636` prices a bump at (the `== 2` gate, the `> 2` skew branch, the "scope is context" claim, and the
deep-dive whitelist) are not owed, because no pre-existing key narrows in any scope on any surface. The one
documentation edit to `:121-124` is a correction of a sentence that becomes stale, not a contract change, and the
`claude-plugins` mirror can absorb it whenever it next syncs.

---

## 7. Sequencing

AC2 splits into five steps. Each is committable, each leaves both suites green, and the goldens regenerate exactly
once — in **S3**.

**S1 — the wire (breaks nothing).** `grid.py` gains `parents` / `children` / `seq` on every node and `desc` / `repos`
on every manifest block. `pyproject.toml` gains `"picture.py"`. Tests G1–G4. Purely additive; the four existing goldens
do not move because `render.py` prints no part of `grid` yet. `borg link --json`'s document grows three keys at v2,
which is the same additive shape `scope` and `grid` already took.

**S2 — `picture.py` (breaks nothing).** The whole pure module plus P1–P23 and the two hand-authored `.expected`
fixtures. Nothing imports it yet. This is where the column algorithm, the connectors, the crossing rule, the glyph
seam, OSC-8 and the width budget are all settled against an oracle that predates the renderer. **The two `.expected`
files must land before any golden is cut.**

**S3 — the renderer (breaks everything, once).** `render.document` + `SECTIONS` + the seven builders; `overview`/`deep`
deleted; `cli._mode`/`_run`/`_document` rewired; `_assert_link_golden` gains the `<TESTS>` scrub;
`_assert_link_grid_golden` and `_link_build_grid_ws` land with the four new fixtures; `borg.zsh:267` widens; R1–R8,
C1–C6 and B1–B16 land. **Three
goldens regenerate and two are created, in one reviewed diff.** `link-porcelain.golden` must not move, and `drone.zsh`
plus the four named pre-existing bats cases must not be touched — that is the review's checklist.

**S4 — the parity retirement (breaks the harness's `render` leg, deliberately).** `bin/link-parity-harness` loses its
`render` command; the `primitives` leg and `tests/link_sweep.bats:417`'s grep on `"link", "--local", *args` stay green.
Separate from S3 so the deletion reads as *evidence replaced*, not *evidence dropped*.

**S5 — documentation.** `CLAUDE.md` and the additive `skills/borg-link/SKILL.md` edits. Last, so it describes what
shipped rather than what was planned.

**Follow-ups filed, not built:** `drone.zsh:964` onto `--porcelain` + `awk`; emitting `isDraft` so `◌` becomes
reachable; a `--json`-side width check so a future manifest cannot silently blow `PICTURE_BUDGET`.

## 8. Residual risk, stated

`PICTURE_BUDGET = 68` is asserted against two fixture manifests and measured against one golden. A future manifest whose
short refs run long in three columns exceeds it, and nothing in this commit notices until someone authors one — the
`--json`-side check is filed above. That is the honest boundary of the mitigation: the picture's width is a
compile-time constant because `render.py` is unconditionally pure, and the guard is a measurement over the shapes that
exist today, not a proof over the shapes that could.