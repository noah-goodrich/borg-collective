# GEPA: Reflective Prompt Evolution Can Outperform Reinforcement Learning

- Citation: Lakshya A Agrawal et al., "GEPA: Reflective Prompt Evolution Can Outperform Reinforcement Learning", arXiv:2507.19457 (v1 July 2025); ICLR 2026.
- URL: https://arxiv.org/html/2507.19457v1
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed (ICLR 2026); fetched text is the arXiv v1 preprint
- Access status: live (first 100k of 151k characters read; Appendix D generalization-gap and Appendix E cost sections not read)

## Verified Quote(s)

Abstract:

> Across four tasks, GEPA outperforms GRPO by 10% on average and by up to 20%, while using up to 35x fewer rollouts.

> GEPA also outperforms the leading prompt optimizer, MIPROv2, by over 10% across two LLMs

Section 3.3 (Pareto-based candidate selection):

> GEPA then compiles a list of candidates that achieve the best score on at least one training task

Section 4.1 (data splits):

> We use 150 examples for training, 300 for validation, and 300 for testing.

> The dataset is split into 111 training examples, 111 for validation, and 221 for testing.

Section 5, Observation 4 (prompt length):

> up to 9.2× shorter than those from MIPROv2

Section 5 (Merge on Qwen3):

> lead to performance degradation when used with Qwen3 8B

## Key finding

GEPA, the current leading reflective optimizer, beats MIPROv2 and GRPO and yields shorter prompts, but its evidence comes from splits of roughly 111 to 150 training plus 111 to 300 validation examples and thousands of rollouts, which is far above a 4-to-10-case regime. Most rollouts go to validating candidates on the Pareto set, so validation size drives cost.
