# Directive: The arrival brief rides SessionStart systemMessage
*Filed: 2026-10-18 · Status: Proposed · Owner: Noah*

**tl;dr** — The spike on 2026-10-18 showed that text printed before `claude` starts is hidden by the fullscreen renderer, and that a SessionStart `systemMessage` renders at the top of the transcript before any typing. This directive builds screen 4 of the board-chooser directive (and the Doorways arrival brief) as a SessionStart hook that prints the brief from the `borg link <repo> --json` document on `startup` and `resume` only, so launched, hand-typed and resumed sessions all get it with no launcher change.

- Plan-slug: `2026-10-18-arrival-brief-on-sessionstart`

## Problem

- **The planned channel does not render.** Screen 4 of `2026-10-05-board-chooser-and-trains-ux.md` has `drone up` print the brief into the pane before Claude starts. With `"tui": "fullscreen"` that text is on the main screen, which Claude hides until it exits (spike (a), 2026-10-18).
- **A launcher print would miss most starts anyway.** A hand-typed `claude` and a `--resume` never pass through `drone up`.
- **Arrival today is model-side.** `hooks/borg-link-down.sh` injects `additionalContext`, which reaches the model and not the human.

## Solution

A new SessionStart hook emits a top-level `systemMessage` carrying the brief. Evidence: `docs/research/2026-10-03-cheat-sheet-design/recommendation.md`, "Spike results (2026-10-18)".

1. **Matchers.** `startup|resume`. Never `clear`, `compact` or `fork`: a brief pushed mid-work is noise.
2. **Content.** The four lines of the screen-4 mock: last time, next + owner, watch out, since then. Derived facts lead (commits, merged PRs, dirty files, a STALE line when the checkpoint is old). It is a presentation of the same `borg link <repo> --json` document that `--brief` presents, never a second read of the registry or git.
3. **Queen session.** When the input `cwd` equals `$BORG_ORCHESTRATOR_ROOT` (classified by `_borg_session_mode`), the hook prints one cross-project verdict line instead of the four-line brief. The Queen session writes nothing to the registry, as `hooks/CLAUDE.md` requires.
4. **Optional `sessionTitle`.** Emitted in `hookSpecificOutput` only when the input's `session_title` is empty. The spike showed that a resume overwrites an existing border title.
5. **Fail loud.** If the brief cannot be built (no checkpoint reader, bad JSON, missing `borg`), the hook still emits a `systemMessage` of one line that says so. Silence is never the fallback.
6. **Hook language.** Per `hooks/CLAUDE.md`, a hook that needs a JSON parse plus string work is Python 3 stdlib behind `command -v python3 >/dev/null 2>&1 || exit 0`, with the render logic in `borg_core` and the hook as a thin wrapper.
7. **Deploy.** Hooks are copied to `~/.claude/hooks/` and do not run from the source tree. After merge, run `borg setup` to redeploy, then confirm with `diff -q hooks/borg-arrival-brief.sh ~/.claude/hooks/borg-arrival-brief.sh`. The plugin owns hook registration; the build adds the SessionStart entry there.
8. **Supersession.** On merge, screen 4's "Channel:" line in the board-chooser directive is already marked superseded; the launcher-print work in build step 2 of the recommendation is not built.

## Non-Goals

- The launcher print (demoted by spike (a)).
- The switch headline (`display-message -d 4000 -C`, kept as is by spike (d)).
- The departure flags on Stop (kept by spike (c)).
- Trains and the train name in the header (screen 3, waits for the stamper).
- Removing the `additionalContext` blocks in `borg-link-down.sh`. That is a later contract step, after this ships.

## Alternatives Considered

- **Launcher print with a hold or `Press Enter`.** Rejected by the spike: it costs a keypress on every launch and still misses hand-typed and resumed sessions.
- **Model restates the brief on its first reply.** Rejected in review round 2: it lands after the first prompt and depends on model discretion.
- **`tmux display-popup` from the hook.** Needs a tmux pane and steals focus; the `systemMessage` needs neither.

## Acceptance criteria

- [ ] AC1 — A real SessionStart `startup` input produces a top-level `systemMessage` with the four brief lines.
  - Verify: `bats tests/arrival_brief.bats` has a case that pipes a SessionStart input JSON (fields `session_id`, `cwd`, `hook_event_name`, `source`: `startup`) into the hook against a fixture repository and asserts `jq -e '.systemMessage | test("last time") and test("next") and test("since then")'` on stdout. The case fails against an empty hook body.
- [ ] AC2 — A `resume` input with an existing title emits no `sessionTitle`; an empty title emits one.
  - Verify: the same file has two cases. With `session_title` set to `kept`, `jq -e '.hookSpecificOutput.sessionTitle // empty'` prints nothing and exits 4 on `-e`; with it empty, the same filter prints a non-empty string.
- [ ] AC3 — `clear`, `compact` and `fork` sources print nothing.
  - Verify: one case per source asserts stdout is empty and exit 0. The registered matcher is checked by `jq -e '.hooks.SessionStart[] | select(.hooks[].command | test("arrival-brief")) | .matcher == "startup|resume"'` on the built hooks file.
- [ ] AC4 — The brief comes from the `borg link --json` document, not a second read.
  - Verify: the test replaces `borg` with a mock that records its argv; the case asserts exactly one call whose args are `link <repo> --json`, and that no `git` process is spawned by the hook (mock `git` on PATH exits 99 and the case still passes).
- [ ] AC5 — The Queen session gets one verdict line.
  - Verify: a case with input `cwd` equal to `$BORG_ORCHESTRATOR_ROOT` asserts the message has exactly one line and the registry file is byte-identical before and after.
- [ ] AC6 — A failing brief is loud.
  - Verify: a case where the mock `borg` exits 1 asserts `.systemMessage` is a non-empty single line containing the word `unavailable`, exit 0.
- [ ] AC7 — The deployed copy matches the source.
  - Verify: after `borg setup`, `diff -q hooks/borg-arrival-brief.sh ~/.claude/hooks/borg-arrival-brief.sh` exits 0.
- [ ] AC8 — It renders live (manual, once, Noah).
  - Verify: start a new `claude` in a repository with a checkpoint and see "SessionStart:startup says:" with the four lines before typing; resume it and see "SessionStart:resume says:" with the title unchanged.
- [ ] AC9 — Suite green.
  - Verify: `make test && make test-bats && make lint`.
