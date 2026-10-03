# Source Card: Local Claude Code Spend Telemetry (Noah's machine)

**Full citation:** Goodrich, N. (2026). `~/.claude/token-spend.jsonl` — per-session token accounting
written by the `token-cost` plugin's SessionEnd hook. 803 records total; 588 carrying `schema: 2`
(per-model split of main-loop vs subagent usage). Analyzed 2026-09-03.

**URL:** `file:///Users/noah/.claude/token-spend.jsonl` (local; not published)

**Date accessed:** 2026-09-03

**Evidence level:** Level 1 — direct observation / instrumented measurement of the production system
under study. This is the strongest evidence class in the hierarchy: it is not a report about agent
harnesses in general, it is a census of the specific harness the decision is about.

**Research topic area:** T1 — Where does agent token cost actually land?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|---|---|---|
| 1 | Authority | 5/5 | Emitted by the harness itself at SessionEnd; not self-reported by a model. |
| 2 | Methodology | 4/5 | Sums the `usage` blocks Anthropic's API returns per assistant message. Sound. Loses one point: `est_cost_usd` is an API-list-price equivalent, not the user's actual subscription billing. |
| 3 | Recency | 5/5 | Rolling window ending 2026-08-31; analyzed two days later. |
| 4 | Corroboration | 4/5 | Raw token counts are trustworthy. Stored cost reconciles by two aggregation paths that differ only by float-summation order: summing top-level `.est_cost_usd` gives $92,711.92, summing `.main.est_cost_usd + .subagents.est_cost_usd` gives $92,712.02. Both reproduce; the 10-cent gap is summation drift, not a discrepancy. (An earlier revision of this card quoted the two figures in different sections without noting they were different paths.) The *derived* cost figures are not corroborated by the collector — two rate bugs were found and corrected against Anthropic's published rate card and the transcripts' own TTL field, which is why this card reprices from raw counts rather than quoting `est_cost_usd`. |
| 5 | Bias | 5/5 | Bias guard applied — scored HARDER because the finding agrees with the thesis under test. No incentive structure: a local log file has nothing to sell. Counts are mechanical. |
| 6 | Logic | 4/5 | Scored HARDER (agreement). The inference "cache tokens dominate cost" follows arithmetically from the counts and the rate card. The weaker inference — that this waste is *removable* — does NOT follow from this source and is not claimed here. |
| 7 | Transparency | 5/5 | Raw data on disk, reproducible with a single `jq` command, shown below. |
| 8 | Intellectual honesty | 4/5 | Scored HARDER (agreement). Known limitation stated rather than buried: the file records totals per session, not per-turn or per-context-source, so it localizes cost to a *layer* and cannot localize it to a *cause*. |
| 9 | Relevance | 5/5 | It is a measurement of the exact system the decision concerns. |
| 10 | Sample size | 5/5 | 588 sessions, 26.7 billion tokens, ~8 weeks. Not a 14-task benchmark. |

**Score band:** `keep`

**Bias Guard Check:** [x] I AGREE with this source's implication (harness/context design drives cost
more than model choice) → dimensions 5, 6, and 8 were scored HARDER, and the limitation in dimension
8 was written before the finding was used.

## Key Findings

**Scope note.** The ledger holds 803 records; only the 588 carrying `schema: 2` break usage down per
model, so every recomputation below covers those 588. The 215 older `schema: 1` records
(stored cost $54,876) cannot be repriced and are excluded rather than silently mixed in. Separately,
**398 of the 803 rows (49.6%) contain zero output tokens** — `claude -p "/usage"` probe sessions from
a since-fixed polling bug. They contribute $0 and do not affect sums, but they corrupt any count or
per-session average taken over the raw file.

**Counting note — the ledger's token counts are themselves inflated ~2×, unevenly.** Verified
directly: for session `e053704a`, this file stores `cache_read` 567,704,618 and `output` 1,664,883,
while deduplicating the transcript by `message.id` gives 262,840,263 and 634,229 — ratios of **2.16×
and 2.63×**. Claude Code writes one transcript record per *content block*, all sharing one request's
`usage`, and the collector sums per record. Because the factor differs per component and per session,
**no single multiplier corrects it**. Consequence: the absolute dollar figures below are upper bounds
of unknown tightness, and the component *shares* are distorted too. For trustworthy per-session
shares, use the deduplicated figures in [the transcript-forensics card](harness-token-transcript-forensics.md)
(context 91–96% of cost, output 3.4–8.7%, cache reads the largest component in four of five sessions).
This card is retained for what it uniquely shows — the shape of the ledger and the defects in it —
not as a cost oracle.

**Rate note — two further collector defects. The first is verified; the second was itself corrected under
verification.** (a) The tier regex
`opus-4-[6-9]` does not match `claude-opus-5`, so the model currently in use falls through to the
generic `opus` branch and is priced at $15/$75 instead of $5/$25 — a **3× overstatement**, confirmed
by running the hook's own jq predicate against the literal model string. The same class of miss hits
`claude-sonnet-5`, billed at Sonnet 4.6's $3/$15 rather than its own $2/$10. (b) The collector has a
single cache-write rate column, but **the TTL differs by tier**: main-loop transcripts are **99.59%**
1-hour (billed at **2× base input**) while subagent transcripts are 100% 5-minute (billed at
**1.25×**). *Corrected under verification.* This card originally claimed 100%/0% on both sides,
generalizing from a 12-session spot check. A full sweep of all 110 main-loop transcripts (22,054
usage records) found the main-loop side is 300,022,304 tokens 1-hour against 1,232,678 5-minute —
0.41% by volume, traced to two real non-sidechain `claude-opus-5` turns on 2026-08-31. The subagent
side held exactly: 1,205 files, 50,204 records, 324,885,942 tokens, 0 at 1-hour. The tier split is
still the right model and the pricing consequence is unchanged, but **"100%, verified in both cases"
was an overclaim from an incomplete sample** and is recorded here rather than quietly amended. A
blanket rate is wrong
in one direction for the main loop and the other for subagents; the fix must derive the rate per
record from the `ephemeral_1h_input_tokens` / `ephemeral_5m_input_tokens` split the transcripts
already carry. Figures below apply 2× to main-loop writes and 1.25× to subagent writes.

**The three defects do not compose into a correctable number.** Applied together across all 803
records: logged $92,711.92 → recomputed at correct rates $53,324.95 → after the ~1.9× dedup
correction roughly **$28,000**. The meter reads about **3× high**. A further inconsistency compounds
it: historical records were priced by whatever table shipped that day and never backfilled, so
`borg spend` sums figures computed under at least two different price lists. Treat every absolute
dollar on this card as an upper bound of unknown tightness.

1. **Context re-transmission is ~92% of main-loop spend, and cache READS are the single largest
   line item.** *(Corrected under review — this card previously had reads and writes inverted, taking
   the split from the double-counted ledger it documents below. Recomputed from deduplicated
   transcripts: reads 54.4%, writes 37.9%, output 7.7%.)* Ledger-derived figures follow, and are
   upper bounds: Recomputed at corrected rates: cache writes $11,921 (47%), cache reads $10,440
   (41%), output $2,821 (11%), fresh input $44 (0.2%). Main-loop total $25,225; subagents $5,807
   (their writes priced at the 5-minute 1.25× rate, not 2×); grand total $31,032 across the 588
   sessions — main 81%, subagents 19%.

2. **Re-read context outweighs generated text by 183× in tokens.** Main-loop cache reads total
   20,666,626,667 tokens against 112,803,436 output tokens across 588 sessions. Fresh input tokens
   (8,643,215) are 0.04% of cache reads — essentially everything the model reads, it has read before.

3. **Cache *writes* are 5.3% of cache token volume but 53% of cache cost.** At 1-hour TTL, cache
   creation is priced at 20× cache read ($10/M vs $0.50/M on Opus). Main-loop cache creation is
   1,164,908,589 tokens — a twentieth of the volume of cache reads, and the majority of the cache
   bill. Every prefix invalidation re-charges the *entire* prefix at that premium.

4. **Subagents are 23% of spend on these 588 sessions — but the split is a function of fan-out
   width, not a constant.** Main $25,225 (81%), subagents $5,807 (19%). Across the full 803-record
   ledger by stored cost it is 79%/21%. The `token-cost` skill's standing ~96%/4% claim is a
   single-session observation generalized into a rule; sessions with 0–3 subagents do run 98–100%
   main, while heavy fan-out sessions invert it (one 46-agent session ran 16% main). Monthly main
   share fell from ~85% (May–July) to 62% (August) as fan-out widened. **Both numbers are right
   under different conditions, and neither is a constant to design against.**

5. **The skill's stated *reason* for the 96/4 split is false on this machine.** It attributes the
   small subagent share to the harness routing subagents to cheaper tiers. In this ledger subagent
   spend is concentrated on the expensive tier — Opus subagents dominate Sonnet and Haiku subagents
   by roughly an order of magnitude. The routing assumption the claim rests on does not hold here.

6. **Delegation is dominated by the cost of *building* context, not reading it.** Subagent cache
   writes are $4,045 against $2,548 of cache reads and just $638 of output — the write side is 55%
   of all subagent spend. A short-lived subagent pays the 2× premium to construct a prefix and
   frequently does not live long enough to amortize it through reads. Delegation carries a fixed
   context-construction toll that the article never mentions, and it is the largest part of the
   delegation bill.

7. **Subagent model routing is the largest single lever inside delegation.** Corrected subagent cost
   by model: opus-5 $2,907, opus-4-8 $1,918, sonnet-5 $1,332, fable-5 $921, sonnet-4-6 $125,
   haiku-4-5 $30. Opus tiers account for 66% of subagent spend.

## Verified Quote(s)

Verbatim record from the file (**line 802** of 803 — the most recent `borg-collective` session. An
earlier revision mislabelled this as line 803, while its own `tail -3` locator below correctly
implied 802), whitespace
preserved as stored:

```
{"schema":2,"ts":"2026-08-31T15:02:48Z","session_id":"0dc0b9bf-ba6c-4611-92e9-84d763fef4df","project":"borg-collective","cwd":"/Users/noah/dev/borg-collective","end_reason":"other","main":{"by_model":{"claude-opus-5":{"input":612,"output":519836,"cache_creation":3498599,"cache_read":87547678}}
```

**Location reference:** `~/.claude/token-spend.jsonl`, final 3 records (`tail -3`), record 2 of 3.
Reproduce the aggregate with:

```
jq -s 'map(select(.schema==2)) | (map(.main.by_model // {} | to_entries) | add)
       | group_by(.key) | map({model: .[0].key, sessions: length,
         input: (map(.value.input)|add), output: (map(.value.output)|add),
         cache_creation: (map(.value.cache_creation)|add),
         cache_read: (map(.value.cache_read)|add)})' ~/.claude/token-spend.jsonl
```

**Access status:** `live`

## Inclusion Decision

**INCLUDE — load-bearing.** This is the only Level 1 source in the evidence base and the only one
measuring the actual system under decision. Every other source describes agent harnesses in general
or a vendor's benchmark of its own product. Where this source and a vendor benchmark disagree about
magnitude, this one governs for decisions about *this* machine.

Its limit is scope, and the limit is real: it establishes **where** the cost sits (the re-transmitted
context layer) and **not** how much of that cost is avoidable. A large cache-read bill is the
signature of a working cache as much as of a bloated context. Nothing here shows the context could
have been smaller without losing capability. That question needs per-turn, per-source attribution,
which this file does not carry — the gap that motivates the measurement recommendation rather than
one that undermines it.

**Perspective category:** `Boots-on-the-ground`
