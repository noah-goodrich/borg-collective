# Source: Anthropic, "Skill authoring best practices"

**Full citation:** Anthropic. "Skill authoring best practices." Claude Platform Docs, Agents and tools > Agent Skills. No date shown.
**URL:** https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, model dependence of skills

## Verified Quote(s)

**Location:** heading "Test with all models you plan to use".

> Skills act as additions to models, so effectiveness depends on the underlying model. Test your Skill with all the models you plan to use it with.

> What works perfectly for Opus might need more detail for Haiku.

**Location:** heading "Writing effective descriptions", warning box.

> **Always write in third person**. The description is injected into the system prompt, and inconsistent point-of-view can cause discovery problems.

**Location:** heading "Build evaluations first", note box.

> There is not currently a built-in way to run these evaluations.

## Key finding

Anthropic's own guidance says skill effectiveness is model-dependent and must be tested per model, even within one vendor's family. Since Cortex Code may route to Claude, GPT, Gemini or Grok models, a description hillclimbed on Claude Code's model is not established to transfer and must be re-validated on each CLI and model pair.

**Access status:** live
