# Source: Vaughan, "The Agent Skills Open Standard: Writing Portable SKILL.md Files That Work Across Codex CLI, Claude Code, and 30+ Tools"

**Full citation:** Daniel Vaughan. "The Agent Skills Open Standard: Writing Portable SKILL.md Files That Work Across Codex CLI, Claude Code, and 30+ Tools." codex.danielvaughan.com, May 5, 2026 (page shows an update dated October 28, 2026).
**URL:** https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/
**Date accessed:** 2026-10-30
**Evidence level:** practitioner
**Track:** T4 portability, what is and is not portable in SKILL.md

## Verified Quote(s)

**Location:** section on agent-specific extensions.

> you gain power at the cost of portability

> tools that do not understand them simply ignore them

**Location:** section on the standard's maturity.

> The specification is stable but still evolving.

> implementation differences still surface occasionally

**Location:** Codex discovery section.

> scans four locations for skills, in priority order

## Key finding

The practitioner view is that the SKILL.md core is portable but vendor extensions (Claude Code's `context: fork`, `disable-model-invocation`, Codex's `agents/openai.yaml`) are silently ignored elsewhere, and discovery directories differ by tool. Silent ignoring is the key eval hazard: a case that passes on Claude Code because of an extension field can fail on Cortex with no error.

**Access status:** live
