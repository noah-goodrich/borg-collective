# Documentation Index

## Start Here

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [Boris Workflow](boris-workflow.md) | ELI5 walkthrough of the day-to-day workflow — what each tool is for and how a session actually runs. Start here. | 10 min |
| [Six-Pager Narrative](six-pager.md) | Formal proposal: why this tool exists, what problem it solves, how it works, and the research that backs every decision. Written in Amazon 6-pager format (narrative prose, not bullet points). | 15 min |
| [Quickstart Guide](quickstart.md) | Step-by-step installation and first-run guide. Takes you from zero to a working `borg` in under ten minutes. | 5 min |
| [Cheatsheet](cheatsheet.md) | Single-page reference card. Every command, status indicator, config option, and file location on one page. | 1 min |

## Deep Dives

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [Architecture Guide](architecture.md) | How every component fits together: data flow, file layout, registry schema, hook lifecycle, CLI dispatch, skills loading, and devcontainer integration. | 10 min |
| [Skills Guide](skills-guide.md) | Every installed skill explained: what it does, when to use it, why it exists, and how to create your own. Covers marketplace skills, built-in commands, and custom ADHD-optimized skills. | 10 min |
| [Research Foundation](research.md) | Complete citation index for every design decision. 50+ sources across ADHD psychology, neurodivergent UX, shipping discipline, Claude Code best practices, AI addiction risk, and the skills ecosystem. | Reference |
| [Devcontainer & CoCo Guide](devcontainer-coco.md) | How borg works with Docker Compose devcontainers and Snowflake Cortex Code CLI. Volume mount requirements, path resolution, skill portability, Podman/Docker coexistence. | 8 min |
| [Orchestration Architecture](orchestration-architecture.md) | Frozen spec for the orchestrator-worker model: the handoff state machine and the multi-agent decisions that are settled. Routing itself lives in `agents/ROUTING.md`. | 10 min |
| [Work Machine Setup](work-machine-setup.md) | The canonical runbook for a fresh macOS work machine — and for ongoing updates to an existing one. | 15 min |
| [Competitive Landscape](competitive-landscape.md) | How borg compares to alternatives in the ecosystem, refreshed quarterly, so investment and deprecation calls are informed. | Reference |
| [Vinculum Message Bus](vinculum.md) | The file-based cross-session pub/sub broker behind `borg vinc`: the verb surface, on-disk layout, the live-delivery watcher, and the gaps it still has. | 8 min |
| [Chains & Program Manifests](chain.md) | `borg chain list/plan/sync` and the `<project>/.borg/programs/*.json` format that declares cross-repo merge order. Explains why `chain` and `program` both appear. | 10 min |
| [Infoviz Program](infoviz/) | The information/data-visualization learning program: curriculum, ELI10 briefs, and the evidence-traced design playbook. | Reference |

## Contributing

| Document | Purpose | Read Time |
|----------|---------|-----------|
| [Contributing Guide](contributing.md) | For someone changing the repo: the `.venv` prerequisite and why there is no devcontainer, every Makefile target, the bats/pytest split, the CI lanes, and what lives in `scripts/`, `bin/`, `merge-tree/` and `evals/`. | 10 min |
| [Environment Variables](environment.md) | Every `BORG_*` name the code reads, with what reads it and its verified default. Leads with the shell-vs-environment-variable rule that once shipped `borg recon` completely dead. | Reference |

## Diagrams

Self-contained HTML — open them in a browser, no build step.

| Diagram | Shows |
|---------|-------|
| [deployment-ownership](diagrams/deployment-ownership.html) | Who installs what, where — `install.sh` vs `borg setup` vs `build-plugin.sh`, and why skills are not under `~/.claude`. |
| [link-pipeline](diagrams/link-pipeline.html) | One sweep, one document — and the purity boundary `picture.py` sits behind. |
| [session-state](diagrams/session-state.html) | `active` to `waiting` to `idle` to `archived`, every edge a hook or a timer. |
| [drones-vs-nanoprobes](diagrams/drones-vs-nanoprobes.html) | Persistent container vs ephemeral subagent — the two things most often conflated. |
| [plan-lifecycle](diagrams/plan-lifecycle.html) | `directives/` to `PROJECT_PLAN.md` to `assimilated/`, with both side exits and both auto-writers. |

## Also See

| Document | Location | Purpose |
|----------|----------|---------|
| [README](../README.md) | Repository root | Open source documentation for sharing |
| [CLAUDE.md](../CLAUDE.md) | Repository root | Internal handoff for Claude Code sessions working on this project |
