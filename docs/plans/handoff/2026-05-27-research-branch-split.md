# Handoff — Split project-state edits off the research branch

**Created:** 2026-05-27
**For:** borg + Claude Code CLI continuation
**Parent plan:** none (branch hygiene)

## Current state

The `research/agent-teams-2026-05-23` branch has five tracked-file modifications that are
cross-cutting project-state concerns, NOT part of the agent-teams research work:

```
M .gitignore
M CLAUDE.md
M README.md
M borg.zsh
M docs/architecture.md
```

These were stashed during the 2026-05-27 borg-state-cleanup session so the
`chore/borg-state-2026-05-27` branch could be cut cleanly off `main`. Stash reference:

```
borg-state-2026-05-27-temp-stash  (on research/agent-teams-2026-05-23)
```

The stash holds tracked-file modifications only — `.gitignore`, `CLAUDE.md`, `README.md`,
`borg.zsh`, `docs/architecture.md`. Untracked files (`.claude/`, `docs/research/borg-next-level-review.md`,
`hooks/borg-plan-promote.sh`, `tests/plan_promote.bats`, the positioning-refresh research dir,
the supabase template dir) were NOT stashed and remain in the worktree.

## What's blocked

- Can't merge the agent-teams research branch cleanly while project-state edits are sitting on
  it — a reviewer reading the diff would see borg.zsh + CLAUDE.md changes in a "research" PR
  and ask the same question this handoff doc answers.
- The `borg-plan-promote.sh` hook + bats test are documented in CLAUDE.md as a shipped pattern
  but aren't committed anywhere — they need to land before CLAUDE.md is accurate.
- `.claude/` is untracked and probably shouldn't be tracked at all — the `.gitignore`
  modification in the stash likely addresses this; verify before committing.

## Next action

Run these commands (DO NOT execute from this session — Noah's call, manual):

```sh
cd ~/dev/borg-collective

# 1. Get back onto the research branch where the stash was created.
git checkout research/agent-teams-2026-05-23

# 2. Cut a fresh branch off main for the project-state edits.
git checkout -b chore/project-state-2026-05-27 origin/main

# 3. Pop the stash onto the new branch.
git stash pop stash@{0}    # adjust index if other stashes were added in between
                            # OR: git stash pop "$(git stash list | grep borg-state-2026-05-27-temp-stash | head -1 | cut -d: -f1)"

# 4. Review each diff before staging — these accumulated across multiple sessions.
git diff -- .gitignore
git diff -- CLAUDE.md
git diff -- README.md
git diff -- borg.zsh
git diff -- docs/architecture.md

# 5. Optionally: run /simplify on borg.zsh and docs/architecture.md before staging,
#    since the 2026-05-26-2203 placeholder checkpoint flagged them as cruft-prone.

# 6. Stage and commit (split into multiple commits if the changes are unrelated).
git add .gitignore CLAUDE.md README.md borg.zsh docs/architecture.md
git commit -m "chore: project-state edits from 2026-05-23..05-26 sessions"

# 7. Push and open PR off main.
git push -u origin chore/project-state-2026-05-27
gh pr create --base main --title "Project-state edits — 2026-05-27" \
  --body "Cross-cutting tweaks split off research/agent-teams-2026-05-23. See
docs/plans/handoff/2026-05-27-research-branch-split.md for context."
```

Separately decide what to do with the untracked items:

- `hooks/borg-plan-promote.sh` + `tests/plan_promote.bats` — likely belong in the same
  project-state PR (CLAUDE.md already documents them as shipped).
- `.claude/` — should be in `.gitignore`, not committed. Verify the stashed `.gitignore`
  diff covers this; if not, add a line.
- `docs/research/borg-next-level-review.md` and `docs/research/2026-05-22-positioning-refresh/`
  — research artifacts, belong with the research branch (or their own research PR), NOT
  bundled into the project-state commit.
- `templates/supabase/.borg/` — likely belongs with the supabase scaffold work; check git log
  for the matching commits before deciding.

## Open questions

- Should `chore/project-state-2026-05-27` PR be squash-merged or use individual commits? The
  five files cover unrelated concerns (gitignore tweaks, doc updates, CLI changes) — separate
  commits would be cleaner for `git blame`.
- Does the research branch (`research/agent-teams-2026-05-23`) itself need a PR? It has four
  research-specific commits. If it's purely for archival, leave it as a branch; if it's the
  basis for follow-up work, open a draft PR to track it.
- After the project-state PR merges, should `CLAUDE.md` get a quick scan for staleness against
  the new architecture.md content?
