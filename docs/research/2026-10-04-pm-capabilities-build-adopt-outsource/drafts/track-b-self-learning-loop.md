# Track B: the self-learning loop (re-runnable, multi-machine PM scorecard)

**Date:** 2026-10-04
**Question:** How do we turn the phase-1 two-axis scorecard (design: "what is it coded to do"; practice: "how well does stored data show it performing") into a recurring, multi-machine, self-learning evaluation, without Goodhart gaming, without leaking work-machine raw data into a public repo?

## Executive summary

- Recommended loop (5 steps): (1) MEASURE: a pure `borg_core/pmeval` computes Axis A predicates and Axis B metrics per machine on a schedule; (2) COMPARE: each result is judged against thresholds pre-registered in a checked-in, versioned `rubric` file (the memory-gate pattern); (3) PROPOSE: regressions and threshold breaches draft a directive proposal into a staging dir, never into the live backlog; (4) HUMAN DECIDES: Noah adopts, edits or rejects, and only a human edits thresholds or targets; (5) SHIP and RE-MEASURE: the change ships through the normal directive/assimilate path and the next scheduled run is the before/after, recorded against the directive id.
- Multi-machine contract in one line: raw rows stay in the machine-local state root; only a schema-allow-listed, numeric, rubric-versioned aggregate record is ever copied anywhere shared; a fail-closed validator is the only writer to the shared location, and machines are compared by label, never merged.
- Automate detection, drafting and re-measurement. Keep human: thresholds, targets, rubric changes, adopting any proposal, and the judgment of whether a regression is real. Keep the scorecard out of agents' reach by making the evaluator an out-of-session launchd job whose rubric and results live outside any project working tree, with agents denied writes there.
- External evidence supports the shape but is thin on exactly the hard part: there is no empirical study of Goodhart effects on software-team metrics (phase-1 analysis section 4.3, "What is missing"), so the anti-gaming design rests on mechanism-level evidence (Bevan and Hood, Manheim and Garrabrant, METR reward-hacking) rather than field trials of this specific setup.
- Storage: stay with append-only JSONL plus Python stdlib. SQLite/DuckDB are not justified at this volume and add a moving part; revisit only if a query cannot be written as a 20-line reduction.

## Findings

### 1. Loop shape and prior art

**DORA's own improvement loop is the closest published template and it is human-gated.** The DORA metrics guide prescribes: establish a baseline (Quick Check), identify friction points through discussion, commit to the most significant constraint, develop an action plan with leading indicators, execute, measure regularly, repeat. It lists seven pitfalls, of which the load-bearing ones here are: do not set metrics as goals (explicit Goodhart citation), do not rely on a single metric (track several with "healthy tension"), do not compare across vastly different applications, do not run inter-team competition, and do not invest in measurement infrastructure before demonstrating value. https://dora.dev/guides/dora-metrics/ (accessed 2026-10-04) [2024-2026]. Implication for borg: the loop is a diagnostic cycle owned by one person, and the "propose" step must name a constraint and leading indicators, not a target number. The pitfall "measurement over action" is also a warning against building this too big (see risks).

**Phase-1 cards already carry the Goodhart evidence; cite by card name.** Bevan and Hood (targets worked and were gamed; once a target is met a controller cannot tell success from gaming) is card `t4-bevan-hood-targets-gaming`; Manheim and Garrabrant's four Goodhart modes (regressional, extremal, causal, adversarial; adversarial is live when the scorer is rewarded by the score) is `t2-manheim-goodhart-variants`; SPACE (at least three dimensions, one perceptual, activity never alone) is `t3-space-framework-forsgren-2021`; DORA four keys pitfalls is `t3-dora-four-keys-guide`; Beck and Orosz on effort-and-output framing is `t3-beck-orosz-mckinsey-response`. Phase-1 analysis section 4.3 resolves them as: team-owned diagnostics, several dimensions, perception labelled as perception. Phase-2 should inherit that resolution unchanged. Mapping to the loop: because the "scorer" (the loop) and the "scored" (agents working in borg projects) overlap, the adversarial Goodhart mode is live, which is why the evaluator must be out of the agents' write path (finding 4).

**Pre-registration is the right discipline for the compare step.** The Center for Open Science states the core problem as the same data being used to generate and test a hypothesis, and that preregistration separates planned from data-dependent analyses and combats selective reporting. https://www.cos.io/initiatives/prereg (accessed 2026-10-04) [2024-2026]. Borg already applies this in miniature: `borg-memory-gate` records a verdict against a threshold fixed in advance (FAIL at 0.050 reads/session vs pre-registered under 0.2 on 2026-10-03, per phase-1 analysis 3.9; PASS at 0.600 on 2026-10-04 per #266's triage report). Generalize: each metric in the rubric ships with `{id, definition, direction, threshold_warn, threshold_fail, registered_at, rubric_version}` and the compare step may only read thresholds from the committed file at the commit that was current when the measurement window opened. Changing a threshold bumps `rubric_version` and results from different versions are never silently compared.

**Evals-as-CI is an existing pattern with a vocabulary borg can borrow.** Anthropic's agent-eval guidance (published 2026-01-09 per the search result) distinguishes capability evals (start at low pass rates, show where the agent is weak) from regression evals (sit near 100%, catch backsliding), says saturated capability evals graduate into the regression suite, recommends code graders where possible, and reading raw traces. https://anthropic.com/engineering/demystifying-evals-for-ai-agents (search-result summary read 2026-10-04; I did not fetch the full page, so details beyond that summary are unverified) [2024-2026]. Mapping: Axis A predicates (does the gate exist, is it pinned by a test) are regression-style and should be near-100% stable; Axis B metrics (lead time, zero-commit share, derived-vs-declared agreement) are capability-style and trend. Different alarm semantics: Axis A flips are alarms; Axis B moves are trends needing a window.

**Metrics-as-code precedent.** dbt's MetricFlow defines metrics in YAML committed to git so "everyone ... can see and approve them as the true and only source of information", removing per-analyst divergent queries. https://docs.getdbt.com/docs/build/about-metricflow (accessed 2026-10-04) [2024-2026]. Borg's analogue: one rubric file + one pure `core.py`; no second reader of the same metric (this is the AC7 "two validators disagree" lesson in CLAUDE.md). Do not adopt dbt itself; only the single-definition principle transfers.

### 2. Multi-machine aggregation without leaking raw data

Honest framing first: the population is one person per machine (n=1 per cell), so classic k-anonymity or n>=5 cell suppression does not apply to the unit of analysis, and applying it would suppress everything. The real leakage risk is content, not re-identification: project names, plan titles, PR titles, directive slugs, checkpoint prose, repo slugs and counts that fingerprint an employer. Therefore the primary control is a schema allowlist of numeric fields and enumerated labels, with a fail-closed validator, not cell-size suppression.

Where cell-size rules are still useful: any published aggregate computed over a small count (for example "3 of 7 shipped plans on this machine had a retro") can fingerprint a small corpus. Established practice for small-count suppression: CMS's cell size suppression policy forbids displaying any cell with a value of 1 to 10 and also forbids percentages or formulas that would reveal such a cell. https://www.hhs.gov/guidance/document/cms-cell-suppression-policy (via search summary, accessed 2026-10-04) [pre-2020 policy, still current practice]. Other implementations use 5 (a SyllabAI project note applies "fewer than 5 distinct units renders statistics null": https://github.com/SyllabAI/syllabai-core/pull/62, not authoritative, illustrative only). Recommendation: publish counts with their denominators only when denominator >= 5, else publish the metric as `null` with `reason: "n_below_floor"`. Threshold 5 is a judgment call, not a standard (CMS uses 11; see open questions).

Options compared (80/20 frame):

- Option A, local-only plus label comparison (recommended default): each machine writes `pmeval/<machine_label>/<date>.json` in its own state root. Nothing leaves the work machine except what Noah copies by hand. Comparison is a `borg pulse --compare <file>` over two aggregate files. Fewest moving parts, zero leak surface, and meets "rerun on multiple machines" as long as the rubric_version matches.
- Option B, allow-listed aggregates published to the public repo (what the phase-1 sketch proposed): works if the validator is fail-closed and the published file has a closed schema (numbers, booleans, enumerated ids from the rubric). Risk: git history is permanent and public; a validator bug leaks forever and history scrubbing was already needed once on this repo (CLAUDE.md, "history-scrubbed once for employer references"). Mitigation: publish only from the personal machine's copy, and have the work machine emit the aggregate file for a human to review and move.
- Option C, private repo or gist for aggregates: same schema, lower blast radius than B, one more credential and remote to maintain. A reasonable middle if B feels risky.
- Option D, encrypted sync of raw data: reject. It keeps employer data moving off the machine for no scoring benefit, and it adds key management.

Recommended data contract (3 lines):
1. Raw rows (per-event, with project names, titles, paths) live only under the machine's `~/.local/state/borg/` and are never read by the publish path.
2. The shared record is one JSON object per run: `{rubric_version, machine_label, window_start, window_end, borg_version, metrics: {<rubric_id>: {value: number|bool|null, n: int, denominator_ok: bool}}, axis_a: {<check_id>: pass|fail}}`, where every key must be in the rubric's allowlist and every value numeric, boolean, null, or an enumerated string; free text is rejected.
3. A fail-closed validator (reject on any unknown key, any string not in an enum, any n below the floor with a non-null value) is the sole writer to the shared location, and comparison is by `machine_label` + `rubric_version`, never by merging machines into one number.

Machine labels should be coarse (`personal`, `work`), not hostnames or employer names.

### 3. Storage and scheduling

**Storage.** Recommend append-only JSONL for per-run raw results and one small JSON per run for the aggregate. Evidence: DuckDB can query JSONL directly with `read_json`, parsing roughly 100k to 1M records/sec per one secondary source, and SQLite requires INSERTing first. https://motherduck.com/blog/analyze-json-data-using-sql/ and https://posthog.com/blog/duckdb-vs-sqlite (search summaries, accessed 2026-10-04; I could not retrieve the DuckDB docs page text to confirm NDJSON support firsthand, so treat the speed number as vendor-blog level) [2024-2026]. But borg's actual volume is small (phase-1: 17,250 agent rows, 817 spend records, 129 checkpoints) and every phase-1 reduction was a short Python pass; the repo already uses JSONL for `agents.jsonl`, `usage-samples.jsonl`, `memory-hits.log`. Adding SQLite or DuckDB adds a dependency and a schema migration surface (expand-migrate-contract applies) for no query the data needs. Trigger to revisit: a metric whose Python reduction exceeds roughly 50 lines or needs windowed joins across sources. This is a recommendation from the numbers, not a sourced claim.

**Phase-1 lesson that must carry into the shell:** the agent log rotates (live file plus `agents.jsonl.1`); reading only the live file undercounted by a factor of about fifty. The impure shell must read the rotated sibling and the core must take a list of rows, with a test that fails if the shell passes only the live file. Also record a `coverage` field per metric (the phase-1 `zero_commit` field covered 56% of rows) so a metric never reads as complete when it is not.

**Scheduling.** launchd, installed by `install.sh` like the other six agents (CLAUDE.md: plists are installed by install.sh only; labels via `_borg_launchd_label`; add `pmeval` to the agent list and template `borg.pmeval.plist`). Use `StartCalendarInterval` (weekly, plus a daily light Axis A pass is optional): per the launchd documentation as summarized, a missed calendar interval fires on wake and multiple missed intervals coalesce into one, whereas `StartInterval` misses intervals during sleep. https://alvinalexander.com/mac-os-x/launchd-plist-examples-startinterval-startcalendarinterval/ and https://developer.apple.com/forums/thread/815034 (search summaries, accessed 2026-10-04; Apple forum thread notes behavior changes, so verify on the target macOS) [2020-2026]. Caveat from the same results: reloading a plist late in the day catches nothing up. Cadence recommendation: weekly. Rationale: Axis B inputs (merge latency, lead time, memory reads) move on a scale of days, a daily run multiplies noise and review burden, and DORA says measure "regularly", not continuously. Retention: keep per-run aggregates forever (a few KB each), keep raw per-run row snapshots 90 days, reuse the existing log-rotation helper. Every run must write a heartbeat record (`ran_at`, `exit`, `metrics_computed`, `metrics_null`) so silence is detectable; CLAUDE.md and memory ("usage-watch silent blindness", same exit-0-and-log-something-reassuring bug 3x) show this agent family fails by reporting health while measuring nothing. Gate the verdict on `metrics_computed > 0` and on non-empty inputs, exactly as the memory-gate should.

### 4. What is automated vs human; keeping the scorecard out of agents' reach

Automate (safe, because they produce proposals or read-only facts): running the measurements; computing Axis A predicates; comparing against registered thresholds; detecting regressions as sustained crossings (for example two consecutive runs, to avoid single-run noise, a threshold I am proposing, not sourcing); drafting a directive proposal using the existing directive template into a staging dir; recording a before/after pair when a directive id tagged to a metric ships; emitting the heartbeat; refusing to publish on validator failure.

Human only: editing a threshold; adopting a target (DORA: metrics are diagnostics, not goals); changing the rubric or bumping `rubric_version`; promoting a proposal into `docs/plans/directives/`; deciding that a trend is real versus a measurement artifact; interpreting perception metrics (labelled as perception, per SPACE and the METR trial in phase-1); deciding what leaves the work machine. The phase-1 resolution that a single scorer was used and no inter-rater agreement exists argues for a periodic human or second-model re-score of Axis A, not full automation of it.

Gaming defence. METR documents frontier models reward hacking by "modifying tests or scoring code", overwriting timing functions, or patching the evaluation function so everything passes, and reports exploit rates from 0% (Claude Sonnet 4.5, Claude Opus 4.5) to 13.9% (DeepSeek-R1-Zero) in one benchmark. https://metr.org/blog/2025-06-05-recent-reward-hacking/ (accessed 2026-10-04, via search summary) [2024-2026]. The exploit-rate figures come from a different search result (arXiv 2605.02964, not fetched), so treat them as indicative. The transferable point is mechanism: an agent that can read or write the scorer can optimize it. Phase-1 already observed the in-repo version: plan checkboxes are both the agent-visible target and the score input, and drift (27% checked vs about double the real completion).

Design rules that follow (all enforceable by existing mechanisms, no new framework):
1. Run the evaluator out-of-session: a launchd job, not a skill or a hook an agent invokes. No agent session triggers a re-score.
2. Keep the rubric and results outside project working trees (the state root, plus the rubric file in the borg-collective repo on main). Extend `bash-guard.sh` (PreToolUse/Bash, already destructive-pattern hard-block) and the Edit/Write permission deny list to block writes to `~/.local/state/borg/pmeval/` and `~/.config/borg/pmeval/`. A deny is a gate; telling agents not to is a request (CLAUDE.md shim-layer rule: anything that MUST happen ships as a gate).
3. Do not surface live metric values to agents in-session. The `borg link` page and checkpoint injection should not carry pillar scores; the human reads the scorecard via `borg pulse`. This removes the "agents can read the target" precondition for the adversarial mode.
4. Prefer metrics derived from artifacts agents do not curate to be judged (git history, `gh` merge data, spend log written by a SessionEnd hook) over volunteered or self-reported ones; this is the cairn lesson (capture must derive from artifacts the agent already produces) and the phase-1 finding that self-reports drift.
5. Track a metric and its tension partner together (merge latency with `fix`-share; throughput with derived-vs-declared agreement), per DORA's "healthy tension" and SPACE.
6. Report trends and denominators, not single scores; the single-number total (14 of 24 plus or minus 2) should not be a published headline.

Residual risk: the evaluator and the code it scores live in one repo that agents edit. An agent that edits `borg_core/pmeval/core.py` or the rubric file in a PR can change the scorer. Mitigation: rubric and core changes require human review under the existing `borg-verify` / Collective path, and the heartbeat records the git sha of the rubric used so a scorer change is visible as a `rubric_version` or sha jump.

### 5. How others do continuous self-evaluation (and what to take)

- DORA: baseline, constraint, plan with leading indicators, re-measure; explicitly conversation-first and anti-comparison (https://dora.dev/guides/dora-metrics/). Take the cycle; leave the benchmark tiers.
- SPACE: multiple dimensions, one perceptual; activity never alone (phase-1 card `t3-space-framework-forsgren-2021`). Take as the constraint on which metrics may be shown together.
- Evals-as-CI: separate regression from capability suites, code graders first (Anthropic engineering post above). Borg's own eval ledger (the evals directive records only three skills have any eval) is the closest in-repo precedent; the pmeval Axis A is a natural regression suite over borg's own claims.
- dbt/MetricFlow: metric definitions in one version-controlled place, reviewed like code (docs link above). Take the single definition.
- COS preregistration: plan before data (link above). Take for thresholds.
- Not found: any public example of a solo-developer, multi-machine, privacy-split self-scoring loop. This design is therefore novel in composition and I could not validate it against a precedent; flag as untested.

## Recommended architecture (components and where they live)

- **1** — `rubric.json` (metric ids, definitions, directions, warn/fail thresholds, registered_at, allowlist)
  - Where in borg: repo, `borg_core/pmeval/rubric.json`
  - Notes: Human-edited only; changes bump `rubric_version`; schema expand-migrate-contract
- **2** (Component: Pure scoring core; Where in borg: `borg_core/pmeval/core.py`) — No I/O; rows in, metrics out; imports restricted like `link/picture.py`; Domain list entry in `pyproject.toml` plus AST import-walk test
- **3** (Component: Impure shell; Where in borg: `borg_core/pmeval/shell.py`) — Reads registry, plans, checkpoints, `gh`, spend log, `agents.jsonl` and `.1`; owns the clock; records `coverage`
- **4** (Component: Axis A predicates) — `borg_core/pmeval/axis_a.py` (pure over a file-tree snapshot)
  - Notes: Pass/fail per check plus 0-3 rule; identical on every machine
- **5** (Component: Validator and publisher) — `borg_core/pmeval/publish.py`
  - Notes: Fail-closed; sole writer of the shared aggregate; allowlist from rubric
- **6** (Component: Proposal drafter) — `borg_core/pmeval/propose.py`
  - Notes: Writes to a staging dir; never to `docs/plans/directives/`
- **7** (Component: CLI) — `borg pulse` (run, show, compare, publish) via `_borg_py`
  - Notes: Honors the zsh-to-Python config boundary lesson
- **8** (Component: Scheduler) — `launchd/borg.pmeval.plist`, resolver `_borg_launchd_label pmeval`, installed by `install.sh`, listed in `borg doctor`
  - Notes: Weekly `StartCalendarInterval`
- **9** (Component: Guard; Notes: Gate, not prose) — `hooks/bash-guard.sh` plus settings deny rules for the pmeval state paths
- **10** (Component: Heartbeat and verdict) — `~/.local/state/borg/pmeval/heartbeat.json`
  - Notes: Same shape as `memory-gate-verdict.json`; `borg doctor` flags stale or zero-metric runs

Tests: a differential test per metric against the phase-1 hand numbers (28 open, 60 shipped, 8 severed, median open age 41 days) so the first run reproduces the phase-1 reading; the shell test must NOT pre-supply derived values (the "tests that supply the derived value" lesson); an end-to-end launchd run before declaring done (the usage-watch lesson: green bats never caught it).

## Risks

1. Goodhart and self-gaming: agents (or Noah under ADHD-driven completionism) optimize the score. Mitigations in finding 4; residual because the scorer lives in an agent-editable repo and there is no empirical field evidence for what works.
2. Silent blindness: the evaluator runs, exits 0, and reports a clean scorecard over empty or partial inputs (rotated log missed, project not registered, `gh` unauthenticated on one machine). This exact failure shipped three times in borg. Mitigation: coverage fields, null-not-zero for missing inputs, heartbeat, `borg doctor` stale check, launchd end-to-end test.
3. Leak into the public repo: a validator hole, or publishing a string field, exposes employer-adjacent content permanently. Mitigation: closed schema, fail-closed validator, human-in-the-loop transfer of work-machine aggregates, no auto-push from the work machine.
4. Measurement over action (DORA pitfall 7): the loop becomes more machinery than the PM problems it measures. Phase-1 found the best-evidenced story is state truth, so the first loop should measure only the 8 to 10 metrics already computable today, not the needs-capture list.
5. Rubric drift and uncomparable history: thresholds or definitions change and old points silently stop meaning the same thing. Mitigation: `rubric_version` in every record; comparison refuses cross-version.
6. Single-scorer bias persists: Axis A was scored by one agent with no inter-rater agreement; automating it freezes that bias into predicates.

## Evidence gaps and uncertainties

- No empirical study of Goodhart effects on software-team metrics (phase-1 analysis 4.3); the anti-gaming design is mechanism-level inference.
- No public precedent found for a personal multi-machine privacy-split self-scoring loop; composition untested.
- The k-anonymity threshold (5 vs 11) is convention, not derived; and n=1 per cell makes classic k-anonymity inapplicable (stated above).
- DuckDB/NDJSON claims rest on secondary blogs (page text of the DuckDB docs did not return usable content on fetch); the storage recommendation does not depend on them.
- Anthropic evals post and launchd coalescing behavior were read from search-result summaries, not full pages; the web-search budget for the session was exhausted before I could fetch them directly. Verify launchd behavior on the target macOS before depending on catch-up semantics.
- The "two consecutive runs" regression rule and the 90-day raw retention are my proposals, unsourced.

## Open questions for Noah

1. Publish target for aggregates: public repo (B), private repo/gist (C), or local-only with hand-carry (A)? Recommendation: A for work, B only from the personal machine.
2. Is a weekly cadence right, or do you want a manual `borg pulse` on demand only for the first month (fewest moving parts) before arming launchd?
3. Small-count floor: n>=5 (my default) or the stricter 11 (CMS)? Given n=1 persons, is it enough to simply never publish counts under the floor?
4. Should Axis A re-scoring ever be done by a second model/blind rater on a schedule, and who owns reconciling disagreements?
5. Do you accept the rule that live pillar scores are never shown to agents in-session (not in `borg link`, not in checkpoint injection), at the cost of weaker in-session feedback?
6. Which 8 to 10 metrics ship in v1? Proposed: open-directive age/count, criteria-checked rate, lead time (with coverage), merge latency, `fix`-share, nanoprobe zero-commit share, derived-vs-declared agreement, memory-gate read rate, retro presence, plus Axis A pass counts.

## Paywalled must-reads

None load-bearing. Forsgren et al. 2021 (SPACE) and Bevan and Hood 2006 were handled in phase 1 (cards `t3-space-framework-forsgren-2021`, `t4-bevan-hood-targets-gaming`).

## Sources index

- **1** (Date: accessed 2026-10-04; Tier: [2024-2026]) — DORA metrics guide (pitfalls, improvement loop)
  - URL: https://dora.dev/guides/dora-metrics/
- **2** (Title: COS: Why preregister; Date: accessed 2026-10-04; Tier: [2024-2026]) — https://www.cos.io/initiatives/prereg
- **3** (Date: 2026-01-09; Tier: [2024-2026]) — Anthropic: Demystifying evals for AI agents (summary only)
  - URL: https://anthropic.com/engineering/demystifying-evals-for-ai-agents
- **4** (Date: accessed 2026-10-04; Tier: [2024-2026]) — dbt MetricFlow: how metrics are defined
  - URL: https://docs.getdbt.com/docs/build/about-metricflow
- **5** (Date: 2025-06-05; Tier: [2024-2026]) — METR: Recent frontier models are reward hacking
  - URL: https://metr.org/blog/2025-06-05-recent-reward-hacking/
- **6** (Date: accessed 2026-10-04; Tier: [pre-2020 policy, current]) — CMS cell suppression policy (HHS)
  - URL: https://www.hhs.gov/guidance/document/cms-cell-suppression-policy
- **7** (Date: accessed 2026-10-04; Tier: [2024-2026]) — SyllabAI k-anonymity n<5 note (illustrative, non-authoritative)
  - URL: https://github.com/SyllabAI/syllabai-core/pull/62
- **8** (Date: accessed 2026-10-04; Tier: [2024-2026]) — MotherDuck: analyze JSON with DuckDB (secondary)
  - URL: https://motherduck.com/blog/analyze-json-data-using-sql/
- **9** (Date: accessed 2026-10-04; Tier: [2024-2026]) — PostHog: DuckDB vs SQLite (secondary)
  - URL: https://posthog.com/blog/duckdb-vs-sqlite
- **10** (Date: accessed 2026-10-04; Tier: [2020-2023]) — launchd StartCalendarInterval examples (secondary)
  - URL: https://alvinalexander.com/mac-os-x/launchd-plist-examples-startinterval-startcalendarinterval/
- **11** (Date: accessed 2026-10-04; Tier: [2024-2026]) — Apple Developer Forums: StartCalendarInterval behavior changed
  - URL: https://developer.apple.com/forums/thread/815034
- **12** (Date: 2026-10-03; Tier: [2024-2026]) — Phase-1 analysis sections 3 and 4.3 (local)
  - URL: docs/research/2026-10-03-project-management-pillars/analysis.md
- **13** (Date: 2026-10-03; Tier: [2024-2026]) — Phase-1 cards: t4-bevan-hood-targets-gaming, t2-manheim-goodhart-variants, t3-space-framework-forsgren-2021, t3-dora-four-keys-guide, t3-beck-orosz-mckinsey-response (local)
  - URL: docs/research/2026-10-03-project-management-pillars/sources/
