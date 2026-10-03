Generated: 2026-09-03

# Repair The Meter, Then Ship The Baton

**Recommendation from a five-option design council with mandatory dissent and a three-lens blind
adversarial review. Evidence base: [`analysis.md`](analysis.md) and two Level-1 source cards.**

---

## Recommendation

> ## ⚠ BLIND REVIEW VERDICT: **REVISE** — unanimous (3 of 3)
>
> The three-lens blind adversarial review ran to completion and **none of the three upheld this
> recommendation**. Two of its findings are serious enough to change what you should do, and both were
> independently re-verified before being recorded here. **Do not execute the sequence below as
> written.** The corrections are stated inline where they land; the two that matter most:
>
> **1. Step 4 would destroy 93% of your cost history, irreversibly.** Verified: the ledger holds
> **744 unique session ids**, only **107 main transcripts** survive on disk, and the intersection is
> **53**. "Replay every transcript and rewrite the ledger" turns an 803-record, 8-week history into
> ~53 records. Transcripts are pruned; **the ledger is the only durable copy.** The collector's own
> header asserts "history is reconstructable from the durable transcripts" — that premise is false on
> this machine. Step 4 is withdrawn and replaced below.
>
> **2. The read/write split in this document was inverted, by exactly the bug it diagnoses.**
> Recomputed from *deduplicated* transcripts at corrected rates: **cache READ 54.4%, cache WRITE
> 37.9%, output 7.7%** — a read:write cost ratio of 1.44. The "cache writes are the single largest
> line item" framing came from the double-counted ledger. Having proved the meter was ~3× wrong, this
> recommendation then reasoned from its output. That inversion is load-bearing: cache read is charged
> on the **full prefix every single turn**, so **prefix size is the dominant cost driver**, which
> partially resurrects the prefix-size options the do-not-build list killed on the inverted framing.
>
> Also flagged and accepted: the **~$28,000** figure is an extrapolation presented as a measurement (a
> blanket 1.9× applied to per-field, per-session inflation that actually ranges 1.80–2.16). Only
> **$53,324.95** — the rate-correction half — reproduces exactly. Three options the reviewers named
> that this set missed are recorded under *Missed options* at the foot of this document.

**Two parts, ~1.5 days total, no new module and no new command.**

But first, the plain answer to what you actually asked.

### The article's thesis is already implemented, and not by borg

All three of its habits ship inside Claude Code itself:

| The article's habit | Where it already lives |
|---|---|
| Defer tool definitions | ToolSearch / deferred tools — **already saving you 64,000–97,000 tokens per turn** |
| Get large payloads out of context | Subagent context isolation, plus your own armed `truncate-tool-output.sh` |
| Compact instead of replaying | Auto-compact at ~95% of window |

You implemented them by upgrading Claude Code. **There is no borg-side work to do on the article.**

Its fourth, quieter habit — measure before you cut — is the one that isn't done. That is the whole
recommendation.

### What the measurement found

**The instrument every option was reasoning from is broken three ways.** All three verified by running
the code:

1. **No request-level deduplication.** `_bymodel` groups by model with no `requestId` dedup, but
   Claude Code writes one transcript line per *content block*, each carrying a copy of the same call's
   usage. Measured inflation across five sessions: 1.63×, 1.86×, 1.89×, 1.91×, 2.11× — call it 1.9×.
2. **One cache-write rate where there are two.** Main-loop transcripts are **99.59% 1-hour** TTL (2×
   base input); subagent transcripts are **100% 5-minute** (1.25×). A blanket rate is wrong in
   opposite directions for the two tiers. *(An earlier revision said 100% on both sides; a full sweep
   of 110 main transcripts found two 5-minute turns.)*
3. **The model-tier regex misses the model you run.** `opus-4-[6-9]` does not match `claude-opus-5`,
   which falls through to a pre-4.6 arm and bills at **$15/$75** instead of $5/$25. `claude-sonnet-5`
   has the same problem. This bug is *growing* — opus-5 is the current default.

Net across all 803 records: logged **$92,711.92** → correct rates **$53,324.95**. That second figure
reproduces exactly and is the one to quote. **The further "≈$28,000 / 3× high" step does not** — it
applies a blanket 1.9× to a dedup inflation that is per-field and per-session (measured range
1.80–2.16), and review correctly flagged it as an extrapolation dressed as a measurement. What is
certain: the meter is materially high, historical records were never backfilled, and `borg spend`
sums figures priced under at least two different rate tables.

### Part 1 — Repair the meter (half a day)

Three bugs, two jq functions, one file: `token-cost/hooks/token-spend-log.sh`. Plus bats coverage in
the same commit, a backfill, and a correction to the skill that is currently steering judgment wrong
in every session that loads it.

### Part 2 — The deterministic baton (one day)

`borg-link-up.sh` writes `<project>/.borg/relay/<ts>-facts.md` on **every** Stop, unconditionally and
non-blocking: files edited, non-zero exits with their first stderr line verbatim, branch, worktree
path, refs seen. `borg-link-down.sh` injects it at the next SessionStart, facts first, prose second.

**Zero model involvement, zero interruption, ~100% coverage.** The "~41.5% capture rate today" this
was sized against **did not reproduce under review** — recount it before using it as justification.

---

## Why not the obvious thing

The council's sharpest dissent came from the User Advocate, and it changed the recommendation rather
than being noted and routed around:

> A dashboard is a discipline dependency wearing an automation costume, and this council is about to
> build four variants of one.

Four of five options led with "build a ledger, then decide." Each terminated in a surface you would
have to choose to read and then choose to act on days later. Against a measured base rate for a
*one-step* voluntary action in this repo — with a hook actively nudging it — of well under half.

Three concrete changes followed: the `borg link` SIGNALS cost line was removed, the `borg ledger`
command was removed, and the baton was promoted from "maybe later, after a measurement gate" to a
committed Part 2 that ships on its own argument.

**Where the recommendation holds against that dissent:** the critique lands on ledgers that add a
*reading* surface. `token-spend-log.sh` already runs unattended on every SessionEnd, and `borg spend`
already prints it. Fixing three bugs inside it adds zero steps to your day and removes a wrong number
from your judgment. That is a defect repair in existing automation, not a new dashboard.

**Where it amends the dissent:** the Advocate wanted a Stop hook returning `decision: "block"` to
force the checkpoint. Two other council members killed that on blast radius — a blocking hook at the
single most sensitive moment for a friction-sensitive user, whose own failure mode is "get the reason
wrong and Claude starts new work instead of checkpointing." Both sides were right, and the resolution
neither named is that **the baton is deterministic**: files, exits, branch, refs all come out of the
transcript with no model involvement. Write it every time, block nothing. The Advocate's goal is
fully served; only the mechanism changes, and it changes in the direction their own argument points.

---

## Do not build

Ranked by how tempting each one is.

**The cause-attribution join.** The flagship of three separate options. Measured: **2 compaction
boundaries against 79 deduplicated cache-write spikes** — the leading hypothesis explains ~2.5% of
events. (Stated as 1 in an earlier revision; recount under review gave 2. The conclusion is unchanged
in direction, and the corpus is 107 on-disk transcripts, not the 588 sessions quoted elsewhere.) Worse, every
remaining candidate cause sits behind a harness wall no hook event can reach:
auto-compact fires internally at ~95% of window, ToolSearch cannot be vetoed without breaking the task
that triggered it, and TTL expiry is billing policy. This is measurement with no lever. As one council
member put it, an elegant attribution table for three causes you cannot act on is *"a very
well-tested feeling of understanding"* — which is precisely what let cairn survive four shipped
surfaces before anyone measured it.

**A new `borg_core/` package for any of this.** All three meter bugs live in a 40-line stretch of one
jq file. The architecture rule about testable cores does not mean every fix becomes a module.

**Splitting `CLAUDE.md`'s `Learned` section behind retrieval.** Killed independently by two council
members. That section is composed entirely of exact numerics and hard constraints that exist *because
each failure already happened once* — the redirect leak that kept plugin CI red for weeks, the
unexported-variable bug that shipped `borg recon` dead for two months. The proposing option's own
evidence puts retrieval at **39.7% complete-set coverage@3**, and it concedes in its own tradeoffs
that some session will re-hit the redirect leak. It is the only proposal in the set that can
*manufacture* a defect rather than merely fail to prevent one — to reclaim ~2% of a 400k prefix.
Keep a byte budget on the spine; do not evict `Learned`.

**Tool pinning / SessionStart schema preload.** Trades a permanent always-paid +7,580 tokens on every
turn against an intermittent, conditionally-avoided write. Those tokens land in the fixed startup
floor that is *already* past the degradation onset in the context-rot literature. It makes the quality
problem worse to improve a billing line.

**Any hook returning `decision: "block"` or `permissionDecision: "deny"`.** Highest blast radius in
the set, at the most sensitive moment, against a cause measured at 1 event per 79. Note the precedent:
`borg-dispatch-guard.sh` was verified to have **never been armed** — `~/.claude/settings.json`
contains exactly `DISABLE_AUTOUPDATER` and `TRUNCATE_TOOL_OUTPUT`. Building a second default-OFF guard
that will also never be armed is not a deliverable.

**A refusal directive written before the backfill.** One option proposed freezing a corrected total
into a document whose purpose is to stop future re-litigation — using a number that runs the wrong way
by ~3×. A refusal list built on a wrong number is worse than none, because it ships this afternoon and
calls itself settled. Write it *after* step 6.

**Anything reimplementing habits 1–3.** That is reimplementing the harness, badly.

---

## Sequence

**Part 1 — the meter**

1. **Fix `_bymodel`** (`token-spend-log.sh:45-56`). Insert `group_by(.requestId) | map(.[0])` before
   `group_by(.m)`. Split `cache_creation` into `_1h` / `_5m` from the transcript's
   `ephemeral_1h_input_tokens` / `ephemeral_5m_input_tokens`, falling back to the flat field at the 1h
   rate when absent. Keep existing field names; the split is additive.
2. **Fix `_costof`** (lines 61-73). Change `opus-4-[6-9]` → `opus-5|opus-4-[6-9]`. Add a `sonnet-5`
   tier at `{i:2, o:10, r:0.20}` ahead of the generic `sonnet` arm. Replace the single `w:` column
   with `w1h:` / `w5m:` (opus: 10.00/6.25; sonnet-5: 4.00/2.50; fable: 20.00/12.50; haiku: 2.00/1.25)
   and price each bucket from the record. Bump to `schema:3`.
3. **Bats coverage, same commit.** Three cases: three content-block lines sharing one `requestId`
   count once; `claude-opus-5` prices at $5/$25; a 1h record prices at 2× while a 5m record prices at
   1.25×. That third case is what would have caught a blanket rate swap.
4. **~~Back up, then backfill from transcripts.~~ WITHDRAWN — this would delete 93% of the ledger.**
   Replaced by **in-place recomputation**, which a reviewer proposed and which is strictly better:
   `token-spend.jsonl` already stores `main.by_model` and `subagents.by_model` as raw
   input/output/cache_creation/cache_read counts per model. Two of the three bugs — the model-tier
   regex and the TTL rate — are pure pricing and can therefore be recomputed **retroactively for all
   744 sessions from the stored counts, with no transcript needed**. Only the dedup bug is a *count*
   error, and that one is unfixable for the 691 sessions whose transcripts are gone; apply it
   **forward-only** and mark pre-fix records with a `counts_deduped: false` flag so the two eras are
   never silently summed. Back up first regardless.
5. **Correct `token-cost/skills/token-cost/SKILL.md`.** Replace the "~96% main / ~4% subagents"
   standing generalization with the backfilled figure. Add `claude-opus-5` and `claude-sonnet-5` rows
   to the pricing table — their absence is what let bug 3 hide. Document the 1h/5m split.
6. **Run the spike census with `jq`, not a module — then STOP and read the number.** This afternoon
   replaces every proposed cause-attribution build. Authorize nothing outside this list before looking
   at the corrected total. **Caveat added under review:** the census covers 107 on-disk transcripts,
   not the 588 sessions quoted elsewhere in this document — say so when reporting whatever it finds.
   The "1 compaction per 79 spikes" figure did not reproduce on recount (actual: 2), so treat the
   compaction-is-rare conclusion as directionally supported, not settled.

**Part 2 — the baton**

7. **Extend `hooks/borg-link-up.sh` (Stop).** It already parses `session_id` and `cwd` from stdin; add
   `transcript_path`. Write the facts file. Always `exit 0`. **Brace-group the redirect** —
   `{ printf ... > "$dir/f"; } 2>/dev/null` — because bash opens redirection targets before the
   command runs, and a missing `.borg/relay/` would splice an error ahead of the JSON on stdout. That
   exact bug is in this repo's own `Learned` section.
8. **Extend `hooks/borg-link-down.sh` (SessionStart)** at the existing `additionalContext` assembly to
   inject the newest facts file alongside the checkpoint. Facts first, prose second — the compression
   evidence says prose is what loses exact numerics, paths, and error strings.
9. **Bats coverage for both hooks.** Override **both** `HOME` and `XDG_CONFIG_HOME` in
   `setup_temp_dirs()` — `borg-link-down.sh` recomputes `BORG_DIR` from `XDG_CONFIG_HOME` and ignores
   an exported one. Export `GIT_AUTHOR_*` / `GIT_COMMITTER_*` / `GIT_CONFIG_NOSYSTEM=1` for any case
   that shells to `git commit`.

**Optional, same afternoon or never**

10. **The byte gate.** `truncate-tool-output.sh` gates on `wc -l > 200` alone, so a 56KB result on 30
    lines passes untouched — which is why it fires on **1–2% of calls**. Add
    `TRUNCATE_TOOL_OUTPUT_MAX_BYTES` (default 8000) as an OR-condition. ~6 lines in an already-armed,
    already-fail-safe hook. Honest ceiling: it slows future prefix growth, it does not shrink a prefix
    already built.

---

## Open questions

- **Is the subagent side duplicated too?** The dedup bug is confirmed on main-loop transcripts.
  `_bysubagent` may share `_bymodel`'s shape. Check before quoting any corrected subagent number.
- **Does ~$28k instead of ~$93k change the priority of this whole question?** Still real money over 8
  weeks, but roughly a third of what every option was sized against. Some do-not-build items were
  borderline at $93k and are clearly not worth it at $28k. Re-read that list after the backfill.
- **AC5 versus this work.** `ls /Users/noah/dev/*/.borg/programs/*.json` returns **2 files in the
  entire workspace**, against a viz layer that took 4 PRs and 7 adversarial review rounds. A finished
  renderer with an empty tank has a stronger claim on your next working day than anything here. That
  is your call, not something to fold in silently.
- **Is ~41.5% the right checkpoint denominator?** 222 real checkpoints against 535 sessions, after
  excluding 607 `.stryker-tmp` duplicates. Some sessions legitimately need no baton. Gating the facts
  file on a non-empty edited-files-or-nonzero-exits set would make the denominator meaningful and stop
  the hook writing empty batons.
- **Does the transcript schema hold?** `requestId`, `attributionSkill`, `compactMetadata` and the
  `cache_creation` sub-object are all *observed, not contracted*. The meter fix depends on `requestId`
  and the TTL sub-object. A Claude Code release renaming either breaks the correction silently — worth
  a bats case that fails loudly on an absent `requestId` rather than falling back to the old summing.
- **Thinking-block wire retention is still unmeasured.** 38.7% of conversation content by transcript
  volume, and nothing here resolves it, because transcript presence does not prove re-transmission.

---

## Prior Work (catalogued, then quarantined)

Recorded before options were generated, and walled off so the option set was produced from zero.

| Artefact | State |
|---|---|
| `token-spend-log.sh` (SessionEnd) | Ships; three verified bugs |
| `token-cost` SKILL inline estimate | Ships; `@`-imported into every session; carries the wrong 96/4 claim |
| `borg spend` | Ships; second contradictory rate table in `--by-model` |
| `truncate-tool-output.sh` | Ships and **armed**; fires on 1–2% of calls |
| `bin/borg-usage-watch` | Ships; signal live and healthy; **sweep default-OFF** |
| `borg-dispatch-guard.sh` | Ships; **never armed** |
| `effortLevel: medium` | Already set globally — a prior recommendation already shipped |
| Claude Code: ToolSearch, auto-compact, subagent isolation | Shipped by the harness |


---

## Missed options (raised by blind review, not evaluated by the council)

All three reviewers named alternatives the five-option set never generated. They are recorded here
unevaluated — none has been through the council, and none should be actioned without one.

1. **Attack the turn multiplier, not the prefix.** Every option decomposed cost as *prefix size* and
   attacked tokens. None decomposed it as **turns × prefix** and attacked the multiplier. At a
   corpus-wide mean prefix of ~354k tokens, every turn costs roughly **$0.177 in cache read before it
   does anything at all**. Tool-call batching reduces the count of turns directly. Given the corrected
   finding that cache read is 54.4% of spend, this is aimed at the largest line item and is the most
   promising of the three.
2. **Use the `session-report` plugin already installed on this machine.** Its
   `analyze-sessions.mjs` header documents the exact content-block duplication this research
   "discovered by measuring" — and it documents the opposite dedup convention: **only the LAST block
   of a group carries the final `output_tokens`**. Sequence step 1's `map(.[0])` takes the *first*.
   Check this before shipping the dedup patch; the proposed fix may undercount output.
3. **In-place ledger recomputation** — now folded into step 4 above.
