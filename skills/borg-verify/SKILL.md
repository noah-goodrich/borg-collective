---
name: borg-verify
description: >
  Independent pre-merge evaluator gate. Spawns a fresh reviewer subagent to re-run tests,
  map acceptance criteria to diff evidence, and issue a structured PASS/FAIL verdict before
  gh pr merge. Call after a nanoprobe completes and before merging its PR.
user-invocable: true
---

# Borg Verify — Independent Pre-Merge Evaluator Gate

You are the orchestrator running this gate **before** merging a nanoprobe's PR. You are NOT the
worker. Do not reuse the worker's reasoning. Spawn a single, independent reviewer.

## When to call /borg-verify

Call after a nanoprobe signals completion and before `gh pr merge`. The gate is cheap; run it
every time unless the skip conditions below apply.

## Skip / Degrade Rules (check first)

| Condition | Action |
|-----------|--------|
| Diff is docs-only (`.md`, `.txt`, `.rst` only) | Skip gate entirely — no verdict needed |
| Single-line change, no logic touched | Skip gate entirely |
| No `PROJECT_PLAN.md` and no inline ACs | Run scope + tests only (advisory, cannot FAIL) |
| Verification command absent / unknown | Report "unverifiable" — do NOT issue FAIL |

If skipping, say so in one line and proceed to merge.

## Step 1: Gather Inputs

Before spawning the reviewer, collect:

1. **Diff** — `gh pr diff <PR-number>` or `git -C <repo> diff main...<branch>`. Full patch text.
2. **Acceptance criteria (ACs)** — from `<repo>/PROJECT_PLAN.md` (the "Acceptance criteria"
   section) or passed inline by the orchestrator. If neither exists, note "no ACs — scope+tests
   only".
3. **Verification command** — from `PROJECT_PLAN.md` ("verification" line) or from `CLAUDE.md`
   (devcontainer pattern: `drone exec <project> -- <cmd>`). If absent, note "unverifiable".
4. **Project name** — registry name for `drone exec` calls.

## Step 2: Spawn ONE Independent Reviewer

Spawn a single fresh `borg-nanoprobe` subagent in **reviewer mode**. Pass ONLY:

- The full diff text (not the worker's transcript or reasoning).
- The ACs list (or "none").
- The verification command (or "none").
- The project name (for `drone exec`).
- The reviewer prompt below (inline — no separate agent file needed).

**Reviewer prompt (pass verbatim as the subagent's task):**

```
You are an independent code reviewer. You did NOT write this diff. You must NOT edit any files.
Your job: judge whether this diff is safe to merge.

INPUTS supplied by the orchestrator:
  DIFF: <full diff text>
  ACCEPTANCE CRITERIA: <ACs or "none">
  VERIFICATION COMMAND: <cmd or "none">
  PROJECT NAME: <name>

DO the following in order:

1. RE-RUN VERIFICATION (if command is not "none"):
   Execute: <verification command>
   Record: ran=true/false, green=true/false. A non-zero exit = green:false.
   Do NOT trust the worker's claim — run it yourself.

2. MAP ACs TO DIFF (skip if ACs are "none"):
   For each acceptance criterion, find evidence in the diff.
   Status: met | partial | unmet
   Evidence: the specific file:line or diff hunk that proves it.

3. SCOPE CHECK:
   Flag any change that touches files the task did NOT require (check for "Do NOT touch" notes
   in CLAUDE.md if accessible). Flag lockfiles, generated artifacts, secrets, debug output left in.

4. REGRESSION SCAN:
   Check for: deleted exports used elsewhere, broken imports, hardcoded secrets, TODO/FIXME/debug
   left in production paths, obvious type errors in changed signatures.

5. RETURN this exact JSON (no extra text before or after):

{
  "verdict": "PASS" | "PASS_WITH_NITS" | "FAIL",
  "ac_results": [
    {"criterion": "<text>", "status": "met|partial|unmet", "evidence": "<file:line or hunk>"}
  ],
  "tests": {"ran": true|false, "green": true|false, "command": "<cmd>"},
  "scope_violations": ["<description>" ...],
  "findings": [
    {"severity": "error|warning|nit", "file_line": "<file:line>", "issue": "<description>"}
  ],
  "summary": "<one sentence>"
}

VERDICT RULES:
- FAIL if: any AC is "unmet", tests.green=false, scope_violations is non-empty, or any
  finding with severity="error" exists.
- PASS_WITH_NITS if: all ACs met or partial, tests green, no errors, but nit-level findings exist.
- PASS if: all ACs met, tests green, no findings.
- If ACs are "none": FAIL only on test failure or error-severity findings; otherwise PASS or
  PASS_WITH_NITS.
```

## Step 3: Parse Verdict and Gate

Read the reviewer's JSON output. Apply the gate:

**PASS**
- Log: "borg-verify: PASS — <summary>"
- Proceed to `gh pr merge`.

**PASS_WITH_NITS**
- Log nits (advisory only): list each `nit`-severity finding.
- Proceed to `gh pr merge`. Nits are not blockers.

**FAIL**
- Block merge. Do NOT call `gh pr merge`.
- Report to the worker (or spawn a fresh fixer nanoprobe) with `findings` as the task brief.
- After the fix, re-run /borg-verify on the updated diff.
- **CEILING: 2 fix iterations maximum.** Track with a counter starting at 0.
  - Iteration 1 FAIL → fix attempt 1 → re-verify.
  - Iteration 2 FAIL → fix attempt 2 → re-verify.
  - **3rd FAIL: STOP. Do NOT loop further.** Escalate to the human:
    "borg-verify: 3 consecutive FAIL verdicts on <branch>. Human review required.
     Last findings: <findings list>. Branch is NOT merged."
  - Never debate the verdict with the reviewer. Never ask for a softer verdict.

## Output to Orchestrator

After the gate resolves (merge or escalation), report:

```
borg-verify: <PASS|PASS_WITH_NITS|FAIL|ESCALATED>
  PR: #<number> (<branch>)
  Tests: <ran/green or skipped>
  ACs: <N met, M partial, K unmet> (or "no ACs — scope+tests only")
  Findings: <count> (<error/warning/nit breakdown>)
  Iterations: <n of 2>
  Action: <merged | blocked — fix iteration N | escalated to human>
```

## Rules

- The reviewer is NEVER the worker. Always a fresh spawn. Single-agent self-critique degenerates.
- The reviewer NEVER edits files. Read-only + run tests only.
- The existing SubagentStop citation hook remains the always-on floor; this gate is additive.
- Bounded termination: 2-iteration ceiling is hard. No exceptions, no judgment calls.
- Nits are advisory. Do not block on nits. Log them so the next session can clean them up.
