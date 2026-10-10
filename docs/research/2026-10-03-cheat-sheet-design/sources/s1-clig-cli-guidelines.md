# Source: Command Line Interface Guidelines (clig.dev) - output design

**Full citation:** Prasad A, Firshman B, Tashian C, Parish E. "Command Line Interface Guidelines." clig.dev. Undated living document (the page carries no publication date; origin believed to be about 2020, unverified); open-source, community-reviewed.
**URL:** https://clig.dev
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 7 (expert practitioner guidelines)
**Research topic area:** S1 terminal and CLI information design - what to show, how much, in what form

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 5/10 | Four named practitioners (two Docker Compose co-creators, a Replicate co-founder, a technical writer per the author list on the page); reviewed by named community members; no formal standards body. |
| 2 | Evidence Quality | 2/10 | Opinion and exemplars (git status, ls); no studies. |
| 3 | Currency | 6/10 | Undated on the page; treated as a 2020s living document (unverified) with a timeless bonus on human-readability. |
| 4 | Intent | 8/10 | Open-source public-good guideline. |
| 5 | Bias & Objectivity | 6/10 | Clear Unix-tradition perspective; acknowledges trade-offs such as machine versus human output. |
| 6 | Logic & Coherence | 7/10 | Rules are consistent and justified with examples. |
| 7 | Corroboration | 6/10 | Consistent with Few on colour restraint and with dashboard-as-external-memory; no independent empirical corroboration for terminal output specifically. |
| 8 | Intellectual Honesty | 5/10 | Presents guidelines as best practice; limited discussion of failure. |
| 9 | Specificity | 7/10 | Concrete rules (TTY detection, NO_COLOR, --json, --plain, suggest next command). |
| 10 | Relevance | 9/10 | It is the only available design source for terminal status output, which is borg's medium. |

**Score band:** borderline (weighted average about 5.4. Included as the sole terminal-design source; no empirical CLI-readability research was found. Findings from it are design hypotheses, not evidence.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Output default: "err on the side of less"; display output on success but keep it brief, so silence does not read as hanging.
- Make current state easy to see and suggest the next command to run (git status is the exemplar, with hints).
- Colour has meaning only if used sparingly: if everything is a different colour the colour means nothing.
- Information density can be raised with scannable formats (ls permissions) because a novice can ignore most of it and learn patterns over time - progressive disclosure by learned pattern.
- Provide separate machine-readable output (--json, --plain) so human formatting does not break composition.

## Verified Quote(s)

**Location reference:** All four quotes are in the page's "Guidelines" > "Output" section (h3 id="output"). Each
guideline there is one paragraph that opens with a bold run-in sentence; sentences are split at a terminal period or
exclamation mark followed by a capital letter, and the bold run-in counts as sentence 1. Quote 1: guideline "Display
output on success, but keep it brief.", sentence 1 (the run-in sentence itself). Quote 2: guideline "Make it easy to
see the current state of the system.", sentence 1 (the run-in sentence itself; the next paragraph cites git status).
Quote 3: guideline "Use color with intention.", single paragraph, sentence 3 (1 = run-in, 2 = "For example, you might
want to highlight some text..."). Quote 4: guideline "Increase information density—with ASCII art!", single paragraph,
sentences 3-4 (1 = run-in, 2 = "For example, ls shows permissions in a scannable way.", 3 = "When you first see
it...", 4 = "Then, as you learn how it works...").

> Display output on success, but keep it brief.

> Make it easy to see the current state of the system.

> Don’t overuse it—if everything is a different color, then the color means nothing and only makes it harder to read.

> When you first see it, you can ignore most of the information. Then, as you learn how it works, you pick out more patterns over time.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline; sole terminal-medium source. Weakness: no evidence base beyond convention.

**Redundancy check:** Unique to the terminal medium; reinforces Few's colour/salience points.

**Perspective category:** Practitioner
