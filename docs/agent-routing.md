# Agent Routing Guide

> Lives in `docs/`, not `agents/`: a file in `agents/` registers as a spawnable agent type and is never
> injected into context. The short card is injected at SessionStart by `hooks/borg-link-down.sh`; the
> `Workflow` guard `hooks/borg-workflow-model-guard.sh` enforces the workflow rule below.

**Principle: the expensive tier is opt-IN. Route to the cheapest tier that fits.**

Every unspecified subagent inherits the **main session model**. On this machine the session default is
**Opus 5** (`opus[1m]`, `settings.json` → `model`). An unspecified subagent therefore inherits Opus 5, not a
cheap tier — still pricier than pinning Haiku or Sonnet for mechanical or judgment-tier work. Use this
matrix to pick the right tier before spawning rather than letting a stage silently inherit the default.

**Two spawn paths, one rule.** This guide governs BOTH:
- the **`Agent` tool** (`subagent_type:` — the borg specialists below carry their own `model:` frontmatter,
  so routing to them is already cheap); and
- the **`Workflow` tool** (`agent()` inside a workflow script — this path has NO default specialist and
  **inherits the session model unless you pass `model:`**). See "Model routing inside Workflow scripts"
  below. The workflow path is the one where an unpinned fan-out quietly runs the full session model
  (Opus 5) at scale instead of a cheaper pinned tier.

---

## Routing Matrix

| Agent            | Model  | Effort | Use when                                                      | Do NOT use when                                      |
|------------------|--------|--------|---------------------------------------------------------------|------------------------------------------------------|
| **borg-grunt**   | Haiku  | low    | Executing a fully-specified change: apply an edit, run tests, | The spec is ambiguous, requires judgment, or may      |
|                  |        |        | grep logs, rote refactor. One task, zero judgment calls.       | expand. Escalate to nanoprobe instead.               |
| **borg-scout**   | Haiku  | low    | Read-only locate/search: "where is X?", "does Y exist?",      | You need to write or edit anything. Scout is          |
|                  |        |        | "what naming convention?". Returns locations + excerpts.       | strictly read-only.                                  |
| **borg-nanoprobe** | Sonnet | medium | Single discrete task that requires judgment: implement a      | The task spans multiple unrelated concerns or needs   |
|                  |        |        | feature, fix a bug, write a test, refactor with discretion.   | open-ended exploration. Split it first.              |
| **borg-researcher** | Sonnet | medium | From-zero web research on ONE track. Fetches primary sources, | You already have the answer or can derive it from    |
|                  |        |        | verifies claims, writes a structured findings doc.             | the repo — don't burn web fetches on known facts.   |
| **borg-reviewer** | Sonnet | high   | Independent blind adversarial review of a proposal or         | You want a collaborator. Reviewer arrives cold and   |
|                  |        |        | option-set. Catches what self-review misses.                   | does not see author reasoning — that's the point.   |
| **claude** / general-purpose | Opus | (inherited) | Hard open-ended reasoning with no clear decomposition:  | Any task that fits a specialist above. Opus is the   |
|                  |        |        | novel architecture, complex multi-step inference, tasks where  | EXCEPTION, not the default. Defaulting here for      |
|                  |        |        | the orchestrator cannot write a clear spec.                    | routine work is the primary cost driver.             |

**borg-scout can read git and GitHub state.** It answers "what is the state of PR X?" and "what changed in
commit Y?" via read-only `git` and `gh` (log/show/diff/status/blame/grep/ls-files/rev-parse, branch list,
remote -v, worktree list; pr view/list/diff/checks, issue view/list, run view/list, repo view, api GET). This is
enforced, not requested: `hooks/borg-scout-guard.sh` denies any other Bash command when the caller is scout.

---

## Decision tree

```
Is the task fully specified (no judgment calls)?
├── YES → can a read-only search answer it?
│         ├── YES → borg-scout (Haiku)
│         └── NO  → borg-grunt (Haiku)
└── NO  → does it require web research from zero?
          ├── YES → borg-researcher (Sonnet)
          └── NO  → is it a blind adversarial review?
                    ├── YES → borg-reviewer (Sonnet/high)
                    └── NO  → is it a single-task with judgment?
                              ├── YES → borg-nanoprobe (Sonnet)
                              └── NO  → claude/general-purpose (Opus 5 — LAST RESORT, also the
                                        inherited session default)
```

---

## Cost reference

Prices go stale with every model generation, so none are listed here. Check current rates before quoting
one. The durable facts: Haiku is the cheap mechanical tier, Sonnet the judgment tier, Opus the session
default and the most expensive tier you should inherit by accident, and any model above Opus must be
selected deliberately, never inherited. Routing a mechanical grep or read-only search to the inherited
model instead of Haiku is the most avoidable cost in a multi-agent session. Cache reads of the growing
orchestrator context usually dominate a long session, so keep the main loop lean (delegate verbose reads;
don't pull large tool output into the orchestrator).

---

## Model routing inside Workflow scripts

The `Agent`-tool matrix above does NOT apply automatically inside a `Workflow` script. In a workflow,
`agent(prompt, opts)` spawns a generic worker that **inherits the session model 
unless `opts.model` is set**. A 30-agent fan-out with no `model:` is 30 Opus agents — wasteful for
mechanical or judgment-tier work even though it is no longer the Fable-5-scale cost bomb it briefly was.
Treat an `agent()` call with no `model:` as a bug in any workflow that is not doing genuinely open-ended
reasoning in that stage.

**Rule: every `agent()` call sets a namespaced `agentType:` (e.g. `'borg-collective:borg-scout'`) OR an explicit `model:` plus `effort:`.** `CLAUDE_CODE_SUBAGENT_MODEL` does NOT reach `agent()`; an unpinned call inherits the session model AND session effort. `hooks/borg-workflow-model-guard.sh` denies unpinned calls; put `/* inherit-ok */` inside a call to inherit on purpose. Pick with the same
logic as the matrix:

| Stage kind                                                        | `model:`    | `effort:` |
|-------------------------------------------------------------------|-------------|-----------|
| Mechanical: extract/reformat, run tests, grep, rote file edits    | `'haiku'`   | `'low'`   |
| Read-only locate/inventory across a repo                          | `'haiku'`   | `'low'`   |
| Analysis, synthesis, writing a findings/section draft             | `'sonnet'`  | (default) |
| From-zero web research on one track                               | `'sonnet'`  | (default) |
| Blind adversarial review / verification gate that guards a merge  | `'sonnet'`  | `'high'`  |
| Genuinely open-ended reasoning with no writable spec (rare)       | omit (inherit) | `'high'` |

- **Compose with the specialists.** `agent(prompt, { agentType: 'borg-collective:borg-scout' })` reuses a borg specialist
  (and its cheap model) from inside a workflow — prefer this for search/locate stages so the model choice and
  the system prompt both come from the specialist definition.
- **Only the last row justifies inheriting the session default.** If you can write a clear brief for the
  stage, you do not need the inherited tier — pass `sonnet`. Reserve the inherited (session) model, currently
  Opus, for the one or two stages that truly cannot be briefed.
- **The gate stage is worth Sonnet-high, not the inherited default.** A verifier/reviewer that guards a
  deliverable should be the strongest *cheap* tier (`sonnet` + `effort:'high'`), not the inherited Opus
  default — independence and rigor come from the blind setup and the high effort, not from spending the top
  tier.

## Practical tips

- **Grunt before nanoprobe.** If the orchestrator has already written a precise spec, dispatch
  a grunt. If the spec still needs refinement, write the spec first, then dispatch.
- **Scout before reading.** When you need to locate something before editing, send a scout
  rather than reading files in the main loop — keeps the orchestrator context lean.
- **Parallelize grunts and scouts freely.** They are cheap and stateless; fan-out is encouraged.
- **One nanoprobe per concern.** If a task touches unrelated files or systems, split it into
  multiple nanoprobes rather than one large one.
- **Reviewer always arrives cold.** Do not prime the reviewer with the author's reasoning; the
  adversarial value comes from genuine independence.
- **Reserve Opus for genuine need.** If you can write a clear brief for a specialist, you do
  not need Opus. Spawn Opus only when the task is genuinely open-ended and no brief is possible.
