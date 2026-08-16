# Directive: Deployed-Artifact Drift Check

*Filed: 2026-08-14*

Independent finding from the `borg link` Python port. Not a child of any in-flight plan — a generalizable gap
in the project's own test coverage.

## Why this exists

Nothing in this repo verifies that what `borg setup` copies out to `~/.claude/` (and the published plugin)
matches the repo source it was copied from. Both existing pinning tests read repo source only:
`tests/skill_borg_link.bats:17` and `tests/bash_guard.bats:654`. Neither one opens the deployed copy.

This is not hypothetical. During the `borg link` port a criterion was verified against the deployed skill,
ticked as done, and invalidated 40 minutes later when [#139](https://github.com/noah-goodrich/borg-collective/pull/139)
edited the repo artifact that had already been "verified" — the deployed copy silently went stale between the
check and the merge, and nothing caught it. The failure shape is generic: any of `borg setup`'s copy targets
can drift from repo source the same way, for the same reason (a check ran once, source moved after).

## Objective

Add a doctor-style check — location and invocation surface (`borg doctor` subcommand, a standalone script,
etc.) is an implementation decision for the directive's own execution, not fixed here — that compares each of
four deployed-artifact targets against its repo source and reports drift. Strictly **one-way**: repo → deployed
only. A target present on disk but absent from the repo's copy manifest is not drift; it is normal and must
not be flagged.

## Scope — four targets (counts verified live in this worktree, 2026-08-14)

| Target | Repo source | Deployed destination | Count | Copied by |
|---|---|---|---|---|
| Skills | `skills/*/` | `~/.claude/skills/*/` | **17** (CLAUDE.md's own file list says 16 — it omits `pane`) | `borg.zsh` (skills install block) |
| Hooks | `hooks/*.sh` | `~/.claude/hooks/*.sh` | **12** | `borg.zsh` around :1618-1623 |
| Agents | `agents/*.md` | `~/.claude/agents/*.md` | **6** | `borg.zsh` around :1798-1805 |
| Shared hook lib | `lib/*.sh` | `~/.claude/lib/*.sh` | **2** (`borg-hooks.sh`, `reaper.sh`) | `borg.zsh` around :1621-1622 |

The shared-lib row is the highest-value target in this set: `lib/borg-hooks.sh` is sourced at runtime by every
installed hook (`borg-hooks.sh:doc` — shared bash helpers), so a stale deployed copy silently breaks every hook
that calls into it, not just one.

## Constraints

- **One-way only (repo → deployed).** A symmetric compare was tried by hand while filing this directive and
  finds four deployed-only hooks the repo never installed (`notify-focus.sh`, `post-tool-format.sh`,
  `pre-compact.py`, `session-log.sh`). Flagging those as drift would make the check cry wolf on day one.
  `borg.zsh` itself already carries the lesson that a health check which cries wolf gets ignored — do not
  reproduce that failure mode here.
- **Reuse `scripts/build-plugin.sh --dry-run` for the plugin leg.** It already diffs each repo `SKILL.md`
  against the plugin copy (`build-plugin.sh:141-151`, `diff -q "$src_skill" "$dst_skill"`, gated behind
  `DRY_RUN`). Do not reimplement that comparison for the plugin distribution path — shell out to or reuse the
  existing script.
- **Derive the plugin path the way `build-plugin.sh` does** (`PLUGIN_DIR_OVERRIDE` else
  `${_MARKETPLACE_ROOT}/borg-collective`, `build-plugin.sh:40-44`). Never hardcode an absolute
  `/Users/noah/...` path into a doctor check — this must work on any machine that runs `borg setup`.
- **The ignore-list needs the owner's one-time ratification before this check can be trusted.** Deployed-only
  files are the normal case (manual installs, machine-local hooks, in-progress work not yet promoted to the
  repo). The check's first real output should be reviewed by hand once to seed an ignore-list, not auto-treated
  as clean.

## Acceptance Criteria

- [ ] **AC1** — The check compares all 17 skill directories' file contents (repo → deployed), reporting any
      repo file whose deployed counterpart differs in content or is missing.
  - Verify: intentionally edit one file in a deployed skill copy (not the repo), run the check, confirm it is
    reported; revert the edit, run again, confirm clean.
- [ ] **AC2** — The check compares all 12 `hooks/*.sh` files (repo → deployed) the same way.
  - Verify: same drift-and-revert test against a deployed hook file.
- [ ] **AC3** — The check compares all 6 `agents/*.md` files (repo → deployed) the same way.
  - Verify: same drift-and-revert test against a deployed agent file.
- [ ] **AC4** — The check compares the 2 `lib/*.sh` files (repo → deployed) the same way, and the PR
      description calls out `lib/borg-hooks.sh` explicitly as the highest-value target.
  - Verify: same drift-and-revert test against the deployed `lib/borg-hooks.sh`.
- [ ] **AC5** — The plugin distribution leg calls `scripts/build-plugin.sh --dry-run` (or an equivalent
      programmatic entry point into the same diff logic) rather than reimplementing the skill diff.
  - Verify: `grep` the new check's source for a call into `build-plugin.sh`; confirm no duplicate `diff`-based
    skill comparison was written from scratch.
- [ ] **AC6** — Deployed-only files (skills' `.borg-managed` markers, `ducky`, the four deployed-only hooks
      named above) are never reported as drift.
  - Verify: run the check against the current live `~/.claude/` state; confirm none of the six known
    deployed-only artifacts appear in its output.
- [ ] **AC7** — Regression: the check is read-only — it must not write to `~/.claude/` or the repo.
  - Verify: `git status` in the repo and a directory-mtime check on `~/.claude/skills`, `~/.claude/hooks`,
    `~/.claude/agents`, `~/.claude/lib` are unchanged before/after a run.

## Scope Boundaries

- NOT implementing the check in this directive — this filing records the finding and scopes the fix; a
  separate execution session builds it.
- NOT a symmetric (deployed → repo) drift check — see Constraints above for why that's explicitly out of scope,
  not just deferred.
- NOT auto-remediating drift (no auto-copy-back). The check reports; a human or a separate `borg setup --sync`
  style command fixes.
- NOT expanding to cover every file `borg setup` touches (e.g. `settings.json` patches, launchd plists) — the
  four targets above are the ones with a clean repo-source/deployed-destination shape. Others can be filed as
  their own follow-ups if this pattern proves useful.
- If done early: seed the ignore-list from a real run and get the owner's ratification, rather than expanding
  to more targets.

## Ship Definition

PR against `main`. New check committed with a test exercising AC1-AC7's drift-and-revert cases. Owner has
reviewed one real run's output and ratified (or corrected) the deployed-only ignore-list before this ships as
something other people rely on.

## Timeline

Small-to-medium — one focused session for the four-target comparison; the plugin leg is a thin wrapper around
existing `build-plugin.sh --dry-run` logic, not new diff machinery.

## Risks

- **Crying wolf kills adoption.** The one-way-only and deployed-only-ignore-list constraints exist specifically
  to prevent this. If the first real run produces noise, fix the ignore-list before shipping, not after.
- **The four counts above will drift the moment someone adds or removes a skill/hook/agent/lib file.** The
  check itself must read the counts live (`ls`/glob at run time), never hardcode "17 skills" as a literal
  assertion — the table in this directive is a point-in-time record for scoping, not a spec to enforce.
- **`lib/*.sh` is deliberately narrow (2 files today).** Do not widen the glob to `lib/**/*.sh` (which would
  pull in `lib/recon/adapters/`) without checking whether `borg setup`'s own copy loop does the same — a
  mismatch there would make the check compare things `borg setup` never actually installs.
