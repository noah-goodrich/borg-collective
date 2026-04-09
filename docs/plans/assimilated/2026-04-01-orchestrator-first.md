# Project Plan: Orchestrator-First Borg
*Established: 2026-04-01*
*Shipped: 2026-04-02 — PR #9 merged to main*

## Objective
Make the borg orchestrator session self-contained by exposing navigation/dashboard/search commands
as skills, fix silent cairn failures with health checks and warnings, default to LLM summaries when
cairn is empty, streamline existing skills for lower token overhead, and add automated tests for the
full context lifecycle.

## Acceptance Criteria
- [x] Orchestrator skills exist for: next, ls, switch, brief, search, refresh, status
- [x] `borg refresh` defaults to LLM summaries when cairn has no data for a project
- [x] Cairn health check at session start warns visibly when cairn is unreachable or has no data
- [x] Cairn write failures are surfaced, not silently swallowed
- [x] Existing skills reviewed and streamlined for token efficiency
- [x] Automated bats tests cover context lifecycle
- [x] Automated bats tests cover cairn integration
- [x] All pre-existing tests still pass (64/64)

## Additional Work Shipped (bug fixes from testing)
- drone claude/feature/up focus + zoom Claude pane
- Ctrl+Space > silent switch (no interstitial text)
- Phantom "dev" project fix (orchestrator CWD)
- Merged borg scan + refresh into single command
- Added borg down (universal teardown) and borg briefing
- Click-to-focus notifications via terminal-notifier
- Extracted get_bottom_pane helpers, batched registry I/O
