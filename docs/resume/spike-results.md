# borg-resume gating spike results (S0b)

## tl;dr

- All 10 gating spikes ran on Claude Code 2.1.296 in an isolated rig: 9 confirmed (several with named sub-gaps), 1 not-run (U17, the resume size dialog could not be triggered). Nothing was refuted outright, but `error_details` is absent from StopFailure, so the reset time must be parsed from text.
- Two findings change the design: a failed workflow agent is journaled as a `failed` record (not just a missing result) and the run still finishes `completed` with nulls, and with native auto-continue off a limit leaves a persistent dialog that only Esc safely dismisses.

Machine-readable results: `spike/SPIKE_RESULTS.json`. Captured-skeleton fixtures from these sessions: `tests/fixtures/resume/` (tagged `captured-skeleton`, extractor v3). The local stub proxy: `spike/stub-proxy.py`.

## Results

| Id  | Topic                          | Outcome   |
|-----|--------------------------------|-----------|
| U1  | StopFailure for subagents      | confirmed |
| U2  | StopFailure on 429, stub       | confirmed |
| U6  | --resume keeps session id      | confirmed |
| U7  | resumeFromRunId accepted       | confirmed |
| U8  | journal: killed / failed       | confirmed |
| U9  | pid and pane identity (host)   | confirmed |
| U13 | send-keys queue, dialog        | confirmed |
| U15 | Stop on Esc, interrupt marker  | confirmed |
| U16 | pane after a limit             | confirmed |
| U17 | resume size dialog             | not-run   |

## Findings

- U1: StopFailure fires for a subagent API error and carries `agent_id` and `agent_type`. In the same run SubagentStop did not fire for the failed subagent (U3, one run), so the hook is the only live subagent-failure signal and the scan stays the backstop.
- U2: StopFailure fires with `error: rate_limit` and the synthetic record has `apiErrorStatus: 429`. The stub reproduces the real weekly and session sentences only under subscription auth with the unified rate-limit headers; a fake API key yields a generic 429 line. `error_details` is absent for 429, 500, 529 and 401, so the reset is text-only in `last_assistant_message`. Error mapping seen: 500 and 529 give `server_error`, 401 gives `authentication_failed`, a plain 400 gives `unknown`. Fallback for the refuted structured reset: parse the text, else backoff.
- U6 and U7: after SIGKILL mid-workflow, `claude --resume <sid>` kept the session id and reused the transcript, and `Workflow` with `resumeFromRunId` was accepted in the same run directory. Completed agents replayed from cache; the killed agent re-ran under a new agent id.
- U8: a killed agent leaves `started` with no `result`. A limit-failed agent inside `parallel()` is journaled as a `failed` record, the run ends `completed` with a result array of nulls, and a resume re-runs the failed agents. The inventory must treat `started` without `result` and `failed` as unfinished, and a completed manifest with null entries as unfinished. Not tested: an agent that returns a literal null by its own code.
- U9: on the host the hook's `$PPID` equals the claude pid and the tmux `pane_pid`, `$TMUX_PANE` is the pane id, and `$TMUX` gives the socket. `tmux set-option -p` from a hook persists. Internal subagents with an empty `agent_type` also fire SubagentStop, so consumers must filter them. Container identity was not run (no drone was started).
- U13: input sent while a turn is generating is queued, not interrupting. Input sent while a permission dialog is open acts on the dialog: text then Enter chose the default Yes. One run dropped the first Enter after a mode change and merged the text into the composer, so any injector needs a verify-then-submit step.
- U15: Esc fires no Stop hook, and the transcript's last record is `[Request interrupted by user]` with no `stop_hook_summary` or `turn_duration` after it. A clean turn ends `system:stop_hook_summary` then `system:turn_duration`. Ctrl+X Ctrl+K (and Esc with idle main) did not stop background agents via send-keys in two tries; that part and the marker in agent transcripts are unverified.
- U16: with auto-continue on (the default here) the pane returns to an empty composer with a footer showing `Usage limit reached` and `Continuing automatically at <time>`. With `autoContinueAtUsageLimit` false a persistent four-option dialog stays up (Stop and wait is the default, then Wait here, Add funds, Upgrade); Esc dismisses it to the composer. No `idle_prompt` Notification fired in either state, so U18 matcher anchoring stayed unobserved.
- U17: the resume size dialog never appeared (about 60k tokens, also after backdating the file). The trust-folder prompt was captured instead (`panes/trust_folder.txt`): No, exit is the default; Down then Enter accepts. Fallback until captured: treat an unrecognised pane after relaunch as not idle and do not inject.

## Not run and caveats

- Container half of U9, U10 and the other non-gating spikes (U3 to U5, U10 to U12, U14, U18) are recorded as `unknown`/not-run in the JSON.
- Pane fixtures pass through the harness pane allowlist, which this slice extended with closed phrases for the limit dialog, footer, trust prompt and dialog footers; every other line stays `<redacted>`.
- The stub never logs headers or bodies and binds loopback only; with subscription auth the OAuth token is sent to that loopback stub, which discards it.

## Follow-ups

- The S0a harness event list lacks `Stop`; add it before S4 relies on the harness to observe Stop.
- Real session-limit and weekly phrasings were both captured; the weekly sentence in the design is confirmed as `resets <time> (<zone>)` without a date for same-day resets.
