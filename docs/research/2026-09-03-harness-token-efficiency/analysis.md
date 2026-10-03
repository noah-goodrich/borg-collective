Generated: 2026-09-03

# Your Harness Is Burning Tokens — But Not Where The Article Says

**A hybrid research + design pass on "Your AI Agent Is Burning 2.5× Tokens," measured against 588
real sessions on this machine.**

---

## Glossary

Every term used more than once in this document, defined once, here.

| Term | Plain meaning |
|---|---|
| **Harness** | The code *around* the model — what it loads, sends, keeps, and throws away each turn. Claude Code is a harness. |
| **Context / prefix** | Everything sent to the model on a single turn: instructions, tool list, and the whole conversation so far. |
| **Token** | A chunk of text, roughly ¾ of a word. Billing is per token. |
| **Prompt cache** | A saved copy of a context prefix. If the next turn starts with the same bytes, you pay a cheap *read* rate instead of resending at full price. |
| **Cache read** | Re-using cached context. Costs 0.1× the normal input rate. |
| **Cache write** | Storing a *new* prefix in the cache. Costs 1.25× normal input at 5-minute expiry, **2× at 1-hour expiry**. |
| **TTL** | Time-to-live: how long a cache entry survives before it expires. Claude Code's main loop uses the 1-hour option; its subagents use the 5-minute one. |
| **Prefix invalidation** | The cached prefix no longer matches, so the whole thing must be re-written at the expensive rate. |
| **Compaction** | Replacing old conversation history with a summary to free up room. |
| **Context rot** | Model accuracy dropping as the context gets longer — *before* the window is full. |
| **Subagent** | A separate Claude instance given one job; it has its own context and returns only a summary. |
| **MCP** | Model Context Protocol — how external tool servers (Gmail, Chrome, etc.) expose tools. |
| **Deferred tools** | Tools listed by name only, with their full specifications loaded on demand instead of every turn. |
| **requestId** | The identifier for one API call. Claude Code writes several transcript lines per call, all sharing it. |

---

## 1. Recommendations

*(Pending — the design council's recommendation and its blind adversarial review are the final inputs.
This section is completed in the companion `recommendation.md`.)*

---

## 2. Summary

> **GATE FAILED — 50% card-failure rate (band `>10%`), and the design review returned REVISE 3 of 3.**
> Independent verification completed on both source cards: one verified, one **failed** (it asserted a
> TTL split as "100%, verified" from a 12-session spot check; a full sweep found 99.59%). A separate
> claim-level pass **refuted 25 of 64 load-bearing claims (39.1%)**. All corrections are folded in
> below and annotated in place. See [`verification-report.md`](verification-report.md) — and read
> [`recommendation.md`](recommendation.md)'s review banner before acting on anything.

The article's argument is that agent cost is decided by the harness, not the model, and it gives three
habits: load tool definitions lazily, keep big payloads out of the conversation, and compress old
history instead of replaying it. A fourth, buried near the end, is to measure before cutting.

**The direction is right. Almost none of the specifics apply to you, and the ones that do are already
shipped.** Claude Code already defers tool loading, already compacts, already isolates subagents. Your
own `token-cost` plugin already truncates large tool output and already logs per-session spend. Asking
"how do I implement this article" has an anticlimactic answer: you did, mostly before it was written.

What the measurement found instead is more interesting, and it is not in the article.

**Your context averages 444,622 tokens per API call.** Pooled across five large sessions and 2,555
deduplicated turns, that is what gets re-read every single time the model responds. Peak observed:
968,811 tokens, against a one-million-token window. For every token the model *writes*, 519 tokens of
prior context are re-read.

**Context is 91–96% of session cost. Output is 3.4–8.7%.** Any effort aimed at making the model's
replies shorter is aimed at a twentieth of the bill.

**Cache reads are the largest line item at 54.4% of main-loop cost** — charged on the *full prefix,
every single turn* — with writes at 37.9% and output at 7.7%. So **prefix size is the dominant cost
driver**. (An earlier revision of this document had reads and writes inverted, taking the figure from
the double-counted ledger described below. That is the single most instructive error in this research:
having proved the meter was ~3× wrong, it then reasoned from the meter.)

**Within the write side, the largest identified waste has nothing to do with payload size. It is
walking away.** Main-loop cache writes are 99.59% 1-hour TTL, and the data shows a clean
dose-response: turns
following a gap of under a minute trigger a full prefix re-write 0.18% of the time; turns following a
gap of over an hour trigger one **95.1%** of the time. Those post-hour-gap turns are **63.2% of all
cache-write tokens measured**. Leave a session idle past the hour and the entire conversation — up to
900,000 tokens of it — is rebuilt at 20× the cache-read rate. That is a session-lifecycle problem, and
none of the article's three habits touches it.

**The instrument you would use to check any of this is broken in three independent ways.** All three
were verified by re-running the code, not by reading it:

1. `claude-opus-5` does not match the regex `opus-4-[6-9]`, so the model you actually run falls
   through to a legacy branch and is priced at $15/$75 instead of $5/$25 — a **3× overstatement**.
2. Cache writes are priced at a single rate when the TTL differs by tier — main loop is 99.59%
   1-hour (2× base), subagents are 100% 5-minute (1.25×) — so the blanket rate is wrong in opposite
   directions for the two.
3. The collector sums one transcript record per *content block* rather than per API call, so every
   token count is inflated by the blocks-per-call factor — measured at **2.16× on cache reads and
   2.63× on output** for one session, and independently reproduced at 1.90× and 1.63× on a different
   session by a separate agent.

These do not cancel to something usable. They point in different directions, differ per component and
per model, and cannot be corrected by any single multiplier. **`borg spend`'s headline is roughly 2×
the real figure.** Every option this research considered had been sized against that wrong number.

**NO PRIMARY EVIDENCE was needed from the literature for the central finding** — it is direct
measurement of the system under study. The published sources matter for two things only: establishing
that the *technique* directions are real, and supplying the counter-evidence that keeps this from
becoming an enthusiastic mistake.

That counter-evidence is substantial, and it reframes the problem:

- **Context rot is measurable at 32,000–50,000 tokens.** NoLiMa finds models dropping below half their
  short-context accuracy by 32K; GPT-4o falls from 99.3% to 69.7%. **You operate at a 444,622-token
  mean — roughly 10–14× past where degradation begins.** If that literature transfers, the strongest
  argument for a smaller context is not the bill. It is that your best model is being asked to work in
  conditions where it measurably is not at its best.
- **But cutting tokens can cut quality directly.** Anthropic found token usage alone explains ~80% of
  performance variance in their multi-agent evaluation — more tokens correlated with *better* results.
- **Compaction is not free and can be worse than doing nothing clever.** The TRACE study found
  summary-based compaction at tight budgets scored 44.6% task completion against 77.2% for naive
  first-in-first-out truncation. Independent evaluation of three production compression systems scored
  all of them 2.19–2.45 out of 5 on file-awareness afterward, naming "silent information drift" as a
  failure mode of Anthropic's own approach.
- **Offloading is not free either.** One study bought a ~40% token reduction with a 10–17% regression
  on SWE-bench Verified.

**Testability classification.** Every load-bearing question here was cheaply testable in-environment
and was tested: the context sizes, the cost split, the invalidation cause, the three collector bugs,
and the truncation hook's real firing rate are all direct measurements with reproduction commands
recorded. Two questions are **declared untestable here**: whether extended-thinking blocks are
re-transmitted on the wire (transcript presence does not prove re-transmission, and the wire format is
not observable from the client), and whether the context-rot literature transfers to this specific
workload (that would need a controlled eval against held-out tasks, which is a project, not a check).

**On the article's own numbers: use the direction, discard the figures.** Its headline comes from
TrueFoundry benchmarking its own harness against a competitor's — a first-party comparison with a
direct conflict of interest, n=14 tasks, no repeated trials, and no confidence interval or
significance test. Adversarial verification corrected this audit in the benchmark's *favour* on two
counts, which is worth stating plainly: the losing side's configuration **is** published (in the
benchmark repository rather than the article), and the "30–75%" range is internally consistent rather
than contradictory. Two problems survive. The article reports the two arms as having near-identical
solve rates, which at n=14 is not a finding — the confidence interval is far wider than the gap. And
the eye-catching "up to 75% cheaper" end of the range is driven mostly by **swapping to a cheaper
model**, which is precisely the move the article's title tells you does not work.

---

## 5. Research

### T1 — Where the cost actually lands

Measured across the 588 ledger records carrying per-model detail, and separately across five large
transcripts analysed turn by turn.

| Component | Share of main-loop cost (deduplicated, all 107 on-disk transcripts) |
|---|---|
| **Cache reads** | **54.4%** |
| Cache writes | 37.9% (1-hour 99.7% of it) |
| Output | 7.7% |
| Fresh input | <0.1% |

**Cache reads are the largest line item**, at a read:write cost ratio of **1.44**. Per-session across
the five deepest transcripts the read share ranges 49.8–73.2% and the write share 19.1–46.8%; the
single session where writes lead is the one with the highest re-write concentration.

This corrects an inverted figure carried through an earlier revision of this research, which reported
writes at ~47% against reads at ~41%. That came from the **double-counted ledger** — the very defect
documented in §T4. Having established the meter was ~3× wrong, the analysis then reasoned from its
output. The correction matters because cache read is charged on the **full prefix every single turn**,
which makes **prefix size**, not invalidation frequency, the dominant cost driver.

Per-session context prefix means: 429,478 / 551,579 / 383,783 / 467,676 / 316,683 tokens. Pooled:
**444,622 tokens re-read per API call**. Pooled cache reads are **519×** pooled output tokens.

A brand-new session opens at **66,231–77,095 tokens before you type anything**. About 20,628 of that
arrives pre-cached — a constant floor seen in every session, the base system prompt and core tool
schemas — and 45,603–56,467 is freshly written each time.

### T2 — When the cost is incurred

Full prefix re-writes, bucketed by idle gap since the previous turn, pooled over 2,555 turns:

| Gap since previous turn | Turns | Full re-writes | Rate |
|---|---|---|---|
| < 1 min | 2,241 | 4 | 0.18% |
| 1–5 min | 175 | 6 | 3.4% |
| 5–30 min | 73 | 8 | 11.0% |
| 30–60 min | 13 | 2 | 15.4% |
| **> 60 min** | **41** | **39** | **95.1%** |

Turns following a >60-minute gap account for **63.2% of all cache-write tokens** (19,834,187 of
31,376,540). Four of five sessions show a 100% re-write rate in that bucket.

**Compaction is not the cause.** Exactly one compaction event occurred across 2,555 turns. One session
ran to a 968,811-token prefix with 27 write spikes and no compaction marker at all. A separate agent
put it at one compaction boundary per 79 spikes. The sessions simply grow until they end.

*This corrects an earlier reading in this same research.* Sorting spikes by size and inspecting their
gaps suggested no relationship, and compaction was proposed. That was the wrong summary statistic: the
question is the re-write **rate per gap bucket**, not the gap of the largest writes.

A residual minority of re-writes is still unexplained — roughly 5 of 27 in one session fire mid-flow
after a sub-minute gap, coinciding with a background task notification opening a new top-level turn.
Mechanism unconfirmed.

### T3 — What is actually in the context

Two independent decompositions, different denominators, both informative.

By API-visible content bytes, averaged over five sessions: tool results 41.4%, the agent's **own
tool-call inputs** 26.9%, harness/hook/skill injections 21.1%, assistant prose 5.7%, **human-typed
text 4.8%**.

The agent's own tool inputs weigh as much as the results it gets back — driven by `Write` and `Edit`
payloads, not `Bash`. Every file written is stored twice: once as the write, again if later read.

By per-turn instruction prefix (28,256 tokens measured): `borg-collective/CLAUDE.md` 40.5%, skill
descriptions 17.7%, deferred tool names 9.6%, SessionStart injection 8.6%, `MEMORY.md` 7.8%.

**Hook output is a silent 20–26% of context.** In one session, `PreToolUse:Bash` fired 376 times at
~400 bytes each — roughly **37,000 tokens** of permanently resident guard-hook chatter.

**Deferred tools are already saving 64,000–97,000 tokens per turn.** All 224 MCP tools arrive as a
name list costing ~2,712 tokens; loading their schemas eagerly would cost an estimated 66,700–100,000.
This is the largest single context lever available and **it is already pulled**. Attacking MCP surface
area further would be optimising the wrong end.

### T4 — The instrument

Three verified defects in `token-cost/hooks/token-spend-log.sh`, detailed in §2. Additionally:

- `borg spend --by-model` carries a *second*, contradictory rate table, reporting one model at
  $54,837 where the same records' stored cost is $18,279 — one command disagreeing with itself by 3×.
- Stored costs are frozen at whatever rates shipped that day, so summing across eras is meaningless.
- **398 of 803 ledger rows (49.6%) are zero-token artefacts** from a since-fixed `/usage` polling bug.
  They contribute $0 but corrupt every count and average taken over the file.
- The `token-cost` skill's standing "~96% main loop / ~4% subagents" claim is a single-session
  observation generalised into a rule, and it is loaded into **every** session via an `@`-import. The
  real split is a function of fan-out width: sessions with 0–3 subagents do run 98–100% main, while a
  46-agent session ran 16% main. Monthly main share fell from ~85% to 62% as fan-out grew. The
  skill's stated *reason* — that the harness routes subagents to cheap tiers — is false here; Opus
  tiers carry roughly two-thirds of subagent spend.

### T5 — The technique evidence, and what argues against it

Established (Anthropic documentation, verified against primary sources): 4 cache breakpoints per
request, rendered tools → system → messages forming an invalidation hierarchy; cache read at 0.1×
base, write at 1.25× (5-min) or 2× (1-hour); **changing tool definitions invalidates the entire
hierarchy**, while changing `tool_choice` invalidates only messages; Tool Search cuts tool-definition
tokens by >85%; auto-compact triggers near 95% of the window; subagents should return 1,000–2,000
token summaries.

Counter-evidence is summarised in §2 and is the reason this research does not recommend aggressive
trimming: compaction can underperform naive truncation, compression buys tokens with accuracy, tool
deferral degrades genuinely multi-tool tasks (39.7% complete-set coverage@3), and more tokens
correlate with better results.

### T6 — In-editor Markdown rendering (separate question)

Neovim 0.12 enables Treesitter Markdown *highlighting* by default but adds no heading backgrounds,
table alignment, or checkbox glyphs — a plugin is still required.

`render-markdown.nvim` renders in-buffer using extmarks and **stays rendered while you move around**;
only the cursor's own line drops to raw syntax. `markview.nvim` is the main alternative and covers
more formats, but its preview disappears on cursor movement, which is wrong for reading. The two must
not be installed together.

**This is now installed and verified working** — see §3.

---

## 3. What Was Installed

`/Users/noah/.config/dotfiles/nvim/lua/custom/plugins/markdown.lua`, picked up automatically by the
existing `{ import = 'custom.plugins' }` in `init.lua:943`. Both dependencies were already present
(`nvim-treesitter`, `nvim-mini/mini.nvim`), as were the `markdown` and `markdown_inline` parsers.

Verified by loading a real document headlessly: `filetype=markdown`, `conceallevel=3`,
`render-markdown` module loaded. Toggle per buffer with `<leader>tm`, or `:RenderMarkdown toggle`
globally.

Unrelated pre-existing issue surfaced during that check: the `tree-sitter` CLI is not installed, so
the `diff` and `sql` parsers cannot compile. Markdown is unaffected — Neovim 0.12 bundles it.

---

## 6. Methodology

**Mode:** hybrid — evidence pipeline first, then decision-design over its findings.
**Tier:** full.

**Search and measurement log.** Ten parallel research tracks: one benchmark audit, five technique
tracks (Anthropic guidance, progressive tool disclosure, payload offload, compaction/context rot,
observability), one Neovim track, and three local measurement tracks (per-turn context weight,
transcript forensics, prior-work catalogue). Followed by 16 adversarial claim verifications, then a
five-option design council and a three-lens blind review.

**Falsification queries were run deliberately** on every technique track — each was instructed to
search for evidence the technique backfires. This produced the TRACE result, the minification
regression, and the tool-retrieval coverage figure, all of which materially changed the
recommendation. This is why the bias-guard summary below is not skewed.

**Source evaluation — GATE FAILED.** Independent card verification completed on both cards.

| Metric | Value |
|---|---|
| Sample size | 2 of 2 cards (100%) |
| Verified | 1 |
| Failed | 1 |
| Inaccessible | 0 |
| Failure rate | 50% |
| Failure-rate band | `>10%` |

**Failure count: 1.** Sample: 2 of 2 total cards (100%) — the protocol requires all cards when fewer
than 10 exist. The failure rate of 50% is ten times the 5% threshold, so this run does not pass and
was not remediated into a pass. Separately, a claim-level adversarial pass refuted 25 of 64
load-bearing claims (39.1%), and the blind design review returned REVISE from all three reviewers.
Full account in [`verification-report.md`](verification-report.md).

**Evidence-level distribution.** Level 1 (direct measurement of the system under study): 2 source
cards, both local. Vendor benchmark: 4 major claims. Peer-reviewed: 4. Documentation: the Anthropic
primary sources. Practitioner report: the remainder.

**Bias-Guard Summary.**

| Stance | Count |
|---|---|
| Sources agreeing with the thesis | 6 |
| Sources disagreeing / limiting it | 7 |
| Neutral (mechanism documentation) | 5 |

Agree:disagree is 0.86:1 — below the 3:1 skew threshold, so no steel-man subsection is required. The
balance is a direct result of the mandatory falsification queries.

**Source exclusion.** The article's own framing claim — that a typical harness "concatenates fifty
tool schemas into the prompt on every turn" — was **excluded as not applicable**: measurement shows
all 224 tools on this machine arrive deferred. The lowest-scoring source that still cleared the bar
is the TrueFoundry benchmark, retained only as the object of the audit, never as support for a
recommendation.

**Limitations.**

1. **One user, one working style.** Eight sessions across two projects, all Noah's. The context-size
   and idle-gap findings may not generalise beyond this workflow.
2. **The cost figures are upper bounds.** Because the collector's inflation factor varies per
   component, absolute dollars are not trustworthy; component *shares* from deduplicated transcripts
   are.
3. **The residual re-write mechanism is unresolved** (§T2).
4. **Thinking-block re-transmission was not established** and is excluded from conclusions.
5. **Context-rot transfer is assumed, not demonstrated,** for this workload.
6. **One brief error propagated.** An early audit finding — that the article's supporting "Automation
   Anywhere: ~20% fewer tool calls" claim could not be found to exist — was **refuted on
   verification**. It is real and published (2026-05-18), verbatim: "Context-enabled agents also
   reduced average tool calls per run by roughly 20% on complex workflows." It remains a vendor blog
   with no disclosed methodology, but "unverified" is a different charge from "fabricated," and the
   erroneous version had already been passed into the design brief before it was caught. No
   recommendation rests on it.
7. **No independent replication of the TrueFoundry benchmark exists**, though verification did surface
   a vendor-neutral peer-reviewed study supporting the *direction* under a cleaner design.

**Paywall scan:** no high-value paywalled candidates identified.
