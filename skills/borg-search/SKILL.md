---
name: borg-search
description: >
  Search the cairn knowledge graph for lessons, decisions, or patterns across projects.
  Use when the user asks to search knowledge, find past decisions, or look something up.
---

Run `borg search "<query>"` with the Bash tool, where <query> is what the user wants to find.
If no query given, ask for one before running.

Present results directly. If no results: say so and suggest a broader search term.
If cairn is unavailable, say so — don't silently return empty results.

After you cite a returned record in your answer, close the loop with the `record_feedback` MCP tool: pass `target_type`
and `target_id` from that hit (its `source_table` and `record_id`), and set `outcome` to `helpful` when you applied the
record, `unhelpful` when it was a dead end, or `partially_helpful` when it only helped in part. This feeds the feedback
score back into future ranking. Only decisions, patterns, and observations take feedback — skip hits whose
`source_table` is `document`.
