# Directive: Hardened Implementation Spec for the One-Front-Door `link`
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-08-25*
*Shipped: 2026-08-31 — B1–B9 all landed across PRs [#164](https://github.com/noah-goodrich/borg-collective/pull/164), [#165](https://github.com/noah-goodrich/borg-collective/pull/165), [#169](https://github.com/noah-goodrich/borg-collective/pull/169), [#175](https://github.com/noah-goodrich/borg-collective/pull/175) and [#176](https://github.com/noah-goodrich/borg-collective/pull/176); AC1/AC2/AC3/AC4 all MET. Archived as bookkeeping, not as new work.*

**tl;dr** — The plan's top risk (AC3's targeted fetch costing the 2.7s reflexive budget) is retired by measurement: the
fetch costs **87ms marginal**, not 770ms, once folded into the sweep query. The real cost was never AC3 — it was
`recon-adapter-github` issuing one serial REST call per repository. Replacing that loop with one batched GraphQL call
takes the all-repository sweep from **12.6s → 2.3s** and the repository-scoped sweep to **~0.9s**, clearing AC1's budget
with 3x headroom instead of scraping past it. A first-pass design of AC1/AC2/AC3 was reviewed blind by three adversarial
lenses and returned **unsound, 12 blockers**; this spec is that design with every blocker's fix folded in.

## 1. Measurements (taken 2026-08-25, this machine, warm cache, authenticated `gh`)

| What | Measured | Plan's assumption |
|---|---|---|
| Sweep, one repository, batched GraphQL | **0.69s** | 2.7s target |
| Sweep, all 14 repositories, batched GraphQL | **2.30s** | 12.5s "measured" |
| Current `recon` (serial `gh pr list` × 14 repos) | 12.6s | — |
| Targeted fetch, 14 declared refs, standalone | 0.77s | *"most likely way this fails"* |
| **Targeted fetch folded into the sweep query** | **+0.087s marginal** | — |
| Targeted fetch, 112 refs | 1.24s, **1** rate-limit point | — |
| Combined sweep (5 repos) + 14 declared refs, one query | 1.03s | — |
| Offline (`GH_HOST` unreachable) | fails in 0.056s | — |

Cost is flat at **1 rate-limit point** from 14 to 112 aliased nodes. There is no incentive to paginate or chunk
conservatively, and `MAX_CHUNKS`-style guards are dead code at any manifest size we will ever author.

**Root cause of the 12.6s**: `lib/recon/adapters/recon-adapter-github:64` is a serial `while IFS= read` loop over
projects; line 82 issues one `gh pr list --repo ... --search updated:>=DATE` REST call per repository. 14 repos ×
~0.9s ≈ 12.6s. This is an *internal* defect of the adapter, not a property of the adapter architecture.

## 2. The architecture call, and why it does not violate "sources are never hardcoded"

CLAUDE.md is explicit: recon sources are NEVER hardcoded; employer adapters (Slack/Jira/Notion) are a machine-injected
layer and this repo ships ONE reference adapter. The tempting fix — promote GitHub to a native collector inside
`borg_core` — directly contradicts that rule.

**It is also unnecessary.** The adapter contract is "an executable that takes a `since` mark plus a project list and
emits normalized Items." Nothing in that contract requires N REST calls. Rewrite `recon-adapter-github` internally to
issue **one batched GraphQL query for all in-scope repositories**, and the architecture is untouched while the cost
collapses. The adapter stays an adapter; it just stops being serial.

Verified on this machine: `github` is the only adapter present (`borg recon --adapters`), and there are no config-dir
adapters shadowing it. So this rewrite is observable end-to-end here, and the employer layer on the work machine is
unaffected — its adapters keep their existing fan-out and deadline.

**AC3's targeted fetch stays borg_core-side** (manifests are not an adapter concern; adapters must not learn about
rows). It runs concurrently with the adapter fan-out. Measured composition: ~0.9s adapter + ~0.8s fetch overlapped ≈
**~1.0s**, against a 2.7s budget.

## 3. Blockers from the blind review, and the binding fix for each

Three lenses (correctness/evidence, performance, scope/shippability) reviewed the first-pass design cold. Two returned
`unsound`. Three blockers were found **independently by all three reviewers** — those are marked ⚑.

### ⚑ B1 — The fzf preview is `deep`, not `porcelain`. The cited protection is inverted.

`borg.zsh:262` uses `cmd_ls --porcelain` to build the picker's *input list*, once. `borg.zsh:266` is
`--preview "borg link {1}"`, and `_borg_link_dispatch` routes a bare positional to `--deep`. So the mode fzf
re-executes on **every cursor move** is exactly the mode the first-pass design put a network sweep behind. Holding the
down-arrow through the registered repositories would fire one full sweep per keypress.

**Fix (binding):** protect the *call site*, not the mode. `deep` must stay sweep-capable — AC2 requires one renderer
whose contexts "differ in breadth only," and a permanently un-swept `deep` would be a third context with different data,
not different breadth. So `borg.zsh:266` becomes `--preview "borg link --local {1}"`, and the opt-down is explicit at
every hot-loop call site. Verify mechanically, not in prose: a bats case asserting `borg link --local <name>` spawns
zero `gh` subprocesses, plus a grep assertion that `borg.zsh:266` carries `--local`.

*(Rejected alternative: adding `deep` to the no-sweep set. It protects the preview but silently makes
`borg link <name>` — the shape `/borg-link`'s deep dive and every scripted caller use — render un-swept data under a
swept layout. That trades a visible latency bug for an invisible truthfulness bug, which is the wrong direction for a
plan whose whole point is derived fact.)*

### ⚑ B2 — `drone.zsh:964` calls `borg link "$wname"` inside a per-window loop.

`drone.zsh:933-975` `cmd_status()` iterates tmux windows and shells out to `borg link "$wname"` once each, greping
`Status:` at :965, with `2>/dev/null || true` swallowing every failure. Post-sweep that is N full sweeps for one status
table — and because scope derives from cwd, running it outside a registered repository root puts every call in
orchestrator scope.

**Fix (binding):** force `--local` at `drone.zsh:964` in the same commit as the sweep lands. Add a bats case asserting
`drone status` triggers no adapter subprocess. **Audit every `borg link` call site that sits inside a loop**, not only
the two the first-pass design happened to read (`cmd_watch` at `borg.zsh:2222` was the only one it caught).

### ⚑ B3 — Scope derived from cwd alone renders one repository's nodes under another's name.

The first-pass `scope_for(cwd, orchestrator_root, registry, local)` never sees the positional argument. `borg link ingle`
run from `borg-collective` resolves scope to `borg-collective`, sweeps it, and renders a grid whose focus header says
`ingle`. That is a wrong answer, not a missing one — the exact failure class AC3 exists to eliminate. Every scripted
caller hits it: `drone.zsh:964`, `cmd_switch:341/348`, the fzf preview, and `/borg-link`'s `borg link --json <project>`.

**Fix (binding):** the explicit positional **dominates** cwd.
`scope_for(cwd, orchestrator_root, registry, local, requested_project)` resolves to the requested project's registry
entry when non-empty, falling back to cwd only for the no-argument shape. pytest case: `_document(project='B')` invoked
from inside repository A yields `scope.repository == 'B'`.

### B4 — `ThreadPoolExecutor` hangs the process after output is complete (measured).

A `ThreadPoolExecutor` worker is a non-daemon thread joined by `concurrent.futures.thread`'s interpreter atexit hook.
Timing out the *future* does not cancel the *work*. The reviewer measured a submitted 12s subprocess with
`.result(timeout=2)`: output printed at 2.01s, **process did not exit until 12.08s**. With the first-pass
`fetch_states(timeout=10)` × `MAX_CHUNKS=3` against a `.result(timeout=15)` join, worst case is a front door that prints
and then sits for tens of seconds. `shutdown(wait=False)` does not fix it; the atexit hook still joins.

**Fix (binding):** no executor. The targeted fetch is a single `subprocess.Popen` — start it before the adapter fan-out,
`communicate(timeout=…)` after. No thread exists, so no thread can leak. Thread one monotonic deadline through any
chunk loop. Catch the timeout and degrade to the declared state per the resolve ladder. pytest asserts total process
wall clock stays under 12s when `gh` is mocked to sleep 30s.

### B5 — `gh` exits non-zero while `data` is fully usable.

Verified: a batch containing one bogus ref returns `errors: [NOT_FOUND]` **and** every valid sibling resolved (5/5).
Code that treats `returncode != 0` as total failure discards a good sweep over one dead ref — and renders exactly the
`unknown` AC3 forbids.

**Fix (binding):** always parse stdout. Merge `data` when present regardless of exit status; treat `errors[]` as
per-node, not per-query. Only an empty/unparseable stdout counts as total failure. pytest case over a fixture payload
carrying both `data` and `errors`.

### B6 — Manifest discovery scoped to the in-scope repository renders an empty grid for 3 of 4 member repositories.

`stillpoint/.borg/programs/ingle-t1-cutover.json` declares refs across `stillpoint-labs/{stillpoint,ingle,reveal,troth}`
but lives **only** under `stillpoint`. Repository-scoped discovery from `ingle` globs `ingle/.borg/programs/` → empty.
So `link` inside ingle, reveal, or troth pays the full sweep and renders nothing — which the plan's own risk section
says "reads as broken." Three of four member repositories is the modal case.

**Fix (binding):** always glob **every** registered repository's `.borg/programs` (a local glob over ~14 directories,
milliseconds), then filter to manifests whose `rows[].ref` prefix matches the scoped repository's `owner/repo`.
Discovery is global; *selection* is scoped.

### B7 — Golden-file snapshots would bake in live network state.

`_assert_link_golden` (the helper in `tests/cli_contract.bats`) runs the CLI with `2>&1` and byte-diffs. Once the sweep
lives in `_document`, goldens capture whatever GitHub returned that minute; `tests/test_helper/setup.bash` never
neutralizes `BORG_RECON_ADAPTER_PATH`, and the case *"contract: recon discovers the repo's shipped github adapter under
zsh (#113)"* exists specifically to prove the real adapter *is* discovered under zsh. Goldens become non-reproducible
on the second run, and `BORG_UPDATE_GOLDEN=1` would freeze one machine's network state as the oracle. `--local` is not
a substitute — it skips the very resolve ladder AC3 builds.

**Fix (binding):** define the stub **before** writing the renderer. An injectable seam read in the shell tier
(`BORG_LINK_SWEEP_FIXTURE`, `BORG_LINK_FETCH_FIXTURE`, each a path to a recorded JSON document), set by the golden
harness, plus a bats case asserting no `gh` subprocess runs under it. Export a neutralized `BORG_RECON_ADAPTER_PATH` in
`tests/test_helper/setup.bash` in the same commit, or all 46 existing link tests begin shelling to `gh auth status`.

### B8 — The registry-resolution guard would lose its teeth while appearing preserved.

*"contract: recon resolves the registry with no BORG_REGISTRY in the environment"* (in `cli_contract.bats`) has force
only because `recon/cli.py` `_die`s on a missing registry and on no-adapters-matched.
`borg link --json` has neither trap: `borg_core/registry/shell.py:34-37` **creates** `{"projects":{}}` when the file is
absent. Re-pointing that test at `link` yields exit 0 and an empty document whether or not `_borg_py` forwarded
`BORG_REGISTRY` — it can no longer distinguish "derived correctly" from "silently defaulted." That is precisely the
`reference_test_supplies_derived_value` failure the test was written to prevent, and the shape that shipped
`borg recon` dead.

**Fix (binding):** seed a registry at a path **no derivation can reach**, point `BORG_REGISTRY` at it from
`$BORG_DIR/config.zsh` (sourced at `borg.zsh:41`, after every default is applied), run
`zsh -c "unset BORG_REGISTRY BORG_DIR; borg link --json"`, and assert a uniquely-named project from that file appears
in `.order`. Assert on the sentinel, never on exit status — a mis-resolved registry is auto-created empty and exits 0.

**Amended 2026-08-26 (S4), after measurement.** This spec originally said *seed the **derived default** path*. That is
worthless, and it is worth recording why, because it is the same failure this blocker exists to prevent: `borg.zsh:24`
and `lib/registry.zsh:14-15` derive `BORG_DIR`/`BORG_REGISTRY` with the **same formula** `borg_core/paths.py` uses,
from the **same environment** the `python3` child inherits. Seed the sentinel at the derived default and delete both
forwarding lines from `_borg_py`, and the child re-derives the identical path, finds the sentinel, and the test stays
green — a test that supplies the value production is supposed to derive. A plain, unexported shell variable set in
`config.zsh` is the discriminator: the child sees it **only** if `_borg_py` names it. The `unset` is load-bearing for
the same reason — `setup_temp_dirs` exports both names and zsh keeps the export attribute across a bare reassignment.
Verified by mutation: deleting `BORG_REGISTRY="$BORG_REGISTRY"` from `_borg_py` turns the case red with an empty
`.order`.

### B9 — The first-pass latency arithmetic was wrong, and this spec's is the corrected one.

The reviewer independently re-measured: `gh auth status` 1.00s (not the assumed ~0.3s), `gh api user` 0.47s — a **1.47s
fixed prelude** inside the adapter before any repository work. End-to-end `borg recon --projects borg-collective --json`
measured 2.53s. Under the first-pass design, repository-scoped `link` landed at ~2.6-2.7s — *at* the AC1 target with
~0.0-0.2s of headroom, before the manifest glob, row join, level computation, and grid render had run at all.

**Fix (binding):** the batched-GraphQL adapter rewrite in §2 removes the per-repository REST calls; fold `viewer{login}`
into the same query to delete the `gh api user` round trip, and drop the `gh auth status` prelude in favour of handling
an auth error on the one real call. Hold the result with a test, not a claim: an eval case running repository-scoped
`link` three times that fails if the **median** wall clock exceeds 2.7s.

## 4. Sequencing

**AC1 → AC3 → AC2**, forced twice over:

- **AC1 first.** Both other ACs consume things that do not exist today. `borg link` has zero context awareness (no
  `getcwd` / `BORG_ORCHESTRATOR_ROOT` anywhere in `borg_core/link/`) and has never read a manifest. AC2's "both
  contexts" and AC3's "declared members" are undefined until `scope` and `declared_refs` exist in the document.
- **AC3 before AC2.** AC3 is assertable on the JSON document alone — `[.nodes[].state] | any(. == "unknown")` — with no
  renderer at all, so it can go red today and green on landing without touching a golden. If AC2 landed first, the grid
  would need an `unknown` rendering path that AC3 then deletes, and every golden would regenerate twice. Writing the
  renderer against an already-truthful document means the token `unknown` never enters `render.py`.
- **AC2 last** concentrates all consumer breakage in one commit: the goldens, `drone.zsh:964`'s `grep -m1 'Status:'`,
  `borg.zsh:266`'s preview contract, and these three `cli_contract.bats` cases — *"link --porcelain prints nothing at
  all on an empty registry"*, *"link \<project\> deep dive wraps and indents a summary longer than 70 columns"*, and
  *"drone status can still extract Status: from the deep dive"*. One regeneration, one review.
  (Anchored by name, not line: S4's insertions shifted every `cli_contract.bats:<N>` in this file by ~90 lines.)

Within AC1: **S1** env bridge + scope resolution (carrying B3's positional-dominates rule) → **S2** manifest reader →
**S3** adapter rewrite + sweep fold (carrying B1, B2, B6, B9) → **S4** verb retirement (carrying B8). S4 is last because
retiring `recon` before `link` can sweep would leave the machine with no working sweep between commits.

`_borg_py` must export `BORG_ORCHESTRATOR_ROOT` with the default applied **in the wrapper**, and the Python side must
independently default it in `borg_core/paths.py` — a module invoked directly has no wrapper. Do not add any
`BORG_RECON_*` name to the wrapper: those use `int(os.environ.get(...))` and an exported-empty value raises.

## 5. Baseline at spec time

`make test` — **432 passed, 97% coverage** (floor 90). `bats tests/` — **700 passed**. Both green before any change.

## 6. Non-goals inherited from the parent plan

No S1 `borg show`. No `--md`/`--html`. No `project` → `repository` internal rename (AC7 files it). No infoviz Track 6
blocker. No evals beyond AC5's three lifecycle skills. If done early, ship what we have.
