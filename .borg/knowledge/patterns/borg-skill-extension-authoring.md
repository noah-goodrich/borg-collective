---
id: borg-skill-extension-authoring
project: borg-collective
domain: skills
tags:
- borg-plan
- borg-assimilate
- skill-extensions
- local-context
- JIRA
preconditions: []
steps:
- 'Identify which skill and which load point you need: `borg-plan/01-context`, `borg-plan/02-output`,
  `borg-plan/03-followup`, or the equivalents for `borg-assimilate`.'
- 'Create a markdown file at the appropriate scope path: per-machine `~/.config/borg/extensions/skill-extensions/<skill>/<NN>-<point>.md`
  or per-project `.borg/extensions/skill-extensions/<skill>/<NN>-<point>.md`.'
- Write the extension as a Claude instruction in markdown — describe what Claude should
  do (e.g., ask for ticket key, run a tool call, use result as source material). Do
  not embed executable code in the file itself.
- 'After `brew upgrade borg-collective && borg setup`, verify the upstream SKILL.md
  contains the load point blocks: `grep -c ''Local Extensions:'' ~/.claude/skills/<skill>/SKILL.md`.'
- Run the skill against a real case to validate the extension is picked up and executed
  correctly.
pitfalls:
- Extensions are only active after `borg setup` copies SKILL.md files to `~/.claude/skills/`.
  Editing the repo directly has no effect until setup runs.
- Per-project extensions override per-machine extensions at the same load point —
  understand layering before writing both.
- v1 is markdown-only. Do not put shell scripts in extension files; describe the tool
  call for Claude to execute instead.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.300499+00:00'
updated_at: '2026-06-16 10:27:02.300500+00:00'
---

# borg-skill-extension-authoring

## description

How to write a local skill extension that injects context (e.g., JIRA ticket data) into an upstream borg skill at a specific load point.
