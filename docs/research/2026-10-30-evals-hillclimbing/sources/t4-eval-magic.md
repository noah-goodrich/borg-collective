# Source: eval-magic crate documentation (docs.rs)

**Full citation:** eval-magic. Crate README on docs.rs, versions 0.6.1 (released 2026-07-27) and 0.11.1 (dated 2026-10-07).
**URL:** https://docs.rs/crate/eval-magic/0.6.1
**URL (latest):** https://docs.rs/crate/eval-magic/latest
**Date accessed:** 2026-10-30
**Evidence level:** practitioner (open-source tool documentation)
**Track:** T4 portability, multi-CLI skill eval runners and harness descriptors

## Verified Quote(s)

**Location:** 0.6.1 README, intro line.

> One-stop CLI for running skill evals.

**Location:** 0.6.1 README, harness section.

> a harness eval-magic has never seen is added with a TOML descriptor file — no code.

**Location:** latest (0.11.1) README, intro.

> It drives Claude Code, Cline, Codex, OpenCode, or a descriptor-backed harness of your own.

**Location:** latest README, harness section.

> Most harness features are declared in TOML descriptors.

**Location:** latest README, `eval-magic docs isolation` description.

> live or installed skill sources can contaminate a comparison

**Location:** 0.6.1 README, limitations.

> This version has no command timeout—a hung command remains operator-interruptible.

## Key finding

eval-magic is the closest existing design to borg's need: cases in `evals/evals.json` beside SKILL.md, a with-skill versus without-skill (or old versus new) A/B per case, four assertion kinds (transcript check, command check, diff scope, LLM judge), and new CLIs added by a declarative TOML descriptor rather than code. Its documented failure cause is contamination from skills already installed on the host, which it can only warn about, and its token totals are workload metrics rather than billing; Cortex Code is not a supported harness.

**Access status:** live
