"""Pure logic for the reader census: what a store must declare, and what makes it a violation.

UNCONDITIONALLY free of I/O. Discovery results and the declared census arrive as arguments.

WHAT THIS GATE IS FOR. Ten of sixteen `.borg/<name>` subdirectory names in this tree had no code
reader at all, and one of them -- `.borg/knowledge/`, which is the decommissioned cairn service's
own export -- was still named in CLAUDE.md's Architecture Rules as a place to grep for prior
decisions. Two independent measurements say what a store with only a voluntary reader is worth:
cairn died at 0.4% cross-project restatement, and the auto-memory instrument reads 0.129
reads/session against a pre-registered 0.2 bar. The engine was never the variable. A store nothing
reads is a write-only store, whatever it is built on.

THREE STATES, NOT TWO, and getting this wrong is how the gate becomes either toothless or
self-contradictory:

  1. referenced by executable code, no reader declared  -> VIOLATION
  2. named in CLAUDE.md, no reader declared             -> VIOLATION (a false promise to every agent)
  3. on disk only: no writer, no reader, named nowhere  -> PASS, inert historical data

State 3 needs no machinery and no census row, which is the point: a name that appears in neither
code nor docs is never discovered, so it passes trivially. That is exactly what `.borg/knowledge/`
becomes once the instruction to grep it is deleted -- its 1106 tracked files stay on disk, and the
gate stops caring, because nothing promises anything about them any more.

WHAT THIS GATE HONESTLY DOES NOT DO. It does not prove a declared reader performs a READ rather than
a write; distinguishing the two mechanically across zsh, bash and Python is not tractable, and a
gate that claimed to do it would be the overclaim this repo keeps paying for. What it does prove is
that every referenced store NAMES a reader, that the named file exists, and that the named file
actually mentions the store -- so a new store cannot be added without a human writing down where it
is read, and a reader cannot be deleted or renamed without the declaration going stale and failing.
That is a real ratchet. It is not a proof.
"""

from __future__ import annotations

NO_READER = "-"

KIND_STORE = "store"
KIND_PROSE = "prose"

# A reader that builds its path from a VARIABLE rather than a literal. `borg_core/extensions/shell.py`
# is the case that forced this kind: it resolves `Path(root) / ".borg" / kind / ...`, where `kind` is
# "skill-extensions" or "agent-extensions" passed in by the caller, so the real reader contains no
# literal token and the mention check cannot see it. `borg_core/manifest/shell.py` is the same shape,
# holding `chains` and `programs` as named constants it joins later.
#
# The alternative was pointing the reader column at whatever file happens to contain the literal --
# which here would be a TEST file. Naming a test as a store's reader to satisfy a gate is precisely
# the wallpapering this census exists to prevent, so the waiver is explicit, per-row, and must carry
# a note saying where the path is actually built.
KIND_DYNAMIC = "dynamic"

# A token that appears in docs ONLY as a historical note -- "this store was retired, and here is
# why" -- rather than as a live instruction. It needs a row because the note names the store, and a
# retirement note is the single most likely place for a retired store's name to survive; but it
# declares no reader, because the whole point is that nothing reads it any more.
#
# THIS IS AN ESCAPE HATCH AND IT IS NAMED AS ONE. The gate cannot tell a historical note from a live
# promise -- both are prose containing the token -- so nothing stops a future edit from marking a
# real promise `retired` to silence a failure. What the row buys is that doing so is a deliberate,
# reviewable line in a census file rather than a silent omission, and the note column has to say
# where the argument lives. The same trade the repo already accepts for `- Instead-of:` anchoring:
# prose discusses itself, so model that explicitly instead of pretending a pattern can tell.
KIND_RETIRED = "retired"


def _reader_failure(
    token: str,
    kind: str,
    reader: str,
    mentions: bool,
    exists: bool,
) -> str | None:
    """What is wrong with a row's READER declaration, or None.

    Split from `_referenced_failure` so neither ladder carries every branch: that one answers "is
    this token declared, and does its kind require a reader at all", this one answers "is the
    declared reader any good". The split is also what keeps each under the return-count ceiling
    without reaching for a linter disable.
    """
    if reader == NO_READER:
        if kind == KIND_DYNAMIC:
            return f"{token}: kind `dynamic` still has to NAME the reader that builds the path."
        return (
            f"{token}: referenced with NO READER declared. "
            "A store nothing reads is a write-only store; give it a reader or retire it."
        )
    if not exists:
        # THE EXISTENCE CHECK IS NEVER WAIVED, for any kind. An earlier draft skipped it alongside
        # the mention check for `dynamic` rows, which made docs/state-census.md's own "the gate
        # proves the named file exists" claim false for four of nine rows -- found by the verify
        # gate's reviewer, who pointed a dynamic row at a nonexistent file and got a clean pass.
        # Waiving the mention is forced by the data, since the path is built from a variable;
        # waiving existence was never forced by anything.
        return (
            f"{token}: declares reader `{reader}`, which does not exist. "
            "`dynamic` waives the mention check, never the file."
        )
    if kind != KIND_DYNAMIC and not mentions:
        return (
            f"{token}: declares reader `{reader}`, which never mentions it. "
            "The declaration is stale -- point it at the file that actually reads the store."
        )
    return None


def _referenced_failure(
    token: str,
    surfaces: str,
    row: dict[str, str] | None,
    mentions: bool,
    exists: bool,
) -> str | None:
    """The one violation a referenced token produces, or None when it is clean."""
    if row is None:
        return (
            f"{token}: referenced ({surfaces}) but absent from the census. "
            "Add a row naming its reader, or stop referencing it."
        )
    kind = row.get("kind", KIND_STORE)
    if kind in (KIND_PROSE, KIND_RETIRED):
        return None
    return _reader_failure(token, kind, row.get("reader", NO_READER), mentions, exists)


def violations(
    discovered: dict[str, set[str]],
    declared: dict[str, dict[str, str]],
    reader_mentions: dict[str, bool],
    reader_exists: dict[str, bool] | None = None,
) -> list[str]:
    """Every census failure, as human-readable lines. Empty list means the gate passes.

    `discovered` maps a `.borg/<name>` token to the surfaces it was found on ("code", "docs").
    `declared` maps a token to its census row. `reader_mentions` and `reader_exists` are resolved by
    the caller, since both are I/O -- and they are two maps rather than one because `dynamic` waives
    the first and never the second.
    """
    exists = reader_mentions if reader_exists is None else reader_exists
    found: list[str] = []

    for token in sorted(discovered):
        failure = _referenced_failure(
            token,
            ", ".join(sorted(discovered[token])),
            declared.get(token),
            reader_mentions.get(token, False),
            exists.get(token, False),
        )
        if failure:
            found.append(failure)

    for token in sorted(declared):
        if token not in discovered and declared[token].get("kind") not in (KIND_PROSE, KIND_RETIRED):
            found.append(
                f"{token}: declared in the census but referenced nowhere. "
                "Delete the row -- an undiscovered store is inert and needs no declaration."
            )

    return found
