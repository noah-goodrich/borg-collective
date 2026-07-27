# PR Control Hub — action-dispatch protocol

Ratified in [borg#97](https://github.com/noah-goodrich/borg-collective/issues/97). This is the contract between the
rendered hub (a menu) and the orchestrator (the executor): how a `ref` + recommended action becomes a concrete
command that actually runs.

## The hub is a menu; the orchestrator is the executor

The page never runs anything itself. It surfaces, per item, a `ref` (`repo#num` or a Jira key) and a recommended
next action. Noah says "do `<ref>`", and the orchestrator looks up and runs the *real* command for that item —
`gh`, Jira, permifrost, Cortex, Slack, whatever the action actually is.

## Action shape

```
actions[ref] = { label: string, command: string, class: "readonly" | "confirm" }
```

- `label` — human-readable recommended action, shown on the node (`.action` block in `render.py`).
- `command` — the literal command to run for this `ref`. Rendered as click-to-copy `<code>` in the hub so it can
  be pasted straight into a terminal, and it's exactly what the orchestrator would run when dispatching.
- `class` — the guardrail tier. See below.

If an item has `action_needed` but no entry in `actions`, the label still renders (from `Item.action_needed`) but
there is no command to dispatch — that's a valid state for items that need a human decision with no scriptable
follow-up.

## Guardrail: `readonly` vs `confirm`

`class` **reuses the existing bash-guard readonly-vs-confirm classification** — this protocol does not invent a new
classifier, and the line between the two tiers is the one already enforced and recently hardened elsewhere in the
orchestrator's command-guard layer.

- **`readonly`** — read-only or prep actions (viewing a diff, re-running a check, drafting a comment). Runs freely
  when dispatched; no confirmation step.
- **`confirm`** — outward-facing or prod-affecting actions (merging, approving, applying a Snowflake grant, pushing
  to a shared surface like a GitHub Project board). Requires an explicit confirm before the orchestrator executes
  it, even when Noah names the `ref` directly.

When classifying a new action type, ask: does this change something outside the local session (a merge, a grant, a
push others will see, a prod resource)? If yes, `confirm`. Otherwise `readonly`.

## Buckets are curation output, not protocol input

The four buckets (`needs-you`, `active-chains`, `standalone`, `collapsed-noise`) and `urgency` are produced by the
curation pass that builds `data.json` — see SCHEMA.md. The dispatch protocol only cares about `ref` → `Action`; it
does not re-derive bucket or urgency, and dispatching an action never changes an item's bucket (that only changes
on the next gather + curation run).

## Annotation-informed dispatch (optional, machine-local)

When `annotations.local.json` is present, the orchestrator should consult an item's `history[]` before dispatching
— specifically to avoid re-suggesting an action that was already attempted and failed. This is advisory: the
protocol's `action → command → class` contract does not change based on annotation presence, and dispatch must work
identically with annotations absent.

## Non-goals

- No new classifier, no per-action bespoke guardrail logic — one `readonly`/`confirm` tag, reused.
- No implicit chaining — dispatching one `ref`'s action does not automatically dispatch a dependent `ref`'s action,
  even across a `stacked` edge. Each dispatch is a single, explicit, Noah-named action.
