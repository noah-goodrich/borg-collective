# Source: CodeTalker GitHub releases (cross-harness transcript normalizer)

**Full citation:** Ickleslimer. "codetalker" Releases page, GitHub. Release v0.3.9 (28 Sep, 2026 per page context) and earlier.
**URL:** https://github.com/Ickleslimer/codetalker/releases
**Date accessed:** 2026-10-30
**Evidence level:** community (single-maintainer open-source project)
**Track:** T4 portability, limitation of cross-CLI transcript normalization

## Verified Quote(s)

**Location:** v0.3.9 release notes, Tip section (sentence split across three quoted fragments as returned).

> The adapters for Claude Code CLI, Aider, and GitHub Copilot Chat

> have complete normalization logic verified by unit test fixtures,

> but have not been live-tested against active local installations on this machine.

**Location:** support table, Codex CLI row, notes column.

> Tested across 480+ local CLI sessions with trailing timestamps and DAG resolution.

## Key finding

A project whose whole purpose is cross-harness transcript normalization ships its Claude Code adapter as fixture-tested only, with an explicit YMMV, while its Codex adapter was validated against hundreds of real sessions. This is a concrete portability limitation: normalizers built from specs and fixtures, rather than recorded live sessions, are unverified, which supports recording real Cortex and Claude sessions as the fixture source.

**Access status:** live (partial: first 100k of 101,762 characters read)
