# Handoff — PROJECT_PLAN.md likely stale (Skill Extension Protocol shipped)

**Created:** 2026-05-27
**For:** borg + Claude Code CLI continuation
**Parent plan:** `PROJECT_PLAN.md` ("Skill Extension Protocol", established 2026-05-04)

## Current state

`PROJECT_PLAN.md` describes the "Skill Extension Protocol" initiative: add three markdown
extension load points to `borg-plan` and `borg-assimilate` that read from
`~/.config/borg/extensions/skill-extensions/<skill>/<hook>.md` (machine) and
`<project>/.borg/skill-extensions/<skill>/<hook>.md` (project), with the project file layered
after the machine file. Six acceptance criteria, all verifiable.

Cross-checking the criteria against current main + the research branch:

| Criterion                                            | Status                              |
| ---------------------------------------------------- | ----------------------------------- |
| `borg-plan` reads extensions at three load points    | Shipped — `skills/borg-plan/SKILL.md` references `skill-extensions` 6 times |
| `borg-assimilate` reads extensions at three load points | Shipped — `skills/borg-assimilate/SKILL.md` references `skill-extensions` 6 times |
| Layering (machine then project)                      | Shipped — documented in CLAUDE.md "Skill extensions" subsection |
| One real JIRA extension exists as proof              | Unknown — lives in Noah's private dotfiles or work machine; can't verify from this repo |
| Regression: no-extension behavior identical          | Unknown — needs Noah to run the regression check |
| CLAUDE.md documents the protocol                     | Shipped — "Skill extensions (v1, may evolve)" bullet under Key Patterns |

Four of six criteria visibly satisfied in the repo. The remaining two (JIRA extension, regression
check) require artifacts outside this repo or a fresh Claude session to verify — neither blocking
the call that the plan is effectively shipped.

The plan also describes a release step (`brew upgrade borg-collective`, `release: v0.7.12`).
No release tag matching `v0.7.12` or "skill extension protocol" appears in `git log` on main,
so the formal Ship Definition wasn't completed even though the implementation work was.

## What's blocked

- No active development work is blocked. The protocol is in use (CLAUDE.md treats it as a
  shipped pattern; downstream consumers like `borg-plan`/`borg-assimilate` already check the
  load points).
- The plan's continued presence at `PROJECT_PLAN.md` makes `borg-plan` and `borg-assimilate`
  behave as if there's an active initiative. Either the plan should move to
  `docs/plans/assimilated/` (with a brief completion note covering the JIRA verification gap)
  or be rewritten for the next scoped initiative.

## Next action

Noah picks one of:

1. **Assimilate as-is.** Run the JIRA verification + regression check on the work machine.
   If both pass, `git mv PROJECT_PLAN.md docs/plans/assimilated/2026-05-04-skill-extension-protocol.md`,
   add a one-paragraph completion note at the top covering the ship outcome, and tag
   `v0.7.12` retroactively if the version-tag step still matters.
2. **Assimilate with a deferred-criteria note.** Same `git mv`, but the completion note flags
   the JIRA extension as "shipped on private dotfiles, not verifiable from this repo" and the
   regression check as "deferred — protocol confirmed safe via downstream usage instead." No
   retroactive tag.
3. **Rewrite for the next initiative.** Replace `PROJECT_PLAN.md` contents with a new plan
   scoped to whatever's next (candidates: nanoprobe-fleet observability tooling, the
   borg-collective ↔ claude-plugins source-of-truth decision once that's made, or the
   knowledge-graph backend confirmation against cairn Phase 1).

This handoff doc explicitly does NOT edit `PROJECT_PLAN.md` — that's Noah's call.

## Open questions

- Did the JIRA extension actually get written on the work machine, or did it get deferred?
- Is the `release: v0.7.12` tag still meaningful, given that there's no formal versioning
  cadence on this repo and the protocol is already in use?
- Should the assimilated copy live under `docs/plans/assimilated/2026-05-04-...` (filing by
  established date) or `docs/plans/assimilated/2026-05-27-...` (filing by ship date)? The
  existing assimilated entries use the established date — keep that.
