# tau-bench: A Benchmark for Tool-Agent-User Interaction in Real-World Domains

- Citation: Shunyu Yao, Noah Shinn, Pedram Razavi, Karthik Narasimhan, "τ-bench: A Benchmark for Tool-Agent-User Interaction in Real-World Domains", arXiv:2406.12045 (v1, 2024-06-17).
- URL: https://arxiv.org/abs/2406.12045
- Date accessed: 2026-10-30
- Evidence level: preprint per arXiv page (venue not listed; I recall ICLR 2025 but did not verify). Older than 2025; flagged.
- Access status: live (abstract only)

## Verified Quote(s)

Abstract:

> We also propose a new metric (pass^k) to evaluate the reliability of agent behavior over multiple trials.

> are quite inconsistent (pass^8 <25% in retail).

## Key finding

tau-bench introduced pass^k (all k trials succeed) as a reliability metric and showed that agents succeeding on under half of tasks once fall below 25% when required to succeed 8 times in a row. For a user-facing routine, pass^k, not pass@k, is the metric that matches the experience of repeated use.
