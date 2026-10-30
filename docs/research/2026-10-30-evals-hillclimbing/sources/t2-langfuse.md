# Source Record: Langfuse repository, releases, and self-hosting docs

- **Full citation:** langfuse/langfuse GitHub repository README and Releases page; Langfuse docs "Self-hosting", read 2026-10-30.
- **URL:** https://github.com/langfuse/langfuse ; https://github.com/langfuse/langfuse/releases ; https://langfuse.com/self-hosting
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

README:
1. "This repository is MIT licensed, except for the `ee` folders."
2. "Datasets enable test sets and benchmarks for evaluating your LLM application."

self-hosting:
3. "consists of two application containers, storage components, and an optional LLM API/Gateway."
4. "Postgres: The main database for transactional workloads."
5. "Clickhouse: High-performance OLAP database which stores traces, observations, and scores."
6. "Redis/Valkey cache: A fast in-memory data structure store."
7. "S3/Blob Store: Object storage to persist all incoming events, multi-modal inputs, and large exports."

Releases facts (not quotes): latest v4.72.0 marked Latest, dated 29 Oct (year not shown; page footer 2026); about 36.8k stars.

## Key finding

Langfuse is actively maintained, mostly MIT, and self-hostable, but self-hosting means running web and worker containers plus Postgres, ClickHouse, Redis/Valkey and S3-compatible storage. That is a hosted service in all but name for a two-machine solo setup, so it fails the adoption-cost bar for eval history.

Access status: live
