# Source Card: Per-Turn Transcript Forensics (8 sessions, 2 projects)

**Full citation:** Goodrich, N. (2026). Claude Code session transcripts,
`~/.claude/projects/-Users-noah-dev-{borg-collective,ingle}/*.jsonl`. Eight largest transcripts by
file size (3,408 deduplicated assistant turns total) analyzed for per-turn context prefix size and
cache-write concentration, 2026-09-03.

**URL:** `file:///Users/noah/.claude/projects/` (local; not published)

**Date accessed:** 2026-09-03

**Evidence level:** Level 1 — direct observation. Per-turn `message.usage` blocks returned by the
Anthropic API and written verbatim to the transcript by the harness.

**Research topic area:** T2 — Within a session, *when* is context cost incurred?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|---|---|---|
| 1 | Authority | 5/5 | API-returned billing counters, recorded by the harness, not model self-report. |
| 2 | Methodology | 4/5 | Deduplicated by `message.id` before aggregating — streaming emits the same `usage` block on every chunk, and skipping this step inflates counts ~2×. Verified no sidechain turns are present, so main-loop and subagent costs are not conflated. Loses a point: "big write" is a chosen 20,000-token threshold, not a harness-emitted event flag. |
| 3 | Recency | 5/5 | Sessions from 2026-08-10 through 2026-08-31. |
| 4 | Corroboration | 5/5 | The pattern reproduces in all 8 sessions across 2 unrelated projects, with concentration between 69% and 94%. Session totals also reconcile with the independently-written `token-spend.jsonl` aggregate. |
| 5 | Bias | 5/5 | Bias guard applied — scored HARDER. Counters are mechanical; the analyst chose which sessions to read (the 8 largest), which is stated rather than hidden. |
| 6 | Logic | 4/5 | Scored HARDER (agreement). Causation is now established by dose-response rather than asserted (Key Finding 4), and the first, wrong causal reading is recorded rather than quietly replaced. Held below 5 because a residual minority of re-writes still has no confirmed mechanism (Key Finding 5). |
| 7 | Transparency | 5/5 | Reproducible from the `jq` pipeline below against files on disk. |
| 8 | Intellectual honesty | 4/5 | Scored HARDER (agreement). The counterfactual is stated as unreachable rather than quietly used as a savings estimate. |
| 9 | Relevance | 5/5 | Directly measures the mechanism the design must target. |
| 10 | Sample size | 4/5 | 3,408 turns is ample for the per-turn distribution; 8 sessions is thin for cross-session generalization, and both projects belong to one user with one working style. |

**Score band:** `keep`

**Bias Guard Check:** [x] I AGREE with this source's implication → dimensions 5, 6, and 8 scored
HARDER. Dimension 6 was reduced to 3/5 specifically because the attractive causal story (compaction
and resumes cause the spikes) was *not* demonstrated.

## Key Findings

1. **The working context is 270k–552k tokens, not the tens of thousands the article implies.**
   Mean prefix per turn across the 8 sessions: 429k, 552k, 468k, 384k, 317k, 270k, 362k, 381k.
   Peak prefix reached 965,016 tokens — 97% of the 1M window. Every one of the article's three
   habits operates on top of this baseline, and none of them is sized to move a 400k prefix.

2. **Cache-write cost is extremely concentrated: 5–29 turns per session carry 69–94% of all
   cache-write tokens.** Median concentration 85%. In the largest session, 15 turns out of 612
   (2.4%) accounted for 69% of cache-write tokens (2,435,885 of 3,484,446).

3. **The signature of these events is a prefix miss, not a large append.** On every spike, cache
   *read* collapses to a small fixed value (28,964 or 36,544 tokens — the stable system-prompt block)
   while cache *write* jumps to 100k–441k. The conversation prefix stopped matching and was rebuilt
   from scratch; only the system prompt survived in cache.

4. **The cause is IDLE TIME — the 1-hour cache TTL expiring — not compaction.** Bucketing all 2,555
   pooled turns by wall-clock gap since the previous turn gives a clean monotonic dose-response in
   the rate of full prefix re-writes:

   | gap since previous turn | turns | full re-writes | rate |
   |---|---|---|---|
   | < 1 min | 2,241 | 4 | 0.18% |
   | 1–5 min | 175 | 6 | 3.4% |
   | 5–30 min | 73 | 8 | 11.0% |
   | 30–60 min | 13 | 2 | 15.4% |
   | **> 60 min** | **41** | **39** | **95.1%** |

   **Turns following a >60-minute gap account for 63.2% of all cache-write tokens** (19,834,187 of
   31,376,540 pooled). Four of the five sessions show a 100% re-write rate after a >60-minute gap.
   This matches the 1-hour TTL exactly: walk away for an hour, come back, and the entire conversation
   is re-written at 20× the read rate.

   *This finding corrects an earlier reading in this same analysis.* Sorting spikes by write size and
   eyeballing the gap column suggested "no monotonic relationship," and compaction was proposed as
   the likely cause. That was an artifact of the wrong summary: the correct analysis computes the
   re-write *rate per gap bucket*, not the gap of the largest writes. Compaction is in fact almost
   absent — exactly **one** compaction event occurred across 2,555 turns (session e053704a turn 414,
   prefix collapsing 937,399 → 117,935 tokens). The other four sessions never compacted; they ran the
   prefix to 521k–969k tokens and simply ended.

5. **A small minority of re-writes remain unexplained.** Roughly 5 of 27 in one session fire
   mid-flow after a <1-minute gap with no context shrink — e.g. turn 445 read 764,405 tokens, turn
   446 read only 26,521 and wrote 740,846, turn 447 read 767,367 (= 26,521 + 740,846 exactly). These
   coincide with a new top-level user turn injected by a background task notification. Mechanism
   unconfirmed; plausibly a cache-shard miss or turn-boundary re-anchor. Not TTL, and not compaction.

6. **The spend collector over-counts by ~2×, unevenly, because it does not deduplicate by request.**
   Claude Code writes one transcript record per *content block*, each stamped with the same
   `requestId` and the same full `message.usage`. Summing per record therefore multiplies every
   counter by the blocks-per-request factor. For session e053704a: 1,300 records but only 612 unique
   requests; the collector stored `cache_read` 567,704,618 and `output` 1,664,883 against deduped
   truth of 262,840,263 and 634,229 — **2.16× and 2.63×**. Because the inflation factor differs per
   component, it cannot be corrected with a single multiplier, and it distorts component *shares* as
   well as totals. The defect is in `token-spend-log.sh`'s `_bymodel` function, which groups by model
   with no unique-by-`requestId` step.

7. **Priced from deduped counts, context is 91–96% of session cost and output is 3.4–8.7%.**
   Per session (read / write / output): e053704a $109.29 (72.2% / 19.1% / 8.7%); 9efa4c28 $660.74
   (49.8% / 46.8% / 3.4%); d44653c3 $118.48 (73.2% / 19.3% / 7.5%); 50981231 $204.62 (62.5% / 32.1%
   / 5.4%); 8aa0e0bb $84.01 (61.6% / 30.7% / 7.6%). Cache *reads* are the largest component in four
   of five sessions; the outlier is the session with the highest re-write concentration (94%).

8. **Pooled cache reads are 519× pooled output tokens** (1,136,008,832 vs 2,187,630). Pooled mean
   context re-read on every API call: **444,622 tokens**.

9. **Sidechain turns are absent from the main transcript** (`isSidechain` false on all 612 turns of
   the largest session). Subagent cost lands in separate files, so main-loop figures here are
   uncontaminated by delegation.

## Verified Quote(s)

Verbatim records from the largest session, the three biggest cache-write turns, showing the
read-collapse/write-spike signature (fields extracted from `message.usage`, values unmodified):

```
gap_before=1054s  cache_write=441426  cache_read=36544
gap_before=4253s  cache_write=380461  cache_read=28964
gap_before=15016s cache_write=359384  cache_read=28964
```

**Location reference:**
`~/.claude/projects/-Users-noah-dev-borg-collective/e053704a-cfc9-42be-939e-525475153822.jsonl`,
assistant turns deduplicated by `message.id`, sorted by timestamp, filtered to
`cache_creation_input_tokens > 20000`, sorted descending — top 3 rows. Reproduce with:

```
jq -s 'map(select(.type=="assistant" and .message.usage != null and .message.id != null))
       | group_by(.message.id) | map(.[0]) | sort_by(.timestamp)
       | map({cw: .message.usage.cache_creation_input_tokens,
              cr: .message.usage.cache_read_input_tokens})
       | map(select(.cw > 20000)) | sort_by(-.cw)' <transcript>.jsonl
```

**Access status:** `live`

## Inclusion Decision

**INCLUDE — load-bearing, and it redirects the recommendation twice over.**

First, it establishes that the addressable cache-write cost is concentrated in a handful of events
per session rather than spread across a bloated per-turn payload, and then names their cause: the
1-hour cache TTL expiring across an idle gap. That makes the largest identified waste a **session
lifecycle** problem — when the user walks away and returns — not a payload-trimming problem. None of
the article's three habits addresses it.

Second, Key Finding 6 disqualifies the existing measurement layer from answering the question it was
built for. `token-spend.jsonl` is inflated ~2× unevenly, and combined with two independently verified
rate errors in the same collector, no figure it reports can be trusted without recomputation from
transcripts. That is not a footnote — it means "measure before cutting" has to start with repairing
the instrument.

The honest limit remains: a prefix must be written once before it can be read, so the counterfactual
"if those tokens had been reads" is not fully achievable, and this data cannot bound how much of the
1.16B cache-write tokens was strictly necessary. It sizes the target and names the mechanism; it does
not promise a saving.

**Perspective category:** `Boots-on-the-ground`
