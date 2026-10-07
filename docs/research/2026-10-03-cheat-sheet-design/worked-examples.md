Generated: 2026-10-04

# Worked examples: one day, six moments, five options

The recommendation is in [recommendation.md](recommendation.md). This file runs the same day through every option so the options can be compared on what Noah would actually see. The v1 version is archived in `drafts/v1/`.

## The scenario

**Wednesday 2026-10-07, 08:40.** Noah has been away from borg for three days. He glances at the whole board, picks something to work on, re-enters borg-collective, plans the next acceptance criterion and switches to doing it, hits friction around tool call 75, and stops for the day.

**Where the facts come from.** Every fact was read from this machine on 2026-10-04. Durations that grow with time are advanced by exactly three days and marked with a dagger (†). The one staged event is marked with a double dagger (‡); it is a plausible instance of a real failure class, not a recorded one. Project names other than the public repos are masked (`shopping-app` is Noah's grocery project). Paths on the authoring machine (`~/...`, its checkout of this repo) and the checkpoints named below are local measurements, not committed files: a reader without that machine cannot re-run them, and the checkpoint `.borg/checkpoints/2026-10-03-222446-beb3b1.md` is not in the repo.

- 20 repositories, 1 needs attention, `shopping-app` waiting, 19 of 20 rows `(no summary)`, 17 rows never or 26+ days idle, 30 queued directives, `▸ NEXT  nobody looked`, 159 lines of output — `zsh borg.zsh link --local` run in the authoring machine's checkout of this repo on 2026-10-04 (a local measurement)
- Last session ended with tl;dr "Shipped State Hygiene AC3 to AC5 ... two full-tier research runs ... mid write-up"; Blockers (stray adapter output to remove, a research-tools bug, a stale gate marker); five Next Session items — `.borg/checkpoints/2026-10-03-222446-beb3b1.md`
- 7 untracked entries (1 checkpoint, `docs/research/snapshots/`, 5 `retrospectives-0*.md`) — `git status` at session start, 2026-10-04
- PRs #258 and #259 merged Sun 2026-10-04 03:42 -0600 (Stop warnings now reach the user) — `git log` on `main`
- Plan 5 of 6 criteria met; open criterion AC6 "Nothing breaks" with its Verify line — `PROJECT_PLAN.md`
- `shopping-app`: "Start with PR #394", the top item; 636 of 659 stored preferences ignored until it merges — that project's checkpoint `2026-10-02-1457.md`
- Auto-memory gate FAIL, 0.050 against a 0.2 threshold, checked 2026-10-02T21:26Z — `~/.local/state/borg/memory-gate-verdict.json`
- What a session-start, 75-call, pre-commit and Stop message look like today — `hooks/borg-link-down.sh`, `tool-count-nudge.sh`, `pre-commit-remind.sh`, `borg-link-up.sh`
- The tmux status line is the date only; `Ctrl+Space >` runs `borg next --switch` — `~/.config/dotfiles/tmux/tmux.conf`
- `borg next` output shape and its jq score; the page's order — `cmd_next` in `borg.zsh`; `core.project_sort_key` in `borg_core/link/core.py`
- Launcher paths — `cmd_claude` in `drone.zsh` (`tmux send-keys "claude" Enter`); `cmd_claude` and `_borg_launch_in_tmux` in `borg.zsh`
- 4 commits and 2 merges after the checkpoint, touching 7 files — `git log --since` the checkpoint time on `main`, 2026-10-04

**Who sees what.** Marked **[H]** when the human sees it and **[M]** when only the model receives it. Corrected after the first blind review: SessionStart, PostToolUse and PreToolUse `additionalContext` reach the model only, and a model-side message reaches the human only if the model repeats it. Stop `systemMessage` is documented to reach the human (and has been emitted since PR #258) but has not been watched rendering live, and Stop fires after every assistant turn, so it is not an end-of-session signal. SessionStart `systemMessage` may render: the current hooks reference lists `systemMessage` as a universal field shown to the user, but a public report (anthropics/claude-code#41285, last reproduced on 2.1.132 under tmux, closed without a fix) says it stopped rendering in the terminal, and nobody has watched it in a borg session; the spike watches it. Switching into a tmux window whose Claude session is already running fires no SessionStart at all. The `borg switch` auto-brief prints to the pane Noah leaves and is built from `summary`. A print from `drone claude` or `borg claude` is plain stdout in the pane and reaches the human with no hook or model, but only for launches that go through those commands.

**Order.** The moments run in clock order, which puts M6 (a problem mid-session) before M5 (the end).

**Layout.** Fenced mocks are wrapped to 72 columns for a narrow pane. An indented continuation line is the same line on screen, and in the status-line mock `left:` and `right:` are the two halves of one line.

---

## M1: the glance (08:40)

**Today.** `borg link --local` prints 159 lines. The cube takes 9 of them, 19 of 20 repository rows say `(no summary)`, and the one line that matters (`waiting <<<`) sits about 60 lines down.

```
$ borg link --local
  _______________
  /|             /|      THE BORG COLLECTIVE         (9 lines of cube)
▸ IN FOCUS  borg-collective
    (38 lines: path, session id, plan, checkpoint)
▸ REPOSITORIES  the collective · 20 repositories · 1 need attention
 shopping-app            [C]  waiting <<<  3d ago†  (no summary)
 pytest-coverage-impact  [C]  idle         never    (no summary)
 ... 17 more rows, 15 of them "(no summary)" ...
 borg-collective         [C]  idle         3d ago†  (no summary) ◀
▸ CHAINS  1 project · 4 refs · 4 unresolved · not swept  (30 lines)
▸ QUEUED  30 directives  (30 lines)
▸ NEXT  nobody looked
  - no state on this page was resolved; run without --local.
```

**A, one page on a diet [H].** A verdict line goes first and the dormant rows collapse.

```
$ borg link --local
1 needs you: shopping-app, waiting 3d†.  16 dormant (never or 30d+).
  Not swept (--local).

▸ IN FOCUS  borg-collective · idle · plan 5/6 ·
  last checkpoint Sat 22:24 (3d†)
▸ REPOSITORIES  20 repositories · 1 need attention
 shopping-app     [C]  waiting <<<  3d†
 claude-plugins   [C]  idle         29d†
 dotfiles         [C]  idle         21d†
 borg-collective  [C]  idle         3d†  ◀
 16 dormant, oldest 126d†  ·  borg link --all
▸ QUEUED  30 directives · top 5 shown
```

**B, ambient periphery [H].** The glance moves to the tmux status line, fed by a cache with a freshness mark. One item fits; the other 19 projects need the page.

```
left:  [borg] 1:borg-collective  2:shopping-app*  3:dotfiles
right: !1 shopping-app 3d  08:40 ·08:38
```

**C, quiet router [H].** The page is as today; only `▸ SIGNALS` changes, and it is the last section, so it is the last thing read.

```
▸ SIGNALS
  - 1 needs you: shopping-app waiting 3d†
  - held back since Sat 22:24: 5‡ (2‡ tool-count check-ins, 3‡
    commit reminders), none urgent
  - sweep: --local, nothing was fetched
```

**D, narrator [H].** One model call over the same sweep.

```
$ borg link --brief
One thing needs you: shopping-app has waited three days† on PR #394,
which unblocks 636 stored preferences. borg-collective is at 5 of 6
criteria on its state-hygiene plan. Sixteen projects have not been
touched in a month. (narrated 08:41 from one sweep; real page available:
borg link)
```

**E, doorways [H, pull].** The MVP adds A's smallest change here, the verdict line, derived from the rows the page already orders (it adds no ranker; `borg next` is left to main's chooser, see M2), and nothing else; the dormant-row collapse is the optional last step (build step 9), and main's board/chooser directive rejects it ("Nothing in this directive collapses projects", `docs/plans/directives/2026-10-05-board-chooser-and-trains-ux.md:17`). Shown is the verdict line plus the rows as they are today.

```
$ borg link --local
1 needs you: shopping-app, waiting 3d†.  16 dormant (never or 30d+).
  Not swept (--local).
▸ REPOSITORIES  the collective · 20 repositories · 1 need attention
 shopping-app            [C]  waiting <<<  3d ago†  (no summary)
 ... the rows as today (collapsing the dormant ones is optional
     step 9) ...
```

---

## M2: choosing the next move (08:44)

**Today.** `borg next` returns one project by score (pinned +200, waiting +100, active +50, idle +10). It shows no reason and no alternatives, and nothing records whether Noah took it. *Superseded 2026-10-07: that describes `borg next` as it was on 2026-10-04. #274 and #275 have since shipped M2 as a TTY chooser that lists every ranked project (`borg.zsh:791`, `borg_core/nextpick/core.py:180-191`); every run appends a row to `next-recs.jsonl` (`borg_core/nextpick/shell.py:15-20`); and a `▸ suggested:` line stays hidden until at least 20 chooser rows show a follow rate of at least 60% (`core.py:108-114`, `:194-198`). Any ranker change goes through that directive's gate and keeps `cmd_next`'s null handling. The mock below is the 2026-10-04 output.* `Needs:` is absent because the registry has no waiting reason.

```
$ borg next

▸ Next up: shopping-app  (waiting, 3d ago†)

  Directives: 2 pending for shopping-app
    - (title of directive 1)
```

**A [H].** Up to three varied moves, one labelled recommended with its reason.

```
$ borg next
▸ Next up (3 moves, recommended first)
  1. shopping-app     merge PR #394
     recommended: waiting longest (3d†); unblocks 636 prefs
  2. borg-collective  AC6 "Nothing breaks"
     plan 5/6, the last criterion; one command verifies it
  3. dotfiles         nothing pending recorded (21d† idle)
```

**B [H].** `Ctrl+Space >` jumps to the top pick and shows one line for two seconds. Alternatives need the page.

```
 borg -> shopping-app: merge #394 (waiting 3d)
```

**C [H].** Unchanged from today; the router does not address M2.

**D [H].** Two sentences instead of a score.

```
$ borg next
Go to shopping-app: PR #394 has waited three days† and gates 636 stored
preferences. If you want a short win instead, borg-collective has one
criterion left (AC6).
```

**E [H, pull].** *Superseded 2026-10-07: E leaves M2 to main's chooser.* This paragraph first proposed one ranker for `borg link` and `borg next` (`core.project_sort_key`) and a `next-log.jsonl`; neither is built. #274 and #275 shipped the chooser and `next-recs.jsonl`, and the ranker stays `cmd_next`'s until that directive's gate passes. What survives is a proposal for the chooser's suggestion line once the gate passes: a reason labelled a heuristic that says what it is (status order, not value), with what the PR is worth quoted from the project's own checkpoint and attributed to it, so borg does not claim it. The mock below is that proposal's wording, not a shipped output. The three-move list is not in E.

```
$ borg next
▸ Next up: shopping-app  (waiting, 3d ago†)
  why (heuristic, status order, not value): waiting outranks active
  and idle; oldest activity first
  its last checkpoint says: "Start with PR #394"
```

---

## M3: re-entering borg-collective (08:46)

Noah has not touched this project for three days†. There are three ways in, and they have different channels. **Path 0, launched through borg** (`drone up borg-collective` or `drone claude borg-collective`, the usual cases after three days, or `drone feature`): the launcher puts `claude` into the project's pane (`drone.zsh:482`, `:561`, `:735`, `:817`). **Path 1, a hand-typed `claude`, `/resume`, or CoCo**: SessionStart fires and nothing runs before it. **Path 2, `borg switch` or `Ctrl+Space >`** into a window whose Claude session is already running: SessionStart does not fire, because no session starts. Everything below that says [M] reaches only the model; the human sees it only if the model repeats it.

**Today, path 0.** Same as path 1: `drone up`, `drone claude` and `drone feature` put `claude` into the pane (the `send-keys` at `drone.zsh:413`, `:735` and `:817`) and print nothing of their own, so the human sees an empty prompt and the model gets the injection below.

**Today, path 1.** The human sees an empty prompt. The model receives about 60 lines [M]: git status (7 untracked entries), the last 5 commits, the memory-gate FAIL paragraph (every session since 2026-10-02), and sections 4 and 5 of the checkpoint verbatim.

```
Noah sees:  > _
Model gets:
  Git branch: main
  Uncommitted changes:  ?? .borg/checkpoints/2026-10-03-222446-beb3b1.md
    (+6 more)
  Recent commits:  0fe3890 Merge pull request #259 ...  (5 lines)
  WORKFLOW REQUIREMENT - AUTO-MEMORY GATE: FAIL ... (6 lines)
  Latest checkpoint for borg-collective (2026-10-03-222446-beb3b1.md):
  ## 4. Blockers  (4 bullets)
  ## 5. Next Session  (5 numbered items, ~20 lines)
```

**Today, path 2.** `_borg_do_switch` builds its auto-brief from `summary` and prints it with `echo` only when `summary` is non-empty. For borg-collective `summary` is "(no summary)", so nothing prints at all. When it does print (the other 1 of 20 rows), it goes to the pane Noah is leaving, and then the window is selected. On the hotkey path the `--silent` branch calls `tmux display-message "borg-collective | <summary>"`, one line.

```
Noah sees:    (origin pane: nothing)  ->  the borg-collective window,
              showing the session's last screen from Saturday
Hotkey:       a one-line tmux message for tmux's display-time (default
              750 ms; tmux.conf does not set it): "borg-collective"
```

**A [H, if he asks].** The page's `▸ IN FOCUS` carries the tl;dr and the first line of Next Session. Nothing is pushed on either path.

```
$ borg link
▸ IN FOCUS  borg-collective · idle · plan 5/6 ·
  last checkpoint Sat 22:24 (3d†)
  Last time: Shipped State Hygiene AC3-AC5 ... two research runs
             verified, mid write-up.
  Next:      Land the two research PRs, run decision-design, then
             State Hygiene AC6.
```

**B [H, ambient].** The Claude Code status line carries the same fact in one segment, on both paths (it renders in a running session too). The model injection is unchanged. The `statusLine` behavior was not verified in this run.

```
borg-collective · plan 5/6 · next: land research PRs ·
  2 PRs merged since Sat
```

**C [M].** Nothing new for the human on either path. On path 1 the model injection shrinks: the memory-gate paragraph is shown once per day and then becomes a ledger line. This is `additionalContext`, so the "push, once" is a push to the model.

```
Model gets:   ... (git, checkpoint 4 + 5 as today)
              Held back since last session: 3‡ (gate FAIL unchanged
              since 10-02; 2‡ check-ins)
```

**D [M on path 1; H only if he runs it or the model repeats it].** A model composes where he stopped from the checkpoint, `git log` and the diff. At session start the text can only be handed to the model as `additionalContext`; the human sees it if Claude repeats it. On path 2 nothing runs unless he types `borg say reenter`, because no session starts.

```
Where you stopped: the research PRs were not yet opened and the two
write-ups were running. Since then #258 and #259 merged, so Stop
warnings now reach you. Seven files are untracked, five of them the
stray adapter output your last checkpoint asked you to remove. Start
with the PRs.
```

**Note for C and D.** A launcher print is a delivery path, not an option; C's held-back line or D's narrated text could ride it, but neither option includes it, and D would pay a model call at every launch to do so.

**E, path 0 [H, deterministic].** The pane command at each launch site is `borg brief borg-collective; claude` (`drone up` on both paths, `drone claude` when the pane is at a shell prompt, `drone feature`), so the brief prints into the target pane and then `claude` starts. No hook and no model is involved, so the brief is on screen before Claude starts and before Noah types anything. Derived lines come first, with the `Activity` line (the part of the evidence that corresponds to the automated cue); the checkpoint's own words come under a line that says who wrote them and when. `Ended` is derived from `state.json` `last_activity` against the newest checkpoint time, read before Claude's SessionStart hook overwrites it. Whether the text stays visible once Claude's screen takes over is the spike's question (a), as is whether the pane's shell can run `borg` when it sits inside the devcontainer. If `borg_core` cannot be imported, the pane shows `borg brief unavailable: <import error>` and Claude starts anyway.

```
$ drone claude borg-collective
borg-collective · main · checkpoint Sat 22:24 (3d† ago) ·
  STALE: HEAD moved (4 commits) since it was written
Activity  since the checkpoint: 4 commits, 7 files touched  ·
          merges (local): #258, #259
Dirty     7 untracked (5 retrospectives-*.md, snapshots/, 1 checkpoint)
Plan      5/6 met; open: AC6 "Nothing breaks";
          first move: its Verify step 1
Ended     last activity Sun 04:41‡, 6h after the checkpoint;
          no checkpoint covers it
--- from your last checkpoint (written Sat 22:24) ---
Last      Shipped State Hygiene AC3-AC5; both research runs verified,
          mid write-up.
Next      Land the two research PRs, run decision-design, then AC6.
Blocked   remove stray adapter output
          (docs/research/sources/retrospectives-0*.md)
(then Claude starts; Noah types his first prompt with the brief
already above it)
```

The `Blocked` and `Dirty` lines describe the same five stray files, one from the checkpoint's words and one from `git`, which is the cross-check a derived line buys. The merged PRs come from local merge commits (`Merge pull request #258`), so launch makes no network call. If there were no checkpoint, the lines under the rule would read `NO CHECKPOINT for this project. Derived facts only.` If nothing had changed since the checkpoint (not STALE), the brief would collapse to its header and the Next line.

**E, path 1 [M, plus a title cue for the human].** Nothing prints before the prompt. The SessionStart hook is scoped to the `startup` and `resume` matchers, so it does not fire on `/compact` or `/clear`. The model gets the derived lines only (not the checkpoint's Last, Next and Blocked, which sections 4 and 5 already carry) and no instruction to restate them; the human sees a one-line `sessionTitle`, if the spike shows it renders where Noah looks. The brief is one command away.

```
Noah sees:      session title:  borg-collective · STALE · AC6 open
                (unverified: where it shows)
Model gets:     derived lines (Activity, Dirty, Plan, Ended) + sections
                4 and 5 verbatim, as today
Model no longer has: the git status block and the last-5-commits
                block, but only if the brief built; if borg_core is not
                importable it keeps both and gains:
                "borg brief unavailable: <reason>"
Noah pulls:     $ borg brief            (the same 9 lines as path 0)
```

**E, path 2 [H, directly, non-modal].** After the window is selected, `borg switch` and the hotkey show one derived headline through `tmux display-message -d 4000 -C`, which does not take over the pane and expires on its own. The old `summary` echo to the origin pane is gone. The full brief is `borg brief`. A popup was rejected: the tmux manual says panes are not updated while one is present.

```
 borg-collective · STALE: 4 commits since the checkpoint · AC6 open ·
 full brief: borg brief
```

The headline carries no Next text, because the launcher print or the model's sections already carry it; the headline points at `borg brief`.

---

## M4: switching from planning to doing (09:05)

Noah plans AC6 in plan mode, exits plan mode, and Claude makes its first edit. `PROJECT_PLAN.md` already exists, so `borg-plan-promote.sh` is a no-op.

**Today [none].** Nothing from borg. The first edit just happens; "done" lives in Claude's plan text and the plan file's Verify line.

**A [none].** Not addressed; the page is not open mid-session.

**B [H, ambient].** The Claude Code status line flips mode and carries the done-when.

```
DO · AC6 Nothing breaks ·
  done when: make test && make test-bats && make lint green
```

**C [none].** The gate holds anything non-urgent until a breakpoint. Nothing mid-edit.

**D [H].** A one-line model restatement at plan exit, as ordinary assistant text (model discretion, so it reaches him only if the model writes it).

```
Doing AC6. Done when the three make targets pass and link output diffs
clean against the capture.
```

**E [none].** Dropped from the MVP. The first-edit message was hung on `borg-plan-promote.sh`, which does nothing when `PROJECT_PLAN.md` already exists (this scenario) and misses re-plans, so the doorway would not have fired here. If it returns it needs its own trigger on the `ExitPlanMode` tool and the same channel spike. This is a stated concession: of the six moments, E leaves this one alone.

---

## M6: something goes wrong (14:10 to 14:31)

Staged‡. A `make test-bats` run goes red on a case in the class the last checkpoint named (a macOS `[[ ]]`-under-errexit blind spot found in #253). At 14:12 the 75th tool call of the session lands mid-edit. At 14:31 Noah runs `git commit`.

**Today.** Two messages, both to the model [M]. Noah sees the red bats output in his own terminal and the two nudges only if Claude repeats them.

```
[M] 14:12  SESSION CHECK-IN: 75+ tool calls this session. Consider
           running /borg-review to check progress against the
           plan, or /borg-link-up if this is a good save point.
[M] 14:31  WORKFLOW REMINDER: About to commit. Have you run /simplify on
           the changed code this session? ... Also: have you
           run /borg-assimilate to verify acceptance criteria are met?
```

**A [none].** The page is not open. On the next `borg link`, `▸ SIGNALS` would show the gate FAIL line.

**B [H, ambient].** The segment turns amber on the facts borg derives itself (calls, dirty files, checkpoint age). It cannot see the bats failure.

```
borg-collective · DO AC6 · 75 calls · 6 dirty ·
  last checkpoint 3d†  [amber]
```

**C [H or M, by hook].** The 14:12 check-in fails the gate (not urgent, not actionable, mid-edit) and is logged. The 14:31 commit reminder is a PreToolUse message, which reaches the model; it passes the gate as the first reminder of the session, shortened to what, since when, do. The human sees it only if Claude repeats it.

```
[M] Before commit (first this session): /simplify not run on 4‡ changed
    files. Run it, then commit.
    held back: tool-count check-in at call 75 (mid-edit). See borg link,
    SIGNALS.
```

**D [H, on request].** Nothing arrives unasked. If Noah types `borg say wrong`:

```
Nothing borg tracks is wrong. This session has 75 tool calls and 6 dirty
files, and the last checkpoint is three days† old. The red test run is
yours, not borg's.
```

**E [none mid-session].** The 75-call check-in is deleted and nothing else is raised mid-session. Nothing is held for later and no `Held` line exists; the next brief's `Activity` and `Dirty` lines are derived from git, so what the session did is visible without a log of suppressed nudges. Hard blocks such as `bash-guard` still interrupt.

---

## M5: ending the session (16:05)

Noah finishes. He runs `/borg-link-up` at 16:02 and it writes a checkpoint. Then he closes the session.

**Today [H].** The Stop hook runs after every assistant turn, not at the end. By reading `hooks/borg-link-up.sh`, the "no checkpoint in the last hour" paragraph is true from the first turn of the day (the newest checkpoint is three days old), so it is emitted from turn one, not at 16:05; the uncommitted paragraph appears from the first turn after a tracked file is modified. Before the once-per-session fix that is landing separately, each of these repeats on every turn; after it, each appears once, at the first turn where its condition holds. Nothing marks the end. The text is a three-paragraph `systemMessage`, and the second paragraph tells him to save state "next session", which is too late by construction.

```
▸ WARNING: borg-collective has uncommitted changes
  Run /simplify then commit before your next session.

▸ No checkpoint in the last hour for borg-collective
  Run /borg-link-up next session to save state for future resumption.

▸ Directive reconciliation? Committed files overlap with:
  - 2026-10-04-stop-hook-warnings-are-invisible.md
  Review open directives and update checkboxes if this work
  advances them.
```

The checkpoint it leads to has `## 5. Next Session` as free-form prose. Whether the Stop `systemMessage` renders live in a session has never been watched (the directive's AC5).

**A [H].** Unchanged from today. The page diet does not touch M5.

**B [H].** Unchanged Stop message, plus the status line shows `unsaved: no checkpoint` until one is written. That is a fact borg derives, but it is ambient and appears after the moment it would have helped.

**C [H, unverified channel].** One coalesced message in what, since when, do. Because Stop fires after every turn, "once per session" lands after the first turn in which a condition holds, not at the end; as designed, C has no end signal.

```
▸ Leaving borg-collective: 6 files uncommitted, no checkpoint since Sat
  22:24 (3d†).
  Do: /simplify, commit, then /borg-link-up. Directive overlap:
    stop-hook-warnings-invisible.
  held back today: 1‡ check-in, 1‡ commit reminder
  (borg link, SIGNALS)
```

**D [H].** `/borg-link-up` already drafts the checkpoint with a model, so M5 is as today with the same three warnings. The narrator adds nothing here.

**E [H, if Stop `systemMessage` renders, and only when there is something new].** The existing three warnings are left to the once-per-session fix and are not redesigned. What E adds fires on one turn only: the turn after a checkpoint file whose name ends in this session's suffix appears. At 16:02 `/borg-link-up` runs `borg checkpoint-name`, which returns `2026-10-07-160214-<suffix>` with the suffix taken from `CLAUDE_CODE_SESSION_ID`; when that turn ends, the Stop hook finds a new `*-<suffix>.md`, computes the two derived flags, and speaks only if at least one is non-empty. The skill has just displayed the checkpoint's Last and Next to Noah, so the message does not repeat them. A turn without a new matching checkpoint emits nothing from E, and a session with no suffix (CoCo, a bare terminal) gets no read-back at all.

```
▸ Checkpoint saved: borg-collective (16:02). Flags (derived by borg, not
    written by the agent):
    CARRIED       "remove stray adapter output" is unchanged since
                  2026-10-03 (Blockers). Keep or drop?
    NOT DEPLOYED  hooks/borg-link-up.sh differs from the ~/.claude copy;
                  run borg setup.‡
```

If Noah had closed the session without ever writing a checkpoint, no message appears and no record is written. At the next arrival, `Ended` is derived: `state.json` `last_activity` is later than the newest checkpoint by more than the tunable gap (first guess 30 minutes), so the line reads `last activity Wed 15:58, 9h after the checkpoint; no checkpoint covers it`. A killed process still leaves its last Stop time, so there is no "unknown" case. If Stop `systemMessage` turns out not to render, the flags move into the `/borg-link-up` skill's final output, which is model-side.

---

## Comparison: option by moment

Each cell says what appears and who sees it. **H** is the human, **M** is the model only, **-** is nothing. Cells now follow the channel a hook can actually use: SessionStart, PostToolUse and PreToolUse `additionalContext` reach the model; Stop `systemMessage` reaches the human but fires after every turn.

- **M1 glance**
  - Today: 159-line page, signal at about line 60 (H, pull)
  - A One page: Verdict line, 4 rows plus a count (H, pull)
  - B Ambient: One status-line item (H, ambient)
  - C Quiet router: Page as today, `SIGNALS` rolled up (H, pull)
  - D Narrator: 3-sentence prose (H, pull)
  - E Doorways (revised): Verdict line (H, pull); dormant-row collapse is optional step 9
- **M2 next move**
  - Today: One project, no reason, not logged (H) as of 2026-10-04; superseded 2026-10-07 by the #274 and #275 chooser
  - A One page: 3 varied moves, 1 recommended with reason (H)
  - B Ambient: One line (H)
  - C Quiet router: As today (H)
  - D Narrator: 2 sentences (H)
  - E Doorways (revised): Left to main's chooser (superseded 2026-10-07); a labelled reason is a proposal for its suggestion line
- **M3 re-enter, fresh session**
  - Today: Empty prompt; model gets about 60 lines (M)
  - A One page: Page if he asks (H, pull)
  - B Ambient: Status-line segment (H, ambient)
  - C Quiet router: Model injection trimmed (M)
  - D Narrator: Composed prose to the model; human only if repeated (M)
  - E Doorways (revised): Launched through borg: brief printed in the pane before Claude starts (H, deterministic; spike). Hand-typed: derived lines to the model, title cue to the human (M, plus H cue)
- **M3 re-enter, running window**
  - Today: Nothing on the origin pane for most projects; one line on the hotkey (H)
  - A One page: Page if he asks (H, pull)
  - B Ambient: Status-line segment (H, ambient)
  - C Quiet router: -
  - D Narrator: - unless he runs `borg say`
  - E Doorways (revised): One derived headline, non-modal and auto-expiring (H); `borg brief` for the rest
- **M4 plan to do**
  - Today: -
  - A One page: -
  - B Ambient: Mode flips on status line (H, ambient)
  - C Quiet router: - (held to a breakpoint)
  - D Narrator: One model sentence (H, model discretion)
  - E Doorways (revised): - (dropped from the MVP)
- **M6 going wrong**
  - Today: Two nudges (M)
  - A One page: -
  - B Ambient: Amber segment on derived facts (H, ambient)
  - C Quiet router: Check-in logged; commit reminder to the model (M)
  - D Narrator: On request only (H)
  - E Doorways (revised): - mid-session; the next brief's `Activity` and `Dirty` lines are derived from git
- **M5 end**
  - Today: 3 warnings, from turn one, one says "next session" (H)
  - A One page: As today (H)
  - B Ambient: As today plus `unsaved` (H)
  - C Quiet router: 1 coalesced message after the first qualifying turn (H, unverified)
  - D Narrator: As today (H)
  - E Doorways (revised): Existing warnings untouched, plus flags-only on the turn this session's checkpoint appears and a flag is non-empty (H, unverified); no-checkpoint case derived at the next arrival

**Counts in this scenario.** Unsolicited messages that reach the human, counting hook-sent messages and a model restatement of a hook-supplied brief, and not counting pulled pages or ambient segments:

- **Unsolicited messages to the human**
  - Today: 1 (3 paragraphs)
  - A: 1
  - B: 1
  - C: 1 to 2 (coalesced Stop; commit reminder only if repeated)
  - D: 2 (Stop, plus the narrated brief if the model repeats it)
  - E: 3 (launcher print or hotkey headline, flags-only read-back when a flag exists, the existing Stop warnings)
- **Of those, caused by a transition the user made**
  - Today: 0 (Stop is per turn)
  - A: 0
  - B: 0
  - C: 0
  - D: 1 (the arrival)
  - E: 2 (launch or switch, checkpoint written)
- **Messages sent to the model only**
  - Today: 2 plus 60-line start-up
  - A: same
  - B: same
  - C: trimmed start-up, 1 reminder
  - D: start-up replaced
  - E: start-up with derived lines, 0 nudges, no restatement instruction
- **Mid-edit interruptions**
  - Today: 1 (the 75-call, to the model)
  - A: 1
  - B: 0
  - C: 0
  - D: 0
  - E: 0

**What the table shows, plainly.**

- E sends the most human-visible messages in this scenario (three), but only one is a leftover: the existing Stop warnings, which the separate fix quiets and which E does not touch. The other two are caused by Noah launching a session and writing a checkpoint, and each fact appears once per transition: the Next text is on the launcher print and in the model's sections 4 and 5, not on the headline, the title or the flags message (Ancker: repeats are the lever). The old claim that all three E messages were user-caused came from treating Stop as an end signal and plan exit as a doorway; neither holds.
- No option fixes everything. A is the only one that improves the glance in depth, and E's MVP adds only the verdict line and the reason line there; E is the only one that changes the handoff itself.
- B and D carry M1 best on paper and fail the scenario's weakest test: B cannot see the failure that actually happened (the red bats), and D adds a model call to the moment that has to be fastest, and its session-start text reaches the model rather than the human.
- E's value in this scenario is mostly derived: the `Activity` and `Dirty` lines against the checkpoint's `Blocked` line (the same five files from two sources), the explicit `STALE` and `Ended` lines, and the two mechanical flags at the read-back. All of these are checks that do not depend on anyone remembering, which is where v1's reviewers pushed.
- E's cold-start path no longer depends on a model: the launcher print is deterministic in what is sent. What is unverified is what is seen: whether the text survives Claude's start-up (spike a; the pane reaching `borg` is answered from the code: the panes are host shells, `drone.zsh:559`), where `sessionTitle` shows (b), Stop `systemMessage` rendering live (c) and key handling during `display-message -d` (d). A hand-typed `claude` is the uncovered path; the launcher marker measures how often that happens.
