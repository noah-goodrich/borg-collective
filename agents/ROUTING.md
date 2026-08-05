# Agent Routing Guide

**Principle: the expensive tier is opt-IN. Route to the cheapest tier that fits.**

Every unspecified subagent inherits the **main session model**. On this machine the session default is
**Opus 4.8** (`settings.json` → `model`). An unspecified subagent therefore inherits Opus 4.8, not a
cheap tier — still pricier than pinning Haiku or Sonnet for mechanical or judgment-tier work. Use this
matrix to pick the right tier before spawning rather than letting a stage silently inherit the default.

**Two spawn paths, one rule.** This guide governs BOTH:
- the **`Agent` tool** (`subagent_type:` — the borg specialists below carry their own `model:` frontmatter,
  so routing to them is already cheap); and
- the **`Workflow` tool** (`agent()` inside a workflow script — this path has NO default specialist and
  **inherits the session model unless you pass `model:`**). See "Model routing inside Workflow scripts"
  below. The workflow path is the one where an unpinned fan-out quietly runs the full session model
  (Opus 4.8) at scale instead of a cheaper pinned tier.

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
                              └── NO  → claude/general-purpose (Opus 4.8 — LAST RESORT, also the
                                        inherited session default)
```

---

## Cost reference (current API rates, per million tokens)

| Model            | Input | Output | Cache read | Notes                                             |
|------------------|-------|--------|------------|---------------------------------------------------|
| Haiku 4.5        | $1    | $5     | $0.10      | Mechanical / read-only tier.                      |
| Sonnet 4.6       | $3    | $15    | $0.30      | Judgment / analysis / review tier.                |
| **Opus 4.6+ (4.8)** | $5 | $25    | $0.50      | **Current session default** — the intended orchestrator tier, and what any unspecified subagent inherits. |
| Fable 5          | $10   | $50    | $1.00      | Most expensive; opt-in only, never the inherited default. |

Two things matter here: **Opus dropped ~3x** at the 4.6 generation ($15/$75 → $5/$25), which is why it is
now the session default rather than an emergency-only tier; and **Fable 5 sits ABOVE Opus** at $10/$50, so
it must be selected deliberately — it is never something a session or workflow inherits by accident. A
Haiku subagent is still ~10x cheaper on output than the inherited Opus 4.8 default. Routing a mechanical
grep or a read-only search to the inherited model instead of Haiku is the single most avoidable cost in a
multi-agent session. Cache reads of the growing orchestrator context usually dominate a long session —
keep the main loop lean (delegate verbose reads; don't pull large tool output into the orchestrator).

---

## Model routing inside Workflow scripts

The `Agent`-tool matrix above does NOT apply automatically inside a `Workflow` script. In a workflow,
`agent(prompt, opts)` spawns a generic worker that **inherits the session model (currently Opus 4.8)
unless `opts.model` is set**. A 30-agent fan-out with no `model:` is 30 Opus 4.8 agents — wasteful for
mechanical or judgment-tier work even though it is no longer the Fable-5-scale cost bomb it briefly was.
Treat an `agent()` call with no `model:` as a bug in any workflow that is not doing genuinely open-ended
reasoning in that stage.

**Rule: every `agent()` call carries an explicit `model:` (and usually an `effort:`).** Pick with the same
logic as the matrix:

| Stage kind                                                        | `model:`    | `effort:` |
|-------------------------------------------------------------------|-------------|-----------|
| Mechanical: extract/reformat, run tests, grep, rote file edits    | `'haiku'`   | `'low'`   |
| Read-only locate/inventory across a repo                          | `'haiku'`   | `'low'`   |
| Analysis, synthesis, writing a findings/section draft             | `'sonnet'`  | (default) |
| From-zero web research on one track                               | `'sonnet'`  | (default) |
| Blind adversarial review / verification gate that guards a merge  | `'sonnet'`  | `'high'`  |
| Genuinely open-ended reasoning with no writable spec (rare)       | omit (inherit) | `'high'` |

- **Compose with the specialists.** `agent(prompt, { agentType: 'borg-scout' })` reuses a borg specialist
  (and its cheap model) from inside a workflow — prefer this for search/locate stages so the model choice and
  the system prompt both come from the specialist definition.
- **Only the last row justifies inheriting the session default.** If you can write a clear brief for the
  stage, you do not need the inherited tier — pass `sonnet`. Reserve the inherited (session) model, currently
  Opus 4.8, for the one or two stages that truly cannot be briefed.
- **The gate stage is worth Sonnet-high, not the inherited default.** A verifier/reviewer that guards a
  deliverable should be the strongest *cheap* tier (`sonnet` + `effort:'high'`), not the inherited Opus 4.8
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
