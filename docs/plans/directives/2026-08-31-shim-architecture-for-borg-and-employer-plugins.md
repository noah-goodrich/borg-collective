# Directive: One shim architecture for borg and the employer plugin layer
*Filed: 2026-08-31*

## Why

Three audiences, one machine each, and no contract between them.

- **Personal machine.** PR stacking and the whole borg workflow must work with zero employer plugins installed.
  Today they cannot: `stacked-pr-program` and `stamp_stack.py` live only in `ai-data-engineer`, so a personal repo
  has no stacking at all.
- **Teammates.** `ai-data-engineer` must work with zero borg. Currently violated —
  `plugins/data-engineer/commands/strike.md:303` tells the reader to run `/borg-plan` and `/borg-collective-review`.
  It is the only `borg` string under `plugins/`, and the portability grep at `tests/run-tests.sh:213` covers
  `skills/stacked-pr-program` and `hooks` only, so it misses `commands/` **and** `skills/deploy-to-airflow-dev/`.
  The suite prints `ok zero borg coupling` while the leak ships green.
- **Work machine.** Both installed, composing, with the boundary visible rather than negotiated per session.

**The mechanism for this already exists in borg, twice, and both sockets are empty.**

1. **Recon adapters.** `borg_core/recon/shell.py` globs `recon-adapter-*` on `BORG_RECON_ADAPTER_PATH`, config dir
   shadowing repo dir. Any executable named `recon-adapter-<source>` registers a source with no code change. The
   repo ships one, `recon-adapter-github`. Employer adapters are already designed as a machine-injected layer.
2. **Skill extensions.** `borg-plan` and `borg-assimilate` each read `01-context`, `02-output` and `03-followup`
   from `~/.config/borg/extensions/skill-extensions/<skill>/`, then `<project>/.borg/skill-extensions/<skill>/`.
   Missing files are skipped silently. CLAUDE.md's own worked example is the work-machine JIRA case.

Verified 2026-08-31: `find ~/.config/borg/extensions` and the per-project equivalent return **nothing**. The
architecture is built and has never been exercised.

The direction is already correct and is the whole answer to the hard constraint: **borg reaches down for employer
shims; the employer plugin never reaches up for borg.** Nothing needs inventing at the seam. What is missing is
coverage, a determinism tier, and one ownership rule.

## The change

**Name the pattern once, extend it to the surfaces that need it, and give the shim layer two tiers.**

### 1. Two tiers, stated explicitly

Skill extensions are markdown — they inject instructions, which puts them back in the ~70-90% model-discretionary
band. Recon adapters are executables and fire by construction. Anything that MUST happen ships as an executable
adapter; anything that shapes judgment ships as a prose extension. This distinction is currently implicit and is the
reason a shim can silently be the wrong kind.

### 2. A third socket: the chain/PR layer

Skill extensions cover two skills. PR stacking, PR-description updating and manifest updating have no load point.
Add the same three-point convention to whichever surfaces own those, following the existing naming exactly rather
than inventing a second shape.

### 3. `borg reconcile`, adapter-driven

A new verb. One idempotent function of (live state for declared refs, local declared overlay), writing
`<repo>/.borg/programs/*.json` atomically.

| Field class | Fields | Treatment |
| --- | --- | --- |
| Derived | `state`, merged-ness, same-repo `order` | Overwritten every run |
| Declared | `lane`, `why`, `after`, `apex`, cross-repo `order` | Never touched, never deleted |
| Declared-but-checked | `gate.kind`, `blocked_by`, `resolved_by` | Reported when they contradict derived state |

Cross-repo `order` is in the declared column because `merge-tree/programs.py` says so in its own docstring, three
times: "a base branch is a repo-local name... nothing in git or the GitHub API says platform#834 must merge before
warehouse#302... So it has to be *declared*."

Live state comes from **adapters, not a hardcoded GitHub call**. Personal machine: only `recon-adapter-github`
exists, GitHub chains work. Work machine: employer adapters present, a row can name a Jira key and resolve. The
three-machine requirement then falls out of which files are on disk instead of being designed for.

Idempotent, so no trigger has to be reliable. Never deletes what it cannot re-derive. Inherits `shell.py`'s
degrade-never-fatal policy: offline, missing `gh`, or rate-limited means it writes nothing and says so.

Primary trigger is a launchd timer, following `com.stillpoint-labs.borg.reap.plist`. A session-boundary trigger
cannot catch a merge in repo B while the session is in repo A, or while the laptop is closed, or when someone else
merges. If Stop is also wired, gate it on staleness — borg's Stop matcher is `*` and fires after every assistant
turn, not once per session.

### 4. borg owns personal stacking; the employer plugin keeps its own

borg grows a stamper for personal repos. `stamp_stack.py` is untouched and remains the only thing that writes a PR
body in employer repos. On the work machine an extension file declares which implementation owns a given repo, so
**two implementations exist and never two writers on one artifact** — the constraint no surveyed tool has ever
solved, avoided rather than attempted.

### 5. Close the leak as an extension, not a deletion

`strike.md:303` should be neither deleted nor guarded by a `command -v borg` probe. It should be an extension file
that exists only on the work machine. A probe hands teammates a dead code path they will eventually delete; an
absent file is invisible. Then widen the portability grep to the whole `plugins/` tree.

### 6. Harden the two existing gates

Zero of 16 borg skills carry an `allowed-tools` key. All six employer commands do. borg has no `commands/` directory
at all. `borg-assimilate` can reach `gh pr merge` today with nothing structurally stopping it, while
`permifrost-ship.md` cannot reach `gh pr review --approve` and carries an inline comment saying why the tool is
deliberately absent. Copy that shape, comment included, and confirm the replacement ship path in the same session.

## Acceptance criteria

- [ ] **The pattern is documented once, in CLAUDE.md, as one named mechanism** with its two tiers (executable
      adapter vs. prose extension) and the one-directional rule stated.
  - Verify: a reader can name which tier a new shim belongs in without reading source.
- [ ] **`ai-data-engineer` has zero borg references and the test proves it.** The portability grep covers the whole
      `plugins/` tree; `strike.md:303` is gone from the repo and lives as a work-machine extension.
  - Verify: `bash tests/run-tests.sh` green with the widened path; the grep fails if a reference is reintroduced
    anywhere under `plugins/`, confirmed by mutation.
- [ ] **`allowed-tools` on `borg-plan` and `borg-assimilate`, omitting the dangerous verb**, with the replacement
      ship path confirmed working.
  - Verify: `gh pr merge` is unreachable from `borg-assimilate`; a named user-typed path merges instead.
- [ ] **The two manifest validators are one.** `borg_core/manifest/core.py` and `merge-tree/programs.py` no longer
      disagree; a round-trip test asserts what the writer emits, the reader accepts.
  - Verify: pytest round-trip case, red before the fix.
- [ ] **`borg reconcile` ships, adapter-driven and idempotent.** Running it twice produces a byte-identical file.
      It never deletes an unresolvable edge. In degraded mode it writes nothing.
  - Verify: pytest for idempotence, edge preservation, and the degraded no-write path; one launchd plist installed.
- [ ] **The #158 class is reported, not guessed.** A `decision` gate on a merged PR is named in reconcile's output.
  - Verify: fixture manifest with a merged-PR decision gate; assert the report names it and the file is unchanged.
- [ ] **Personal-machine stacking works with zero employer plugins**, and the work machine has exactly one writer
      per repo.
  - Verify: stacking exercised in a personal repo with the employer marketplace disabled; an extension declares
    ownership on the work machine and a test asserts the non-owner does not write.

## Notes

- Full reasoning, the six-option ballot, the council dissent and three blind reviews:
  `docs/research/2026-08-31-plugin-coexistence/recommendation.md`.
- **Not a child of the One Front Door plan.** Deliberately carries no `*Parent plan:*` line — adding one would make
  it a sixth `borg-assimilate` Step 0.75 blocker on a plan already blocked by five.
- **Sequencing.** The leak fix and `allowed-tools` are each under a session and independent of everything else.
  The validator merge is AC7's work under the One Front Door plan; do it there, not twice.
- **Explicitly out of scope.** Making `ai-data-engineer` aware of borg in any way. Growing deploy/maintain/monitor
  vocabulary in borg — that duplicates externally-verified domain logic for no gain. A shared third package: the
  stamper is employer work product derived from a colleague's format, and a personal harness should not assert
  co-authority over it.
- **Known blind spot.** Nothing here is testable by the first-party skill-firing harness — `claude plugin eval` is
  gated behind early access, `--bare` does not disable skills, and the fleet has zero skill-firing tests against 85
  hook test cases. The effect of the `allowed-tools` change is asserted, not measured.
- **Does not address the clickable-links class.** Assistant prose streams and is not a tool call, so no hook can
  reach it. The tractable half — prose written *into* a tool call — is a separate, smaller piece of work: the regex
  already exists at `ai-data-engineer/tests/run-tests.sh:205-208` and moving it into a PreToolUse deny on
  `gh pr create` / `gh pr edit` / `gh issue comment` / `Write` makes that half structurally unbreakable.
