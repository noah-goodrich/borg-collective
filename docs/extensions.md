# Local extensions

A local extension is a markdown file that layers machine-specific or project-specific instructions
onto a skill or an agent, without that content living in this repository. Missing files are skipped
silently; markdown only, no executable scripts.

This repository is **public** and was history-scrubbed once to remove employer references. The
extension layer is the mechanism that stops that recurring — content naming an employer's internal
tools, tickets or plugins belongs in a machine-local extension, never in a checked-in file.

## The two layers

Every extension is looked for in both, in this order:

1. `~/.config/borg/extensions/<kind>/<subject>/<hook>.md` — per machine
2. `<project root>/.borg/<kind>/<subject>/<hook>.md` — per project

`<kind>` is `skill-extensions` or `agent-extensions`. Keep extension files terse: they load on every
invocation of their subject.

## Load points

**Skills get three**, mapped to positions in the skill's own flow rather than to anything
domain-specific — which is why the same three names fit a planning conversation and a shipping
checklist equally:

| hook | when |
|---|---|
| `01-context` | before any work |
| `02-output` | before the artifact is produced |
| `03-followup` | after the artifact lands |

| subject | hooks | note |
|---|---|---|
| `borg-plan` | all three | |
| `borg-assimilate` | all three | |
| `borg-link-up` | all three | |
| `borg-review` | `01-context`, `02-output` | **no `03-followup`, on purpose** — see below |

`borg-review` has no `03-followup` because its entire contract is to end on exactly ONE action, and
a hook that runs after the recommendation invites a second. Post-review behaviour belongs in the
skill the recommendation points at.

**Agents get one.** An agent has no phases: it has a brief consumed once at spawn, a scope gate, and
a return contract. There is no "before the artifact" moment to hook.

| subject | hook | note |
|---|---|---|
| `borg-nanoprobe` | `brief` | read before the scope gate, which is **not** extensible — see below |

The nanoprobe's scope gate is **not** extensible: an extension may add instructions, but never
widen what the agent may touch, raise its deliverable ceiling, or relax bounded termination.

## The `prefer-tool` type

A `prefer-tool` extension says *use tool X instead of the default*. A file becomes this type by
carrying a `- Prefer-tool:` line; everything without one is prose, so every extension that existed
before this type parses unchanged.

```markdown
- Prefer-tool: `dev-workflow:create-pr`
- Instead-of: `gh pr create`
- Requires: `skill:dev-workflow:create-pr`

When creating a PR, delegate to `dev-workflow:create-pr` rather than calling `gh pr create`
directly. That skill exposes a `pr_default_draft` userConfig boolean, so the draft-PR policy is
configuration instead of prose repeated across skills.
```

| key | meaning |
|---|---|
| `- Prefer-tool:` | the tool to use. Presence makes the file this type |
| `- Instead-of:` | the default it displaces; matched against shell commands |
| `- Requires:` | what must exist for the preference to be live: `command:<name>` or `skill:<plugin>:<name>` |

Keys are anchored on the leading `- `. An extension file is prose that will often discuss its own
keys, and an unanchored match returns the sentence doing the discussing.

### Precedence — the layer that owns the fact wins

One rule, not a per-type exception, so a reader can predict what a file does without knowing its
type. The question to answer for any future type is: **who owns the fact being asserted?**

| the extension asserts | owner | winner |
|---|---|---|
| project policy ("plans here cite a ticket") | the project | **repo** — binds everyone who works on it |
| environment ("this machine makes PRs via X") | the machine | **machine** — a public repo cannot know this machine |

So prose keeps the existing behaviour (repo layered after machine, repo wins) and `prefer-tool`
inverts it — not as a special case, but because its subject is the environment. A conflict is
reported only when both layers assert the *same* key, and reported once.

### What it may and may not do

It **advises in prose**. It does not redirect a call. Silently rewriting the command that runs would
break the standing posture that skills propose and the developer validates, and its failure mode
would be invisible — which is the property every defect in this area has shared. The escalation path
if advice proves insufficient is a `PreToolUse` **warning** (the surface `hooks/bash-guard.sh`
already occupies), never a rewrite.

### When the preferred tool is absent

Degrade to the default, **loudly, once**. Not silently: a dead preference nobody is told about reads
as working. Not fatally: a missing personal plugin must never break the action it was advising on.

The loader reads markdown and cannot know what "tool X" means, so the precondition cannot live in
the loader — which is why `- Requires:` exists and why this type is not pure prose. A `prefer-tool`
extension with no parseable `- Requires:` is reported as `unprobed`, **not** live: it has opted out
of being checked and must not be reported as working.

Check with:

```
borg doctor                                    # dead and unprobed preferences appear here
python3 -m borg_core.extensions.cli survey     # or --json
```

### The oracle, and what it does not measure

Prose is ignorable. Per CLAUDE.md's cairn entry this repository has already measured what
uninstrumented voluntary compliance is worth — four shipped, tested, exposed surfaces produced
**one** real row in five months, and the rule drawn from it was *never build capture that asks the
agent to volunteer*. So the type ships with a number attached.

`hooks/borg-prefer-tool-log.sh` (PostToolUse/Bash) appends one line to
`~/.config/borg/prefer-tool.jsonl` whenever a shell command matches a **live** preference's
`- Instead-of:` pattern.

**It witnesses bypasses only.** Invoking the preferred *skill* is not a Bash call and leaves no
trace on that surface, so compliance events are unobservable there. A rising bypass count means the
preference is not working; an empty log means either it is working or nobody performed the action.
Nothing computes a ratio, because calling this a "compliance rate" would be the same overclaim as a
gate that passes by measuring nothing.
