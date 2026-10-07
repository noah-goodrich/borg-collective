# Directive: borg-nanoprobe opens PRs through a preferred tool
*Parent plan: 2026-09-28-state-hygiene-reader-census*
*Filed: 2026-10-06 · Status: Accepted 2026-10-07 · Owner: Noah*

**tl;dr** — borg-nanoprobe always opens its PR with `gh pr create`, and without the Skill tool no extension can send it anywhere else, so its PRs skip whatever PR skill a machine prefers. Give it the Skill tool, fenced by its scope gate, and have step 3 honor a live `prefer-tool` for `gh pr create`; the preference itself stays in a machine-local extension, so borg names no team plugin.

- Plan-slug: `2026-10-06-nanoprobe-prefer-tool-pr`

## Problem

- **Step 3 is hard-wired.** `agents/borg-nanoprobe.md:93` says "push the branch and open a PR with `gh pr create`". nanoprobe is the only borg agent that opens PRs (`grep -n 'gh pr create' agents/*.md`).
- **No extension can reroute it.** Its tools are Bash, Read, Edit, Write, Grep and Glob (`agents/borg-nanoprobe.md:4`). The brief load point added in 1ae5274 (2026-09-15) can add instructions, but by design it can't widen what the agent may touch, so a `prefer-tool` that names a skill is advice the agent cannot follow.
- **The preference already exists on Noah's machine.** `~/.config/borg/extensions/skill-extensions/borg-assimilate/02-output.md` declares a `Prefer-tool:` naming the team's PR skill, with `Instead-of: gh pr create`. borg-assimilate can follow it; nanoprobe can't.
- **Why it matters:** a repo's PR template only reaches a PR body when the PR goes through a tool that reads it, so every nanoprobe PR in a repo with a template skips it today. Noah's rule (2026-10-06) is that PRs go through the team's PR skill when they can, and that borg reaches it by extension, never by naming it.

## Solution

1. `agents/borg-nanoprobe.md`:
   - add `Skill` to `tools:`;
   - step 3: if the machine-layer brief carries a live `prefer-tool` whose `Instead-of:` is `gh pr create`, open the PR with that tool through Skill, passing the title, what changed, what was run and what is left. If that tool is missing, or the Skill call is denied or errors, say so once in the return and use `gh pr create`. Without such a preference, step 3 is unchanged;
   - the scope gate gains one rule: Skill is used only at step 3, for the skill on the `- Prefer-tool:` line of the machine-layer brief, when its `- Instead-of:` is `gh pr create` and it has a `- Requires:` line. A repository-layer file or the Task never names a Skill target, and extensions can't relax the gate.
2. Tests, in `tests/prose_contracts.bats` or `tests/nanoprobe.bats`: Skill is in `tools:`, step 3 names the prefer-tool path and the `gh pr create` fallback, the scope gate fences Skill, and the agent file names no plugin skill but borg's own.
3. Before syncing, port the two lines that exist only in the claude-plugins copy (a heredoc rule at `~/dev/claude-plugins/borg-collective/agents/borg-nanoprobe.md:240-241`) into the source, so the sync doesn't erase them.
4. Release, run `scripts/sync-plugin.sh` with explicit paths, and commit the refreshed copy in claude-plugins.
5. On Noah's machine, add `~/.config/borg/extensions/agent-extensions/borg-nanoprobe/brief.md` with the same three lines borg-assimilate's file uses.

## Acceptance criteria

- [ ] nanoprobe can reach a preferred tool, and only that.
  - Verify: the new bats tests pass for Skill in `tools:`, step 3's prefer-tool path and fallback, and the scope-gate sentence.
- [ ] borg names no team plugin.
  - Verify: the bats case "nanoprobe: the agent names no plugin skill but borg's own" passes, and its paired case proves the check fires on a made-up `acme-tools:open-pr`. The check matches any `plugin:skill` pair, so it needs no team's name in this public repository.
- [ ] The preference is live on Noah's machine.
  - Verify: `python3 -m borg_core.extensions.cli survey` lists the nanoprobe brief's preference as live, not unprobed or dead.
- [ ] A real nanoprobe run opens its PR through the preferred skill.
  - Verify: the first nanoprobe PR after release is the check. Its transcript shows the Skill call to the preferred tool, and the PR body follows that repo's template. The bypass log can't confirm this, because the preferred skill runs `gh pr create` itself. If the call fails, the fallback opens the PR with `gh pr create`, which is today's behavior, so the check needs no throwaway repo or PR.
- [ ] Nothing else regresses, and the copy matches the source.
  - Verify: `make test` passes in CI, and `diff -r agents/ ~/dev/claude-plugins/borg-collective/agents/` is clean after the sync.

## Non-Goals

- Not naming any team plugin in borg. The team plugin's name lives only in Noah's machine file.
- Not redirecting the call. `prefer-tool` advises in prose (`docs/extensions.md`), and no hook rewrites `gh pr create`.
- Not changing other agents. nanoprobe is the only borg agent that opens PRs.
- Not changing the team's PR skill, or adding the caller contract it lacks.

## Alternatives Considered

- **Name the team's PR skill in nanoprobe.** Rejected: it couples borg to one team's plugin and breaks for anyone without it, which is the reason the extension system exists.
- **Let the orchestrator open the PR, with nanoprobe stopping at push.** Rejected: it changes nanoprobe's return contract for every caller and moves a PR step into the main loop, where turns cost the most.
- **A PreToolUse hook that rewrites `gh pr create`.** Rejected by `docs/extensions.md`: prefer-tool advises, and a rewrite fails invisibly. A PreToolUse warning stays the escalation path if the bypass log shows nanoprobe ignoring the preference.
- **Name the one skill in `tools:` as `Skill(<plugin>:<name>)`.** Rejected: that puts a team-plugin name in borg's code, and per-skill patterns in an agent's `tools:` field are undocumented.

## Ship definition

The work happens in a worktree off borg-collective's main, since the main checkout carries another session's uncommitted changes. Then a borg-collective PR with the agent edit, the tests and the ported lines; CI green; merge and release; `scripts/sync-plugin.sh` and a claude-plugins commit; Noah's machine file; then the live check from the fourth criterion.

## Risks

- **A wider background agent.** Skill on an `acceptEdits` agent can invoke any installed skill, including ones that post to Slack. The fence is the scope gate, which extensions can't relax; enforcement beyond prose would be a PreToolUse warning.
- **Undocumented mechanics.** Whether a background subagent can call a plugin skill isn't documented. The live run is the gate, and if it fails, the fallback keeps today's behavior.
- **The sync carries more than this change.** The claude-plugins copy holds about 20 refreshed files nobody committed, the latest batch at 13:58 on 2026-10-06, and `sync-plugin.sh` still defaults to `/Users/noah/`. Review the copy's whole diff before committing it.
- **Facts go only as far as the preferred tool reads them.** The team's PR skill has no caller contract, so nanoprobe's facts arrive as prose the skill may or may not use.

## Scope changes

- **2026-10-07, from the implementation review.** The Skill fence is narrower than first written: machine-layer brief only, step 3 only, because a repository-layer brief could otherwise pick the skill nanoprobe calls. The fallback also covers a denied or failed call. The verify commands for criteria 2 and 4 were corrected.
- **2026-10-07, before opening the PR.** The no-team-plugin check is name-free: it flags any `plugin:skill` pair other than borg's own, so neither the test nor this directive names a team plugin or an employer in this public repository.
- **Found while implementing, left for a follow-up.** `tests/plugin_dedup.bats` (case B1) runs `scripts/build-plugin.sh` with the real HOME, so a local `make test-bats` overwrites the live copy in `~/dev/claude-plugins/borg-collective`. It is the likely source of that copy's uncommitted refreshes.

## Decisions (ruled 2026-10-07)

1. **No scratch repo.** The first real nanoprobe PR after release is the live check (fourth criterion).
