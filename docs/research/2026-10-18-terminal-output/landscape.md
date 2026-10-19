# Agentic coding landscape since 2026-07-30, and what it replaces in borg

**Date:** 2026-10-18
**Question:** What has changed in agentic coding best practice since 2026-07-30, and which components of borg are now covered by native features or a well-supported tool?

Method note: prior research (2026-07-30 refresh, 2026-10-13 Pocock study, orchestration-architecture.md) was read and not redone. Everything below is from primary Claude Code docs, the changelog, Snowflake's changelog, arXiv abstracts and practitioner posts. Claims marked UNVERIFIED rest on one secondary source or an abstract only. Nothing was run; all replacement verdicts are hypotheses until the experiments in section 3 are run.

## Executive summary

- The biggest shift is not a feature, it is a closed gap. The 2026-07-30 refresh's validation spike asked whether native fan-out works when the orchestrator CWD is not a git repo. As of 2.1.281 (2026-09-23), `/batch` runs outside a git repo if a `WorktreeCreate` hook supplies worktrees. That is the exact failure that made nanoprobes manage their own worktrees. Re-run the spike now.
- Four things borg built by hand are now first-class natives: cross-session messaging (2.1.224, 2026-08-07, socket-based, with inbound controls and idle notices), agent view with `--json`, `attach`, `logs`, `respawn` and PR labels (cross-project, research preview), parameter-matched permission rules like `Agent(model:opus)` (2.1.178), and an `effort` parameter on the Agent tool (2.1.292). The dispatch guard and vinculum are the most replaceable components.
- Not replaced, and the docs say so: a human-authored cross-repo "what next" ordering, checkpoints as human framing, the usage guardian's proactive thresholds (native only retries and displays), recon's checkpoint-vs-GitHub contradiction logic, and Queen-by-CWD discipline. Native Projects (cloud, public beta, Pro/Max only) is the nearest Queen analogue but is cloud-first and not available on Team/Enterprise.
- Evidence on multi-agent value is still thin and mixed. Best reading: multi-agent helps on long, decomposable, independent work and costs far more tokens; borg's orchestrator-worker, no-mesh stance is consistent with it. Skills evals are now native (`claude plugin eval`), which makes "add evals to borg skills" cheap.
- Hype to discount: Gas Town (Yegge reportedly said his own workflow failed by Aug 2026), star counts for any pack, "Illusion of Multi-Agent Advantage" (tests auto-generated MAS on reasoning tasks, not coding), and secondary-blog usage-limit percentages.

## 1. What is new (dated, with URLs)

Claude Code (versions per changelog https://code.claude.com/docs/en/changelog and weekly digests https://code.claude.com/docs/en/whats-new). The Sept 14 to Sept 22 changelog span and digests for weeks 38 to 42 were not retrievable (digest URLs 404), so that window is thinner than the rest.

- 2026-08-03..07 (v2.1.224): cross-session messaging, `ListAgents` and `SendMessage` tools, local Unix socket, inbound controls `crossSessionInbound` accept/hold/refuse, `/list-agents`. Same week: 200-subagent cap removed; worktree isolation now blocks Bash and git redirects into the main checkout; background sessions that edit in a worktree commit and push before finishing; `/fork` makes its own worktree. https://code.claude.com/docs/en/whats-new/2026-w32 and https://code.claude.com/docs/en/cross-session-messaging
- 2026-08-14: auto mode becomes default permission mode on Pro/Max/Team. Same week 33: `@` mentions another session by name; fork mode on by default; auto-continue after a usage limit (Desktop only). https://code.claude.com/docs/en/whats-new
- 2026-08-17..21 (w34): `ANTHROPIC_DEFAULT_MODEL`; Concise output style; Remote Control device cards. https://code.claude.com/docs/en/whats-new
- 2026-08-24..28 (w35): `--restricted` for eval harnesses; `modelPicker` setting; `/resume` of CLI sessions in Desktop. https://code.claude.com/docs/en/whats-new
- 2026-08-31..09-04 (w36): `/skill-doctor` (context cost and usage per skill); `PreModelSwitch` and `PostModelSwitch` hooks; `/cost` prompt-cache line; per-model saved effort; Fable 5.1. https://code.claude.com/docs/en/whats-new/2026-w36
- 2026-09-07..11 (w37): `claude plugin eval` (cases plus graders, runs each case with and without the plugin, CI-gateable); `maxEffortLevel` cap on every provider. https://code.claude.com/docs/en/whats-new/2026-w37 and https://code.claude.com/docs/en/plugin-evals
- 2026-09-23 (2.1.281): `/batch` can run outside a git repo when a `WorktreeCreate` hook provides worktrees. 2026-09-22 (2.1.280/282): `--setting-sources` carried into spawned background sessions; `claude --bg` asks for workspace trust. https://code.claude.com/docs/en/worktrees
- 2026-09-24..28: resume of very large sessions faster; a session that ended mid-tool-call now tells Claude the outcome is unknown; `/rate-limit-options`; status line `rate_limits.spend_limit`; `/doctor prompt-audit`. https://code.claude.com/docs/en/changelog
- 2026-09-30..10-02 (2.1.286..288): unattended retry gives up after three stream timeouts (`CLAUDE_CODE_RETRY_WATCHDOG`); one limit per model call (max 14 requests); resume fixes (lost turns after parallel tool batch, truncated transcripts); PreToolUse and PermissionRequest hooks now block when matcher evaluation fails. https://code.claude.com/docs/en/changelog
- 2026-10-01 (2.1.287): Claude Mods (plugin hook layer with `agent.spawn` that can rewrite a subagent's prompt and model); replies from `claude agents` queue as messages. 2026-10-05 (2.1.290): `claude attach <name>`, `claude logs <name>`, background sessions survive `/loop` waits. https://code.claude.com/docs/en/changelog
- 2026-10-06 (2.1.292): `effort` parameter on the Agent tool; cloud sessions tell Claude which stopped background agents can be resumed by id. 2026-10-08..09 (2.1.295/296): `onFailure: "block"` for hooks; `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL`; per-subagent `autoCompactWindow`; Sonnet 5.5 cache reads halved to $0.10/MTok. 2026-10-14..16 (2.1.299..302): `CLAUDE_CODE_RETRY_WATCHDOG_MAX_USAGE_LIMIT_WAIT_MS`; `/usage` warns about max effort and workflows; idle compaction at ~54 minutes; fork subagents default in `claude -p`. https://code.claude.com/docs/en/changelog
- Docs state as of 2026-10-18: agent teams still experimental and off by default, no resume of in-process teammates, one team per session; agent view still research preview; routines still research preview; Projects (cloud threads, public beta, Pro/Max, not Team/Enterprise). https://code.claude.com/docs/en/agent-teams, https://code.claude.com/docs/en/agent-view, https://code.claude.com/docs/en/routines, https://code.claude.com/docs/en/claude-projects
- Anthropic engineering blog: no post dated 2026-08 or later found on the index (latest dated 2026-05-25, "How we contain Claude across products"; one undated featured post "Redesigning source control at Anthropic" was not read). https://www.anthropic.com/engineering
- Snowflake Cortex Code CLI: 1.1.65 (2026-08-11) data-discovery subagent on by default; 1.1.78 (2026-09-07) skill catalog on by default, resume keeps model; 1.1.87 (2026-09-14) conversation recall (`cortex conversations search`), `--fork`/`/fork`, restricted session scope on by default with child-session support. No worktrees, hooks, scheduled tasks or AGENTS.md entries in the visible window. Cortex stopped reading `.claude/settings.json` as project settings in an earlier release (1.1.47). https://docs.snowflake.com/user-guide/cortex-code/changelog
- Practitioners: Simon Willison, 2026-08-08 and 08-27 on auto mode (Anthropic reports 89% harmful actions blocked, 0 of 720 injections; independent attack reportedly worked ~80%; his conclusion: adversarial content needs sandboxes); 2026-09-18 AGENTS.md fallback in Claude Code 2.1.277; 2026-10-16 Claude Code team reviews continuously while code is written. https://simonwillison.net/tags/claude-code/
- Steve Yegge: an ai.engineer profile says that by August 2026 he reported his own Gas Town workflow had failed and moved to a private harness (Wheelhouse). Secondary source, single claim. Treat as a signal about maintainability of heavy multi-agent harnesses, not as proof. https://www.ai.engineer/orgs/gas-town
- Karpathy: nothing found after July 2026; earlier statements (agents dependable since Dec 2025, still bloat code and skip clarifying questions) are not new. https://the-decoder.com/former-tesla-ai-chief-andrej-karpathy-now-codes-mostly-in-english-just-three-months-after-calling-ai-agents-useless/
- Usage limits: secondary blogs report weekly limits +25% on 2026-09-14 after a summer 50% boost, a net cut for some. UNVERIFIED; check `/usage`. https://pasqualepillitteri.it/en/news/13403/claude-code-weekly-limits-25-percent-17-cut
- Matt Pocock: covered in the 2026-10-13 study; nothing newer retrieved.

Papers and benchmarks:
- AsynCodeBench (2026-09-26): 19 tasks, 52 dependencies; coding skill does not predict collaboration skill. Abstract does not compare to single agent. https://arxiv.org/abs/2609.32662
- The Illusion of Multi-Agent Advantage (2026-06-11/13): automatically generated MAS lose to CoT-SC at up to 10x cost on reasoning tasks; hand-designed MAS win when task structure supports decomposition. Not coding-specific. https://arxiv.org/abs/2606.13003
- Single-agent baselines: "Rethinking the Value of Multi-Agent Workflow" (arXiv 2601.12307) and the README-generation study (2606.30524: single agent -86% tokens, 2x speed, comparable quality). Abstract-level only. https://arxiv.org/html/2601.12307v1
- Agent-framework evaluation: multi-agent better on completeness, single agent better on executability (2511.00872, pre-window background). https://arxiv.org/pdf/2511.00872
- Skills: SkillsBench (curated skills +16.2pp average, +4.5pp in software engineering, 16 tasks degraded, self-written skills negligible; 2602.12670) and "Signal or Noise" web-dev study (31 public skills reduced Pass@2 by 1.3 to 4.2%, token cost +72% to +394%; 2608.23067). Abstract-level only. https://arxiv.org/html/2602.12670v1 and https://arxiv.org/pdf/2608.23067
- "Engineering Reliable Coding Agents" (2608.13867): PDF unreadable via fetch; title only. https://arxiv.org/pdf/2608.13867

## 2. Borg component to replacement candidate

Confidence is that the replacement can cover the job at equal or better quality for Noah's workflow (20 repos, tmux, ADHD guardrails). Numbers are my judgment, not measured.

- Queen orchestrator session (CWD-defined, never edits repos)
  - Candidate: native Projects (https://code.claude.com/docs/en/claude-projects) plus agent view as the status surface.
  - Confidence it replaces: 20%. Projects is cloud-first, Pro/Max only, rolling out; it does not enforce briefing, priority scoring or work/life boundaries. Agent view gives the "needs input / ready for review" board but not ordering.
  - Keep: briefing synthesis, boundaries, CWD identity rule. Replace: any hand-built "list what is running" code with `claude agents --json`.
  - Experiment: E3 (agent view as the Queen's roster).
- Drone sessions per repo in tmux
  - Candidate: `claude --bg` plus `claude agents` (dispatch with `@<repo>`), `--worktree --tmux`, community tmux plugin that reads `claude agents --json` (tmux-claude-session-manager, vendor-unverified).
  - Confidence: 35% for session launch and worktree/lifecycle; 10% for container up/down and the 3-pane layout, which have no native equivalent. Background sessions are local and survive sleep, not shutdown. Drone-in-devcontainer cannot message host sessions (docs: container and host sessions cannot reach each other).
  - Experiment: E3, E5.
- Nanoprobe subagents with their own worktrees
  - Candidate: native `isolation: worktree` frontmatter, background-by-default subagents, `/batch` (5 to 30 worktree subagents) with a `WorktreeCreate` hook so it works outside a git repo (2.1.281), `worktree.baseRef`, `.worktreeinclude`, periodic sweep (`cleanupPeriodDays`).
  - Confidence: 55% for worktree lifecycle and cleanup (`borg reap-worktrees` overlaps the native sweep); 25% for the PR-opening, 5-read-before-write nanoprobe protocol, which is prompt discipline, not mechanics. Note native subagent worktrees do not load the worktree's own CLAUDE.md; they take instructions from the main conversation (docs), which matters for per-repo rules.
  - Experiment: E1.
- Session registry (registry.json)
  - Candidate: `claude agents --json`, `/list-agents`, session names via `--name`/`/rename`, `~/.claude` transcripts, `claude project purge`.
  - Confidence: 40% for "what is running now"; 10% for the persistent repo-to-path-to-container map (registry holds repository facts, not session facts). Native view is machine-local and process-scoped.
  - Experiment: E3.
- Cross-session messaging (vinculum)
  - Candidate: native cross-session messaging (`SendMessage`, `ListAgents`, `notify_when_idle`), https://code.claude.com/docs/en/cross-session-messaging.
  - Confidence: 70% for host-to-host sessions on one machine. Gaps: text only, ~1M char cap, burst throttling, 50-message queue, held messages when both sides differ in permission class, host and container sessions cannot reach each other, `-p` and `--bare` sessions need `crossSessionInbound: accept` and non-bare mode. The prior decision "workers never message each other" is untouched; this is session-to-session.
  - Experiment: E2.
- Usage guardian
  - Candidate: status line `rate_limits.five_hour/seven_day.used_percentage` and `resets_at` plus `spend_limit` (https://code.claude.com/docs/en/statusline), `/usage`, retry watchdog env vars, Desktop-only auto-continue. No native hook fires on a usage threshold (none found in docs; UNVERIFIED absence).
  - Confidence: 25%. Native covers display and unattended retry caps, not proactive throttling, stopping dispatch, or ADHD-style speed bumps. The status-line JSON is a cleaner data source than whatever the guardian polls now; swapping the sensor but keeping the policy is the realistic win.
  - Experiment: E4.
- Dispatch guards (cap subagent model and effort)
  - Candidate: deny rule `Agent(model:opus)` (v2.1.178), `Agent(effort:...)` likely now that Agent has an `effort` parameter (UNVERIFIED), `maxEffortLevel`, `CLAUDE_CODE_SUBAGENT_MODEL` with `_FORCE=1` (v2.1.257), `PreModelSwitch` hook, `agent.spawn` mod hook that rewrites model, `availableModels` allowlist.
  - Confidence: 65% for model caps; 45% for effort caps (session-level `maxEffortLevel` is not subagent-specific). Allowlist-by-agentType and "deny untyped spawn" logic likely still needs a hook. Caveat: the sub-agents doc page did not mention `Agent(model:)` rules while the w25 digest did; verify on the installed version.
  - Experiment: E1b (guard parity).
- Resume after interruption
  - Candidate: `claude --resume`, `--continue`, worktree-aware resume, `claude respawn`, `/resume` picker including background sessions, many 2.1.281..292 resume fixes, retry watchdog for unattended.
  - Confidence: 60% for session-level resume (borg's own layer should shrink); 15% for cross-repo "pick up where the whole portfolio stopped". Known native holes: in-process agent-team teammates are not restored; cloud sessions after restart only list resumable background agents by id.
  - Experiment: E5.
- Checkpoints (`.borg/checkpoints/`, user-authored)
  - Candidate: auto-memory and `/memory`, session recap, `/rewind` with "summarize up to here", Cortex `conversations search`, claude-mem (prior research).
  - Confidence: 15%. Human-authored framing at session boundaries is a deliberate borg choice (prior research agreed). Native memory notes are model-authored and path-scoped. Idle compaction (54 minutes) reduces cost but not handoff value.
  - Experiment: none new; keep. If testing, E6 compares checkpoint injection against a plain CLAUDE.md note for cold-start accuracy.
- Recon (gather GitHub state, reconcile with checkpoints)
  - Candidate: agent view PR labels (`#N` colored by check state), routines with GitHub triggers (cloud, Pro/Max, 100 scheduled runs/hour), `gh` CLI, GitHub MCP connector.
  - Confidence: 10% as a replacement for contradiction logic; 50% that the raw gather layer could be a routine or `gh` call instead of custom fan-out. Routines are cloud and research preview.
  - Experiment: E7.
- `borg link` and `borg next`
  - Candidate: `claude agents` (state board), `/goal` for in-session completion conditions, Concise output style. Nothing native orders work across projects (prior 2026-10-13 study, agent view page).
  - Confidence: 10%. Keep. Use native JSON as input.
  - Experiment: E3 supplies the data feed.

## 3. Proposed experiments

All use a scratch repo created with `git init` under the scratchpad, a scratch settings file passed with `claude --settings <file>`, and no edits to /Users/noah/.claude/settings.json. Add `--setting-sources` as needed to isolate user settings (note the flag now propagates to spawned sessions, 2.1.282). Token costs are order-of-magnitude, subscription tokens, using Haiku or Sonnet for workers.

- E1: native fan-out outside a git repo (re-run of the 2026-07-30 spike)
  - Hypothesis: with a `WorktreeCreate` hook in the scratch settings, `/batch` and `isolation: worktree` subagents work when the launch CWD is a non-git parent holding several scratch repos, so nanoprobe worktree code is redundant for creation and cleanup.
  - Setup: scratch parent dir with two `git init` repos, settings file with a `WorktreeCreate`/`WorktreeRemove` hook writing worktrees under a scratch state dir; run `claude --settings s.json -p "use /batch to add a header comment to every .py file"` from the parent.
  - Success: worktrees created and removed by hook, each subagent commits on its own branch, no write to the parent, sweep leaves none after `cleanupPeriodDays`; failure: error "requires git repository".
  - Cost: ~150k to 400k tokens (Haiku workers). Headless.
- E1b: dispatch-guard parity
  - Hypothesis: settings rules `Agent(model:opus)`, `Agent(effort:xhigh)` plus `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` reproduce borg's guard decisions for the cases in docs/agent-routing.md.
  - Setup: scratch settings with the deny rules and `maxEffortLevel`; a table of ~12 spawn prompts (typed, untyped, opus, xhigh, workflow `agent()`); compare allow/deny against the existing hook's decisions using `--output-format stream-json`.
  - Success: >= 11/12 identical; every divergence classified (rule gap vs hook over-strictness). Untyped-spawn denial is the likely gap.
  - Cost: ~100k tokens (Haiku). Headless.
- E2: native messaging replacing vinculum
  - Hypothesis: two host sessions in two scratch repos can hand off a finding with `SendMessage` and a `notify_when_idle` notice, matching vinculum's latency and reliability with no custom transport.
  - Setup: two tmux panes, each `claude --name a|b --settings s.json` with `crossSessionInbound: accept` for the receiver; also one `claude -p` long-running worker with `accept`; send 20 messages, 5 bursts, one oversize.
  - Success: >= 19/20 delivered and acted on, burst refusal observed and recoverable, idle notice arrives; cross-container case documented as non-working.
  - Cost: ~200k tokens. Needs the TUI for interactive panes; the `-p` variant is headless.
- E3: agent view as roster, registry and link feed
  - Hypothesis: `claude agents --json` provides enough fields (name, state, cwd, PR) to replace the "what is running" half of registry.json and to feed `borg link`.
  - Setup: dispatch 4 `claude --bg` sessions across 2 scratch repos (one needing input, one done, one with a PR stub); diff the JSON against registry fields; test `attach`, `logs`, `respawn`, kill the daemon mid-run.
  - Success: all four states correctly classified; missing-field list is under 3 items; survives daemon restart.
  - Cost: ~150k tokens. Mostly headless, one TUI pass to check agent view is usable for the Queen.
- E4: usage guardian sensor swap
  - Hypothesis: a status-line script writing `rate_limits` to a file gives the guardian equal or better threshold data than its current source, and `CLAUDE_CODE_RETRY_WATCHDOG_MAX_USAGE_LIMIT_WAIT_MS` bounds unattended waits.
  - Setup: scratch settings with `statusLine` command that appends JSON to a scratch file; run 3 short sessions; compare `used_percentage` to `/usage`; for the watchdog, run `claude -p` with the env var set low (needs a real or simulated limit, so this half is UNVERIFIABLE without hitting a limit; skip).
  - Success: reading within 2 points of `/usage` in all samples, updated at least once per turn.
  - Cost: ~30k tokens. Needs the TUI (status line renders there; `-p` may not call it, UNVERIFIED).
- E5: resume parity
  - Hypothesis: native resume, `respawn` and worktree re-entry recover 9 of 10 interruption cases (kill -9 mid-edit, mid-tool-call, mid-parallel-batch, worktree deleted, machine sleep) that borg's resume logic handles.
  - Setup: scripted scratch sessions killed at defined points, then `claude --resume`/`--continue` with the same settings file.
  - Success: >= 9/10 with correct state and no duplicate edits; record where borg logic still adds value.
  - Cost: ~250k tokens. Headless for `-p` cases; TUI for two interactive cases.
- E6: evals for borg skills with `claude plugin eval`
  - Hypothesis: a 7-case suite for one borg skill shows a measurable positive delta versus no-plugin baseline; if the delta is zero or negative, the skill is dead weight.
  - Setup: copy the skill to a scratch plugin dir, `claude plugin eval init`, then `claude plugin eval .`; run 3 times to see variance.
  - Success: mean delta >= +10 points with the 3-run spread smaller than the delta. Cost: each run is a real model call plus judge calls; ~300k to 600k tokens per skill. Headless. Also run `/skill-doctor` to rank skills by context cost (cheap, TUI).
- E7: recon gather layer as `gh` plus one routine
  - Hypothesis: the GitHub-state gather step can be a single cached `gh` query (or a nightly routine) without a custom fan-out; the contradiction logic stays.
  - Setup: scratch repo on a throwaway GitHub repo with 3 PRs; compare recon's output to a `gh pr list --json` baseline.
  - Success: identical item set, lower wall time or tokens. Cost: ~50k tokens. Headless. Note routines need a claude.ai login and GitHub app install, which touches an account; run only on a throwaway repo.
- E8: single agent versus multi-agent on a borg-shaped task (the missing evidence)
  - Hypothesis: for the decomposable tasks borg fans out (independent per-repo changes), nanoprobe fan-out beats one session on wall time without losing correctness; for tasks with shared files it loses.
  - Setup: two scratch repos of 6 independent and 6 coupled tickets; run single session vs `/batch` vs nanoprobe fan-out; hold model and effort constant.
  - Success: report wall time, tokens, test pass rate; fan-out should win only on the independent set. Cost: ~1M to 2M tokens. Headless, run in the background.

## Evidence gaps and uncertainties

- Weeks 38 to 42 digests and part of the changelog for 2026-09-14 to 2026-09-22 were not read; features there are missing.
- No Anthropic engineering post after May 2026 was found; one undated featured post was not read.
- The changelog and docs fetches pass through a summarizing model; the Agent(model:) rule appeared in the digest but not in the sub-agents page summary. Verify on the installed version before relying on it.
- Papers were read at abstract level except AsynCodeBench and the Illusion paper abstracts; no coding-specific, head-to-head multi-agent study with Claude Code was found. The skills studies disagree (curated helps, public skills often hurt).
- Practitioner coverage after July is thin (Willison yes; Karpathy, Yegge, Pocock effectively no new primary material). Yegge's Gas Town failure is a single secondary statement.
- The absence of a native usage-threshold hook is inferred from docs not mentioning one.
- Cortex Code: the visible changelog window shows no worktree, hook or messaging features; unknown whether newer builds exist past 1.1.87.

## Paywalled must-reads

None identified; all sources were openly retrievable.

## Sources index

- Claude Code changelog, 2026-10-16 (tier 2024-2026): https://code.claude.com/docs/en/changelog
- Claude Code weekly digests w32 to w37, 2026-08 to 09: https://code.claude.com/docs/en/whats-new
- Cross-session messaging doc, 2026: https://code.claude.com/docs/en/cross-session-messaging
- Agent view doc, 2026: https://code.claude.com/docs/en/agent-view
- Worktrees doc, 2026: https://code.claude.com/docs/en/worktrees
- Subagents doc, 2026: https://code.claude.com/docs/en/sub-agents
- Agent teams doc, 2026: https://code.claude.com/docs/en/agent-teams
- Run agents in parallel doc, 2026: https://code.claude.com/docs/en/agents
- Projects doc, 2026: https://code.claude.com/docs/en/claude-projects
- Routines doc, 2026: https://code.claude.com/docs/en/routines
- Plugin evals doc, 2026: https://code.claude.com/docs/en/plugin-evals
- Status line doc, 2026: https://code.claude.com/docs/en/statusline
- Cortex Code changelog, 2026-09-14: https://docs.snowflake.com/user-guide/cortex-code/changelog
- Anthropic engineering index, 2026-05-25 latest: https://www.anthropic.com/engineering
- Simon Willison claude-code tag, 2026-10-16: https://simonwillison.net/tags/claude-code/
- ai.engineer Gas Town profile, 2026-08: https://www.ai.engineer/orgs/gas-town
- AsynCodeBench, 2026-09-26: https://arxiv.org/abs/2609.32662
- Illusion of Multi-Agent Advantage, 2026-06: https://arxiv.org/abs/2606.13003
- Rethinking Multi-Agent Workflow, 2026-01: https://arxiv.org/html/2601.12307v1
- SkillsBench, 2026-02: https://arxiv.org/html/2602.12670v1
- Signal or Noise skills study, 2026-08: https://arxiv.org/pdf/2608.23067
- Usage limit commentary (secondary, unverified), 2026-09: https://pasqualepillitteri.it/en/news/13403/claude-code-weekly-limits-25-percent-17-cut
- tmux plus agents-json community plugin (vendor/secondary), 2026: https://www.sourcepulse.org/projects/33026218
