# Source Record: Inspect AI (UK AISI) docs and PyPI

- **Full citation:** UK AI Security Institute, Inspect AI documentation pages "Scoring Metrics", "Agent Bridge", "Sandboxing", and the `inspect-ai` PyPI project page, read 2026-10-30.
- **URL:** https://inspect.aisi.org.uk/metrics.html.md ; https://inspect.aisi.org.uk/agent-bridge.html.md ; https://inspect.aisi.org.uk/sandboxing.html ; https://pypi.org/project/inspect-ai/
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (government lab, open source)
- **Track:** t2 tooling landscape

## Verified Quote(s)

metrics.html.md:
1. "If a task is run over more than one `epoch`, multiple scores will be generated for each sample."
2. "By default, the reduced view is built with `mean`."
3. pass_at reducer: "Probability of at least 1 correct sample given `k` epochs"
4. "Wilson score confidence interval for the mean of binary (0/1) scores, treating it as a binomial proportion."
5. "Defaults to a 95% Student-t interval"

agent-bridge.html.md:
6. "You can also use CLI based agents that run within sandboxes"
7. "All model calls are captured and produce the same transcript output as when using conventional agents."

sandboxing.html:
8. local sandbox: "Local file system (no sandbox)."
9. "Before using Docker sandbox environments, please be sure to install Docker Engine."

PyPI page:
10. Summary: "Framework for large language model evaluations"

PyPI facts (not quotes): latest 0.3.286 released 2026-10-28; MIT License; requires Python >=3.11.

## Key finding

Inspect is the most statistically complete option: epochs with mean/pass@k/at_least reducers, stderr, bootstrap, Student-t and Wilson intervals, rich eval logs, and a `local` sandbox that runs on the host filesystem, with releases every few days (MIT). Its agent bridge captures model calls only by proxying the agent's API traffic through Inspect's provider, which fits Claude Code (via inspect_swe) but not a Snowflake-authenticated Cortex CLI, which would need a custom solver that shells out and parses stream-json itself.

Access status: live (scorers.html also fetched; it does not cover epochs)
