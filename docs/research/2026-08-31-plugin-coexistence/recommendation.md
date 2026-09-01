Generated: 2026-08-31
AI-scoring: 100/100 (scanning mode: categories 3, 4, 6, 8-words)

# Making borg and ai-data-engineer coexist without either one losing

**Verdict: revise ×3, amendments applied.** Three blind reviewers each returned `revise`; none overturned. Their
three corrections are folded into the recommendation below and are marked where they land. The amended version was
not itself re-reviewed — treat the three amendments as the least-tested part of this document.

## Glossary

| Term | Meaning |
| --- | --- |
| **hook** | A script Claude Code runs at a fixed moment: session start, before a tool, after a tool. Fires whether or not the model wants it to. |
| **skill** | A markdown instruction file the model chooses to load based on its description. Fires roughly 70–90% of the time. |
| **PreToolUse / PostToolUse** | Hook events. PreToolUse runs before a tool and can refuse it. PostToolUse runs after, cannot refuse, but can still act. |
| **manifest** | borg's `<repo>/.borg/programs/*.json` — a file describing a chain of related PRs. |
| **master table** | The ai-data-engineer equivalent: a markdown table stamped into every PR body and an apex issue. |
| **apex** | The issue that sits above a PR chain and tracks the whole program. |
| **gate.kind** | Hand-typed field marking a blocked row `decision` (a human must choose) or `verification` (anyone can run). |
| **idempotent** | Running it twice produces the same result as running it once. Makes "did it fire?" stop mattering. |
| **reconciler** | A job that recomputes the truth and rewrites the file, rather than reporting that the file is wrong. |
| **`allowed-tools`** | Frontmatter listing the only tools a skill or command may use. Omitting a tool makes it unreachable. |
| **launchd** | macOS's scheduler. Runs a job on a timer, independent of any Claude session. |
| **drift** | Two records of the same fact disagreeing. |

## 1. Recommendation

**Do not pick a manifest-ownership model yet. Ship three things that are true regardless of which model wins, then
make the record self-healing instead of arbitrated.**

The chosen architecture is Option B, rebuilt. B was on the ballot as a *drift detector* — two artifacts, exclusive
ownership, plus a validator that reports disagreement. That version was killed in council, correctly: a detector
emits a verdict somebody has to read and act on, and this codebase has already measured what happens to those. The
rebuilt version emits nothing. It recomputes the derivable fields and rewrites them.

That single change — **from reporting to rewriting** — is what makes it survive the objection that killed it. Nobody
has to read anything, remember anything, or act on anything.

### The sequence, in order

**Step 0 — Close the live leak. Under an hour.**

`ai-data-engineer/plugins/data-engineer/commands/strike.md:303` tells the reader to run `/borg-plan` and
`/borg-collective-review`. Verified: it is the **only** `borg` string anywhere under `plugins/`. Delete it and
replace it with a portable restatement of what it was buying — a design pass before risky logic changes — not a
`command -v borg` probe. A probe hands teammates a dead code path they will eventually delete, silently unhooking
your machine.

Then widen the portability grep. It currently covers exactly two paths:

```
grep -ril "borg" "$REPO/plugins/data-engineer/skills/stacked-pr-program" \
        "$REPO/plugins/data-engineer/hooks"
```

It misses `commands/` **and** `skills/deploy-to-airflow-dev/`. Two blind spots, not one. Point it at the whole
`plugins/` tree. This is the only place in either repo where standalone integrity is tested at all, and right now it
prints `ok zero borg coupling` while the leak ships green.

**Step 1 — Put `allowed-tools` on the borg gates. One session.**

This was not on the ballot. Three of four council personas invented it independently, which was the strongest
convergent signal the exercise produced.

Verified: **zero of 16 borg skills carry an `allowed-tools` key.** All six ai-data-engineer commands do. borg has no
`commands/` directory at all. That one grep is the entire "why are my gates weak" question — it is not a philosophy
problem, it is a missing YAML block.

`borg-assimilate` can currently reach `gh pr merge` with nothing structurally stopping it. `permifrost-ship.md`
cannot reach `gh pr review --approve`, and carries an inline comment saying why the tool is deliberately absent.
Copy that shape, comment included. Roughly twenty lines across two files converts a narrated gate into an
unreachable tool.

Confirm the replacement ship path in the same session. If `gh pr merge` becomes unreachable and nothing user-typed
replaces it, you have hardened the gate by breaking the workflow.

**Step 2 — Resolve the two-validator disagreement first.** *(Blind Critic's amendment.)*

`borg_core/manifest/core.py` reads manifests. `merge-tree/programs.py` writes them. They disagree about shape, and
`core.py`'s own docstring says retiring one of the two copies is AC7's job. Shipping a new *automated* writer on top
of an unresolved reader/writer disagreement takes a risk that today only fires when you hand-edit, and makes it fire
on a timer instead.

This is already on your plate — it is the same merge-tree dedupe the infoviz audit surfaced under AC7. Sequence it
here rather than duplicating it.

**Step 3 — Ship `borg reconcile`. Two to three sessions.**

An idempotent function of (live GitHub sweep, local declared overlay) that recomputes every derivable field and
rewrites `.borg/programs/*.json` atomically. It reports on exactly one thing: the fields it cannot derive.

Three amendments from the blind review, all load-bearing:

- **Cross-repo `order` is NOT derivable.** *(Blind Auditor.)* `merge-tree/programs.py` says so in its own docstring,
  three times: "a base branch is a repo-local name… nothing in git or the GitHub API says platform#834 must merge
  before warehouse#302… So it has to be *declared*." Scope order-derivation to **same-repo base-ref chains only**.
  Cross-repo order joins `gate.kind` / `blocked_by` / `resolved_by` in the report-only set. A reconciler that
  overwrites cross-repo order from base refs produces confident nonsense, and silently deleting a declared edge is
  worse than a stale status.
- **The primary trigger is launchd, not session boundaries.** *(Blind Ideator.)* You already ship
  `com.stillpoint-labs.borg.reap.plist` on an hourly `StartInterval` — OS-scheduled reconciliation is an installed
  pattern here, not a hypothesis. Session triggers cannot catch a merge that happens in repo B while you are working
  in repo A, or while the laptop is closed, or when a teammate merges. A timer catches all three unconditionally.
- **If you also wire Stop, gate it on staleness.** *(Blind Critic.)* borg's Stop matcher is `*`, which fires after
  **every assistant turn**, not once per session. Unguarded, "wire it to Stop" means a live `gh` sweep every turn.
  Skip if the last successful reconcile is under N minutes old.

**Step 4 — Optional, and only if you feel the latency.**

A PostToolUse hook on Bash, filtered on the command string, reading the tool response for the PR URL and calling
`borg reconcile` for that one program. Registered in borg only — never in the ai-data-engineer plugin, where an
airflow-debugger user would pay a per-write tax for a stacked-PR layer they will never run.

This is Option D, demoted twice and corrected once. It buys latency, not correctness.

### What this costs ai-data-engineer

**Two lines.** One deleted instruction, one widened grep path. No new hook, no new dependency, no new file. Every
other change lands in borg-collective. `stamp_stack.py` stays the only thing that writes a PR body — the reconciler
shells out to it rather than reimplementing it, so DE keeps its single-writer property rather than sharing it.

## 2. Summary

Three things went differently than the framing predicted, and each one changed the answer.

**The reliability problem is not where you thought it was.** Every defect in the live corpus was *correct when it was
written* and became a lie at merge. Six PRs are on main; four manifest rows still say `stacked` and `review`; neither
file has a second commit. A hook on `gh pr create` — the intuitive fix, and the one three of four personas initially
picked — would have fired six times and prevented zero of the six. The moment that produced 100% of the defects is
frequently not a local tool call at all: `permifrost-ship` documents that a bot auto-merges. **The mechanism that
catches a state change you did not personally execute is a sweep, not a hook.**

**The tension the clever option existed to resolve is imaginary.** Option F split ownership by lifecycle phase to
preserve "declare a chain before any PR exists." That capability does not exist. `_row_ref_error` returns
`missing ref` on any row without one, and `parse_ref` rejects anything that is not `owner/repo#<digits>`. Every row
in the live corpus carries a ref. F was four to five sessions of machinery defending a pole nobody occupies.

**The highest-value change was not on the ballot.** Zero of 16 borg skills carry `allowed-tools`. All six DE commands
do. That is the whole gate-strength gap, and it costs about twenty lines.

Two things also turned up that nobody was looking for. `.borg/programs/viz-program.json` and
`docs/plans/directives/2026-08-18-program-manifests-stack.json` **both describe PR #158 and disagree about it** —
`gate.kind` is `decision` in one and `verification` in the other. Under ai-data-engineer's own published rule
("a verification with declared outcomes is never a blocker on a person"), one file says a human must choose and the
other says anyone can just run it. And borg-collective's *live* program manifest is the one in
`docs/plans/directives/`, in DE's format, with DE's key names — the repo that owns the borg format is not using the
borg format for its current program.

**This does not fix the clickable-links class, and should not be sold as if it does.** See §4.

## 3. The determinism ladder

Everything below rests on this. Verified against current documentation and this machine's config.

| Tier | Mechanism | Fires |
| --- | --- | --- |
| Deterministic | Hooks on declared events | By construction |
| Deterministic | `disable-model-invocation: true` / `user-invocable: false` skills | Always loaded |
| Deterministic | Slash commands you type | You decide |
| Deterministic | launchd timers | OS-scheduled, session-independent |
| Data, not control | CLAUDE.md | Loads once at session start |
| ~80–90% | Output styles | System prompt; adherence varies |
| ~70–90% | Model-invoked skills | The model decides |

Three limits shape every option:

- **PreToolUse can refuse a tool call. PostToolUse cannot.** But PostToolUse can still *act* — run a script, write a
  file, shell out. "Cannot reject" is not "can only annotate," and collapsing those two is what made Option D's MVP
  look buildable when it is not. At PreToolUse on `gh pr create` there is no PR number yet.
- **There is no plugin-detection API.** A hook can only shell-probe.
- **Skill *names* already don't collide** — they are namespaced `/plugin:skill`. What collides is *semantics*: two
  skills that both plausibly match one task. There is no arbiter for that, and no way for one plugin to disable
  another's skill.

## 4. The clickable-links problem, answered separately

It deserves its own section because it is a different problem and has been getting the same treatment.

The memory file carrying that rule **was demonstrably read into context** — logged 2026-08-18, 08-20 twice, and
08-26. You still had to restate the violation on 08-18, 08-20 and 08-24, and the file grew more emphatic each time.
The delivery mechanism worked. The behavior still failed.

That rules out the entire "write it down somewhere better" family. Prose in context is not a mechanism, even when you
can prove it arrived.

**Split the problem by destination:**

- **Prose the model says to you in chat** — streams, is not a tool call, cannot be intercepted or rewritten by any
  hook. The only lever is the system prompt, at ~80–90% adherence. This one is not solvable today.
- **Prose the model writes into a tool call** — a PR body, an issue comment, a file — *is* a tool call, and
  PreToolUse can refuse it.

And the regex already exists. `ai-data-engineer/tests/run-tests.sh:205-208` carries it as a CI check. Moving it into
a PreToolUse deny on `gh pr create` / `gh pr edit` / `gh issue comment` / `Write` makes the rule structurally
unbreakable **at the moment prose becomes a tool call**. That is a free win sitting in the tree, and it is
deliberately not in the sequence above — it is a separate, smaller piece of work.

## 5. The options, and why five lost

| | Option | Outcome |
| --- | --- | --- |
| A | GitHub is the record; borg only reads | **Killed** |
| B | Partitioned ownership + validator | **Chosen, rebuilt as a reconciler** |
| C | Shared contract package | **Killed** |
| D | Deterministic hook spine | Demoted to optional step 4, event corrected |
| E | Capability-probe layering | Adopted as step 0, probe half rejected |
| F | Phase-separated single writer | **Killed** |

**A — killed on correctness, twice, independently.** The stamped block is a *rendered markdown table*, not a
machine-parseable payload: `after:` edges are absent entirely and `gate.blocked_by_ref` is rendered to prose
footnotes. Reading the chain back off it is an inverse renderer over a lossy rendering. Separately, `shell.py`
states as policy that an unauthenticated `gh`, an offline host or a rate limit is *always* a named warning and a
degraded grid, never a blank one. Making GitHub the sole record inverts that. A's insight survives, though — as the
*derivation source* rather than as a record swap.

**C — killed on governance, not effort.** `stamp_stack.py` is Ontra-time work derived from a colleague's format;
its own provenance line names `kellyldougan`'s stack in `ontra/mswi`. "A third repo neither owns" is a personal
harness asserting co-authority over an employer artifact nobody asked to share — proposed and reviewed by the same
person.

**F — killed on a falsified premise.** Covered in §2.

**D — the event was wrong, not the mechanism.** Kept, moved, and sequenced last so that by the time it stamps
anything, the record it stamps from is derived rather than transcribed. Stamping "from whatever record exists" today
would take a contradiction that is currently inert in two files nobody opens and publish it into four PR bodies
teammates do read.

**E — adopted, minus the probe.** The grep widening is real and mechanically enforceable. The `command -v borg` seam
is the weakest contract on the table and was refused.

## 6. Council dissent worth keeping

The strongest objection to the chosen option, recorded because it is not fully answered:

> "B ships a second cairn and calls the detector a feature."

The argument: drift is not theoretically possible, it is *present, unflagged, today*, in the one repo already running
B's design — and B's response is to formalize that arrangement and add an instrument someone must act on. Backed by
the two hardest numbers available: ~0% effective voluntary capture across four shipped surfaces over five months, and
the clickable-links case above.

**The rebuild answers most of it.** A reconciler emits no verdict for derivable fields; it rewrites them. Nobody
reads anything. The kill was precisely calibrated to a *detector*, and the output type changed.

**Where it still lands:** the #158 `gate.kind` contradiction is hand-typed and not derivable from GitHub. For those
three fields the reconciler can only report — which is exactly the shape the objection names. The honest claim is
that the reporting surface shrinks from an entire row class to three fields, not that it goes to zero.

## 7. Residual risks

1. **Cross-repo edges must never be silently deleted.** If the reconciler cannot re-derive an edge, it leaves it
   alone. A missing edge is worse than a stale status.
2. **`gate.kind` drift remains unsolved.** Three hand-typed fields, one verified live contradiction, no derivation
   available.
3. **`allowed-tools` may break the legitimate ship path.** Confirm the replacement in the same session.
4. **The effect of step 1 is asserted, not measured.** `claude plugin eval` is gated behind early access, `--bare`
   does not disable skills, and there are zero skill-firing tests in the fleet against 85 hook test cases. A harness
   asserting "typing X loads skill Y, and skill Y cannot reach tool Z" is the right long-term fix and is deliberately
   not in this sequence.
5. **SessionStart is a shared slot.** Third-party wildcard hooks already exist in `~/.claude/settings.json`, ordering
   is undocumented, and a periodic writer there must be safe against a concurrent copy of itself. Atomic write is
   necessary; a lock may also be.
6. **Step 3's second leg writes to a team repo.** JSON-only first; PR-body stamping behind a separate flag after two
   clean weeks, and always by shelling to `stamp_stack.py`.

## 8. Prior work (catalogued and quarantined)

Catalogued before option generation and walled off from it; options were generated from the track findings and the
constraint axes, not from this list.

- **`2026-08-11-stacked-pr-gate-integrity.md`** — the zero-borg-coupling ruling. Gets right: names the real root
  cause (settlements and blockers in different documents with one-way pointers) and verifies the constraint
  empirically. Gets wrong: never checked `commands/`.
- **`tests/run-tests.sh`** — four-layer suite. The coupling grep is mechanical and unevadable, and scoped to two
  directories.
- **`stacked-pr-program` + `stamp_stack.py`** — derives from an artifact the author already produces; idempotent
  re-stamping after a documented 2026-08-12 data-loss bug. But the stamp is human-run: a manifest can drift from
  what is published for an arbitrary time with only a warning.
- **`stacked_pr_gate_lint.py`** — deterministic firing, warn-only by design because PostToolUse fires after the
  write. Its heuristic half is explicitly "a speed bump, not a gate."
- **`borg-plan` / `borg-assimilate`** — the maximum a model-invoked skill can do to force sequencing, which is not
  much. No `allowed-tools`.
- **`borg-plan-promote.sh`** — the one clean example in the tree of converting a model-discretionary act into a
  deterministic artifact write.

**The obvious default** — write a stronger instruction in CLAUDE.md or a memory file and expect the model to
comply — is the one approach with measured evidence against it in this codebase.

## 9. Method

Decision-design mode. D1 prior-work catalog quarantined from option generation. D2 fanned out four independent
research tracks (platform mechanics, empirical reliability, ecosystem precedent, artifact/gate shape). D3 generated
six options from zero, including one contradiction-forge option using separation-in-time. D4 ran a four-persona
council with mandatory dissent, then a recommender that engaged the strongest objection. D5 ran three blind
adversarial reviewers — ideator, critic, auditor — none of whom saw the council's reasoning.

Nineteen agents. Ten load-bearing claims independently re-verified against the tree before publication: the
`allowed-tools` count, the absent `commands/` directory, the ref requirement, the #158 contradiction, the Stop hook
matcher, the declared-never-derived docstring, the strike.md leak, the grep scope, the launchd precedent, and the DE
`allowed-tools` count.
