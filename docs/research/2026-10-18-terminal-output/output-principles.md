# Output principles for terminal status screens

**Date:** 2026-10-18
**Question:** How to shape AI output so a human understands and acts on it, as testable rules for `borg next` and `borg link`.

## Executive summary

- Karpathy's post is real (X, 2026-10-02 00:37 UTC, standalone, 7.9M views). It is advice, not a study. It names a four-rung ladder: ASD-STE100 text, diagram, HTML page, explainer video. The Medium posts could not be fetched (403), so their attribution was not checked directly; the secondary coverage matches the tweet.
- STE is a real standard (Issue 9, Jan 2025, 53 rules, about 900 words). Sentence caps are 20 words (procedures) and 25 (descriptive). Evidence that it helps is thin and mostly old; it helps non-native readers on complex text.
- The strongest evidence for the screens comes from older, general sources: Few (glance, one screen), Nielsen/Norman (scanning, inverted pyramid, concise+scannable+objective), Leroy (ready-to-resume plans), Mark (interruptions cost time and stress).
- ADHD-specific switching evidence is mixed and task-dependent. No controlled study isolates terminal-to-browser cost. The "stay in the terminal" rule is a judgment backed by indirect evidence.
- Borg already applies tl;dr placement, front-loading and a brevity checklist (`brevity` skill, `design-doc` validator). It does not apply STE, a word list, a line cap, or a glyph vocabulary to the two screens.

## Findings

### 1. What Karpathy said
- Primary: X post https://x.com/karpathy/status/2105819303471976479, 2026-10-02 00:37 UTC, standalone, no thread (via fxtwitter mirror https://api.fxtwitter.com/karpathy/status/2105819303471976479) [2024-2026]. The mirror tool refused to reproduce the text verbatim (quote-length limit), so I have NO verbatim full text. I could not open x.com directly.
- Quotes attributed to him by secondary coverage (not verified against the tweet): "We'll be spending a lot more time trying to understand the outputs of language models." / "Instead of writing, ask your LLM to create a diagram." / "Ask for output 'in HTML' to get a beautiful, interactive webpage." / "Create a 3b1b style video explainer on X." Sources: https://explainx.ai/blog/karpathy-understand-llm-outputs-ste100-diagrams-html-video-2026 and https://searchenginejournal.com/karpathy-llm-aircraft-manual-writing/591813 [2024-2026].
- Content confirmed by the mirror summary: ask for ASD-STE100, or "80% of the way" to it because the full spec is stringent; diagrams are easier to process than prose; HTML gives interactive pages; custom explainer videos are what he is "most bullish on"; humans shift to "oversight and understanding".
- Embellishment check: https://themenonlab.blog/blog/asd-ste100-simplified-technical-english-prompting says nobody "released a new technique" and STE predates the reposters; no results or benchmarks were offered. Another summary says some people compared normal and STE answers and saw little difference on simple questions (https://www.aiposthub.com/karpathy-asd-ste100-ai-output-writing-diagrams-html-video/, unverified). Verdict: the claim is a personal anecdote. Anything presented as "Karpathy's research" is embellished.
- Medium posts: all three returned HTTP 403. Search found no trace of the levysoft "20 ways" post or the Inamdar post content. Their attribution is UNVERIFIED.

### 2. ASD-STE100 core rules
- asd-ste100.org returned 403, as did the ASD white paper. Rules below come from Wikipedia (https://en.wikipedia.org/wiki/Simplified_Technical_English) and Skybrary (via search snippet, https://skybrary.aero/articles/simplified-technical-english-ste) [2024-2026]. Rule numbers are NOT verified against the spec.
- Issue 9, January 2025: 53 writing rules, about 900 approved words; each word has one meaning and one part of speech. Free since Issue 6 (2013).
- Procedures: at most 20 words per sentence. Descriptive text: at most 25.
- One instruction per sentence. One topic per paragraph. At most 6 sentences per paragraph.
- Active voice preferred; passive only in descriptive text when the agent is unknown. Noun clusters of 3 words or fewer. Vertical lists for complex text. Safety instructions open with a clear command or condition. Use articles. Open procedures with an imperative verb.
- ASD white paper on AI (https://www.asd-europe.org/news-media/publications/asd-position-papers/asd-ste100-simplified-technical-english-and-artificial-intelligence-ai/, via search snippet): AI-written text can look STE-compliant without being compliant; the standard takes priority.
- Evidence it helps: a 1995 experiment (J. Technical Writing and Communication, found via search, not opened) found better comprehension on complex documents, same time, stronger for non-native readers but untested statistically. A 2025 corpus study says effectiveness is underexplored and simplification can remove comprehension cues (https://research.polyu.edu.hk/en/publications/the-case-of-english-for-aviation-maintenance-a-multi-dimensional--2/). Verdict: weak and old.

### 3. The four-level ladder
- Origin is Karpathy's tweet itself (finding 1): (1) ASD-STE100 text, (2) diagram, (3) HTML page, (4) explainer video. Inamdar's article could not be read. Evidence for the ladder: none beyond Karpathy's stated preference. It ranks richness of medium, and it is aimed at learning a topic, not at status triage. Karpathy reportedly warned that richer formats are harder to quality-check (aiposthub, unverified).
- Mapping fit: levels 3 and 4 need a browser or player, which breaks Noah's one-window rule. Only levels 1 and 2 (text, ASCII/box diagram) fit the terminal.

### 4. ELI5 and "20 ways"
- I found no study of "explain like I'm five" prompting. Related: LLMs can adjust reading level, but formulas misjudge it, and mid-level (high school) explanations often rated best, so "simplest" is not best (summary at https://www.promptlayer.com/research-papers/free-text-rationale-generation-under-readability-level-control; secondary, unchecked). Pre-registered human check of GPT-4 readability edits: https://ar5iv.labs.arxiv.org/html/2410.14028.
- Evidence-backed: controlling reading level and sentence length (measurable). Vibes: ELI5 persona, analogy, "explain like..." framing. The 20-ways list could not be read, so no per-technique verdicts.

### 5. Beyond the articles
- Dashboard / glance: Few defines a dashboard as the most important information for one or more objectives, on a single screen, monitored at a glance (2004 "Dashboard Confusion"; via https://dundas.com/resources/dundas-data-visualization-blog/does-everyone-know-what-a-dashboard-really-is) [pre-2020, foundational]. Text-only KPI dashboards are valid.
- Scanning and inverted pyramid: Nielsen: 79% of users always scanned new pages (https://www.nngroup.com/articles/how-users-read-on-the-web/); concise +58%, scannable +47%, objective +27%, combined +124% usability (Morkes and Nielsen 1997, one site, small sample; https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/); inverted pyramid lets readers stop anywhere (https://www.nngroup.com/articles/inverted-pyramid/) [pre-2020]. Applies to web reading; transfer to terminal is an assumption.
- Progressive disclosure: I found only a low-authority claim that empirical evidence is limited (Carroll and Rosson). Treat as design convention, not measured.
- Mark: 2008 CHI study (https://www.ics.uci.edu/~gmark/chi08-mark.pdf): interrupted people finish faster with no quality loss but report more stress, frustration, time pressure and effort [2020-2023 or older]. The "23 minutes 15 seconds" figure is widely repeated; I could not trace it to a primary paper. Mark's 47-second screen-switch figure comes from a 2016 study of 90 workers (secondary only).
- Leroy 2009, Organizational Behavior and Human Decision Processes 109:168-181: unfinished tasks leave attention residue that hurts the next task. Leroy 2018 (Organization Science): a "ready-to-resume" plan reduces the effect (via search; abstracts not opened). Supports leaving a resume line on the screen.
- ADHD: adult studies are mixed. Slower switching appears when the switch also changes attentional set (2018 study, 38 adults vs 39 controls, https://behavioralandbrainfunctions.biomedcentral.com/articles/10.1186/s12993-018-0150-y); some studies show no larger switch cost, and voluntary-switching results conflict. Working-memory deficits are reported in meta-analyses (Kasper, Alderson and Hudec 2012), though Kofler 2016 argues many tasks measured short-term storage. Verdict: do not claim "ADHD makes switching cost X"; claim "keep what must be held in mind small".
- Terminal vs browser cost: no controlled study found. Closest: window-switching is slow (https://arxiv.org/pdf/1810.04673, Windows 7, 2018); a 2020 industry replication found multitasking volume did not clearly predict lower output (https://arxiv.org/abs/2006.12636v1). Vendor figures (559 switches/day, 20-80% loss) have no primary source; ignore.

### 6. Rules for the two screens
E = evidence-backed (indirect), J = judgment. Thresholds are starting values to tune, and each is a mechanical test.

1. Verdict first (E: inverted pyramid, front-loaded gaze). Line 1 holds one state word plus one sentence. Test: line 1 contains a verdict token from a fixed set.
2. Landing region (J, from borg's own viz-1 finding). The verdict sits where the terminal eye lands: bottom for chat, top for a rendered screen. Test: position is the same on every run.
3. One next action (E: Mark and Leroy on cost of open loops; J on count). Exactly one line starts with the action marker, in imperative form with the literal command. Test: count equals 1.
4. One action per line (E: STE one instruction per sentence). Test: no line has two imperative verbs joined by "and" or ";".
5. Line cap (E: Few single screen; J on numbers). `borg next` at most 15 lines for 5 items; `borg link` at most one terminal screen (24 rows, ideally 40 lines in a tall pane). Test: `wc -l`.
6. Fixed row shape (J). Each row: glyph, id, owner, readiness, one clause. Columns align. Test: regex on every row.
7. Fixed glyph vocabulary (J). At most 6 glyphs, each with one meaning, defined in a legend line. Test: glyphs outside the set fail. Never rely on colour alone (J).
8. Controlled words (E partial: STE one word, one meaning). Statuses come from a closed list (ready, blocked, waiting, done, review). A synonym for a status word fails. Test: grep against the list.
9. Sentence cap 20 words, 25 for descriptions (E: STE). Rows count as sentences. Test: word count per line.
10. Active voice, present tense, imperative for actions (E: STE). Test: lint for "is/are/was + participle" in action lines; accept false positives.
11. Name the blocker with its owner and the unblocking action (J). Test: every "blocked" row has an owner and a "by" clause.
12. Resume line (E: Leroy 2018). `borg link` ends with one "pick up here" line naming where work stopped. Test: line exists.
13. Ladder maps to surfaces (J, adapted from Karpathy): one line (status/verdict) -> card (a `borg next` row expanded) -> detail (`borg link` board) -> full doc opened in the nvim side pane. Rungs 3 and 4 of Karpathy's ladder (HTML, video) are excluded because they leave the terminal. Test: every row ends with a handle that expands to the next rung.
14. Stay in the terminal (J; indirect E from Mark and Leroy). No screen requires a URL to act. Links are allowed as extras. Test: the action line contains no URL.
15. Do not flatten trade-offs (J, taken from borg's brevity skill). A real two-sided choice gets a sentence per side plus the verdict.
16. STE as lint, not as law (J: 80% of STE, per Karpathy; ASD warns that AI text can fake compliance). Check with the scripted rules above, not by asking the model whether it complied.

## What borg already applies (item 7)
- Communication program umbrella: /Users/noah/dev/borg-collective/docs/plans/directives/2026-08-20-communication-program.md. It covers three layers (standards, delivery surfaces, derived data), tl;dr at the bottom of chat, docs in the side pane, brevity "distilled from the Google developer style guide and Smart Brevity", and a rejection of web dashboards. It contains no STE, no word list, no line cap, no glyph set.
- The `brevity` skill: /Users/noah/dev/claude-plugins/noah-writing-voice/skills/brevity/SKILL.md. tl;dr at the top for documents and at the bottom for chat, two lines or fewer; front-load the one thing; exactly one why-it-matters line; banned-word grep; a document length marker around 1,500 words; "never flatten a real trade-off"; and a numbered checklist.
- `design-doc` skill and validator: /Users/noah/dev/claude-plugins/noah-content-tools/skills/design-doc/ (validate.sh plus fixtures). Also `pr-description`.
- `borg-link` skill (/Users/noah/dev/borg-collective/skills/borg-link/SKILL.md and references/rationale.md, queen-view.md) uses tl;dr only as a checkpoint-summary source; it has no row-shape or cap rules in the grep results.
- Grep for "STE", "Simplified Technical English", "ASD-STE100" and "BLUF" across /Users/noah/dev/borg-collective/skills and /Users/noah/dev/claude-plugins returned zero matches. (The `\bSTE\b` grep returned no hits; the broader tl;dr grep hit the files above.) I did not search borg_core Python or `lib/` for line-cap or glyph logic, so a hidden renderer limit is possible; the link renderer docs at borg_core/link/CLAUDE.md were not read.

## Evidence gaps and uncertainties
- All three Medium posts, asd-ste100.org, the ASD white paper and skybrary returned 403. Dedicated STE rule numbers are unverified.
- No verbatim tweet text; secondary quotes are unchecked against the original.
- No ELI5 or 20-ways evidence; no terminal-vs-browser measurement; ADHD switching evidence is mixed; the 23-minute figure is not traced.
- Rule thresholds in section 6 are judgment values; none has been tested on Noah's screens.

## Paywalled must-reads
- Leroy 2009 (OBHDP 109:168-181) and Leroy and Glomb 2018 (Organization Science): not opened; abstracts only via search. Access: author page at https://www.uwb.edu/business/faculty/sophie-leroy or an institutional library.

## Sources index
- [1] Karpathy X post (mirror) - https://api.fxtwitter.com/karpathy/status/2105819303471976479 (2026-10, 2024-2026 |)
- [2] Search Engine Journal on Karpathy - https://searchenginejournal.com/karpathy-llm-aircraft-manual-writing/591813 (2026-10, 2024-2026 |)
- [3] explainx on Karpathy - https://explainx.ai/blog/karpathy-understand-llm-outputs-ste100-diagrams-html-video-2026 (2026-10, 2024-2026 |)
- [4] Menon Lab on STE prompting - https://themenonlab.blog/blog/asd-ste100-simplified-technical-english-prompting (2026, 2024-2026 |)
- [5] aiposthub summary - https://www.aiposthub.com/karpathy-asd-ste100-ai-output-writing-diagrams-html-video/ (2026, 2024-2026 |)
- [6] Wikipedia STE - https://en.wikipedia.org/wiki/Simplified_Technical_English (2025, 2024-2026 |)
- [7] Skybrary STE (snippet only) - https://skybrary.aero/articles/simplified-technical-english-ste (n/d, n/d |)
- [8] ASD STE and AI position - https://www.asd-europe.org/news-media/publications/asd-position-papers/asd-ste100-simplified-technical-english-and-artificial-intelligence-ai/ (n/d, n/d |)
- [9] Aviation maintenance STE corpus study - https://research.polyu.edu.hk/en/publications/the-case-of-english-for-aviation-maintenance-a-multi-dimensional--2/ (2025, 2024-2026 |)
- [10] NN/g How Users Read on the Web - https://www.nngroup.com/articles/how-users-read-on-the-web/ (1997, pre-2020 |)
- [11] NN/g Concise, Scannable, Objective - https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/ (1997, pre-2020 |)
- [12] NN/g Inverted Pyramid - https://www.nngroup.com/articles/inverted-pyramid/ (n/d, n/d |)
- [13] Few dashboard definition (via Dundas) - https://dundas.com/resources/dundas-data-visualization-blog/does-everyone-know-what-a-dashboard-really-is (n/d, pre-2020 |)
- [14] Mark, Gudith, Klocke CHI 2008 - https://www.ics.uci.edu/~gmark/chi08-mark.pdf (2008, pre-2020 |)
- [15] Leroy 2009 (via faculty page) - https://www.uwb.edu/business/faculty/sophie-leroy (2009, pre-2020 |)
- [16] Adult ADHD attentional set shifting - https://behavioralandbrainfunctions.biomedcentral.com/articles/10.1186/s12993-018-0150-y (2018, 2020-2023 or older |)
- [17] Hidden Cost of Window Management - https://arxiv.org/pdf/1810.04673 (2018, 2020-2023 or older |)
- [18] Developer multitasking replication - https://arxiv.org/abs/2006.12636v1 (2020, 2020-2023 |)
- [19] borg communication program - /Users/noah/dev/borg-collective/docs/plans/directives/2026-08-20-communication-program.md (2026-08-20, local |)
- [20] brevity skill - /Users/noah/dev/claude-plugins/noah-writing-voice/skills/brevity/SKILL.md (2026, local |)
