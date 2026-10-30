# Source: Li et al., "SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks"

**Full citation:** Xiangyi Li, Wenbo Chen, Yimin Liu, Shenghan Zheng, et al. "SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks." arXiv:2602.12670v1 [cs.AI], 13 February 2026.
**URL:** https://arxiv.org/html/2602.12670v1
**Date accessed:** 2026-10-30
**Evidence level:** peer-reviewed status not established (arXiv preprint; treat as preprint research)
**Track:** T4 portability, failed/uneven cross-harness transfer (limitation source)

## Verified Quote(s)

**Location:** Section 3.2 (models and harness pairing).

> Claude Code runs with all four Claude models; Gemini CLI runs with Gemini models; Codex CLI runs with GPT-5.2.

**Location:** Section 4.1.1, Finding 1.

> This variability suggests that Skills efficacy depends strongly on the specific agent-model combination

**Location:** Section 5, "Harnesses mediate Skills use".

> Skills efficacy depends not only on Skills quality but also on how the harness implements Skills.

**Location:** Section 3.3 (self-generated Skills condition).

> Gemini CLI does not support this condition.

**Location:** Section 5.1 (limitations).

> commercial harness behavior and Skills integration can change over time.

**Location:** Section 2.2 (verifiers).

> Deterministic test scripts with programmatic assertions, including numeric tolerances where appropriate.

Note: the fetch covered the first 100,000 of 158,106 characters; quotes are from that portion. The fetch tool also reported (unquoted) that Section 4.1.2 describes Codex CLI as frequently neglecting provided Skills and Claude Code as having the highest skills utilization rate.

## Key finding

The same curated skills produced different gains across Claude Code, Gemini CLI and Codex CLI, and the authors attribute part of that to how each harness implements skills rather than to skill quality; one experimental condition could not even run on Gemini CLI. This is the strongest available evidence that a skill (and by extension its tuned description) does not transfer unchanged across CLIs, and that harness behavior drifts over time, so cross-CLI results need per-harness baselines and re-runs on version change.

**Access status:** live (partial: first 100k characters read)
