# State audit — adversarial pass over every store borg touches

*2026-09-28. Prompted by "why three PRs, not one" plus "we've built a database out of JSON and the filesystem — does
this bring Postgres or Obsidian back into play?" Cairn was decommissioned 2026-08; this asks whether that ruling was
about the ENGINE or about something else.*

**tl;dr:** No to Postgres, no to Obsidian, and the question itself is the wrong first question. The binding constraint
is not storage, it is **reads per session** — and we already have an instrument that says so, currently reading FAIL.
But the audit also breaks my own recommendation on the way through, and indicts PR #233 (which I just shipped) as a
palliative. Both concessions are below.

## Part 0 — Why three PRs and not one

Honest answer, with the weak part first.

**#231 was not mine.** It was already open and published by the peer session before the handoff. Folding it into a code
PR would have rewritten someone else's published branch.

**#232 and #233 are genuinely independent** — disjoint files, disjoint tests, and either reverts cleanly without the
other. #232 touches `lib/reaper.sh`, `agents/borg-nanoprobe.md`, `tests/reap_worktrees.bats`; #233 touches
`borg_core/{registry,link}/`.

**The real argument for splitting #232 out is the blast radius**, not tidiness. It converts a LaunchAgent that has
removed nothing for 3.5 months into one that removes directories hourly. That deserves its own approve/revert boundary
and its own read-only blast-radius measurement, because "revert the reaper change" and "revert the registry change"
are questions someone will ask separately.

**Where the split is WRONG, and I caused it.** My own §5a says the reaper fix is a *prerequisite* to Option A. Three
PRs means merge order matters and **nothing enforces it** — GitHub will happily merge #233 first. A single PR, or a
`Depends on #232` marker plus a stacked base branch, would have encoded the dependency I asserted. This repo has a
whole skill for stacked-PR programs (`data-engineer:stacked-pr-program`) and I used none of it for a two-PR stack with
a stated order. That is the correct criticism of the split, and it is not the one the question anticipated.

## Part 1 — The census: what actually holds state

Counted by grep over `borg_core/ lib/ hooks/ bin/ *.zsh`, 2026-09-28.

### 1a. Per-project `.borg/` — sixteen names, six readers

| `.borg/<name>` | referenced by executable code | verdict |
|---|---|---|
| `checkpoints` | yes (5 files) | live |
| `programs` | yes (13 files) | live |
| `state` (`state.json`) | yes (5 files) | live |
| `skill-extensions` | yes (2) | live |
| `skills` | yes (2) | live |
| `agent-extensions` | yes (1) | live |
| `knowledge` | **ZERO** | write-only |
| `debriefs` | **ZERO** | write-only |
| `chains` | **ZERO** | docs-only (the `programs` rename, never landed) |
| `research` | **ZERO** | write-only |
| `decisions` | **ZERO** | write-only |
| `drafts` | **ZERO** | write-only (5 live dirs on disk) |
| `notes` | **ZERO** | write-only (2 live) |
| `inbox` / `recovered-inbox` | **ZERO** | write-only (2 live) |
| `plans` | **ZERO** | invented; the directive already flagged it |
| `briefings` | **ZERO** | write-only |

**Ten of sixteen have no code reader.** Several exist on disk right now. And CLAUDE.md's Architecture Rules
(`CLAUDE.md:485`) instruct every agent that "prior decisions live in `.borg/checkpoints/`, `.borg/knowledge/`, and
`docs/plans/assimilated/` — grep them before assuming something is undocumented." One of those three is read by
nothing. The instruction is the only reader.

**And `.borg/knowledge/` is cairn's corpse.** It holds 13 files across four directories
(borg-collective, its shim, its retro worktree, claude-plugins), and the dotfiles `.gitignore:17` says what it is in
so many words: *"knowledge/ is the cairn export and IS meant to sync across machines."* So the Architecture Rules of
the repo that decommissioned cairn still name cairn's export as a place to look for prior decisions, two months after
the teardown, with no code path reading it. This is the single sharpest finding in the audit: the decommission removed
the service and left both the data and the instruction to consult it.

### 1b. Machine-local — two roots, no principle

`~/.config/borg/` (20 entries) and `~/.local/state/borg/` (10). The split is not config-vs-state:

- `memory-gate-state.json` and `usage-guardian.json` live in **config**; `memory-gate.log` and
  `usage-samples.jsonl` live in **state**. Same subsystem, split across roots.
- `plan-promote-debug.log` is 33 KB of unrotated debug output.
- `data.json.bak.20260730153445` and `data.json.bak.20260925153431` — manual backups as a versioning strategy.
- **`cairn-hits.log` (44 KB), `cairn-inbox/`, `cairn-heartbeat-last` are still on disk.** Cairn was decommissioned
  two months ago. Nothing garbage-collects, so a decommission leaves litter that outlives the decision.

### 1c. Stores I nearly forgot, which are the interesting ones

State borg depends on but does not own, and mostly cannot reconcile:

| Store | Holds | Who owns it |
|---|---|---|
| **git refs** | the only thing connecting 31 worktrees | git |
| **GitHub PR bodies + apex issue** | merge order, stamped 3× by `stamp_stack.py` | GitHub |
| `<repo>/docs/plans/directives/<slug>-stack.json` | apex + merge-ordered stack, spans repos | the repo convention |
| `docs/plans/{PROJECT_PLAN.md,directives/,assimilated/}` | plan lifecycle | git, tracked |
| **tmux** | window ↔ project binding, live-ness | tmux server, dies on reboot |
| **launchd** | 6+ agents, labels resolved not spelled | `~/Library/LaunchAgents` |
| **devcontainers** | `~/.config/borg/devcontainer-hashes/`, container liveness | Docker |
| `~/.claude/projects/*/memory/*.md` + `MEMORY.md` | auto-memory, `[[wikilinks]]` | Claude Code |
| `~/.claude/projects/*/*.jsonl` | session transcripts — `borg scan`/`borg link` mine these | Claude Code |
| `~/.claude/token-spend.jsonl` | `borg spend` | token-cost plugin |
| `.claude/settings.local.json` | per-project permissions (`break-glass`) | Claude Code |
| `~/.local/state/borg/merge-tree/` | `data.json`, `annotations.local.json`, `story.json` | borg, separate CLI |
| recon since-marks / last-run marker | sweep watermark | borg |
| Jira / Notion / Slack adapters | employer layer, machine-injected | external |

**Fourteen-plus stores, at least six owned by something other than borg.** Any "unify the database" proposal has to
answer what it does about the six it cannot move — and the answer is always "read them through an adapter", which is
what `borg recon` already does. So unification was never available; the only question is how many stores borg *itself*
owns.

## Part 2 — The answer: engine is not the variable

### Postgres: no

Cairn was Postgres+pgvector and it died measuring **0.4% cross-project restatement**, indistinguishable from null.
CLAUDE.md records the transferable lesson, and it is not about Postgres: *build capture that derives from an artifact
the agent already produces; never build capture that asks the agent to volunteer.* Four shipped, tested, exposed
voluntary-write surfaces produced one real row in five months.

Two further objections specific to reintroducing a daemon:
1. **Hooks must fail open.** Every borg hook already does. A hook that cannot reach a daemon and therefore blocks a
   session start is a worse failure than any state problem it solves.
2. **A service is a maintenance obligation** for one user and ~25 projects. That is the cairn shape again.

### Obsidian: no, but its idea is already adopted

Obsidian is a GUI over markdown plus `[[wikilinks]]`. borg already has both — auto-memory literally uses `[[name]]`
and explicitly permits dangling links, resolved at read time. Adding Obsidian would add a **fourth home** competing
with git, `.borg/`, and the machine-local roots, plus a GUI against a CLI-first preference. The *pattern* worth
keeping — dangle-tolerant links, resolution at read, no schema migration to add a link — is already in place.

### What the measurement actually says

`hooks/borg-memory-read-log.sh` instruments every read of a Claude Code project-memory file, and
`bin/memory-hits-report` scores it against a **pre-registered** threshold of 0.2 reads/session. As of the
2026-09-24 check it reads **0.129 — FAIL**. The session-start hook prints this every session.

That is the whole finding. Auto-memory is markdown on a filesystem; cairn was Postgres with embeddings. **They are
failing the same way at the same measurement**, which is direct evidence that the engine is not the variable. Ten
unread `.borg/` directories depend on precisely the mechanism that instrument is failing: an agent told to go look.

**So the rule to adopt is a gate, not a database:** no new store ships without a *mandatory code-path reader* and a
retention policy. A store whose only reader is an instruction in CLAUDE.md is a write-only store with extra steps,
and we now have two independent measurements of what that is worth.

**And the rule ships WITH its enforcement test or it does not ship.** This is not a follow-up item — it is a hard
dependency, and the blind review was right to make it one. A rule of this shape, written as prose into CLAUDE.md, is
indistinguishable from the ten instructions that already failed: `.borg/knowledge/` is cited in the Architecture Rules
and read by nothing, `borg recon` shipped non-functional behind a documented contract, and the memory gate was
wallpapered once already (see the `2026-08-31-auto-memory-gate-measures-the-wrong-thing` directive). A prose gate
against prose gates is the one form this rule cannot take. The enforcement is a contract test in the shape of
`tests/prose_contracts.bats`: fail when a `.borg/<name>` is written by any code path, or named in CLAUDE.md, and read
by none.

## Part 3 — Where this audit breaks my own recommendation

### Concession 1: "state must travel with the branch" is true in exactly one repo

I was going to argue that durable artifacts belong in git because worktrees share refs. Measured:

| repo | `.borg/` | tracked files under `.borg/` |
|---|---|---|
| borg-collective | not ignored | **1220** |
| dotfiles | not ignored | 3 |
| snowflake-permissions | **IGNORED** | 0 |
| dbt | **IGNORED** | 0 |
| mswi | **IGNORED** | 0 |
| infrastructure | ignores only `state.json` | **0** |
| ai-data-engineer | ignores only `state.json` | **0** |
| claude-marche | ignores only `state.json` | **0** |

Three repos could have tracked `.borg/` and committed **nothing**. So `.borg/` is *de facto machine-local everywhere
except the repo that builds borg*. My git argument generalized borg-collective's self-hosting without warrant.
borg-collective tracks its checkpoints because there they are product documentation — that is a special case, not the
latent design.

### Concession 2: the per-project location is the actual error, and PR #233 is a palliative

If `.borg/` is machine-local in 7 of 8 repos, then storing it *inside each working directory* is the bug. One clone
with 31 worktrees gets up to 31 stores of state that was never meant to be per-directory. My #233 reads all of them
and reconciles by content hash — but **if that state had one home keyed by repo, there would be no stores to union
and no collisions to dedupe.** I made the reader tolerant instead of putting the data in the right place. That is the
"weaken the validator" antipattern CLAUDE.md warns about, in reader form.

Worse: the same-minute filename collision is a **missing unique key**, and content-hash dedupe is a workaround for it.

And there is a sharper version of this, found on re-reading the writer. `skills/borg-link-up/SKILL.md:281-284`
**already carries a collision guard**: before writing, check whether `<project-root>/.borg/checkpoints/<timestamp>.md`
exists and if so append `-2`, then `-3`, until the name is free. So the collision did not happen for want of a guard.
It happened because **the guard is scoped to the directory** — two sessions in two worktrees of one clone each check
their own store, each find the name free, and both write it. The same unit error as the registry PK, the plan slot and
the checkpoint read, one level further down: the guard asks "is this name taken *here*" when the question is "is this
name taken *for this repo*."

Two consequences. (1) Fixing the key at the writer means second-resolution plus a short session-id suffix — collisions
become unrepresentable rather than detected, which also retires a scan-then-write race that is non-atomic even within
one directory. (2) Any guard that keeps scanning a directory will keep being wrong for as long as state is stored
per-directory, so this cannot be fixed without Concession 2.

### Concession 3: I added a fourth identity without retiring any

borg now keys by **directory basename** (still the registry PK), **common dir** (`repo`, mine), **`owner/repo` slug**
(manifests), and **apex issue** (stacks). #233 added one and retired nothing. The registry's primary key is still the
basename, so `snowflake-permissions` and `-olf` remain two entries with two `state.json`s and two tmux windows. I
fixed the *read* of one field and left the identity untouched. That is Option A as specified — but the directive
should say plainly that its core diagnosis is only half-addressed.

## Part 4 — What I would actually do, in order

Smallest-first, each independently revertible, none requiring a new engine.

1. **Fix the checkpoint key at the writer.** Second-resolution timestamp + short session-id suffix. One line, kills
   the collision class permanently, and makes #233's dedupe defensive rather than load-bearing.
2. **Run a reader census as a test.** A contract test that fails when a `.borg/<name>` is written by any code path or
   documented in CLAUDE.md but read by none. Mechanically the same shape as `tests/prose_contracts.bats`.
3. **Delete or adopt the ten write-only directories.** Each gets a mandatory reader or gets removed, including from
   CLAUDE.md's "grep them" instruction. Start by deleting cairn's three leftovers.
4. **One machine-local root, with a retention policy.** Collapse `~/.config/borg/` operational files into
   `~/.local/state/borg/`; config keeps only what a human edits. Rotate the logs.
5. **Then, and only then, consider SQLite for the operational half** — registry, session status, usage samples,
   nanoprobe log, hit logs. The case is not "we need a database"; it is two specific properties: a `UNIQUE`
   constraint would have made the basename key *unrepresentable*, and a transaction would have fixed the writer split
   (`state.json` to the resolved dir, checkpoints to CWD — two writes, no atomicity). Stdlib `sqlite3`, no daemon, one
   file, still `rm`-able, still readable from the CLI. Checkpoints and plans stay as files: they are human-authored
   prose and a blob in a table is worse to edit and worse to grep.
6. **Never** a daemon, and never a second markdown vault.

Note what steps 1–4 have in common: they are all retention, identity and census work, and **none of them is a
storage-engine decision.** If steps 1–4 land and the pain is gone, step 5 was never needed — which is itself the
answer to the original question.


## Part 5 — Blind adversarial review, and where it corrected me

A reviewer was given Part 2's recommendation COLD — as a compressed A-D proposal, with Part 3's concessions and Part
4's ordering **deliberately withheld**, so it would attack the strongest form of the argument rather than a
pre-hedged one. Verdict: **adopt-with-changes** — accept "no Postgres", accept "no Obsidian", accept the
reads-per-session rule *only when paired with its enforcement test*, and **reject the SQLite split as framed**.

**It reached Part 3's concessions on its own, without seeing them.** Independently: that "state must travel with the
branch" is refuted by the tracked-file counts; that SQLite fixes *neither* real bug (the collision is a writer-key
defect, the PK bug is an identity decision, and a correctly-keyed JSON file solves the latter as well as a table
would); and that presenting SQLite as the plan rather than as step 5 of 6 is "the build-infrastructure-before-proving-
it's-needed pattern cairn is the cautionary tale for." Two analyses reaching the same three concessions from opposite
directions is the strongest evidence in this document, and it is evidence against the engine change.

**Two corrections adopted:**
1. **The reader count was wrong** — this document's own header said "seven readers" while its table listed six. Fixed
   above. An audit of rigor should not miscount.
2. **The census test is a hard dependency of the rule**, not step 2 of a list. Folded into Part 2.

**One refutation that is itself wrong, and worth recording because of HOW it is wrong.** The review reported that the
`repo` field is not a registry field at all but "a checkpoint-identity/common-dir concept — a different data structure
entirely", and that "nothing in the registry changed." It read the default worktree, which sits on
`feat/short-window-names`; PR #233 is unmerged, so `borg_core/registry/core.py` there has no `repo` and the live
`registry.json` has not been backfilled. On `feat/registry-repo-key` it is a `build_add_entry` parameter emitting a
`"repo"` key into the registry entry. The reviewer's *conclusion* nonetheless stands and matches Concession 3
verbatim: basename remains the sole registry primary key, and #233 does nothing about the registry duplication ---
`snowflake-permissions` and `-olf` are still two entries with two `state.json`s and two tmux windows.

The lesson is about the method, not the reviewer: a blind review of an UNMERGED change reads whatever branch the
default worktree happens to be parked on. That is the same class of error as everything else in this retro --- a
directory standing in for an identity --- and it argues that a review prompt for unmerged work must name the branch
or the PR, not the repository.

## Part 6 — The standing recommendation

Unchanged in substance by the review, reordered by it. Do these four, in order, none of which is a storage-engine
decision:

1. Fix the checkpoint key at the **writer** — second-resolution timestamp plus a short session-id suffix.
2. Ship the **reader-census contract test**.
3. **Delete or adopt** the ten write-only directories, starting with cairn's corpse in `.borg/knowledge/` and the
   three cairn files still in the machine-local roots --- and remove `.borg/knowledge/` from `CLAUDE.md:485`.
4. **One machine-local root** with a retention policy; rotate `plan-promote-debug.log`.

Then re-measure. SQLite is deferred until those four are shown insufficient, which both analyses independently expect
they will not be. Postgres and a second markdown vault are refused outright.

## Part 7 — The TUI/board design exists, is unbuilt, and is the missing consumer

You remembered correctly. It is three directives filed **2026-08-11**, all still in
`docs/plans/directives/` and none assimilated — seven weeks pending:

**`2026-08-11-viz-1-awaiting-you-tier.md`** — **AWAITING YOU** as its own labeled tier, *ahead of all ranking*, in
both the live renderer and `borg link`. Separates blocked-on-you from blocked-on-others in the data model, because
collapsing them is what hid the most actionable work.

**`2026-08-11-viz-2-spine-generator.md`** — make `story.json`, the cross-repo spine, **derivable** instead of
hand-authored: a machine-derived skeleton regenerated from every recon gather, plus a small persisted judgment
overlay that survives regeneration.

**`2026-08-11-viz-3-cross-repo-chains.md`** — cross-repo dependency chains plus **three-tier ranking instead of one
score**, because a single score is what buried the right answer.

Two surfaces, not one: the browser app at `merge-tree/app/` (`serve.sh`, `graph.py`, rendered to
`graph.html`) and the terminal page `borg link` already prints. Viz 1 says the tier belongs in **both**.

### The failure it was designed to fix, and why it matters here

From viz-1's own write-up: Noah returned from a week away and spent most of a day rebuilding context.
`sme-self-service-pat` was never surfaced, even though the spine described it in prose as approved and sitting
behind one manual merge gate, and recorded it as:

```json
"state": "ready-to-start",
"blocked_by": ["manual review-first PR merge/approval gate (human decision, not a technical/code blocker)"]
```

The author annotated the blocker as non-technical **and the ranking suppressed it anyway**, because any model that
treats a non-empty `blocked_by` as a demotion inverts the signal exactly when the blocker *is the person being
briefed*. `#340` and `#341` sat OPEN, APPROVED and MERGEABLE — minutes of work, zero risk.

### The connection to this audit: it is the same defect, mirrored

`story.json` on this machine was last written **2026-07-28** — two months stale. Viz 2's diagnosis is that it
**has no generator**: `render_graph.py` and `spine.py` only read it, nothing writes it.

So put the two halves of the census together:

- Part 1 found **ten stores nothing reads** (`.borg/knowledge/`, `debriefs/`, `decisions/`, …).
- Part 7 finds **one store nothing writes** (`story.json`), feeding the only view that would answer "what is blocked
  on me."

**Both are the same defect: a store missing a mandatory code path on one side.** And they compound. The board is the
consumer that would have made the checkpoint and manifest stores load-bearing — i.e. the mandatory reader the
census test is going to demand. Its absence is *why* those ten directories could rot unnoticed: nothing downstream
ever needed them to be right. Meanwhile the board itself cannot be trusted because its own input is hand-authored and
two months cold, so nobody consults it, so context gets rebuilt by hand — which is the 2026-08-10 failure repeating.

### Sequencing consequence

This reorders nothing but it explains the priority. The four steps in Part 6 are not a detour from the board — they
are its precondition, and the board is the payoff that makes them worth doing rather than mere hygiene:

1. Writer key → checkpoints stop being ambiguous, so a tier can cite one.
2. Census test → the board's reads become the thing that keeps stores honest.
3. Delete the dead ten → the board is not built over rot.
4. One machine-local root → `story.json` has an unambiguous home to be generated into.

Then **viz 2 before viz 1**, which is viz-2's own ruling and the opposite of the cheapest-first instinct: viz 1 is a
tier over a stale spine, and a correct tier computed from two-month-old data is still wrong. Viz 3 last.

**The `repo` identity from PR #233 is what makes viz 3 expressible at all.** Cross-repo chains need a stable answer
to "which repo is this row in", and the audit's Concession 3 stands: basename is still the registry PK, so that
answer is still only half-available.

## Part 8 — "Does everything move to one machine-level folder?" No. Five categories, four answers.

*Asked directly, and the question exposes a real inconsistency between this document's own Part 4 step 4 and its
Concession 2. Step 4 proposed consolidating the two MACHINE-LOCAL roots (`~/.config/borg/` and
`~/.local/state/borg/`) — it said nothing about `.borg/` inside repos. Concession 2 then said "the per-project
location is the actual error," which reads as a much larger proposal. **Concession 2 overreached and is corrected
here.** It is the error for exactly one artifact, defensible-but-not-worth-paying-for on a second, and flatly wrong
on a third.*

### 1. Already in git, correctly placed — NO CHANGE

`docs/plans/PROJECT_PLAN.md`, `docs/plans/directives/`, `docs/plans/assimilated/`.

These are not in `.borg/` and never were. They are tracked, reviewed, diffed and travel with branches, which is
exactly right for human-authored decisions about a repo. Nothing in this audit touches them. Note that this is
already the counter-example to any "borg state is scattered" framing: borg's most important artifacts are in git, in
the repo, versioned — and they work.

### 2. MUST stay per-project — moving them destroys the mechanism

`.borg/skill-extensions/`, `.borg/agent-extensions/`, and `.borg/programs/`.

`docs/extensions.md:11-16` defines **two layers, in order**: (1)
`~/.config/borg/extensions/<kind>/<subject>/<hook>.md` per machine, (2)
`<project root>/.borg/<kind>/<subject>/<hook>.md` per project — with the precedence rule at `:79`, "the layer that
owns the fact wins." A per-project layer that does not live in the project is not a layer. Consolidating these would
delete the entire mechanism, including the reason it exists: this repo is public and was history-scrubbed once for
employer references, so a machine layer must be able to hold what a checked-in file must not.

Honest caveat: **the project extension layer is currently unexercised.** A sweep of every live `.borg/` found zero
`skill-extensions/` or `agent-extensions/` directories, and `.borg/programs/` in two repos with one file each. So
there is no migration cost in either direction — the argument rests on design intent, not on installed base. That is
still sufficient: an escape hatch being unused is the normal state of an escape hatch, unlike the ten stores in Part
1, which are written to and never read.

### 3. Genuinely misplaced — SHOULD move

`<project>/.borg/state.json`.

This is machine-derived session state: `status`, `last_activity`, `waiting_reason`, uncommitted-change tracking.
Keying it to a *directory* is meaningless — 27 copies exist on disk, one per directory that ever hosted a session,
and `hooks/borg-link-down.sh:110-112` reads it back by path. It is about (this machine, this repo, this session) and
belongs machine-local, keyed by repo. Six of the eight sampled repos already gitignore it *specifically* and by name
(`.gitignore` lines naming `.borg/state.json` alone), which is the repos telling us, in their own configuration, that
it is not a repo artifact.

### 4. Already machine-local, merely split across two roots — THIS is what step 4 meant

`registry.json`, `usage-samples.jsonl`, `usage-watch.log`, `agents.jsonl`, `memory-hits.log`,
`prefer-tool.jsonl`, `devcontainer-hashes/`, `merge-tree/`, `worktrees/`, recon marks, the memory-gate and
usage-guardian files.

Nothing moves out of a repo here. It is one uncontroversial hygiene change: pick one root, put operational state in
it, leave in `~/.config/borg/` only what a human edits, and rotate the logs (`plan-promote-debug.log` is 33 KB
unrotated; `data.json.bak.<timestamp>` files are manual versioning).

### 5. Contested, and the answer is still DON'T MOVE — `.borg/checkpoints/`

The tempting move, and I am arguing against it having initially implied it.

**For moving:** untracked in 7 of 8 repos, so machine-local in practice; one clone with 31 worktrees can accumulate
31 stores; and one home keyed by repo would make Part 4 step 1 and PR #233 both unnecessary.

**Against, and this wins:**
- **The collision — the only measured harm — is a WRITER KEY defect, not a location defect.** Second-resolution plus
  a session-id suffix makes it unrepresentable, wherever the file lives. Location is not load-bearing for the bug.
- **The read side is already neutralized.** PR #233's union read makes 4 stores answer as one, verified: after
  backfill, `borg link snowflake-permissions` and `borg link snowflake-permissions-olf` return an identical list and
  an identical head. The scatter is no longer visible to a reader.
- **borg-collective and dotfiles genuinely track theirs** (1220 files and 3). There the checkpoints *are* product
  documentation and must stay in git. So any move needs a per-repo exception, and a conditional location is worse
  complexity than the scatter it removes.
- **Cost is a data migration across 8+ repos with a tracked exception**, for the remaining ~5% of benefit after the
  writer-key fix. Wrong trade.
- **Locality has real value**: `grep -r` from the project you are standing in finds them, and deleting a repo takes
  its own notes with it.

So: **fix the key, keep the location.** If the location should change later it deserves its own directive with its
own migration plan, not a clause smuggled into a hygiene step.

### Summary

| Artifact | Lives where today | Proposal |
|---|---|---|
| `docs/plans/**` | git, tracked | unchanged |
| `.borg/{skill,agent}-extensions/`, `.borg/programs/` | per project | unchanged, by design |
| `.borg/state.json` | per directory | → machine-local, keyed by repo |
| `~/.config/borg/*` + `~/.local/state/borg/*` | two roots | → one root, with retention |
| `.borg/checkpoints/` | per directory | stay; fix the writer key instead |

One artifact moves out of repos. One pair of machine-local roots merges. Nothing else changes location.
