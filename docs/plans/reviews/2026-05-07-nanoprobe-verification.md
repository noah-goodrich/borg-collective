# Nanoprobe v2 Verification Spike

Date: 2026-05-07
Scope: Three open questions blocking the nanoprobe orchestrator + cairn restoration directives.
Verdict: All three answered. Two out of three resolutions require directive edits before
implementation lands.

---

## Question 1 — Worktree x `drone exec` interaction

### Result: WORKS CORRECTLY. No nanoprobe directive change required.

### Evidence

`drone.zsh:90-128` (`_drone_resolve`) checks the project arg in this order:

1. **Registry lookup by name** (`$BORG_DIR/registry.json` → `.projects[name].path`) — wins
   when the arg matches a registered project, regardless of cwd.
2. **Existing path** (`-d "$arg"`) — only consulted if registry lookup misses.
3. **`$BORG_ROOT/<arg>`** — last-resort fallback. *(Note: renamed to `$BORG_ORCHESTRATOR_ROOT`
   by the 2026-05-11 orchestrator-mode-separation directive.)*

Cwd is only consulted when the arg is empty (`drone exec` with no project). When a name is
passed, the registry path wins unconditionally — the calling shell's cwd is irrelevant.

`cmd_exec` (`drone.zsh:743-782`) calls `_drone_resolve "$project_arg"` and then runs
`docker compose -p "$project_name" -f "$compose" exec ...` using the resolved path. The
`docker compose -p <project>` flag scopes to the project label, not cwd.

### Practical test

Created `/tmp/borg-worktree-test` (a worktree of `borg-collective`), then:

```
cd /tmp/borg-worktree-test && drone exec ingle -- pwd       # → /workspaces/ingle
cd /tmp/borg-worktree-test && drone exec ingle -- hostname  # → 6abf332cba5f (ingle container)
```

Both commands routed to the `ingle` devcontainer correctly. The shell cwd inside the
worktree had zero effect on routing.

### Implication for nanoprobe directive

No new clause needed. The existing v2 spec already says nanoprobes invoke `drone exec
<project> -- <cmd>` with an explicit project name. As long as that contract is enforced (no
`drone exec -- <cmd>` calls without a project arg), worktree isolation is safe.

**One nice-to-have**: add a one-line note to `borg-nanoprobe.md` system prompt — "Always
pass the project name explicitly to `drone exec`; never rely on cwd, since you may be
running from a worktree." Defensive, costs nothing.

---

## Question 3 — Cairn root cause

### Result: ROOT CAUSE IS CAIRN INSTALL, NOT BORG SUBSHELL PATH. Directive belongs in cairn.

### Evidence

`borg.zsh` invokes `cairn` at three sites:

- `borg.zsh:508` — `command -v cairn &>/dev/null` gate, then `_borg_timeout 5 cairn search ...`
- `borg.zsh:762-765` — same pattern in switch-time auto-brief
- `borg.zsh:882-883` — auto-disable LLM-summary fallback when cairn is empty

All three are gated behind `command -v cairn &>/dev/null` first. If `cairn` is not on PATH,
the gate fails silently and the cairn block is skipped. There is no failure mode here that
silently corrupts state — it simply degrades gracefully.

### PATH inheritance test

```
command -v cairn                                 # → NOT_FOUND  (interactive shell)
/bin/zsh -c 'command -v cairn || echo X'         # → NOT_FOUND_SUBSHELL  (non-interactive)
```

**Both fail identically.** The cairn binary is missing from the system entirely, not
PATH-shadowed in subshells. This rules out the "borg.zsh subshells strip PATH" hypothesis —
PATH is fine; the binary doesn't exist.

`hooks/borg-link-down.sh:18-21` does prepend `~/.config/dotfiles/zsh/bin` to PATH for the
hook context, but that prepend is irrelevant: cairn isn't installed there either. The hook
PATH adjustment is correct as written.

### Diagnosis

Cairn is not installed on this machine. The cairn restoration directive correctly belongs in
the cairn project — its job is to install/build/wire the cairn binary onto PATH (or into
`~/.config/dotfiles/zsh/bin`, which is what `borg-link-down.sh` already covers). Once cairn
exists on PATH, all three borg.zsh callsites will pick it up automatically.

### Recommendation

**Do NOT file a sibling borg-collective directive.** The cairn directive as scoped is
correct. One amendment to confirm: the cairn install script must drop the binary somewhere
that `borg-link-down.sh`'s PATH (`~/.config/dotfiles/zsh/bin:/usr/local/bin:/usr/bin:/bin`)
finds it — `~/.local/bin` would NOT work for the hook context. `/usr/local/bin` (Homebrew on
Intel) or `~/.config/dotfiles/zsh/bin` (the dotfiles bin dir) are both fine. If cairn is
already destined for `/opt/homebrew/bin` (Apple Silicon Homebrew), add that path to the hook
script — see follow-up note below.

### Follow-up nit (optional, not blocking)

`borg-link-down.sh:20` lists `/usr/local/bin:/usr/bin:/bin` but omits `/opt/homebrew/bin`.
If cairn lands as a Homebrew formula on Apple Silicon, the hook will not find it. Either:

- Have the cairn directive's installer symlink into `~/.config/dotfiles/zsh/bin/cairn`
  (already in the hook PATH), or
- File a one-line borg-collective amendment adding `/opt/homebrew/bin` to the hook PATH.

Cleaner option: cairn installer drops the symlink. Borg stays untouched.

---

## Question 4 — SubagentStop hook payload

### Result: SubagentStop IS REAL. v2 directive's hook strategy works as written.

### Evidence (Claude Code official docs + local changelog)

From `https://code.claude.com/docs/en/hooks` — the canonical hook event list includes
`SubagentStop` (alongside the related `SubagentStart`, `TaskCreated`, `TaskCompleted`):

> SessionStart, Setup, UserPromptSubmit, UserPromptExpansion, PreToolUse,
> PermissionRequest, PermissionDenied, PostToolUse, PostToolUseFailure, PostToolBatch,
> Notification, **SubagentStart, SubagentStop, TaskCreated, TaskCompleted**, Stop,
> StopFailure, TeammateIdle, InstructionsLoaded, ConfigChange, CwdChanged, FileChanged,
> WorktreeCreate, WorktreeRemove, PreCompact, PostCompact, Elicitation, ElicitationResult,
> SessionEnd

> `SubagentStop` | When a subagent finishes
> For subagents, `Stop` hooks are automatically converted to `SubagentStop` since that is
> the event that fires when a subagent completes.

### Confirmed payload fields

Standard fields on every hook event:

- `session_id`
- `transcript_path`
- `cwd`
- `permission_mode`
- `hook_event_name`

SubagentStop-specific (per local changelog at `~/.claude/cache/changelog.md`):

- `agent_id` — Unique identifier for the subagent (added explicitly in 2.0.41+)
- `agent_type` — Agent name, e.g. `"Explore"`, `"security-reviewer"`, or a custom subagent
  type. The subagent's type takes precedence over the parent session's `--agent` value.
- `agent_transcript_path` — Path to the subagent's transcript file.
- `last_assistant_message` — Final assistant response text. Hooks can read the summary
  without parsing the transcript JSONL.

### Mapping to nanoprobe v2 logging needs

The directive wants to log `subagent_type, agent_id, status, summary` per completion:

| Field needed       | Available from SubagentStop                                            |
|--------------------|------------------------------------------------------------------------|
| `subagent_type`    | `agent_type`                                                           |
| `agent_id`         | `agent_id`                                                             |
| `summary`          | `last_assistant_message` (already extracted, no transcript parsing)    |
| `status`           | Not a payload field — derive from `decision` field or transcript state |

`status` is the only soft spot. SubagentStop fires when the subagent stops, but does not
distinguish "completed cleanly" vs "errored mid-run." Two options:

1. Treat all SubagentStop fires as `status=completed`. Errors surface separately (the parent
   agent will see the error in its tool result and can record `status=failed` itself).
2. Have the nanoprobe write a marker file before exiting (`<.borg/agents/<agent_id>.done`)
   and have the SubagentStop hook check for the marker; missing marker = `status=failed`.

Option 1 is simpler and probably sufficient. Option 2 is more robust but adds a coordination
point.

### Recommendation

The v2 directive's hook strategy is sound as written. Two small refinements:

- Use the `last_assistant_message` field (no transcript parsing) for `summary`.
- Decide explicitly on the `status` derivation (option 1 vs option 2 above) and document it
  in the directive.

---

## Summary table

| Q | Verdict | Action |
|---|---------|--------|
| 1 | Worktree + `drone exec` works correctly | Optional: add "always pass project name" line to nanoprobe system prompt |
| 3 | Cairn is uninstalled — not a borg subshell PATH issue | Keep cairn directive as-is; install must land in a PATH visible to `borg-link-down.sh` |
| 4 | `SubagentStop` is real with `agent_id`, `agent_type`, `last_assistant_message`, `agent_transcript_path` | Refine status derivation; otherwise green-light |
