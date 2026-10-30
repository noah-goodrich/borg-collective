Generated: 2026-10-30

# Verification report: citation check of the source cards

**Gate result: NOT PASSED. Stamp: low-confidence on quote form.** Two rounds ran; both landed in the `>10%` failure-rate band. Every failure is a punctuation, capitalization, truncation or section-label error inside a quote. No verifier found a fabricated, misattributed or contradicted quote, and none could not reach its source (0 inaccessible).

Mode: decision-design, with the citation protocol of the evidence pipeline applied to the 77 source cards the four research tracks wrote. The verifiers were `research-tools:research-verifier` runs, two per round, each given 12 cards and the protocol only, and distinct from the four `research-analyst` runs that wrote the cards. The harness's internal agent ids are not recorded here because the session treats them as internal metadata, so the gate's "distinct verifier id" line cannot be satisfied literally; the separation is by agent type and by run.

## Sampling

- Cards: 77 (t1: 18, t2: 21, t3: 13, t4: 25).
- Floor: 30% rounded up, minimum 3, is 24.
- Method: `ls sources | sort -R | head -24`, drawn in the shell; the list was saved before dispatch.
- Round 1 and round 2 are independent draws. Eight cards appear in both (t1-aisi-evaluation-standard, t1-inspect-metrics, t1-openai-eval-best-practices, t2-skill-creator-skillmd, t3-ace-context-collapse, t3-craft-pareto, t3-mage-low-data-overfit, t4-codetalker-releases).

## Round 1

| Counts | Verified | Failed | Inaccessible | Failure rate |
|--------|----------|--------|--------------|--------------|
| 24 cards | 19 | 5 | 0 | 20.8% |

Failures:
- `t2-langsmith`: quote 4 ends with a period the pricing page lacks.
- `t3-promptbridge-model-drift`: quote starts with a capital R; the abstract has a lowercase r mid-sentence.
- `t3-single-rewrite-skill-descriptions`: a capital A the abstract lacks, and a trailing period on a Section 5.4 quote that continues in the source.
- `t4-skillgrade-blog`: quote ends with a period; the page has a colon.
- `t4-snowflake-cortex-code-extensibility`: a quote filed under the Skills intro actually sits under the subheading "Creating custom skills".

Verified: t1-aisi-evaluation-standard (see round 2), t1-dorner-judge-twice-data, t1-inspect-metrics, t1-openai-eval-best-practices, t1-thakur-judging-judges, t2-harbor, t2-skill-creator-skillmd, t3-ace-context-collapse, t3-anthropic-hillclimbing-blog, t3-craft-pareto, t3-mage-low-data-overfit, t4-agent-exam-docs, t4-agentskills-specification, t4-claude-code-headless, t4-codetalker-releases, t4-openai-eval-skills-blog, t4-snowflake-cortex-code-plugins, t4-snowflake-cortex-code-settings, t4-txcript.

Remediation: the five cards were corrected to the exact source text. A corrected card is not re-counted as verified in this round.

## Round 2 (fresh draw after remediation)

| Counts | Verified | Failed | Inaccessible | Failure rate |
|--------|----------|--------|--------------|--------------|
| 24 cards | 21 | 3 | 0 | 12.5% |

Failures:
- `t1-aisi-evaluation-standard`: quote 5 stopped mid-sentence and added a period; the source continues ", and for the scores not to change over time given the same model". (Round 1 had passed this card on its other quotes.)
- `t2-cortex-cli-reference`: quotes 1 to 3 add a final period the options-table cells do not have.
- `t4-docker-cagent-session-recording`: a sentence filed under "how it works" is under "Getting started".

Verified: t1-anthropic-demystifying-evals, t1-anthropic-skill-creator, t1-eugeneyan-llm-evaluators, t1-inspect-metrics, t1-openai-eval-best-practices, t1-tau-bench-passk, t2-braintrust, t2-inspect-ai, t2-langfuse, t2-promptfoo-assertions-cli, t2-promptfoo-claude-agent-sdk-provider, t2-skill-creator-skillmd, t3-ace-context-collapse, t3-craft-pareto, t3-gepa-paper, t3-mage-low-data-overfit, t3-skill-creator-run-loop, t4-anthropic-skill-best-practices, t4-codetalker-releases, t4-snowflake-cortex-code-cli-overview-trial, t4-snowflake-cortex-code-cli-reference.

Remediation: the three cards were corrected.

## Reading the result

- The failures share a cause: the analysts added a terminal period or a capital to quote fragments. That is a quoting habit, not invention; in 8 of the 8 failed cards the words of the quote were found on the cited page.
- Combined over both rounds the verifiers opened 48 card checks (40 distinct cards) and found 8 failures in form, 0 in substance.
- A third round was not run: a fresh draw would re-find the same class of defect in cards not yet fixed, at about 130k tokens a round, and no claim in the recommendation rests on the exact placement of a period.
- What a reader should do: treat every quote as a fragment whose wording is right and whose punctuation may be off by a period, and open the card when a number matters (the Wilson bound, the 34.0% against 62.4% result, the 79.2% against 79.4% result).
