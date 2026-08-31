# Directive: Flatten `summary` once, at assembly, instead of at each renderer that remembers to
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-16-link-port-latent-defects (assimilated 2026-08-31)*
*Filed: 2026-08-31*

**tl;dr** — `_flatten_summary` is opt-in at three call sites. A fourth consumer that reads `entry["summary"]`
directly reintroduces the bug with every test in the repo green, because nothing asserts the property at the point
where the field enters the document. The same bug was found and fixed three times in one day at three different call
sites, which is the argument.

## Why this exists

A `summary` reaching storage can carry a raw TAB, LF or CR. `lib/registry.zsh`'s `_borg_registry_write` scrubs
`\000-\010,\013,\014,\016-\037` — a set that deliberately EXCLUDES 0x09, 0x0A and 0x0D — so those three are the
exact characters that survive, which is what `_flatten_summary`'s own docstring enumerates.

**Three fixes, three call sites, one day.** Each was found separately, each was a real defect, and none of them was
the last one:

- **`_summary_block`, the deep dive.** A literal newline produces a sub-line `_fold_s` never indents, breaking the
  `^  [^ ]` continuation contract the deep-dive renderer depends on. Fixed by flattening before folding.
- **`_overview_summary_cut`, the board.** A newline inside the first 50 characters split one board row into two and
  sheared the fixed-width table, exactly the way an over-long project name would. Fixed by flattening before cutting,
  so the 50-char budget measures displayed characters.
- **`porcelain`, the machine surface.** An LF ends a TSV record early and a TAB shifts every field after it. Fixed by
  flattening before the 80-char cut, the same ordering and for the same reason.

Three renderers, three independent discoveries, one property. That is not three bugs — it is one missing invariant
found three times, and the third one was found only because someone went looking after the second.

**The fourth one is unguarded by construction.** `_flatten_summary` is a function a call site chooses to call.
Re-derive the current set with `grep -n '_flatten_summary' borg_core/link/render.py`; every hit outside the function
itself is a renderer that remembered. A new section builder that writes `entry.get("summary")` into a line — the most
natural thing to write — is correct-looking, passes every existing test, and ships the same defect a fourth time. The
existing tests cannot catch it: they are all per-renderer, so they assert the property exactly where it is already
held.

**And the flatten is also not the only spelling in the tree.** `cmd_ls --porcelain` is a separate zsh implementation
of the same record with its own cut (`${summary:0:80}`), fixed separately in PR
[#176](https://github.com/noah-goodrich/borg-collective/pull/176). Two implementations of one contract already
diverge; a chokepoint on the Python side does not fix the zsh half, and this directive should not pretend otherwise.

## Solution

**Flatten once, where the field enters the document.** `cli._document` (or whichever function assembles the project
map onto the wire — the assembly point, not a renderer) normalizes every `summary` before any consumer sees it. After
that:

- Every renderer reads an already-flat string, and a new one cannot get it wrong by omission.
- `_flatten_summary` stays exactly as it is, with its docstring, as the single statement of the character set. It
  moves call site, not definition.
- **The three existing call sites come out.** Leaving them in would be defensible as belt-and-braces and is rejected:
  a redundant call at a renderer is a live invitation to conclude the renderer owns the property, which is the state
  this directive exists to end. One owner, named in one place.
- **The property gets a test at the chokepoint**, asserting it over the assembled document rather than over one
  renderer's output — the only shape of test that a fourth consumer cannot bypass.

**Where exactly it lands has one hard constraint.** The document is also the `--json` wire, and
`skills/borg-link/SKILL.md` reads it. Flattening at assembly changes what a `--json` consumer receives for a summary
containing a newline, so this is a wire behaviour change and needs to be stated as one: decide whether
`DOCUMENT_VERSION` moves, or whether the normalization is a documented property of the field rather than a shape
change. The honest reading is the latter — no key narrows and no key is added — but it must be decided, not assumed.

## Non-goals

- **Changing what `_borg_registry_write` scrubs.** The exclusion of 0x09/0x0A/0x0D is deliberate and enumerated. This
  is a rendering invariant, not a storage one, and the whole point of the previous round's decision was that the
  invariant belongs to the artifact that depends on it, not to the writer.
- **Fixing `cmd_ls --porcelain`'s zsh implementation.** It was fixed already, it has its own test, and it is a
  separate implementation with its own life. Unifying the two porcelain producers is a real question and a different
  directive.
- **Changing `_flatten_summary`'s behaviour.** Same three characters, same mapping to one space.
- **Widening the chokepoint to other fields.** `waiting_reason` and `objective` may have the same shape; check them,
  but do not fold a survey into a fix.

## Alternatives considered

**Keep it opt-in and add a test per renderer.** This is the status quo plus discipline, and it is what failed three
times. A per-renderer test asserts the property where it is already true; it says nothing about the renderer nobody
has written yet. Rejected.

**Flatten at read time, in `core.py`'s registry reader.** Close to the right answer and rejected on altitude: the
reader's job is to report what the registry says, and a reader that silently edits values makes the registry and the
document disagree about their own contents for any other consumer of that function. Assembly is where the document is
being constructed and is the honest place to normalize for it.

**A typed wrapper (`Summary` newtype) that cannot be rendered unflattened.** The strongest version of the guarantee
and rejected as disproportionate: it is a real type-system change across every renderer signature to defend one
string field, in a module whose other 38 functions take plain `dict`s.

**Do nothing; three fixes closed three real sites.** Rejected on its own evidence. Each of those three fixes was
believed to be the last one at the time it shipped, and the file's own comments record the retraction that followed.

## Acceptance criteria

- [ ] `summary` is flattened exactly once, at document assembly, and `grep -n '_flatten_summary' borg_core/link/`
      shows the definition, the assembly call site, and test references — no renderer call sites.
- [ ] A test asserts the property over the ASSEMBLED DOCUMENT, not over a renderer's output: a registry entry whose
      summary carries a TAB, an LF and a CR yields a document whose `summary` contains none of the three.
      **The mutation that turns it red is deleting the assembly-side call**, verified rather than assumed.
- [ ] A second test proves the guarantee is structural rather than incidental: a renderer that reads
      `entry["summary"]` directly — the shape a future consumer would naturally write — still produces a flat line.
      This is the case that distinguishes a chokepoint from a fourth opt-in.
- [ ] The wire question is answered in the commit message: either `DOCUMENT_VERSION` moves with
      `skills/borg-link/SKILL.md`'s version gate updated, or the reasoning for why it does not is recorded.
- [ ] No golden and no `.expected` oracle moves, since no current fixture carries an embedded control character —
      confirm this rather than assume it, because a moved golden means the change did more than normalize.
- [ ] `make test`, `make lint` and `bats tests/` all exit 0, checked by exit code.
