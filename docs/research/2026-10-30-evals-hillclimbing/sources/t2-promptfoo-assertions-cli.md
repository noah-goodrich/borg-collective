# Source Record: promptfoo docs, assertions, CLI, custom providers, web viewer

- **Full citation:** Promptfoo documentation pages: "Assertions and metrics" (expected-outputs), "Command line", "Custom script provider", "Python provider", "Web viewer", read 2026-10-30.
- **URL:** https://www.promptfoo.dev/docs/configuration/expected-outputs/ ; https://www.promptfoo.dev/docs/usage/command-line ; https://www.promptfoo.dev/docs/providers/custom-script/ ; https://www.promptfoo.dev/docs/providers/python/ ; https://www.promptfoo.dev/docs/usage/web-ui/
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

expected-outputs, assertion types table:
1. `trajectory:tool-used`: "Ensure a traced agent trajectory used specific tools"
2. `trajectory:tool-sequence`: "Ensure traced tool usage happened in the expected order"
3. `llm-rubric`: "Grade text, images, or audio against a rubric with a compatible model"
4. `python`: "provided Python function validates the output"
5. `cost`: "Cost is below a threshold, or recorded as a zero-weight named metric"

command-line page:
6. `--repeat`: "Number of times to run each test"
7. `--filter-failing`: "Filter tests that failed in a previous eval (by file path or eval ID)"

custom-script page:
8. "treats standard output as the response `output`, even when the script prints JSON."

python provider page, Return Format example:
9. `"tokenUsage": {"total": 150, "prompt": 50, "completion": 100},`
10. `"cost": 0.0025,  # in dollars`

web-ui page:
11. "Diff against another eval (green = added, red = removed)."

## Key finding

promptfoo can wrap any CLI agent: an `exec:` provider returns stdout only, while a Python provider can return output plus `tokenUsage` and `cost`, so a Cortex stream-json wrapper of a few dozen lines would feed its cost and trajectory assertions. It offers repeats, Python/JS/LLM-rubric graders, trajectory assertions, a local viewer with eval-to-eval diff, but the CLI page documents no run-level spend ceiling and no confidence intervals or train/test split.

Access status: live (all five pages)
