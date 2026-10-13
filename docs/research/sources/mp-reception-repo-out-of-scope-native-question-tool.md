# Source: mattpocock/skills .out-of-scope: grilling through the harness's native question tool

**Full citation:** Matt Pocock (maintainer). ".out-of-scope/native-question-tool.md." github.com/mattpocock/skills. Repository file, read 2026-10-13 (raw file; repo last pushed 2026-10-12).
**URL:** https://github.com/mattpocock/skills/blob/main/.out-of-scope/native-question-tool.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion; primary policy document of the author)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 8/10 | the maintainer |
| 2 | Evidence Quality | 5/10 | rationale, no data |
| 3 | Currency | 10/10 | live file |
| 4 | Intent | 7/10 | curation policy |
| 5 | Bias & Objectivity | 5/10 | author's own view |
| 6 | Logic & Coherence | 7/10 | coherent |
| 7 | Corroboration | 6/10 | 5 user requests cited |
| 8 | Intellectual Honesty | 8/10 | candid trade-off |
| 9 | Specificity | 8/10 | issue numbers |
| 10 | Relevance | 9/10 | native-features angle |

Justifications (one line per dimension, same order):

1. Authority: The repo owner is the authority on his own policy.
2. Evidence Quality: The rationale is first-hand ("I've tried the AskUserQuestion UI") but not measured.
3. Currency: Live file in a repo pushed the day before.
4. Intent: A curation policy written to explain rejected requests.
5. Bias & Objectivity: The author states his own preference and pushes harness-specific preference to users' CLAUDE.md.
6. Logic & Coherence: Reasoning (harness-neutral text; pickers bias toward multiple-choice) is coherent.
7. Corroboration: Five prior user requests are listed (#19, #643, #840, #1107, #1152), confirming demand.
8. Intellectual Honesty: Candidly admits the choice is a design preference and tells users how to opt in per user.
9. Specificity: Names the specific tool (AskUserQuestion) and the exact issues.
10. Relevance: Directly addresses the native Claude feature versus harness-neutral skill question.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The maintainer deliberately keeps grilling skills as plain chat text, not harness-native question tools, so they stay harness-neutral across Claude Code, Codex, Copilot and Cursor.
- He argues structured pickers bias questions toward multiple-choice with pre-baked answers, the opposite of grilling's purpose of open questions in the user's own words.
- Users repeatedly ask for native-tool support (five prior issues), and HN users fork the skill to add AskUserQuestion, so adopter demand and the maintainer's stance diverge.
- The maintainer's fallback is a one-line per-user preference in CLAUDE.md/AGENTS.md; native features remain the user's plumbing choice.

## Verified Quote(s)

**Location reference:** Sections "Why this is out of scope" paragraphs 1 and 2 of .out-of-scope/native-question-tool.md.

> The skills are harness-neutral text.

> Structured pickers push the model towards multiple-choice questions with pre-baked answers, which is the opposite of what grilling is for: open questions you answer in your own words, one branch of the decision tree at a time.

> I've tried the `AskUserQuestion` UI and don't want it in these skills.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Keep band. Supporting because it is the author's own policy, not external reception, but it is the clearest primary evidence on the native-features boundary.

**Redundancy check:** Unique; the user-side demand evidence is in the plan-mode HN comment card.

**Perspective category:** Practitioner
