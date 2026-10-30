# Source Record: Community Claude Code skill-testing projects (skill-eval action; Scott Spence harness)

- **Full citation:** (a) skill-bench/skill-eval-action, "Skill Eval," GitHub Marketplace Action, v1.3.0, read 2026-10-30. (b) Scott Spence, "Measuring Claude Code Skill Activation With Sandboxed Evals," scottspence.com, February 8, 2026.
- **URL:** https://github.com/marketplace/actions/skill-eval ; https://scottspence.com/posts/measuring-claude-code-skill-activation-with-sandboxed-evals
- **Date accessed:** 2026-10-30
- **Evidence level:** community (a); practitioner (b)
- **Track:** t2 tooling landscape

## Verified Quote(s)

skill-eval action page:
1. "eval YAML -> claude -p (execute) -> claude -p (grade) -> summary.json -> PR comment + artifact"
2. "Grades each response against criteria via a separate `claude -p` call."

Scott Spence post:
3. "So I built an eval harness that runs `claude -p` commands inside isolated Daytona sandboxes."
4. "Runs each of the 22 test prompts through `claude -p` with `--output-format stream-json`."
5. "The whole eval cost $5.59 across ~250 Claude invocations."

Facts (not quotes): action licensed MIT; release date not shown on the Marketplace page.

## Key finding

Community skill testing in 2026 converges on the same shape as borg's harness: `claude -p` with stream-json, detect `Skill` tool calls, grade with a second `claude -p` call, emit a summary JSON. Neither project offers history, intervals, or Cortex support, so neither is worth adopting over the existing harness; they confirm the pattern is cheap (about $5.59 for ~250 invocations).

Access status: live (both)
