# Research Foundation

Every design decision in The Borg Collective is backed by published research. This document provides the complete citation index organized by domain, with URLs and a brief description of what each source contributes to the design rationale.

---

## ADHD and Executive Function

These sources establish the neurological basis for borg's boundary enforcement and cognitive load management features.

**Context switching costs 23+ minutes to rebuild mental models.**
Wake Forest University (2024). "The Switch Cost of Multitasking."
https://news.wfu.edu/2024/04/16/the-switch-cost-of-multitasking/
*Basis for: tmux window integration, `borg switch` reducing search time, session summaries as instant context restoration.*

**89% of children with ADHD have specific executive function impairments.**
NIH/PMC (2015). "Executive Function in Children with ADHD."
https://pmc.ncbi.nlm.nih.gov/articles/PMC4425416/
*Basis for: external scaffolding over willpower tenet. Working memory, inhibition, and cognitive flexibility are impaired.*

**fMRI shows ADHD brains work harder during decision tasks; all information weighed equally.**
Relational Psychology Group. "ADHD and Decision Paralysis."
https://www.relationalpsych.group/articles/adhd-and-decision-paralysis-why-small-choices-can-feel-overwhelming
*Basis for: `borg next` single recommendation, flat project lists causing paralysis, `BORG_MAX_ACTIVE` limit.*

**Limiting choices reduces cognitive load and prevents overanalysis.**
Focus Bear. "Choice Paralysis ADHD Tips."
https://www.focusbear.io/blog-post/choice-paralysis-adhd-tips-for-easier-decision-making
*Basis for: binary pin flag (not priority numbers), archiving stale projects, capacity warnings.*

Psychology Today (2024). "Overcoming Decision Fatigue in ADHD."
https://www.psychologytoday.com/us/blog/changing-the-narrative-on-adhd/202405/overcoming-decision-fatigue-in-adhd
*Basis for: Eisenhower-style prioritization simplified to a single boolean flag.*

**Body doubling (including AI) measurably improves sustained attention and task completion.**
ArXiv (2025). "Neurodivergent-Aware Productivity Framework."
https://arxiv.org/html/2507.06864
*Basis for: `borg next` as digital body double; AI providing accountability presence.*

ADDA. "The Body Double."
https://add.org/the-body-double/
*Basis for: understanding body doubling mechanism and applying it to CLI tooling.*

**Perfectionism is common in ADHD, leading to scope creep and avoidance.**
Psychology Today (2025). "Adult ADHD and Perfectionism."
https://www.psychologytoday.com/us/blog/rethinking-adult-adhd/202503/adult-adhd-and-perfectionism
*Basis for: `done_when` acceptance criteria, Scope Guard skill, `/simplify` as "good enough" declaration.*

ADDA. "ADHD and Perfectionism."
https://add.org/adhd-and-perfectionism/
*Basis for: understanding the paradox and designing around it.*

**Recovery from hyperfocus is as important as breaking it.**
UK Psychiatry. "How to Break the Hyperfocus Cycle."
https://www.audhdpsychiatry.co.uk/how-to-break-hyperfocus-cycle/
*Basis for: `BORG_SESSION_WARN_HOURS` duration warning, structured break suggestions.*

Dr. Sharon Saline. "From Hyperfixation to Balance."
https://www.drsharonsaline.com/blog/2025/10/hyperfixationadhd
*Basis for: work/life time boundaries, recovery time design.*

**ADHD context switching: slower executive function transition but lower stress from interruptions.**
PubMed (2000). "Task switching and attention deficit hyperactivity disorder."
https://pubmed.ncbi.nlm.nih.gov/10885680/
*Basis for: understanding that ADHD brains take longer to transition, making summaries at switch time critical.*

PMC (2018). "Selective Impairment of Attentional Set Shifting in Adults with ADHD."
https://pmc.ncbi.nlm.nih.gov/articles/PMC6230251/
*Basis for: quantifying the switching cost specific to ADHD adults.*

**Accountability check-ins increase goal achievement from 25% to 95%.**
Edge Foundation. "Harnessing AI to Thrive with ADHD."
https://edgefoundation.org/harnessing-ai-to-thrive-in-the-workplace-with-adhd/
*Basis for: `borg next` as accountability mechanism, session checkpoint skills.*

**Executive function deficits are the primary predictor of ADHD burnout.**
PMC (2024). "Executive function deficits mediate the relationship between employees' ADHD and job burnout."
https://pmc.ncbi.nlm.nih.gov/articles/PMC11007411/
*Basis for: burnout prevention being a first-class design goal, not an afterthought.*

---

## UX Design for Neurodivergent Users

**15-20% of the worldwide population is neurodivergent.**
Interaction Design Foundation. "How to Design for Neurodiversity."
https://www.interaction-design.org/master-classes/how-to-design-for-neurodiversity-inclusive-content-and-ux
*Basis for: taking neurodivergent design seriously as a mainstream concern, not a niche.*

**Distraction-free modes are essential for ADHD users.**
UXmatters (2024). "Embracing Neurodiversity in UX Design."
https://www.uxmatters.com/mt/archives/2024/04/embracing-neurodiversity-in-ux-design-crafting-inclusive-digital-environments.php
*Basis for: dimming out-of-context projects, clean `borg ls` output, archiving stale items.*

**Adaptive UX frameworks for AI-driven interfaces should integrate cognitive load management.**
ResearchGate (2025). "Adaptive UX Frameworks for Neurodivergent Users."
https://www.researchgate.net/publication/393905078_Adaptive_UX_Frameworks_for_Neurodivergent_Users_Integrating_Cognitive_Load_Management_into_AI-Driven_Interfaces
*Basis for: time-of-day-aware display changes, capacity warnings, staleness detection.*

---

## Shipping Discipline

**"Prompt specificity determines scope." Vague prompts expand implementation fourfold.**
LogRocket. "Ralph Makes Claude Code Finish Tasks."
https://blog.logrocket.com/ralph-claude-code/
*Basis for: `goal` and `done_when` registry fields, acceptance criteria pattern.*

Ralph Framework. GitHub.
https://github.com/snarktank/ralph
*Basis for: fresh context per iteration, acceptance criteria as completion gates.*

**"Protocol is better than heroics."**
Adaline Labs. "How to Ship Reliably with Claude Code."
https://labs.adaline.ai/p/how-to-ship-reliably-with-claude-code
*Basis for: PM Build Protocol, plan mode gates, subagent review.*

**"I wasn't coding with Claude Code. I was gambling with it."**
Prompt Contracts. Medium.
https://medium.com/@rentierdigital/i-stopped-vibe-coding-and-started-prompt-contracts-claude-code-went-from-gambling-to-shipping-4080ef23efac
*Basis for: structured specifications over vibe coding, `done_when` criteria.*

**"More code means better software is a horrible myth."**
Adam Drake. Medium.
https://medium.com/@adam_drake
*Basis for: compose-first architecture, thin glue layer, Phase 3 deletion.*

**Ship features in one 45-90 minute session.**
TurboDocx. "How I Use Claude Code to Ship Features in One Session."
https://www.turbodocx.com/blog/how-i-use-claude-code-to-ship-features-in-one-session
*Basis for: director mindset, acceptance criteria, timeboxed sessions.*

**incident.io: 4-5 parallel agents, JS editor upgrade 10 min (estimated 2 hours).**
incident.io Blog. "Shipping Faster with Claude Code and Git Worktrees."
https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees
*Basis for: parallel worktree pattern validation, real-world performance data.*

---

## Claude Code Best Practices (Boris Cherny)

**3-5 parallel worktrees is the single biggest productivity multiplier.**
How Boris Uses Claude Code.
https://howborisusesclaudecode.com/
*Basis for: entire parallel session management paradigm.*

**CLAUDE.md: keep minimal, update after corrections.**
HumanLayer. "Writing a Good CLAUDE.md."
https://www.humanlayer.dev/blog/writing-a-good-claude-md
*Basis for: CLAUDE.md best practices, <300 lines guideline.*

Builder.io. "How to Write a Good CLAUDE.md."
https://www.builder.io/blog/claude-md-guide
*Basis for: progressive disclosure, what to include vs exclude.*

**"Give Claude a way to verify its work." 2-3x quality improvement.**
Claude Code Docs. "Best Practices."
https://code.claude.com/docs/en/best-practices
*Basis for: verification loops, test-driven workflows, Scope Guard.*

**Context is the fundamental constraint. Manage it aggressively.**
Claude Code Docs. "Manage Context Aggressively."
https://code.claude.com/docs/en/best-practices#manage-context-aggressively
*Basis for: /compact, /clear, /rewind recommendations, checkpoint skills.*

**Skills encode discipline. If you do something more than once a day, make it a skill.**
Claude Code Docs. "Extend Claude with Skills."
https://code.claude.com/docs/en/skills
*Basis for: skills-first approach, portable discipline across tools.*

---

## AI Addiction Risk

**AIAS-21: 21-item assessment identifies compulsive use, craving, tolerance, withdrawal.**
Springer Nature (2025). "AI Addiction Scale."
https://link.springer.com/article/10.1007/s00787-025-02874-8
*Basis for: taking addiction risk seriously, boundary enforcement as health measure.*

**GenAI Addiction Syndrome proposed as recognized behavioral disorder.**
ScienceDirect (2025). "Generative AI Addiction."
https://www.sciencedirect.com/science/article/abs/pii/S1876201825001194
*Basis for: clinical context for work/life boundaries.*

**Channels and always-available features remove protective friction.**
Adam Drake. "Claude Code Just Released a Feature That Genuinely Scares Me."
Medium, March 2026.
*Basis for: speed bumps not walls tenet, time-of-day gating, "the friction was actually good" principle.*

**AI chatbot dependency research.**
TechPolicy.Press. "AI Chatbots and Addiction: What Does the Research Say?"
https://www.techpolicy.press/ai-chatbots-and-addiction-what-does-the-research-say/
*Basis for: understanding behavioral patterns and designing safeguards.*

---

## ADHD-Specific Claude Code Frameworks

**Zack Proser: Claude as external brain for ADHD/autistic cognition.**
https://zackproser.com/blog/claude-external-brain-adhd-autistic
*Basis for: compassionate constraints skill, bounded task execution, biometric awareness concept, shame-free language.*

**Mohamed Amgad: Obsidian + Claude Code for ADHD task management.**
https://amgad.io/posts/building-ai-assistant-productivity-claude-obsidian/
*Basis for: external brain pattern, chaos-adapted task tracking, deferred Obsidian integration.*

**7 Claude Code workflows for ADHD developers.**
DEV Community.
https://dev.to/chudi_nnorukam/adhd-devs-claude-code-workflows-1b5c
*Basis for: community validation of ADHD-first Claude Code patterns.*

**"Between hyper-focus and burnout: Developing with ADHD."**
Stack Overflow Blog (2024).
https://stackoverflow.blog/2024/05/10/between-hyper-focus-and-burnout-developing-with-code/
*Basis for: understanding the hyperfocus-burnout cycle in professional developers.*

**Compassionate constraints for neurodivergent developers.**
GitHub: assafkip/founder-skills.
https://github.com/assafkip/founder-skills
*Basis for: interaction rules that accommodate RSD, energy-based task assignment.*

---

## Skills Ecosystem

**alirezarezvani/claude-skills: 205+ production skills, 7,800+ GitHub stars.**
https://github.com/alirezarezvani/claude-skills
*Basis for: skills installation, engineering bundles, Scope Guard.*

**Skill eval framework for measurable quality.**
Reza Rezvani. "New Claude Skill Evals." Medium.
https://alirezarezvani.medium.com/
*Basis for: skill quality validation, iteration from 60% to 85%+ pass rates.*

**Claude Code plugin marketplace: 2,300+ skills.**
Claude Code Docs. "Discover and Install Plugins."
https://code.claude.com/docs/en/discover-plugins
*Basis for: installation workflow, marketplace add pattern.*

**Boris's 42 tips encoded as a single skill.**
Reza Rezvani. "Boris Cherny's Claude Code Tips Are Now a Skill." Medium.
https://alirezarezvani.medium.com/boris-chernys-claude-code-tips-are-now-a-skill-here-is-what-the-complete-collection-reveals-b410a942636b
*Basis for: treating tips as installable tools, not just reference material.*

---

## Devcontainers and Container Workflows

**Claude Code official devcontainer reference.**
https://github.com/anthropics/claude-code/tree/main/.devcontainer
*Basis for: devcontainer.json patterns, security model, volume mounting.*

**Claude Code devcontainer documentation.**
https://code.claude.com/docs/en/devcontainer
*Basis for: official support, CLAUDE_CONFIG_DIR env var.*

**Persisting Claude auth across container rebuilds.**
https://www.eke.li/vscode/2026/03/14/persist-claude-across-rebuilds.html
*Basis for: credential persistence strategy, .claude.json handling.*

**Running Claude Code safely in devcontainers.**
https://nakamasato.medium.com/using-claude-code-safely-with-dev-containers-b46b8fedbca9
*Basis for: security isolation tradeoffs.*

**One Project, One Container pattern.**
https://medium.com/rigel-computer-com/running-claude-code-in-docker-containers-one-project-one-container-1601042bf49c
*Basis for: per-project container isolation model.*

**Sharing Claude memory across multiple devcontainers.**
https://dev.classmethod.jp/en/articles/share-claude-mem-across-devcontainers/
*Basis for: bind-mount vs named volume tradeoffs for ~/.claude/.*

---

## Cortex Code CLI (CoCo)

**CoCo CLI documentation.**
https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli
*Basis for: understanding CoCo architecture, session management, config locations.*

**CoCo extensibility: skills, hooks, MCP.**
https://docs.snowflake.com/en/user-guide/cortex-code/extensibility
*Basis for: skill portability confirmation, hook format differences.*

**CoCo best practices.**
https://www.snowflake.com/en/developers/guides/best-practices-cortex-code-cli/
*Basis for: recommended workflows, integration patterns.*

**CoCo skills library.**
https://github.com/vinodhini-sd/coco-skills-library
*Basis for: community CoCo skill ecosystem.*

**Skills portability: "One Skill, Two AI Coding Assistants."**
Kelly Kohlleffel. Medium, March 2026.
https://medium.com/@kelly.kohlleffel/one-skill-two-ai-coding-assistants-snowflake-cortex-code-and-claude-code-92e0de8dfef2
*Basis for: skills as portable unit of discipline, cross-tool workflow encoding.*

**Docker and Podman coexistence.**
https://www.ericsbinaryworld.com/2019/11/02/can-docker-and-podman-both-run-on-the-same-machine/
*Basis for: confirming Docker (devcontainers) + Podman (CoCo) can run simultaneously.*
