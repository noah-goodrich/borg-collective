# Cortex hook probe (S0 of #516), 2026-11-03

Cortex Code v1.2.33, model claude-sonnet-5-5. Part of the Cortex hook parity work, tracking issue noah-goodrich/borg-collective#516. No borg hook registration or script was changed.

## Method

- `evals/cortex-agents/hook-probe.sh` is registered for all 11 documented events (empty matcher) in a project-level `.cortex/settings.local.json` of a scratch git repository. XDG_STATE_HOME, XDG_CONFIG_HOME and XDG_DATA_HOME pointed at scratch dirs, so borg's own user-level hooks (which also fired) wrote there.
- For every event the recorder logged the payload and the CLAUDE_/CORTEX_ env var names, then answered with `additionalContext` carrying `CANARY-<event>-7f3a` and a `systemMessage` carrying `SYSCANARY-<event>-7f3a`. The model was then asked which canaries it could see.
- 4 Cortex sessions (the cap), all with `--no-mcp`:
  - S1: headless stream-json, `--bypass`: Bash, Read, Edit, Task, skill, then `/compact` as a second message.
  - S2: headless stream-json, `--bypass`, gates on: blocked prompt, blocked writes, a borg-scout subagent, Stop block.
  - S3: headless stream-json, `--resume` of S1, no `--bypass`, a Bash call needing permission.
  - S4: interactive TUI in a detached tmux, `--bypass`: a prompt, then `/compact`.
- Payload fixtures for what fired are in `tests/fixtures/cortex/` (session ids, paths and tool ids replaced with the existing placeholders).

## Events

| Event | Fired? | Headless? | Canary to model |
|-------|--------|-----------|-----------------|
| PreToolUse | yes | yes | no |
| PostToolUse | yes | yes | yes |
| PermissionRequest | yes | yes (no bypass) | not tested |
| UserPromptSubmit | yes | yes | yes |
| SessionStart | yes | TUI only | no |
| SessionEnd | yes | headless only | n/a |
| PreCompact | yes | TUI only | n/a |
| Stop | yes | yes | n/a |
| SubagentStop | yes | yes | n/a |
| Notification | yes | yes | not tested |
| Setup | no | no | n/a |

- Payload keys common to all: `session_id, transcript_path, cwd, permission_mode, hook_event_name`.
- Added per event: PreToolUse `tool_name, tool_input, tool_use_id`; PostToolUse adds `tool_response`; PermissionRequest `tool_name, tool_input` (no `tool_use_id`); UserPromptSubmit `prompt`; SessionStart `source`; SessionEnd `reason`; PreCompact `trigger`; Stop `stop_hook_active`; Notification `message, notification_type`; SubagentStop `agent_id, agent_type, agent_transcript_path, parent_session_id, parent_thread_id, parent_thread_message_id, stop_hook_active, last_assistant_message`.
- `permission_mode` is `bypassPermissions` under `--bypass` and `default` otherwise.
- Env var names starting CORTEX_ seen in hook processes: `CORTEX_PROJECT_DIR, CORTEX_SESSION_ID, CORTEX_ENV_FILE, CORTEX_TASK_CONTEXT_ID, CORTEX_CODE_CLIENT_SURFACE, CORTEX_THINKING_EFFORT`, a few feature flags. No CLAUDE_ names.
- `systemMessage` canaries never reached the model. They surface to the user: in stream-json as `{"type":"system_message","content":"[Hook: UserPromptSubmit]: SYSCANARY-..."}`, in the TUI as a `[Hook: ...]` line.

## Blocking

| Gate | Blocks? | Text to model | Text to user |
|------|---------|---------------|--------------|
| UserPromptSubmit exit 2 | yes | no (0 turns) | yes |
| PreToolUse exit 2 | yes | yes | not seen |
| PreToolUse deny JSON | yes | yes | not seen |
| Stop exit 2 | yes | yes | not seen |
| PreCompact exit 2 | not tested | | |

- UserPromptSubmit exit 2 with stderr `GATE-UPS-BLOCK`: the stream returned a result `error_during_execution`, `num_turns 0`, `errors: ["[Hook] Blocked: GATE-UPS-BLOCK\n"]`, and the same text on stderr. The model never saw the prompt. The session stayed alive and processed the next stream message.
- PreToolUse exit 2 on a Write to a `blockA` path: the tool result the model received was exactly `[Hook] Blocked: GATE-PTU-EXIT2\n`.
- PreToolUse deny JSON (`permissionDecision: "deny"`, `permissionDecisionReason: "GATE-PTU-DENY-REASON"`): the tool result was `[Hook] Blocked: GATE-PTU-DENY-REASON` (no trailing newline). Same prefix as exit 2, so the two are equivalent to the model.
- Stop exit 2 with stderr `GATE-STOP-BLOCK reply with the word STOPGATE`: the turn continued and the model's next message was `STOPGATE`, then a second Stop fired with the marker file set and the session ended. The second Stop payload carried `stop_hook_active: true` (`stop-hook-active.json`); the first carried false.
- Not tested: PreCompact exit 2 (compaction needs the TUI session, and the cap left no session for a gated compaction).

## Answers

- a) Tool calls inside a subagent carry `agent_type` (for example `borg-collective:borg-scout`), `agent_id`, `agent_transcript_path`, `parent_session_id`, `parent_thread_id`, `parent_thread_message_id`. Calls in the main thread carry none of these. See `pretooluse-in-subagent.json`.
- b) PostToolUse carries `tool_response`: `{name, tool_use_id, content: [{type: text, text}], status, metrics}`. Bash puts `metrics.bash.exit_code`.
- c) PreCompact fires, in the TUI on `/compact`, with `trigger: "manual"`. Auto was not tested. Headless stream-json does not run `/compact`: the model answered that it is a built-in command and no PreCompact fired.
- d) Skill invocation: `tool_name` is lowercase `skill` (Pre and Post), `tool_input.command` is the skill name. Other tools are capitalized (`Bash`, `Read`, `Edit`, `Write`, `Task`), but `agent_output` is lowercase too.
- e) Notification types seen: `permission_prompt` (message like "Permission needed: bash — execute_command") and `finished` (message is the assistant reply text). `idle_prompt` not seen.
- f) SessionStart `source` values seen: `startup` (TUI) and `compact` (fired right after PreCompact). `resume` was not observed: see l).
- g) Reached the model: UserPromptSubmit (appended to the user message) and PostToolUse (appended as `[Additional context]` on the tool result, including Task and agent_output). Did not reach it: PreToolUse (the model saw none), SessionStart at startup (consistent with 2026-10 evidence). Unverified: SessionStart `compact`, Notification, PermissionRequest (the model was not asked after them or the answer was ambiguous). SessionEnd, Stop, PreCompact, SubagentStop were not meaningfully testable.
- h) Setup never fired in any of the 4 sessions. PermissionRequest fires headless when `--bypass` is off (together with a `permission_prompt` Notification); the headless permission request then failed and the tool did not run.
- i) See Blocking: prompt blocked, text to user (result error and stderr), not the model. Exact wording `[Hook] Blocked: GATE-UPS-BLOCK\n`.
- j) Both exit 2 and deny JSON block Write; the model gets `[Hook] Blocked: <stderr or reason>`.
- k) PreToolUse and PostToolUse both fire for tool calls inside a subagent, with `tool_name` `Read` and the subagent fields from a). The parent saw `Task` and `agent_output` (not `Agent`). Note the Task subagent ran in the background, and the parent's `agent_output` call waited for it. A subagent spawned with `Explore` was blocked in S1 by the user's own borg model guard, so the first attempt did not run.
- l) On a resumed headless session (`--resume <id>` with stream-json) SessionStart did not fire at all. In the TUI the only SessionStart seen were `startup` and `compact`. So a `startup|resume` matcher has not been shown to match a real resume; the resume case needs a TUI test (not run, cap reached).
- m) Stop can block with exit 2 and its stderr reaches the model (see Blocking). PreCompact blocking not tested.

## Still unanswered

- PreCompact exit 2, and `trigger: "auto"`.
- `source: "resume"` in the TUI.
- Whether SessionStart `compact`, Notification and PermissionRequest additionalContext reach the model.
- `idle_prompt` notifications.
- Whether a borg guard registered in Cortex denies a live subagent's Bash call end to end (#516 S2 replays the fixture payloads only). The `agent_type` the fixtures carry is `borg-collective:borg-scout`, the plugin form `borg setup` writes into the installed agent's `name:`, and both guards already list that form; if a live run reports a different value the guards stay inert, which is the pre-S2 state.

## Corrections found in S2

- `transcript_path` (`<id>.json`) is conversation metadata with no messages; the messages are the JSONL beside it, `<id>.history.jsonl`. The user's own prompt is a `role: user` entry whose text block has `is_user_prompt: true`; injected context blocks are `internalOnly: true`. `borg-precompact-checkpoint.sh` reads that sibling file.
- The `skill` tool carries the skill name in `tool_input.command`, so `borg-nanoprobe-guard.sh` falls back to it for the lowercase tool only.

## Cleanup (Cortex files these sessions created)

- Conversations: `~/.snowflake/cortex/conversations/` ids `2cb331fc-d249-412c-a2ee-c905c4277082` (S3), `8b27149e-871d-4f53-bc4d-b2c315f457d4` (S1, resumed by S3), `6babcbed-7330-4909-bd3d-1e1b83792604` (S2), `83e0a53d-1b05-4ad2-8218-8c3cc0f5fba1` (S2 subagent), `43a6ba9e-b2d2-4e29-a9be-5faea1b44393` (S4), each as `.json` and `.history.jsonl`.
- `.last-session` in that directory was updated (pre-existing file).
- `~/.snowflake/cortex/cortex.json`: no trust entry was added for the probe directory.

## S3 live check (2026-11-03, #516 S3)

- Method: the S0 one. A scratch git repository carried a checkpoint with the canary `PELICAN-4417-QUARTZ` under `## 5. Next Session`, and a project-level `.cortex/settings.local.json` registered `hooks/borg-cortex-restore.sh` on UserPromptSubmit and SessionStart. `cortex --input-format stream-json --output-format stream-json --bypass --no-mcp --model claude-sonnet-5-5 -w <repo>` ran headless with XDG_STATE_HOME, XDG_CONFIG_HOME and XDG_DATA_HOME in scratch directories. One run, no retry.
- Prompt: "What is the release codeword you were told about in this session context? Reply with the codeword only, or UNKNOWN." The model replied `PELICAN-4417-QUARTZ`. Headless never fires SessionStart, so the only path the canary could take to the model was the UserPromptSubmit additionalContext. The marker file `cortex-restore/<session_id>` appeared in the scratch state directory.
- Not run live: the second-prompt silence and the compact reset (both pinned by `tests/cortex_payload_replay.bats` on the real fixtures); no control run without the hook.
- Cortex conversation created: `2cb331fc-d249-412c-a2ee-c905c4277082`.
