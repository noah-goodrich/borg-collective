# Source: Gechev, "skill grade" (skillgrade announcement)

**Full citation:** Minko Gechev. "skill grade." blog.mgechev.com, March 14, 2026.
**URL:** https://blog.mgechev.com/2026/03/14/skillgrade/
**Date accessed:** 2026-10-30
**Evidence level:** practitioner
**Track:** T4 portability, multi-CLI skill eval runners

## Verified Quote(s)

**Location:** setup section.

> The agent is auto-detected from your API key.

**Location:** config section.

> Everything lives in a single `eval.yaml` file

**Location:** graders section.

> deterministic and LLM rubric graders with configurable weights

**Location:** CI section.

> the runner is already an ephemeral sandbox, so Docker adds overhead without benefit.

## Key finding

skillgrade defines one `eval.yaml` per skill with tasks (instruction, workspace files, weighted deterministic and LLM-rubric graders, trials) and runs it against Claude Code, Codex or Gemini CLI, choosing the agent from whichever API key is set. The agent-selection-by-API-key design does not fit Cortex, which authenticates through a Snowflake connection, illustrating that a portable runner needs an explicit per-CLI auth adapter.

**Access status:** live
