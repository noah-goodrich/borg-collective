# Future Project: Plugin Audit Tooling
*Created: 2026-04-01*

## Problem

Claude Code plugins can contain two types of content with very different security profiles:

- **Skills** (SKILL.md files): Pure text instructions for Claude. Safe by construction — gated
  by the user's permission allowlist and bash-guard.sh hook.
- **Hooks** (shell scripts): Executable code that runs directly in the Claude Code harness,
  bypassing the permission allowlist entirely. A malicious hook can exfiltrate data, modify
  settings, or execute arbitrary commands.

There is no signing, sandboxing, or curation in Claude Code's plugin system. Anthropic's own
marketplace warning: "Make sure you trust a plugin before installing. Anthropic does not control
what MCP servers, files, or other software are included in plugins."

## Proposed Solution

A CLI tool (standalone or borg subcommand) that audits a plugin repository before installation:

```bash
audit-plugin <github-repo>
```

**What it does:**
1. Clones the repo to /tmp (shallow, ephemeral)
2. Scans for hooks/, mcp-servers/, and any .sh/.py/.js files outside skills/
3. If executable files found: lists them with a summary of what they do
4. Reports verdict: "Skills-only: safe to install" or "Contains executable code — review
   these files before installing: [list]"
5. Cleans up the clone

**Stretch goals:**
- Static analysis of hook scripts (flag network calls, file access patterns)
- Diff against a known-good baseline (detect supply chain changes)
- Integration with `borg setup` recommended plugins output
- Support for both Claude Code and Cortex Code plugins

## Analogues

- `npm audit` — checks for known vulnerabilities in dependencies
- `pip-audit` — same for Python packages
- `brew audit` — validates Homebrew formula correctness
- GitHub Dependabot — automated dependency security alerts

## Why This Is a Separate Project

- Scope is broader than borg-collective (applies to all Claude Code users)
- Could be a community contribution to the Claude Code ecosystem
- Requires its own test suite, CI, and possibly its own Homebrew formula
- May evolve into a plugin marketplace curation tool

## Implementation Notes

- ~50-100 lines of bash/zsh for the basic version
- Uses `git clone --depth 1` for minimal bandwidth
- `find` + `file` commands to detect executables
- Could parse plugin.json manifests for declared hooks
- Should handle both GitHub URLs and local directory paths

## Open Questions

- Should this block installation or just warn?
- Should it verify against a community allowlist of trusted plugins?
- How to handle plugins that legitimately need hooks (e.g., formatting hooks)?
- Should it integrate with private package manager repositories?
