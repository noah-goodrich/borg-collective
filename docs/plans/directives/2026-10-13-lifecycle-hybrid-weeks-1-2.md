# Directive: lifecycle hybrid, weeks 1 and 2

*Filed: 2026-10-13 · Revised after blind review round 1 · Status: Proposed (strategy decided by Noah 2026-10-13; slice defaults await his OK; not yet design-reviewed)*

Public-repo note: this file is public. Sensitive specifics (the highest-risk item, private repo PR numbers, anything about tenancy or security posture) are deliberately kept out and live in the private triage sheet and the private repos' own PRs. Check visibility with `gh repo view --json visibility` before adding any such detail.

## tl;dr

- A lifecycle research pass (2026-10-13) compared three strategies for plan, implement, test, review, deploy and monitor: adopt a platform (Beads, Gas City, Superpowers), compose borg with FOSS per stage, or focus borg and delete. Noah chose a HYBRID: borg stays the spine, plus a short list of cheap, stateless adoptions. Every state-store addition (Beads, Backlog.md, Gas City) is deferred behind a spike with a kill gate. Obsidian is a no. Every adoption is paired with a deletion PR. Experiments ran first (E1 to E4); this directive is the two-week plan built on their results.
- The measured problem is not missing tooling, it is where the effort goes. In the 60 days to 2026-10-13, 79% of 321 merged PRs were infra (borg-collective, claude-plugins, dotfiles). Only 13.7% had an independent verdict before merge, all of it in borg-collective and all in the last two days; product repos got 0%. The waiting queue is two-thirds product with a median age of about 105 days, and it contains the highest-risk open product item, a long-open fix tracked in a private channel (details deliberately kept out of this public file).
- So two product slices come first and are not infra: P0a, the single highest-risk open item (due day 2, with an escalation path), and P0b, a sweep of the other stale product PRs. Everything else is subordinate to them and to a new infra budget rule (product feature or fix PRs at least 40% of merged feature, fix and deletion PRs over the two weeks, measured with a stated command).
- The stateless adoptions, in value-per-effort order: verify-by-default on every dispatched PR including product repos (S1); a test-first prompt cherry-picked into nanoprobe briefs (S2); production probes (S3) and a free-tier error tracker (S4); a path-gated CI reviewer pilot on one stillpoint-labs repo with a kill criterion (S5); deployment rolled into `/borg-assimilate` as a step that calls a shared reusable workflow extracted from reveal's and adopted by one more repo, with no separate deploy command or skill (S6); a one-week trial of native Claude Code agent features as plumbing under borg's visibility layer, which it must improve and which is never a deletion target; the trial gates deleting only transport pieces (the orchestrator-to-drone path of vinculum delivery, tmux send-keys broadcast, home-grown liveness polling) (S7).
- The deletions slices (S8 inventory, S9 deletions) are the guard against borg's add-without-remove habit: an adoption is not done until its deletion PR is open, and only items an inventory proves unused are deleted.
- Reliability and friction: a small flake-fix slice (F1) so the verifier and the gates are trustworthy, and a friction-not-addressed section with revisit triggers.
- Housekeeping: correct the stale "96% main loop" cost claim in the token-cost skill to the measured share (H1), clear stale blocked background sessions (H2), close or run the Obsidian lens (H3).
- Reconciliation with PR #262 (PM capabilities, build/adopt/outsource): agree on its "no external state store" stance, DEFER its build phases (they are infra and sit behind the budget), supersede nothing. See the dedicated section.

## Ground truth this plan stands on

Experiment results, all from 2026-10-13. Raw notes are kept outside the repo; the figures below are the load-bearing ones.

- E1, native agents. In a running drone, native `ListAgents`, `claude agents --json` and `SendMessage` all saw and reached the session. The drone's claude process runs on the host (only the services run in containers), so no container boundary was in the way. Registration lag after start was about 2 to 3 minutes. A `notify_when_idle` subscription was accepted and fired with a one-line summary. Caveats: one drone, one ping; a message to a session in a different permission mode is held for that session's user; four stale "blocked" background sessions from earlier months still show in `claude agents`.
- E2, coverage. Merged PRs since 2026-08-14: 321, of which infra 254 (79%) and product 67 (21%). Independent verdict before merge: 44 of 321 (13.7%); borg-collective 43 of 214 (20%), all of it on 2026-10-12 and 2026-10-13; zero of the 142 earlier borg-collective merges; zero on ingle, stillpoint, the sites, reveal and dotfiles. Of a 23-PR triage sheet from 2026-10-08, 8 were infra and 15 product (median age 4 days versus 105). By 2026-10-13, 10 of the 23 had merged without a verifier run, 3 were closed, and 10 remain open: 3 infra and 7 product aged 70 to 136 days.
- E3, cold CI reviewer replay on 15 past PRs (75 findings). Strict precision 11%, lenient precision 43%, blocker/major-only lenient 76%, recall 78% on known defects, about 5 comments per PR to adjudicate, about five cents per PR on Sonnet. It never said "no issues" on clean PRs. It caught diff-detectable classes (an in-place edit of an applied migration, a search_path mistake, a hook firing too often) and missed environment-assumption bugs. Conclusion: useful only if path-gated (DB migrations, hook code), blocker/major only, capped, with an explicit "no findings" output; otherwise it adds to the human queue.
- E4, synthetic production probe. A Gatus config (health with build sha, sign-in page renders, auth-callback landing origin, MCP version and build sha) ran in about 30 minutes, all green on production, and both replays (wrong redirect origin, version skew) failed as intended. Gaps: this Gatus build has no header condition, so the redirect check is indirect; and the actual 2026-08-17 login break was a browser-side PKCE magic-link bug (the verifier cookie unreadable by the edge callback), not the auth URL configuration that earlier notes blamed. A credential-free GET cannot catch that class; it needs a POST and an inbox.
- Cost shape (90 days): main loop about 68% of spend and subagents about 32%, not the 96/4 the token-cost skill states. Cost history before 2026-09-08 was computed by a buggy estimator and is suitable for relative shape only.
- Native GitHub merge queue is unavailable for personal repos and likely for private Team-plan org repos, so it is not an option. The org self-hosted runner serves stillpoint-labs repos only, not noah-goodrich repos where most borg PRs live.
- Gas City needs a young stack (tmux, git, jq, dolt, bd) with no devcontainer model; Beads is a per-repo store with unproven cross-repo support. Both stay deferred.

## Decisions (defaults stated so you can override in a word)

- D1 Strategy: hybrid with borg as the spine. Decided 2026-10-13.
- D2 Obsidian: no. Decided. The open 30-minute lens is offered as close-or-run; default CLOSE (H3).
- D3 State stores (Beads, Backlog.md, Gas City): deferred behind spikes, none in these two weeks.
- D4 Infra budget: of merged feature and fix PRs across the 14 days starting 2026-10-14, at least 40% are in product repos; deletion PRs are excluded from both sides (they are what we want more of); S3 to S6 PRs landing in product repos are infra adoption work and are excluded from the product side; net surface count (skills, agents, hooks, launchd jobs, bin scripts, tests and fixtures excluded) not higher on day 14 than day 0. Feasibility is precomputed in the budget section. Default on; the numbers are overridable.
- D5 Probe host (S3). Options: (a) a scheduled GitHub Actions job on the org self-hosted runner running curl and jq checks; (b) a Gatus container; (c) a tiny Fly app. Default (a): no new service for the checks, config lives in git, and curl can check a Location header, which the Gatus build tested in E4 cannot. Gatus was validated in E4; curl and jq are not, so S3 replaces that validation with fixture tests including a dead-endpoint case. The weakness is that the runner is one machine and GitHub's cron is best-effort, so a dead runner skips probes silently and a skipped run is not a red run. Mitigation: the dead-man's switch lives OFF the runner (a free external heartbeat monitor that the probe pings on every success and that alerts when pings stop), and alerts go to an explicit channel (a phone push topic plus email), not GitHub failure emails. Revisit trigger for (c): a missed incident traced to a skipped run, or a need for status history.
- D6 Error tracker (S4). Options: Sentry hosted free tier (FSL license, not OSI) versus GlitchTip self-hosted (MIT). Default Sentry free tier: zero hosting, an official MCP, and the fewest moving parts. Go GlitchTip only if strictly OSI-FOSS is required, accepting a server plus database and a thin MCP. Honest limit: neither would have caught the 2026-08-17 break, which rendered a blank form without throwing.
- D7 PKCE magic-link gap: do not build a synthetic login now. Default: rely on the regression test that shipped with the fix, and record the gap in the probe README. Revisit trigger: a second auth-path production incident, or a test mailbox that costs nothing to run.
- D8 CI reviewer pilot repo (S5): default ingle (private stillpoint-labs), the repo whose migration PRs produced the E3 catches. Needs a model API key stored as an org or repo secret, which is Noah's to add.
- D9 Shared deploy workflow home (S6): default keep it in reveal's repo and call it cross-repo at a pinned SHA (requires the Actions access setting on that repo), rather than create a new repo. Move it only when a third consumer appears. Second consumer: default ingle, confirmed by diffing its deploy workflow against the reusable inputs in S6 step 1.
- D10 Native agents trial scope (S7): one week, orchestrator-to-drone traffic only, vinculum left running as the fallback throughout. Borg's visibility layer (`borg link`, `borg next`, stacks and manifest chains, the WAITING ON YOU block, checkpoints and the viz updates) exists to manage the chaos and keep Noah knowing what is next; it is OUT of scope for deletion and is what the trial must improve. Native features (`claude agents --json`, `ListAgents`, `SendMessage`, `notify_when_idle`, `claude --bg`) are evaluated only as plumbing that feeds that layer: liveness for `borg link`, idle signals, message transport. Because the trial exercises only the orchestrator-to-drone path, a pass can delete ONLY transport pieces on that path (vinculum delivery, tmux send-keys broadcast, home-grown liveness polling); drone-to-orchestrator and cross-session pubsub (N subscribers) stay on vinculum until a separate trial covers them. The trial starts by day 2 so the verdict lands by day 9.
- D11 PR #262: default merge #252 and then #262 as the research record, build nothing from it in these two weeks (see the reconciliation section). Order matters because #262 is stacked on #252: retarget #262 to main FIRST (`gh pr edit 262 --repo noah-goodrich/borg-collective --base main`), then merge #252; if #252 is squashed, rebase #262 with `--onto` as its body describes. Merging #252 first with the stack intact can auto-close #262.
- D12 Product queue (P0a, P0b): the highest-risk item is prepared read-only and presented to Noah by day 2; nothing touches production without Noah. If the read-only check shows live exposure, the escalation is a same-day manual mitigation that Noah authorizes explicitly (P0a). Deferral is allowed only as an explicit, dated, written risk acceptance by Noah with a re-check date. Other aged product PRs get a keep, close or merge recommendation each (P0b); Noah applies them.
- D13 Superpowers: cherry-pick prompts only, by copy, with the source commit noted; never install the plugin (auto-trigger token cost, drift accepted and bounded by a note).

## Slices

Effort is S (under half a day), M (about a day), L (2 to 3 days). Week 1 is days 1 to 7 from 2026-10-14; week 2 is days 8 to 14. Every slice lists at most two deliverables (tests and preconditions are not deliverables).

| Slice | Title | Repo | Effort | Week |
|-------|-------|------|--------|------|
| P0a | Highest-risk product item | stillpoint-labs | M | 1 (due day 2) |
| P0b | Stale product PR sweep | stillpoint-labs | M | 1 |
| F1 | Flake fixes behind the gates | borg-collective | S | 1 |
| S1 | Verify by default | borg-collective | S | 1 |
| S2 | Test-first prompt | borg-collective | S | 1 |
| S3 | Production probes | stillpoint-labs | M | 1 |
| S7 | Native agents trial | borg-collective | M | 1-2 |
| S8 | Fire inventory | borg-collective | M | 1 |
| H1 | Fix 96/4 claim | claude-plugins | S | 1 |
| H2 | Clear stale sessions | local | S | 1 |
| H3 | Obsidian close-or-run | borg-collective | S | 1 |
| S4 | Error tracker | stillpoint-labs | M | 2 |
| S5 | CI reviewer pilot | stillpoint-labs | M | 2 |
| S6 | Deploy as an assimilate step | stillpoint-labs | L | 2 |
| S9 | Deletions | borg-collective | L | 2 |

Dependencies: P0a first, due day 2, ahead of everything. S1 after F1 (the verifier needs trustworthy gates). S2 after S1 (same file). S4 after S3 and D6. S9 after S8; the transport deletions (orchestrator-to-drone path only) also wait for the S7 verdict, which must land by day 9; each adoption slice's deletion PR is listed in its own deliverables and is tracked by S9. S5 and S6 are independent of each other.

### P0a Highest-risk product item (due day 2; highest value in this directive)

Why first: this is the only slice that removes live production risk, and it is exactly the work the infra share is crowding out. It is its own slice with its own deadline so it cannot be absorbed into a sweep. The item is a long-open fix in a stillpoint-labs repo, identified in the private triage sheet; this public file intentionally says no more.

- Deliverable 1: verify the current production state READ-ONLY with the read-only path already used for inspections, and record the result (what was checked, when, observed state) in the private repo's own PR comment, never in a public artifact. Do not run any write against production.
- Deliverable 2: bring the fix to merge-ready: rebase onto current main, check the migration for idempotence against the live shape, run the migration lane and the repo's verification command (re-run a red lane once and record flake versus real failure; F1 does not cover product lanes), obtain an independent verdict on the diff, and present to Noah with the exact apply path (the human-gated dispatch workflow) and a one-line risk statement. Merge and apply are Noah's actions.
- Escalation path: if the read-only check confirms the exposure exists now, the orchestrator tells Noah the same day and proposes the minimal manual mitigation (enable the missing protection on the affected tables by hand, with an asserted before and after state and a rollback statement). The orchestrator never runs it; Noah authorizes and applies it, or applies the normal fix path sooner. The rest of the plan does not start slices that need Noah's attention until this is answered.
- Tests: no code. Verification is evidence in the private PR comments: the dated state check, a green migration lane, and a verifier verdict link.
- Done when (by day 2): merged and applied by Noah, OR mitigated by Noah, OR Noah has recorded a written, dated risk acceptance naming a re-check date no more than 7 days out. A bare "defer" does not close the slice.

### P0b Stale product PR sweep

- Scope: stillpoint-labs repos only. Stale PRs in noah-goodrich repos are triaged separately and do not count toward Rule 1.
- Deliverable 1: a keep, close or merge recommendation for every product PR open longer than 30 days, one PR comment each, written so Noah can act in one word. The seed list is in the private triage sheet. Newer PRs are out of scope unless they block P0a. Recommendations are comments, not repo files.
- Deliverable 2: the before and after list of product PRs open over 60 days, recorded in the closing checkpoint (AC2).
- Tests: no code. Verification is a comment per aged PR.
- Done when: every aged product PR has a recommendation comment and the count older than 60 days has dropped. This slice is lower priority than every P0a step and can slip to week 2 without failing the directive.

### F1 Flake fixes behind the gates

Evidence: friction scan, flaky or untrusted tests mentioned in 14 of 101 checkpoints; the two named offenders are a timing test in the process tests and the numpy-alias case in the CLI contract tests, which fail under full-suite load.

- Deliverable 1: fix those two offenders at the cause (a deterministic fake or a load-insensitive assertion, not a retry or a longer sleep), each starting with a failing repro under load.
- Deliverable 2: run the full suite three times back to back under load and record the result in the PR.
- Done when: both pass in all three runs. Other flakes are listed in the friction section with a revisit trigger.

### S1 Verify by default

Evidence: E2 (13.7% overall, 0% on product repos, all verdicts in the last two days).

- Deliverable 1: change the tail of the nanoprobe brief so every dispatched PR ends with the independent verifier step, product repos included, with an explicit opt-out token for docs-only or trivial PRs. The tail lives with the nanoprobe contract in `agents/borg-nanoprobe.md` (its completion section) and the dispatch guidance in `docs/agent-routing.md`; the slice first locates every place the orchestrator's brief template is composed and edits the one source, so the tail is not duplicated.
- Deliverable 2: record the verdict on the PR as a comment, so coverage is countable later with the E2 method (a PR with a verifier comment counts).
- Tests: extend the prose-contract bats (`tests/prose_contracts.bats`) to assert the brief tail names the verifier step and the opt-out; a stubbed-dispatch test asserting a brief generated for a product repo path includes the tail.
- Precondition: every existing verdict was produced in borg-collective, so before relying on the tail, run one test verifier pass against one real product-repo PR and record whether it works there (checkout, test command discovery); if it does not, fix that first or scope the tail to repos where it works and say so.
- Stamp protocol: this slice does not change the cross-machine stamp protocol. A verifier comment is invisible to `reviewDecision` (issue #278), so the verdict comment starts with a stable marker line a later fix can read; #278 itself stays in the friction section.
- Done when: a nanoprobe-opened PR on a product repo shows a verifier comment before the orchestrator reports it ready; deletion PR named: none needed (this removes a convention, adds none).

### S2 Test-first prompt

- Deliverable 1: first check the superpowers TDD prompt against the existing test-first rule: the rule today is Noah's standing feedback (new work starts with tests as executable acceptance criteria; every bug fix starts with a failing repro test, then fix, then green) and the verify-before-completion step. Record, in the PR body, which sentences of the superpowers prompt add something the rule lacks (for example "watch it fail for the right reason" and "do not keep the code you wrote before the test") and which are redundant.
- Deliverable 2: copy only the non-redundant lines (a few sentences, source version and license noted in a comment) into the nanoprobe brief. No plugin install.
- Tests: prose-contract assertion that the brief contains the failing-test-first sentence; no behavioral test is claimed, since prompt effect is not unit-testable.
- Done when: the rule appears once in the brief, in one wording; if the check finds nothing non-redundant, the slice closes with that finding and no change (a valid outcome).

### S3 Production probes

Evidence: E4. Default per D5: a scheduled workflow on the self-hosted runner in one product repo first.

- Deliverable 1: a probe script (curl and jq, one function per check) and a scheduled workflow (every 10 minutes is plenty) with these checks: health endpoint returns ok and a build sha; the sign-in page renders its expected title; the auth callback does not redirect to a different origin (read the Location header directly); the MCP health endpoint returns the expected version and build sha. The expected sha comes from the latest successful deploy run of the same repo (via the API), not a hardcoded value, which removes the bump-per-deploy flaw found in E4.
- Deliverable 2: a dead-man's switch that does not depend on the runner: the probe pings an external free-tier heartbeat monitor on every success and the monitor alerts when pings stop for 35 minutes (the grace covers GitHub's best-effort cron), plus an explicit notification channel for both probe failures and missed heartbeats (a phone push topic and email; GitHub failure emails are not the channel), plus a README of what the probe cannot see (the PKCE class, D7).
- Tests: the two E4 replays become fixtures against a local stub server: a callback that redirects to a foreign origin must fail; a health endpoint serving a different sha than the last deploy must fail; a healthy stub must pass; a stub that is down must fail. A dry run of the workflow on the real endpoints must be green. Dead-runner acceptance test: stop or disable the runner for more than 35 minutes and confirm an alert arrives on the notification channel; a silent skip that produces no signal fails the slice.
- Done when: the probe has run green for 24 hours, a deliberately broken replay turns the job red and alerts, and the dead-runner test has produced its signal. Deletion PR named: none (monitor stage was empty).

### S4 Error tracker

- Deliverable 1: per D6, create the hosted free-tier project and wire the SDK into one product repo (server and browser), with the DSN as a secret; confirm a test event arrives.
- Deliverable 2: connect the tracker's MCP to the orchestrator and document the one-paragraph "how an agent reads recent errors" in the repo's operations notes.
- Tests: a throwaway event in a preview environment; a check that the DSN is absent from the repo and from build logs.
- Done when: one real or synthetic error is visible through the MCP. Stop gate: if setup exceeds one day, stop and record why (the point is the fewest moving parts). Deletion PR named: none.

### S5 Path-gated CI reviewer pilot

Evidence: E3. Exactly as E3 recommends, on one stillpoint-labs repo (D8).

- Precondition (pick the pilot repo on data): E3's hook catch was in a borg-collective PR, which the org runner cannot serve, so it is unverified that the default pilot repo has a hook path or comparable PRs. Before choosing, confirm the candidate's hook paths exist and count its path-matching PRs over the last 60 days; if the rate cannot plausibly reach 10 in 4 weeks, say so in the PR body and rely on the single extension below. If the default has no hook path, the gate is migrations only. It does not cover noah-goodrich repos, because the org runner cannot serve them; that is accepted, since the pilot targets the product repos where E2 shows zero review.

- Deliverable 1: a workflow using the claude-code-action (MIT), pinned by full commit SHA (not a floating tag), model Sonnet, triggered only for same-repo PRs touching the DB migration paths and the hook paths. Prompt rules: report only blocker or major findings; at most 3 comments; when there is nothing to report, post a single explicit "no findings" comment; never post style or test-quality remarks. Permissions: read contents, write pull-request comments, nothing else; no secrets other than the model key; fork PRs excluded (untrusted diff content on a self-hosted runner is the main security risk).
- Deliverable 2: a one-line outcome log convention: Noah (or the orchestrator) marks each posted comment useful, noise or acted-on with a reaction, and a small query counts them.
- Tests: re-run the workflow's prompt offline on the E3 PRs that match the path gate and confirm the cap and the no-findings output hold; a fork-PR and a docs-only-PR simulation must not trigger it.
- Kill criterion (decided before the pilot starts, applied after 10 path-matching PRs or 4 weeks, whichever comes first): remove the workflow if fewer than half of posted comments were useful or acted-on ("useful" is the LENIENT standard applied to blocker and major comments only, as in E3's 76%; E3's strict precision was 11%, accepted because the severity filter and cap are what keep the cost bounded), or if any PR drew more than 3 comments, or if it produced zero true catches across the window. If fewer than 10 path-matching PRs occur in 4 weeks, extend once by 4 weeks, then decide on what exists. Removal is a one-file deletion PR prepared in advance.
- Done when: the workflow is live on the pilot repo with the kill date written in the PR body. Deletion PR named: none for stillpoint-labs; the human review time it is meant to save is measured in the acceptance criteria.

### S6 Deploy as a step of /borg-assimilate

Evidence: audit (reveal's reusable pipeline is the only real one: ordered jobs, Fly bluegreen with health gate and rollback, Cloudflare Pages deploy). Noah's direction (2026-10-13): `/borg-assimilate` was always meant to be the deploy command, so all deploy behavior rolls into it. There is no `/borg-deploy` skill and none is created; no separate deploy command is added.

- Deliverable 1: make reveal's reusable deploy workflow callable from another repo (parameterize app names, health URL, build sha check; document inputs in the file header), consumed at a pinned SHA (D9).
- Deliverable 2: add a deploy step to `skills/borg-assimilate/SKILL.md`, after the merge in its shipping step: assimilate calls the shared reusable workflow, waits on its health gate, runs the post-deploy probes from S3 (health with build sha, sign-in page, auth-callback origin, MCP version), and reports the outcome; a failed gate leaves the workflow's automatic rollback in effect and assimilate reports it as a blocker. Repos with no deploy workflow skip the step silently.
- Deliverable 3: adopt it in one more repo (default ingle) in a PR that DELETES that repo's inlined copy of the same steps; the PR is the deletion PR for this slice.
- Tests: actionlint on both workflows; a bats test that the assimilate skill's deploy step names the shared workflow, the health-gate wait, the S3 probes and the report; a preview or dry-run deploy of the second repo run through assimilate; a forced health-gate failure proving the rollback path still runs; the second repo's post-deploy sha assertion still passes.
- Done when: both repos deploy through one definition, invoked from `/borg-assimilate`, and the second repo's workflow file is shorter. Review gate: S5 does not apply to these PRs unless the pilot repo is the second consumer.

### S7 Native agents trial (gates deletions)

Evidence: E1 (one drone, one ping; not yet a trial). Duration: 7 days from start. The start is by day 2 so the verdict lands by day 9, in time for S9. Scope per D10: orchestrator-to-drone traffic only.

Framing: borg's visibility layer (`borg link`, `borg next`, stacks and manifest chains, the WAITING ON YOU block, checkpoints, the viz updates) is out of scope for deletion and is the thing this trial must improve. Native features are evaluated only as plumbing feeding that layer (liveness for `borg link`, idle signals, message transport). The only deletion candidates are transport pieces: vinculum delivery, tmux send-keys broadcast and home-grown liveness polling.

- Deliverable 1: use native `claude agents --json`, `ListAgents`, `SendMessage` and `notify_when_idle` as plumbing under borg's visibility layer for all orchestrator-to-drone traffic that vinculum delivery or home-grown liveness polling would carry (feeding `borg link` liveness and idle signals), keeping vinculum running as the fallback. Log every event with a tiny helper that appends a TSV line (kind, drone, outcome, seconds, and a flag for scripted versus natural) to a file under the state root, also recording the Claude Code version; the helper is deleted at the end of the trial.
- Deliverable 2: a one-page verdict recorded in the PR that either deletes or keeps the transport pieces on the orchestrator-to-drone path (vinculum delivery, tmux send-keys broadcast, home-grown liveness polling). `borg link` and the rest of the visibility layer are kept either way; the verdict says so, as it does for drone-to-orchestrator and cross-session pubsub.
- Reaching the minimum samples in 7 days: natural traffic is counted first; any shortfall by day 5 is made up with scripted drills, flagged as such in the log, so the minimums do not depend on luck. Drills: cycle drones with `drone down` then `drone up` to reach the drone-start minimum (including one after a Docker restart and one after tmux window renumbering, both induced), and send scripted pings to idle drones for the SendMessage and idle-notification minimums. If a minimum is still unmet on day 8, the verdict is "insufficient data", which counts as a fail for deletion purposes.
- Pass criteria (all measured from the log): (1) registration lag at most 5 minutes in 90% of at least 10 drone starts (E1 observed 2 to 3 minutes, so a 3-minute bar sat on the edge of noise; the 5-minute bar is the point past which liveness is useless); (2) at least 95% of at least 20 `SendMessage` calls to idle drones delivered with a reply or acknowledgement inside 2 minutes; (3) `notify_when_idle` fires for at least 90% of at least 10 dispatched turns; (4) zero silent drops (a message that vanished without a held or failed signal); (5) messages held for a permission-mode mismatch are at most 10% and each is visible to the orchestrator (a held message the orchestrator cannot see is a silent drop under criterion 4); (6) vinculum used as a rescue at most once during the week; (7) `borg link` liveness is more accurate with native data than without it. The day-1 drill found `borg link` has no real liveness today, while `claude agents --json` and tmux agreed on all live sessions; the trial must show `borg link` fed from native data matches ground truth (tmux plus a manual check) on every live and every dead session sampled, with no false live and no false dead. Fail any one and the deletion is off; record which.
- Tests: the log helper has a bats test for append format; the criteria are computed by a short documented jq expression run at the end.
- Done when: the verdict exists by day 9. Pass leads to the transport-piece deletion PRs in S9 (orchestrator-to-drone path only), plus wiring native liveness into `borg link`; fail leads to a dated note and a retry trigger (the next Claude Code release that changes agent view or messaging). Native features are closed source and in preview, so a pass is reversible by design: the deletion PR is a revert away, and a change in the recorded Claude Code version reopens the question.

### S8 Fire inventory

- Deliverable 1: a re-runnable inventory script and its output committed as a dated asset under `docs/plans/assets/`: for each hook, skill, agent, launchd job, bin script and borg verb, the fire or use count over the available transcript and log window, the data source, and the window's start date. Sources: session transcripts (about 35 days survive), the nanoprobe log (rotated; read both the live file and the `.1` file, since reading only the live one undercounted by about fifty times in an earlier pass), spend ledger, launchd logs, and static references (grep). Missing data sources are reported as missing, never as zero.
- Deliverable 2: a keep or delete table, each deletion row naming its replacement or "none", its evidence, and its owner PR in S9.
- Tests: a bats test on fixture transcripts proving a known-used item counts nonzero and an absent log yields "no data" rather than 0.
- Done when: every deletion candidate in S9 has a row. Rule: delete only when the window covers at least 30 days of data, the count is zero, and static references are limited to the item's own tests and docs.

### S9 Deletions

Each adoption names its deletion PR. Candidates, each conditional on S8 (or S7 or #262 where stated):

- Directive-state deriver and the status vocabulary: delete the deriver and the competing status words only if S8 shows nothing consumes them AND #262 is not building on them (its Review-by and lapse logic reads directive state). If #262 proceeds, defer this row.
- Hard-wired pr-watch (single-repo launchd job and bin script): delete if nothing consumes its notifications; the PR control hub design (#97, never built) is closed as severed in the same PR.
- Cairn residue: the remaining references in the test flow matrix and docs.
- Per-repo deploy copies: delivered by S6 deliverable 3.
- Zero-fire hooks: whichever of the 17 hook scripts S8 proves unused, deleted together in ONE batched, revertable PR with one commit per hook, so any single hook can be reverted by cherry-picking its commit while the infra PR count stays low.
- Transport pieces on the orchestrator-to-drone path (vinculum delivery, tmux send-keys broadcast, home-grown liveness polling): only after S7 passes, and only that path; drone-to-orchestrator and cross-session pubsub stay. `borg link`, `borg next`, stacks and manifest chains, the WAITING ON YOU block, checkpoints and the viz updates are never deletion candidates.
- Dormant skills (`/borg-review`, repo-review): only if S8 shows zero use over a window of at least 30 days; otherwise keep.
- Tests: for each deleted item, remove its tests in the same PR, run the full suite, and assert the install and plugin-build checks still pass (no dangling references to a deleted hook in the hook registry or the plugin mirror).
- Done when: the deletion record (what was deleted, evidence row, PR number) is appended to the S8 asset, and the surface-count command shows no net growth. If any named deletion is blocked, its row says why and gets a revisit date; "listed but not done" is the named failure mode.

### H1 Fix the cost claim

- Deliverable 1: in the token-cost skill (claude-plugins repo), replace the "about 96% main loop, 4% subagents" passage with the measured split (main loop about two thirds, subagents about one third over 90 days to 2026-10-13), keep the guidance that the main loop is a large lever, and add the new lever (cap fan-out; fan-out sessions of 40 to 77 agents are the costliest single sessions), with the caveat that cost data before 2026-09-08 came from a buggy estimator.
- Deliverable 2: bump the plugin version as that repo's version check requires.
- Tests: that repo's version-bump check and plugin build pass; grep shows no remaining "96%" claim in the skill.
- Done when: merged. No dollar figures go in the skill or the PR.

### H2 Clear stale blocked sessions

- Deliverable 1: list background sessions with `claude agents --json`, identify the ones blocked for more than 30 days (four known from E1), confirm each is dead with Noah, and stop or clear them with the supported commands (`claude stop` and `claude rm` take a session id per `claude --help`; read their `--help` first, since this has not been run).
- Tests: `claude agents --json` shows no blocked session older than 30 days afterwards. Record the command and result in the slice's PR or checkpoint.
- Done when: the list is clean; this also removes noise from the S7 trial.

### H3 Obsidian close-or-run

- Deliverable 1: default CLOSE: mark the open lens item in the communication-program directive as closed (decided no, 2026-10-13, with the one-line reason: reads per session, not storage, is the constraint, and plans and checkpoints are already markdown). If Noah picks RUN instead: a 30-minute read-only lens over checkpoints and plans with a one-paragraph note of what it showed; a Neovim lens (zk or obsidian.nvim) is the CLI-first variant. No vault is created either way.
- Tests: grep confirms the directive no longer lists the lens as open.
- Done when: the item is closed or has a dated result.

## Infra budget rule (two weeks, 2026-10-14 to 2026-10-27)

- Rule 1: among merged feature and fix PRs (conventional-commit titles starting feat or fix) across all measured repos, product PRs are at least 40%. Deletion PRs (title scope `prune`) are excluded from both sides. S3 to S6 PRs landing in product repos carry the scope `lifecycle` and are excluded from the product side, because they are infra adoption work. Baseline from E2 was 21% on the raw PR count.
- Rule 2: net surface count is not higher on day 14 than day 0. Tests and fixtures are excluded from the count.
- Rule 3: no new borg skill, agent, hook, launchd job or verb is added in these two weeks except those named in a slice.
- Rule 4: an adoption slice is not done until its deletion PR (or the "none needed" statement) is open and linked.

Feasibility, computed in advance. Planned infra feature and fix PRs in the window: F1, S1, S2, S7 (if it ships a helper), S8, H1, H3, so about 7, plus allowance of about 2 unplanned fixes, so about 9. For 40%, product PRs must be at least 6 (6 of 15). Product supply: P0a (1), P0b merges (about 2), plus ordinary product feature and fix work, which the sweep should unblock. If product count is under 3 at day 7, pause the optional infra slices in week 2 (S4 and S6 first) rather than let the ratio fail. S9 is one batched PR for hooks plus the other prune PRs, all excluded.

Measurement command (run on day 0 and day 14; infra = the three noah-goodrich repos, product = the stillpoint-labs repos). Counts feature and fix PRs only, excluding `prune` and, for product repos, `lifecycle`:

```
since=2026-10-14
for r in noah-goodrich/borg-collective noah-goodrich/claude-plugins \
         noah-goodrich/dotfiles; do
  n=$(gh pr list -R $r --state merged \
      --search "merged:>=$since" --limit 500 --json title \
      | jq '[.[] | select(.title|test("^(feat|fix)"))
             | select(.title|test("\\(prune\\)")|not)] | length')
  echo "infra $r $n"
done
for r in ingle stillpoint reveal troth stillpointlabs-site \
         reveal-site ingle-site; do
  n=$(gh pr list -R stillpoint-labs/$r --state merged \
      --search "merged:>=$since" --limit 500 --json title \
      | jq '[.[] | select(.title|test("^(feat|fix)"))
             | select(.title|test("\\((prune|lifecycle)\\)")|not)]
             | length')
  echo "product $r $n"
done
```

Sum each prefix and divide. Surface count, from the borg-collective checkout (tests and fixtures excluded):

```
git ls-files skills agents hooks launchd bin \
  | grep -v -E '(^|/)(tests?|fixtures?)/|\.bats$' | wc -l
```

Caveat: PR count is not effort-weighted, and part of the pilot product repo's merged PRs are governance work, so the true product share is lower than reported. The rule is a guardrail on attention, not a precise metric.

## Acceptance criteria

- [ ] AC1 By day 2 the highest-risk item (P0a) is merged and applied, mitigated, or covered by a written dated risk acceptance with a re-check date; the read-only state check is recorded privately. Evidence: the private PR state and the dated private comment.
- [ ] AC2 Every stillpoint-labs PR open over 30 days at day 0 has a recommendation comment, and the count open over 60 days has fallen. Evidence: gh pr list -R stillpoint-labs/<repo> --state open --json number,createdAt per repo, before and after.
- [ ] AC3 Verify is the default tail of dispatched briefs, and at least 5 product-repo PRs merged in the window carry a verifier comment. Evidence: tests/prose_contracts.bats case; gh pr view comments on those PRs.
- [ ] AC4 The test-first prompt check is recorded and the brief carries one wording. Evidence: S2 PR body; the prose-contract assertion.
- [ ] AC5 The production probe ran green for 24 hours, both replay fixtures and the dead-endpoint fixture fail it, and stopping the runner produced an alert on the notification channel. Evidence: the probe workflow run list, the stub-server bats results, and the received alert.
- [ ] AC6 One error visible through the tracker's MCP. Evidence: the S4 PR note with the event id.
- [ ] AC7 The CI reviewer is live on the pilot repo with a written kill date, pinned by full SHA, and has produced at least one posted run. Evidence: the workflow file's uses line; a PR with the reviewer comment.
- [ ] AC8 Two repos deploy through the shared workflow, driven by `/borg-assimilate`, and the second repo's inlined copy is deleted. Evidence: the S6 PR diff stat; a green deploy run on each.
- [ ] AC9 The native agents trial has a recorded verdict against the seven criteria by day 9, with sample minimums met or the verdict marked insufficient. Evidence: the trial log summary and the S7 verdict PR.
- [ ] AC10 The fire inventory exists and the deletion record lists what was deleted with PR numbers. Evidence: the dated asset under docs/plans/assets/; git log for the deletion PRs.
- [ ] AC11 Rule 1 and Rule 2 of the infra budget hold at day 14. Evidence: the measurement commands' output pasted in the closing checkpoint.
- [ ] AC12 The token-cost skill no longer states 96/4; stale blocked sessions are cleared; the Obsidian item is closed or has a result. Evidence: grep of the skill; claude agents --json; the communication-program directive.
- [ ] AC13 The two named flaky tests pass three consecutive loaded full-suite runs. Evidence: the F1 PR.

## Reconciliation with PR #262

PR #262 (PM capabilities, phase 2: build, adopt or outsource) is open, docs only, stacked on #252, stamped not design-reviewed after three blind rounds. The lifecycle research flagged that no strategy cited it, so this directive does.

- Agree. #262's conclusion is "adopt only gh and launchd": no hosted tracker, no second record of truth, no heavy self-hosted stack, SQLite or DuckDB only if a metric outgrows a short script. That matches D3 (every state-store addition deferred behind a spike) and the hybrid's rule that adoptions are stateless. Its rejection of Linear, Plane and Taskwarrior as the record of truth stands.
- Different axis, no overlap. #262 is about prioritization, review-by dates, status history, a scorecard and a self-learning loop. This directive is about lifecycle stage coverage (verify, deploy, monitor, review) and the infra-to-product balance. Neither implements the other.
- Defer, not reject. #262's build phases (review-by and lapse reader, status-history log, scorecard) are borg-core and launchd work, i.e. infra. With 79% infra share and Rule 1, they wait until after day 14; D11's default is to merge #252 and then #262 as the research record, with no build from it. A later directive can schedule its first phase (its own triage conclusion is the same one-off directive triage, which the 2026-10-08 triage sheet partly executed).
- Where they touch. (1) The directive-state deriver and status vocabulary deletion in S9 is conditional on #262 not building on them. (2) #262 leaves value-based ordering manual ("highest-value item at the highest-value time" is a named open gap); P0a is a manual instance of it, chosen by risk (production exposure) rather than by a score. (3) #262 notes the plan-to-execution hand-off is unowned; this directive does not claim it either. (4) #262's Review-by default (filed date plus four weeks) would lapse most old directives on day one, so its own triage precedes any lapse; nothing here conflicts.
- Supersede: nothing. If Noah merges #262 as record, this directive remains valid unchanged; if he closes it, only the S9 conditional row simplifies.

## Friction not addressed in these two weeks (each with a revisit trigger)

From the friction scan of 101 checkpoints (theme counts are checkpoints mentioning the theme). Naming them here is the point: none is silently dropped.

- Two-machine stamp protocol toil (22 checkpoints), including the false "merge YOU" row because a review comment is invisible to `reviewDecision` (#278). S1 touches it only by adding a marker line to the verdict comment. Trigger: the next false merge row, or when S1's verdict comments are in use for a week.
- `borg setup` and self-deploy drift (27). Not touched; hooks and skills are live only after a manual deploy. Trigger: a stale-copy incident like the shadowed harness, or the S9 deletions landing (re-run setup and confirm).
- Flaky and untrusted tests beyond the two named offenders (14). F1 fixes those two. Trigger: any new test failing under full-suite load on main.
- Local Docker and VirtioFS instability, drone input wedges (recurring). Not touched; S7's induced Docker restart will generate data. Trigger: a third recurrence after the fixes in the memory notes.
- Permission and classifier refusals forcing Noah's hands (13). Not touched. Trigger: a refusal that blocks a slice in this plan, which is then reported rather than worked around.
- Other scan themes (CI cost and availability, state and handoff fragility) are covered by existing decisions or later directives and stay out.

## Deferred (each with a revisit trigger)

- Beads, Backlog.md, Gas City spikes. Trigger: after day 14, only if directive status drift or cross-project dependency tracking causes a missed or duplicated piece of work that a file cannot answer. Spike rules when they happen: at most two spikes, a written kill gate before starting; Backlog.md stays non-canonical until a concurrency test (three worktrees editing status, merge, count conflicts) passes; Beads needs a cross-repo ready-list and a restart-survival check in one drone first.
- Obsidian: no. Revisit only if reads per session stops being the constraint and a lens shows a retrieval win over grep.
- PKCE synthetic login (D7). Trigger: a second auth-path incident, or a free test mailbox.
- Merge-queue tooling (Refinery-style serialized rebase and merge): trigger is rebase toil recurring after the queue shrinks; GitHub's native merge queue is not available here.
- OpenTelemetry export into a local dashboard: trigger is a concrete cost-dashboard demand; the spend ledger already works.
- Fly review apps and a Renovate preset: after S6, as a follow-on to the shared workflow, still driven from `/borg-assimilate`, if a third consumer appears.
- Rolling the CI reviewer to a second repo: only if S5 passes its kill criterion.

## Risks

- Week-1 work is itself infra. The plan adds probes, a workflow, a trial and an inventory while its thesis is that infra is crowding out product. Mitigation: P0a first and measured, Rule 1 and Rule 3, a stop gate on S4, and S1 to S3 chosen as the smallest forms.
- Deletions historically do not happen (cairn was built, then decommissioned; additions landed and removals did not). Mitigation: Rule 4 (adoption not done until its deletion PR is open), S8's evidence rule, one deletion PR per item so each is revertible, and the deletion record in AC10. If S9 slips, that is reported in the closing checkpoint, not silently carried.
- Native features are closed source and in preview. A pass in S7 is not permanent. Mitigation: the trial's explicit pass criteria, vinculum retained until the verdict, deletion as a revertible PR, and a retry trigger on release.
- The probe host is one machine (D5). A dead runner skips probes and a skipped run raises no red run. Mitigation: an off-runner dead-man's switch, an explicit notification channel, and an acceptance test that stopping the runner produces a signal; trigger to move to a tiny hosted app.
- The CI reviewer adds comments rather than shrinking the queue (E3: about 5 comments per PR, 11% strict precision). Mitigation: path gate, blocker/major only, cap of 3, explicit no-findings, and the kill criterion. It also does not catch environment-assumption bugs.
- Prompt-injection and supply-chain exposure from running a third-party action on a self-hosted runner against PR content: same-repo PRs only, full-SHA pin, least-privilege token, no fork triggers.
- The usage evidence covers about 35 days of transcripts and the cost history has a known estimator bug. S8 reports missing data as missing; H1 states the caveat.
- P0a touches production risk. Mitigation: read-only verification, independent verdict, a day-2 deadline with a same-day escalation path, and every apply or manual mitigation is Noah's.
- Verdict coverage numbers depend on a log that can rotate or be missing on a machine (the nanoprobe log is absent on one host). The E2 method reads both rotation files and says so.

## Review disposition

This directive has not yet gone through /borg-collective-review; that is the next step after Noah's OK on the defaults. The table below records how the research critique of the three candidate strategies was applied, so the same fatal flaws do not reappear.

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| 1 | blocker | Platform bet unverified | applied |
| 2 | blocker | Always-on reviewer unreachable | applied |
| 3 | blocker | Delete list weakly evidenced | applied |
| 4 | major | Reviewer adds queue load | applied |
| 5 | major | Merge queue not available | applied |
| 6 | major | Week-1 work is infra | applied* |
| 7 | major | Probes miss the real break | applied* |
| 8 | minor | #262 not cited | applied |

- 1 applied: the Adopt-a-platform strategy rested on Gas City wrapping `drone exec`, which was unverified, and it added a database server. All state-store and orchestrator adoptions are deferred behind spikes (D3).
- 2 applied: the Compose strategy's always-on reviewer could not reach noah-goodrich repos. The pilot targets a stillpoint-labs repo only and says so (S5).
- 3 applied: the Focus strategy deleted vinculum and `borg link` on an unverified assumption. E1 tested visibility and messaging; S7 sets measurable criteria before any deletion, and S8 requires an inventory with a data-window rule.
- 4 applied: E3 showed precision of 11% strict; S5 is path-gated, severity-gated, capped, and has a kill criterion.
- 5 applied: GitHub merge queue is dropped, not carried as an evaluation item.
- 6 applied*: the risk is acknowledged and bounded by the budget rule rather than removed; two weeks of infra is still two weeks of infra.
- 7 applied*: E4 showed a credential-free GET cannot catch the browser-side PKCE class. S3 states the limit and D7 defers the synthetic login with a trigger; the residual risk is accepted.
- 8 applied: reconciled above.
- Rejected findings: none from the research critique.

Direction (2026-10-13, Noah): "while borg may be able to use the new agents features under the covers the goal of ... borg in general is to manage the chaos and keep me knowing what's next"; the visibility layer is out of deletion scope, native features are plumbing only, and S7, S9 and AC9 are re-scoped accordingly (new liveness-accuracy pass criterion 7).

### Blind review round 1 (2026-10-13)

Each finding was checked against the research evidence before acting.

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| B1 | blocker | Public file exposes a sensitive open item | applied |
| B2 | major | Highest-risk item not time-boxed or escalated | applied |
| B3 | major | Heartbeat shares the runner's failure mode | applied |
| B4 | major | Infra budget inconsistent and gameable | applied |
| B5 | major | High-ranking friction absent | applied |
| B6 | major | Vinculum deletion over-scoped for the trial | applied |
| B7 | minor | Pilot repo hook paths unverified | applied (precondition) |
| B8 | minor | Dangling and unchecked references | applied |

- B1 applied: confirmed the repo is public. The item, its repo and PR number, and the security-posture wording were removed; the specifics live in the private triage sheet and the private repo's own PR. Caveat for Noah: the earlier revision stays reachable in this PR's commit history and the PR was open when filed; scrubbing that needs a force-push or a fresh PR, which is Noah's call.
- Direction (2026-10-13, Noah): deployment is a step of `/borg-assimilate`, not a separate command or skill; S6 and AC8 re-scoped accordingly, no other slice changed.
- B2 applied: P0 is split into P0a (day 2, escalation, dated risk acceptance only) and P0b (sweep, lower priority, stillpoint-labs only; the noah-goodrich PRs are out of Rule 1).
- B3 applied: dead-man's switch off the runner, explicit alert channel, grace for best-effort cron, dead-runner acceptance test. Declined in part: the finding asks why Gatus was dropped. It stays dropped because the tested Gatus build cannot read a Location header; the replacement for its validation is the fixture suite in S3.
- B4 applied: deletions excluded, hook deletions batched into one PR, S3 to S6 excluded from the product side, feature and fix PRs only, Rule 2 excludes tests and fixtures, feasibility precomputed (needs about 6 product PRs of about 15).
- B5 applied: confirmed against the friction scan (flaky 14, two-machine stamps 22, setup drift 27, local Docker instability, refusals 13). Added F1 and a friction-not-addressed section with triggers; S1 states what it does and does not touch of the stamp protocol (#278).
- B6 applied: deletion limited to the orchestrator-to-drone path; sample minimums met by scripted drills with a day-5 check; lag bar moved to 5 minutes (3 sat on E1's noise); verdict due day 9; version recorded and held-message visibility tied to the silent-drop criterion.
- B7 applied: pilot repo is chosen after confirming hook paths and PR rate; "useful" is stated as the lenient standard on blocker and major comments. The hook paths in the pilot repo are NOT yet verified (private repo, not checked here).
- B8 applied: the S9 verifier row reference removed (no such row); S1 gains a test verifier pass on a product repo as a precondition; H2 names `claude stop` and `claude rm` from `claude --help` (not yet run); D11 restates retarget-before-merge.
