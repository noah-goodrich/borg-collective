# Source: agent-exam documentation (Read the Docs)

**Full citation:** agent-exam project. "agent-exam" documentation home. agent-exam.readthedocs.io. No version or date shown.
**URL:** https://agent-exam.readthedocs.io/
**Date accessed:** 2026-10-30
**Evidence level:** practitioner (open-source tool documentation)
**Track:** T4 portability, multi-CLI skill eval runners

## Verified Quote(s)

**Location:** home page, intro.

> agent-exam grades agent skills.

**Location:** home page, supported harnesses.

> Claude Code, Codex CLI, Copilot CLI or OpenCode

**Location:** home page, caveats.

> Skill behavior is non-deterministic, so one good run is not a green light

> Automating runs against subscription-backed CLIs may stretch a harness's terms

> LLM evals are slow and expensive

## Key finding

agent-exam runs YAML task suites against real agent CLIs (Claude Code, Codex CLI, Copilot CLI, OpenCode) through a per-CLI harness, with assertions, fixtures, trigger evals and LLM judges, and reports cost, tokens and wall time. It does not list Cortex Code, and it flags vendor terms-of-service risk when automating subscription-backed CLIs, a risk that also applies to Cortex trial use.

**Access status:** live (home page only; task YAML reference not fetched)
