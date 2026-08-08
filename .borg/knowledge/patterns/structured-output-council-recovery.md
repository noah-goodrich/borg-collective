---
id: structured-output-council-recovery
project: borg-collective
domain: infrastructure
tags:
- multi-agent
- council
- structured-output
- claude-code
- error-recovery
preconditions: []
steps:
- Identify that agents returned prose (council run produces unstructured text instead
  of typed records)
- Do NOT restart the full workflow — prior research tracks and cache are still valid
- Add compact inline context summarizing the task to each agent prompt
- 'Add explicit terminal instruction: ''respond only via StructuredOutput'' (not just
  ''use StructuredOutput'')'
- Resume from cache — only the council stage re-executes
pitfalls:
- Vague instructions like 'please use structured output' are insufficient — the instruction
  must be terminal and unambiguous
- Restarting the full workflow discards valid cached research; always check whether
  only the council stage failed
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.479409+00:00'
updated_at: '2026-06-16 10:27:02.479410+00:00'
---

# structured-output-council-recovery

## description

When a multi-agent council run fails because agents return prose instead of StructuredOutput, recover without restarting by injecting explicit formatting instructions and resuming from cache.
