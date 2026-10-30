# A Single Rewrite Suffices: Empirical Lessons from Production Skill Description Optimization

- Citation: Yangqiaoyu Zhou, Mohammad Alqudah, Kwei-Herng Lai, Aaron Halfaker, Yingqi Xiong, Yaar Harari, "A Single Rewrite Suffices: Empirical Lessons from Production Skill Description Optimization", arXiv:2606.30775, submitted 29 June 2026.
- URLs: https://arxiv.org/abs/2606.30775 and https://arxiv.org/html/2606.30775
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed status unknown (arXiv preprint; production deployment data plus ToolBench ablation)
- Access status: live

## Verified Quote(s)

Abstract:

> The pipeline produces descriptions averaging 79.2% F1, matching manually tuned descriptions at 79.4% F1

> a single LLM rewrite using any available false-positive and false-negative cases captures most of the available improvement.

> We identify a diagnostic (a large train-validation F1 gap)

Section 5.2 (iteration budget, HTML):

> Iterative refinement with sampled feedback adds little when single-shot has access to the full training signal.

Section 5.4 / Appendix I (train-validation gap, HTML):

> Description text alone cannot disambiguate skills whose intended scopes overlap

Section 4 (training data, HTML):

> range from 10 to 119 per skill depending on skill scope

## Key finding

On 9 production routing skills (372 test cases, 3 seeds, per-skill noise floor about ±0.78% F1) and a ToolBench ablation, one LLM rewrite fed the false-positive and false-negative routing errors matched hand-tuned descriptions; iteration budget and feedback design each moved F1 by under 0.5%. When train gains do not show up on validation, the cause was overlapping skill scopes, and the fix was in the architecture, not more rewording. Some skills (Calendar, StatusReport, IntKnowledge) still scored below the human baseline.
