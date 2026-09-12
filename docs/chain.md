# Chains — `borg chain` and the program manifests behind it

A **chain** is a declared ordering of pull requests, issues, and tickets that must land in a particular sequence —
often across more than one repository. `borg chain` is the command that finds those declarations, audits them against
reality, and writes them back out.

It appears in `borg help` and nowhere else: not in the command block in `CLAUDE.md`, not in `README.md`, not in
`docs/cheatsheet.md`, not in `docs/architecture.md`. This document is the reference.

---

## First, the naming

You will hit two words for one thing. Both are correct, and neither is a typo.

**`borg chain` is the 2026-08-31 rename of `borg program`** — AC7 decision (2) in `PROJECT_PLAN.md`. `borg program`
is now a tombstone that dies with a pointer:

```
$ borg program list
'borg program' was renamed to 'borg chain'. Run: borg chain list
```

The word *program* deliberately survives in two places:

- the manifest path, `<project>/.borg/programs/*.json`
- the flag, `--programs-dir`

Those are `coordinator.py`'s argparse tokens and the on-disk contract, and `borg.zsh` says so in a comment above
`cmd_chain`: they *"move with the merge-tree retirement, not with the verb."* **AC7 is still unticked** — the rename
of the verb has shipped, the sweep of the remaining surfaces has not. So: the verb is `chain`, the files are
`programs`, and both stay that way until AC7 closes.

It is also not `borg project` on purpose. `cmd_chain` resolves roots by reading `.projects[].path` from the registry,
where "project" means *repository*; naming the verb `project` would make the word mean two things at once until the
deferred `project` → `repository` rename lands.

---

## What the command does

```
borg chain list|plan|sync [--programs-dir <path>]...
borg chain plan [--recon <file>]
```

`borg chain` with no arguments is `borg chain list`. Any other action is a usage `die`.

`cmd_chain` is a thin, registry-resolving wrapper. The Python it calls — `merge-tree/coordinator.py` — is
registry-free by design (Architecture Rules: testable core, shell wrapper), so the shell side is where registry
knowledge lives. Its whole job is to turn every registered project path into a `--programs-dir` argument and then
exec:

```
PYTHONPATH=$BORG_HOME python3 $BORG_HOME/merge-tree/coordinator.py <action> --programs-dir … --programs-dir …
```

### The three actions

| Action | Writes? | What it does |
|--------|---------|--------------|
| `list` | no | Discovers every manifest under the swept roots and prints `<program>: N row(s)`, then a total. |
| `plan` | no | A three-way drift audit: borg's copy vs. the sync target's copy vs. reality. Reports, never resolves. |
| `sync` | yes | Rewrites every manifest through borg's own validating writer, then dispatches to a sync target. |

**`list`** is the cheap one. It prints one line per discovered chain plus `N chain(s), M skipped`. Manifests that
fail discovery are named on stderr as `MANIFEST SKIPPED …` — a bad file is skipped with a *named* warning rather
than blanking the sweep, and an unnamed skip would be indistinguishable from a file that was never there.

**`plan`** compares three copies of the truth and prints every disagreement as
`<kind>: <ref> — <copy_says> / <reality_says>`:

1. **borg's copy** — the rows in the manifests.
2. **the target's copy** — obtained by running the discovered sync target's own `plan` dry run, which by contract
   must not write anything. With no target found, it says so on stderr and audits borg's copy alone.
3. **reality** — item states from the `--recon` document. Omit `--recon` and the reality check is skipped entirely.

Nothing is auto-resolved. Per the coordinator's docstring, *"Negotiation here means naming which side a fix would
change, not applying one."* `plan` exits non-zero only when a manifest was malformed — and when that happens it also
prints a `CAVEAT` line on **stdout**, beside the findings, because an "absent from borg's copy" finding may be a
parse artifact rather than real drift.

**`sync`** refuses outright if any manifest is malformed (`refusing to sync`) — a half-written sync is the failure
it is guarding against. Otherwise it rewrites each manifest in place through `programs.write_manifest`, atomically
and idempotently, then dispatches to the sync target. Two behaviours worth knowing:

- Each manifest is rewritten to **its own filename**, never to a name derived from the `program` id — so a file whose
  name differs from its program id cannot spawn a second copy.
- Two files declaring the same program id are rewritten separately and the collision is reported as a named
  `SYNC WARNING`: they will contend downstream, and only a human knows which is right.

With no sync target installed, `sync` writes borg's own copy and exits 0. That is the intended state on a machine
with no target shim.

### The flags

**`--programs-dir <path>`** (repeatable) names a project root to sweep for `.borg/programs/*.json`. Passing it even
once **suppresses the registry sweep entirely** — you get exactly the roots you named:

```bash
borg chain list --programs-dir /Users/noah/dev/ingle --programs-dir /Users/noah/dev/reveal
```

With no explicit `--programs-dir`, `cmd_chain` reads `.projects[].path` from `$BORG_REGISTRY` and passes one
`--programs-dir` per registered project, so a bare `borg chain list` sweeps the whole collective. It dies early with
a pointer at `borg add` if the registry is missing or has no project paths.

**`--recon <file>`** is accepted **only with `plan`**, because argparse registers it on the `plan` subparser alone —
`cmd_chain` rejects it for `list` and `sync` in the shell rather than advertising a flag the Python would then
refuse. It takes a recon/gather JSON document, or `-` for stdin. Omitting it skips the reality leg of the audit.

Any other flag is an `unknown flag` die.

### The sync target

The external writer is **discovered, never hardcoded** — exactly like a recon adapter. It is any executable named
`borg-sync-target-<name>` found on `$BORG_SYNC_TARGET_PATH` (colon-separated) or, by default, in
`~/.config/borg/sync-targets`. Its contract:

```
borg-sync-target-<name> plan|sync
  stdin:  {"manifests": [<manifest>, ...]}
  stdout: {"ok": bool, "rows": [{"ref": "owner/repo#num", "status": "..."}], "note": "..."}
```

`plan` must not write; `sync` performs the write. `coordinator.py` itself writes nothing outside borg's own manifest
files and knows no field name from any external schema. No target installed is a supported, silent state.

### Examples

```bash
borg chain                                            # list across every registered project
borg chain list --programs-dir /Users/noah/dev/ingle  # one root only
borg chain plan                                       # drift audit, no reality check
borg chain plan --recon /tmp/gather.raw.json          # full three-way audit
borg recon --json | borg chain plan --recon -         # same, from a live sweep
borg chain sync                                       # rewrite manifests, dispatch to target
```

---

## The manifest format

Chains are declared in `<project>/.borg/programs/<name>.json`. This is **borg's own contract**, owned by
`merge-tree/SCHEMA.md`; it is not derived from or validated against any other tool's format.

### Why you have to write them by hand

`gather.derive_stacked_edges` can recover a stacked ordering from branch topology, because a stacked PR's base branch
is its parent's head branch. But a base branch is a repo-local name, so every derived edge is repo-local by
construction. Nothing in git or the GitHub API says `platform#834` must merge before `warehouse#302` — that ordering
*"exists only in the head of whoever planned the program, so it has to be declared"* (`merge-tree/SCHEMA.md`).

### Minimum viable manifest

Enough to hand-author one:

```json
{
  "program": "auth-hardening",
  "desc": "Rotate service credentials before the ingest cutover.",
  "rows": [
    {"order": "1", "ref": "noah-goodrich/platform#834"},
    {"order": "2", "ref": "noah-goodrich/warehouse#302"}
  ]
}
```

Two consecutive rows in the same lane become one `stacked` edge. That is the whole mechanism.

### Fields

| Field | Required | Meaning |
|-------|:--------:|---------|
| `program` | yes | The chain id. |
| `rows[].ref` | yes | The canonical item ref — `owner/repo#num` or a Jira key. Must be unique within the manifest. |
| `rows[].order` | yes | Declared merge position: `–` for an already-merged prerequisite, else `E1` / `I2` / `1`. |
| `rows[].lane` | no | A parallel track. Omit it on every row for single-stack mode. |
| `rows[].gate` | no | Why a row is parked. See below. |
| `apex` | no | `{"ref": …, "label": …}` — the chain's tracker issue. Omit on a small single-ticket chain. |
| `desc` | no | ONE plain sentence, rendered under the chain heading in chain views. |
| `note` | no | Free text, deliberately **not** rendered. |

Rows key on `ref` because `ref` is already the one canonical key everywhere in this schema — so declared edges need
no normalization, which removes a whole silent-failure class (a wrong transform yields edges matching no item, and
they vanish from the graph without raising).

### Gates

A `gate` records why a row is parked:

```json
{"order": "2", "ref": "noah-goodrich/warehouse#302",
 "gate": {"blocked_by": "waiting on a colleague's review",
          "kind": "decision",
          "resolved_by": "Dana signs off on the grant model",
          "blocked_by_ref": "noah-goodrich/platform#834"}}
```

- `kind` is **required** whenever a gate exists — an absent or blank `kind` is a defect on every reader. The two
  routed values are `decision` (a human must choose, so it blocks on a person) and `verification` (someone must run
  something, so it blocks on nobody in particular and must never be routed to an awaiting-you tier).
- `blocked_by` is **prose and stays prose** — it is never turned into an edge. String-matching it would invent
  dependencies. Unmapped gates are counted and reported instead.
- `blocked_by_ref` is the optional machine-readable companion and *does* produce a `blocks` edge. It must contain
  `#`. `blocks` edges do not group.
- `resolved_by` is mandatory alongside `blocked_by`: a blocker naming nothing that would unpark it is the defect the
  field exists to prevent.

**The two readers disagree about whether the `kind` set is closed, deliberately.** `merge-tree/programs.py` rejects a
third value; `borg_core/manifest/core.py` requires only that a gate *name* some kind, because `borg link`'s
`▸ NEXT` has an `unsure` group that reports an unrecognized kind on the page rather than deleting the row. See
`borg_core/manifest/core.py::_validate_gate`.

### Derivation rules, in one list

- Consecutive rows within a lane → a `stacked` edge. This is the only construct that can span repositories.
- Every row → an `apex` edge to `apex.ref`, when an apex exists. `apex` groups, so a multi-lane chain stays one
  workstream.
- Separate lanes never link. Lane ids are prefixed precisely so cross-lane rows imply no total order.
- On a duplicate edge, **declared wins** over derived: topology is an inference, a manifest row is stated intent.
- Conflicts (declared says A → B, topology says B → A) and dangling endpoints are counted and surfaced, never
  auto-resolved.

Validation reports **every** problem in one pass, so a manifest is fixed in one edit rather than N runs.

### Full spec

This section is the working subset. The complete contract lives in the two files below, and they are the only place
it is written down — nothing else in `docs/` links to them:

- **[`../merge-tree/SCHEMA.md`](../merge-tree/SCHEMA.md)** — the `data.json` / `story.json` / manifest schema,
  including the "Program manifests" section this summarizes, edge provenance, validation, and the planned but
  unimplemented row-level `after: [refs]` field.
- **[`../merge-tree/PROTOCOL.md`](../merge-tree/PROTOCOL.md)** — the action-dispatch protocol: how a `ref` plus a
  recommended action becomes a command, and the `readonly` / `confirm` guardrail tiers it reuses from bash-guard.

---

## Gotchas

- **`borg program` still exists as a tombstone.** It dies with a pointer rather than `unknown command`; that is
  AC7 decision (1), not an oversight.
- **`--programs-dir` is all-or-nothing.** One explicit root suppresses the registry sweep completely. There is no
  "registry plus this extra directory" mode.
- **`plan`'s exit code is about malformed files, not about drift.** Findings print and exit 0. A malformed manifest
  exits 1 — after the findings print, so one bad file never blanks the audit.
- **`sync` writes to your working tree.** It rewrites every discovered manifest in place, atomically, even when
  nothing changed. Expect `git status` to be clean only because the writer is idempotent, not because it skipped.
- **A stale registry entry is not fatal.** A registered project path that does not exist on this machine is a
  directory-level note, not a file-level warning, so it never vetoes a sync — the personal and work machines carry
  different project sets on purpose.
- **`borg chain` shells to `python3` directly**, not through `borg.zsh`'s `_borg_py` wrapper — it sets `PYTHONPATH`
  itself because `coordinator.py` imports its sibling `programs` module. It therefore does not inherit the config
  surface `_borg_py` exports; it does not need to, because the registry read happens in zsh before the exec.

## Unverified

- **Whether any `borg-sync-target-*` shim exists anywhere.** None is present in this repository, and the coordinator
  docstring says the shim *"lives outside this repo"*. Everything documented here about target behaviour is the
  contract the coordinator expects, not an observed implementation.
- **Which producer's output `--recon` is tuned for.** `load_recon_items` accepts either a bare items list or a full
  recon/gather document, and dies with a named message on an unreadable or unparsable file — but nothing read for
  this document pins whether `borg recon --json` or `merge-tree/gather.py` is the intended source. Both parse; only
  the item states keyed by `ref` are consumed.

## See also

- `borg help` — the only other place `chain` is documented today.
- [`vinculum.md`](vinculum.md) — the other live-but-undocumented subsystem.
