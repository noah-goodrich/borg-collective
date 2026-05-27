# Handoff — borg-collective ↔ claude-plugins source-of-truth for skill files

**Created:** 2026-05-27
**For:** borg + Claude Code CLI continuation
**Parent plan:** none (cross-project coordination question)

## Current state

Skill source files (the `borg-link-up`, `borg-plan`, `borg-assimilate`, `borg-review`,
`borg-link`, `borg-collective-review`, `adhd-guardrails` `SKILL.md` files and any companion
assets) exist in **two** repositories simultaneously:

1. **`~/dev/borg-collective/skills/`** — the historical home. `install.sh` symlinks these into
   `~/.claude/skills/`. CLAUDE.md still describes this layout as canonical.
2. **`~/dev/claude-plugins/borg-collective/skills/`** — populated this weekend by the plugin-build
   task (`local_fdc38548`). Distributed via the `noah-local` Claude marketplace as a
   `claude plugin install borg-collective@noah-local`-style package.

Both copies are presumed identical right now (the build script in claude-plugins read from
borg-collective during the weekend run). There is no automated sync. Any future edit to a skill
in one repo silently drifts the other.

## What's blocked

- Cannot safely delete either copy until the source-of-truth is named.
- Cannot recommend `claude plugin install borg-collective@noah-local` as the official install
  path in borg-collective's README until that path is the canonical one.
- Cannot safely run `/borg-link-up` etc. from a fresh session and trust that the latest skill
  text is loading — Claude resolves whichever copy `~/.claude/skills/` happens to point at.

## Next action

Pick one of the options below, document the decision in both repos' READMEs, and either delete
or symlink the non-canonical copy so the duplication can't drift.

### Option A — borg-collective is canonical, claude-plugins consumes via build script

- `~/dev/borg-collective/skills/` is the only place skill text is edited.
- A build script in `claude-plugins/` (or a `Makefile` target) copies/syncs skills from
  borg-collective into `claude-plugins/borg-collective/skills/` whenever the plugin is rebuilt.
- Pros:
    - Matches the existing developer workflow (most weekend edits happened in borg-collective).
    - Keeps `borg-collective` self-contained as a clone-and-go repo for someone who doesn't want
      the plugin marketplace.
    - The plugin tarball stays reproducible from borg-collective at a known commit SHA.
- Cons:
    - Two-step edit: change in borg-collective, then rebuild the plugin to ship the update.
    - Sync drift if the build script isn't run before publishing.
    - Plugin consumers can't contribute upstream — they edit a derived copy.

### Option B — claude-plugins is canonical, borg-collective references the plugin

- Skill files move entirely to `~/dev/claude-plugins/borg-collective/skills/`.
- `~/dev/borg-collective/skills/` is deleted (or becomes a thin symlink to the plugin's
  install path).
- borg-collective's README points users at `claude plugin install borg-collective@noah-local`
  for the skills; the repo itself holds the CLIs (`borg.zsh`, `drone.zsh`), hooks, lib, and
  knowledge-graph artifacts only.
- Pros:
    - Single edit point. Plugin install is the only distribution mechanism.
    - Matches the direction Claude Code is heading (plugin marketplace is the official path).
    - Plugin consumers can fork the plugin repo to contribute back.
- Cons:
    - Breaks anyone who installed borg-collective without the plugin (treats the plugin as a
      hard dependency for the skills, even though the CLIs can run without them).
    - Requires a one-time migration commit in both repos and a CLAUDE.md rewrite.
    - The `install.sh` symlink step has to change to point at the plugin install path.

### Option C — split by concern: knowledge graph stays, skills move

- `borg-collective` becomes the knowledge-graph + directives + checkpoints + CLI repo.
- All skill files move to `claude-plugins/borg-collective/skills/`.
- `install.sh` in borg-collective stops symlinking skills entirely — that's the plugin's job.
- Effectively Option B with an explicit narrative: "borg-collective is the orchestrator's
  memory; the plugin is the orchestrator's behavior."
- Pros: cleanest mental model; matches the "skills do the thinking, knowledge graph does the
  remembering" framing in CLAUDE.md.
- Cons: most disruptive in the short term; same migration cost as B.

## Open questions

- Does Noah want the plugin marketplace to be the official install path for skills, or is the
  marketplace still treated as experimental and the symlink-from-clone the supported path?
- Is anyone other than Noah currently consuming either copy? (If yes, the migration needs an
  announcement; if no, the only cost is Noah's own muscle memory.)
- Should `claude-plugins/borg-collective/INSTALL.md` (written this weekend) become the single
  source of install docs, or is it duplicating instructions already in `borg-collective/README.md`?
- If Option B/C is chosen, do the three existing directives in
  `borg-collective/docs/plans/directives/` stay where they are, or do they also move? (Probably
  stay — they're knowledge-graph artifacts, not skill behavior.)
