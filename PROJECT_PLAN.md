# Project Plan: Skill Extension Protocol
*Established: 2026-05-04*

## Objective

Add a lightweight prompt-level protocol that lets `borg-plan` and `borg-assimilate` absorb
context-specific behavior (e.g. JIRA on the work machine, Linear in some repos) by reading
markdown files dropped at well-known per-machine and per-project paths. Same canonical entry
points everywhere; behavior bends to local context via dropped files. Validate the protocol
by writing one real JIRA extension as proof the load points are usable.

## Acceptance Criteria

- [ ] **`borg-plan` reads extensions at three load points.** Three injection blocks added to
      `skills/borg-plan/SKILL.md`: at the start (after preamble, before Collective Review),
      before writing `PROJECT_PLAN.md`, and after writing it. Each reads
      `~/.config/borg/extensions/skill-extensions/borg-plan/<hook>.md` then
      `<project>/.borg/skill-extensions/borg-plan/<hook>.md` and silently skips if absent.
  - Verify: drop a test file at
    `~/.config/borg/extensions/skill-extensions/borg-plan/01-context.md` saying "Open with:
    'extension fired'", run `/borg-plan` in a scratch project, confirm the string appears before
    the Collective Review.

- [ ] **`borg-assimilate` reads extensions at three load points.** Same three-block pattern,
      mapped to assimilate's phases: before Step 0 (`/simplify`), at the start of Step 4b before
      the merge, and after the merge succeeds before plan archival.
  - Verify: drop a test file at
    `~/.config/borg/extensions/skill-extensions/borg-assimilate/01-context.md`, run
    `/borg-assimilate` on a project with an existing `PROJECT_PLAN.md`, confirm the file is read
    before Step 0.

- [ ] **Layering works: project file is read after machine file.** With both files present, both
      contents are injected, project content appears second so it can extend or override.
  - Verify: drop machine and project files for `borg-plan/01-context.md`, run `/borg-plan` in
    `borg-collective` itself, confirm both messages appear in the right order.

- [ ] **One real JIRA extension exists as proof of fitness.** A working
      `borg-plan/01-context.md` extension file (lives in Noah's private dotfiles or work-machine
      path, NOT in this repo) that pulls a JIRA ticket and uses its description as the plan
      source. Treat as the validation target, not a doc example.
  - Verify: Noah confirms the extension is written and sits on the work machine; running
    `/borg-plan JIRA-1234` (or similar) in a real work repo opens the conversation with the
    ticket description loaded.

- [ ] **Regression: no-extension behavior is identical to today.** `/borg-plan` and
      `/borg-assimilate` in a clean project with no extension files installed produce the same
      output, ask the same questions, and write the same artifacts as before this change.
  - Verify: run `/borg-plan` in a clean scratch project with
    `~/.config/borg/extensions/skill-extensions/` absent. Confirm no mention of
    skill-extensions paths, no error about missing files, identical PROJECT_PLAN.md shape to a
    pre-change baseline. Repeat for `/borg-assimilate`.

- [ ] **CLAUDE.md documents the protocol.** New "Skill extensions" subsection under Key Patterns:
      the two paths, three hook points, layering rule, markdown-only constraint, terse-files
      note, and one short JIRA worked example. ≤30 lines.
  - Verify: read the new section. A fresh reader can write a working extension from it without
    asking questions.

## Scope Boundaries

- **NOT building:** executable script extensions (only markdown in v1). Pattern to copy when
  needed: `.devcontainer/borg-hooks/`.
- **NOT building:** a `borg extend` CLI scaffolder. Add when creating extensions becomes a
  frequent ritual.
- **NOT building:** multi-file composition per hook (`*.md` glob). One file per hook in v1; merge
  manually if multiple integrations land on one machine.
- **NOT building:** hooks for `borg-review`, `borg-link`, `borg-next`, etc. Add per skill when a
  real use case appears, using these two as templates.
- **NOT building:** a standalone `docs/skill-extensions.md` reference page. Fold the worked
  example into the CLAUDE.md subsection; promote to its own doc when there are 2+ extensions to
  document.
- **If done early:** ship, don't expand. The deferred items above are well-understood; resist the
  urge to grab one.

## Ship Definition

CI/CD project pattern:
1. Branch with all edits committed
2. PR opened to main, CI passes
3. PR merged
4. Tag a release: `release: v0.7.12 — skill extension protocol`
5. `brew upgrade borg-collective` on the work machine, drop the JIRA extension file in place,
   confirm acceptance criterion #4

## Timeline

Target: this session.
Estimated effort: ~1 hour. Five edits, no code, mostly prompt threading. The longest task is the
regression check (running both skills clean and comparing output).

## Risks

- **Threading new instructions through SKILL.md without breaking the Collective Review flow.**
  Both skills have a specific call sequence (preamble → Collective Review → conversation →
  output). Inserting load-point blocks in the wrong place could re-order the Collective Review
  or cause Claude to skip phases. Mitigation: keep insertions tightly scoped, run the regression
  check before merging.
- **Vocabulary collision risk with Claude Code's existing `hooks` (SessionStart, etc.) and
  `~/.config/borg/extensions/hooks/`.** Picking `skill-extensions/` (vs. the original draft's
  `skill-hooks/`) avoids both. Mitigation: locked in now while there are zero extensions in the
  wild.
- **Premature taxonomy.** Three hook names with one real use case is a small sample. Names may
  churn in v2 once a second integration shows what's actually needed. Mitigation: don't promise
  stability in CLAUDE.md; mark the protocol "v1, may evolve."
