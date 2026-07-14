# Agent Routing Guide

**Principle: the expensive tier is opt-IN. Route to the cheapest tier that fits.**

Every unspecified subagent inherits the **main session model**. On this machine the session default is
**Fable 5** (`settings.json` → `model`), the single most expensive tier — pricier per token than Opus.
So an unspecified subagent is not "usually Opus" anymore; it is Fable 5, and a fan-out of them is the
fastest way to burn an allotment. Use this matrix to pick the right tier before spawning.

**Two spawn paths, one rule.** This guide governs BOTH:
- the **`Agent` tool** (`subagent_type:` — the borg specialists below carry their own `model:` frontmatter,
  so routing to them is already cheap); and
- the **`Workflow` tool** (`agent()` inside a workflow script — this path has NO default specialist and
  **inherits the session model unless you pass `model:`**). See "Model routing inside Workflow scripts"
  below. The workflow path is the one that silently runs Fable 5 at fan-out scale; it is the primary leak.

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
                              └── NO  → claude/general-purpose (Opus — LAST RESORT)
```

---

## Cost reference (current API rates, per million tokens)

| Model            | Input | Output | Cache read | Notes                                             |
|------------------|-------|--------|------------|---------------------------------------------------|
| Haiku 4.5        | $1    | $5     | $0.10      | Mechanical / read-only tier.                      |
| Sonnet 4.6       | $3    | $15    | $0.30      | Judgment / analysis / review tier.                |
| Opus 4.6+ (4.8)  | $5    | $25    | $0.50      | Open-ended reasoning; the intended orchestrator.  |
| **Fable 5**      | $10   | $50    | $1.00      | **Most expensive. The current session default.**  |

Two things changed from the old table and both matter: **Opus dropped ~3x** at the 4.6 generation
($15/$75 → $5/$25), and **Fable 5 now sits ABOVE Opus** at $10/$50. So the inherited-default tier is no
longer "expensive Opus" — it is *even-more-expensive Fable 5*. A Haiku subagent is ~10x cheaper on output
than Opus and ~50x cheaper than the inherited Fable 5 default. Routing a mechanical grep or a read-only
search to the inherited model instead of Haiku is the single most avoidable cost in a multi-agent session.
Cache reads of the growing orchestrator context usually dominate a long session — keep the main loop lean
(delegate verbose reads; don't pull large tool output into the orchestrator).

---

## Model routing inside Workflow scripts (the leak that burns the most)

The `Agent`-tool matrix above does NOT apply automatically inside a `Workflow` script. In a workflow,
`agent(prompt, opts)` spawns a generic worker that **inherits the session model (Fable 5) unless `opts.model`
is set**. A 30-agent fan-out with no `model:` is 30 Fable 5 agents — the exact pattern that trips session and
weekly limits. Treat an `agent()` call with no `model:` as a bug in any workflow that is not doing genuinely
open-ended reasoning in that stage.

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
- **Only the last row justifies inheriting Fable 5.** If you can write a clear brief for the stage, you do not
  need the inherited tier — pass `sonnet`. Reserve the inherited (session) model for the one or two stages that
  truly cannot be briefed.
- **The gate stage is worth Sonnet-high, not Fable.** A verifier/reviewer that guards a deliverable should be
  the strongest *cheap* tier (`sonnet` + `effort:'high'`), not the inherited default — independence and rigor
  come from the blind setup and the high effort, not from spending the top tier.

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
