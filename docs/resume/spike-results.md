# borg-resume gating spike results (S0b)

## tl;dr

- All 10 gating spikes were attempted on Claude Code 2.1.296 in an isolated rig. Outcome vocabulary is the design's `pass | fail | unknown`, plus `partial` (some of the question is established, the rest is listed as a gap). Result: 1 pass (U7), 8 partial, 1 unknown (U17: the resume size dialog could not be triggered). Nothing was recorded as `fail`, but `error_details` is absent from StopFailure, so the reset time must be parsed from text.
- Claims that rest only on private logs that are not committed are not recorded as established: they sit in the `not_run_parts` of the entry, so a downstream test that reads only `.outcome` cannot mistake them for a pass.
- Two findings change the design: a failed workflow agent is journaled as a `failed` record (not just a missing result) and the run still finishes `completed` with nulls, and with native auto-continue off a limit leaves a persistent dialog (Esc dismissed it in the first run; that part is unverified).

Machine-readable results: `spike/SPIKE_RESULTS.json`. Captured-skeleton fixtures from these sessions: `tests/fixtures/resume/` (tagged `captured-skeleton`, extractor v3), including scrubbed event-name sequences (names and order only) under `tests/fixtures/resume/events/`. The local stub proxy: `spike/stub-proxy.py`.

## Results

| Id  | Topic                          | Outcome |
|-----|--------------------------------|---------|
| U1  | StopFailure for subagents      | partial |
| U2  | StopFailure on 429, stub       | partial |
| U6  | --resume replays workflow      | partial |
| U7  | resumeFromRunId accepted       | pass    |
| U8  | journal: killed / failed       | partial |
| U9  | pid and pane identity (host)   | partial |
| U13 | send-keys queue, dialog        | partial |
| U15 | Stop on Esc, interrupt marker  | partial |
| U16 | pane after a limit             | partial |
| U17 | resume size dialog             | unknown |

`partial` gaps, in short: U1 subagent-origin payload fields (agent_id, agent_type) have no committed payload fixture; U2 `error_details` is absent (refuted part, fallback is text parsing); U6 session-id continuity and U9 host identity were read from private logs; U8 literal-null return was not tried; U13 dialog-input behaviour and the dropped first Enter have no committed capture; U15 Ctrl+X Ctrl+K and the for-tool-use marker were not shown; U16 Esc dismissal and the Notification check in the persistent-dialog state have no committed capture.

## Findings

- U1: a subagent API error produced StopFailure events, SubagentStart fired and SubagentStop did not fire for the failed subagent (`events/subagent_api_error.txt`, names only, one run). Whether the subagent-origin payload carries `agent_id` and `agent_type` is not shown by any committed file (the committed payload fixture is main-loop origin), so it is a gap and U1 is partial; S4 and S5 must not rely on it until captured.
- U2: StopFailure fires with `error: rate_limit` and the synthetic record has `apiErrorStatus: 429`. The stub reproduces the real weekly and session sentences only under subscription auth with the unified rate-limit headers; a fake API key yields a generic 429 line. `error_details` is absent for 429, 500, 529 and 401, so the reset is text-only in `last_assistant_message`. Error mapping seen: 500 and 529 give `server_error`, 401 gives `authentication_failed`, a plain 400 gives `unknown`. Fallback for the refuted structured reset: parse the text, else backoff.
- U6 and U7: after SIGKILL mid-workflow, `claude --resume` reused the workflow directory and `Workflow` with `resumeFromRunId` was accepted in the same run directory (committed journal and manifest). Completed agents replayed from cache; the killed agent re-ran under a new agent id. That the session id stayed the same was read from print-mode output that is not committed.
- U8: a killed agent leaves `started` with no `result`. A limit-failed agent inside `parallel()` is journaled as a `failed` record, and the run ends `completed` with a result array of nulls (`workflows/wf_failed.json`). A resume re-runs the failed agents. The inventory must treat `started` without `result` and `failed` as unfinished, and a completed manifest with null entries as unfinished. Not tested: an agent that returns a literal null by its own code.
- U9: a SessionStart payload carries the documented fields. Host PPID, `$TMUX_PANE` and `tmux set-option -p` persistence were observed in private logs and are not committed. A SubagentStop appears with no preceding SubagentStart in the queued run (`events/queued_two_turns.txt`, names only), so consumers should expect unpaired SubagentStop events; that its `agent_type` is empty is not committed and is unverified. Container identity was not run (no drone was started).
- U13: input sent while a turn is generating is queued, not interrupting (`panes/queued_composer.txt`), and the queued turn ran afterwards (a second Stop in `events/queued_two_turns.txt`). Behaviour with a permission dialog open, and a dropped first Enter after a mode change, were seen in the first run but have no committed capture, so any injector must keep the dialog block and a verify-then-submit step.
- U15: an Esc-interrupted session fires no Stop (`events/esc_interrupt.txt`), while an uninterrupted turn does (`events/clean_turn.txt`, the positive control). The interrupted transcript's last record is `[Request interrupted by user]` with no `stop_hook_summary` or `turn_duration` after it; a clean turn ends `system:stop_hook_summary` then `system:turn_duration`. Ctrl+X Ctrl+K (and Esc with idle main) did not stop background agents via send-keys; that part and the marker in agent transcripts are unverified.
- U16: with auto-continue on (the default here) the pane returns to an empty composer with a footer showing `Usage limit reached` and `Continuing automatically at <time>`. With `autoContinueAtUsageLimit` false a persistent four-option dialog stays up (`panes/limit.txt`). In the auto-continue state an unmatched Notification hook saw no Notification and no Stop for about 2.5 minutes (`events/main_limit_weekly.txt`: StopFailure only), so U18 matcher anchoring stayed unobserved.
- U17: the resume size dialog never appeared (about 60k tokens, also after backdating the file). The trust-folder prompt was captured instead (`panes/trust_folder.txt`): No, exit is the default; Down then Enter accepts. Fallback until captured: treat an unrecognised pane after relaunch as not idle and do not inject.

## Not run and caveats

- Container half of U9, U10 and the other non-gating spikes (U3 to U5, U10 to U12, U14, U18) are recorded as `unknown` in the JSON.
- Pane fixtures pass through the harness pane allowlist, which this slice extended with closed phrases for the limit dialog, footer, trust prompt, queue hints and dialog footers; every other line stays `<redacted>`. Matching is locale independent (NBSP, middle dot and curly apostrophe are normalised before matching).
- The stub never logs headers or bodies and binds loopback only. The limit runs used subscription auth, so the subscription OAuth token was sent to that loopback-only stub, which discards it.

## Follow-ups

- The S0a harness event list now includes `Stop`; S4 can rely on the harness to observe it.
- Real session-limit and weekly phrasings were both captured; the weekly sentence in the design is confirmed as `resets <time> (<zone>)` without a date for same-day resets.
