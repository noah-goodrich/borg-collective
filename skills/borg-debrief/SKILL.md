---
name: borg-debrief
description: >
  Deep session analysis. Extracts objective, outcome, decisions, patterns, and next steps from the
  current session. Produces structured output for persistence. Runs automatically via stop hook,
  or manually when you want to capture what happened before context compresses.
user-invocable: true
disable-model-invocation: true
---

# Borg Debrief — Session Analysis

Analyze the current session and produce a structured debrief. This captures what happened so the next
session (or a different person) can pick up without re-reading the full conversation.

## Output Format

Produce exactly this structure. Be specific. Use file paths, function names, and command examples.
Vague summaries are useless — "worked on improvements" tells the next session nothing.

```markdown
# Session Debrief: [project name]
*Date: [YYYY-MM-DD HH:MM]*
*Session ID: [if known]*

## Objective
What was the goal of this session? One sentence.
If the goal changed mid-session, note both: "Started with X, pivoted to Y because Z."

## Outcome
What actually happened? Be specific:
- Files created/modified (with paths)
- Features built or bugs fixed
- Tests written or passing
- Commands that now work

## Decisions Made
For each significant decision during the session:
- **Decision**: What was decided
- **Reasoning**: Why this over alternatives
- **Alternatives considered**: What we didn't do and why
- **Confidence**: High / Medium / Low

Only include decisions that would matter to someone continuing this work.
Skip trivial choices (variable names, formatting).

## Patterns Discovered
Reusable approaches or techniques that worked:
- What the pattern is
- When to apply it
- Any pitfalls to watch for

Only include if genuinely reusable. Don't force this section.

## Blockers and Observations
Things that surprised, failed, or blocked progress:
- Gotchas encountered (with resolution if found)
- Errors that took time to diagnose (with root cause)
- Tool behavior that was unexpected
- Dependencies that were missing or broken

## Progress Against Plan
If PROJECT_PLAN.md exists, update the checklist:
- [ ] Criterion 1 — status
- [x] Criterion 2 — completed this session
...

## Next Steps
What should the NEXT session do FIRST? Be specific enough that someone returning after 3 days
knows exactly where to start:
1. [Most important action — include file path and function if applicable]
2. [Second action]
3. [Third action if relevant]

## Context for Next Session
Anything the next session needs to know that isn't captured above:
- Uncommitted changes and their purpose
- Background processes or services that need to be running
- Decisions that were deferred and why
- Links to relevant PRs, issues, or docs
```

## Rules

- Be specific. "Fixed the bug" → "Fixed PATH clobbering in borg.zsh:335 caused by zsh's tied
  `path` variable. Renamed to `ppath` throughout."
- Include file paths. "Modified the config" → "Modified ~/.config/borg/config.zsh"
- Include commands. "Run the tests" → "Run `pytest tests/ -v` from the project root"
- If the session was short or simple, keep the debrief short. Don't pad.
- If no decisions were made, say "No significant decisions." Don't invent them.
- If no patterns were discovered, say "None." Don't force it.
