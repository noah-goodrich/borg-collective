# Manifest Row: full rules

Read only when an add-row is refused or reports MANIFEST_FAILED, or before passing `--lane`. Moved verbatim from SKILL.md.

- **Resolve, never scaffold.** A `refused:` value (`no manifest declared`, `ambiguous: <stems>`, or a verb this borg does not have yet) is a no-op, not an error to work around: name the reason in one line and move on. **Creation belongs to `/borg-plan`.** Never scaffold from link-up, never hand-write a manifest, and never re-run with different arguments to get a different answer.
- **The ref comes from `gh`, never from memory.** `PR_REF` is the PR `gh` reports for the current branch. Degraded `gh`, no PR for this branch, or a detached HEAD → **no row**, one proposal line. The ref is never recalled from this session's own narrative. A session that believes it opened #204 and actually opened #205 would write a row pointing at someone else's work.
- **No stub rows.** Never write a stub row for a branch with no PR. Next session's real PR would land behind it as its child, a confident empty `ready` answer, which is worse than an unknown one.
- **Ref kinds.** Only kinds this machine can resolve; `PR_REF` is `github`. `add-row` enforces it: a kind with no resolver here is refused by name, and a `link` ref is refused because a reference is context a human attaches, not work this writer declares.
- **Lanes.** Add `--lane <lane>` only to reuse a lane already in the manifest. Reuse a lane already in the manifest, verbatim. An undeclared lane is refused. Starting a genuinely new lane requires `--new-lane`, which a typo never says. When in doubt omit `--lane`.
