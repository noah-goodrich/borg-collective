# Source Record: Harbor (harbor-framework/harbor) repository

- **Full citation:** harbor-framework/harbor (formerly laude-institute/harbor), GitHub repository README, read 2026-10-30.
- **URL:** https://github.com/harbor-framework/harbor
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (repository README)
- **Track:** t2 tooling landscape

## Verified Quote(s)

1. Description: "Framework for evaluating and improving agents"
2. "Evaluate arbitrary agents like Claude Code, OpenHands, Codex CLI, and more."
3. "will launch the benchmark locally using Docker"

Facts (not quotes): Apache-2.0; about 6.6k stars; install `uv tool install harbor` or `pip install harbor`; release list not shown on the fetched page.

## Key finding

Harbor (the Terminal-Bench 2.0 harness) runs CLI coding agents such as Claude Code in Docker containers per trial, which is the closest match to "agent edits a working directory" among general frameworks. It is built for benchmark-scale container runs; Docker-per-trial and its task format are a heavier lift than borg's host-side harness, and Cortex support would need a custom agent adapter (not verified).

Access status: live
