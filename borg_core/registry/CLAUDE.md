# borg_core/registry/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md.

- **A worktree is a VIEW of a repo, and `repo` is the key that says so**: `borg add` used to identify
  a repository by directory basename and nothing else (`registry/cli.py`'s `name = _basename(ppath)`,
  with no git call in the add path), so a git worktree was not a view of a repository, it WAS one —
  its own `PROJECT_PLAN.md` slot, its own `.borg/checkpoints`, its own `state.json`, invisible to
  its parent. `build_add_entry` now emits a `repo` field: the absolute
  `git rev-parse --path-format=absolute --git-common-dir`, which is byte-identical from a main
  checkout and from every linked worktree of it. **`--path-format=absolute` is load-bearing** — a
  bare `--git-common-dir` answers a relative `.git` from the checkout, so the two values that must
  compare equal would be the two that differ. It is the COMMON DIR and not
  `manifest.shell.repository_slug`'s `owner/repo` on purpose: the slug answers "which stack declares
  rows here", the common dir answers "where did this session's state go", and two independent clones
  of one GitHub repo genuinely are separate working state. **Additive, per expand → migrate →
  contract**: `link.core.repo_sources` resolves a missing or null `repo` to a group of one, which is
  exactly the pre-change behaviour, so no existing entry is read by a rule it was not written to
  satisfy. `python3 -m borg_core.registry.cli backfill-repo [--dry-run]` is the migrate phase
  (idempotent, only ever fills a hole, never overwrites a hand-corrected value). **No contract phase
  is scheduled** — a registered directory outside any git repository has no common dir, so null is a
  permanently legal value, not one to eliminate.
