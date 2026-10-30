# Source: Snowflake, "Cortex Agent evaluations" and "AI Observability with Snowflake Cortex"

**Full citation:** Snowflake Inc. "Cortex Agent evaluations" (GA per release note dated Mar 13, 2026) and "AI Observability with Snowflake Cortex." Snowflake Documentation.
**URL:** https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-evaluations
**URL (observability):** https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, built-in eval/observability features

## Verified Quote(s)

**Location:** Cortex Agent evaluations page, overview (first paragraph).

> Cortex Agent evaluations allow you to test, baseline, and hill climb on your agent’s behavior and performance

**Location:** Cortex Agent evaluations page, metrics section.

> Logical consistency spans the whole loop: it measures consistency across agent instructions, planning, and tool calls.

**Location:** Cortex Agent evaluations page, custom metrics section.

> The prompt you provide is passed to an LLM judge along with run traces to conduct your custom evaluation.

**Location:** Cortex Agent evaluations page, Cortex Code mention.

> Cortex Code can also run the evaluation against the dataset, so you can go from dataset to results in a single flow.

**Location:** AI Observability page, TruLens section.

> Use TruLens when you build a custom AI application whose observability you own end to end

> Traces and scores live in SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS.

> Trace delivery is best effort, so totals computed from the event table can under-report consumption.

## Key finding

Snowflake's built-in evaluation and hillclimbing tooling targets native Cortex Agents (server-side agent objects) and custom TruLens-instrumented apps, using LLM judges over traces; Cortex Code appears only as a helper that runs those evaluations, not as a subject that can be evaluated. Nothing in these pages evaluates a Cortex Code CLI session, skill or subagent, so borg's portable harness gets no native Snowflake equivalent and TruLens would at most be an optional Tier 3 sink.

**Access status:** live
