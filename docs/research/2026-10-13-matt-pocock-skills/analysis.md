Generated: 2026-10-13
AI-scoring: 84/100

# Matt Pocock and His Skills Library: What It Is, What People Say, and How It Compares to borg, Claude Code's Native Features, and Cortex Code CLI

*Conducted: 2026-10-13 | Methodology: deep-research v1 (hybrid mode, full tier)*

---

## Glossary: read this first

Every term below is also defined inline where it first appears in the body.

- **Skill (SKILL.md)**: a folder holding a markdown file of instructions that a coding agent loads on demand. The file format is called Agent Skills.
- **Agent Skills open standard**: the shared file format for skills, started by Anthropic and now read by many tools (Claude Code, Codex, Cursor, Gemini CLI, Cortex Code CLI, and others).
- **Harness**: the program around the model (Claude Code, Codex, Cortex Code CLI). It runs tools, spawns subagents, and decides what is enforced.
- **Grilling (grill-me)**: a skill that makes the agent interview you, one question at a time, before any plan or code exists.
- **Vertical slice / tracer bullet**: a small piece of work that cuts through every layer (data, logic, screen) and can be demoed alone, as opposed to finishing one layer at a time.
- **AFK / HITL**: "away from keyboard" (an agent works alone) versus "human in the loop" (a person is needed).
- **Frontier**: the set of tickets whose blockers are all done, so they can start now, in parallel.
- **Worktree**: a second checked-out copy of a git repo on its own branch, so parallel agents do not trample each other's files.
- **Hook**: a script the harness runs at set moments (before a tool call, at session start). Hooks enforce rules; instruction files only suggest them.
- **borg (borg-collective)**: Noah's tool for running about 20 projects from tmux: a queen (orchestrator) session, one drone (per-project) session each, locked acceptance criteria, verifier and blind-reviewer gates, checkpoints.
- **Evidence level (L1 to L9)**: how rigorous a source's method is; L1 is a systematic review, L9 is marketing. Defined fully in §6.
- **Score band (keep / borderline / reject)**: the three-bucket credibility result from the 10-dimension source rubric.

Other acronyms (PRD, TDD, ADR, MCP, HN, PR, RCT, DORA, METR, SDD) are expanded where they first appear.

---

## 1. Recommendations

Each bullet names the §4 section that backs it. The commands in the Cortex bullet are untested in this run.

- **Keep borg as the control layer and treat Matt's skills as a source of ideas, not a replacement.** His repo explicitly has no cross-project, session-visibility, gating, or deploy layer, and he declines harness-level concerns on purpose. Backing: §4.3, §4.5.
- **Add a per-ticket AFK/HITL label to borg stacks** (his `ready-for-agent` versus `ready-for-human`), because it answers "can I leave this alone?" at a glance and fits the WAITING ON YOU view. Backing: §4.4.
- **Test a "what can I demo when this is done?" check, plus a completeness check for the whole breakdown, inside /borg-plan.** His own tracker shows the slicing rule is not self-enforcing (layer-named slices pass, and the quiz step rubber-stamps). borg's locked Verify: criteria can be made to fail at the starting commit, which his docs recommend but do not enforce. Backing: §4.4.
- **Write regression checks for the three planning-state failures reported on his repo**: finished tickets never closed, two sessions claiming the same ticket, and resolved decisions that leave stale premises in open tickets. Ask of borg stacks: does /borg-assimilate close the entry, can two drones claim one item, does a locked decision update its dependents. Backing: §4.4.
- **Keep investing in what he lacks: a stop rule with review dates, status history, value ranking, and delivery numbers.** He covers none of the five PM gaps from borg's own build/adopt/outsource research in full, and the one randomized trial in the corpus shows self-reported speed-ups are unreliable, so measurement matters. Backing: §4.4.
- **Pilot a grilling pass before criteria are locked, and measure it.** Run it on two or three projects for about six weeks against the six delivery numbers; no outcome study of the grill-spec-slice chain exists anywhere, so this is the only way to know. Backing: §4.2, §4.4.
- **Do not install his full pack next to borg skills without a name audit.** His `/code-review` and `/prototype` already collide with Claude Code built-ins, and skill-library research finds that overlapping descriptions cause selection failures. If you trial any of it, use user-invoked skills only and call them namespaced. Backing: §4.5.
- **Use native primitives for plumbing where they now fit.** Dynamic workflows, `isolation: worktree`, and `/batch` cover what his `implement-spec` describes in prose; agent view is a research preview, so adopt it read-only and do not depend on it. Agent teams (experimental, one team per session) do not replace persistent drones. Backing: §4.5.
- **Treat Sandcastle as a watch item, and spike it only if borg needs container isolation for unattended runs.** It is a small TypeScript library with no independent reviews found. Backing: §4.1, §4.5.
- **Add evals to borg's own skills.** His repo ships none, a competitor's repo does, and Anthropic's authoring guide says to write evaluations first. That is a cheap differentiator. Backing: §4.2, §4.5.
- **At work, try the Cortex Code CLI route in a scratch directory, and expect only the prose skills to port.** Try `npx skills@latest add mattpocock/skills -a cortex`, then run `/skill list` to see what loaded. Check that user-invoked skills are not auto-triggering, because whether Cortex honors `disable-model-invocation` is undocumented. Keep Claude Code and borg as the orchestrator and consider Snowflake's own routing skill for Snowflake-only work. Backing: §4.6.
- **Date every star, install, and skill count you cite.** They range from 54,000 to 289,000 stars and 21 to 53 skills depending on the source and day. Backing: §4.1, §4.2.
- **Re-check this space in about 90 days.** The repo went from v1.0.0 to v1.3.1 in under four months and shipped breaking renames as minor versions. Backing: §4.1.

---

## 2. Summary

NO PRIMARY EVIDENCE — all findings are literature-derived predictions

**What was researched.** Noah asked for "all of the things" about Matt Pocock and his skills library: what the thing is, what practitioners say, how it compares to borg, what his project-management (PM) approach looks like, how it stacks against Claude Code's native features, and whether it matters for the Cortex Code CLI (Snowflake's Claude-Code-like tool, which he uses at work). The run read 98 source cards from five parallel tracks, scored them, and cut 8. Distinct sources: 85, of which 79 survive.

**What it is.** `mattpocock/skills` is a curated, MIT-licensed personal kit of about 27 skills that Matt says he uses every day. It is not a framework: the README names GSD, BMAD, and Spec-Kit as tools that "own the process" and take away control, and says the opposite is intended. On 2026-10-13 it had 289,479 stars and 24,301 forks, was created 2026-02-03 (not April; April was the viral moment), and had reached v1.3.1. One author wrote 499 of 545 commits. The skills split into user-invoked ones you type (grill, spec, tickets, triage) and model-invoked ones the agent calls (tdd, diagnosing bugs). The core flow is: grill yourself, write a short spec in the issue tracker, cut it into tracer-bullet tickets with blocking links, implement each in fresh context, review, run a retro. His paid business (AI Hero cohorts and courses) sits beside a free repo and newsletter. Sandcastle is a separate, much smaller TypeScript library (8,418 stars) that runs agents in containers on their own branches.

**What people say.** Warm but thin on measurement. Reviewers agree on one framing: Superpowers is a framework that injects itself through a hook; Pocock's pack is a toolkit you drive. There is real dissent, but little of it is evidence: a Hacker News thread (43 points) says skills like this are personal and might be one AGENTS.md file; a September issue on his repo says the skills now add work, and the maintainer closed it as not planned. The only quantitative third-party work measures install cost (about 1,030 always-on tokens), not output quality. Independent benchmarks on skills in general are mixed: curated, focused skills help (+16.6 percentage points), but 39 of 49 generic public software skills gave no gain, and process-heavy skills can turn checklists into mandatory work. None of those studies tested his pack.

**Matt versus borg.** They are different layers. His kit shapes how one session works. borg manages many sessions across many projects: what is next, what is waiting on Noah, what is locked, what passed a blind review. Where they touch, he is ahead on AFK/HITL labels and the demo-test slice check; borg is ahead on locked acceptance criteria, gates, cross-project visibility, and checkpoints. His tracker also shows three failures borg should test itself against (tickets never closed, double-claimed tickets, stale premises). One tension deserves a plain statement: his README criticizes tools that enforce a process, and borg enforces more than he does. That is a difference in purpose, not a flaw; borg's job is to keep Noah aware across 20 repos.

**Matt versus native Claude Code.** Native features now cover most of the mechanics his orchestration skills describe in prose: background subagents, worktree isolation, `/batch`, dynamic workflows, agent view, cross-session messaging. They do not supply his process (grilling, shared glossary, vertical-slice tickets, triage labels), and they do not supply borg's control layer either. His own policy files say skills are plain text that ride native improvements but cannot assume them.

**Matt and Cortex Code CLI.** Cortex natively reads the Agent Skills format and even looks in `.claude/skills`, and the `skills` installer has a first-class Cortex target. But no one has been found using his pack there, and the install was not tried. Prose skills should port; tracker-coupled ones (tickets, triage) and Claude-specific ones (hooks, "call the Skill tool") will not port cleanly.

**Testability.** The questions about what the repo is, its numbers, and how it compares to native features were cheaply testable by reading primary sources, and they were. The question of whether his grill-spec-slice chain improves delivery outcomes is declared untestable inside this run: it needs weeks of real delivery data on real projects. The Cortex port question is cheaply testable (one install in a scratch directory) but no direct-observation artifact exists yet, so it is surfaced here as untested. One randomized trial (METR, Level 2) is in the corpus; it is general to AI tooling, not to Matt, so it is not primary evidence about his skills.

**Where experts agree, disagree, and what surprised us.** They agree on the invoke-versus-inject split and on the repo's fast growth. They disagree on whether imported process skills help at all. Surprises: the star count is 289,000 but Anthropic's own marketplace counter reads 1,745 installs; Matt's own marketing page still lists skill names he renamed in July; and his repo has no evals.

**The one thing to remember.** Matt's library and borg are not rivals: his sits under one session and borg sits over twenty. The useful question is which of his small ideas (AFK/HITL labels, the demo check, the three failure cases) are worth stealing into borg, and the honest answer is "test them and measure".

---

## 3. Three Layers: Mechanics, Process, Control

This framework is the researcher's synthesis. No source states it, but every element below is grounded in the cited cards.

| Layer | What it owns | Who fills it |
|-------|--------------|--------------|
| Mechanics | Subagents, worktrees, scheduling | Claude Code native |
| Process | Grilling, spec, slicing, TDD | Matt's skills |
| Control | Cross-project next, gates, deploy | borg |

- **Mechanics** are runtime features. Claude Code documents background subagents, `isolation: worktree`, `/batch` (5 to 30 worktree-isolated subagents), dynamic workflows, agent view, and cross-session messaging [native-parallel-agents-overview; native-subagents; native-commands-bundled-skills; native-dynamic-workflows]. Native skills are "plumbing, not process" [native-claude-skills-docs].
- **Process** is the instruction layer. His skills describe how to align, spec, slice, and review, in plain text with no runtime [native-pocock-skills-readme; pm-repo-ask-matt-router].
- **Control** is the layer that knows about many projects and enforces. His README has no session-visibility, cross-project, or deploy layer [native-pocock-skills-readme]; native agent view has no cross-project ordering, acceptance criteria, or "what is next" [native-agent-view]. A user of his pack on Hacker News built their own staleness tracking and governance gates on top, which is evidence that demand for this layer exists [reception-hn-comment-ceremony-fast-lane].
- **How it compares to existing frameworks.** Martin Fowler's site places PRD-first workflows (PRD: product requirements document, such as his `/to-spec`) in the "spec-first" tier of spec-driven development (SDD), ahead of "spec-anchored" and "spec-as-source" [pm-fowler-boeckeler-sdd-tools]. The layer model is different: it sorts by who owns the concern, not by how long the spec lives.
- **Limits.** The boundaries leak. Matt's `implement-spec` sits across Process and Mechanics, because it describes a worktree fan-out that native features now do [native-pocock-implement-spec]. borg's gates also sit across Control and Mechanics. The model is a sorting aid, not a theory.
- **How to apply it.** For any feature under consideration, ask which layer owns it. Adopt native for Mechanics, borrow ideas for Process, keep Control in borg.

---

## 4. Analysis

Source keys in brackets are card file names without the `mp-` prefix and `.md` suffix. Section 5 lists each with its score band and evidence level.

### 4.1 What it is: the skills repo, Sandcastle, AI Hero, and Matt's philosophy

**Research question:** What is `mattpocock/skills` today, what are Sandcastle and AI Hero, and what does Matt say he believes?

**What the evidence says:** The repo is a personal kit, not a framework. The README catalogues 27 skills, split on one axis: who may invoke them (user-invoked orchestrators versus model-invoked disciplines) [what-skills-readme]. SCOPE.md closes new-skill contributions and calls the set "the skills I use every day"; it declines harness-level concerns such as subagent recursion guards and native question tools [what-skills-scope-out-of-scope]. Live GitHub data on 2026-10-13 shows 289,479 stars, 24,301 forks, MIT licence, created 2026-02-03, tagged releases v1.0.0 (2026-06-17) through v1.3.1 (2026-10-04), and four listed contributors, with the owner at 499 of 545 commits [what-github-api-metadata]. The to-tickets lead from the novelty probe is verified with corrections: v1.1.0 (PR 464, merged 2026-07-08) renamed `to-prd` to `to-spec` and merged `to-plan` and `to-issues` into `to-tickets`; v1.3.0 (2026-10-04) added `implement-spec`, `pr`, and `retro`, renamed `CONTEXT.md` to `GLOSSARY.md`, and removed `resolving-merge-conflicts` [what-skills-changelog; pm-repo-changelog]. `to-tickets` writes tracer-bullet vertical slices with blocking edges, and any ticket whose blockers are done sits on the frontier, so several agents can run at once [pm-repo-to-tickets-skill].

Sandcastle (npm `@ai-hero/sandcastle`, 8,418 stars, created 2026-03-17, latest 0.12.0) is a TypeScript library: one `run()` call sandboxes an agent in Docker, Podman, or a Vercel microVM (or no sandbox), applies one of three branch strategies, and merges commits back [what-sandcastle-readme; what-github-api-metadata]. It is code-level orchestration for parallel AFK work.

His philosophy, from two conference talks, an interview, and his posts: agents are memoryless "new starters", so fundamentals matter more than ever (shared glossary language, vertical slices, tests or proof of working, deep modules) [what-aie-fundamentals-talk; what-aihero-five-skills-post]. Skills should be short, user-invoked by default, and pruned with a deletion test; he names the failure "skill hell" [what-aie-agent-skills-talk]. Fresh context per task keeps the agent in the "smart zone", which is also why he rejects Anthropic's Ralph loop plugin, a native feature that re-feeds the prompt into one session [what-aihero-ralph-plugin-post]. He has mixed feelings about TDD (test-driven development: write the failing test first) with agents and is moving his work to cloud agents [what-pragmatic-engineer-interview].

AI Hero monetization: the repo and the newsletter (about 60,000 readers per the README) are free; the paid layer is cohorts and courses. Total TypeScript, his earlier business, is reported at over 2.5 million dollars in sales [what-pragmatic-engineer-interview; what-skills-readme]. The cohort page is a sales page with no verifiable price and was excluded [what-aihero-cohort-page].

**Where sources agree:** The repo is curated, single-author, fast-moving, and positioned against process-owning frameworks [what-skills-readme; native-pocock-skills-readme; reception-kaizen-critical-guide].

**Where sources disagree:** Counts and dates. Stars read 54,000 to 289,000 depending on date; the "late April" launch is the viral moment, not creation; skill counts are 21 on Anthropic's listing, 25 in the plugin manifest, 37 on disk, 53 in the skills.sh index, and 27 in the README [what-github-api-metadata; reception-varops-sizing-pack; what-claude-marketplace-listing; what-skills-readme]. Matt's own AI Hero page still lists the pre-v1.1 names `/to-prd` and `/to-issues` and a different Claude Code install command from the README [what-aihero-skills-catalogue]. The "18 million installs" figure is unverified; Anthropic's counter reads 1,745 [reception-claude-marketplace-listing].

**What's missing:** No independent hands-on Sandcastle review. No AI Hero price. The full Pragmatic Engineer transcript and the v1.1 video were not retrieved.

**Institutional vs. ground truth:** The institutional surfaces (marketplace listing, Matt's marketing page) lag the repo; the repo and its changelog are the only reliable record.

### 4.2 What people in the industry are saying

**Research question:** How has the pack been received, and is there evidence on whether it works?

**What the evidence says:** Reception is warm and descriptive. The strongest consistent theme is the invoke-versus-inject split: Superpowers injects a SessionStart hook that mandates a skill check, while Pocock's pack has no hook and fires on explicit call or description match [reception-nocoders-superpowers-vs-pocock; reception-zenn-superpowers-vs-pocock; reception-devto-yim-review]. One switcher deleted the Superpowers hooks because they "overcomplicated simple problems" and reports lower token use, unmeasured [reception-glean-switching-from-superpowers]. A distinguishing feature is cross-session artifacts (`CONTEXT.md`, ADRs (architecture decision records), issues) [reception-zenn-superpowers-vs-pocock]. The most-cited gateway skill is grilling; one Hacker News (HN) user uses it instead of Claude Code's plan mode and forked it to use the native question tool, which the maintainer's policy file declines [reception-hn-comment-plan-mode-replacement; reception-repo-out-of-scope-native-question-tool].

Measurement is thin. VarOps sized the pack: always-on cost is about 1,030 tokens (about 0.5 percent of a 200,000-token window), but bodies total about 28,800 tokens and three skills carry about 8,500, and the author ran no agent and makes no quality claim [reception-varops-sizing-pack]. The academic work is general: SkillsBench finds curated, focused skills raise pass rate from 33.9 to 50.5 percent and that bundles of up to three modules beat larger ones [reception-skillsbench-arxiv]; SWE-Skills-Bench finds 39 of 49 public software skills gave zero improvement, with a +1.2 percent average and up to +451 percent token cost [reception-swe-skills-bench-arxiv]; a third study finds skills "often turn validation checklists and construction recipes into mandatory work" [reception-skill-induced-failures-arxiv]. A workshop paper reports up to a 21 percent drop at 202 skills, driven by selection failure [native-skill-shadowing-icml]. None tested Matt's pack; applying them to it is inference.

Dissent, in rising order of evidentiary weight: a HN thread (43 points, 14 comments) says such skills are personal, one AGENTS.md may do, and imported rules cause hidden behavior [reception-hn-ai-coding-agent-skills-thread]; an issue on his repo (opened 2026-09-11, closed not planned 2026-10-07) says the skills now add work, `ask-matt` routes inconsistently, and `diagnosing-bugs` fires in non-coding chats, with a second user agreeing [reception-github-issue-1071-skill-bloat]; Kaizen Craft's critical guide cites open issues on TDD attention dilution and unverified review subagents [reception-kaizen-critical-guide]; Every argues skills have a shelf life as models improve, with one regression anecdote [reception-every-case-against-skills]; a structured May critique says the install model has no lockfile, dependency declaration, or security review (now partly dated, since tagged releases exist) [what-mcp-directory-npm-moment]. A vendor founder argues skills are "an expensive form of RAG" without data [native-chatbotkit-skills-expensive-rag]. A peer maintainer says his repo ships no in-repo evals and is "Define and Build heavy" [reception-addy-agent-skills-compare; native-agent-skills-comparison-doc].

**Where sources agree:** The hooks-versus-manual split; the lack of evals; the stack bias in the original set (TypeScript, GitHub, Husky), partly fixed by local-markdown and GitLab support [reception-kaizen-critical-guide].

**Where sources disagree:** Whether process skills help or hurt. Curated skills help on average (SkillsBench), generic public ones mostly do nothing (SWE-Skills-Bench), and the effect depends on model generation (Every). The evidence is mixed, and no source resolves it for this pack.

**What's missing:** Any outcome test of this pack. Reddit and X were unreachable. No usable direct comparison against Compound Engineering, BMAD, or Spec-Kit beyond his README's own positioning. The "grill-me is prior art, promoted by marketing" critique rests on one unsourced comment and was excluded [reception-hn-comment-prior-art-marketing].

**Institutional vs. ground truth:** Marketing and blogs report star counts and "saves tokens"; ground truth is a small install cost, a lumpy body cost, and no output-quality evidence either way. Users who like it still borrow only the shape of a few skills [reception-devto-yim-review].

### 4.3 Matt's stuff versus borg

**Research question:** How do the pack and borg relate? This question had no dedicated track; the comparison is the researcher's synthesis of the cards below and borg's internal research.

**What the evidence says:** They sit at different layers (§3). The pack shapes one session: its README lists grilling, shared language, feedback loops, and design depth, and has no session-visibility, cross-project, or deploy layer [native-pocock-skills-readme]. Dispatch is manual: no auto-dispatch exists, you count unblocked tickets, open that many fresh sessions, and update ticket state yourself [pm-aihero-to-tickets-docs]. His `implement-spec` closes with a single code-review pass; borg adds locked acceptance criteria and a blind reviewer [native-pocock-implement-spec]. The pack leaves enforcement to the user's instruction files and hooks [native-memory-claude-agents-md; reception-nocoders-superpowers-vs-pocock].

Where he is ahead: AFK/HITL labels on tickets and issues (`ready-for-agent` versus `ready-for-human`, and HITL/AFK on wayfinder tickets) [pm-repo-triage-skill; pm-repo-wayfinder-skill], and the demo check for slices [pm-aihero-to-tickets-docs]. His wayfinder map (a tracker issue that indexes decision tickets, for work bigger than one session) is the structural analogue of a borg stack [pm-repo-wayfinder-skill]. Where borg is ahead: locked acceptance criteria, gates, a cross-project view, checkpoints. His docs themselves warn that acceptance criteria can pass before any work is done [pm-aihero-to-tickets-docs].

**Where sources agree:** Both use fresh context per unit of work and keep planning state outside the chat (his tracker, borg's directives and manifests). That overlap is inference from the cards.

**Where sources disagree:** There is a philosophical tension, and a real one. His README says process-owning tools "take away your control" [what-skills-readme]. borg is a process-owning control layer. The resolution is purpose: his kit serves one developer in one repo at a time; borg exists to manage the chaos across about 20.

**What's missing:** No third party compares the pack with a multi-session control layer. His planned direction (cloud agents, "multiplayer" sessions [what-pragmatic-engineer-interview]) could move toward borg's ground; his wayfinder already drifts toward multi-session orchestration through trackers [native-agent-skills-comparison-doc].

**Institutional vs. ground truth:** The pack's own docs admit manual dispatch and an unreliable done-signal, which is where the control layer earns its keep.

### 4.4 Matt's PM approach, and how it compares to borg's PM research

**Research question:** How does he plan and track work, and how does that compare to borg's PM research (the pillars audit in PR #252, scored 14 of 24, and the build/adopt/outsource decision in PR #262: enforce first, measure second, with a stop rule, review dates, status history, and six delivery numbers)?

**What the evidence says:** His method is a chain: grill (human alignment), spec in the tracker (`to-spec`), tracer-bullet tickets with blocking edges (`to-tickets`), implement with test-first development, fresh-context review, retro [pm-repo-ask-matt-router; pm-aiengineer-workflow-talk-2026]. Planning state lives in the issue tracker: a five-state triage machine, native blocking links, and a wayfinder map issue as index [pm-repo-triage-skill; pm-repo-wayfinder-skill]. HITL versus AFK is split by phase: alignment is HITL, build is AFK; he concedes he has no complete answer to review burden [pm-aiengineer-workflow-talk-2026].

Against borg's five PM gaps, he covers none fully:

| Gap borg is closing | Matt's coverage |
|---------------------|-----------------|
| Stop rule | Partial: wontfix, notes |
| Value ranking | None: blocking order |
| Status history | None |
| Debriefs | Partial: retro |
| Delivery numbers | None |

- **Stop rule:** per-item `wontfix` with an `.out-of-scope` memory, a wayfinder out-of-scope section, and doc-rot closing; no review date, lapse, or time budget [pm-repo-triage-skill; pm-repo-wayfinder-skill; pm-aiengineer-workflow-talk-2026]. Shape Up's appetite (fixed time, variable scope) has no counterpart [pm-shape-up-set-boundaries].
- **Value ranking:** none; order comes only from the blocking graph [pm-repo-to-tickets-skill].
- **Status history:** none found in the skills or the talk; state is the current label on each issue [pm-repo-triage-skill].
- **Debriefs:** `retro` changes the agent's environment, not the plan, and has no action closure [pm-repo-ask-matt-router].
- **Delivery numbers:** no DORA-style (DevOps Research and Assessment) metrics in the repo or talk [pm-dora-2025-ai-amplifier].

The weak spot is the write points on planning state. Three reports on his repo: finished tickets are not closed, so the frontier goes stale [pm-issue-508-implement-no-completion]; two sessions resolved the same wayfinder ticket one second apart because a claim by assignee is invisible when sessions share one human [pm-issue-476-wayfinder-claim-concurrency]; a decision that removed a concept left four open tickets describing the old design [pm-issue-828-wayfinder-stale-premises]. The slicing rule is not self-enforcing either: layer-named slices can each look reasonable, and the quiz step rubber-stamps a pre-authored plan [pm-issue-310-to-tickets-rubber-stamp]. His docs report a 26-ticket layer-sliced case costing about twenty agent runs per closed ticket, but it is unnamed and unverified [pm-aihero-to-tickets-docs].

Relation to established methods: tracer bullets come from The Pragmatic Programmer, whose authors framed them against up-front specification [pm-aihero-tracer-bullets-article; pm-artima-hunt-thomas-tracer-bullets]. PRD-first is spec-first in Boeckeler's taxonomy and exposed to the "Waterfall strikes back" critique, though a short spec after a live interview plus vertical slices softens it; that mapping is the researcher's [pm-fowler-boeckeler-sdd-tools; pm-marmelab-sdd-waterfall].

**Where sources agree:** The vertical-slice rationale is sound and the chain is long for small changes: a third-party post concedes it pays off only when work must survive several sessions [pm-contextstudios-pocock-workflow]; an HN user built a fast lane and a full lane [reception-hn-comment-ceremony-fast-lane].

**Where sources disagree:** Asset or Waterfall relapse (Matt versus Marmelab and Boeckeler). The evidence is mixed.

**What's missing:** An outcome study of the chain. The nearest hard evidence is METR (Model Evaluation and Threat Research), a randomized controlled trial (RCT) where experienced developers took 19 percent longer with AI while believing they were 20 percent faster [pm-metr-ai-slowdown-rct]. It does not test his workflow, but it supports measuring instead of self-reporting.

**Institutional vs. ground truth:** His talk and docs describe a tidy chain; the issue tracker shows where state goes stale. DORA's headline, that AI amplifies an organization's existing strengths and weaknesses, argues that the system around the tools matters more than the tools [pm-dora-2025-ai-amplifier].

### 4.5 Matt's stuff versus new Claude native features

**Research question:** Which of his skills do native Claude Code features replace, and which do they leave alone?

**What the evidence says:** Native features now supply most of the mechanics. Claude Code has five parallelism approaches (subagents, agent view, agent teams, cloud projects in beta, dynamic workflows) plus worktrees, cross-session messaging, and `/batch` [native-parallel-agents-overview]. Subagents get `isolation: worktree` [native-subagents]; a dynamic workflow is a script holding the plan, resumable, shippable in plugins, with a usage-limit wait [native-dynamic-workflows]. His `implement-spec` has the model manage the task-graph frontier in prose, with implementers in worktrees and a merger subagent; the mechanics are native, the ticket-graph process is not [native-pocock-implement-spec].

The process layer is largely untouched. Native `/plan` has no pre-plan interview, which grilling fills (one advocate argues this; no controlled comparison) [native-commands-bundled-skills; native-questionpro-grill-vs-plan-mode]. Native `/code-review` reviews for correctness bugs; his is a two-axis Standards-and-Spec review; the names clash, and his repo records issues about it and answers with namespaced invocation [native-commands-bundled-skills; native-pocock-out-of-scope-harness]. His split of user-invoked versus model-invoked rides the native `disable-model-invocation` flag [native-claude-skills-docs]. The same flag means his user-only skills cannot be scheduled with `/loop` [native-scheduled-tasks-loop].

Distribution is native: the plugin is in Anthropic's official marketplace at a pinned commit [native-official-marketplace-listing]; the open Agent Skills standard originated at Anthropic [native-agentskills-open-standard; native-anthropic-engineering-blog-skills]. Visibility features overlap borg's layer but not its purpose: agent view (research preview) shows Working / Needs input / Idle / Completed with linked PRs but no cross-project order or acceptance criteria [native-agent-view]; agent teams are experimental, one team per session, no resumption [native-agent-teams]; cross-session messaging is plain text and not durable [native-cross-session-messaging]; routines run from a fresh cloud clone and cannot reach a local tmux fleet [native-routines]. Anthropic's guidance favors lean, evaluated skills: under 500 lines, evaluations first, Claude can write skills itself [native-anthropic-skill-best-practices]; research warns that confusable overlapping skills hurt selection [native-arxiv-skill-selection-scaling; native-skill-shadowing-icml].

Sandcastle versus native: container or microVM isolation, several agents (claude-code, pi, codex, cursor, opencode, copilot), and programmatic control, versus native worktree-only isolation, Claude-only workers, and a richer state board [what-sandcastle-readme; native-sandcastle-readme; native-parallel-agents-overview]. No source compares them; that is the researcher's synthesis.

His own stance: skills are harness-neutral text. He refuses the native question tool, assigns subagent-recursion safety to the harness, and tells users to put preferences in their own CLAUDE.md or AGENTS.md [native-pocock-out-of-scope-harness]. Those files are context, not enforcement; hooks enforce [native-memory-claude-agents-md].

**Where sources agree:** Native covers mechanics; his skills cover process; neither covers a cross-project control layer.

**Where sources disagree:** Whether native `/code-review` makes his redundant (correctness versus spec conformance; no head-to-head). Whether skills are worth their context cost: the vendor critique offers no data, while the docs and one paper say overhead is small [native-chatbotkit-skills-expensive-rag].

**What's missing:** No empirical comparison of his skills against native features. The agent-view page was read to about 100,000 of 137,000 characters.

**Institutional vs. ground truth:** Anthropic's docs describe clean, composable primitives; his issues show real name collisions and user demand for native tool use that the maintainer declines.

### 4.6 Matt's stuff and Cortex Code CLI

**Research question:** Does his pack work with Cortex Code CLI, and what does that mean for the work setup?

**What the evidence says:** Cortex Code CLI (generally available February 2026; version 1.1.87 as of September 14, 2026) supports the Agent Skills SKILL.md model, subagents with worktree isolation, 11 hook events, MCP (Model Context Protocol, a standard for connecting tools), and plugins. Claude layouts are first-class discovery paths: `.claude/skills`, `~/.claude/skills`, `.claude/agents`, and `.claude-plugin/plugin.json` [cortex-extensibility-docs; cortex-plugins-docs; cortex-changelog]. It reads Claude MCP servers from `~/.claude.json` [cortex-changelog]. The `skills` installer has a first-class `cortex` target (`.cortex/skills/`, `~/.snowflake/cortex/skills/`), and his README documents `npx skills@latest add mattpocock/skills -a <agent>`, so the route exists in principle [cortex-vercel-skills-agent-table; cortex-mattpocock-readme].

No evidence was found that anyone has used his pack on Cortex: zero hits in his README and in repo issue searches for "cortex" or "snowflake", and no community post [cortex-mattpocock-readme]. That is an absence claim with medium confidence; nothing was installed.

What would likely port: pure-markdown process skills (grilling, tdd as a discipline, diagnosing bugs, domain modeling). What would not port cleanly: tracker-coupled skills (`to-tickets`, `triage`, setup assume a GitHub, GitLab, or local-file tracker) and Claude-specific constructs (`disable-model-invocation`, "Call the Skill tool", and a PreToolUse hook whose matcher uses a capitalized tool name, where Cortex uses lowercase) [cortex-pocock-to-tickets-skill; cortex-pocock-git-guardrails-skill; cortex-extensibility-docs]. Those port assessments are inferences from skill text and docs, untested. The open standard's frontmatter list does not include `disable-model-invocation` [cortex-agentskills-spec; cortex-claude-skills-docs]; if Cortex ignores it, user-only skills could become auto-invocable (inference).

Portability has rough edges: the changelog shows Cortex stopped reading `.claude/settings.json` as project settings in 1.1.53, contradicting the extensibility page's hooks table [cortex-changelog]; AGENTS.md support is a single line, and CLAUDE.md loading is undocumented [cortex-overview-agentsmd].

Domain mismatch: Cortex ships 50-plus Snowflake-domain skills (dbt, Streamlit, Airflow) and the community catalog has no software-process skills [cortex-coco-skills-repo; cortex-capitalone-review]. Snowflake's own pattern is dual-tool: a skill that routes only Snowflake operations from Claude Code or others to Cortex in headless mode [cortex-subagent-cortex-code-repo]. Snowflake's claim of 28 of 43 tasks versus 25 of 43 for Claude Code is a self-run benchmark and is discounted [cortex-snowflake-blog-dbt-benchmark].

**Where sources agree:** SKILL.md folders are the shared unit, and Cortex wants to read Claude layouts.

**Where sources disagree:** The docs and changelog disagree on `.claude/settings.json`; whether Cortex honors Claude-only frontmatter is unresolved.

**What's missing:** A live install. No contrarian voice on Cortex beyond Capital One's scope limit. No academic sources exist for this niche.

**Institutional vs. ground truth:** Snowflake's docs promise Claude compatibility; the changelog shows partial retreat. The one independent hands-on test found dbt generation worked end to end but frames Cortex as competing with manual Snowflake work, not with general coding agents [cortex-capitalone-review].

---

## 5. Research

Format: `[source key; score band; evidence level]` after each claim. Keys are card file names without the `mp-` prefix and `.md` suffix; the full citation and URL for each is in §7. "Core" and "Supporting" decisions are in §7. Excluded sources are not cited here. Statements marked "inference" are the researcher's, not the source's.

### 5.1 What it is: the repo, Sandcastle, AI Hero, philosophy (track "what")

**The repo**
- The README catalogues 27 skills across Engineering (11 user-invoked, 9 model-invoked) and Productivity (5 and 2), and gives install routes for Claude Code, Codex, Copilot, Gemini CLI, and `npx skills@latest add` for Cursor, OpenCode, Devin, Windsurf, Amp, and Pi; it warns that installing by both plugin and skills.sh installs every skill twice [what-skills-readme; keep; L7]. In its words: "My agent skills that I use every day to do real engineering - not vibe coding."
- Positioning: "Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve." [what-skills-readme; keep; L7]. The same README on a second pull is the source for the install matrix used by the Cortex track [cortex-mattpocock-readme; keep; L5] and the native-feature track [native-pocock-skills-readme; keep; L7].
- SCOPE.md: contributions of new skills are closed; an idea stays open only if it describes an observed failure in a real session; `misc/` skills are frozen and not in the Claude plugin; skills deliberately do not guard against sub-agent recursion [what-skills-scope-out-of-scope; keep; L7].
- Live data on 2026-10-13: 289,479 stars, 24,301 forks, MIT, created 2026-02-03, releases v1.0.0/v1.0.1 (2026-06-17), v1.1.0 (2026-07-08), v1.2.x (2026-08-05/06), v1.3.0/v1.3.1 (2026-10-04); contributors API lists the owner at 499 contributions and three others [what-github-api-metadata; keep; L3].
- CHANGELOG: v1.1.0 (PR 464) unified planning skills (`to-prd` to `to-spec`; `to-plan` and `to-issues` into `to-tickets`); v1.3.0 added `implement-spec`, `pr`, `retro`, renamed `CONTEXT.md` to `GLOSSARY.md`, removed `resolving-merge-conflicts`; several entries fix cross-skill references, showing the cost of the composition model; breaking renames shipped as minor versions [what-skills-changelog; keep; L5; pm-repo-changelog; keep; L5].
- Marketing surface: AI Hero lists a six-entry changelog (2026-04-30 to 2026-10-05) with a stated "63% token reduction" at v1.0, still lists `/to-prd` and `/to-issues`, and gives a different Claude Code command from the README [what-aihero-skills-catalogue; borderline; L9]. Anthropic's listing shows 1,745 installs and "21 composable skills", lagging the repo [what-claude-marketplace-listing; borderline; L4; reception-claude-marketplace-listing; borderline; L9].

**Sandcastle**
- A TypeScript library; `run()` takes an agent (Claude Code, Codex, Pi), a sandbox provider (Docker, Podman, Vercel microVM, none), and a prompt; branch strategies are head, merge-to-head, and named branch; authentication uses `CLAUDE_CODE_OAUTH_TOKEN` or an API key [what-sandcastle-readme; keep; L7; native-sandcastle-readme; keep; L7]. Repo: 8,418 stars, MIT, created 2026-03-17, npm 0.12.0 [what-github-api-metadata; keep; L3].

**Philosophy**
- Skill design talk: "skill hell" and a four-part rubric of trigger, structure, steering, pruning; model-invoked skills add context load, user-invoked add operator load [what-aie-agent-skills-talk; borderline; L7].
- Fundamentals talk: fundamentals matter more than ever because fast code is not cheap code; shared terminology makes planning better and reasoning less verbose; skills encode classic practice (DDD, Ousterhout, Pragmatic Programmer) [what-aie-fundamentals-talk; borderline; L7].
- Posts: agents are "a fleet of middling to good engineers" with no memory; grill-me is three sentences long and replaces Claude Code's early plan [what-aihero-five-skills-post; borderline; L7]; tracer bullets keep AI slop under control by building one slice end to end in a fresh context [what-aihero-tracer-bullets-post; borderline; L7; pm-aihero-tracer-bullets-article; borderline; L7]; Anthropic's Ralph plugin re-feeds one session, so context accumulates; a bash loop with fresh context stays in the "smart zone" [what-aihero-ralph-plugin-post; borderline; L7].
- Interview: grill-me was inspired by an Anthropic engineer's description of an agent interviewing its user; "leading words" from classic books steer agents; mixed feelings on TDD; moving to cloud agents; AI Hero follows Total TypeScript, reported at over 2.5 million dollars in sales [what-pragmatic-engineer-interview; keep; L6; pm-pragmatic-engineer-pocock-interview; borderline; L6].
- Critique of the install model (May 2026): no semver pinning at the time, no declared dependency between skills, no lockfile, no security review; setup is a hard prerequisite for nine other skills; the article misdescribes one HN comment as a 36-comment thread [what-mcp-directory-npm-moment; reject; L7]. This is the lowest-scoring included source, kept by override (§6).

### 5.2 Reception (track "reception")

- Positive and descriptive: "small tools you copy and adapt"; Superpowers, Karpathy skills, and Pocock are three poles that "do not clash"; the author borrowed the shape of a few skills because many are TypeScript-tied; v1.1 renames noted [reception-devto-yim-review; borderline; L7].
- The architectural fork: Superpowers injects a SessionStart hook ("1% chance, you MUST invoke"); Pocock has no hook; Superpowers has an eval harness, Pocock's repo had no in-repo tests at that date [reception-nocoders-superpowers-vs-pocock; borderline; L7]. Superpowers is a mechanism to enforce discipline; Pocock's pack is fundamentals as skills, and its CONTEXT.md, ADRs, and issues persist across sessions [reception-zenn-superpowers-vs-pocock; borderline; L7]. A switcher found Superpowers "overcomplicated simple problems" and used a split-model flow [reception-glean-switching-from-superpowers; borderline; L8].
- Competitor comparison: "a sharp, opinionated daily toolkit with a signature grill me loop"; no in-repo evals; "Claude-Code-first in practice, with thinner coverage past Build"; the competitor omits star counts because they are "cited wildly differently and change weekly" [reception-addy-agent-skills-compare; borderline; L7; native-agent-skills-comparison-doc; borderline; L7].
- Cost: always-on about 1,030 tokens for 25 shipped skills; bodies about 28,800; supporting files about 21,500; counts of 37 on disk, 25 in the plugin manifest, 53 in the skills.sh index [reception-varops-sizing-pack; borderline; L5].
- Critical guide: no controlled comparison shows the elaborate grilling phrasing beats "ask me clarifying questions"; issues on TDD attention dilution and unverified review subagents; stack lock-in fixed in part; "literally his dotfiles"; advice to curate rather than install all [reception-kaizen-critical-guide; borderline; L7].
- Issue 1071: a former fan says the skills add work; `ask-matt` routes inconsistently; `diagnosing-bugs` fires in non-coding chats; the maintainer closed it as not planned and pointed to the observed-failure bar [reception-github-issue-1071-skill-bloat; borderline; L8].
- HN thread: skills are "extremely specific to that dev and their workflow"; TDD fits in one AGENTS.md line; imported instructions create hidden behavior; defenders cite educational value [reception-hn-ai-coding-agent-skills-thread; borderline; L8]. One commenter uses grill-me instead of plan mode and forks it to add the native ask tool [reception-hn-comment-plan-mode-replacement; borderline; L8]; another built fast and full lanes plus governance because a 100-line spec for a 10-line change was too much [reception-hn-comment-ceremony-fast-lane; borderline; L8].
- Maintainer policy: grilling stays plain chat text for harness neutrality; five prior requests for native tools were declined; the fallback is a per-user preference [reception-repo-out-of-scope-native-question-tool; keep; L7].
- Benchmarks (none tested this pack): SkillsBench, 33.9 to 50.5 percent with curated skills, focused beats exhaustive [reception-skillsbench-arxiv; keep; L3]; SWE-Skills-Bench, 39 of 49 zero gain, three harmful, up to +451 percent tokens [reception-swe-skills-bench-arxiv; keep; L3]; skill-induced failures, excessive verification (67 cases) and heavy pipelines (30 cases) [reception-skill-induced-failures-arxiv; keep; L3]. Every reports a shelf-life argument and a Fable 5 regression anecdote; the rest of the article is paywalled [reception-every-case-against-skills; borderline; L7].

### 5.3 Matt's PM approach (track "pm")

- Flow and router: grill-with-docs, optional prototype, then `to-spec`, `to-tickets`, `implement` or `implement-spec`, `code-review`, `retro`; triage is for issues the maintainer did not create; steps 1 to 3 stay in one window and each implement starts fresh [pm-repo-ask-matt-router; borderline; L7]. The AI Engineer write-up adds: alignment is HITL, build is a night shift of AFK issues, doc rot is a risk, and he has no answer to the review burden (the write-up is generated, not his wording) [pm-aiengineer-workflow-talk-2026; borderline; L7].
- `to-tickets`: tracer-bullet slices, blocking edges (native links or text), frontier, `ready-for-agent` by default after user approval, expand-migrate-contract for wide refactors; no ranking, time budget, or stop rule [pm-repo-to-tickets-skill; borderline; L7]. Docs page: horizontal versus vertical slices, a 26-ticket anecdote, the demo question, manual dispatch, and criteria that can pass before any work [pm-aihero-to-tickets-docs; borderline; L7].
- `triage`: five states plus a category, `ready-for-agent` and `ready-for-human`, verification before grilling, `.out-of-scope` knowledge base [pm-repo-triage-skill; borderline; L7]. `wayfinder`: a map issue as index, HITL and AFK decision tickets, claim by assignment, "fog of war" section [pm-repo-wayfinder-skill; borderline; L7].
- Failure reports: issue 508 (no completion step) [pm-issue-508-implement-no-completion; borderline; L8]; issue 476 (claim races across sessions) [pm-issue-476-wayfinder-claim-concurrency; borderline; L5]; issue 828 (stale premises) [pm-issue-828-wayfinder-stale-premises; borderline; L5]; issue 310 (no completeness check, rubber-stamp quiz) [pm-issue-310-to-tickets-rubber-stamp; borderline; L8].
- Outside frames: tracer bullets are tied to anti-up-front-specification [pm-artima-hunt-thomas-tracer-bullets; borderline; L7]; appetite is a time budget set before design [pm-shape-up-set-boundaries; borderline; L7]; spec-first versus spec-anchored [pm-fowler-boeckeler-sdd-tools; keep; L7]; SDD repeats Waterfall [pm-marmelab-sdd-waterfall; borderline; L7]; AI as amplifier [pm-dora-2025-ai-amplifier; keep; L3]; a randomized trial found a 19 percent slowdown against a believed 20 percent speed-up [pm-metr-ai-slowdown-rct; keep; L2].
- Secondary: the full flow is overkill for a two-line fix [pm-contextstudios-pocock-workflow; borderline; L8]; "Define and Build heavy" with no shipped quality measurement [pm-addy-osmani-skills-comparison; borderline; L7].

### 5.4 Versus Claude native features (track "native")

- Runtime: skills follow the open standard plus Claude extensions; `disable-model-invocation` makes a skill user-only and keeps it out of scheduled fires; `context: fork` runs a skill in a subagent [native-claude-skills-docs; keep; L4; native-scheduled-tasks-loop; keep; L4]. Five parallelism approaches, with `/batch` as a packaged use of worktree-isolated subagents; all workers are Claude sessions [native-parallel-agents-overview; keep; L4]. Subagents: own context, `isolation: worktree`, preloaded `skills` field [native-subagents; keep; L4]. Dynamic workflows: script-held plan, saved to `.claude/workflows/`, resumable, pause at a usage limit, no mid-run user input [native-dynamic-workflows; keep; L4].
- Visibility: agent view states, worktree isolation, research preview [native-agent-view; keep; L4]; agent teams experimental, hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted` [native-agent-teams; keep; L4]; messaging not durable, cannot approve anything [native-cross-session-messaging; keep; L4]; routines in the cloud, one-hour minimum [native-routines; keep; L4].
- Commands: native `/code-review`, `/verify`, `/batch`, `/plan`, `/init` and how each relates to his skills [native-commands-bundled-skills; keep; L4]. Instruction files are context, not enforcement [native-memory-claude-agents-md; keep; L4].
- Lineage and portability: the format originated at Anthropic and became an open standard in December 2025 [native-anthropic-engineering-blog-skills; keep; L4]; client showcase includes Codex, Cursor, Gemini CLI, OpenCode, Copilot, and Cortex Code [native-agentskills-open-standard; keep; L4]; the plugin sits in Anthropic's official marketplace at a pinned SHA [native-official-marketplace-listing; keep; L4].
- His side: `implement-spec` (frontier, implementers in worktrees, merger, closing review) [native-pocock-implement-spec; keep; L7]; harness-neutrality decisions, name collisions in issues 423, 483, and 1019 [native-pocock-out-of-scope-harness; keep; L7]; Sandcastle versus native, differentiators container isolation and multi-agent support [native-sandcastle-readme; keep; L7].
- Guidance and research: concise skills, evaluation first [native-anthropic-skill-best-practices; keep; L4]; shadowing, up to 21 percent drop at 202 skills [native-skill-shadowing-icml; keep; L3]; accuracy flat then dropping sharply with confusability (abstract only) [native-arxiv-skill-selection-scaling; borderline; L3]; skills as "an expensive form of RAG" (vendor opinion) [native-chatbotkit-skills-expensive-rag; borderline; L7]; plan mode answers how to build, not whether to [native-questionpro-grill-vs-plan-mode; borderline; L8].

### 5.5 Versus Cortex Code CLI (track "cortex")

- Extension model: skills from `.cortex/skills/` or `.claude/skills/`, `/skill add`, `$skill-name`, subagents from `.claude/agents/`, 11 hook events, case-sensitive tool names [cortex-extensibility-docs; keep; L4]. Plugins accept `.claude-plugin/plugin.json` and install from a GitHub shorthand or Git URL [cortex-plugins-docs; keep; L4]. Changelog: `.agents/skills` (1.0.77), Claude MCP and config reuse (1.1.53), `.claude/settings.json` no longer read (1.1.53), explicit-only flags (1.1.65) [cortex-changelog; keep; L4]. AGENTS.md support documented in one line [cortex-overview-agentsmd; borderline; L4].
- Standard and semantics: standard frontmatter fields exclude `disable-model-invocation` [cortex-agentskills-spec; keep; L4; cortex-claude-skills-docs; keep; L4].
- Pocock side: README has no Cortex mention; zero issue hits [cortex-mattpocock-readme; keep; L5]; `to-tickets` depends on a configured tracker and a Claude-only key [cortex-pocock-to-tickets-skill; keep; L5]; the git-guardrails skill is a Claude PreToolUse hook [cortex-pocock-git-guardrails-skill; keep; L5]; the `skills` installer has a `cortex` agent [cortex-vercel-skills-agent-table; keep; L5].
- Ecosystem and practice: 50-plus bundled skills, community catalog in Snowflake domains [cortex-coco-skills-repo; keep; L5]; hands-on test: dbt generation worked end to end; warehouse sizing is on the user; token cost accumulates [cortex-capitalone-review; keep; L5]; a skill that routes Snowflake work from Claude Code to Cortex in headless mode [cortex-subagent-cortex-code-repo; keep; L5]; vendor benchmark 28 of 43 versus 25 of 43, self-run [cortex-snowflake-blog-dbt-benchmark; borderline; L9].

## 6. Methodology

### Research Design

**Research questions:**
1. What is `mattpocock/skills` (plus Sandcastle and AI Hero), and what does Matt Pocock say he believes?
2. What are people in the industry saying, and is there evidence the skills work?
3. How does the pack compare to borg?
4. What is his PM approach, and how does it compare to borg's PM research?
5. How does it compare to new Claude Code native features?
6. How does it relate to the Cortex Code CLI?

**Scope boundaries:**
- In scope: primary sources (repo, README, changelog, GitHub API, skill files, Matt's posts and talks), third-party reception, adjacent academic work on skills, Claude Code and Cortex Code documentation.
- Out of scope: paid courses (not bought), a live install on Cortex, a hands-on trial of the skills, and any evaluation of borg itself beyond the comparison points supplied in the brief.

**Target audience:** Noah, a solo architect running about 20 projects with Claude Code and borg, who also uses Cortex Code CLI at work.

**Methodology version:** deep-research v1, hybrid mode, full tier (five parallel evidence tracks, independent citation verification, then this synthesis).

### Source Discovery

**Search strategy:**
- 76 logged queries and fetch batches across five tracks on 2026-10-13, ordered by track: what it is (13), reception (24), PM (19), native features (10), Cortex (10).
- Platforms: web search, direct fetches of the repo, GitHub REST API, npm registry, Hacker News Algolia and Firebase APIs, arXiv, vendor documentation sites. Reddit and X were unreachable.
- Source diversity targets: academic, institutional, practitioner, boots-on-the-ground, contrarian, with falsification queries in each track.

**Search log:** Frame codes: F factual, E experiential, C contrarian or falsification, V evaluative. "Used" is the number of results pulled for evaluation as logged by each track; per-query raw hit counts were not logged. Track codes: W what, R reception, P PM, N native, C Cortex.

| # | Trk | Query (shortened) | Frame | Used |
|---|-----|-------------------|-------|------|
| 1 | W | Pocock skills repo grill-me explained | F | 3 |
| 2 | W | Pocock AI Engineer talk 2026 skills | F | 3 |
| 3 | W | aihero.dev cohort price, free vs paid | F | 2 |
| 4 | W | "Building Better AI Agent Skills" talk | F | 2 |
| 5 | W | skills criticism, overhyped, token cost | C | 0 |
| 6 | W | mattpocock/skills Hacker News thread | E | 2 |
| 7 | W | Sandcastle review, Docker, worktrees | E | 1 |
| 8 | W | Sandcastle announcement, Ralph, AFK | F | 0 |
| 9 | W | Sandcastle limitations and issues | C | 0 |
| 10 | W | AI Hero business, newsletter, revenue | V | 1 |
| 11 | W | skills v1.1 to-tickets migration | F | 1 |
| 12 | W | skills stopped using, too much ceremony | C | 0 |
| 13 | W | Direct fetches: repo, API, npm, HN, talks | F | 16 |
| 14 | R | Pocock skills repo review | F | 4 |
| 15 | R | mattpocock/skills Hacker News | E | 2 |
| 16 | R | HN Algolia API, six query variants | E | 14 |
| 17 | R | skills criticism, bloat, token cost | C | 4 |
| 18 | R | Pocock vs Superpowers vs Spec-Kit, BMAD | V | 4 |
| 19 | R | reddit Pocock grill-me tried it | E | 1 |
| 20 | R | reddit search.json (blocked) | E | 0 |
| 21 | R | reddit r/ClaudeCode Pocock skills | E | 0 |
| 22 | R | WebSearch scoped to reddit.com | E | 0 |
| 23 | R | Pocock vs Compound Engineering | V | 1 |
| 24 | R | compound engineering vs Superpowers | V | 3 |
| 25 | R | Every plugin vs grill-me vs Superpowers | V | 1 |
| 26 | R | Pocock skills did not work, backfired | C | 2 |
| 27 | R | SkillsBench self-generated skills study | C | 2 |
| 28 | R | public agent skills made output worse | C | 4 |
| 29 | R | arXiv API: SWE-Skills-Bench | C | 1 |
| 30 | R | Pocock skills YouTube review | E | 0 |
| 31 | R | Pocock skills X reactions | E | 0 |
| 32 | R | Pocock skills multilingual (DE/JA/KO) | E | 1 |
| 33 | R | Pocock skills in Russian | E | 0 |
| 34 | R | Pocock skills in Spanish, critical | C | 0 |
| 35 | R | skills lock-in, portability complaints | C | 1 |
| 36 | R | Pocock vs obra/superpowers vs compound | V | 3 |
| 37 | R | GitHub API, SCOPE and .out-of-scope | F | 2 |
| 38 | P | Pocock to-prd, to-issues, grill-me review | F | 4 |
| 39 | P | tracer bullet tickets, vertical slices | E | 2 |
| 40 | P | skills criticism, overengineered | C | 1 |
| 41 | P | ready-for-agent, AFK, HITL, triage | F | 1 |
| 42 | P | tracer bullet Pragmatic Programmer, AI | F | 2 |
| 43 | P | HN Pocock grill-me discussion | E | 0 |
| 44 | P | Pocock vs Superpowers vs spec-kit, skeptic | C | 2 |
| 45 | P | Fowler, Boeckeler SDD tools critique | V | 2 |
| 46 | P | reddit grill-with-docs after weeks | E | 0 |
| 47 | P | DORA 2025 AI-assisted development | F | 1 |
| 48 | P | aihero tracer bullets article | F | 2 |
| 49 | P | Pragmatic Programmer tracer excerpt | F | 1 |
| 50 | P | spec-driven waterfall critique | C | 1 |
| 51 | P | Shape Up appetite for AI agents | V | 1 |
| 52 | P | Sandcastle planner, implementer, merger | F | 0 |
| 53 | P | wayfinder skill review blog | V | 0 |
| 54 | P | workflow limits, solo dev, PRD overhead | C | 0 |
| 55 | P | gh issue search on skills tracker | E | 4 |
| 56 | P | GitHub API repo and releases | F | 2 |
| 57 | N | Pocock skills official marketplace | F | 3 |
| 58 | N | Pocock vs Superpowers vs GSD vs BMAD | V | 3 |
| 59 | N | criticism vs native plan mode | C | 2 |
| 60 | N | Sandcastle vs worktrees, bg agents | E | 0 |
| 61 | N | library bloat, lock-in, review | C | 3 |
| 62 | N | skill shadowing, library size | F | 3 |
| 63 | N | Claude Code docs (11 pages) | F | 11 |
| 64 | N | best-practices, eng blog, agentskills.io | F | 3 |
| 65 | N | GitHub raw: README, out-of-scope, Sandcastle | F | 6 |
| 66 | N | Addy compare, questionpro, ICML, arXiv | V | 6 |
| 67 | C | Cortex skills, AGENTS.md, hooks, MCP | F | 5 |
| 68 | C | Pocock skills Cortex Snowflake (absence) | F | 0 |
| 69 | C | Cortex release notes 2026 | F | 2 |
| 70 | C | vercel-labs skills CLI cortex agent | F | 3 |
| 71 | C | Cortex vs Claude Code skill reuse | E | 2 |
| 72 | C | Cortex problems, limitations | C | 0 |
| 73 | C | Cortex and .claude/skills reuse | V | 2 |
| 74 | C | Cortex honest review, pitfalls, cost | C | 1 |
| 75 | C | Snowflake-Labs cortex-code-skills | F | 2 |
| 76 | C | issue search and README grep: cortex | C | 1 |

- Falsification or contrarian queries (frame C) number 19: rows 5, 9, 12, 17, 26 to 29, 34, 35, 40, 44, 50, 54, 59, 61, 72, 74, and 76 (row 76 is an absence test).
- **Total sources pulled for evaluation:** 98 cards, 85 distinct sources (13 sources were carded by more than one track, e.g., the README by three).
- **Triaged out before carding:** 57 entries (some bundle several pages), mostly aggregators, content farms, mirrors, and paywalled or blocked pages. Total raw discovered was not logged per query.
- **Paywall scan:** one high-value candidate, Every's "The Case Against Skills" (subscription, cost unknown, not registered). The free portion was carded; the candidate is listed in `drafts/paywalled-candidates.md` with the claim it would test (a with-and-without skill evaluation method). Not purchased.

### Source Evaluation

**Evaluation framework:** 10-dimension credibility rubric, reported as three bands (keep at 7.0 or above, borderline 5.0 to 6.9, reject below 5.0).

**Evidence classification:** 9-level hierarchy (1 systematic review, 2 randomized trial, 3 large-scale observational or benchmark, 4 expert consensus or vendor documentation, 5 practitioner case study, 6 qualitative interview, 7 expert opinion, 8 anecdote, 9 marketing).

**Bias guards applied:**
- Confirmation-bias check on every card (score harder when agreeing, gentler when disagreeing, on dimensions 5, 6, and 8).
- Triangulation: findings that matter rest on at least two source types, or are flagged as single-source.
- Falsification queries in every track (above).

**Bias-Guard Summary:**

| Bias-guard outcome | Count |
|--------------------|-------|
| Agreed, scored harder (dims 5, 6, 8) | 5 |
| Disagreed, scored more generously | 2 |
| Neutral / no strong reaction | 91 |
| **Total sources evaluated** | 98 |

- Agree:disagree is 5:2, or 2.5:1, below the 3:1 threshold, so a "Steel-man the contrarian" subsection is not required. Falsification queries were run anyway (above).
- Caution: 91 of 98 cards were marked neutral, so the guard fired rarely. That is a limit on how much comfort the ratio gives.
- The agree cards: native-questionpro-grill-vs-plan-mode, pm-aihero-tracer-bullets-article, pm-artima-hunt-thomas-tracer-bullets, reception-every-case-against-skills, reception-skill-induced-failures-arxiv. The disagree cards: cortex-snowflake-blog-dbt-benchmark, native-chatbotkit-skills-expensive-rag.

**Citation-Verification Report** (Phase 3.5 sample audit; full report in `verification-report.md` in this directory):

| Metric | Value |
|--------|-------|
| Total source cards | 106 (98 mp-* plus 8 deployment-primitive) |
| Cards sampled | 34 of 106 (32.1%) |
| Verified | 34 |
| Failed | 0 |
| Inaccessible | 0 |
| **Failure rate** | 0.0% (0 of 34) |
| Failure-rate band | `≤5%` |

- Rounds 1 and 3: round 1 checked 30 of 98 cards (0 failed); round 3 is the reported audit, drawn fresh from the mp-* cards that round 1 left out. Round 3 ran because cards added after round 1 pushed the audit under the 30% floor and the agent-ID format needed correcting.
- Each sampled card's URL was fetched live and every verbatim quote matched after normalizing quotes and whitespace. One sampled card (mp-what-hn-skills-thread) was later excluded at Phase 4 as redundant, not for accuracy.

### Inclusion/Exclusion Results

**Summary** (unit: source cards):

| Category | Count |
|----------|-------|
| Total sources evaluated | 98 |
| Included: Core | 34 |
| Included: Supporting | 56 |
| Excluded | 8 |
| Overrides applied | 8 |

- Rules applied in order. Rule 1 (score at or above 7.0, not redundant): 27 Core. Rule 2 (diversity): 0 uses after Phase 4. Rules 3 and 4 (unique insight, or moderate score with two contextual factors): 55 Supporting (19 keep-band sources that overlap a stronger card, 36 borderline). Rules 5 and 6: 8 Excluded (Rule 5 for six; Rule 6 for the besthub duplicate and the unsourced prior-art comment, which has no duplicate but sits under the 5.0 bar for a unique-insight include). Overrides: 8.
- **Overrides (8).** Seven Core upgrades: pm-aiengineer-workflow-talk-2026, pm-aihero-to-tickets-docs, pm-repo-ask-matt-router, pm-repo-to-tickets-skill, pm-repo-triage-skill, pm-repo-wayfinder-skill, what-aie-agent-skills-talk. Rule that would apply: Rule 3, Supporting, because composites sit at 6.6 to 6.95 (below 7.0). Reason: they are the executable or authoritative definition of the method being compared, and the rubric scores design documents low on evidence quality by construction. Role: Core primary artifacts for what Matt's method is, never evidence of outcomes. One retention: what-mcp-directory-npm-moment, reject band. Rule that would apply: Rule 6, excluded. Reason: the only structured critique of the install and supply-chain model, and an example of how a misreported HN thread spread. Role: flagged perspective and counterexample, never a factual authority.
- **Decisions changed at Phase 4 (2).** mp-what-hn-skills-thread was a diversity override at card stage; it is the same HN thread as mp-reception-hn-ai-coding-agent-skills-thread (higher score), so it is now Excluded (Rule 5). mp-native-besthub-grill-vs-superpowers is the same article the PM track excluded in the reject band, so it is now Excluded (Rule 6) for consistency. Both card files were updated.

**Distribution by evidence level** (the pre-cut set, included and excluded):

| Level | Description | Incl. | Excl. |
|-------|-------------|-------|-------|
| 1 | Systematic review / meta-analysis | 0 | 0 |
| 2 | Randomized controlled trial | 1 | 0 |
| 3 | Large-scale observational or benchmark | 7 | 0 |
| 4 | Expert consensus or vendor docs | 22 | 0 |
| 5 | Practitioner case study | 12 | 0 |
| 6 | Qualitative research or interview | 2 | 0 |
| 7 | Expert opinion / thought leadership | 34 | 0 |
| 8 | Anecdotal / personal experience | 9 | 6 |
| 9 | Marketing / promotional | 3 | 2 |
| | **Total** | 90 | 8 |

- Level 2 is one randomized trial (METR) on AI coding in general, not on Matt's skills. Level 1 is empty. Level 3 is mostly benchmarks and platform data. No Level 1 to 3 evidence tests the pack itself.

**Distribution by source category:**

| Category | Included | Excluded |
|----------|----------|----------|
| Academic | 6 | 0 |
| Institutional | 29 | 0 |
| Practitioner | 36 | 1 |
| Boots-on-the-ground | 11 | 6 |
| Contrarian | 8 | 1 |
| **Total** | 90 | 8 |

**Distribution by credibility band:**

| Band | Weighted avg | Count | Disposition |
|------|--------------|-------|-------------|
| keep | 7.0 or more | 46 | 46 incl., 0 excl. |
| borderline | 5.0 to 6.9 | 44 | 43 incl., 1 excl. |
| reject | below 5.0 | 8 | 1 incl., 7 excl. |

**Real cut made this run:** eight cards excluded: the AI Hero cohort page (a sales page with no price; the run's lowest-value source), andrew.ooo review (SEO-style, unsourced numbers), an HN comment from "pipes" (single anecdote), an HN comment claiming grill-me is prior art (unsourced), the Juejin launch narrative (stale, unsourced statistics), the BestHub comparison (two cards, one project) and its native-track duplicate, and the first HN thread card (redundant). The lowest-scoring source kept is what-mcp-directory-npm-moment (reject band, by override). Among the lowest kept without an override: pm-contextstudios-pocock-workflow (recorded composite about 5.15), kept for its overkill caveat only.

### Perspective Balance

| Topic area | Acad. | Inst. | Pract. | Boots | Contra. |
|------------|-------|-------|--------|-------|---------|
| What it is | N | Y | Y | N | Y |
| Reception | Y | Y | Y | Y | Y |
| PM approach | Y | Y | Y | Y | Y |
| Native features | Y | Y | Y | Y | Y |
| Cortex Code CLI | N | Y | Y | Y | N |

- **What it is:** 3 of 5 categories. No academic source exists on the repo. The only boots-on-the-ground card (an HN thread) was excluded as redundant with the reception track's copy of the same thread, so that voice lives in the Reception row.
- **Cortex Code CLI:** 3 of 5. No academic work exists on this niche, and no contrarian voice was found; Capital One's scope limit and the discounted vendor benchmark are the nearest.

### Limitations

- Web search favors SEO content and aggregators; 57 triage entries removed many, but the surviving blogs are still mostly promotional or descriptive.
- Reddit and X were unreachable, YouTube comment sections were not reached, and non-English coverage is thin (one Japanese and one Chinese-origin source included, plus one Chinese post excluded).
- No source tests Matt's pack against an outcome, so every claim about whether the skills help is inference from general benchmarks or silence.
- The borg side of §4.3 and §4.4 is drawn from the commissioning brief and borg's internal research, not from a source card; those comparisons are the researcher's synthesis.
- Port assessments for Cortex are inferences from documentation; nothing was installed. The extensibility page's options table did not render in any fetch.
- Several talk cards are generated write-ups of videos, not transcripts; academic cards for skill-library research are abstract-level.
- The unit of count is the card. Thirteen sources were carded by more than one track, so card counts overstate distinct sources (98 cards, 85 distinct). Two duplicate cards were scored differently by different tracks, which Phase 4 resolved (above).
- Cards were produced by a generator script with quotes machine-checked against fetched text; the audit sampled 30 of 98, so an error in an unsampled card is possible at a rate the sample cannot bound tightly.
- Credibility scoring is by a single evaluator per card, with no inter-rater check.
- Everything here is dated 2026-10-13. Star counts, install counts, version numbers, and the Cortex version will change.

---

## 7. Bibliography

Every included source, grouped by the track that carded it. Entry format: key, title, URL, then score band, evidence level, inclusion decision, and a one-line contribution (the first key finding on the card, shortened). 13 sources appear twice or more under different keys because more than one track carded them. Excluded sources are in 7.6.

### 7.1 What it is

- **[what-aie-agent-skills-talk]** AI Engineer World's Fair 2026: Building Great Agent Skills, The Missing Manual. https://ai.engineer/talks/UNzCG3lw6O0-building-great-agent-skills Band: borderline | L7 | Core (override: borderline band).
  Contribution: Matt names 'skill hell', an accumulation of apparent capabilities that does not reliably produce results, and proposes a four-part rubric: trigger, structure, steering, pruning.
- **[what-aie-fundamentals-talk]** AI Engineer Europe 2026: Software Fundamentals Matter More Than Ever. https://ai.engineer/talks/v4F1gFy-hqg-software-fundamentals-for-ai-coding Band: borderline | L7 | Supporting.
  Contribution: Thesis in the talk's own words: software fundamentals matter now more than ever, because quickly producing code does not make code cheap.
- **[what-aihero-five-skills-post]** AI Hero post: 5 Agent Skills I Use Every Day (grill-me, to-spec, to-tickets, tdd, architecture). https://www.aihero.dev/5-agent-skills-i-use-every-day Band: borderline | L7 | Supporting.
  Contribution: Matt's framing: agents are 'a fleet of middling to good engineers' with no memory, so you need 'extremely strict and well-defined processes'; skills encode that process.
- **[what-aihero-ralph-plugin-post]** AI Hero post: Why the Anthropic Ralph plugin sucks (use a bash loop instead). https://www.aihero.dev/why-the-anthropic-ralph-plugin-sucks Band: borderline | L7 | Supporting.
  Contribution: Matt argues Anthropic's official Ralph plugin intercepts exit attempts and feeds the prompt back into the same session, so context accumulates and the model degrades.
- **[what-aihero-skills-catalogue]** AI Hero Skills catalogue and changelog page. https://www.aihero.dev/skills Band: borderline | L9 | Supporting.
  Contribution: AI Hero presents the skills as 'a practical skill system', grouped Getting Started, The Main Flow, Shaping, Engineering, Productivity Skills and Reference Skills, with a changelog of six ...
- **[what-aihero-tracer-bullets-post]** AI Hero post: Tracer Bullets, Keeping AI Slop Under Control. https://www.aihero.dev/tracer-bullets Band: borderline | L7 | Supporting.
  Contribution: Failure mode named: AI sycophancy makes the agent build whole layers in isolation ('outrunning your headlights') and only later find the integration is wrong.
- **[what-claude-marketplace-listing]** Claude.com plugin listing: Matt Pocock's Skills. https://claude.com/plugins/mattpocock-skills Band: borderline | L4 | Supporting.
  Contribution: Anthropic's official marketplace lists the plugin as 'Matt Pocock's Skills', made by Matt Pocock, with 1,745 installs on the access date; this is the Claude Code distribution route the ...
- **[what-github-api-metadata]** GitHub REST API metadata for mattpocock/skills and mattpocock/sandcastle. https://api.github.com/repos/mattpocock/skills Band: keep | L3 | Core.
  Contribution: Live star count was 289,479 with 24,301 forks and MIT licence on 2026-10-13, so the 'inconsistent' public figures (58.5k in May, 160k in July, 230k+ in August, 239k in an August guide) are ...
- **[what-mcp-directory-npm-moment]** MCP.Directory: Matt Pocock's Skills, The npm Moment for AI Agents (critical audit). https://mcp.directory/blog/matt-pocock-skills-the-npm-moment-explained-2026 Band: reject | L7 | Supporting (override: reject band retained).
  Contribution: Net assessment: the unit (SKILL.md), installer (npx skills) and discovery are solved; the supply chain (no semver pinning, no declared dependency between skills, no security review, no ...
- **[what-pragmatic-engineer-interview]** The Pragmatic Engineer: AI skills with Matt Pocock. https://newsletter.pragmaticengineer.com/p/ai-skills-with-matt-pocock Band: keep | L6 | Core.
  Contribution: grill-me was inspired by Anthropic's Thariq Shihipar describing an agent interviewing its user; Matt turned that idea into a skill.
- **[what-sandcastle-readme]** mattpocock/sandcastle README (TypeScript orchestrator for sandboxed agents). https://github.com/mattpocock/sandcastle Band: keep | L7 | Core.
  Contribution: Sandcastle is a TypeScript library: you call run() with an agent (Claude Code, Codex, Pi), a sandbox provider and a prompt; it sandboxes the agent, applies a branch strategy, and merges ...
- **[what-skills-changelog]** mattpocock/skills CHANGELOG (versions 1.0.0 to 1.3.1). https://github.com/mattpocock/skills/blob/main/CHANGELOG.md Band: keep | L5 | Core.
  Contribution: v1.1.0 (PR 464, merged 2026-07-08) unified the planning skills: to-prd renamed to to-spec, and to-plan plus to-issues merged into one to-tickets skill (to-issues deleted). This verifies the ...
- **[what-skills-readme]** mattpocock/skills README (install paths, skill catalogue, philosophy). https://github.com/mattpocock/skills Band: keep | L7 | Core.
  Contribution: The README catalogues 27 skills (my count of the listed bullets: Engineering 11 user-invoked plus 9 model-invoked, Productivity 5 plus 2), split on one axis: who can invoke them ...
- **[what-skills-scope-out-of-scope]** mattpocock/skills SCOPE.md and .out-of-scope decisions. https://github.com/mattpocock/skills/blob/main/SCOPE.md Band: keep | L7 | Supporting.
  Contribution: The repo is explicitly a curated personal set: 'the set of skills I use every day', not a community-driven framework; new-skill proposals and contributions are closed.

### 7.2 Reception

- **[reception-addy-agent-skills-compare]** Addy Osmani agent-skills: "Honest positioning" comparison page. https://skills.addy.ie/compare/ Band: borderline | L7 | Supporting.
  Contribution: A competing maintainer describes Pocock's skills as "a sharp, opinionated daily toolkit with a signature grill me loop", strongest at requirements and TDD.
- **[reception-claude-marketplace-listing]** Claude Marketplace listing: "Matt Pocock's Skills". https://claude.com/marketplace/plugins/mattpocock-skills Band: borderline | L9 | Supporting.
  Contribution: Anthropic hosts the pack in its Claude Marketplace as a Claude Code plugin by Matt Pocock; the page lists "21 composable agent skills".
- **[reception-devto-yim-review]** DEV: "mattpocock/skills review: a real engineer's .claude, 160k stars". https://dev.to/yimtheppariyapol/mattpocockskills-review-a-real-engineers-claude-160k-stars-4d3f Band: borderline | L7 | Supporting.
  Contribution: Positions the pack as the opposite of an enforced framework: "small tools you copy and adapt".
- **[reception-every-case-against-skills]** Every, "The Case Against Skills" (Context Window). https://every.to/context-window/the-case-against-skills Band: borderline | L7 | Supporting.
  Contribution: A senior AI consultant argues frontier models have absorbed most skills trending on social media, and extra instructions "fight the weights" of the model.
- **[reception-github-issue-1071-skill-bloat]** GitHub issue 1071 "Skill Bloating and Regressions" (mattpocock/skills). https://github.com/mattpocock/skills/issues/1071 Band: borderline | L8 | Supporting.
  Contribution: A former enthusiast reports the skills "nowadays" add work instead of removing it, and attributes it either to skill changes or to model changes (uncertain).
- **[reception-glean-switching-from-superpowers]** Glean/justinyan: "Switching from Superpowers to mattpocock/skills: Less Token Waste, More Control". https://glean.smartcoder.ai/en/a/switching-from-superpowers-to-mattpocock-skills-less-token-w-y7bggx Band: borderline | L8 | Supporting.
  Contribution: A user ran Superpowers and Pocock's pack side by side, then deleted Superpowers' hooks because it "overcomplicated simple problems".
- **[reception-hn-ai-coding-agent-skills-thread]** Hacker News thread "AI Coding Agent Skills for Real Engineers" (14 comments). https://news.ycombinator.com/item?id=49529329 Band: borderline | L8 | Supporting.
  Contribution: Top-level reaction was skeptical: skills of this kind are "extremely specific to that dev and their workflow" and rarely transfer (hungryhobbit, fishfasell).
- **[reception-hn-comment-ceremony-fast-lane]** HN comment (cg-enterprise): ceremony cost and a fast/full lane over Pocock-style flows. https://news.ycombinator.com/item?id=49737218 Band: borderline | L8 | Supporting.
  Contribution: A user of Superpowers and Pocock's skills for spec-driven development still built custom workflow management because existing frameworks omit artifact-staleness tracking, multi-model ...
- **[reception-hn-comment-plan-mode-replacement]** HN comment (diegof79): grill-me used instead of Claude Code plan mode. https://news.ycombinator.com/item?id=49851420 Band: borderline | L8 | Supporting.
  Contribution: A user prefers /grill-me to Claude Code plan mode and to "a complex, spec-driven set of skills".
- **[reception-kaizen-critical-guide]** Kaizen Craft: "Matt Pocock's Skills, Actually Explained: A Critical Guide". https://kaizencode.art/notepad/matt-pocock-skills-guide/ Band: borderline | L7 | Supporting.
  Contribution: Names the structural critique from HN: no controlled comparison shows the elaborate phrasing ("walk down each branch of the decision tree") outperforms plain "ask me clarifying questions".
- **[reception-nocoders-superpowers-vs-pocock]** nocoders: Superpowers vs Matt Pocock's skills, two opposite bets. https://www.nocoders.com/blog/superpowers-vs-pocock-agent-skills/ Band: borderline | L7 | Supporting.
  Contribution: Both libraries use the same primitive (SKILL.md folders); the fork is default invocation: Superpowers injects a SessionStart hook ("1% chance, you MUST invoke"), Pocock has no hook and ...
- **[reception-repo-out-of-scope-native-question-tool]** mattpocock/skills .out-of-scope: grilling through the harness's native question tool. https://github.com/mattpocock/skills/blob/main/.out-of-scope/native-question-tool.md Band: keep | L7 | Supporting.
  Contribution: The maintainer deliberately keeps grilling skills as plain chat text, not harness-native question tools, so they stay harness-neutral across Claude Code, Codex, Copilot and Cursor.
- **[reception-skill-induced-failures-arxiv]** Agent Skills Can Be Harmful: An Empirical Study of Skill-Induced Failures (arXiv 2608.11888). https://arxiv.org/abs/2608.11888 Band: keep | L3 | Supporting.
  Contribution: A seemingly relevant skill is a bigger failure source than an irrelevant one: skills often cause the agent to implement or omit required elements incorrectly.
- **[reception-skillsbench-arxiv]** SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks (arXiv 2602.12670). https://arxiv.org/abs/2602.12670 Band: keep | L3 | Supporting.
  Contribution: Curated skills raised average pass rate from 33.9% to 50.5% (+16.6 pp) across 18 model-harness configurations, so skills can help.
- **[reception-swe-skills-bench-arxiv]** SWE-Skills-Bench: Do Agent Skills Actually Help in Real-World Software Engineering? (arXiv 2603.15401). https://arxiv.org/abs/2603.15401 Band: keep | L3 | Supporting.
  Contribution: 39 of 49 public SWE skills yield zero pass-rate improvement; average gain only +1.2%.
- **[reception-varops-sizing-pack]** VarOps: sizing the Pocock skill pack (measured install and token cost). https://varops.com/how-to-size-an-agent-skill-pack-when-three-sources-disagree-on-how-many-skills-it-has/ Band: borderline | L5 | Supporting.
  Contribution: The always-on cost is small: the 25 shipped skills' names and descriptions total roughly 1,030 tokens, about half a percent of a 200k window.
- **[reception-zenn-superpowers-vs-pocock]** Zenn (Japanese, English machine translation): superpowers vs mattpocock/skills. https://zenn.dev/kanagen/articles/claude-code-skills-superpowers-vs-mattpocock?locale=en Band: borderline | L7 | Supporting.
  Contribution: Superpowers is a "mechanism to enforce discipline on an agent"; Pocock's pack is "engineering fundamentals implemented as skills".

### 7.3 PM approach

- **[pm-addy-osmani-skills-comparison]** agent-skills: How it compares (to Superpowers and Matt Pocock's skills). https://skills.addy.ie/compare/ Band: borderline | L7 | Supporting.
  Contribution: Matt's set is described as 'Define & Build heavy: grilling, PRDs, issues, TDD, triage'; it is weaker on later lifecycle phases.
- **[pm-aiengineer-workflow-talk-2026]** AI Engineer Europe 2026: Full Walkthrough, Workflow for AI Coding (Matt Pocock), write-up page. https://ai.engineer/talks/ai-coding-workflow Band: borderline | L7 | Core (override: borderline band).
  Contribution: Alignment is explicitly human-in-the-loop: Grill Me interviews the human (dozens of questions) before a PRD captures the destination; this stage is not for an unattended loop.
- **[pm-aihero-to-tickets-docs]** AI Hero: /to-tickets docs page (tracer bullets, failure modes, manual dispatch). https://www.aihero.dev/skills-to-tickets Band: borderline | L7 | Core (override: borderline band).
  Contribution: A horizontal slice ships one layer so nothing works until all land; a vertical slice (tracer bullet) is verifiable alone and 'owns everything it grades'.
- **[pm-aihero-tracer-bullets-article]** AI Hero: Tracer Bullets, Keeping AI Slop Under Control (Matt Pocock). https://www.aihero.dev/tracer-bullets Band: borderline | L7 | Supporting.
  Contribution: The rationale: agents tend to build whole layers in isolation and only test at the end ('outrunning your headlights'), so slop and review burden pile up.
- **[pm-artima-hunt-thomas-tracer-bullets]** Artima interview: Tracer Bullets and Prototypes (Hunt and Thomas). https://www.artima.com/intv/tracer.html Band: borderline | L7 | Supporting.
  Contribution: The software analogue of firing artillery by calculation is specifying everything up front; tracer bullets instead produce something early to adjust aim.
- **[pm-contextstudios-pocock-workflow]** Context Studios: Pocock Workflow, grill-me to Spec to Tickets to Subagent Review. https://www.contextstudios.ai/blog/pocock-workflow-grill-me-spec-tickets-subagent-review Band: borderline | L8 | Supporting.
  Contribution: Four phases: alignment by questioning, a written spec in the tracker, tickets sized to one context window, then implementation reviewed by a fresh subagent.
- **[pm-dora-2025-ai-amplifier]** DORA: State of AI-assisted Software Development 2025 (overview page). https://dora.dev/research/2025/dora-report/ Band: keep | L3 | Supporting.
  Contribution: The 2025 report's headline is that AI's primary role is as an amplifier of an organisation's existing strengths and weaknesses.
- **[pm-fowler-boeckeler-sdd-tools]** martinfowler.com: Understanding Spec-Driven-Development, Kiro, spec-kit, and Tessl (Boeckeler). https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html Band: keep | L7 | Core.
  Contribution: All spec-driven approaches she found are spec-first; few aim to be spec-anchored (spec kept over time) or spec-as-source.
- **[pm-issue-310-to-tickets-rubber-stamp]** mattpocock/skills issue 310: to-tickets vertical-slice rule has no completeness check. https://github.com/mattpocock/skills/issues/310 Band: borderline | L8 | Supporting.
  Contribution: Layer-named slices can each look reasonable while the union omits the connecting step, owned by no ticket.
- **[pm-issue-476-wayfinder-claim-concurrency]** mattpocock/skills issue 476: wayfinder claim protocol fails under concurrent sessions. https://github.com/mattpocock/skills/issues/476 Band: borderline | L5 | Supporting.
  Contribution: Two sessions resolved the same wayfinder ticket one second apart; one ran as a bot identity that could not assign itself, so the claim was invisible.
- **[pm-issue-508-implement-no-completion]** mattpocock/skills issue 508: /implement has no completion step, finished tickets are never marked done. https://github.com/mattpocock/skills/issues/508 Band: borderline | L8 | Supporting.
  Contribution: After /implement finishes, the issue is left open with no closing comment, so the 'frontier' of unblocked tickets goes stale.
- **[pm-issue-828-wayfinder-stale-premises]** mattpocock/skills issue 828: wayfinder resolutions don't propagate to the tickets they invalidate. https://github.com/mattpocock/skills/issues/828 Band: borderline | L5 | Supporting.
  Contribution: About eight tickets in, one decision removed a whole concept, but four open tickets still described the old design; a fresh session would have resolved them against dead premises.
- **[pm-marmelab-sdd-waterfall]** Marmelab: Spec-Driven Development, The Waterfall Strikes Back. https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html Band: borderline | L7 | Supporting.
  Contribution: SDD (requirements, design doc, tasks, then agent) repeats Waterfall's heavy up-front documentation; the author says Big Design Up Front 'has proven to fail most of the time'.
- **[pm-metr-ai-slowdown-rct]** METR: Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity. https://arxiv.org/abs/2507.09089 Band: keep | L2 | Supporting.
  Contribution: In a randomized trial, allowing AI increased task completion time by 19 percent for experienced developers on mature projects.
- **[pm-pragmatic-engineer-pocock-interview]** The Pragmatic Engineer: AI Skills with Matt Pocock (Gergely Orosz). https://newsletter.pragmaticengineer.com/i/215854309/takeaways-from-the-conversation-with-matt Band: borderline | L6 | Supporting.
  Contribution: grill-me was inspired by Anthropic's Thariq Shihipar, who shared an approach of an agent interviewing its user; Matt turned it into a skill.
- **[pm-repo-ask-matt-router]** mattpocock/skills: ask-matt SKILL.md (the intended end-to-end flow). https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/ask-matt/SKILL.md Band: borderline | L7 | Core (override: borderline band).
  Contribution: Main flow: grill-with-docs, optional prototype detour, then (if multi-session) to-spec, to-tickets, then implement per ticket or implement-spec for the whole graph, closing with code-review ...
- **[pm-repo-changelog]** mattpocock/skills: CHANGELOG.md (renames, graduations, v1.1.0 to v1.3.1). https://raw.githubusercontent.com/mattpocock/skills/main/CHANGELOG.md Band: keep | L5 | Core.
  Contribution: to-prd was renamed to to-spec and to-issues became to-tickets in the 1.1.0 'Unify the planning skills' change; 'spec' is now the single term.
- **[pm-repo-to-tickets-skill]** mattpocock/skills: to-tickets SKILL.md (current main). https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md Band: borderline | L7 | Core (override: borderline band).
  Contribution: Tickets are tracer-bullet vertical slices: each cuts a narrow complete path through every layer, is demoable on its own, and is sized for one fresh context window.
- **[pm-repo-triage-skill]** mattpocock/skills: triage SKILL.md (state machine, ready-for-agent / ready-for-human). https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/triage/SKILL.md Band: borderline | L7 | Core (override: borderline band).
  Contribution: Triage is a five-state machine (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix) plus a bug/enhancement category; every issue carries exactly one of each.
- **[pm-repo-wayfinder-skill]** mattpocock/skills: wayfinder SKILL.md (decision-ticket map for work bigger than one session). https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md Band: borderline | L7 | Core (override: borderline band).
  Contribution: A wayfinder map is one tracker issue (label wayfinder:map) that is an index: Destination, Notes, Decisions so far, Not yet specified, Out of scope. Detail lives in child decision tickets.
- **[pm-shape-up-set-boundaries]** Basecamp Shape Up: Set Boundaries (appetite, fixed time and variable scope). https://basecamp.com/shapeup/1.2-chapter-03 Band: borderline | L7 | Supporting.
  Contribution: Appetite is a time budget set before design: 'Estimates start with a design and end with a number. Appetites start with a number and end with a design.'

### 7.4 Native Claude features

- **[native-agent-skills-comparison-doc]** agent-skills project comparison doc (agent-skills vs Superpowers vs Pocock). https://raw.githubusercontent.com/addyosmani/agent-skills/main/docs/comparison.md Band: borderline | L7 | Supporting.
  Contribution: Matt's skills are described as a "sharp, opinionated Claude Code toolkit distilled from one expert's daily workflow", with the center of gravity in grilling, not TDD.
- **[native-agent-teams]** Claude Code docs, Agent teams. https://code.claude.com/docs/en/agent-teams Band: keep | L4 | Core.
  Contribution: Agent teams are experimental and disabled by default; one lead session coordinates teammates that share a task list and message each other directly.
- **[native-agent-view]** Claude Code docs, Agent view and background sessions. https://code.claude.com/docs/en/agent-view Band: keep | L4 | Core.
  Contribution: `claude agents` opens one screen for all background sessions with states Working, Needs input, Idle, Completed, Failed, Stopped; sessions can be started with `claude --bg`, `/bg`, or the ...
- **[native-agentskills-open-standard]** Agent Skills open standard (agentskills.io). https://agentskills.io/home Band: keep | L4 | Core.
  Contribution: A skill is a folder with a `SKILL.md` (name, description, instructions) plus optional scripts, references, assets; agents load it by progressive disclosure.
- **[native-anthropic-engineering-blog-skills]** Anthropic engineering blog, Equipping agents with Agent Skills. https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills Band: keep | L4 | Supporting.
  Contribution: Progressive disclosure is stated as the core design principle of Agent Skills.
- **[native-anthropic-skill-best-practices]** Anthropic, Skill authoring best practices. https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices Band: keep | L4 | Core.
  Contribution: Anthropic's stance is "concise is key": the context window is shared, so SKILL.md should only add what Claude does not already know, and stay under 500 lines.
- **[native-arxiv-skill-selection-scaling]** arXiv 2601.04748, single agent with skills vs multi-agent. https://arxiv.org/abs/2601.04748 Band: borderline | L3 | Supporting.
  Contribution: The paper argues that a single agent selecting from skills can approximate a multi-agent system with less token use and latency, on reasoning benchmarks.
- **[native-chatbotkit-skills-expensive-rag]** ChatBotKit, Skills: an expensive form of RAG. https://chatbotkit.com/reflections/skills-an-an-expensive-form-of-rag Band: borderline | L7 | Supporting.
  Contribution: Thesis: skills, MCP tools, and RAG all solve selective retrieval, and skills have the worst context economics.
- **[native-claude-skills-docs]** Claude Code docs, Skills. https://code.claude.com/docs/en/skills Band: keep | L4 | Core.
  Contribution: Claude Code skills follow the Agent Skills open standard and add Claude Code extensions: invocation control, subagent execution, and dynamic context injection.
- **[native-commands-bundled-skills]** Claude Code docs, Commands and bundled skills. https://code.claude.com/docs/en/commands Band: keep | L4 | Core.
  Contribution: Native `/code-review` (alias `/review`) reviews the current diff or a PR for correctness bugs, with effort levels, `--fix`, `--comment`, and a cloud `ultra` mode; Matt's `/code-review` is a ...
- **[native-cross-session-messaging]** Claude Code docs, Cross-session messaging. https://code.claude.com/docs/en/cross-session-messaging Band: keep | L4 | Core.
  Contribution: Claude can list and message your other sessions on this machine, on other machines, and in the cloud, using `ListAgents` and `SendMessage`; no setup is needed once the version requirement ...
- **[native-dynamic-workflows]** Claude Code docs, Dynamic workflows. https://code.claude.com/docs/en/workflows Band: keep | L4 | Core.
  Contribution: A dynamic workflow is a JavaScript script that orchestrates many subagents; the runtime runs it in the background and keeps intermediate results in script variables, not Claude's context.
- **[native-memory-claude-agents-md]** Claude Code docs, CLAUDE.md, AGENTS.md and auto memory. https://code.claude.com/docs/en/memory Band: keep | L4 | Supporting.
  Contribution: Claude Code can read a repository's AGENTS.md in place of CLAUDE.md, so one instruction file can serve several agents.
- **[native-official-marketplace-listing]** anthropics/claude-plugins-official marketplace listing. https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json Band: keep | L4 | Supporting.
  Contribution: `mattpocock-skills` is a listed plugin in Anthropic's official marketplace, category development, sourced from the author's own repo at a pinned commit.
- **[native-parallel-agents-overview]** Claude Code docs, Run agents in parallel (overview). https://code.claude.com/docs/en/agents Band: keep | L4 | Core.
  Contribution: Claude Code now has five native parallelism approaches: subagents, agent view, agent teams, projects (cloud, beta), and dynamic workflows, plus worktrees, cross-session messaging, and ...
- **[native-pocock-implement-spec]** mattpocock/skills implement-spec skill. https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement-spec/SKILL.md Band: keep | L7 | Core.
  Contribution: `implement-spec` is `disable-model-invocation: true` and treats tickets as a task graph with a "frontier" of ready work, run by implementer subagents in the background.
- **[native-pocock-out-of-scope-harness]** mattpocock/skills .out-of-scope decisions (harness-neutrality). https://raw.githubusercontent.com/mattpocock/skills/main/.out-of-scope/native-question-tool.md Band: keep | L7 | Core.
  Contribution: Matt keeps skills harness-neutral: he refuses to call Claude Code's `AskUserQuestion` in grilling, because structured pickers push toward multiple-choice answers and each harness has a ...
- **[native-pocock-skills-readme]** mattpocock/skills README (primary). https://raw.githubusercontent.com/mattpocock/skills/main/README.md Band: keep | L7 | Core.
  Contribution: The catalog is built on the Agent Skills format and installs three ways: a Claude Code plugin (`claude plugin install mattpocock-skills@claude-plugins-official`), plugin marketplaces for ...
- **[native-questionpro-grill-vs-plan-mode]** QuestionPro Engineering, Stop Asking Claude to Agree With You. https://www.questionpro.com/engineering/engineering/developer%20tools/ai%20&%20machine%20learning/stop-asking-claude-to-agree-with-you/ Band: borderline | L8 | Supporting.
  Contribution: The author argues native plan mode answers how to build, not whether the thing is worth building.
- **[native-routines]** Claude Code docs, Routines. https://code.claude.com/docs/en/routines Band: keep | L4 | Supporting.
  Contribution: A routine is a saved prompt plus repositories and connectors that runs on Anthropic-managed cloud infrastructure on a schedule, an API call, or GitHub events.
- **[native-sandcastle-readme]** mattpocock/sandcastle README (primary). https://raw.githubusercontent.com/mattpocock/sandcastle/main/README.md Band: keep | L7 | Core.
  Contribution: Sandcastle is a TypeScript library: one `run()` call sandboxes an agent, runs it on a configurable branch strategy, and merges its commits back; providers are Docker, Podman, Vercel ...
- **[native-scheduled-tasks-loop]** Claude Code docs, Scheduled tasks and /loop. https://code.claude.com/docs/en/scheduled-tasks Band: keep | L4 | Supporting.
  Contribution: `/loop` and the cron tools are session-scoped: tasks only fire while Claude Code is running and idle, and recurring tasks expire seven days after creation.
- **[native-skill-shadowing-icml]** "More Skills, Worse Agents?" (ICML 2026 workshop). https://icml.cc/virtual/2026/77891 Band: keep | L3 | Supporting.
  Contribution: The study reports that performance can drop by up to 21% when a library grows from a small helpful set to 202 skills.
- **[native-subagents]** Claude Code docs, Subagents. https://code.claude.com/docs/en/sub-agents Band: keep | L4 | Supporting.
  Contribution: A subagent runs in its own context window with its own system prompt, tool access, and permissions, and returns only a summary.

### 7.5 Cortex Code CLI

- **[cortex-agentskills-spec]** Agent Skills specification (agentskills.io). https://agentskills.io/specification Band: keep | L4 | Supporting.
  Contribution: The standard frontmatter fields are name, description, license, compatibility, metadata, and allowed-tools (experimental); `disable-model-invocation` does not appear in the page text ...
- **[cortex-capitalone-review]** Capital One Software, hands-on review of Cortex Code CLI. https://capitalonesoftware.com/blog/snowflake-coco-cli Band: keep | L5 | Core.
  Contribution: Cortex consults its built-in skills proactively (Streamlit skills in the test), so bundled Snowflake skills already cover the domain work (dbt, Streamlit, Airflow) that a generic skill ...
- **[cortex-changelog]** Snowflake docs, Cortex Code changelog (CLI). https://docs.snowflake.com/user-guide/cortex-code/changelog Band: keep | L4 | Core.
  Contribution: Version 1.0.77 added `.agents/skills` as a project-level skill discovery directory, which is the shared path that Codex, Cline, Warp, and others use, so skills installed for those agents ...
- **[cortex-claude-skills-docs]** Claude Code docs, Skills (invocation control extensions). https://code.claude.com/docs/en/skills Band: keep | L4 | Supporting.
  Contribution: `disable-model-invocation: true` stops Claude from triggering a skill automatically, making it user-invoked only; most of Matt's workflow skills (to-tickets, triage, setup, implement, ...
- **[cortex-coco-skills-repo]** Snowflake-Labs/cortex-code-skills (community skills catalog). https://github.com/Snowflake-Labs/cortex-code-skills Band: keep | L5 | Supporting.
  Contribution: Cortex ships with 50+ bundled skills and extends via community Agent Skills; this repo uses the agentskills.io format.
- **[cortex-extensibility-docs]** Snowflake docs, Cortex Code CLI extensibility. https://docs.snowflake.com/user-guide/cortex-code/extensibility Band: keep | L4 | Core.
  Contribution: Skills are directories with a SKILL.md, loaded from `.cortex/skills/` or `.claude/skills/` (project) and `~/.snowflake/cortex/skills/` or `~/.claude/skills/` (user), so an existing Claude ...
- **[cortex-mattpocock-readme]** mattpocock/skills README (install matrix and Cortex absence). https://github.com/mattpocock/skills Band: keep | L5 | Core.
  Contribution: The README names no Cortex Code or Snowflake support; a case-insensitive search of the README for "cortex", "snowflake", and "coco" returned no matches, and GitHub issue searches on the ...
- **[cortex-overview-agentsmd]** Snowflake docs, Cortex Code overview (AGENTS.md support). https://docs.snowflake.com/user-guide/cortex-code/cortex-code Band: borderline | L4 | Supporting.
  Contribution: The CLI is documented as supporting `AGENTS.md` files and Agent Skills for per-project behavior.
- **[cortex-plugins-docs]** Snowflake docs, Cortex Code CLI plugins. https://docs.snowflake.com/user-guide/cortex-code/cortex-code-plugins Band: keep | L4 | Core.
  Contribution: A Cortex plugin accepts a manifest at `.cortex-plugin/plugin.json` or `.claude-plugin/plugin.json`, with `.cortex-plugin` winning if both exist.
- **[cortex-pocock-git-guardrails-skill]** mattpocock/skills, git-guardrails-claude-code SKILL.md. https://github.com/mattpocock/skills/blob/main/skills/misc/git-guardrails-claude-code/SKILL.md Band: keep | L5 | Supporting.
  Contribution: The skill is explicitly Claude Code specific and works by installing a PreToolUse hook that blocks destructive git commands.
- **[cortex-pocock-to-tickets-skill]** mattpocock/skills, to-tickets SKILL.md (tracker dependence, Claude-style frontmatter). https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md Band: keep | L5 | Core.
  Contribution: The frontmatter carries `disable-model-invocation: true`, a Claude Code key that is not in the Agent Skills open specification's field list; whether Cortex honors it is not documented ...
- **[cortex-snowflake-blog-dbt-benchmark]** Snowflake blog, Cortex Code CLI expands to dbt and Airflow. https://www.snowflake.com/en/blog/cortex-code-cli-expands-support/ Band: borderline | L9 | Supporting.
  Contribution: Snowflake states that Cortex Code CLI understands and supports popular dbt and Airflow patterns.
- **[cortex-subagent-cortex-code-repo]** Snowflake-Labs/subagent-cortex-code (Claude Code skill that delegates to Cortex). https://github.com/Snowflake-Labs/subagent-cortex-code Band: keep | L5 | Supporting.
  Contribution: Snowflake-Labs ships a skill that lets Claude Code, Cursor, Codex, Copilot, and Windsurf route Snowflake operations to Cortex Code CLI in headless mode.
- **[cortex-vercel-skills-agent-table]** vercel-labs/skills README, supported agents table (Cortex Code row). https://github.com/vercel-labs/skills Band: keep | L5 | Core.
  Contribution: The `skills` CLI has a first-class `cortex` agent with project dir `.cortex/skills/` and global dir `~/.snowflake/cortex/skills/`.

### 7.6 Excluded sources

- **[what-aihero-cohort-page]** AI Hero cohort page: Claude Code for Real Engineers (2026-04). Band: reject | L9 | Excluded.
  Reason: Real-cut: lowest-scoring source evaluated (borderline-to-reject). It is a sales page with no outcome data and no live price. Excluded from evidence for claims about effectiveness; kept only as a pointer for the paid-offer structure, with the structure claim ...
- **[what-hn-skills-thread]** Hacker News: 'AI Coding Agent Skills for Real Engineers' (mattpocock/skills thread). Band: reject | L8 | Excluded (superseded by mp-reception-hn-ai-coding-agent-skills-thread).
  Reason: Redundant (Rule 5): the same HN thread is carded with a stronger score in reception-hn-ai-coding-agent-skills-thread, which carries the finding. The card-stage diversity override was withdrawn.
- **[reception-andrew-ooo-review]** andrew.ooo: "Matt Pocock's Skills Review: 54k Stars for Claude Code". Band: reject | L9 | Excluded.
  Reason: Reject band: SEO-style review with unsourced numbers. Recorded as the secondhand-Reddit pointer and a low-rigor example only; no finding rests on it.
- **[reception-hn-comment-agents-too-complicated]** HN comment (pipes): skills including grill-me "helped a bit" with over-complicated agent code. Band: reject | L8 | Excluded.
  Reason: Reject band (4.6 average): a single unsubstantiated anecdote. Kept as a documented cut; no finding rests on it.
- **[reception-hn-comment-prior-art-marketing]** HN comment (brandall10): Pocock's grill-me is prior art, promoted by pervasive marketing. Band: reject | L8 | Excluded.
  Reason: Reject band: unsourced single assertion by an anonymous account; recorded so the educator-vs-practitioner critique is visible as an evidence gap, not used for any finding. This is the lowest-scoring card.
- **[reception-juejin-all-18-skills]** Juejin (Chinese): "I used all 18 of Matt Pocock's skills" (launch narrative). Band: reject | L8 | Excluded.
  Reason: Reject band (4.4 average): stale, unsourced launch statistics from an enthusiast tutorial; kept as the documented cut for non-English coverage. The launch-date claim is flagged as contested rather than used.
- **[pm-besthub-grill-with-docs-vs-superpowers]** BestHub: Exploring /grill-with-docs, a New Rival to Superpowers. Band: reject | L8 | Excluded.
  Reason: Scores in the reject band (unattributed, single-project, aggregator); not relied on in findings. Kept as a documented cut. The same invoke-by-hand point is better sourced from the repo's own disable-model-invocation flags and the Addy Osmani comparison.
- **[native-besthub-grill-vs-superpowers]** BestHub, Exploring /grill-with-docs vs Superpowers. Band: borderline | L8 | Excluded (same article as mp-pm-besthub-grill-with-docs-vs-superpowers, reject band; point carried by mp-reception-nocoders-superpowers-vs-pocock).
  Reason: Redundant (Rule 6): the same article was scored in the reject band by the PM track; its hooks-versus-manual point is carried by reception-nocoders-superpowers-vs-pocock.

