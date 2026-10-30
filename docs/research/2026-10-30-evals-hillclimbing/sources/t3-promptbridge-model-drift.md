# PromptBridge: Cross-Model Prompt Transfer for Large Language Models

- Citation: Yaxuan Wang, Quan Liu, Zhenting Wang, Zichao Li, Wei Wei, Yang Liu, Yujia Bao, "PromptBridge: Cross-Model Prompt Transfer for Large Language Models", arXiv:2512.01420, submitted 1 Dec 2025.
- URL: https://arxiv.org/abs/2512.01420
- Date accessed: 2026-10-30
- Evidence level: peer-reviewed status unknown (arXiv preprint)
- Access status: live

## Verified Quote(s)

Abstract:

> We term this phenomenon Model Drifting.

> reusing a prompt engineered for one model on another often yields substantially worse performance

## Key finding

Prompts optimized for one model often do worse on another model than a prompt tuned for that target, and the authors report this "model drifting" is common and can be severe across many LLM pairings. For borg, a description hillclimbed against Claude may not hold on Cortex Code's model, so each runtime needs its own eval run.
