# Source: Parnin 2013 - "Programmer, Interrupted" (Game Developer)

**Full citation:** Parnin C. "Programmer, Interrupted." Game Developer / Gamasutra (reprint of the April 2013 magazine article). April 22, 2013.
**URL:** https://www.gamedeveloper.com/programming/programmer-interrupted
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 7
**Research topic area:** S2 re-entry, resumption and handoff - Developer task-context recovery

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Author is a PhD candidate at the time publishing his own studies; trade-magazine venue. |
| 2 | Evidence Quality | 5/10 | Summarizes his own 10,000-session and 414-survey data without methods detail in this piece. |
| 3 | Currency | 4/10 | 2013; +2 timeless bonus on memory content, but tooling is dated. |
| 4 | Intent | 6/10 | Popular education aimed at programmers, with some tool promotion (prototype tools named). |
| 5 | Bias & Objectivity | 6/10 | Mentions that 40 percent of interrupted tasks are not resumed and interruption may be beneficial. |
| 6 | Logic & Coherence | 7/10 | Reasoning from memory taxonomy to tool ideas is plausible but speculative. |
| 7 | Corroboration | 8/10 | Numbers match the Parnin & Rugaber 2009 abstract. |
| 8 | Intellectual Honesty | 6/10 | Admits "less evidence" for programmers than office workers. |
| 9 | Specificity | 7/10 | Concrete numbers and named coping tactics. |
| 10 | Relevance | 8/10 | Developer re-entry is the exact scenario. |

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A programmer takes 10-15 minutes to start editing after resuming from an interruption; resumption within a minute happened only 10 percent of the time (10,000 sessions / 86 programmers, 414-programmer survey).
- Reported coping tactics: navigating several locations to rebuild context, intentional compile errors as a roadblock reminder, source diffs as a last resort; TODO comments fail because nothing prompts anyone to view them.
- Interruption is worst at high memory load (mid-edit, navigation and search, comprehending data/control flow); programmers often need at least seven minutes to reach a low-memory-state breakpoint.

## Verified Quote(s)

**Location reference:** Quote 1: section "Studying programmer interruption", the first bullet after the sentence
beginning "Based on an analysis of 10,000 programming sessions". Quote 2: section "Prospective memory", paragraph 2
(beginning "Various studies have described"; paragraph 1 is "Prospective memory holds reminders..."), sentence 3 (1 =
"Various studies...", 2 = "For example, developers often leave TODO comments...", 3 = "A drawback of this
mechanism..."). Quote 3: section "The worst time to interrupt a programmer", paragraph 3 (beginning "If an interrupted
person is allowed"; paragraphs 1-2 are "Research shows that the worst time..." and "In our study, we looked at
subvocal utterances..."), sentence 2 (1 = "If an interrupted person is allowed...", 2 = "However, programmers often
need at least seven minutes..."). Paragraphs counted as body <p> elements, excluding figure captions and the list that
follows; sentences split at a terminal period followed by a capital letter.
beginning "Based on an analysis of 10,000 programming sessions". Quote 2: section "Prospective memory", paragraph 2
(beginning "Various studies have described"; paragraph 1 is "Prospective memory holds reminders..."), sentence 3 (1 =
"Various studies...", 2 = "For example, developers often leave TODO comments...", 3 = "A drawback of this
mechanism..."). Quote 3: section "The worst time to interrupt a programmer", the paragraph beginning "If an
interrupted person is allowed" (the first body paragraph after the two figure captions), sentence 2. Paragraphs
counted as body <p> elements, excluding figure captions; sentences split at a terminal period followed by a capital
letter.

> A programmer takes 10-15 minutes to start editing code after resuming work from an interruption.

> A drawback of this mechanism is that there is no impetus for viewing these reminders.

> However, programmers often need at least seven minutes before they transition from a high memory state to a low memory state.

**Access status:** live - Fetched with curl; quotes extracted from the page HTML paragraphs.

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline (weighted average about 6.2) included because it is the only accessible full text carrying the field coping tactics and the worst-time-to-interrupt guidance; the underlying study (Parnin & Rugaber 2009) is only available as an abstract.

**Redundancy check:** Overlaps Parnin & Rugaber 2009 numbers (card not written; redundant), adds coping tactics and timing.

**Perspective category:** Practitioner
