# Retro: borg projects, git worktrees, apex stacks — 2026-09-25

> Vocabulary note: borg is retiring the word *program* (borg_core/manifest/across.py:159).
> The unit is a **manifest** declaring **rows** in **lanes**. Agent text below predates that.

## BLIND ADVERSARIAL REVIEW (read this first)

## Verdict: adopt-with-changes — but the order is wrong and step 3 as written damages the artifact it is meant to protect

I verified every load-bearing claim against the live tree. The diagnosis in §1 is correct and well-evidenced. The
recommendation is not: **B's fix does not address the failure B is justified by**, and three of the seven acceptance
criteria fail against the proposal's own steps.

### What survives scrutiny

- §1's diagnosis (git keys by repo, the convention keys by program, borg keys by directory) is right, and
  `build_add_entry` at `borg_core/registry/core.py:32` really does emit seven flat fields with no repo/parent/kind.
- The collisions are real: `2026-09-18-2215.md`, `2026-09-24-1000.md`, `2026-09-25-1704.md` exist in both stores.
  Verified `read_checkpoints` (`borg_core/link/shell.py:402`) returns **filenames, not paths**, so union-read-with-byline
  is the correct shape and merge-write really would be data loss. §5 items 2 and 3 are sound.
- 31 worktrees, 25 registry entries, 3 of them worktrees of this repo — confirmed.
- The rejections of C and D are correct, for the reasons given.

---

### 1. The `isabs` guard does not prevent the harm it is sold on — and the harm is live right now

B's whole priority argument is "a stamp from the wrong directory republishes a week-old apex over #427, idempotently."
That is true. The proposed fix rejects a **path shape**. The damage comes from a **stale body**. After step 2 every path
is relative, the guard is permanently inert, and the harm is fully available.

Concretely, right now:

| copy | bytes | content |
|---|---|---|
| live issue #427 | 21916 | "four are merged and applied…", day-one read list = Frank He + Christopher Baek, TRD Decision 13 |
| `~/dev/snowflake-permissions/docs/plans/directives/olf-ingestion-apex.md` | 16716 | "The day-one read list has no names on it" |
| `~/.local/state/borg/worktrees/snowflake-permissions/olf-trd-restructure/…-apex.md` | 21897 | byte-matches the issue modulo wrapping |

`gh issue edit --body-file` is a full-body replace. Committing the main-checkout copy and running the stamper destroys
5.2 KB of newer content — with a clean relative path and a green guard. **The freshest copy of the apex is the GitHub
issue**, which inverts the document's own model: §2B's title says GitHub is the store and files are the cache; the
mechanism makes the file the store and the issue a render target that humans can edit and nothing reconciles.

### 2. Step 2 picks the wrong copy for three of four programs

It says "newest copy per program," correctly warns "do NOT re-commit the Sep-18 working copy" for OLF — then `git add`s
the main-checkout copies of dcm-implementation, password-deprecation and de1706 with no freshness check, having already
established that unregistered `~/.local/state/borg/worktrees/` copies exist. It applies its own lesson to one program
and not the other three.

### 3. Step 3, run exactly as written with a *correct* body, regresses #427's rendering

`stamp_stack.py` contains no unwrap (I read all 241 lines). The live #427 body is unwrapped; the file is hard-wrapped at
120. Publishing the raw file re-wraps the issue, which GitHub renders as `<br>` soup. The skill's real publish path is
stamp-then-unwrap; the document treats the stamper as the whole publisher. This is the one step billed "useful even if
nothing else ships," and as written it is net-negative on the flagship artifact.

### 4. Option A's reaper change is a data-loss vector billed as "Breaks: Nothing"

`lib/reaper.sh` `_borg_reap_worktrees` carries the contract "Never touches worktrees outside
`BORG_WORKTREE_STATE_DIR`." The basename-derived `wt_base` **is** that boundary, not a bug. Swapping in `git worktree
list` moves 27 hand-made worktrees — including this one — into reap scope. Removal is gated only on mtime > 12h and a
clean `git status --porcelain`; the "branch merged" check at `reaper.sh:127-137` sets the *reason string*, it does not
gate removal. And `git rev-parse --abbrev-ref olf@{upstream}` → `fatal: no upstream configured`: this branch's 6 commits
exist nowhere else. Refs survive `worktree remove --force`, so it is recoverable — but handing a 12-hour timer authority
over 27 directories is not "Breaks: Nothing," and the doc cites the `keypair-329-e2e` near-miss as evidence against
exactly this.

### 5. §5's rejection of `.borg/programs/` rests on a premise the proposal controls

It rejects the escape hatch because `.gitignore:135` is `.borg/`. borg-collective's own `.gitignore:14-18` is
`.borg/*` + `!.borg/checkpoints/` + `!.borg/programs/` + `!.borg/knowledge/`, and `borg_core/manifest/shell.py:206`
states `.borg/programs/` is git-tracked as a design fact. snowflake-permissions' blanket ignore is the outlier and the
carve-out is one line. There is a real objection — borg's manifest is plan-shaped and apex-less at birth, the repo's is
apex-and-merge-order-shaped, and wiring them creates the duplication the repo has been bitten by twice — and the
document never reaches it. Reject on the schema mismatch or not at all.

### 6. B does not survive the cross-repo case, and the doc's own program is the counterexample

`olf-ingestion-stack.json` rows span `Ontra-ai/snowflake-permissions` **and** `Ontra-ai/infrastructure`; its `stamp`
targets only snowflake-permissions. Committing to this repo's `main` gives all 31 worktrees the manifest and zero
infrastructure worktrees. A two-repo program gets one home repo (blind from the other side) or two copies (the forbidden
duplication). This is review question 3 and the document does not answer it.

### 7. Staleness-by-ref replaces staleness-by-directory, and is harder to see

This worktree is 9 behind / 6 ahead of `origin/main`. After B, a stamp from any feature branch reads an N-commits-stale
manifest through a perfectly valid relative path. The old failure announced itself (`/Users/noahgoodrich/…`); the new
one looks correct. Never mentioned. The cheap fixes the doc doesn't propose: read the manifest via
`git show origin/main:<path>`, or refuse when `git merge-base --is-ancestor origin/main HEAD` fails.

### 8. Acceptance criteria 1, 4 and 5 fail against the proposal's own steps

- **AC1** verifies with `--dry-run`, but §4 says put `_resolve` "at the `gh issue edit` call" — that is inside the `else`
  of `if dry:` (`stamp_stack.py:218-224`). The dry run prints and exits 0. Separately, the test passes an absolute
  *manifest* path (`argv[1]`), which `_resolve` never inspects; `argv[1]` stays cwd-resolved and unguarded.
- **AC5** already fails today: `git grep '"bodyFile": "/' origin/main -- docs/plans/directives/` hits
  `de1706-snowpipe-stack.json:6`, tracked on main since `df88eb8`. Step 2 adds only `de1706-snowpipe-apex.md` and never
  edits that manifest.
- **AC4** wants 5; `git ls-tree origin/main … | grep -c stack.json` is **2** today, step 2 adds 2 → 4, and the fifth
  needs PR #420 merged while step 2's own work sits on an unmerged branch.

### 9. Migration (question 4): half-migrated is worse than today

Today the staleness is self-announcing — untracked file, one machine's absolute path. After step 2 without a freshness
audit, `main` carries a tracked, blessed, relative, **wrong** body for three programs while fresher unregistered copies
persist. That is strictly worse. The 68 checkpoints are fine under A (union read never writes), but A's benefit is
smaller than advertised: the fan-in for this repo merges exactly 3 registry entries, and the other 28 worktrees have no
entry to carry the new field.

### 10. What it missed entirely

- **The unwrap transform** (finding 3) — a lossy step between "store" and "render" that breaks the file-is-source model.
- **Nothing writes `status`.** #427 showing B1/O1/G2 as `stacked` after both merged is not a path bug or a directory bug;
  no process reconciles `status` against `gh pr view`. Landing the file on `main` just makes the stale status repo-wide.
  Deriving `status` from `gh pr view --json state,mergedAt` is the best ratio in the whole document and is absent.
- **AC7 is the highest-value item and is ranked last with no owner and no place in the plan.** Confirmed: zero hits for
  `docs/plans|directive|apex` across CLAUDE.md. That — not path resolution — is why a cold session in any of 31
  directories cannot see a 9-row merge train. It costs one paragraph, no code, no migration, no prerequisites.
- **The freeze window is named as evidence and then never routed.** If the open #424→#426 window is the live #272-shaped
  hazard, it belongs in CLAUDE.md today, not as a downstream benefit of landing manifests.

---

### Do this instead — same options, reordered, three changes

**Step 0 (new, first).** Add a "Programs in flight" section to `CLAUDE.md` naming each apex by issue number and the open
`#424 → #426` freeze window. Zero prerequisites, zero migration, and it fixes the harm actually reported.

**Step 1 (revised).** Make the stamper refuse to publish a **stale body**, not just an absolute path: fetch the current
issue body, compare against the resolved `bodyFile`, refuse unless `--force` when the issue is newer than the file's last
commit. Add `isabs` too. Derive `status` from `gh`. Put `_resolve` **above** `if dry:` so `--dry-run` exercises it, and
guard `argv[1]`. Carry the unwrap into the stamper or the AC.

**Step 2 (gated on an audit).** Compare all copies per program — main checkout, every `~/.local/state/borg/worktrees/*`,
every worktree, **and the live issue body** — pick the winner, then commit. Fix `de1706-snowpipe-stack.json`'s absolute
path in the same commit so AC5 can pass. Decide the cross-repo home rule before, not after.

**Step 3.** Option A, **minus the reaper change**. Union-read + byline and repo-primary `PROJECT_PLAN.md` resolution are
sound and additive. Leave `lib/reaper.sh` alone; unregistered-worktree visibility belongs in a read-only report, not in
the code that deletes directories.

Not C, not D — agreed, for the doc's own reasons.

**Weakest parts:** §3's priority argument (fix doesn't match harm), §4 step 3 (damages #427), Option A's reaper bullet
(mislabeled as safe), §5 item 1 (circular premise). **Strongest:** §1's diagnosis, §5 items 2–3, and the C/D rejections.

Evidence files: `/Users/noahgoodrich/dev/borg-collective/lib/reaper.sh` (lines 96–137, the boundary and the
non-gating merge check), `/Users/noahgoodrich/dev/borg-collective/.gitignore` (lines 14–18, the carve-out the proposal
says doesn't exist), `/Users/noahgoodrich/dev/ai-data-engineer/plugins/data-engineer/skills/stacked-pr-program/scripts/stamp_stack.py`
(lines 213–224, the `if dry:` / `else:` split that breaks AC1), and
`/Users/noahgoodrich/.local/state/borg/worktrees/snowflake-permissions/olf-trd-restructure/docs/plans/directives/olf-ingestion-apex.md`
(the copy that actually matches issue #427).

---

## DESIGN + OPTIONS

# Directive draft — borg projects, git worktrees, and PR stacks

*Filed: 2026-09-25 — retro + decision. Parent plan: none; this is cross-cutting tooling. Filing slug must be declared,
not computed, when this lands (see "Filing", last section).*

---

## 0. What the main checkout looks like from here (live, 2026-09-25, read-only)

You asked what it looks like if I query the main directory. Side by side:

| | `~/dev/snowflake-permissions` | `~/dev/snowflake-permissions-olf` (this session) |
|---|---|---|
| registry key | `snowflake-permissions` | `snowflake-permissions-olf` |
| branch | `de-2107/owle-pgvector-postgres` | `olf` |
| `git rev-parse --git-common-dir` | `.git` (primary) | `…/dev/snowflake-permissions/.git` |
| `.borg-project` | `snowflake-permissions` | `snowflake-permissions-olf` |
| `PROJECT_PLAN.md` | present, **untracked**, "SME PAT Documentation Consistency", 7/9 | **absent** |
| `docs/plans/directives/` | 35 files, **16 untracked** | 19 files, all tracked |
| apex + stack JSON | all 5 programs — **all untracked** | **none** |
| `.borg/checkpoints/` | 68 | 5 |

Whole-repo numbers: **31 worktrees, 3 registered borg projects, 25 registry entries, 4 checkpoint stores, 4
`PROJECT_PLAN.md` copies with 3 distinct contents.**

The two facts that make this a retro rather than a cleanup ticket:

1. `git ls-files --error-unmatch PROJECT_PLAN.md` → `did not match any file(s) known to git`. `.gitignore:135` is
   `.borg/`. Neither the plan nor any borg state is in git — so git, the *only* thing that actually connects these 31
   directories, is explicitly told not to carry any of it.
2. `git check-ignore -v docs/plans/directives/olf-ingestion-apex.md` exits 1. The apex is **not** ignored — it was just
   never committed. The OLF program shipped five PRs today, driven from this worktree, and **this worktree contains no
   copy of the apex or the stack manifest that drove them.** The manifest that stamped issue #427 lives untracked in a
   directory this session is instructed not to `cd` into, and a *third*, newer copy lives in
   `~/.local/state/borg/worktrees/snowflake-permissions/olf-trd-restructure/` (mtime today 13:40), which is registered
   nowhere.

And the collisions are real, not theoretical — verified by md5 just now:

```
DIFF 2026-09-18-2215.md
DIFF 2026-09-24-1000.md
DIFF 2026-09-25-1704.md
```

Three checkpoint filenames exist in both stores with different bodies. Two were written in the same minute by two
sessions on the same repo. Every reader sorts by *name*, so "the latest checkpoint" is a different document depending on
which directory you asked about.

---

## 1. The diagnosis

Three systems are in play and each keys state by a different unit. **git** keys by repository. **The repo convention**
keys by program — an apex issue plus a merge-ordered stack spanning repos and deploy planes. **borg** keys by
*directory*, and by nothing else: `borg add` is `ppath = realpath(...)` then `name = basename(ppath)`, and
`build_add_entry` emits seven flat fields with no repo, no parent, no kind. A git worktree is therefore not a view of a
project to borg — it *is* a project, coequal with its own parent, with its own `PROJECT_PLAN.md` slot, its own
checkpoint store, its own `state.json`. Everything downstream follows from that one substitution. State gets partitioned
by the accident of which directory a session happened to start in, while the work is partitioned by program, and neither
partition can see the other. The durable, free, already-correct key exists on every one of the 31 directories —
`git rev-parse --git-common-dir` returns either `.git` or `/Users/noahgoodrich/dev/snowflake-permissions/.git` and
partitions all 31 correctly today — and nothing records it. borg *knows* the concept: `manifest/shell.py:206`
`_manifest_identity` dedups manifests by hashing file bodies specifically because "a git worktree is the live case," and
`:397` uses `-e` not `isdir` on `.git` because a worktree's `.git` is a file. It reconstructs the relation by content
hashing, entry by entry, rather than stating it once.

---

## 2. Options

### A — Teach borg the repo: one additive registry field, readers fan in

**Changes.** Add `repo` to `build_add_entry` (`borg_core/registry/core.py:32`), populated from
`git -C <path> rev-parse --git-common-dir`, realpath'd, `None` outside a repo. Backfill the 25 live entries. Then change
readers, not writers:

- `link/shell.py:402-416 read_checkpoints()` becomes a **union read** across all entries sharing a `repo`, rendered with
  a byline — `2026-09-25-1704.md @snowflake-permissions-olf` — so the three collisions stay distinguishable without
  renaming a single file (the filename stays the sort key and stays the clock-divergence probe input).
- `PROJECT_PLAN.md` resolves to the repo's **primary** worktree (the entry whose common-dir is literally `.git`), not to
  cwd. The olf session stops being nudged to create a second plan for one repo.
- `recon/shell.py:115 newest_checkpoint_epoch()` computes `--since` **per repo group**, not globally, so a 17:04
  checkpoint in olf stops silently narrowing main's sweep window.
- `recon-adapter-github` aliases by `repo`, so 30 PRs are fetched once and land in one bucket instead of an arbitrary
  one of three.
- `reaper.sh:96` stops building `wt_base` from the basename; `git worktree list` on the repo enumerates all 31 for free,
  which is how the 28 unregistered ones become visible at all.

**Costs.** Schema migration for 25 entries with no migration path today. Touches five readers. Warnings must be *named*
when a fan-in merges (silent blindness is this codebase's named failure class). Keep `_manifest_identity`'s content
dedup until every entry carries the field — do not swap one for the other.

**Breaks.** Nothing if the field is purely additive and basename stays the primary key — which it must, since it's
reached from `_drone_resolve`, `_borg_resolve_proj_dir`, tmux window naming, `borg switch`, and the reaper.

**Makes impossible.** Nothing. This is the option with no lock-in.

**Does not fix.** The apex still exists in four places with three contents. A is a *visibility* fix, not a
*single-source-of-truth* fix.

---

### B — Make GitHub the program store; files on `main` are its cache

**Changes.** Two moves, both on the repo/skill side, none on borg.

1. **Program manifests live on `main`.** `docs/plans/directives/<program>-stack.json` and `<program>-apex.md` are
   committed to the default branch *early* — when the program is created, not when it ships. Worktrees share refs, so
   every one of the 31 directories gets the manifest for free the moment it's on `main`. Today only
   `de1706-snowpipe-stack.json` and `de1896-stack.json` are tracked; the other five program files are untracked in one
   checkout.
2. **`stamp_stack.py` resolves paths against the repo root, and refuses absolute ones.** Right now
   `stamp_stack.py:213` does `json.load(open(sys.argv[1]))` and `:222` hands `bodyFile` straight to `gh --body-file`,
   which resolves it against **cwd**. And the main checkout's manifest carries
   `"bodyFile": "/Users/noahgoodrich/dev/snowflake-permissions/docs/plans/directives/olf-ingestion-apex.md"` — an
   absolute path into one machine's one checkout, pointing at an untracked file. Run the stamper from anywhere with that
   copy and you publish a Sep-18 apex body over today's, to issue #427, silently and idempotently.

The apex stays a GitHub issue (core rule 1, learned 2026-07-08 when diagrams vanished from rewritten PR bodies). The
stamped block stays byte-identical across PR bodies (rule 2). `validate_gates` stays before any `gh` mutation — path
resolution goes *after* it, not before.

**Costs.** A discipline change: the manifest lands on `main` before the program's PRs, which means committing a document
describing work that hasn't started. ~15 lines in `stamp_stack.py`. Someone has to land the five orphaned manifests
once.

**Breaks.** Nothing in the skill's six core rules. Apex-less ≤2-PR programs keep working — `de1896-stack.json` is
unaffected.

**Makes impossible.** Keeping a program's merge order private to one worktree while it's drafted. That is the point.

---

### C — Program-as-project: invert the mapping

**Changes.** Register programs, not directories: `borg add --program olf-ingestion --repo Ontra-ai/snowflake-permissions
--apex 427`. Checkpoints, plans and directives key by program; worktrees become an implementation detail that borg
resolves through `git worktree list`.

**Costs.** A rewrite of the identity spine: the registry's primary key, `_borg_find_project`, `_borg_resolve_proj_dir`,
tmux window naming, `scope_for`'s component-boundary matching, `borg switch`, the reaper. `registry/cli.py` is a
deliberate byte-for-byte port of the zsh `cmd_add` pinned by `tests/cli_contract.bats`, preserved bug and all.

**Breaks.** Basename keying — the registry's primary key, reached from five independent readers.

**Makes impossible.** Opening a directory that belongs to no declared program and just working. That is most of what
happens, including three of today's merged PRs and every one-off grant PR (#434, #324, #294).

**Verdict.** Correct model, wrong price. Revisit only if A ships and proves insufficient.

---

### D — Collapse the worktrees

**Changes.** Drive 31 → ~5, one per live program. Reap the rest. Enforce a naming convention.

**Costs.** `permifrost plan` runs ~40 minutes (#435 measured a 122-minute run). Parallel worktrees exist *because* of
that latency — the fragmentation is the cost of something load-bearing. Collapsing serializes ~10 concurrent
workstreams.

**Breaks.** Nothing technical.

**Makes impossible.** The way you actually work. Also: the `keypair-329-e2e` near-miss proved that pruning based on
committed content alone misses uncommitted work in unregistered worktrees. Any collapse must `git status` all 31, not
just compare refs.

**Verdict.** Worth doing as hygiene (42 → 30 already happened this week by hand). Not a fix for this problem.

---

### E — Do nothing

**Costs, named, all already incurred:**

- **The freeze window is visible in 1 of 4 stores.** olf's `2026-09-25-1704.md` §4 records that since 20:52Z `OLF_DEV` /
  `OLF_PROD` carry grants permifrost cannot see, and that *any* permifrost apply by anyone walks into it. A session
  resuming in `~/dev/snowflake-permissions` on #416 or #434 reads the branch-hygiene checkpoint, sees nothing, and runs
  apply into the open window — the exact #272 / 2026-05-22 shape `CLAUDE.md` exists to prevent.
- **SME PAT reports 7/9 when it is 9/9.** The registered project reads the main copy; the copy the plan's own header
  names (`wt-smepat`) has criteria 1 and 8 closed with evidence. `planstate` can't correct it: 0 `Evidence:`
  annotations → 9 `unknown` → 0 flips.
- **The same fix was written twice.** The `M generate_spec_file.py` + two untracked paths in this worktree right now are
  a weaker first cut of the #423 integrations fix that shipped from `feat/olf-role`. Only a human noticing stopped the
  inferior copy landing on a second branch.
- **Two retired plans are live.** `snowflake-permissions-rbac` and `wt-snowpipe` both restore "Drop Snowball & Switch to
  Nexus-Hosted Permifrost," retired 2026-09-01.

The damage rate scales with worktree count, and worktree count is going up.

---

## 3. Recommendation — **B now, A next. Not C, not D.**

**Do B first**, because B removes the only failure in this set that can *publish something false to other people*. The
apex issue and 11 PR bodies are what Kelly and the infra reviewers read; a stamp run from the wrong directory with the
absolute-path manifest republishes a week-old merge order to all of them, and does it idempotently, so nothing looks
wrong afterward. Every other breakage on this list is local blindness — bad, but it misleads one session, not the
reviewers of a live train with a 2026-10-05 external date.

**Then A**, because A is the only option that's purely additive: one field, five readers, basename stays the key,
nothing in `registry/cli.py`'s pinned contract moves.

**If you'd rather start with A** — and it's the more satisfying fix, because it addresses the root — here's the argument
against leading with it. A makes borg *show* you the OLF program state; it does not make that state correct. Today
there is no correct copy to show: three manifests, 11/12/11 rows, and the newest lives in an unregistered
`~/.local/state/borg/worktrees/` path. Pointing a better reader at four wrong files gets you a confident wrong answer
instead of an obviously missing one. B establishes the one copy; A then has something true to fan in.

**If you'd rather do C** — the program *is* the right unit, and C is where this ends up in a year. But C's bill is the
identity spine, and B+A buy most of C's outcome at a fraction of it: after B, program state is repo-wide and
GitHub-visible; after A, session state is repo-grouped. What C adds on top is cross-program checkpoint routing, which
isn't the thing that hurt today.

**Against D:** it treats 31 worktrees as the disease. They're the treatment for a 40–120 minute plan step.

### Two calls only you can make

1. **Who owns landing the five orphaned manifests** — they're untracked in your main checkout and the OLF pair is on
   open PR #420. I can't create them from here without forking a fourth copy.
2. **Does the stack manifest land on `main` at program creation**, before its PRs exist? That's the discipline change in
   B, and it's a change to how you start programs, not just to a script.

---

## 4. The smallest first step — one afternoon, useful even if nothing else ships

Three commands, in this order. Step 1 must land before step 3 or you republish the stale body.

**1 — Make the stamper repo-root-relative and reject absolute `bodyFile` (in `ai-data-engineer`):**

```bash
cd ~/dev/ai-data-engineer && git switch -c fix/stamp-stack-repo-root main && \
  $EDITOR plugins/data-engineer/skills/stacked-pr-program/scripts/stamp_stack.py
```

In `main()`, immediately **after** `validate_gates(manifest)` (never before — a malformed gate must still refuse first):

```python
root = os.path.realpath(subprocess.run(
    ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip())

def _resolve(p: str) -> str:
    if os.path.isabs(p):
        raise SystemExit(f"bodyFile must be repo-root-relative, got an absolute path: {p}")
    full = os.path.realpath(os.path.join(root, p))
    if not full.startswith(root + os.sep):
        raise SystemExit(f"bodyFile escapes the repo root: {p}")
    return full
```

Use `_resolve(apex["bodyFile"])` at the `gh issue edit` call. That one `isabs` check refuses the main checkout's
`/Users/noahgoodrich/dev/...` path outright — the machine-specific path is also what defeats SKILL.md:146's stated
purpose, "so anyone can re-stamp after merges." Do not touch `BLOCK_RE`; it stays anchored to whole lines (2026-08-12
data-loss entry).

**2 — Land the manifests on `main`, newest copy per program:**

```bash
# OLF: already pushed and newest. Land the branch — do NOT re-commit the Sep-18 working copy.
gh pr view 420 --repo Ontra-ai/snowflake-permissions --json state,mergeable

# The other four exist only as untracked files in the main checkout:
cd ~/dev/snowflake-permissions && git switch -c chore/land-program-manifests main && \
  git add docs/plans/directives/dcm-implementation-{apex.md,stack.json} \
          docs/plans/directives/password-deprecation-{apex.md,stack.json} \
          docs/plans/directives/de1706-snowpipe-apex.md && \
  git commit -m "docs(plans): land the program apex bodies and stack manifests on main"
```

Check each `bodyFile` is relative before committing — `grep -n bodyFile docs/plans/directives/*-stack.json`.

**3 — Re-stamp from `main`, dry first:**

```bash
cd ~/dev/snowflake-permissions && git switch main && git pull && \
  python3 ~/dev/ai-data-engineer/plugins/data-engineer/skills/stacked-pr-program/scripts/stamp_stack.py \
    docs/plans/directives/olf-ingestion-stack.json --dry-run
```

Issue #427 currently renders B1/O1/G2 as `stacked`. B1 #424 merged 20:52Z and O1 #425 merged 22:20Z. Anyone reading the
apex today is told #424 is next.

**Why this is useful standalone:** after step 2, all 31 worktrees can read every program's merge order and gates with no
borg change at all — including gate 6, the #424→#426 freeze window, which is the one that reproduces #272 and is open
right now.

### Acceptance criteria

- [ ] 1. `stamp_stack.py` refuses an absolute `bodyFile`.
      Verify: `python3 stamp_stack.py /tmp/abs-manifest.json --dry-run` exits non-zero with "must be repo-root-relative".
- [ ] 2. Path resolution runs after `validate_gates`.
      Verify: `grep -n -A6 'validate_gates(manifest)' scripts/stamp_stack.py` — `_resolve` appears below, not above.
- [ ] 3. `BLOCK_RE` unchanged.
      Verify: `tests/run-tests.sh` layer 4 passes.
- [ ] 4. All five programs' manifests are on `main`.
      Verify: `git ls-tree origin/main docs/plans/directives/ | grep -c 'stack.json'` returns 5.
- [ ] 5. No manifest on `main` carries an absolute path.
      Verify: `git grep -n '"bodyFile": "/' origin/main -- docs/plans/directives/` returns nothing.
- [ ] 6. A fresh worktree can re-stamp.
      Verify: from `~/dev/snowflake-permissions-olf` after `git pull`, `stamp_stack.py
      docs/plans/directives/olf-ingestion-stack.json --dry-run` runs clean.
- [ ] 7. `CLAUDE.md` routes an agent to the convention.
      Verify: `grep -n -i 'docs/plans\|directive\|apex' CLAUDE.md` — currently **zero hits across 216 lines**. This is
      why this session read CLAUDE.md cold, learned the permission discipline perfectly, and had no idea a 9-row
      cross-repo merge train with 8 human gates was mid-flight.

---

## 5. What must NOT be built

**1. A borg manifest for `snowflake-permissions` — do not teach `borg_core.manifest` to mirror the repo's stack JSON.**

This is the integration that looks obviously right. `borg link` would render the CHAINS grid; `manifest resolve` would
stop exiting 1; the row-add step in `/borg-link-up` would stop being a permanent no-op. It is the wrong move, and it is
the *third* instance of the failure this repo has already been bitten by twice — three copies of a PR status in one
apex, and a manifest key read off the wrong CLI version. `borg_core.manifest` and `docs/plans/directives/*-stack.json`
are two different manifests with the same name: borg's is plan-shaped and deliberately apex-less at birth ("Never pass
`--apex`. A plan has no PR yet."); the repo's is apex-and-merge-order-shaped from birth. Wiring them together means PR
status lives in two files and something has to reconcile them.

The obvious escape hatch — "just put the stack JSON in `.borg/programs/`, then there's one copy" — is worse, not better:
`.gitignore:135` ignores `.borg/`, so the manifest would become per-worktree and untracked, which is precisely the
disease. What borg should store is a **pointer**: the apex issue number, resolved through `gh issue view 427`. One fact,
one home, and the home is the one place every worktree and every teammate can already see.

**2. Do not commit `.borg/` or sync checkpoints through git.** It would end the divergence, and it would put session
transcripts into `permifrost plan` diffs and PR reviews, make every checkpoint a cross-worktree merge conflict, and
violate the reservation on `.borg/checkpoints` as user-authored space agents may not edit. Worse, the filename is the
key: `2026-09-25-1704.md` exists twice with different bodies, so `git add .borg/` is a **silent overwrite, not a
conflict**.

**3. Do not build a checkpoint merger or a shared checkpoint store.** Same reason — no content key, three live
collisions, two written in the same minute. **Union-read with a byline is safe; merge-write is data loss.** Option A
reads the union and renders the origin; it never writes across directories.

**4. Do not follow the `link-down` nudge in this worktree.** `borg-link-down.sh:221-229` fires "WORKFLOW REQUIREMENT —
NO PROJECT_PLAN.md FOUND" on every SessionStart here. Complying creates a second plan for one repo, which is the exact
thing the single-slot design exists to prevent. There are already 4 copies and 3 distinct contents. Silence that nudge
via the repo-primary resolution in Option A, not by writing a file.

**5. If anything ever validates `*Parent plan:*`, it reads the plan's declared `- Plan-slug:` line.** Never compute it
from a filename. A computed slug ran 268 characters and matched nothing, and nine directives went invisible to the gate
built to find them.

---

## Filing

This wants to be `docs/plans/directives/2026-09-25-worktree-program-state.md`, committed **on `main` from the main
checkout** — filing it from this worktree would fork a fourth copy of a program document, which is the failure being
reported. It has no natural parent apex (it's tooling, not DCM or OLF), so the `*Parent plan:*` line needs your call:
either a new `tooling-` apex or an explicit `none — cross-cutting`.

Two files hold the load-bearing evidence if you want to re-derive any of this:
`/Users/noahgoodrich/dev/snowflake-permissions/docs/plans/directives/olf-ingestion-stack.json` (line 6, the absolute
`bodyFile`) and `/Users/noahgoodrich/dev/ai-data-engineer/plugins/data-engineer/skills/stacked-pr-program/scripts/stamp_stack.py`
(lines 213 and 222, the `open(sys.argv[1])` / `--body-file` pair that resolves against cwd).

---

## ANGLE: borg data model

1. HOW BORG IDENTIFIES A PROJECT — basename, nothing else.

`borg add` is `borg_core/registry/cli.py:42-72`. Two lines decide identity:
  :45  `ppath = shell.resolve_path(path_arg or ".")`  -> `os.path.realpath`, `borg_core/registry/shell.py:85-94`
  :46  `name = _basename(ppath)`                      -> `path.rpartition("/")[2]`, cli.py:37-39
and `:66 shell.registry_merge(name, entry)` keys `.projects` on that string (`registry/shell.py:70-75`).
The entry payload is six flat fields (`registry/core.py:32-49`): path, source, tmux_session, tmux_window,
claude_session_id, last_activity. There is no repo field, no parent field, no git call anywhere in the add path.

Registry format (verified, ~/.config/borg/registry.json, 25 projects):
  "snowflake-permissions"        -> /Users/noahgoodrich/dev/snowflake-permissions
  "snowflake-permissions-olf"    -> /Users/noahgoodrich/dev/snowflake-permissions-olf
  "snowflake-permissions-wt-e2e" -> /Users/noahgoodrich/dev/snowflake-permissions-wt-e2e
Three peers. Nothing in the JSON says two of them are checkouts of the first.

Verified they are worktrees of one repo: `git -C <dir> rev-parse --git-common-dir` returns
`/Users/noahgoodrich/dev/snowflake-permissions/.git` for both, and `git worktree list` on main shows 31 worktrees
(24 under ~/dev/snowflake-permissions-*, 6 under ~/.local/state/borg/worktrees/snowflake-permissions/, 3 as
in-repo .wt-* dirs). Only 3 of the 31 are registered.

The `.borg-project` marker is NOT a repo pointer — it is a name override read by the hooks:
`lib/borg-hooks.sh:21-31 _borg_find_project()` walks up from CWD for the file, `cat`s it, and falls back to
`basename "$1"`. `lib/borg-hooks.sh:135-142 _borg_resolve_proj_dir()` then looks that NAME up in the registry and
returns `.projects[$name].path`, else CWD. Written by `drone.zsh:495` and `:574` as `$project_name`, which
`_drone_resolve` (drone.zsh:183-218) sets to the basename of whatever dir it was handed. So `drone feature`
(drone.zsh:782-825) creates `${project_dir%/*}/${project_name}-${feature}` — literally `snowflake-permissions-olf`
— then `:816 borg add "$work_dir"`, and the worktree is registered under its own basename.

Live proof the two conventions coexist on disk today:
  snowflake-permissions-olf/.borg-project      = "snowflake-permissions-olf"   (own project; own .borg/)
  snowflake-permissions-wt-smepat/.borg-project = "snowflake-permissions"      (aliased to parent)
  18 other ~/dev/snowflake-permissions-wt-* markers also say "snowflake-permissions".
Nothing enforces which one you get; it depends on the arg `drone up` was handed.

WHERE A WORKTREE WOULD BE DETECTED IF ANYTHING LOOKED. Two functions already do the right kind of test and
neither feeds registration:
  - `borg_core/manifest/shell.py:386-412 repository_slug()` resolves a directory to `owner/repo` via
    `git remote get-url origin`, and :396-403 deliberately uses `os.path.exists(.../.git)` not isdir precisely
    because "a linked git worktree's `.git` is a file containing `gitdir: ...`". Measured just now, all three
    registered dirs return the identical slug `Ontra-ai/snowflake-permissions`.
  - `borg_core/paths.py:23-43 repo_root_of()` walks for `.git` — used only by planstate/derive.py:37 and
    extensions/shell.py.
`--git-common-dir` and `git worktree list` appear nowhere in the engine (grep over borg.zsh, lib/, hooks/,
borg_core/): the only `worktree list` is in `agents/borg-nanoprobe.md:88` prose and a bats test. So borg already
computes a perfectly good repo identity (the slug) and throws it away everywhere except manifest selection.

2. PROJECT_PLAN.md IS ONE-PER-PROJECT BY DESIGN, AND THE "PROJECT" IS THE DIRECTORY.

Path resolution, three independent readers, all `<dir>/PROJECT_PLAN.md` with no slot or glob:
  - `borg_core/link/shell.py:436-449 read_plan()` — `plan = directory / "PROJECT_PLAN.md"`, directory from the
    registry entry's path.
  - `borg_core/manifest/cli.py:334-363 _declared_plan_slug()` — `os.path.join(repository_dir, "PROJECT_PLAN.md")`.
  - `hooks/borg-link-down.sh:222` — `[[ ! -f "$CWD/PROJECT_PLAN.md" ]]` fires the plan-mode nudge.
`skills/borg-plan/SKILL.md:162` writes it; `skills/borg-assimilate/SKILL.md:180-182` archives it to
`docs/plans/assimilated/<date>-<slug>.md` and deletes the root copy. Single slot, by construction.

Concurrency was designed for, but as SUBORDINATE documents, not peers: `skills/borg-plan/SKILL.md:118-142` says a
new directive filed while a plan is active goes to `docs/plans/directives/<date>-<slug>.md` carrying
`*Parent plan: <plan-slug>*`, and the slug must be READ from the plan's `- Plan-slug:` line, never computed
(`lib/promote-next.sh:79-95` explains why: a computed slug ran 268 chars and matched nothing, so nine directives
were invisible to the gate meant to find them). `skills/borg-assimilate/SKILL.md:60-61` blocks shipping while a
child directive is open. Promotion is strictly serial — `lib/promote-next.sh:47-77 _borg_promote_next_decide()`
returns AUTO for exactly one candidate, ASK for two or more.

So: several concurrent WORK ITEMS per project, yes (directives). Several concurrent PLANS, no.
The one part of the engine that is plan-agnostic is `borg_core/planstate/cli.py:110` — it takes an arbitrary
`plan` path argument, so evidence-derivation already works on any file. The single slot is a skills-and-hooks
convention layered on top of a per-file deriver, not a data-model limit.

Note on this repo's current plan: `/Users/noahgoodrich/dev/snowflake-permissions/PROJECT_PLAN.md:1-8` says it
supersedes the DCM Deploy Runway plan "preserved verbatim at `.borg/plans/2026-09-01-dcm-deploy-runway.md`".
`.borg/plans` is NOT a borg concept — grep for it across borg-collective returns zero code hits. It is an
improvised second slot, and since `.gitignore:135` ignores `.borg/`, that preserved plan is both untracked and
unread by every borg reader. The designed archive is `docs/plans/assimilated/`.

3. WHO READS .borg/checkpoints, AND WHAT THREE DIRECTORIES DO TO CONTINUITY.

Readers, all of them path-scoped:
  - `borg_core/link/shell.py:402-416 read_checkpoints()` — `<registry path>/.borg/checkpoints/*.md`, NAME sort.
  - `borg_core/link/shell.py:419-432 read_latest_checkpoint_head()` — head of the newest.
  - `borg_core/link/cli.py:71-73` — the deep-dive `focus` block, built from `entry.get("path")`.
  - `borg.zsh:1418-1431` — the overview prints the newest checkpoint for the top 3 projects, per registry path.
  - `hooks/borg-link-down.sh:379-380` — SessionStart injection, from `$CWD/.borg/checkpoints`, NOT the registry.
  - `borg_core/recon/shell.py:257-274 read_checkpoint_blockers()` — newest checkpoint of one project dir, fed to
    `core.project_contradictions` (recon/cli.py:63-66).
  - `borg_core/recon/shell.py:115-121 newest_checkpoint_epoch(project_dirs)` — the recon `--since` mark is the
    newest checkpoint across ALL project dirs (`core.resolve_since`, recon/core.py:35-54, precedence rule 2).

Writers split across two different resolutions, which is the root of the scatter:
  - state.json goes to the RESOLVED project dir: `hooks/borg-link-down.sh:152-177`
    (`_borg_find_project` -> `_borg_resolve_proj_dir` -> `_borg_state_write "$PROJ_DIR"`).
  - checkpoints go to CWD: `skills/borg-link-up/SKILL.md:271` writes `<project-root>/.borg/checkpoints/<ts>.md`,
    and `hooks/borg-link-up.sh:74` and `:128` both hardcode `$CWD/.borg/checkpoints` for the clock-divergence
    probe and the "no checkpoint in the last hour" nudge.
So a session in a worktree whose marker says `snowflake-permissions` writes its STATE to the parent and its
CHECKPOINT to the worktree. Verified on disk: wt-smepat's marker says `snowflake-permissions`, yet it holds
`.borg/checkpoints/2026-09-25-1033.md` and no state.json.

Measured checkpoint stores for this one repo:
  snowflake-permissions/.borg/checkpoints        68 files + PROJECT_PLAN.md + .borg/plans/ + briefings/ + inbox/
  snowflake-permissions-olf/.borg/checkpoints     5 files, no PROJECT_PLAN.md
  snowflake-permissions-wt-e2e/.borg              state.json ONLY — no checkpoints dir at all
  snowflake-permissions-rbac/.borg/checkpoints    2 files  (NOT registered — invisible to borg)
  snowflake-permissions-wt-smepat/.borg/checkpoints 1 file (NOT registered — invisible to borg)

Which one does borg surface? Whichever you name. `borg link snowflake-permissions` reads main's 68;
`borg link snowflake-permissions-olf` reads the olf 5 (link/cli.py:55-76 looks the name up and uses its path).
With no argument, scope comes from cwd via `borg_core/link/core.py:302-368 scope_for()`, longest
component-boundary path prefix — so a session in ~/dev/snowflake-permissions-olf resolves to the olf project, and
a session in ~/dev/snowflake-permissions/.wt-336 resolves to the PARENT (it is inside the parent's path). Sessions
under ~/.local/state/borg/worktrees/... match no registry path and fall through to `kind: orchestrator`.
`borg link-down` (the hook) ignores all of that and reads `$CWD` directly (borg-link-down.sh:379).

Three checkpoints carry the SAME filename in both stores with DIFFERENT content (2026-09-25-1704.md,
2026-09-24-1000.md, 2026-09-18-2215.md) — same-minute writes from two sessions on the same repo. Since both
readers sort by NAME, "the latest checkpoint" is a different document depending on which project you asked about.

Also: `.gitignore:135` in snowflake-permissions ignores `.borg/` wholesale, so none of this travels with the
branch and none of it is recoverable from git.

4. .borg/programs AND THE MANIFEST — ORTHOGONAL TO THE PLAN, AND IT IS THE STACKED-PR MODEL.

`borg_core/manifest/shell.py:57-69 manifest_dir()` is the one path rule: `<repository>/.borg/programs`, never
`<repository>/.borg/` and never the repo root. A manifest is `{apex, rows[], desc}`; rows key on `ref`
(`manifest/core.py` module docstring, "ROWS KEY ON `ref`"), where a ref is a full `owner/repo#number`, a Jira key,
or a link. Ordering is declared, not inferred: `core.py:193 ORDERING_EDGE_KINDS = ("stacked", "blocks")`,
`_stacked_edges` (:564) emits a `stacked` edge between consecutive rows in a lane, `after` entries and
`gate.blocked_by_ref` add more (:643-668). The docstring states the motive directly: "Branch topology only ever
links PRs inside ONE repository ... nothing mechanical says `stillpoint#48` must merge before `ingle#12`. That
ordering lives only in the head of whoever planned the work."

Relationship to PROJECT_PLAN.md — ORTHOGONAL, and explicitly coupled at exactly one point:
  - plan = objectives + acceptance criteria (prose a human validates).
  - manifest = the merge-order graph of refs (machine-readable, cross-repo).
  - `skills/borg-plan/SKILL.md:215` scaffolds the manifest immediately after writing the plan, "Unconditional —
    not an offer". `skills/borg-link-up/SKILL.md:179-190` RESOLVES one every session and may add a row, but is
    forbidden to create one.
  - The coupling: `borg_core/manifest/cli.py:366-412 _cmd_resolve()` — rule 2, exactly one manifest -> use it;
    rule 3, MORE THAN ONE -> pick the one whose `_id` equals the slug DECLARED by PROJECT_PLAN.md's
    `- Plan-slug:` line; rule 4, no match -> exit 1, never a guess.
So a repository MAY hold several manifests concurrently — that is the designed multi-program case — and the single
PROJECT_PLAN.md is the tiebreaker that says which one is current. Measured in that docstring: "across 22
registered repositories, 1 has any manifest and 0 has more than one." Confirmed today: only ~/dev/ai-data-engineer
and ~/dev/borg-collective have a `.borg/programs/`. snowflake-permissions has none, in any worktree.

Discovery is GLOBAL, selection is SCOPED (`manifest/shell.py:337-357 discover_registered` sweeps every registered
path; `manifest/core.py:780-799 select_for_repository` narrows on the repo slug a row's ref parses to). Since all
three snowflake-permissions projects return the same slug, `borg link` would render an IDENTICAL grid under all
three headers.

planstate is the third, separate leg: `borg_core/planstate/derive.py:66+` reads one plan file, resolves each
criterion's `pr:` / `path:` / `pytest:` / `bats:` annotation to pass/fail/unknown, and `--apply` flips only
`- [ ]` lines whose verdict is `pass`. It is per-FILE (cli.py:110), so it already works on directives.

5. WHAT BORG ALREADY KNOWS ABOUT WORKTREES AND STACKS — more than expected, in exactly two places.

KNOWN, deliberately handled:
  - `manifest/shell.py:206-223 _manifest_identity()` + `:239-246` in `discover()`: manifests are deduplicated
    TWICE, on realpath'd directory and on CONTENT, and the docstring names the reason — "a git worktree is the
    live case, since `.borg/programs/` is git-tracked, so `drone feature` produces a second checkout of every
    manifest and `borg add` registers it beside its parent ... the grid would render every node, every gate and
    every declared ref twice under one header."
  - `lib/recon/adapters/recon-adapter-github:137-143`: "Two projects may legitimately resolve to the SAME
    repository (a worktree registered alongside its parent)" — it aliases the GraphQL batch by project line index
    rather than by repo, so each registered worktree gets its own copy of the same 30 PRs. The duplicates are then
    collapsed by ref in `borg_core/recon/core.py:186-195`, and whichever project's copy wins takes the whole item
    into ITS bucket (`merge_by_project`, :250-261).
  - `manifest/shell.py:396-403` and the adapter's `:99-103`: both use `-e`/`os.path.exists` on `.git`, and both
    carry a comment saying the other must never diverge.
  - Stacked PRs: the manifest schema, above. Also a separate, unrelated implementation exists outside borg —
    the `data-engineer:stacked-pr-program` skill's master Stack table — which shares no data with manifests.
  - Nanoprobe worktrees: `lib/reaper.sh:41-140` reaps only worktrees under
    `${BORG_WORKTREE_STATE_DIR}/${repo##*/}` (default ~/.local/state/borg/worktrees). Note `repo_name` is the
    BASENAME again (:98), so `borg reap-worktrees snowflake-permissions-olf` looks in a directory that does not
    exist and silently no-ops.

NOT KNOWN ANYWHERE:
  - No code links a registered project to its parent repo. No `--git-common-dir`, no `git worktree list` in the
    engine.
  - The registry has no field that could hold it (`registry/core.py:32-49`).
  - Checkpoints, state.json, PROJECT_PLAN.md, docs/plans/directives and the briefings/inbox/drafts dirs are all
    resolved per-DIRECTORY, with zero dedup or merge across sibling worktrees.
  - `borg_core/link/core.py:285-294 project_paths()` returns every entry verbatim; the overview has no notion
    that three rows are one repo.

**Breakages:**

1. CONTINUITY IS SPLIT FIVE WAYS FOR ONE REPO, AND THREE OF THE FIVE ARE INVISIBLE.
   Manifests: main 68 checkpoints, olf 5, rbac 2, wt-smepat 1, wt-e2e 0. Only main/olf/wt-e2e are registered, so
   the rbac and wt-smepat checkpoints (the newest is 2026-09-25-1033, yesterday) can never be surfaced by
   `borg link`, `borg recon`, or the SessionStart hook from anywhere but their own directory.
   Manifests: a session in the olf worktree that reads "the latest checkpoint" gets 2026-09-25-1704.md from the
   OLF store; a session in main gets a DIFFERENT file with the same name. Neither knows the other exists.

2. SAME-NAMED, DIFFERENT-CONTENT CHECKPOINTS.
   `.borg/checkpoints/2026-09-25-1704.md`, `2026-09-24-1000.md` and `2026-09-18-2215.md` exist in both main and
   olf with different bodies (verified by diff). Every reader sorts by NAME (link/shell.py:402-416,
   borg.zsh:1421, recon/shell.py:266). There is no merge and no collision detection — two sessions checkpointing
   in the same minute on the same repo produce two documents that look like one.

3. THE OLF WORKTREE HAS NO PLAN, AND THE HOOK KEEPS TELLING IT TO MAKE ONE.
   `hooks/borg-link-down.sh:221-229` fires the "WORKFLOW REQUIREMENT — NO PROJECT_PLAN.md FOUND" nudge on every
   SessionStart in ~/dev/snowflake-permissions-olf, because the plan lives in the main checkout and `.borg/` +
   PROJECT_PLAN.md are not git-tracked here (`.gitignore:135` ignores `.borg/`; `git ls-files PROJECT_PLAN.md`
   is empty). Following the nudge would create a SECOND plan for one repo, which is the thing the single-slot
   design exists to prevent. Ignoring it means the acceptance criteria the olf work is judged against are in a
   directory that session never reads.

4. THE RECON `--since` MARK IS SET BY WHICHEVER WORKTREE CHECKPOINTED LAST.
   `borg_core/recon/shell.py:158` -> `newest_checkpoint_epoch(project_dirs)` takes the newest checkpoint across
   ALL project dirs and `core.resolve_since` (recon/core.py:50-51) makes it the sweep window for EVERY project.
   A 17:04 checkpoint written in the olf worktree silently narrows main's "what changed" window to since-17:04,
   even though main's own last checkpoint may be older.

5. PR ATTRIBUTION LANDS IN AN ARBITRARY BUCKET.
   The github adapter emits the same 30 PRs three times, once per registered worktree
   (recon-adapter-github:137-143). `recon/core.py:186-195` keeps one copy per ref; ties keep the first track's
   item and the loser's project bucket is emptied. So a snowflake-permissions PR can be filed under
   `snowflake-permissions-olf`, and `project_contradictions` (recon/cli.py:63-66) then checks it against the OLF
   checkpoint's Blockers section rather than main's — the stale-blocker detector can only see the blockers of
   whichever bucket won.

6. STACK/MERGE-ORDER STATE IS NOT IN BORG AT ALL FOR THIS REPO.
   No `.borg/programs/` exists in any snowflake-permissions worktree, so `manifest.cli resolve` exits 1 in all of
   them, `/borg-link-up`'s row-add step is a permanent no-op (skills/borg-link-up/SKILL.md:249), and the CHAINS
   grid renders empty. The actual merge order for the current stacked work lives only in the
   `data-engineer:stacked-pr-program` master table in PR bodies — a parallel system borg cannot read.

7. `.borg/plans/` IS A SLOT BORG DOES NOT KNOW ABOUT.
   PROJECT_PLAN.md:1-8 points at `.borg/plans/2026-09-01-dcm-deploy-runway.md` as the preserved superseded plan.
   Zero code in borg-collective references `.borg/plans`, and `.gitignore:135` makes it untracked. The designed
   archive is `docs/plans/assimilated/` (skills/borg-assimilate/SKILL.md:180). That plan is preserved nowhere a
   reader or a teammate will find it.

8. `borg reap-worktrees snowflake-permissions-olf` SILENTLY DOES NOTHING.
   `lib/reaper.sh:96-100` builds `wt_base` from `${repo##*/}` — the project basename — so for a worktree-as-project
   it looks under ~/.local/state/borg/worktrees/snowflake-permissions-olf/, which does not exist, and returns 0.
   Separately, the 24 `~/dev/snowflake-permissions-*` worktrees are outside the state dir and are never reaped by
   design (reaper.sh:46-47), which is how 31 worktrees accumulated.

9. THE TWO MARKER CONVENTIONS ARE IN CONFLICT AND NOTHING ADJUDICATES.
   18 worktrees carry `.borg-project` = `snowflake-permissions` (alias to parent: state goes to the parent,
   checkpoints still go to CWD — a half-merge). One carries its own name (full fork). One carries no marker at
   all (wt-e2e: `_borg_find_project` falls back to basename, which happens to match its registry key). Which
   behavior a session gets depends on which argument `drone up` was invoked with months ago.

---

## ANGLE: repo convention

## What a fresh copy sees vs. the main checkout

The main checkout is `/Users/noahgoodrich/dev/snowflake-permissions`, on branch `de-2107/owle-pgvector-postgres`, with
30 worktrees attached (`git worktree list`). `docs/plans/directives/` there holds **36 entries**. This worktree
(`/Users/noahgoodrich/dev/snowflake-permissions-olf`, branch `olf`) holds **19**.

The gap is not branch drift. `git ls-files docs/plans/directives/` returns the **same 19 files** in both checkouts, and
`git ls-tree origin/main` returns the same 19. The extra 17 in the main checkout are **untracked working-tree files**
(`??` in `git status`), including every apex and every stack manifest:

```
?? docs/plans/directives/olf-ingestion-apex.md
?? docs/plans/directives/olf-ingestion-stack.json
?? docs/plans/directives/dcm-implementation-apex.md
?? docs/plans/directives/password-deprecation-apex.md
?? docs/plans/directives/de1706-snowpipe-apex.md
?? PROJECT_PLAN.md
```

`git check-ignore -v docs/plans/directives/olf-ingestion-apex.md` exits 1 — they are not gitignored, just never
committed on that branch. Only two manifests are tracked on `main`: `de1706-snowpipe-stack.json` and
`de1896-stack.json`.

## 1. What a directive is

A directive is a **ratified decision record with executable acceptance criteria**, filed at
`docs/plans/directives/<date>-<slug>.md`. Shape, from
`/Users/noahgoodrich/dev/snowflake-permissions/docs/plans/directives/2026-09-03-dcm-permifrost-lifecycle-parity.md:1-4`:

```
# Directive: DCM and the companion adopt permifrost's deploy lifecycle
*Parent plan: dcm-implementation-apex*
*Filed: 2026-09-03 — ratified by Noah Goodrich in review of [#392](...)*
```

Sections that recur across all of them: **The decision** / **Objective**, **What is wrong today** (usually a
side-by-side table), **Why X is correct and stays** (defensive: records what was raised and rejected), **Acceptance
criteria** (numbered, `- [ ]` checkboxes, each with its own `Verify:` line naming a runnable command), **Scope
boundaries** (explicit `NOT` list), **Risk**.

The `Verify:` line is the load-bearing part — it is a command, not an assertion:

> - [x] **5. `fail-on-DROP` is explicitly NOT implemented** … Verify: `grep -n fail-on-DROP
>   docs/architecture/dcm-project-organization-decision.md` — every hit references this directive.

A directive is **not** a plan. `2026-09-03-adhoc-sandbox-execution-gate.md:4-6` says so out loud:

> Parented to the DCM apex rather than the active `PROJECT_PLAN.md` (SME PAT Documentation Consistency), which is a
> different program. Lineage is the ad-hoc runner and deploy-safety line.

So `PROJECT_PLAN.md` (borg's artifact, one per repo, root-level, "locked" criteria) is the *current* work; directives are
a **queue of independently-parented decisions**, many filed while a different plan was active. That is why 24 of them
coexist. `docs/plans/2026-08-10-directive-audit.md` audited them and kept 23 of 24 — "this backlog is not bloated with
finished paperwork, it is a real queue of unfinished work that has drifted out of date."

Directives also serve a third mode that borg has no slot for: **diagnosed-and-deliberately-not-fixed.**
`2026-09-25-permifrost-plan-latency.md:1-24` (on `snowflake-permissions-wt-latency`, unmerged):

> **Do nothing now.** The cause is understood and written down below; acting on it is deferred until the slow runs
> recur. This directive exists so that when they do, nobody spends another afternoon re-deriving the answer.
>
> **Threshold: 3 or more runs whose EXECUTION exceeds 45 minutes, in a rolling 100.** Measured at filing: **exec >45m =
> 2, queued >5m = 2**.

It ships a `gh api` one-liner as the trip-wire. A borg plan has no way to express "no acceptance criteria, resume on a
measured trigger."

## 2. What the apex models that a plan does not

`git show origin/feat/olf-ingestion-trd:docs/plans/directives/olf-ingestion-apex.md` — 16 KB, the body of GitHub issue
**#427**. It carries six things a `PROJECT_PLAN.md` structurally cannot:

- **A merge-ordered table across repos and planes.** Rows are lane-prefixed (`D1/C1/P1/I1/S1/G1/B1/O1/G2`) and span
  `Ontra-ai/snowflake-permissions` and `Ontra-ai/infrastructure`. A plan's acceptance criteria are a flat checklist with
  no ordering semantics and no notion of another repo.
- **Deploy state distinct from merge state.** Row P1: "must be DEPLOYED, not merely merged." Gate 4: "Merging deploys
  nothing, so merged-but-undeployed is the normal state." No checkbox can hold that distinction.
- **Named human gates CI will not run** — 8 numbered items, e.g. gate 6, the freeze window: "In that gap `OWN_OLF_<ENV>`
  owns two databases permifrost has never heard of, the same shape as the #272 incident."
- **Open decisions with an owner and a date stamp**, each closed in place: "The day-one read list: closed 2026-09-22.
  Jess Grider set the policy… Christopher named the list the same day: Frank He and Christopher Baek."
- **The behavioural facts the design rests on**, sandbox-measured: "`GRANT OWNERSHIP … COPY CURRENT GRANTS` fails as
  plain SYSADMIN"; "`CREATE PIPE` with `AUTO_INGEST` validates S3 at create time… That is why the pipe is last."
- **A rendered dependency diagram**, pinned to an issue rather than a PR body.

### The gate schema specifically

In `olf-ingestion-stack.json`, a `stacked` row carries its own settlement:

```json
"gate": {
  "blocked_by": "G1 must be applied. OWN_OLF_<ENV> must exist before ownership can be transferred to it.",
  "kind": "verification",
  "resolved_by": "permifrost apply on PR 423, then confirm by hand with USE SECONDARY ROLES NONE and USE ROLE OWN_OLF_<ENV>",
  "outcomes": [
    "role exists -> merge B1 deliberately; it applies on merge with no plan gate",
    "role absent -> the ownership transfer fails, the file is not registered, and it re-runs after a fix"
  ]
}
```

`kind` is closed to `decision` | `verification`. The skill's iteration log (SKILL.md, 2026-08-11 entry) explains why
that two-word vocabulary is the point, not decoration:

> Root cause: **the settlements and the blockers lived in different documents, and only the blockers had pointers.**
> `gate.resolved_by` forces the pointer to travel *with* the blocker… the one item that genuinely *was* open (item 3a)
> was a **verification**, not a decision, but was filed as "needs a human's call" and parked work that needed nobody —
> when someone finally ran it… it passed in under ten minutes.

And: "a `verification` with declared outcomes is **never a blocker on a person**, because anyone can run it and the row
stays actionable whichever way it lands."

`stamp_stack.py:87-121` (`validate_gates`) enforces it, reporting every offending row in one pass and exiting non-zero
**before** any `gh` mutation, "so a malformed gate can never half-stamp a program."

## 3. The stacked-pr-program skill

`/Users/noahgoodrich/dev/ai-data-engineer/plugins/data-engineer/skills/stacked-pr-program/` — `SKILL.md` (22 KB, 6 core
rules + ~10 iteration-log entries), `scripts/stamp_stack.py` (241 lines), 3 example manifests, plus a warn-only
`PostToolUse` lint hook at `plugins/data-engineer/hooks/stacked_pr_gate_lint.py`.

**It owns**: the master-table format; the `<!-- ORCHESTRATOR-CHAIN -->` marker block mirrored byte-identical into every
PR body; the status vocabulary (`merged` / `approved` / `review` / `stacked`); the `next` marker; the `gate` schema; apex
rules (one apex issue per program, diagrams in issues only); and idempotent publication via `gh issue edit` +
`gh pr edit`.

**It explicitly does not own** branch mechanics — core rule 4 defers those to GitHub native stacked PRs and
`gh stack sync` / `view` / `merge`, and positions itself as "the program layer on top… tickets, apex gates, and status
semantics `gh stack view` doesn't track."

**What it assumes about the manifest's home** (SKILL.md:146-148):

> Keep each program's manifest under the program's repo (e.g. `docs/plans/directives/<program>-stack.json`) so anyone
> can re-stamp after merges.

That is an *instruction to a human*, not a mechanism. `stamp_stack.py` has no path logic at all: `manifest =
json.load(open(sys.argv[1]))` (`:213`), then `gh(["issue","edit",…,"--body-file", apex["bodyFile"]])` (`:222`).
`bodyFile` is opened by `gh` relative to **cwd**, and the schema example at SKILL.md:116 literally shows
`"bodyFile": "/abs/path.md"`. There is no repo-root resolution, no "find the manifest," no check that the manifest is
committed.

## 4. `docs/plans/assimilated/`

Four files, all `# Project Plan: …` documents — i.e. **retired `PROJECT_PLAN.md` copies**, not directives.
`2026-05-19-keypair-lib-prototype.md:1-3`:

```
# Project Plan: Keypair Lib Prototype
*Established: 2026-05-15*
*Shipped: 2026-05-28 (via PR #266)*
```

A plan lands there when `/borg-assimilate` ships it. The handoff rule is written in the live `PROJECT_PLAN.md` header:

> *Supersedes the **DCM Deploy Runway** plan, which reached 6/6 and is blocked only on review of #392. Preserved
> verbatim at `.borg/plans/2026-09-01-dcm-deploy-runway.md`; archive it to `docs/plans/assimilated/` once #392 merges
> and its post-merge deploy is verified.*

So there is a staging step: superseded-but-unverified plans park in **gitignored** `.borg/plans/`, and only move to
tracked `docs/plans/assimilated/` after the merge is verified. Two sibling dirs complete the taxonomy:
`docs/plans/severed/permifrost-fork.md` (abandoned/fulfilled gates) and `docs/plans/proposals/` (not yet ratified).

Assimilated is nearly dormant: `git log -- docs/plans/assimilated/` shows **2 commits**, last one in the #291 keypair
batch. Four archived plans against 24 live directives.

## 5. CLAUDE.md

216 lines. `grep -n -i "borg\|PROJECT_PLAN\|docs/plans\|directive" CLAUDE.md` returns **zero hits**. It mentions borg
nowhere, and the entire planning convention nowhere.

What it *does* point an agent at, as canonical:

- `docs/architecture/dcm-project-organization.md` — "it is canonical and has the object → home routing table. We keep
  re-deciding this; don't."
- `PERMIFROST_RUNBOOK.md` — operations.
- Two inline CRITICAL sections: Permission Change Discipline (the #272 incident) and the Permifrost Version Validation
  Rule.

So an agent that reads only CLAUDE.md learns the repo's *operational* rules perfectly and does not learn that
`docs/plans/directives/` exists, that apexes are the program tracker, or that `stamp_stack.py` must be re-run after a
merge.

## 6. Borg state for this repo

- `.borg/` is gitignored (`.gitignore:135`), so every worktree keeps its own. Checkpoint sets have already diverged: the
  main checkout has `2026-09-25-1704.md`, `2026-09-24-1000.md`, `2026-09-23-1530.md`; this worktree has
  `2026-09-25-1704.md`, `2026-09-24-1000.md`, `2026-09-19-1420.md`, …
- `find ~/.local/state/borg -name "*manifest*"` → **nothing**. `find .../snowflake-permissions/.borg -name "*manifest*"`
  → **nothing**. The repo has no borg manifest, confirming the program ran without one.
- `.borg-project` differs by checkout: `snowflake-permissions` in main, `snowflake-permissions-olf` here — so borg treats
  this worktree as a separate project.
- Borg is **not** ignorant of the convention. `/Users/noahgoodrich/dev/borg-collective-shim/skills/borg-plan/SKILL.md`
  :118-143 already writes directives to `docs/plans/directives/<date>-<slug>.md` with `*Parent plan: <plan-slug>*`, and
  warns: "A computed slug writes a `*Parent plan:*` line no gate will ever match, which is exactly how nine directives
  came to be invisible to the check meant to find them." :215-231 scaffolds a manifest via `borg_core.manifest.cli
  scaffold` with "**Never pass `--apex`.** A plan has no PR yet. Rows arrive at link-up."

That last line is the seam. Borg's manifest is plan-shaped and apex-less by design; the repo's manifest is
apex-and-merge-order-shaped from birth. They are two different manifests with the same name, and nothing reconciles
them.

## What each does well

**Repo convention does better:**

- Models **cross-repo, cross-plane merge order**. Borg's plan is single-repo, single-checklist.
- Separates **merged** from **applied/deployed**. In this repo merge ≠ live on three of four planes; a borg checkbox
  cannot say "deployed, not merely merged."
- **Gates carry their settlement.** `blocked_by` + `resolved_by` + `kind` + `outcomes`, machine-validated. Borg's
  acceptance criteria have `Verify:` lines but no concept of a blocker, let alone one that names who unblocks it.
- **Publishes to where reviewers already are.** The table is stamped into all 8 PR bodies and the apex issue, so a
  reviewer landing cold on #425 sees the merge order without leaving GitHub. A `PROJECT_PLAN.md` is visible only to
  someone in that checkout.
- **Survives program churn.** A directive outlives the plan that spawned it — the ad-hoc-gate directive is parented to
  the DCM apex while a completely unrelated plan was active.
- **Has a real iteration log.** SKILL.md records ten format changes with the incident that caused each, including two
  data-loss bugs in the tool itself (`BLOCK_RE` unanchored, 2026-08-12; `apex.label` silently dropped, 2026-08-11).

**Borg does better:**

- **Discoverability from a cold start.** `.borg/checkpoints/` + `PROJECT_PLAN.md` at a fixed path is something a fresh
  session finds without being told. The repo convention is discoverable only if you already know to look, since CLAUDE.md
  never mentions it.
- **Lifecycle closure.** `/borg-assimilate` actually retires a plan. The repo's equivalent (`assimilated/`) has 4 files
  and 2 commits against 24 live directives, and needed a one-off 6-auditor audit to establish which were still true.
- **A single source of truth per project.** One `PROJECT_PLAN.md`, root-level, locked criteria. The apex convention has
  the body in three places (issue, branch file, untracked working copy) with no reconciler.
- **Cross-project view.** `borg link` / `borg next` answer "what needs attention" across all repos. The apex convention
  has no view above one program.
- **Explicit slug lineage with a stated failure mode.** borg-plan already learned "never compute the slug" the hard way
  (nine invisible directives). The repo convention's `*Parent plan:*` lines are hand-written with nothing checking them.

**Breakages:**

## 1. This worktree cannot see or re-stamp the program it is working on

`docs/plans/directives/olf-ingestion-apex.md` and `olf-ingestion-stack.json` do not exist here, on `main`, or in any
other worktree that is not `snowflake-permissions-wt-olf`.

**Manifests:** `git ls-tree origin/main docs/plans/directives/` returns 19 files, none of which is an apex or an
`olf-*` file. The apex exists on exactly one ref: `origin/feat/olf-ingestion-trd` (PR #420, **still OPEN**).

**How it manifests:** any session in this worktree that is asked to update program state after a merge cannot run
`stamp_stack.py` — there is no manifest to pass it — and cannot read the gates before merging a row. It also cannot see
gate 6 (the #424→#426 freeze window), which is the one that reproduces the #272 incident shape.

## 2. Three copies of the manifest exist and all three disagree with reality

| Copy | `next` | G1 #423 | B1 #424 | O1 #425 | Extra rows |
|---|---|---|---|---|---|
| `origin/feat/olf-ingestion-trd` | B1 | merged | stacked | stacked | — |
| `snowflake-permissions-wt-olf` working tree (mtime **Sep 18**) | C1 | stacked | stacked | stacked | C2 #428 |
| Reality (`gh pr list`, 2026-09-25) | G2 #426 | **merged 18:39Z** | **merged 20:52Z** | **merged 22:20Z** | #428 **CLOSED** |

`git diff --stat origin/feat/olf-ingestion-trd -- docs/plans/directives/` in `snowflake-permissions-wt-olf`: 9 files,
209 lines changed in the apex, 95 in the manifest, 3 PDFs deleted. The local working copy is **older** than what is
pushed, and still lists `C2 #428` — a PR that was closed and folded into #422 on 2026-09-23.

**How it manifests:** apex issue #427's rendered table now says B1/O1/G2 are `stacked` when B1 and O1 merged hours ago.
Anyone reading the apex today is told #424 is next; it merged at 20:52Z. Three PRs landed today and no copy of the
manifest was updated.

## 3. The stale copy hardcodes an absolute path to a different checkout

`snowflake-permissions-wt-olf/docs/plans/directives/olf-ingestion-stack.json`:

```json
"bodyFile": "/Users/noahgoodrich/dev/snowflake-permissions/docs/plans/directives/olf-ingestion-apex.md"
```

That file is **untracked** in the target checkout (`??` in its `git status`). The pushed version on
`origin/feat/olf-ingestion-trd` was fixed to the relative `docs/plans/directives/olf-ingestion-apex.md`, but
`stamp_stack.py:222` passes it straight to `gh --body-file`, so it resolves against **cwd** — correct only when run from
that one worktree's root.

**How it manifests:** run `stamp_stack.py` from the wrong directory and you either get a file-not-found, or — with the
stale absolute-path copy — you publish the *main checkout's* untracked apex body to issue #427 regardless of which
worktree you are in, silently overwriting whatever the branch says. The machine-specific path also means the manifest is
unusable by any teammate, which defeats SKILL.md:146's stated purpose ("so anyone can re-stamp after merges").

## 4. CLAUDE.md does not route an agent to the convention

`grep -n -i "borg\|PROJECT_PLAN\|docs/plans\|directive" CLAUDE.md` → zero hits, across 216 lines that otherwise go into
great detail on ad-hoc script idempotency, the four DCM planes, and the #272 incident.

**How it manifests:** exactly this session. A fresh agent in a fresh worktree reads CLAUDE.md, learns the permission
discipline cold, and has no idea that a 9-row cross-repo merge train with 8 human gates is mid-flight — nor that
`docs/plans/directives/` is where that is written down. It will not check gate 6 before the next permifrost apply.

## 5. `PROJECT_PLAN.md` is untracked and points at a program that finished weeks ago

The only `PROJECT_PLAN.md` is untracked in the main checkout, titled "SME PAT Documentation Consistency" (established
2026-09-01), with criterion 1 still unchecked. The repo shipped three OLF PRs today under a completely different program.

Its own header carries an unexecuted instruction: "Preserved verbatim at
`.borg/plans/2026-09-01-dcm-deploy-runway.md`; archive it to `docs/plans/assimilated/` once #392 merges" — #392 is still
open, so the archive never happened and `.borg/plans/` (gitignored) holds the only copy.

**How it manifests:** borg's "what am I working on" answer for this repo is wrong by two programs, and the previous
plan's archive is one `rm -rf .borg/` away from being lost.

## 6. Nine directives were already invisible to the gate meant to find them

borg-plan's SKILL.md:130-133 records the earlier instance of this same class: "A computed slug writes a `*Parent plan:*`
line no gate will ever match, which is exactly how nine directives came to be invisible to the check meant to find
them." The repo's `*Parent plan:*` lines are still hand-written and nothing validates that
`*Parent plan: dcm-implementation-apex*` resolves to a file that exists.

## 7. `.borg/` divergence across 30 worktrees

`.gitignore:135` ignores `.borg/`, and there are 30 worktrees. Checkpoint directories have already forked (main checkout
has `2026-09-23-1530.md`, this worktree has `2026-09-19-1420.md` / `2026-09-18-2215.md` / `2026-09-18-2200.md`, and the
two share only the newest two files). `.borg-project` also differs (`snowflake-permissions` vs
`snowflake-permissions-olf`), so borg registers them as separate projects with separate histories of the same repo.

**How it manifests:** "what changed since the last checkpoint" gives a different answer depending on which of 30
directories the session started in, and neither is complete.

---

## ANGLE: observed damage

## 0. The mechanism (this is the root cause, everything else follows)

- `/Users/noahgoodrich/dev/snowflake-permissions-olf/.gitignore:135` is `.borg/`. All borg state is
  **untracked**, so git — the one thing that actually links these directories — is explicitly told not to
  share it. `git ls-files .borg` → `0`.
- `PROJECT_PLAN.md` is **not tracked either**: `git ls-files --error-unmatch PROJECT_PLAN.md` → `error:
  pathspec ... did not match any file(s) known to git`. It was deleted from git in `76bfb54` (PR #291) and has
  been a local-only file since. `git cat-file -e <ref>:PROJECT_PLAN.md` is MISSING on `main`, on `olf`, and on
  `de-2107/owle-pgvector-postgres`.
- Identity is the directory: `.borg-project` contains `snowflake-permissions` in one and
  `snowflake-permissions-olf` in the other. Nothing else distinguishes them.

## 1. Checkpoint fragmentation — 68 vs 5, and they are different projects, not different views

Counts: main `68` files, olf `5`. Two more stores exist that the task did not name —
`snowflake-permissions-rbac/.borg/checkpoints` (2) and `snowflake-permissions-wt-smepat/.borg/checkpoints` (1,
written today 2026-09-25 10:33). **4 checkpoint stores, 76 files, one repo.**

**Three filename collisions, all with different md5s** (`comm -12` on the two listings):

| file | main md5 | olf md5 |
|---|---|---|
| `2026-09-18-2215.md` | `c7711695…` | `211d4c59…` |
| `2026-09-24-1000.md` | `0c8aa94f…` | `9cab73c0…` |
| `2026-09-25-1704.md` | `9f77d7d0…` | `e3ab4152…` |

`2026-09-25-1704.md`, both written at 17:05 the same minute:
- main: *"Branch hygiene session: pruned 238 dead remote branches and 49 local ones … removed 12 dead
  worktrees"*
- olf: *"Shipped five PRs of the OLF ingestion train end to end — roles, platform rename, databases, DCM
  landing objects and the DEV Snowpipe"*

`2026-09-24-1000.md`, same minute, same filename:
- main: *"Owle drone. Ontra-ai/snowflake-permissions#414 now carries the TRD and code that matches it"*
- olf: *"OLF ingestion train: Ontra-ai/snowflake-permissions#422 applied to DEV and PROD and merged"*

**Do they describe the same work?** No. Zero overlap. The last 3 main checkpoints mention "olf"
2 / 0 / 1 times and every hit is incidental (`~/dev/olf/13-ethan-replies-de-2107.md` is a path;
`feat/olf-role` is a branch name in the pruning log). The last 3 olf checkpoints mention "owle" 3 / 2 / **0**
and `#414` 2 / 2 / **0** — the reference decays to nothing as the two diverge.

**Does either reference the other?** Only by hand, twice, and only olf → main:
- `snowflake-permissions-olf/.borg/checkpoints/2026-09-18-2200.md:8` — *"The repo-level checkpoint
  `/Users/noahgoodrich/dev/snowflake-permissions/.borg/checkpoints/2026-09-18-1550.md` holds the full OLF
  record … Read it first; it mixed OLF and Owle, so take only the OLF items from it."* A human-authored
  seed telling the drone to go read the other project's store and filter it.
- `…/2026-09-24-1000.md:31` — *"committed in Noah's main checkout `~/dev/snowflake-permissions`, which was
  already on that branch"*. A cross-worktree write, recorded only in the worktree that did not receive it.

Zero references main → olf (`grep -rl 'snowflake-permissions-olf'` over 68 files → no match).

**Would a session resuming in one know what happened in the other?** No. The SessionStart hook reads
`<project>/.borg/checkpoints/` — a directory literal. A session in olf resuming on 2026-09-26 reads the OLF
checkpoint and learns nothing about 238 deleted branches or 12 removed worktrees; a session in main learns
nothing about `OLF_DEV`/`OLF_PROD` existing in Snowflake.

The cost is already recorded: olf's `2026-09-25-1704.md` §3 says the three uncommitted paths in the working
tree (`generate_spec_file.py`, `snowflake_permissions/integrations/`, `tests/test_generate_spec_integrations.py`)
are *"the first cut of the #423 integrations fix, written here before the work moved to the `feat/olf-role`
worktree. The shipped version is strictly better … Committing these would re-introduce the weaker version on a
second branch."* The same fix was written twice in two worktrees of one repo.

## 2. Plan mismatch — what criteria reconciliation would have done

`/Users/noahgoodrich/dev/snowflake-permissions/PROJECT_PLAN.md` line 1: `# Project Plan: SME PAT Documentation
Consistency`. 9 criteria, 7 `[x]`, **0 `Evidence:` annotations**, 9 `Verify:` lines.

Ran the engine read-only (`python3 -m borg_core.planstate.cli … --json`, writes nothing):

```
counts: {"total": 9, "checked": 7, "pass": 0, "fail": 0, "unknown": 9, "would_flip": 0}
flips: []
```

Every row: `"evidence": "no evidence annotation"`, `"verdict": "unknown"`, `"would_flip": false`.

So **concretely, nothing**. Per `borg_core/planstate/derive.py`, `flips` *"IS THE INTERSECTION OF TWO
CONDITIONS AND NOTHING ELSE: the criterion is currently `- [ ]`, and its verdict is `pass`"*, and
`docs/planstate.md`: *"An unannotated criterion is not an error. It resolves to `unknown` and is proposed,
never flipped."* `apply()` explicitly does **"NO WRITE AT ALL WHEN NOTHING WOULD MOVE."**

The olf session's own 2026-09-24 checkpoint already recorded this outcome in the *main* dir's copy: *"Criteria
engine: `PROJECT_PLAN.md` is the SME PAT docs plan, unrelated to this session; all 9 criteria `unknown` (no
`Evidence:` annotations), nothing flipped."*

**The damage is not corruption — it is that the gate is inert, and its inertness is hiding a real
divergence.** There are two SME PAT plan copies with different md5s:

| path | md5 | checked |
|---|---|---|
| `…/snowflake-permissions/PROJECT_PLAN.md` | `14e949f1…` | **7 of 9** |
| `…/snowflake-permissions-wt-smepat/PROJECT_PLAN.md` | `7339b923…` | **9 of 9** |

31 diff lines. The main copy has the newer Jira line (`DE-2128 — SME PAT Self-Service (own epic as of
2026-09-15)`) but stale criteria; the wt-smepat copy has the stale Jira line (`DE-1365 — PAT lane`) but
criteria 1 and 8 closed with evidence (*"**CLOSED 2026-09-24.** `ADD`/`ROTATE` ran verbatim against
`BOT_NGOODRICH` on RBAC_AUDIT"*). The plan's own header names
`/Users/noahgoodrich/dev/snowflake-permissions-wt-smepat` as its worktree — **and the registered project reads
the other copy.** Both are stale, in opposite directions.

Worse, the main copy's `**Directive:** docs/plans/directives/2026-09-01-sme-pat-docs-consistency.md` **does not
exist in the main checkout** (PRESENT only in wt-smepat, MISSING in main and olf). If the criteria had carried
`path:` annotations they would have resolved `fail` — `docs/planstate.md`: *"A `path:` annotation is the one
kind where absence is `fail` rather than `unknown`"* — purely because the worktree is on a different branch.

Two more copies exist: `snowflake-permissions-rbac/PROJECT_PLAN.md` and
`snowflake-permissions-wt-snowpipe/PROJECT_PLAN.md`, both `0f688845…`, both titled `# Project Plan: Drop
Snowball & Switch to Nexus-Hosted Permifrost` — a plan the main copy's own header says was superseded on
2026-09-01. **4 copies, 3 distinct contents, 2 of them a plan that was retired 24 days ago.**

## 3. State files — both true, and that is the problem

```
main:  {"status":"waiting","last_activity":"2026-09-25T23:06:54Z",
        "claude_session_id":"2d27ecfc-…","has_uncommitted_changes":true}
olf:   {"status":"idle",   "last_activity":"2026-09-26T03:26:58Z",
        "claude_session_id":"2b8bde71-…","has_uncommitted_changes":true}
```

Both are accurate about their own directory and both are unfalsifiable from the other. Two different live
`claude_session_id`s, 4h20m apart in `last_activity`, and `has_uncommitted_changes: true` in both — referring
to **different files** (main: `.gitignore`; olf: `generate_spec_file.py` + two untracked paths). Nothing reads
these two together, so "snowflake-permissions has uncommitted changes" is true twice and means two unrelated
things. The main dir also carries `.borg/briefings/` (3), `.borg/inbox/` (2) and `.borg/plans/` (1); olf
carries `.borg/drafts/` (25). **Neither directory has any of the other's subdirectories.**

## 4. Registry — 3 of 25 entries into one repo, and no field can express the relation

`~/.config/borg/registry.json`, 25 projects. Three point into the same git repo:

- `snowflake-permissions` → `/Users/noahgoodrich/dev/snowflake-permissions` (branch
  `de-2107/owle-pgvector-postgres`, `git rev-parse --git-common-dir` → `.git`)
- `snowflake-permissions-olf` → `…-olf` (branch `olf`, common-dir
  `/Users/noahgoodrich/dev/snowflake-permissions/.git`)
- `snowflake-permissions-wt-e2e` → `…-wt-e2e` (branch `keypair-e2e-runbook`, same common-dir)

**Is there a field that could express "this is a worktree of that"? No.** The union of keys across all 25
entries is exactly: `claude_session_id, has_uncommitted_changes, last_activity, notify_origin, path, source,
status, summary, tmux_session, tmux_window, waiting_reason`. `borg_core/registry/core.py:32` `build_add_entry`
emits six fields (`path, source, tmux_session, tmux_window, claude_session_id, last_activity, summary`) with
the comment *"six flat fields mirror cmd_add's `jq -n` object 1:1"*. There is no parent, no repo, no
`git_common_dir`, no kind.

borg **knows** the concept — it just keeps it out of the registry. `borg_core/manifest/shell.py:206`
`_manifest_identity` exists solely for this case: *"Two registry entries can point at two DIFFERENT
directories holding the SAME manifest — a git worktree is the live case … Their `_path` values differ, so no
path-level dedup can see it, and the grid would render every node, every gate and every declared ref twice
under one header."* It dedups by **hashing file bodies**, because the registry cannot tell it. Same file,
`:397`: *"A linked git worktree's `.git` is a file containing `gitdir: …` … the old `isdir` test made every
worktree select no manifests at all."* The relation is reconstructed by content hashing and `.git`-file
sniffing, entry by entry, instead of being stated once.

And the registry sees almost none of it: `git worktree list` → **31 worktrees**; **3** are registered borg
projects; **28** are invisible. 6 of the 31 carry borg state (`.borg/` or a `PROJECT_PLAN.md`) — so 3 stateful
worktrees are running borg artifacts with no registry entry at all.

## 5. Concurrent programs in this one repo

- **19 open PRs** (`gh pr list … --state open` → `length: 19`), oldest #294 from 2026-06-12, newest #434/#435
  from today. **13 PRs merged in the last 14 days.**
- **36 distinct directive files** across the three worktrees inspected — and the set is **branch-dependent**:
  main 35, olf 19, wt-smepat 22. 16 files exist in the main checkout and not in olf; **all 16 are UNTRACKED**
  (`git ls-files --error-unmatch` fails on every one), including all five apex/stack manifests.
- **5 apex programs**, each a multi-PR merge train with its own stack manifest:
  `olf-ingestion-stack.json` (apex issue **#427**, 11 rows), `dcm-implementation-stack.json`,
  `de1706-snowpipe-stack.json`, `de1896-stack.json`, `password-deprecation-stack.json`.
- Grouping the 19 open PRs by program: OLF ingestion (#426, #420) · Owle Postgres DE-2107 (#414, #416) · ARBAC
  / grant authority (#377, #396, #410, #419) · SME PAT docs (#395) · keypair migration (#412) · DCM routing
  and reference docs (#415, #403) · permifrost plan latency (#435) · Renovate deps (#360, #344) · one-off
  grants (#434, #324, #294) · RBAC audit rehearsal (#310). **≈10 live workstreams**, and the directive tree
  carries more that have no open PR right now (keypair phases 0-4, `two-phase-permifrost-flow`,
  `warehouse-strategy`, `streamlit-app-permissions`, `adhoc-sandbox-execution-gate`,
  `dcm-permifrost-lifecycle-parity`, `agent-aware-masking`, `bcr-2026-06-readiness`,
  `segment-schema-grant-lag`).

**That is the number a one-plan-per-project model has to carry: ~10 concurrent, 5 of them multi-PR trains, in
one git repo.** A single `PROJECT_PLAN.md` per directory can represent one of them. The other nine are
represented by untracked apex/stack JSON in whichever worktree happened to create them.

**Breakages:**

## B1. The OLF program's own manifest is not in the OLF project, and exists in 4 places with 3 contents

`find` for `olf-ingestion-stack.json` / `olf-ingestion-apex.md`:

| mtime | worktree | stack md5 | rows |
|---|---|---|---|
| 2026-09-18 08:20 | `dev/snowflake-permissions` (the registered project) | `36ab7a3d…` | 11 |
| 2026-09-18 08:20 | `dev/snowflake-permissions-wt-olf` | `36ab7a3d…` | 11 |
| 2026-09-22 10:39 | `.local/state/borg/worktrees/snowflake-permissions/olf-trd` | `384750e1…` | **12** |
| 2026-09-25 13:40 | `.local/state/borg/worktrees/snowflake-permissions/olf-trd-restructure` | `fb15eca5…` | 11 |

**Zero copies in `dev/snowflake-permissions-olf`** — the borg project actually running the OLF program. The
live copy (today 13:40) is in an unregistered `~/.local/state/borg/worktrees/…` path. The olf checkpoint from
17:04 today says *"#427's diagram now shows merged / next / waiting state and its table was regenerated from
the manifest"* — from a manifest the OLF project cannot see.

Manifests: `stamp` writes PR bodies and issue #427 from `rows`. One copy says 12 rows, two say 11.
**How it manifests:** a `/stacked-pr-program` stamp run from the wrong worktree publishes a merge-order table
that is a week stale or missing a row, to 11 PR bodies and the apex issue, idempotently and silently.

## B2. The stack manifest hard-codes an absolute path into one worktree

`dev/snowflake-permissions/docs/plans/directives/olf-ingestion-stack.json`:
`"bodyFile": "/Users/noahgoodrich/dev/snowflake-permissions/docs/plans/directives/olf-ingestion-apex.md"`.
The two `.local/state` copies use the relative `docs/plans/directives/olf-ingestion-apex.md`.

**How it manifests:** a stamp run from any other worktree using the absolute-path copy reads the *main
checkout's* apex body — Sep 18 content — and republishes it over today's. Silent cross-worktree read.

## B3. SME PAT is reported 7/9 when it is 9/9

The registered project `snowflake-permissions` reads `PROJECT_PLAN.md` = `14e949f1…` = 7 of 9 checked. The
worktree the plan's own header names reads `7339b923…` = 9 of 9, with criteria 1 and 8 closed and evidence
written. `planstate` cannot correct it: 0 annotations → 9 `unknown` → 0 flips.

**How it manifests:** `/borg-next`, `/borg-link` and any status roll-up show SME PAT as 78% done and blocking.
It is done. The 2026-08-20 audit failure that `planstate` was built to fix — *"36 were verifiably shipped with
unflipped checkboxes"* — is reproduced here by fragmentation rather than by forgetting.

## B4. Two retired plans are live in two worktrees

`snowflake-permissions-rbac/PROJECT_PLAN.md` and `snowflake-permissions-wt-snowpipe/PROJECT_PLAN.md`, both
`0f688845…`, both `# Project Plan: Drop Snowball & Switch to Nexus-Hosted Permifrost`. The main copy's header
says the current plan *"Supersedes the **DCM Deploy Runway** plan"* as of 2026-09-01 — and neither of these is
even that one; they are older still.

**How it manifests:** a session opening either directory gets a `SessionStart` plan restore for a program
retired weeks ago and starts work against it. `snowflake-permissions-rbac` also carries 2 checkpoints, so it
looks like a live project.

## B5. The directive the current plan points at does not exist where the plan lives

`**Directive:** docs/plans/directives/2026-09-01-sme-pat-docs-consistency.md` — MISSING in
`dev/snowflake-permissions`, MISSING in `dev/snowflake-permissions-olf`, PRESENT only in `wt-smepat`.

**How it manifests:** any `path:` evidence annotation added to that plan resolves `fail` (not `unknown`) from
the registered project, because `path:` absence is defined as `fail`. Adopting the very annotation feature
that is supposed to fix B3 would immediately produce false regressions.

## B6. Duplicate implementation of the same fix, caught only by a human

Working tree of `snowflake-permissions-olf` right now: `M snowflake_permissions/lib/generate_spec_file.py`,
`?? snowflake_permissions/integrations/`, `?? tests/test_generate_spec_integrations.py`. Per its own
checkpoint these are a weaker first cut of the #423 integrations fix; the version that shipped in `ef73190`
was written in the `feat/olf-role` worktree and *"has `category` and tests against permifrost's own
validators."*

**How it manifests:** two worktrees of one repo, no shared plan, produced the same fix twice; only a human
noticing stopped the inferior copy from being committed to a second branch.

## B7. Freeze-window / cross-plane risk is recorded in exactly one of four stores

olf `2026-09-25-1704.md` §4: *"**The #272-shaped freeze window is OPEN.** Since 20:52Z, `OLF_DEV` / `OLF_PROD`
and everything Ontra-ai/snowflake-permissions#425 created carry grants permifrost cannot see. **Any permifrost
apply by anyone, on any PR, walks into it.**"*

**How it manifests:** this is a repo-wide, account-wide hazard affecting every one of the ~10 workstreams, and
it is visible only to a session that opens `dev/snowflake-permissions-olf`. A session resuming in
`dev/snowflake-permissions` on #416 or #434 reads the branch-hygiene checkpoint, sees nothing, and runs
`permifrost apply` into the open window — the exact 2026-05-22 / #272 failure mode `CLAUDE.md` exists to
prevent.

## B8. Registry-invisible worktrees accumulate

31 worktrees, 3 registered, 28 invisible. `borg_core/proc.py:26` already records the shape: *"six orphans.
`borg reap-worktrees` does not know about them and nothing else reaps them."* Main's own checkpoint reports
going 42 → 30 worktrees by hand this week, and the cleanup itself nearly lost data — *"`keypair-329-e2e` is
held, not deleted. Its worktree `.wt-keypair-329` has an uncommitted 5-line change … That string appears in
**no committed ref in the repo** … The 'zero unique content' finding that justified deleting it measured
committed content only and was wrong."*

**How it manifests:** borg cannot enumerate its own working set, so pruning is manual, and manual pruning
measured committed content and missed uncommitted work in an unregistered worktree.

## B9. Checkpoint filenames collide by construction

`<timestamp>.md` is unique per directory, not per repo or per program. Three collisions today, all different
content, two written in the same minute. **How it manifests:** any future consolidation (a merge, a sync, a
shared store, a `git add .borg/`) is a silent overwrite, not a conflict — there is no content key.