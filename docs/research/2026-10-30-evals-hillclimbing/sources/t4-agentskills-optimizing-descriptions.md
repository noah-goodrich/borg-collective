# Source: Agent Skills, "Optimizing skill descriptions"

**Full citation:** Agent Skills project. "Optimizing skill descriptions." agentskills.io, Skill creation guides. No date shown.
**URL:** https://agentskills.io/skill-creation/optimizing-descriptions
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation (open-standard guide)
**Track:** T4 portability, description hillclimbing and overfitting

## Verified Quote(s)

**Location:** heading "Testing whether a description triggers", first paragraph.

> Make sure the skill is registered and discoverable by your agent — how this works varies by client (e.g., a skills directory, a configuration file, or a CLI flag).

**Location:** heading "Running multiple times", first paragraph.

> Model behavior is nondeterministic — the same query might trigger the skill on one run but not the next.

**Location:** heading "Running multiple times", shell example comment lines.

> # Replace this function with detection logic for your agent client.

**Location:** heading "Avoiding overfitting with train/validation splits", first paragraph.

> If you optimize the description against all your queries, you risk overfitting — crafting a description that works for these specific phrasings but fails on new ones.

**Location:** heading "The optimization loop", step 3 bullet.

> Avoid adding specific keywords from failed queries — that's overfitting.

**Location:** heading "How skill triggering works", last paragraph.

> A simple, one-step request like "read this PDF" may not trigger a PDF skill even if the description matches perfectly, because the agent can handle it with basic tools.

**Location:** heading "Applying the result", "After" YAML example (uses a folded scalar).

> description: >

## Key finding

The vendor-neutral guide defines the description hillclimb as about 20 labeled should/should-not-trigger queries, 3 runs each, a trigger-rate threshold, a fixed 60/40 train/validation split and best-iteration selection by validation score, and it states that trigger detection is client-specific. Its own worked example uses a folded `description: >`, which our measurements show the Cortex agent parser rejects, a concrete case where following the standard's guidance breaks on one CLI.

**Access status:** live
