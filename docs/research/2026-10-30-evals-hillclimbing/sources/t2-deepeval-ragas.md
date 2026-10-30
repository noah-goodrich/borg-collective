# Source Record: DeepEval and Ragas PyPI pages and Ragas releases

- **Full citation:** `deepeval` PyPI project page; `ragas` PyPI project page; explodinggradients/ragas GitHub Releases, read 2026-10-30.
- **URL:** https://pypi.org/project/deepeval/ ; https://pypi.org/project/ragas/ ; https://github.com/explodinggradients/ragas/releases
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (package metadata and README)
- **Track:** t2 tooling landscape

## Verified Quote(s)

deepeval:
1. Summary: "The LLM Evaluation Framework"
2. "similar to Pytest but specialized for unit testing LLM apps."
3. Task Completion: "evaluate whether an AI agent accomplished its goal"
4. Tool Correctness: "check if the right tools were called with the right arguments"

ragas:
5. Summary: "Evaluation framework for RAG and LLM applications"
6. "`agent_evals` - Evaluate AI agents"  (listed under a "Coming Soon" template list)

Facts (not quotes): deepeval 4.3.2 released 2026-10-27, Apache-2.0, Python >=3.9,<4.0. ragas 0.4.3 released Jan 13 (year inferred 2026 from page), Apache-2.0, Python >=3.9; prior releases 23 Dec and 10 Dec.

## Key finding

DeepEval is active (release two days before this read) and offers pytest-style agent metrics, but its metrics are mostly LLM-judged over a test case object you populate yourself, so for a CLI agent it is a judge library, not a runner, and adds a dependency for what one judge prompt does. Ragas is RAG-focused, lists agent evals as coming soon, and has not released since January 2026: skip.

Access status: live
