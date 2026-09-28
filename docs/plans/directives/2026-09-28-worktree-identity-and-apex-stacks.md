# Directive: borg keys state by directory; the work is keyed by repo and by apex stack

*Filed: 2026-09-28 — retro, from a session that shipped 5 PRs of the OLF ingestion train out of an unregistered
worktree and discovered borg could not see any of it.*

**tl;dr:** One git repo is three borg projects, four checkpoint stores and four `PROJECT_PLAN.md` copies with three
distinct contents, because `borg add` identifies a project by directory basename and nothing else. The decision
below is what to change, in what order, and what not to build. A blind adversarial review is included and it
**rejects the original first step** — read §5a and §6 before acting on §5. §6.1, which blocked the
recommendation, was ruled on 2026-09-28.

## 1. The diagnosis

Three systems are in play and each keys state by a different unit:

| System | Keys by | Where that is decided |
|---|---|---|
| **git** | repository | `git rev-parse --git-common-dir` |
| **the repo convention** | apex issue + merge-ordered stack, spanning repos and deploy planes | `docs/plans/directives/<slug>-stack.json` |
| **borg** | **directory basename** | `borg_core/registry/cli.py:45-46` |

`borg add` is two lines: `ppath = shell.resolve_path(...)` then `name = _basename(ppath)`. `build_add_entry`
(`borg_core/registry/core.py:32-49`) emits flat fields with **no repo, no parent, no kind**, and there is no git
call anywhere in the add path. So a git worktree is not a *view* of a project — it **is** a project, coequal with
its own parent, carrying its own `PROJECT_PLAN.md` slot, its own `.borg/checkpoints`, its own `state.json`.

Everything downstream follows from that one substitution. **State is partitioned by which directory a session
happened to start in; work is partitioned by repo and by stack; neither partition can see the other.**

The correct key already exists, is free, and is already computed twice in the codebase:

- `borg_core/manifest/shell.py:386-412 repository_slug()` resolves a directory to `owner/repo`, and at `:396-403`
  deliberately tests `os.path.exists(.../.git)` rather than `isdir` **because "a linked git worktree's `.git` is a
  file containing `gitdir: ...`"**. All three registered snowflake-permissions directories return the identical
  slug.
- `borg_core/manifest/shell.py:206 _manifest_identity` dedups manifests by hashing file bodies, with the comment
  that "a git worktree is the live case."

So borg reconstructs the relation by content-hashing, entry by entry, instead of stating it once. `--git-common-dir`
and `git worktree list` appear nowhere in the engine.

## 2. Measured state — snowflake-permissions, 2026-09-25

| | |
|---|---|
| git worktrees | **31** (24 under `~/dev/snowflake-permissions-*`, 6 under `~/.local/state/borg/worktrees/`, 3 in-repo `.wt-*`) |
| registered as borg projects | **3** — `snowflake-permissions`, `-olf`, `-wt-e2e` |
| checkpoint stores | **4** (68 / 5 / 0 / …) |
| `PROJECT_PLAN.md` copies | **4 files, 3 distinct contents** |
| checkpoint filename collisions | **3** — `2026-09-18-2215.md`, `2026-09-24-1000.md`, `2026-09-25-1704.md`, each existing in two stores with **different bodies** |

Two of those collisions were written in the same minute by two sessions on the same repo. Every reader sorts by
**name** (`borg_core/link/shell.py:402-416` returns filenames, not paths), so "the latest checkpoint" is a
different document depending on which directory you asked about.

### The two facts that make this a retro rather than a cleanup ticket

1. **All borg state is gitignored.** snowflake-permissions' `.gitignore:135` is `.borg/`, and `PROJECT_PLAN.md` is
   untracked. So git — the only thing that actually connects those 31 directories — is explicitly told to carry
   none of it. Note borg-collective's own `.gitignore:14-18` does the opposite: `.borg/*` plus `!.borg/checkpoints/`,
   `!.borg/skill-extensions/`, `!.borg/knowledge/`, `!.borg/programs/`. The blanket ignore is the outlier and the
   carve-out is one line.
2. **The apex and stack manifests are untracked.** `git check-ignore` exits 1 on
   `docs/plans/directives/olf-ingestion-apex.md` — it was never committed, not ignored. The OLF train shipped five
   PRs driven from a worktree that contains **no copy of the manifest that drove them**, and a third, newer copy
   lives in an unregistered `~/.local/state/borg/worktrees/` path.

### Writer split — the mechanical cause of the scatter

- `state.json` goes to the **resolved** project dir (`hooks/borg-link-down.sh:152-177`, via `_borg_find_project` →
  `_borg_resolve_proj_dir`).
- checkpoints go to **CWD** (`skills/borg-link-up/SKILL.md`, `<project-root>/.borg/checkpoints/<ts>.md`).

Two different resolutions for two halves of the same session's state.

### `PROJECT_PLAN.md` is single-slot by design, and the "project" is the directory

Three independent readers resolve `<dir>/PROJECT_PLAN.md` with no slot or glob: `borg_core/link/shell.py:436-449`,
`borg_core/manifest/cli.py:334-363`, `hooks/borg-link-down.sh:222`. Concurrency **was** designed for, but as
subordinate documents — a directive filed while a plan is active carries `*Parent plan: <slug>*` and promotion is
strictly serial (`lib/promote-next.sh:47-77` returns AUTO for exactly one candidate, ASK for two or more).

Several concurrent work items per project: yes. Several concurrent plans: no. Meanwhile snowflake-permissions is
running SME PAT, OLF ingestion, keypair migration, DCM migration and warehouse strategy at once.

One improvisation worth killing: that repo's plan says the previous one is "preserved verbatim at
`.borg/plans/<date>-<slug>.md`". **`.borg/plans` is not a borg concept** — zero code hits across borg-collective.
It is an invented second slot, and because `.borg/` is ignored it is both untracked and unread. The designed
archive is `docs/plans/assimilated/`.

## 3. Vocabulary — three names for one shape

| System | Calls it |
|---|---|
| borg | a **manifest** declaring **rows** in **lanes**, with **gates** |
| the repo | an **apex** with a **stack** |
| `stamp_stack.py` | a **Stack table** |

borg is mid-retirement of the word *program* (`borg_core/manifest/across.py:159`: "pinned never to invent
`program` … once AC7 finishes retiring the word"). Usage today: `row` 898, `manifest` 751, `lane` 295, `program` 88.
The `.borg/programs/` path outlived the noun. **Three names for one shape is part of why they do not compose** —
worth settling before wiring them together.

## 4. Options

**A — Teach borg the repo.** Add one additive `repo` field to `build_add_entry`, populated from
`git rev-parse --git-common-dir`; backfill 25 entries; change **readers, not writers**. `read_checkpoints()` becomes
a union read across entries sharing a repo, rendered with a byline (`2026-09-25-1704.md @snowflake-permissions-olf`)
so collisions stay distinguishable without renaming anything. `PROJECT_PLAN.md` resolves to the repo's **primary**
worktree. `recon`'s `--since` computes per repo group rather than globally.

**B — Make the stack manifest live on `main`; files are its cache.** Commit `<slug>-stack.json` and `<slug>-apex.md`
at stack creation, not at ship. Worktrees share refs, so all 31 directories get it for free. Plus: make
`stamp_stack.py` resolve paths against the repo root and refuse absolute ones — the main checkout's manifest
currently carries an **absolute** `bodyFile` into one machine's one checkout, pointing at an untracked file.

**C — Invert the mapping: register stacks, not directories.** `borg add --stack olf-ingestion --repo … --apex 427`.
Correct unit; bill is the identity spine (registry primary key, `_borg_find_project`, `_borg_resolve_proj_dir`,
tmux naming, `scope_for`, `borg switch`, the reaper).

**D — Fewer worktrees.** Rejected: they are the treatment, not the disease. A 20–120 minute plan step is why
parallel worktrees exist.

**Original recommendation: B now, A next. Not C, not D.**

## 5. …and the blind review rejects that first step

A reviewer that never saw the reasoning verified every load-bearing claim and returned
**adopt-with-changes — the order is wrong and step 3 as written damages the artifact it is meant to protect.**

What survived: the §1 diagnosis, the collision analysis, union-read-with-byline as the correct shape, and the
rejections of C and D.

What did not:

1. **The guard does not prevent the harm it is sold on.** B's priority argument is "a stamp from the wrong
   directory republishes a stale apex, idempotently." The proposed fix rejects a **path shape**; the damage is a
   **stale body**. After the fix every path is relative, the guard is permanently inert, and the harm is fully
   available.
2. **Step 2 picks the wrong copy for three of four stacks** — it warns "do not re-commit the Sep-18 copy" for OLF,
   then `git add`s main-checkout copies of the other three with no freshness check, having already established that
   newer unregistered copies exist.
3. **Step 3 regresses the flagship artifact.** `stamp_stack.py` on `main` has no unwrap; the live apex body is
   unwrapped and the file is hard-wrapped at 120, so publishing the raw file re-wraps the issue into `<br>` soup.
   *(Independently fixed 2026-09-25 in Ontra-ai/ai-data-engineer#51 — the reviewer rediscovered the same bug from
   the other direction, which is convergent evidence for both.)*
4. **Option A's reaper change is a data-loss vector billed "Breaks: Nothing."** `lib/reaper.sh` carries the
   contract "never touches worktrees outside `BORG_WORKTREE_STATE_DIR`"; the basename-derived boundary **is** that
   contract. Swapping in `git worktree list` moves 27 hand-made worktrees into reap scope, gated only on mtime and
   a clean tree — the "branch merged" check sets a reason string, it does not gate removal.
5. **The `.borg/programs/` rejection rests on a premise we control** — the gitignore carve-out is one line, and
   borg-collective already has it. Reject on the real objection (schema mismatch: borg's manifest is plan-shaped
   and apex-less at birth; the repo's is apex-and-merge-order-shaped) or not at all.
6. **B does not survive the cross-repo case, and this stack is the counterexample.** `olf-ingestion-stack.json`
   rows span `Ontra-ai/snowflake-permissions` **and** `Ontra-ai/infrastructure`; its `stamp` targets only the
   former. Committing to one repo's `main` gives 31 worktrees the manifest and zero on the other side. **This is
   the unanswered question.**
7. **Staleness-by-ref replaces staleness-by-directory, and is harder to see.** After B, a stamp from any feature
   branch reads an N-commits-stale manifest through a perfectly valid relative path. The old failure announced
   itself with an absolute path; the new one looks correct. Cheap fixes not proposed: read via
   `git show origin/main:<path>`, or refuse when `git merge-base --is-ancestor origin/main HEAD` fails.
8. **Three of seven acceptance criteria fail against the proposal's own steps** — including a `--dry-run`
   verification that exercises a code path the fix is not on.

## 5a. Verification on takeover, and one finding the retro missed

*Added 2026-09-28 by the session this was handed to. Every load-bearing claim in §1 and §2 was re-checked against
the tree rather than inherited: the add path is basename-only with zero git calls, `build_add_entry` emits seven
keys and no identity, `read_checkpoints` name-sorts filenames, `repository_slug` tests `exists(.git)` for
worktrees, `--git-common-dir` and `git worktree list` return zero hits across `borg_core/ lib/ hooks/`, and the
worktree/registration counts are exact. The store count is 4 as claimed; the two the retro elided as "0 / …" are
`-rbac` (2) and `-wt-smepat` (1).*

**The `BORG_WORKTREE_STATE_DIR` boundary is not strict. It is inert, and has been since it shipped.**

`lib/reaper.sh` defaulted the boundary to a literal `/Users/noah/.local/state/borg/worktrees`, which was already
wrong on the machine it shipped from — `$HOME` is `/Users/noahgoodrich`. `_borg_reap_worktrees` opens with
`[ -d "$wt_base" ] || return 0`, so it returned immediately for every registered repo. The hourly LaunchAgent has
run and removed nothing since `6501294` (2026-06-10, ~3.5 months) while 15 real borg worktrees accumulated across
9 repos under the correct path. Nothing in `borg.zsh`, `install.sh` or any hook sets the variable — the only
assignments in the tree are in `tests/reap_worktrees.bats` and `tests/cli_contract.bats`, whose line 968 *comments*
that the real default "is always overridden." Third instance of the pattern in CLAUDE.md's Learned list, beside the
`BORG_REGISTRY` and `XDG_CONFIG_HOME` entries: **a test that supplies the value the production path is supposed to
derive proves nothing about production.**

This does not overturn review point 4 — it changes what that point is an argument for. The 27 hand-made worktrees
really are outside the reaper's reach today, so Option A's reaper change really would be a data-loss vector billed
"Breaks: Nothing." But the mechanism is not "a strict boundary traded for a loose one." It is that
`git worktree list` would **switch a dead code path live and point it at 31 directories in the same change**, with
no observation of the reaper's real behaviour in between. That is a strictly worse starting position than the
review assumed, and it makes the §7 prohibition a sequencing constraint rather than a preference.

Fixed separately and first in **PR #232** (`fix/reaper-state-dir-default`), which is a prerequisite to Option A
rather than a part of it: default derived from `${XDG_STATE_HOME:-$HOME/.local/state}`, matching `install.sh:231-232`
and `borg.zsh:2482` so the reaper cannot scan a directory `borg doctor` does not report on; the same literal fixed
on the **writer** side in `agents/borg-nanoprobe.md` (4 occurrences), since a reader-only fix leaves every
nanoprobe worktree permanently out of scope; and 4 tests that assert the default with the variable unset,
mutation-verified red against the old literal. Blast radius was computed read-only before merge rather than
discovered after: 10 of 17 worktrees in scope on the first live run, all clean-tree, none losing work —
`git worktree remove` deletes the directory and not the branch, and both detached-HEAD worktrees resolve to commits
reachable from `origin/feat/olf-ingestion-trd`.

## 6. Open questions — decisions, not analysis

1. ~~**Cross-repo stacks.**~~ **RULED 2026-09-28: the apex issue's repo is home, and the other side resolves by
   slug.** The question as posed was a false binary. A manifest has exactly ONE authoritative copy, in the repo
   that owns its apex issue — so there is no duplication to pay for. The other repo is not reached by a second
   file; it is reached **by reference**, because the rows already carry their own `owner/repo` slug and the apex is
   an issue number, which makes `owner/repo#apex` a complete address. borg standing in `~/dev/infrastructure`
   already computes `repository_slug()` → `Ontra-ai/infrastructure`; what is missing is a **resolver** that answers
   "which stacks have rows for this slug", not a copy. This is also the only one of the three options consistent
   with §7's third bullet, which forbids keeping a copy and requires reading the stack JSON through an adapter.
   Review point 6 is answered and **B is unblocked on this axis** — though see Q2, which it does not settle.
2. **Does the stack manifest land on `main` at creation**, before its PRs exist? That is a change to how stacks
   start, not just to a script.
3. **Who lands the orphaned manifests** currently untracked in the main checkout — and which copy is authoritative,
   given three exist with 11/12/11 rows.
4. **Settle the vocabulary** (§3) before wiring apex-stacks to borg manifests.

## 7. What must not be built

- **Do not merge the checkpoint stores by moving files.** Readers return filenames, not paths
  (`borg_core/link/shell.py:402-416`), so a merge-write is data loss on three known collisions. **Settled by** the
  union-read-with-byline change to that same function, described in Option A (§4) — it gets the outcome with zero
  writes and no renames.
- **Do not give the reaper `git worktree list`** without first replacing the `BORG_WORKTREE_STATE_DIR` boundary
  with something equally strict. 27 hand-made worktrees, some carrying unpushed commits, are outside exactly that
  basename check today. **Sharpened by §5a:** that boundary is currently *inert*, not merely narrow, so the change
  would switch a dead code path live and widen it to 31 directories at once. **Settled by** either leaving
  `lib/reaper.sh` `_borg_reap_worktrees` untouched when Option A lands (the default, and what this directive
  recommends), or by a separate directive that specifies the replacement boundary and its test before any code
  moves — and in either case not before PR #232 has landed and the reaper has been observed doing real work once.
- **Do not duplicate the stack manifest into a borg manifest.** Two homes for merge order is the failure this repo
  has already paid for twice — three copies of one PR status in an apex, and a manifest key read off the wrong CLI
  version. If borg should see stack state, it should **read** the stack JSON via an adapter, not keep a copy.

## 8. Evidence

Full transcript — four investigation angles with file:line citations, the option survey, and the complete
eight-point teardown — is in `docs/plans/directives/assets/2026-09-28-worktree-identity-retro-evidence.md`.

### 8a. The state audit this retro triggered

`docs/plans/directives/assets/2026-09-28-state-audit-adversarial.md`, added 2026-09-28.

The retro's §1 diagnosis — *three systems, three keys* — prompted the wider question of whether borg's
JSON-and-filesystem state wants a real database, given cairn was decommissioned two months earlier. The audit answers
**no, and the engine is not the variable**: auto-memory (markdown on a filesystem) is failing the same pre-registered
metric cairn (Postgres + pgvector) failed, at 0.129 reads/session against a 0.2 bar. It censuses every store borg
touches — including the six it does not own — and finds **ten of sixteen `.borg/` subdirectory names have no code
reader at all**, one of which, `.borg/knowledge/`, is cairn's own export and is still named in `CLAUDE.md`'s
Architecture Rules as a place to grep for prior decisions.

It carries a second blind adversarial review, and it **breaks two of this directive's working assumptions**:

1. **"State travels with the branch" holds in exactly one repo.** Measured: borg-collective tracks 1220 files under
   `.borg/`, dotfiles 3, and every other sampled repo tracks **zero** — including three that ignore only
   `.borg/state.json` and could have tracked the rest. So `.borg/` is de facto machine-local everywhere except the
   repo that builds borg, and any argument from git-distribution generalizes one special case.
2. **Option A's checkpoint union-read is a palliative, and the audit says so plainly.** The collision it reconciles is
   a *writer-key* defect: `skills/borg-link-up/SKILL.md` already carries a collision guard, and that guard is scoped
   to the DIRECTORY — two sessions in two worktrees each check their own store, each find the name free, and both
   write it. The same unit error as this directive's §1, one level further down. The audit's first recommended fix is
   therefore at the writer, not the reader.

Its standing recommendation is four steps, **none of which is a storage-engine decision**: fix the checkpoint key at
the writer; ship a reader-census contract test; retire the ten unread stores (keeping `.borg/knowledge/`'s files but
deleting the instruction to grep them); consolidate the two machine-local roots with a retention policy. Postgres and
a second markdown vault are refused outright; SQLite is deferred until those four are shown insufficient.

Part 7 also records that the **board that would have consumed all of this already exists as three pending directives**
(`2026-08-11-viz-1-awaiting-you-tier`, `-viz-2-spine-generator`, `-viz-3-cross-repo-chains`) and that `story.json`,
their input, has had no generator and no write since 2026-07-28. Ten stores nothing reads, one store nothing writes:
the same defect from both ends.

Produced by a 5-agent sweep: borg data model, repo convention, observed damage, design synthesis, and a blind
adversarial review that never saw the design's reasoning.
