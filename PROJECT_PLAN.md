# Project Plan: Research Gap Close — Cairn Enrichment, Evidence Gate, Borg Watch
*Established: 2026-05-27*

## Objective
Close three research-identified gaps: (1) enrich cairn session records at Stop with structured
content from transcript and git state; (2) upgrade the SubagentStop hook to score nanoprobe
evidence quality before logging completion; and (3) add `borg watch` as a live-refresh display
of project status + recent nanoprobes.

## Acceptance Criteria
- [ ] Cairn enrichment — `borg-link-up.sh` parses `transcript_path` from hook input, reads the
      last assistant message (capped at 20KB from end of file), and calls
      `cairn record session --notes "<git log --oneline -3>\n<last assistant message>"`. When
      `transcript_path` is absent, empty, or unreadable, and when cairn is unavailable, falls
      through silently and exits 0.
  - Verify: `cairn.bats` — mock transcript with known assistant message; confirm `--notes`
    contains git log output
- [ ] Evidence gate — `borg-nanoprobe-log.sh` checks `last_assistant_message` for file-path
      citations (`\w+\.\w+:\d+` pattern). Appends `"evidence_found": bool, "evidence_score": 0–3`
      to the agents.jsonl record. Prints one-line stderr warning when `evidence_found` is false.
  - Verify: `tests/nanoprobe.bats` — message with `lib/foo.sh:42` → score ≥ 1; generic
    summary → score 0, stderr contains "no evidence"
- [ ] `borg watch [interval]` — new command in `borg.zsh` that clears screen and prints `borg ls`
      output + last 5 nanoprobes on a configurable interval (default 5s). `borg help` includes
      `watch`.
  - Verify: `borg help | grep -q watch`; manual smoke confirms refresh loop
- [ ] No regressions — all existing bats tests pass.
  - Verify: `bats tests/`

## Scope Boundaries
- NOT building: Cairn service health fixes — availability failures are a service issue, not a hook issue
- NOT building: Fancy TUI for `borg watch` — v1 is a `tput clear` polling loop
- NOT building: Evidence gate that blocks or retries nanoprobes — advisory only, always exits 0
- NOT building: Tiered model selection (Gap 5) or Agent Teams hooks (Gap 4)
- If done early: ship what we have, don't expand scope.

## Ship Definition
CLI tool: committed to `main` + `bats tests/` green + manual smoke of all three features
(run `borg watch` for 10s, trigger stop hook, verify agents.jsonl has `evidence_found` field).
No version bump — no on-disk schema changes.

## Timeline
Target: this session
Estimated effort: ~2.5 hours (evidence gate 40m, cairn enrichment 50m, borg watch 30m, tests 30m)

## Risks
- Transcript path may be absent/empty in CoCo sessions or crash sessions — guard every access
- Large transcripts (10MB+) would slow the Stop hook — `tail -c 20000` cap is non-negotiable
- `cairn record session --notes` flag — confirmed from cairn.bats, verify with smoke during impl
