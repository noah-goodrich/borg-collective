# Source Record: Anthropic Engineering, "Demystifying evals for AI agents"

- **Full citation:** Anthropic, "Demystifying evals for AI agents," Engineering at Anthropic, Jan 9, 2026.
- **URL:** https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (first-party engineering guidance)
- **Track:** t2 tooling landscape (contrary-to-framework evidence)

## Verified Quote(s)

Appendix "Eval frameworks" and surrounding text (fetch tool returned fragments; each fragment is exact):

1. "We find that while frameworks can be a valuable way to accelerate progress and standardize,"
2. "they're only as good as the eval tasks you run through them."
3. "It's often best to quickly pick a framework that fits your workflow, then invest your energy in the evals themselves"
4. "by iterating on high-quality test cases and graders."
5. Harbor entry: "is designed for running agents in containerized environments"
6. Langfuse entry: "provides similar capabilities as a self-hosted open-source alternative"
7. "Because model outputs vary between runs, we run multiple trials to produce more consistent results."
8. "pass^k measures the probability that all k trials succeed."

Apostrophes in quotes 2 and 3 may be curly on the live page.

## Key finding

Anthropic's own guidance treats the framework choice as secondary: pick one quickly, then spend effort on tasks and graders, and run multiple trials reporting pass@k or pass^k. Its framework appendix lists Harbor, Braintrust, LangSmith, Langfuse and Arize but not promptfoo or Inspect.

Access status: live
