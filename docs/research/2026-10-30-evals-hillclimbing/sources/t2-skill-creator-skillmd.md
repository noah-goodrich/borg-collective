# Source Record: anthropics/skills, skill-creator SKILL.md

- **Full citation:** Anthropic, `skills/skill-creator/SKILL.md`, anthropics/skills GitHub repository, main branch, read 2026-10-30.
- **URL:** https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md (rendered: https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (first-party skill source)
- **Track:** t2 tooling landscape

## Verified Quote(s)

From the raw file, section "Description optimization", "Step 3: Run the optimization loop" (fetch tool limited quotes to fragments; fragments are exact):

1. "This handles the full optimization loop automatically."
2. "selected by test score rather than train score to avoid overfitting."

Section "Step 4: Grade, aggregate, and launch the viewer", item 2:

3. "This produces `benchmark.json` and `benchmark.md` with pass_rate, time, and tokens for each configuration,"
4. "with mean ± stddev and the delta."

Section "Step 3: As runs complete, capture timing data":

5. "This is the only opportunity to capture this data — it comes through the task notification and isn't persisted elsewhere."

Lines referencing the subprocess runner:

6. "This section requires the `claude` CLI tool (specifically `claude -p`) which is only available in Claude Code."
7. "Description optimization (`run_loop.py` / `run_eval.py`) should work in Cowork just fine since it uses `claude -p` via subprocess, not a browser,"

Not quoted (paraphrase, from the same section): the loop splits the trigger eval set 60% train / 40% held-out test, runs each query 3 times for a trigger rate, iterates up to 5 times, and returns `best_description`. The scripts directory (https://github.com/anthropics/skills/tree/main/skills/skill-creator/scripts) lists `run_loop.py`, `run_eval.py`, `improve_description.py`, `aggregate_benchmark.py`, `generate_report.py`.

## Key finding

skill-creator ships the only first-party description hillclimber found: `run_loop.py` drives `claude -p` as a subprocess, uses a 60/40 train/held-out split with 3 runs per query, and picks the best description by held-out score. Its body/output evals run as in-session subagents with mean ± stddev aggregation and tokens per run, but token data is captured from task notifications only and "isn't persisted elsewhere", and its `evals/evals.json` format is incompatible with `claude plugin eval`.

Access status: live (license of the skill not confirmed on the page)
