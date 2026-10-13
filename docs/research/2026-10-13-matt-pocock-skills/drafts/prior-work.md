# Prior-work catalog (D1): what borg-collective already has

Purpose: list what exists in this repo that overlaps a general-purpose engineering-skills library, so options can be generated without anchoring on it. Sources: skills/*/SKILL.md, agents/*.md, docs/plans/directives/, config/claude/CLAUDE.md, and the 2026-10-13 internal lifecycle audit and report. Usage counts come from about 35 days of session transcripts (a floor, not a quarter) and count top-level skill calls only, so they understate agent-spawned use.

Format per line: what it is | where | gets right | gets wrong.

## Skills: planning and shaping

- /borg-plan: proposes objectives and acceptance criteria from the codebase, human validates, criteria locked in PROJECT_PLAN.md | skills/borg-plan | agent does the thinking and the human only decides; lock prevents drift | single active plan per repo; heavy ceremony for a solo dev; used 6 times
- /borg-collective-review: six core personas plus code owners and a rotating specialist debate a plan or ship decision | skills/borg-collective-review | adversarial, called from plan and assimilate | Opus-level token cost; correlated model voices; used 4 times
- /borg-review: mid-session diagnostic that checks progress against the plan and gives ONE next recommendation | skills/borg-review | single recommendation, scope-creep detection | zero uses in the window; not a code review despite the name
- /borg-assimilate: ship checklist against acceptance criteria, then merge and archive with confirmation | skills/borg-assimilate | rigorous "are we done" gate that resists one more thing | used 2 times; most merges bypass it
- research-tools plugin (/brainstorm, /research, /deep-research, analyst and verifier agents) | claude-plugins, not this repo | the most-used planning-adjacent tools (research 27, brainstorm 7, deep-research 6) | lives outside borg, so plan-to-research linkage is manual
- design-doc skill | noah-content-tools plugin in claude-plugins | produces design docs on demand | no link to PROJECT_PLAN.md or directives

## Skills: execution, quality, review

- /simplify: reviews files changed this session for reuse, dead code and needless complexity, and fixes them | skills/simplify | fixes rather than reports; scoped to session diff | advisory only, enforced by a pre-commit reminder hook, not a gate
- /fable-reviewer: five-gate discipline (scope before work, evidence before reasoning, adversarial self-review, real-suite verification, response calibration) | skills/fable-reviewer | closest thing here to a general working-discipline skill | borg-specific wording (bats/pytest); no with/without eval of its effect
- /borg-verify: spawns a fresh read-only verifier agent to rerun tests, map acceptance criteria to diff evidence and return PASS/FAIL before merge | skills/borg-verify with agents/borg-verifier.md and hooks/borg-verifier-guard.sh | independent context; read-only enforced by a hook allowlist | opt-in by convention; the audit found it used on a small share of merges before the 2026-10-13 verify-by-default directive
- adhd-guardrails (always on): pushes back on perfectionism, flags scope expansion, shame-free language, done criteria in every plan | skills/adhd-guardrails | a persistent behavioral skill, not a command | cannot be measured; fires on every interaction (token cost)
- no-unnecessary-read-perms (always on) and break-glass (permission exception escape hatch) | skills/ | cut permission-prompt friction | pure environment plumbing, no lifecycle value; break-glass zero uses

## Skills: state, handoff, attention

- /borg-link-up: flush session state to .borg/checkpoints/<ts>.md; the SessionStart hook reloads it | skills/borg-link-up | most-used skill (33 slash plus 4); eliminates context rebuild | one of about six overlapping state stores (checkpoints, handovers, memory, .borg/knowledge, PROJECT_PLAN.md, directives)
- /borg-link: scope-aware status page (orchestrator overview vs single repo page) via the borg link engine | skills/borg-link | second most used (25); thin skill over a deterministic engine | engine is large shell and Python surface that native agent view may absorb
- /borg-next: ranked chooser of what needs attention, owner YOU or AGENT | skills/borg-next | uses a structured picker; decision-surfacing default-the-obvious | rows are capped; 3 uses
- /borg-recon: fan-out sweep of changes since a mark across pluggable adapters, with Yours vs Mine action lists | skills/borg-recon | source-agnostic adapters | retired as a human verb
- /borg-resume: manual and fallback resume after a session or usage limit interruption; primary path is a launchd watcher | skills/borg-resume | handles a real failure mode (limits killing workflows) | newest and least proven; waves of open PRs
- /borg-switch and /pane: tmux window and pane navigation | skills/ | trivial CLI wrappers | environment-specific, no portability

## Agents

- borg-nanoprobe (Sonnet): single-task worker in its own worktree, opens a PR, scope gate of at most 2 deliverables, write-first and lean-return contracts | agents/borg-nanoprobe.md | scope gate and bounded reads prevent runaway work; heavily used (127 spawns) | no test-first step; verify not part of its tail until the 2026-10-13 directive
- borg-verifier (Sonnet, read-only): independent merge evaluator | agents/borg-verifier.md | no Edit or Write tools, hook-enforced | 12 spawns
- borg-reviewer (Sonnet, high effort): blind adversarial reviewer that never sees the author's reasoning | agents/borg-reviewer.md | cold review beats self-critique | used more on plans than on code diffs (19 spawns)
- borg-researcher (Sonnet, web-enabled): one research track, writes findings to a supplied path | agents/borg-researcher.md | evidence-first, track-scoped | 49 spawns, cost grows with fan-out
- borg-scout (Haiku, read-only locate) and borg-grunt (Haiku, one fully specified mechanical change) | agents/ | cheap tiers for no-judgment work | scout nearly unused (2); 37 general-purpose spawns still bypassed routing
- Model guards (agent-model-guard, workflow-model-guard) | hooks/ | explicit model on every spawn is the cost lesson | part of a 17-hook surface with about 700 lines of guard logic

## Directives and process records (docs/plans/directives, 27 files; 74 assimilated plans)

- 2026-10-13 lifecycle-hybrid-weeks-1-2: verify-by-default, test-first prompt in nanoprobe briefs, probes, deletion-PR rule, infra budget | the live decision that governs adoptions from outside libraries | Proposed, not design-reviewed
- 2026-10-03 evals-for-everything: ledger and plugin-eval for skills and agents | the only mechanism that could falsify a skill's value | Phase 1 not shipped
- 2026-08-20 communication-program and directive-state-deriver | status vocabulary and plan state | status vocabulary still inconsistent (Proposed, Accepted, Approved, in flight)
- 2026-08-08 cairn decommission: volunteered knowledge capture died | a durable lesson against second write surfaces | informs any proposal to add a glossary or context store
- 2026-10-13 shell-command-hygiene, 2026-10-10 scout-shell-allowlist, 2026-09-28 worktree-identity | environment hardening | not lifecycle-relevant but they consume the same maintenance budget

## Conventions in config/claude/CLAUDE.md (shipped to every machine)

- Bash rules (plain commands by default, no command substitution, absolute paths) and subagent rules to pass into every spawn | gets right: reduces permission prompts and classifier refusals | gets wrong: environment-specific, would not transfer to another harness
- No coding-style, testing or domain-language conventions are in that file; those live per repo in each project CLAUDE.md. Test-first is a memory rule, not an enforced gate.

## Known gaps relevant to a skills comparison (from the audit)

- No test-first enforcement and no coverage or mutation tooling.
- No shared domain glossary or context file convention across projects.
- No plan-to-ticket linkage; plans live in markdown, the board is sparse.
- No deploy skill (the memory and brainstorm references to /borg-deploy point at something that was never built) and no production monitoring.
- Infra was about 79% of merged PRs; the library is a heavy DIY surface and the standing guidance is "maintain, do not expand".
- Dormant by transcript count: borg-review, break-glass, repo-review, reconcile-req, capability-index.

## Outside frameworks already evaluated (2026-10-13 methodology track) and prior stance

Stance column is the 2026-10-13 hybrid decision: borg stays the spine, adopt cheap stateless prompts, defer any state store behind a spike.

- obra/superpowers (MIT, v7.0, large, official marketplace): brainstorm, worktrees, 2-5 minute plan tasks, fresh subagent plus review per task, strict TDD, code review, branch finish | stance: cherry-pick the TDD prompt into nanoprobe briefs; do not install wholesale (auto-trigger token cost; copied prompts drift)
- EveryInc/compound-engineering-plugin (MIT): 36 skills, review report-only multi-agent, ce-compound writes docs/solutions learnings read by the next plan | stance: borrow the docs/solutions idea only, with care given the cairn lesson
- github/spec-kit (MIT): constitution, specify, plan, tasks, implement, converge | stance: not adopted; heavy spec ceremony vs the AC-lock already in borg-plan
- Fission-AI/OpenSpec (MIT): proposal, delta specs, archive per change | stance: not adopted; partly duplicates plans/assimilated archive
- BMAD-METHOD (MIT text): agile persona framework | stance: not adopted; persona overlap with the Collective, heavier
- gotalab/cc-sdd (MIT, small): fresh implementer per task, independent reviewer, auto-debug | stance: noted as closest shape to nanoprobe plus reviewer; no adoption
- spec-kitty (MIT, small): worktree per work package, review lanes | stance: noted as closest to worktree-plus-review lanes; no adoption
- MrLesk/Backlog.md (MIT): markdown tasks in repo | stance: deferred; not canonical until a concurrency test across worktrees passes
- Beads and Gas City / Gas Town (MIT): agent task ledger and orchestrator | stance: deferred behind spikes (Dolt dependency, per-repo scope, no devcontainer model)
- agent-os, conductor, get-shit-done, AGENTS.md convention | stance: lightweight or stale; no adoption
- Disqualified on licence or status: Task Master (Commons Clause), pilot-shell (proprietary), spec-workflow-mcp (GPL-3.0), cavekit (frozen)
- Native Claude Code features (agent view, teams, messaging, routines): stance is watch and trial; E1 showed native agents can see and reach a drone session
- Decision-rule carried forward: every adoption names a deletion PR; adopt prompts and stateless pieces, not new state stores.

## Not yet evaluated before this pass

- Matt Pocock's skills library was not among the frameworks above. This catalog is the baseline against which it should be compared; nothing here pre-judges it.
- Obsidian was judged only as a knowledge surface (decided no); no skills library has been judged against the dormant-skill evidence.
