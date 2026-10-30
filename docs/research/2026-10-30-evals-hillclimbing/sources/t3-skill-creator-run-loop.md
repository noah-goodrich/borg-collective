# anthropics/skills: skill-creator run_loop.py and SKILL.md (description optimization)

- Citation: Anthropic, `skills/skill-creator/scripts/run_loop.py` and `skills/skill-creator/SKILL.md`, GitHub repository anthropics/skills, main branch.
- URLs: https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/scripts/run_loop.py and https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (Anthropic first-party tool source code; no reported effect sizes)
- Access status: live

## Verified Quote(s)

run_loop.py, `split_eval_set` docstring:

> Split eval set into train and test sets, stratified by should_trigger.

run_loop.py, `--holdout` argument help text (default `0.4`):

> Fraction of eval set to hold out for testing (0 to disable)

run_loop.py, comment inside the loop:

> # Strip test scores from history so improvement model can't see them

run_loop.py, comment before final selection:

> # Find the best iteration by TEST score (or train if no test set)

SKILL.md, "### Step 1: Generate trigger eval queries":

> Create 20 eval queries — a mix of should-trigger and should-not-trigger.

SKILL.md, "### Step 3: Run the optimization loop":

> It splits the eval set into 60% train and 40% held-out test

> selected by test score rather than train score to avoid overfitting

Other defaults read from run_loop.py argparse: `--runs-per-query` default `3`, `--max-iterations` default `5`.

## Key finding

Anthropic's own skill tooling already ships a trigger-description hillclimber: 20 labeled queries, a stratified 60/40 split, 3 runs per query, up to 5 iterations, and test scores stripped from what the improver model sees. The final pick is the iteration with the best test score, so the held-out set is used for selection, which leaks some selection bias into the reported score (there is no third, sealed set).
