# Source: OpenAI Developers, "Testing Agent Skills Systematically with Evals"

**Full citation:** OpenAI. "Testing Agent Skills Systematically with Evals." OpenAI Developers blog. No author or date shown on the fetched page.
**URL:** https://developers.openai.com/blog/eval-skills
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation (vendor engineering blog)
**Track:** T4 portability, recording runs and deterministic grading on Codex

## Verified Quote(s)

**Location:** section on running `codex exec`.

> When you enable `--json`, `stdout` becomes a JSONL stream of structured events.

> Every command execution appears as an `item.*` event, in order.

**Location:** section on grading.

> Deterministic checks answer “did it do the basics?” but they don’t answer “did it do it the way you wanted?”

**Location:** section on skill triggering.

> If these are vague or overloaded, the skill won’t trigger reliably.

**Location:** section on sandboxing.

> By default, `codex exec` runs in a restricted sandbox.

## Key finding

OpenAI's recipe for skill evals on Codex is the same shape as Claude Code's and Cortex's: run headless with a JSONL event stream, grade the ordered tool/command events deterministically first, and add model-graded checks only for style. The Codex event vocabulary (`item.*`) differs from Claude Code's stream-json, and its default sandbox differs from other CLIs' permission defaults, both of which a per-CLI adapter must normalize.

**Access status:** live
