# Demystifying evals for AI agents

- Citation: Mikaela Grace, Jeremy Hadfield, Rodrigo Olivares, Jiri De Jonghe, "Demystifying evals for AI agents", Anthropic Engineering blog, 2026-01-09.
- URL: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (practitioner engineering post)
- Access status: live (fetch tool capped quotes at 125 characters, so quotes are sentence fragments)

## Verified Quote(s)

Section "How to think about non-determinism in evaluations for agents":

> pass@k measures the likelihood that an agent gets at least one correct solution in k attempts.

> pass^k measures the probability that all k trials succeed.

Section "Capability vs. regression evals":

> They should start at a low pass rate, targeting tasks the agent struggles with and giving teams a hill to climb.

> should have a nearly 100% pass rate.

> capability evals with high pass rates can “graduate” to become a regression suite

Section "Step 0. Start early":

> In reality, 20-50 simple tasks drawn from real failures is a great start.

Section "Step 3: Build balanced problem sets":

> Test both the cases where a behavior should occur and where it shouldn't.

> One-sided evals create one-sided optimization.

> The challenge was preventing the model from searching when it shouldn’t

Section "Step 4" (environment):

> Each trial should be “isolated” by starting from a clean environment.

Section "Step 5: Design graders thoughtfully":

> We recommend choosing deterministic graders where possible,

> LLM-as-judge graders should be closely calibrated with human experts

> So as not to unnecessarily punish creativity, it’s often better to grade what the agent produced, not the path it took.

Section "Step 7: Monitor for capability eval saturation":

> Eval saturation occurs when an agent passes all of the solvable tasks, leaving no room for improvement.

> SWE-Bench Verified scores started at 30% this year, and frontier models are now nearing saturation at >80%.

Section "How evals fit with other methods": table row for automated evals:

> Can run on every commit

## Key finding

Anthropic separates capability evals (start low, give a hill to climb) from regression evals (near 100%), and saturated capability cases "graduate" into the regression suite rather than being deleted. It recommends 20-50 tasks from real failures to start, multiple isolated trials, deterministic graders where possible, human-calibrated judges otherwise, both should and should-not cases, and pass^k when consistency matters.
