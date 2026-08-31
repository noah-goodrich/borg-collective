# Directive: The auto-memory gate's numerator cannot see the path it is judging — fix it or retire it
*Parent plan: (none — instrumentation, not the link front door)*
*Parent directive: 2026-08-08-cairn-decommission-and-unconditional-block, Phase 1.6*
*Filed: 2026-08-31*

**tl;dr** — The gate FAILs and nags on every SessionStart, but its instrument is a `PostToolUse(Read)` hook while
the dominant way project memory reaches a session is a system-prompt injection and `<system-reminder>` recall —
neither of which is a tool call. The numerator structurally cannot see them. **The threshold is pre-registered and
must not move.** The question is whether the numerator can be fixed, or whether the gate should be retired and say
so.

## Why this exists

**Measured today**, `bin/memory-hits-report` over the last 30 days:

```
  reads:    13
  sessions: 73
  ratio:    0.178 reads/session
  VERDICT: FAIL — < 0.2 reads/session — auto-memory is a second write-only store.
```

That verdict may well be correct. The problem is that nothing about it is *evidence*, because of how the numerator is
collected.

**The instrument.** `hooks/borg-memory-read-log.sh` is a `PostToolUse(Read)` hook: it appends a line to
`$BORG_DIR/memory-hits.log` when the agent calls the `Read` tool on a file under a project's
`~/.claude/projects/*/memory/` directory. `bin/memory-hits-report` divides that count by a session count.

**The paths it cannot see.** Claude Code surfaces project memory to a session in at least two ways that are not
`Read` tool calls:

1. **`MEMORY.md` is injected into the system prompt.** Every session in the window received it. Zero of those
   injections can produce a `PostToolUse(Read)` event, because no tool ran.
2. **Recalls arrive inside `<system-reminder>` blocks.** Same reason.

So the measured numerator counts one specific behaviour — an agent explicitly opening a memory file with the `Read`
tool — and the ratio is being read as though it measured *whether project memory is used*. Those are different
questions, and the second is the one Phase 1.6 was asking. **A denominator of every session against a numerator that
can only be incremented by a minority path produces a number that trends to zero whether the feature works or not.**

This is the same family as the failures already in `CLAUDE.md`'s Learned section — `borg recon` shipped dead because
every test supplied the value production was supposed to derive; the usage-watch job exited 0 and logged something
reassuring three times. Here the check runs, produces a number, and the number is about the wrong thing. A check
pointed at the wrong thing does not fail; it reads as a result.

**Meanwhile the delivery is broken in the opposite direction from what it looks like.** Two behaviours, both
verified in `bin/borg-memory-gate` and `hooks/borg-link-down.sh`:

- **The notification fires once, ever.** The gate compares against `last_verdict` and logs *"FAIL already delivered
  previously — not re-notifying (idempotent)"* on every subsequent run. A standing FAIL is announced on the
  FAIL-transition and never again.
- **The SessionStart injection fires every single session.** `borg-link-down.sh` appends a `WORKFLOW REQUIREMENT —
  AUTO-MEMORY GATE: FAIL` block to `CONTEXT_PARTS` whenever the verdict file exists, which it does continuously
  while the verdict is FAIL.

So the human is told once and the agent is told forever. Neither cadence was chosen: idempotent-notify is right for a
transition and wrong for a standing condition, and an unbounded per-session injection of a workflow requirement that
nobody can action is how a real signal becomes wallpaper. It has been wallpaper for weeks.

## Solution

Two decisions, in order. The first determines whether the second is worth making.

**1. Can the numerator see the dominant path?** Investigate, and record the answer either way:

- Does any Claude Code hook event fire on system-prompt memory injection or on a `<system-reminder>` recall? If one
  exists, the instrument moves to it and the ratio becomes a measurement of the thing the null was registered about.
- If none exists, can the numerator be derived from an artifact that already exists — a session transcript scan for
  the injected block, the same way `borg-plan-promote.sh` scans session JSONL for `ExitPlanMode`? This repo's own
  ratified lesson is that capture which derives from an artifact the agent already produces works, and capture that
  asks for a volunteer does not.

**2a. If the numerator can be fixed** — fix it, re-run against the SAME pre-registered `< 0.2` threshold, and let the
verdict fall where it falls. That is the whole value of a pre-registration.

**2b. If it cannot** — retire the gate, and retire it loudly. Delete the SessionStart injection, the launchd job and
the verdict file, and write the result into the cairn-decommission directive's Phase 1.6 as *"could not be measured
with the instruments available; the pre-registered null was never actually tested"*. That is an honest null result
and it is more useful than a permanent FAIL nobody can act on. **Do not delete the `PostToolUse(Read)` logging** — it
is cheap, it is real data about one genuine behaviour, and `borg nanoprobes`-style inspection of it costs nothing.

**Either way, fix the two cadences.** A standing FAIL should re-notify on a schedule (weekly, or on a ratio change
beyond some delta) rather than once ever; and the SessionStart injection should be bounded — a fixed number of
sessions, or dropped entirely in favour of the notification, since the agent cannot act on it and the human can.

## Non-goals

- **MOVING THE 0.2 THRESHOLD. It was pre-registered — `hooks/borg-memory-read-log.sh` says "do not move this bar
  after seeing the number" in the file.** Adjusting a threshold because the measurement came back inconvenient is
  the exact move a pre-registration exists to forbid, and this repo has an entire decommissioned service worth of
  evidence about what happens when a metric is bent to fit a conclusion. If the instrument is wrong, fix the
  instrument or abandon the experiment; the bar does not move.
- **Re-litigating the cairn decommission.** That evidence base stands; this is about whether its replacement is
  being measured at all.
- **Building a new memory system.** The question is measurement, not architecture.
- **Making the gate blocking.** It is a notification and a context injection, and nothing here proposes changing
  that.

## Alternatives considered

**Leave it FAILing; the number might be right.** Rejected on two counts. It may well be right, and that is the
problem — a gate that produces the same output whether the hypothesis is true or false is not evidence for either,
so "it might be right" is not a defence of the instrument. And the standing FAIL is currently consuming context in
every single session for a finding nobody can act on, which is a real cost paid continuously.

**Count injections by having the agent report them.** Rejected outright and on the record: four shipped, tested,
exposed voluntary-write surfaces produced one real row in five months. Capture that asks the agent to volunteer does
not work here, and that lesson is why cairn was decommissioned in the first place.

**Widen the numerator to any mention of a memory filename anywhere in a transcript.** Rejected as filed — it counts
the agent *discussing* memory as the agent *using* it, which inflates toward a PASS. If a transcript-derived
numerator is built it must pin what it counts as precisely as the `Read` hook does, or it trades a numerator that is
too narrow for one that is too generous, which is worse because it will read as success.

**Lower the denominator instead (count only sessions where a memory file existed).** Rejected: it is the threshold
move wearing a different hat.

## Acceptance criteria

- [ ] The investigation's answer is written down in this directive or in a checkpoint the directive links: either
      an event/artifact that observes system-prompt injection and `<system-reminder>` recall, or an explicit "no
      such observation is available from this harness".
- [ ] If a numerator exists: the instrument is re-pointed at it, `bin/memory-hits-report` reports the new ratio
      against the UNCHANGED `< 0.2` bar, and a test asserts the numerator increments on a path where no `Read` tool
      call occurs — the mutation being to revert the instrument to `PostToolUse(Read)` only.
- [ ] If it does not: the launchd job, the verdict file and the `borg-link-down.sh` injection are removed, Phase 1.6
      of the cairn-decommission directive records the null result as unmeasurable, and
      `hooks/borg-memory-read-log.sh` survives as plain instrumentation with no verdict attached.
- [ ] `grep -n '0.2' bin/memory-hits-report hooks/borg-memory-read-log.sh` shows the threshold unchanged, whichever
      branch is taken. This criterion exists specifically so a future reader can confirm the bar was not bent.
- [ ] The re-nag policy is decided rather than inherited: `bin/borg-memory-gate` either re-notifies on a stated
      cadence or documents why once-ever is right, and the SessionStart injection is bounded or removed.
- [ ] `make test`, `make lint` and `bats tests/` all exit 0.
