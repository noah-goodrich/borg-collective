Generated: 2026-10-30

**Design review: REVISE twice, revisions applied, the final revision was not re-reviewed.** **Citation check: not passed, low-confidence on quote form** (see `verification-report.md`).

# Recommendation: better evals and hillclimbing, for Claude Code and Cortex Code

AI-scoring: 89/100 (article mode, scored by hand against the ai-scoring rubric: staccato -3, parallel structure -6, repeated openings -2; no banned words or em dashes by mechanical search). The noah-voice pass was not run, because the design-doc skill records that voice as a poor fit for scanned decision documents.

## In plain words

borg has a small test program for its skills and agents. It catches one known bug coming back, but it covers 5 of 22 items, it never checks whether a skill fires at the right moment, and nothing improves a skill automatically. On the day this research ran we also found that the live half of the program could not pass any more, because the skills now call `borg` and the test sandbox had no `borg` in it, and nobody noticed, because the only part that runs on every change is the offline half. The research says: do not buy an evaluation platform, do not try to improve whole skill bodies with only a handful of test cases, and do start by making the live tests honest, recorded and scheduled. After that, test when each skill fires, using 20 or more labeled requests per skill, and improve only the one-line descriptions, one careful rewrite at a time. Cortex Code gets the same cases through a small runner, and nothing runs on the employer's Snowflake account without the owner saying so.

## Glossary

- **Eval**: a test for an AI behavior. You run the AI and check what it did.
- **Tier 1, 2, 3**: the three kinds of test. Tier 1 is a script with no model. Tier 2 runs the AI and checks the result with a script. Tier 3 runs the AI and asks another model to judge.
- **Hillclimbing**: trying small changes to a prompt or description and keeping the ones that score better, step by step.
- **Trigger**: whether a skill starts when it should, and stays quiet when it should not.
- **Near-miss**: a request that sounds like it belongs to a skill but does not. It is the most useful kind of "should not fire" case.
- **Held-out set**: test cases the improver never sees, so it cannot learn the answers.
- **Saturated**: a case that always passes. It still guards against regressions but cannot show improvement.
- **Wilson interval**: an honest error range for a pass rate when you have few runs.
- **Paired comparison**: comparing two versions on the very same cases, instead of comparing two overall scores.
- **Pareto view**: showing accuracy and token cost side by side, not blended into one number.
- **CoCo or Cortex Code**: Snowflake's command-line coding agent.

## 1. Recommendation

Take **Option A**, a platform-native core with a thin Cortex runner, in this order. Each step is worth doing even if the later ones never happen.

0. **Sort the skills first.** Mark which of the 16 skills are meant to fire on their own and which are only ever typed as slash commands. A slash-command-only skill can be hidden from the model's listing (`disable-model-invocation: true` in Claude Code, which removes it from context entirely), which saves tokens with certainty and needs no trigger test. Fix overlapping scopes before measuring anything: link, recon and next overlap, and so do review, collective-review, fable-reviewer and verify. The one study of description rewrites found overlapping scopes are fixed by restructuring, not by rewording. Cortex ignores the field, so Cortex keeps today's behavior.
1. **Make the live evals trustworthy, recorded and scheduled.** The lifecycle harness now tests the build under review and keeps every run's result. Add one JSONL record per run (git SHA, model id, cost, turns, tokens, verdict) and a short stdlib script for Wilson intervals and per-SHA trends. Run a weekly live sweep on the personal machine under launchd with a pinned model, a per-case cap and a total cap, and raise a visible notice when a case skips or errors for an environmental cause. In the same step add a Cortex load check for every skill and agent: use a real load command if one exists without a model call, otherwise a lint for folded `description: >` blocks (all 16 skills use that form today, and `borg setup` discards `cortex skill add` errors). Do not discard those errors any more.
2. **Declare each harness's tier in `evals/ledger.json`**, in three moves: accept an optional `tiers` field, fill the five entries, then require it. An offline test enforces it.
3. **Write the evals for the 17 waived items** before their waivers expire (5 on 2026-12-15, 12 on 2027-01-31), each with a known-good and a known-bad transcript. The ledger itself says three items have no observable output or need a judge. For those, allow an `llm` grader with a calibrated rubric, or renew the waiver with that reason on record.
4. **Trigger suites for the self-firing skills only**: 20 or more labeled requests each, about half should-fire and the rest near-misses, including competing skills from other plugins. Run each in two modes: isolated (`claude plugin eval`, which loads no other plugin) and in situ (`claude -p` with the real plugin set, the only way to see competition). The in-situ runner must read the plugin list from the session's `system/init` event and abort if it differs from the expected one, must isolate its state directories the way `evals/cortex-agents/live.sh` does, and must name its plugin with `--plugin-dir` because plain `-p` may start loading no plugins at all. Budget before building: 20 queries, 3 runs and 2 modes is 120 runs per skill, so set a dollar total per sweep. Split 60/40, with no sealed third split below 40 queries per skill.
5. **Cortex, in this order.** First probe once whether a skill invocation can be detected in Cortex's stream or hook payloads; borg's recorded sessions contain task calls but no skill event. Until that is confirmed, the Cortex trigger check is advisory and gates nothing. If it works, extend `evals/cortex-agents` to replay the same queries live, locally, under a ceiling set below the monthly allowance, and record the date the personal trial ends (Snowflake documents 30 days, then a conversion, and overage makes the CLI unavailable until the next billing period). Passive capture of real prompts and skill invocations, and any run on the employer account, each need the owner's explicit approval first; employer-machine logs never leave that machine.
6. **Description hillclimb, Claude first.** One rewrite from the misfire cases on the 60% train split. Accept it only when the held-out gain falls outside the paired (or Wilson) interval, or when there are at least 40 queries; otherwise the result is "do not merge". It must use the same or fewer tokens (accuracy and tokens reported separately), pass the Cortex load check, and be read by a human. Where trigger accuracy is already 95% or higher, the goal becomes fewer tokens at held accuracy. If the two CLIs disagree, one SKILL.md stays, Claude's result gates, the divergence is logged, and a Cortex-only difference would be an install-time rewrite justified by eval evidence, never a forked description.
7. **Do not hillclimb skill bodies or agent definitions** unless the pre-run noise check passes, the train split holds more than 30 cases, and the baseline is below 95%. The threshold is a guard, not a finding: no source gives a minimum, and the one study of small-data optimizers saw harm at exactly 30 training examples.

**Not worth doing:** adopting Braintrust, LangSmith, Langfuse, OpenAI Evals, Ragas, DeepEval, Harbor or Inspect AI's agent bridge (hosted, deprecated, or a poor fit for a coding-agent CLI); promptfoo unless a Claude-and-Cortex matrix becomes necessary; optimizing prompts with a general reflective optimizer at 4 to 10 cases per skill; assuming one description works on both CLIs; using a judge where a script can decide; running live evals as a required CI check.

**Decisions only the owner can make:** whether to run the employer-account probe and passive capture (credits and employer policy); whether the personal Cortex trial is still active; the live-sweep dollar total.

## 2. Options

| Option | Idea | Sessions |
|--------|------|----------|
| A | Platform tools + thin Cortex runner | about 8 |
| B | Borg-owned harness and optimizer | about 25 |
| C | promptfoo as the matrix runner | about 12 |
| D | Fix and measure only, defer the rest | about 5 |

- **A** reuses `claude plugin eval` for Tier 2 and 3 cases and the description-optimization idea from Anthropic's skill-creator; the same case directories run against Cortex through a small borg runner; history is a JSONL file. Cost: the Cortex runner and its event normalizer are new code, plugin eval has no intervals, split or history, and the two Anthropic case formats cannot read each other.
- **B** builds a YAML case format, an adapter per CLI and its own optimizer. One loop for everything, but it rebuilds what Anthropic ships and 4 to 10 cases cannot feed an optimizer that size.
- **C** gives one matrix and an assertion library. Cost: Node becomes a new runtime, there is no documented run-level spend cap, no intervals and no train and test split, and its Claude path uses the Agent SDK rather than `--plugin-dir`.
- **D** fixes the demonstrated failure and adds history, and defers hillclimbing and Cortex. Smallest, but it leaves descriptions unmeasured and Cortex covered only by the offline replay.

## 3. Council and dissent

- **Product Strategist:** A fits one owner on two machines and addresses the real failure, stale live evals. D leaves the work machine's Cortex unmeasured; B is a product-building project. Kills B for duplicating tools Anthropic maintains and the owner would have to maintain alone.
- **Technical Realist:** A's weak point is the Cortex runner: the stream schema is undocumented, and plugin eval's graders must be re-implemented over normalized events. Kills C: a new runtime, no spend cap, and an SDK path that may not test the plugin as installed.
- **User Advocate:** the owner works in both CLIs on two machines, and only the personal Cortex account can be driven freely. So the live Cortex face is local and small, and the CI face is the offline replay.
- **Pragmatist (formal dissent, logged as a named risk):** hillclimbing at all is premature. borg's own listing is about 1.9k tokens, so even a 20% saving is a few hundred tokens a session, and no source gives a minimum case count. Steps 0 to 3 are most of the value. Named risk: step 6 may never be worth building.
- **Recommender:** pick A, ordered so the value arrives early, and engage the Pragmatist directly. Steps 0 to 3 stand alone. Step 6 is gated on measured noise, a minimum margin and an available 20-query suite, and the token goal is bounded: the bigger lever is the roughly 9.9k-token listing across every installed plugin, so the same tooling should accept any plugin directory, not only borg's.

## 4. Blind review record

Two independent reviews, each given the problem, the options and the chosen option, and not the council's reasoning.

**Round 1: REVISE.** Strongest objection, verbatim: "Step 5 scores one shared SKILL.md description 'per CLI', so the plan's only hillclimb waits on step 4. Step 4 rests mostly on what Track 4 lists as Not found: the Cortex stream-json schema, a per-call model id, whether the SDK works on a trial account, and any project that tests skills on Cortex. borg measured `--print` refused on the trial, so every Cortex run lands on the work account. Spend there is estimated credits per user, with admin caps that block access once exceeded over a rolling 24 hours (t4-snowflake-cortex-code-credit-limits). One description pass at skill-creator defaults is about 300 trigger checks per skill. The plan has no rule for when the two CLIs disagree, which t3-promptbridge-model-drift and t4-skillsbench-arxiv-2602-12670 say will happen. It also has no gate stopping a rewrite that emits a folded `description: >`, which Cortex rejects; the open standard's own example uses that form (t4-agentskills-optimizing-descriptions). The likely regret: an eval sweep for a personal repository locks the owner out of Cortex at work, or spends employer credits on automation that t4-agent-exam-docs warns may stretch vendor terms."

Applied: a sealed third split dropped below 40 queries; bodies gated on a noise check and train size; Cortex-loadability lint; a rule for CLI disagreement; the employer account moved behind approval; hillclimb scored on Claude first; scheduled live runs. One premise was corrected for round 2: borg already drives headless Cortex through stream-json on the personal account (PR 474), so the Cortex runner extends an existing harness rather than starting from nothing.

**Round 2: REVISE.** Strongest objection, verbatim: "Step 6 makes every description change wait on a Cortex trigger check (5b) that nothing in the findings shows can be built, on an account that may be gone in a month. Track 4 lists the Cortex stream-json schema as 'Not found'. borg's own recordings (evals/cortex-agents/recorded/stream-*.jsonl) contain task calls and a modelUsage result but no skill-invocation event to detect. Snowflake's docs say the personal CoCo trial 'is valid for 30 days' and then converts to a subscription; going over its included usage makes 'CoCo CLI … unavailable until the next billing period'. One recorded 4-turn session read about 360k cached tokens, so a 320-query replay could lock the owner out of Cortex. The step also contradicts itself: the Cortex check must pass, yet 'Claude's result gates' and a Cortex divergence is only logged. Meanwhile the one cheap Cortex check, the 5(a) load lint, is placed fifth. Every borg SKILL.md uses `description: >`, borg.zsh records that Cortex 'silently skips a file whose description is a folded `>` block' (measured for agents, not verified for skills), and cmd_setup runs `cortex skill add … 2>/dev/null`. That is the same 'cannot pass and nobody noticed' failure the problem describes."

Applied, all seven changes: the load check moved into step 1 and its errors are no longer discarded; skill-invocation detection is probed before a Cortex check is built and is advisory until confirmed; budgets and the trial-end date are required; step 0 was added for invocation mode and scope; the in-situ runner is hardened; step 6 requires a gain outside the interval or 40 queries; llm graders are allowed for the three judge-only ledger items and passive capture on the employer machine needs approval.

Also found by the reviewers and kept as work items: `disable-model-invocation` as the certain token saving; `--bare` becoming the default for `-p`, which would silently make every should-not-fire case pass; plugin eval gives each run a temporary HOME, so a scaffold must seed borg's state; and the cost of 1,920 runs per sweep if all 16 skills were suited, which step 0 shrinks.

## 5. Track findings

Condensed in `track-findings.md`, one section per research track, each claim naming its source card in `sources/` (77 cards). The numbers the recommendation leans on:

- A 10 of 10 result has a 95% Wilson lower bound of about 72%, so it cannot show a case is solved.
- A single rewrite from the misfire cases matched hand-tuned descriptions (79.2% against 79.4% F1), and extra rounds changed F1 by under half a point.
- Optimizing at 30 training examples scored 34.0% on test against 62.4% for the starting prompt.
- Anthropic's own description optimizer uses 20 queries, a 60/40 split, 3 runs and up to 5 rounds, and picks the winner by held-out score, so its held-out set doubles as a selection set.
- Cortex Code documents a Python and TypeScript SDK that returns cost and usage; no source shows it working on a trial account.

## 6. Prior work (listed for reference, kept apart from the option generation)

Options were generated from the track findings and the problem statement. This catalog was used to state the problem and the constraints.

- **`evals/ledger.json` and the 2026-10-03 directive**: the rule that every skill and agent has an eval or a dated waiver. Right: nothing ships unlisted. Wrong: 17 of 22 are waived, and it declares no tier.
- **`evals/link-next`**: positive and negative pairs, known-good and known-bad transcripts, a throwaway plugin built from the checkout. Right: the best-designed harness. Wrong: saturated on the production model, nothing stored.
- **`evals/lifecycle-manifests`**: one offline contract case and six live cases with a canonical-hash oracle. Right: skips rather than passes when a positive did not fire. Wrong: its sandbox had no `borg` and denied the skills' commands, so it could not pass; found and fixed 2026-10-30.
- **`evals/cortex-agents`**: a recorded Cortex session replayed offline plus a live driver. Right: sanitized recordings, six known-bad variants. Wrong: covers agents and the guard, not skill triggering.
- **`evals/plugin-eval/linkup-writes`**: one `claude plugin eval` case with a file check and one judge. Right: the first Tier 2 and 3 case. Wrong: its hermetic run has no `borg`, so it passed 1 of 3 for the wrong reason.
- **claude-plugins `ai-scoring` harness**: provenance-recorded corpus, sealed held-out split, Wilson intervals. Right: the model for Tier 3 discipline. Wrong: one skill of about 18.
- **`docs/agent-routing.md`, "Cortex Code"**: the measured Cortex behavior. Right: the source for what Cortex ignores. Wrong: nothing about evals.
- **Anthropic's hillclimbing post**: the loop, the guards, the stop rule. Used as one of the research inputs, not as the design.
