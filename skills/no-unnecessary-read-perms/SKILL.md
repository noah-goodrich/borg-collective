---
name: no-unnecessary-read-perms
description: >
  Suppress unnecessary read-permission prompts for files already accessible via
  normal tool use. Always active. Applies to Claude's own tool calls and to any
  subagent prompts that include the system subagent rules.
disable-model-invocation: true
---

# Read Access Rule

You have Read access to all files in the working directory and its subdirectories.
**Do not request additional permission before reading a file. Just use the Read,
Grep, or Glob tools directly.**

When spawning subagents (via the Agent tool), include this rule in every subagent
prompt: *"Use Read/Grep/Glob directly on any file — do not ask for read permission
first."* Subagents that ask for permission before reading are in violation of this
rule; re-prompt them with the rule and proceed.

This rule does NOT override write/execute permission prompts. Those are intentional
and must be presented to the user for approval.
