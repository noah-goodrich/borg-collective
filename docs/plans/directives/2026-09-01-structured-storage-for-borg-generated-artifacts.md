# Directive: Structured storage for borg-generated artifacts

*Filed: 2026-09-01*

**tl;dr** — Every artifact borg generates is a loose file with no write-time constraints, so each writer re-implements
validation and each one gets it slightly wrong. A storage layer with real constraints gives "the write fails and the
agent must fix it" for free, once, for every writer. This is filed rather than executed because it is a strictly
larger question than the validation bug that surfaced it, and it must not be decided as a side effect of AC7's writer
port.

## Why this exists

The trigger was narrow. AC5 makes three lifecycle skills author chain manifests by default, which means the primary
author of `<repo>/.borg/programs/*.json` stops being a careful human and becomes a model. Asked how to stop an invalid
manifest reaching disk, a four-track design council returned a five-layer, ~600-line perimeter: a CLI seam, a
`PreToolUse` hook, a recovery-receipt log, a case-drift check, and a `bash-guard` clause.

Noah's pushback was the correct one and is the reason this file exists:

> "Isn't this what databases are designed to do? ... why is it so hard to code defensively so that writes fail if the
> json fails to validate? And if the writes fail, then we bubble that back up and force the agent to fix it before
> moving on?"

Both halves land. The defensive write is ~30 lines and shipped as `shell.write_manifest`. The five-layer perimeter
existed only because **there is no single write path** — a skill can bypass any writer by using the Write tool on a
raw file. Every layer past the writer was defending a door that does not exist. A storage layer with constraints is
the version of that door you cannot walk around, and it is the thing a database has done since 1970.

### What is actually loose today

Measured across the 21 registered projects that have a `.borg/` directory:

| artifact | where | writer | write-time validation |
| --- | --- | --- | --- |
| chain manifests | `<repo>/.borg/programs/*.json` | `borg_core.manifest.shell.write_manifest` | yes, as of 2026-09-01 |
| checkpoints | `<repo>/.borg/checkpoints/*.md` | the `/borg-link-up` skill, free-form | none |
| per-project status | `<repo>/.borg/state.json` | hooks, direct writes | none |
| registry | `~/.config/borg/registry.json` | `lib/registry.zsh`, atomic tmp+mv | shape only |
| nanoprobe runs | `~/.config/borg/agents.jsonl` | `hooks/borg-nanoprobe-log.sh` | none |
| memory-read log | `$BORG_DIR/memory-hits.log` | `hooks/borg-memory-read-log.sh` | none |
| token spend | `~/.claude/token-spend.jsonl` | external | none |
| debriefs, notes, inbox, knowledge, plans | `<repo>/.borg/*` | assorted | none |

Every row but the first re-answers "is this well-formed" independently, in a different language, or not at all.

### The durability finding that reframes it

`.borg/` is not the shared, reviewable artifact the codebase talks about it as. Measured 2026-09-01 across all 21
registered projects with a `.borg/` directory:

- **12 of 21 gitignore `.borg/` entirely.** `snowflake-permissions` (`.gitignore:135`) and `dbt` (`:25`) are typical.
- **borg-collective is the only repository with anything committed under `.borg/` at all** — 1212 files. It is the
  exception because someone hand-added a three-line carve-out (`.gitignore:14-18`, `!.borg/programs/`), and **nothing
  propagates that carve-out**. Neither `borg add` nor `drone scaffold` installs it.
- The other 9 repositories do not ignore `.borg/` and have still never committed a byte of it. `snowflake-permissions`
  holds 58 uncommitted checkpoints; `dev` holds 36.

So the argument "files are better because they ride the PR and a human can review them" is **already false in 20 of 21
projects**. That is not a reason to adopt a database on its own, but it removes the strongest objection to one, and it
means the status quo is not "reviewable files" — it is an unindexed pile of machine-local state that only one
repository has ever preserved.

## What this is NOT

**This is not cairn, and the cairn postmortem does not settle it.** Conflating the two would be the easiest wrong turn
here, so the distinction is stated up front.

Cairn was killed for a specific falsified claim: cross-project semantic recall, measured at **0.4%** restatement —
indistinguishable from a null baseline — plus a token thesis that turned out to be worth ~1.5–3% of spend, and a
retrieval layer that worked fine for a need that never arose. Its transferable lesson was about **capture**: never
build a surface that asks an agent to volunteer data, because four shipped, tested, exposed voluntary-write surfaces
produced one real row in five months.

None of that is this. This proposes storage with constraints for artifacts borg **already generates as a byproduct of
work it already does** — the definition of derived capture, which is the thing the cairn postmortem says *did* work.
No semantic search, no embeddings, no recall claim, no belief store. If any of those reappear in a proposal, they are
a separate directive and inherit cairn's evidentiary burden in full.

**It is also not "analyze it for insights."** Storage and analysis are different projects with different risk. The
first is a well-scoped swap with a mechanical success test. The second is where cairn's five months went. Ship the
first, prove it, and let the second earn its own directive with a pre-registered question.

## The candidate

SQLite, one file, in `~/.local/state/borg/`. Not Postgres, not a service — borg is a single-user CLI on one machine
per audience, and the cairn teardown's first finding was that a service was infrastructure nobody needed.

All five current manifest-invalidity rules map to ordinary constraints, which is the crux of the argument:

| rule (today, `core.validate`) | as a constraint |
| --- | --- |
| ref must be full `owner/repo#num` | `CHECK (ref GLOB '*/*#*')` plus a stricter app-side regex |
| missing `order` key | `NOT NULL` |
| gate needs `blocked_by` or `resolved_by` | `CHECK (kind IS NULL OR COALESCE(blocked_by, resolved_by) IS NOT NULL)` |
| row must be an object | the table schema itself |
| duplicate ref in one chain | `UNIQUE (chain_id, ref)` |

The write fails at the storage layer, for every writer, with no perimeter — which is exactly what was asked for.

## Open questions this directive must answer before any code

1. **Does the file stay?** Three shapes: database-of-record with files exported for review; files-of-record with the
   database as a derived index; or dual-write. Only the first delivers the constraint guarantee, and only the last two
   keep hand-authoring. Note that hand-authoring is currently real — every live manifest was hand-written.
2. **Cross-machine.** A local SQLite file is exactly as machine-local as the JSONL it replaces. If cross-machine
   review matters, this does not solve it, and the honest answer may be that the git-committed carve-out should be
   propagated instead. **Do not let a database quietly become a sync project.**
3. **Migration and hand-authoring.** What reads a hand-edited JSON file after the swap? What does `borg chain
   validate` mean when the constraint lives in the schema? Is there an import path, and is it lossy?
4. **The 1212 committed files in borg-collective.** They are real history. Migrating them is a one-way door.
5. **Blast radius.** `.borg/programs` appears in 94 code references across 20 files; `borg_core/link/` reads manifests
   through `shell.discover` on the reflexive `borg link` path, which has a latency budget.
6. **What measurable thing gets better?** State it before building, as a pre-registered question, because cairn ran
   three keep-or-kill gates and all three produced zero kill decisions. A directive with no falsifiable claim is how
   that happens.

## Acceptance criteria

*None yet — this is filed for a decision, not for execution.* Promote it to a plan only after questions 1, 2 and 6
have answers on the record. Question 6 is the gate: if the honest answer is "nothing measurable, it is just tidier,"
the correct outcome is to sever this directive and keep the ~180-line validated writer, which already solved the
problem that produced it.

## Notes

- Prompted by Noah on 2026-09-01, mid-session, while scoping AC5's authoring path.
- The narrow fix shipped instead: `feat(manifest): port the manifest writer into borg_core, validating before it
  writes` — validate-then-refuse in `shell.write_manifest`, one shared `core.declared_body`, no `program` backfill,
  suggestion-not-repair on a shorthand ref.
- Dropped from that change on the reasoning above: the `PreToolUse` write hook, the recovery-receipt JSONL, and the
  `bash-guard` redirect clause. The dropped-row warning they were partly duplicating **already exists** —
  `shell.py:143` emits `"<path>: N of M rows dropped -- ..."` and `link/render.py:1093` already prints it on the page.
- If an AC5 eval later shows skills routing around the writer, the hook becomes justified by measurement rather than
  by speculation. That ordering is deliberate.
