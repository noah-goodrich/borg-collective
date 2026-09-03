# Directive: A session-load harness — each skill registered exactly once, each hook fired exactly once

*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-09-03*

**tl;dr** — AC6 asked for a case proving "a fresh session registers each skill exactly once and fires its hooks," and
no gate it named could ever fail for it. Twenty-four unit cases already prove each registration mechanism correct in
isolation; not one of them starts a session, so the composition is unverified — and double-firing is not hypothetical,
it shipped once and its remediation is a de-dup pass verified only against a synthetic file. Build the harness that
observes a real session start, or say plainly that the claim is unowned.

## Why this was deferred rather than gated

AC6 decision (6) removed the clause from the criterion body because every gate that criterion names — `make test`
in the `python` job, `bats tests/*.bats` in `test`, shellcheck in `lint`, `make eval`, `make eval-live` — could go
green with the clause wholly unbuilt. A grep for `session-load` over `evals/`, `tests/`, the `Makefile` and
`docs/plans/directives/` returned nothing at filing time; every hit was in `PROJECT_PLAN.md` itself. A requirement no
clause can fail for is not a requirement, it is a description.

It is also the wrong **shape** for that AC. Every other case in `evals/s4-k3/run.sh` is offline and deterministic or
sits behind `make eval-live`. This one needs a real session start, real hook dispatch, and the installed skill set —
a different harness, not a case in that file. Its negative ("a skill registered twice") requires mutating an install,
which no committed artifact can express.

## Measured scope

Registration reaches a session through **three registries**, and `borg setup` writes to all three:

| surface | path | mechanism |
|---|---|---|
| Claude Code skills | `~/.claude/plugins/cache/noah-local/borg-collective/<ver>/skills/` | `build-plugin.sh` |
| Claude Code hooks | plugin-owned `hooks/hooks.json` | `build-plugin.sh`; setup **removes** literal copies |
| extension skills | `~/.claude/skills/<name>` | `borg setup` step 4b symlink |
| CoCo | `~/.snowflake/cortex/settings.json` + `cortex skill add` | `_borg_register_hook`, literal paths |

Measured on the machine of record, 2026-09-03: one version dir (`0.8.9`), 17 skills installed, 17 skills in `skills/`,
zero `borg-*` entries in `~/.claude/skills/`, and 12 hook scripts in `hooks/`.

**The double-firing failure mode already shipped.** `borg.zsh`'s step 3 exists because hook registration moved from
`settings.json` to the plugin, and the literal `~/.claude/hooks/...` entries `borg setup` used to write would
otherwise fire alongside the plugin's copies. That comment is the incident report.

**What is already covered, at the unit altitude — 31 cases, and this directive must not re-litigate them:**

- `tests/plugin_dedup.bats` — `_borg_unregister_hook` removes matching entries, leaves non-borg hooks intact,
  preserves `permissions`/`model`, no-ops when absent, survives a shared matcher block (6);
  `build-plugin.sh` idempotence, hooks.json wrapper shape, all 6 lifecycle events, version sync (15);
  `check-plugin-version.sh` drift detection (3).
- `tests/setup_skill_cleanup.bats` — the legacy-copy sweep, marker discipline, the never-adopt rule, and no-op
  on an already-clean directory (7).

**What no existing case can see.** Every one of those calls a function or a script directly. None starts a session. So
the composition is unverified, and these four surfaces are invisible to all of them:

1. **Two versioned plugin cache dirs.** An upgrade leaving `0.8.8` beside `0.8.9` registers every skill twice. Nothing
   counts version dirs.
2. **A plugin skill and an extension symlink of the same name.** Step 4b symlinks unconditionally into
   `$CLAUDE_SKILLS_DIR`; a name collision with a plugin skill is two registrations of one skill.
3. **Claude Code and CoCo both firing one logical event.** The plugin owns Claude Code's hooks; CoCo still gets
   literal-path registration. One `SessionStart` on a machine running both is two `borg-link-down.sh` executions
   against one registry.
4. **The de-dup pass is verified against a synthetic `settings.json`, never against the real post-`borg setup` state.**
   The six `_borg_unregister_hook` cases construct their own fixture. That proves the function; it does not prove the
   invocation list in step 3 names every literal path `borg setup` ever wrote.

## The change

Build `evals/session-load/run.sh` — a harness, not a bats file, because its inputs are an installed state rather than
a repository, and it must be able to SKIP with a named reason on a machine that has neither CLI.

1. **Observe, do not simulate.** Start a real headless session (`claude -p` with a trivial prompt, and `cortex` where
   present), and read what the session reports rather than re-deriving it from the filesystem. A harness that greps
   install paths is testing `borg setup`'s output, which the 31 unit cases already do; the claim under test is what a
   *session* sees.
2. **Count, then compare against an authored number.** Each borg skill appears exactly once; each lifecycle hook fires
   exactly once per event. Report the shortfall or surplus BY NAME, in the vocabulary
   `evals/s4-k3/run.sh` already uses (`selected N of M authored`).
3. **Arm an execution floor, both modes.** Per AC6 decision (3): a run that selected or executed zero cases is a
   FAILURE. This harness is picked up by the `evals/*/run.sh` glob, so `make eval`'s selection floor already covers its
   existence; it owns its own global and per-mode floors. Skills-only and hooks-only are separate modes, because a
   machine may have Claude Code and not Cortex.
4. **Give every floor an oracle, in both directions.** `tests/session_load_floor.bats`, on the `bats tests/*.bats` leg
   the `test` job already runs. No sixth CI job — AC6 decision (1). Each floor fires on a planted duplicate and holds
   on the clean install. The negatives are the point: plant a second version dir, plant a colliding extension symlink,
   plant a literal-path hook entry, and confirm each turns the harness red.
5. **Do not add a `skip` that yields to a missing dependency.** Per decision (5)'s repair: a premise the harness needs
   and cannot find is `premise broken: <what> -- <how to fix>` at non-zero rc, not a green `ok`.

## Acceptance criteria

- [ ] **SL1 — The harness observes a real session.** `evals/session-load/run.sh` starts a headless session and reports
      the skill set and fired hooks that session saw. Verify: the harness names its interpreter/CLI resolution the way
      E2a does (`BORG_EVAL_PYTHON`-style override, then a repo-local default, then bare), and SKIPs only when the
      RESOLVED CLI is absent, naming it.
- [ ] **SL2 — Exactly-once is asserted with an authored number and a named shortfall.** Verify: forcing a duplicate
      (planted second version dir) turns the harness red with both counts in the message; the clean install exits 0.
- [ ] **SL3 — All four invisible surfaces above are covered, each in both directions.** Verify:
      `tests/session_load_floor.bats` has a case per surface per direction, and deleting any floor from `run.sh` turns
      that file red. Run the mutation; a floor whose absence keeps every gate green is not a floor.
- [ ] **SL4 — Nothing regresses the 24 existing cases.** Verify: `bats tests/plugin_dedup.bats
      tests/setup_skill_cleanup.bats` green, unchanged. This directive adds an altitude; it does not rewrite the
      unit layer.
- [ ] **SL5 — The CoCo double-fire is decided, not discovered.** Verify: either the harness asserts one execution per
      logical event across both CLIs, or this directive records the deliberate decision that CoCo fires independently
      and says why. An unowned answer here is the defect, not the double-fire.

## Risks

- **The harness needs a model to start a session, so it cannot be a CI gate.** It belongs behind `make eval-live`,
  which means its only forcing function is the Ship Definition's one required run — the exact weakness AC6's mode
  floors were added to fix. Mitigation: the *floors* are oracled by `tests/session_load_floor.bats` on the `test` leg,
  which needs no model. The harness's correctness is gated in CI even though its execution is not.
- **Install state is machine-specific, and the machine of record is one sample.** A clean 0.8.9 install proves nothing
  about the upgrade path that produces two version dirs. Mitigation: plant the duplicate rather than wait for it — SL3
  requires the negative to be synthetic and committed.
- **Mutating an install to test it can leave the machine broken.** The negatives plant duplicates in real registry
  paths. Mitigation: every case operates on a redirected `HOME`/`XDG_CONFIG_HOME` sandbox, per the harness convention
  in `tests/test_helper/setup.bash` — and per that file's own lesson, redirect BOTH, and export the `GIT_*` identity
  vars rather than writing a `.gitconfig`.

## Notes

- **The vocabulary is deliberate.** "Registers exactly once" is a claim about what a session SEES, not about what
  `borg setup` WRITES. The 24 existing cases own the write side completely. Conflating the two is how this clause sat
  in a criterion body for weeks looking covered.
- **This is the third instance of one defect class in this plan**, after the eval floors and their inert oracle: a
  guard whose own absence is indistinguishable from success. The tell is always the same — delete the guard and every
  gate stays green. SL3 requires running that mutation rather than asserting it.
- `CLAUDE.md` says "Skills (16)"; the tree has 17. Not this directive's scope, noted so the next reader does not
  re-measure it.
