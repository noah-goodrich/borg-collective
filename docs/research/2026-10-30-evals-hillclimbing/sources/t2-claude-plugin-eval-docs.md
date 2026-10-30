# Source Record: Claude Code docs, "Test plugins with evals"

- **Full citation:** Anthropic, "Test plugins with evals," Claude Code Docs (plugin-evals page), undated living documentation, read 2026-10-30.
- **URL:** https://code.claude.com/docs/en/plugin-evals (fetched as the Markdown twin https://code.claude.com/docs/en/plugin-evals.md)
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

Quotes are from the `.md` rendering of the page; inline code backticks are as they appear in the Markdown source.

1. Intro paragraph: "A grader is a pass/fail check on what Claude produced, such as a regex over the reply, whether a particular tool was called, or a rubric that a second model judges the reply against."
2. "How a case is scored": "One run of a non-deterministic agent tells you little, so each case runs three times by default. A run's score is the fraction of its graders that passed, weighted if you set weights, and the case's score is the mean across its runs."
3. "The no-plugin baseline": "To separate the two, a case's runs are repeated with no plugin loaded, and you get two scores, `WITH` and `W/OUT`. Their difference, `Δ`, is what the plugin contributed."
4. "Choose and weight graders": "Of the six types, `regex`, `tool_used`, `tool_order`, and `file_exists` are computed from the transcript and files and cost nothing, while `llm` and `baseline` call a judge model and add to the run's cost."
5. "Choose and weight graders": "There are no custom-code graders."
6. "Grader types" table, `file_exists` row: "Only files created during the run count"
7. "Command options" table, `--max-cost-usd`: "A ceiling on the run's list-price cost estimate, not on plan usage. Checked before each run starts."
8. "Command options" table, `--model`: "Pin it in CI so a model rollout isn't mistaken for a plugin regression"
9. "Run evals in CI": "To keep costs predictable, give quick every-change suites only graders that don't call a judge, use `--ablation none` where you don't need `Δ`, and leave `partial: true` documents and runs with `skippedPaidGraders` out of any trend you chart."
10. "JSON result": "`aggregate-result.json`, and `--json` output, is a versioned document with `schemaVersion: 1` for CI scripts to parse."
11. "JSON result" table, last row: "Estimated cost at list price including judge calls, wall-clock seconds, and the Claude Code version that ran the suite"
12. "How runs are isolated": "Each run gets a temporary home directory, working directory, and Claude Code configuration, and the agent under test runs there as a `claude -p` child process with only your plugin loaded."
13. "Seed the workspace or conversation": "The script runs as you, outside the agent's sandbox, and only when you pass `--scaffold`, so pass that flag only for suites you or your organization wrote."
14. Intro: "the [skill-creator plugin](https://code.claude.com/docs/en/skills.md#run-evals-with-skill-creator) runs a similar comparison with its own `evals/evals.json` format, and neither tool reads the other's case files."
15. "prompt.md frontmatter" table, `runs`: "Runs per arm, 1 to 50. `--runs` overrides it"

## Key finding

`claude plugin eval` (Claude Code v2.1.269+) is a complete Tier 2/Tier 3 runner for Claude Code plugins: case dirs with `prompt.md` + `graders/*.md`, six grader types (regex, tool_used, tool_order, file_exists, llm 2-of-3 judge, baseline), 3 runs per arm default, automatic with/without-plugin delta, cost ceiling, pinned models, versioned JSON plus self-contained HTML per timestamped run, and documented CI exit codes. It cannot run custom-code graders, cannot target any agent other than `claude -p` (so not Cortex), reports no confidence intervals, no train/test split, no cross-run history or trend (each run is a separate `results/<timestamp>/` directory and the docs tell you to chart trends yourself), and its documented JSON fields list cost, duration and Claude Code version but not token counts.

Access status: live
