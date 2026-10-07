---
name: borg-next
description: >
  Show what project needs attention most urgently and let the user pick one to open. Use when the user asks
  "what should I work on?", "what's next?", or wants to know priorities.
---

You are the chooser. Run `borg next --rows --json` with the Bash tool (it logs nothing). It prints one JSON object: `rows` (each with `n`, `project`, `item`, `next_step`, `owner`, `ready`), `rec`, and `suggestion` (a row number or null).

1. If `rows` is empty, say "Nothing registered needs you", run `borg next --declined`, and stop.
2. Present one line per row: `n. project — next step · owner · ready glyph`. Show a blank field as "—". If `suggestion` is non-null, put that row first and label it "suggested". If it is null, keep borg's ranked order and never label or imply a recommendation.
3. Ask which to open with the AskUserQuestion tool: up to 4 options from the top rows, plus "Not now". When `suggestion` is non-null, that row is first with "(Recommended)" appended; otherwise "(Recommended)" appears nowhere.
4. Log exactly ONE outcome per invocation, adding `--shown` iff a suggestion was displayed:
   - A listed project: `borg next --open <project> --chosen`. It switches tmux and logs the choice. If it fails, say so plainly.
   - "Not now", or any answer that is not a listed project: `borg next --declined`.
   Never open a project that was not in `rows`.

Keep the reply short: the rows, the question, one line of outcome.
