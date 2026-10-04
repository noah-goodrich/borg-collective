# Track A: external landscape for borg's PM gaps

**Date:** 2026-10-04 (all URLs accessed 2026-10-04)
**Question:** For each gap in phase-1 analysis, which real external tools/libraries/services exist, and how do they fare on coverage, access, privacy, cost, health, integration effort and lock-in?
**Method note:** repo facts (last push, latest release, license, archived flag) come from the GitHub REST API via `gh api repos/<owner>/<repo>` and `.../releases/latest` on 2026-10-04 (cited as "GH API"). Product claims come from vendor pages fetched the same day. The web-search budget was exhausted mid-run, so some candidates have thinner evidence; those are marked UNVERIFIED. Phase-1 analysis.md was only skimmed (its §1 recommendations and glossary), not re-researched.

## Executive summary

- Almost every gap is a computation over events borg already owns (checkpoints, plan files, registry, agents.jsonl, gh PRs). The external landscape offers storage/query/visualization pieces (DuckDB, `gh`, GitHub Projects fields) far more than finished "PM intelligence" that fits a local-first, work-data-stays-local, solo setup.
- Strongest adoptable pieces: `gh` + GitHub GraphQL (PR latency, deployments, and `ProjectV2ItemStatusChangedEvent` status history) as the fact source; DuckDB as an optional local store over JSONL; GitHub Projects v2 date/number/iteration fields as an optional appetite/stop-date surface.
- Everything DORA/flow-metric-shaped as a product is team-oriented: Swarmia ($45/dev/mo, free <=10 devs), LinearB (min 50 devs), DevLake (needs MySQL/Postgres + Grafana, still beta-tagged), Four Keys (archived). None is a fit for one developer plus a work-data-never-leaves rule except self-hosted DevLake, at a heavy operational cost.
- No verified tool covers the verify-verdict log, debriefs-from-repo-facts, capacity/sustainability signals, or the re-runnable scorecard; those are BUILD by default, and the build is small (append-only JSONL + derived queries).

## Gap -> candidates table

| Gap | Candidates (best first) | Verdict |
|---|---|---|
| Value/prioritization rule + ranking snapshots | (1) plain JSONL snapshot written by borg (build); (2) Taskwarrior urgency coefficients; (3) Beads ready-queue; (4) Linear/Plane priority fields | Build the snapshot. Taskwarrior/Beads would be a second source of truth for work items. |
| Appetite + stop dates | (1) GitHub Projects v2 date/number/iteration fields via `gh project`; (2) frontmatter fields in directive files (build); (3) Plane cycles/modules; (4) Linear cycles | Frontmatter in the existing directive file is fewest-moving-parts. Projects v2 is an optional mirror. |
| Status-history events, flow metrics (lead time, WIP, throughput, aging) | (1) borg's own append-only event log + DuckDB/jq; (2) GitHub `ProjectV2ItemStatusChangedEvent` / issue timeline via GraphQL; (3) ActionableAgile (analytics, SaaS/desktop) UNVERIFIED details; (4) DevLake | Build the log (no external tool can see session status flips). Use GitHub timeline for PR/issue-side history. |
| DORA-style delivery metrics | (1) `gh` REST/GraphQL (PRs, releases, Deployments) computed locally; (2) Apache DevLake self-hosted; (3) Swarmia free tier (SaaS); (4) OTel Collector githubreceiver (alpha); Four Keys = dead | Compute locally from `gh`. DevLake only if a team appears. |
| Verify-verdict logging | None found. Closest: Beads (issue graph), generic JSONL | Build (one hook line). |
| Debriefs/retros fed by repo facts | None found for solo/agent use. Partial inputs: git-quick-stats, gitinspector, `gh` | Build; use `gh`/git as fact source. |
| Capacity/sustainability signals | (1) Timewarrior (manual time tracking, JSON export); (2) ActivityWatch (automatic window/activity tracking) | Optional personal input only; manual tracking conflicts with ADHD-aware low-capture design. |
| Re-runnable scorecard | (1) DuckDB SQL files over JSONL/SQLite; (2) Datasette for browsing; (3) Grafana (heavy) | DuckDB (or plain sqlite3 + SQL files) is the cheapest correct shape. |

## Candidate entries

### GitHub Projects v2 + `gh` CLI + GraphQL
- Covers: custom fields (date, iteration, number; up to 50), charts/insights, built-in workflow automations, GraphQL API and Actions control. https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects
- CLI/API: `gh project` has 19 subcommands (field-create, item-edit, item-list, etc.); token needs the `project` scope. https://cli.github.com/manual/gh_project
- History: GraphQL introspection on 2026-10-04 shows `ProjectV2ItemStatusChangedEvent` as a member of `IssueTimelineItems`, plus `AddedToProjectV2Event`/`RemovedFromProjectV2Event`; `ProjectV2Item` itself exposes only `createdAt`/`updatedAt` (no per-field history). So status history exists only for items that are issues/PRs and only for the Status field (inferred from schema names; field semantics not tested). Source: `gh api graphql` introspection, run 2026-10-04.
- `Deployment` objects expose `createdAt`, `state`, `statuses`, `environment`, `commit` (same introspection) which is enough for deploy-frequency/lead-time-for-changes if the repo records deployments (borg-style repos may not; UNVERIFIED that borg's repos create Deployments).
- Hosting/privacy: SaaS on GitHub, which the project already uses as code host. Private-repo project data stays within GitHub's tenant; for the work machine this is a policy question for the employer (not verifiable here). Plan/pricing limits for Projects: UNVERIFIED (docs page gave none).
- License/cost: `gh` is MIT, v2.102.0 released 2026-09-30, pushed 2026-10-02 (GH API). Projects included with GitHub accounts (pricing details UNVERIFIED).
- Integration effort: low (borg already shells to `gh`). Lock-in: moderate for Projects field data (export via GraphQL), none for `gh`.
- Caveat: `github/gh-projects` (old extension) is archived (last push 2023-06-21; GH API), irrelevant now that `gh project` is built in.

### Apache DevLake
- Covers: ingests GitHub, GitLab, Jira, Jenkins, Bitbucket, Azure DevOps, SonarQube, PagerDuty and others; webhooks for unsupported tools; DORA metrics and prebuilt Grafana dashboards; custom SQL against its domain layer. https://devlake.apache.org/docs/Overview/Introduction
- Self-hosted only; Docker Compose (PoC) or Helm/Kubernetes; supports MySQL and PostgreSQL. https://github.com/apache/incubator-devlake
- Health: Apache-2.0, pushed 2026-09-28, latest release `v1.0.3-beta18` on 2026-09-27, 3,155 stars (GH API). Beta-tagged releases only on the latest tag.
- Privacy: fully local, so work data can stay on the work machine; but it needs a database + Grafana stack (several containers) per machine and per-project config. Disproportionate for a solo CLI-first tool.
- Integration: DB queries or Grafana; borg would read SQL tables. Lock-in: low (open schema), cost: operational.

### Google Four Keys
- Archived by owner 2024-01-23, "not currently maintained"; GCP-only architecture (Cloud Run, Pub/Sub, BigQuery). https://github.com/dora-team/fourkeys ; GH API confirms archived=true, last release v1.0.2 (2023-05-04).
- Verdict: dead; only useful as a metric-definition reference.

### Swarmia
- Free plan up to 9 developers; Standard $45/dev/month (annual); includes DORA metrics, code/issue metrics, working agreements, data export to warehouses; integrates GitHub, GitLab, Jira, Linear, Slack. https://www.swarmia.com/pricing/
- SaaS only (no self-host verified; Enterprise lists "on-premise integrations"). Work data would leave the work machine to a third party, which violates the stated constraint unless the employer approves. Lock-in: moderate. Also cannot see session/agent events.

### LinearB
- Essentials $29/user/month with a 50-developer minimum, GitHub Cloud only; Enterprise $59 with 100-dev minimum; 45-day trial; DORA + benchmarks; REST API export. https://linearb.io/pricing
- Verdict: priced and scoped for teams; not applicable to solo use.

### Sleuth
- Sleuth's site now leads with "Sleuth Skills" (AI-agent skill governance); "Sleuth DORA" is retained as a separate login-portal product. https://www.sleuth.io/ ; pricing page lists only the SX open-source skills distribution and an enterprise skills product, with no DORA pricing shown. https://www.sleuth.io/pricing
- Verdict: DORA product is de-emphasized; no public DORA pricing found; treat as unavailable for planning.

### ActionableAgile / Nave (flow analytics)
- Claimed coverage (cycle-time scatterplot, CFD, aging WIP, Monte Carlo) is from general knowledge and could NOT be verified: actionableagile.com redirects to 55degrees.se, whose product/pricing pages returned 404 in this run. No GitHub repo found under the ActionableAgile org via the GH API (404). Treat as UNVERIFIED SaaS/commercial.
- Value as a reference: the metric definitions (aging WIP, cycle-time percentiles) are well-known and cheap to compute in SQL. Don't adopt.

### Plane (OSS) and Linear (SaaS) as the tracker
- Plane: AGPL-3.0, 60,350 stars, pushed 2026-10-01, latest release v1.4.2 on 2026-08-23 (GH API). Self-host with Docker Compose/K8s needing PostgreSQL and Redis; cloud Free up to 12 users, Pro $6-8/user/mo; cycles, modules, analytics dashboards. https://github.com/makeplane/plane ; https://plane.so/pricing . Plane analytics tiers: Pro and above; whether self-hosted community edition includes them is UNVERIFIED.
- Linear: Free plan (2 teams, 250 issues), Basic $10/user/mo, Business $16/user/mo (adds Linear Insights). https://linear.app/pricing . SaaS only. Linear's API/webhook/history docs could not be fetched (host unreachable), so history/cycle-time API claims are UNVERIFIED. Official monorepo `linear/linear` is MIT, SDK/plugins, pushed 2026-09-29 (GH API). No official CLI found; community `schpet/linear-cli` is unofficial, ISC, v2.6.0 on 2026-09-02, pushed 2026-10-04. https://github.com/schpet/linear-cli
- Verdict: both would introduce a second system of record for work items that borg currently models as files; on the work machine, SaaS (Linear) is a data-export problem; Plane self-host adds Postgres+Redis. Only worth it if borg abandons files-as-directives.

### Taskwarrior + Timewarrior
- Taskwarrior 3.x: UDAs, hooks API, JSON import/export, urgency scoring, sync. https://taskwarrior.org/docs/ ; MIT, v3.5.0 (2026-08-16), pushed 2026-09-26 (GH API).
- Timewarrior: tags, JSON export, extension API, Taskwarrior on-modify hook integration. https://timewarrior.net/docs/ ; MIT, v1.10.0 (2026-08-02), pushed 2026-10-02 (GH API).
- Local-first, no network, so the work-machine rule is satisfied. Urgency coefficients are a ready-made editable rule, but they weight due date/priority/tags and are not a value model (inference). Integration: borg would have to mirror directives into tasks or vice versa (two stores); Timewarrior requires manual start/stop, which an ADHD-aware design should not depend on. Lock-in: low.

### Beads (agent issue tracker)
- Dependency-graph issue tracker for coding agents on Dolt; embedded mode stores data in `.beads/embeddeddolt/`; `bd ready` lists unblocked tasks; sync via git remotes. https://github.com/gastownhall/beads ; MIT, v1.3.1 (2026-09-30), pushed 2026-10-04, 27,621 stars (GH API).
- Explicit lead-time/cycle-time dashboards not found in the fetched README. Relevant as a possible store for directives plus a ready-queue, but it would replace borg's file-based directive model rather than add the missing PM layers; also overlaps borg's own nanoprobe/plan system. Fit assessment is an inference.

### Git-analytics tools (git-quick-stats, gitinspector, Hercules, cloc)
- git-quick-stats: bash script with commit stats by author/day/branch, CSV and JSON output; MIT, 2.11.0 (2026-04-18). https://github.com/git-quick-stats/git-quick-stats ; GH API.
- gitinspector: per-author statistics; GPL-3.0, v0.5.1 (2026-09-25), pushed 2026-10-01 (GH API).
- Hercules: pushed 2023-02-07, last release v10.7.2 (2020-01-14), license NOASSERTION (GH API): effectively unmaintained.
- All measure code activity (commits/lines), which phase-1 flags as the Activity dimension that must not stand alone. They do not produce lead time, WIP or delivery stability. Low value; `git log` plus `gh` already covers what's useful.

### DuckDB / SQLite / Datasette as the local metrics store
- DuckDB queries JSON and newline-delimited JSON files directly in SQL (`SELECT ... FROM read_json('*.json.gz')`, `read_ndjson`). https://duckdb.org/docs/current/data/json/loading_json ; MIT, v1.5.6 (2026-09-28), pushed 2026-10-02 (GH API). In-process, no server (embedded nature is general knowledge, not confirmed from the fetched page).
- Fit: borg's existing JSONL (agents.jsonl, memory-hits.log style files, token-spend.jsonl) can be queried in place, so the scorecard becomes versioned SQL files over append-only logs. Zero ingestion service; works offline on either machine; aggregates can be allow-listed for publication. Python wheel or CLI binary adds one dependency; sqlite3 (already in Python stdlib) is the zero-dependency alternative with weaker JSON ergonomics (inference).
- Datasette (Apache-2.0, 0.65.5 on 2026-09-16) and sqlite-utils (Apache-2.0, 4.2.1 on 2026-08-13) are optional browse/ingest helpers (GH API). Not needed.

### Grafana
- AGPL-3.0, v13.2.3 (2026-09-29), massively maintained (GH API). Dashboard server; heavy for a CLI-first solo tool, and borg's renderer already prints the `borg link` document. DevLake is the main reason anyone would run it. Skip unless a visual surface is demanded.

### OpenTelemetry for dev metrics
- Collector-contrib `githubreceiver`: alpha for metrics and traces; scrapes GitHub via GraphQL/REST (VCS metrics described as leading indicators to DORA) or receives Actions webhooks; needs a token for useful rates. https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/githubreceiver ; collector-contrib v0.162.0 (2026-09-29), Apache-2.0 (GH API).
- Needs a collector process plus a backend to store results. Overbuilt for one developer; alpha stability. Skip.

### GrimoireLab / CHAOSS
- GrimoireLab (CHAOSS community-health analytics): GPL-3.0, 1.22.1 (2026-09-22) (GH API). Oriented to open-source community metrics (contributors, orgs), not a solo PM. The related Augur repo is archived with a notice that it left CHAOSS (GH API). Skip.

### Shape Up tooling
- No dedicated open-source Shape Up tool was verified in this run (search budget exhausted). Appetite and circuit breaker are methods (Basecamp), implementable as two fields plus a review date. Treat the tooling landscape as UNVERIFIED/empty; Plane cycles/Linear cycles are fixed-length iterations, not appetite-per-item.

## Strongest "don't adopt" cases

1. **Team DORA/flow SaaS (Swarmia, LinearB, Sleuth DORA).** They are priced and scoped for teams (LinearB 50-dev minimum, Swarmia free only to 9 devs but SaaS), they cannot see borg's session/agent events, and on the work machine they export work data to a third party. They also invite the Goodhart failure the analysis warns about (a dashboard that agents and the owner start optimizing).
2. **Heavy self-hosted analytics stacks (DevLake + Grafana, OTel Collector + backend, Plane).** Each adds a database, multi-container stack and per-machine operations for one user; DevLake's latest tags are still beta; the githubreceiver is alpha. They violate "fewest moving parts" and add a second store beside borg's files.
3. **Moving the system of record to an external tracker (Linear, Plane, Taskwarrior, Beads).** It creates dual truth with directive files, checkpoints and the registry, breaks the one-direction/public-repo/work-data rules unless mirrored carefully, and changes the stated Axis A fix from "derive from artifacts the agent already produces" to "ask someone to maintain a tracker", which is the voluntary-capture pattern borg's cairn post-mortem rejected.
4. (Dead options) Four Keys is archived since 2024-01-23; Hercules has had no release since 2020; code-activity git-stats tools measure Activity only.

## Evidence gaps and uncertainties
- Linear API/history/webhook docs unreachable (EHOSTUNREACH); ActionableAgile/Nave product facts unverified (404s); GitHub Projects plan limits and privacy terms unverified; Plane community-edition analytics scope unverified; Shape Up tooling not surveyed; Taskwarrior urgency-as-value-model judgement and DuckDB embedded characterization are inference or general knowledge.
- `ProjectV2ItemStatusChangedEvent` was confirmed to exist in the schema, not exercised against a real project (payload fields, retention, and whether it fires for automation-driven changes are untested).
- Star counts and "last push" are activity proxies, not quality evidence.

## Sources index
| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | GitHub REST API repo/release metadata (many repos) | https://api.github.com/repos/<owner>/<repo> via `gh api` | 2026-10-04 | [2024-2026] |
| 2 | GitHub GraphQL schema introspection (ProjectV2*, Deployment) | https://docs.github.com/en/graphql | 2026-10-04 | [2024-2026] |
| 3 | About Projects (GitHub docs) | https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects | 2026 | [2024-2026] |
| 4 | gh project manual | https://cli.github.com/manual/gh_project | 2026 | [2024-2026] |
| 5 | DevLake introduction | https://devlake.apache.org/docs/Overview/Introduction | 2026 | [2024-2026] |
| 6 | DevLake repo | https://github.com/apache/incubator-devlake | 2026 | [2024-2026] |
| 7 | Four Keys repo | https://github.com/dora-team/fourkeys | 2024 | [2024-2026] |
| 8 | Swarmia pricing | https://www.swarmia.com/pricing/ | 2026 | [2024-2026] |
| 9 | LinearB pricing | https://linearb.io/pricing | 2026 | [2024-2026] |
| 10 | Sleuth home / pricing | https://www.sleuth.io/ , https://www.sleuth.io/pricing | 2026 | [2024-2026] |
| 11 | Linear pricing | https://linear.app/pricing | 2026 | [2024-2026] |
| 12 | schpet/linear-cli | https://github.com/schpet/linear-cli | 2026 | [2024-2026] |
| 13 | Plane repo / pricing | https://github.com/makeplane/plane , https://plane.so/pricing | 2026 | [2024-2026] |
| 14 | Taskwarrior docs | https://taskwarrior.org/docs/ | 2026 | [2024-2026] |
| 15 | Timewarrior docs | https://timewarrior.net/docs/ | 2026 | [2024-2026] |
| 16 | Beads repo | https://github.com/gastownhall/beads | 2026 | [2024-2026] |
| 17 | git-quick-stats repo | https://github.com/git-quick-stats/git-quick-stats | 2026 | [2024-2026] |
| 18 | DuckDB JSON loading docs | https://duckdb.org/docs/current/data/json/loading_json | 2026 | [2024-2026] |
| 19 | OTel githubreceiver README | https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/githubreceiver | 2026 | [2024-2026] |
