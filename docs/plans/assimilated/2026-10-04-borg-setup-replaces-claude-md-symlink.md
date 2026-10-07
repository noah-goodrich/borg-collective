# Directive: borg setup replaces a symlinked ~/.claude/CLAUDE.md
*Filed: 2026-10-04*
*Shipped: 2026-10-04 — PR [#261](https://github.com/noah-goodrich/borg-collective/pull/261) merged to main (`lib/claude-md.zsh`, `tests/claude_md.bats`); closed out by the 2026-10-04 directive triage*

**tl;dr** - `borg setup` merged its block into `~/.claude/CLAUDE.md` with a tmp file and `mv`. `mv` onto a
symlink replaces the link, so the dotfiles symlink became a regular file and dotfiles edits stopped reaching it.

## Problem

dotfiles' install.sh links `~/.claude/CLAUDE.md` to `~/.config/dotfiles/claude/code/CLAUDE.md`. The old
`_borg_merge_claude_md` (and the extension append after it) wrote `$target.new.$$` and `mv`d it over the target.
Found 2026-10-04 when a dotfiles CLAUDE.md change did not appear after `borg setup`.

## Fix

- borg writes its rules (plus the machine extension CLAUDE.md) to `~/.claude/borg-managed.md`, rewritten only on change.
- `~/.claude/CLAUDE.md` carries one import line: `@~/.claude/borg-managed.md` (Claude Code memory `@path` imports).
- A symlinked CLAUDE.md is never replaced or written through; setup prints the line to add to its source, once.
- A regular-file CLAUDE.md is migrated: legacy inline BEGIN/END block and borg-extensions tail stripped, import line
  ensured, user content kept, second run is a no-op.

Code: `lib/claude-md.zsh`. Tests: `tests/claude_md.bats`.
