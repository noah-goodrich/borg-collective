"""Validation-message vocabulary: the shapes `validate` writes, and how to read them back.

SPLIT OUT OF core.py for the same reason refs.py was, and the note there predicted this one: a
suppression with an expiry condition next to it is the only kind that gets removed, so when the file
crossed 1000 lines again the answer was another seam rather than another disable. Every function
below is byte-identical to the copy it replaces.

WHY THESE FIVE BELONG TOGETHER. `validate` returns formatted strings, and two consumers need
structure back out of them -- `shell._drop_invalid_rows` wants the row indices at fault,
`shell._write_refusal` wants the offending value to offer a `did you mean`. The tokens those parses
key on (`rows[`, `, got `) are interpolated by the producers in core.py and split by the readers
here, so producer and parser have to stay in one place or the format becomes an undeclared contract
that a reword breaks silently. core.py imports the tokens; nothing else needs them.

PURE. No imports at all.
"""

from __future__ import annotations

_GOT_MARKER = ", got "
_ROW_ERROR_PREFIX = "rows["


def _row_error_index(error: str) -> int | None:
    """The row index a validation message is scoped to, or None when it is not row-scoped.

    STRING OPS RATHER THAN A REGEX, and not for speed. The obvious `re.match(r"^rows\\[(\\d+)\\]")`
    form needs `int(match.group(1))`, which the clean-architecture plugin rejects as a Demeter chain
    (W9006) -- caught by CI, where the plugin runs, and not by the local pylint. Splitting it into
    two statements to appease the rule would leave a regex whose entire job is to extract one integer
    from a prefix this module itself writes. `partition` says the same thing in less.

    Reads BOTH label forms `_validate_row` produces: `rows[N]: ...` and `_validate_after`'s
    `rows[N].after[M] ...`, which carries no colon after the bracket. Anything whose bracket contents
    are not a plain integer is treated as NOT row-scoped, which fails safe -- an unparseable label
    keeps the whole file rather than dropping a row nobody identified.
    """
    if not error.startswith(_ROW_ERROR_PREFIX):
        return None
    digits, closed, _ = error[len(_ROW_ERROR_PREFIX) :].partition("]")
    if not closed or not digits.isdigit():
        return None
    return int(digits)


def offending_value(error: str) -> str:
    """The value a validation message is complaining about, or "" when it names none.

    LIVES BESIDE `partition_errors`, FOR THE REASON THAT FUNCTION GIVES ABOUT ITS OWN FORMAT. Six
    messages here end in the `got <value>` shape and `shell._write_refusal` needs the value back to
    offer a `did you mean`. Parsing it there made the format an undeclared cross-module contract with
    six producers and no shared token -- reword one and every suggestion silently disappears, nothing
    red. `_GOT_MARKER` is that token, interpolated by the producers and split here.

    NOT EVERY `got` IS A REF: two report a TYPE name (`got int`). Returns the token either way;
    `suggest_full_ref` answers "" for anything that is not a bare `repo#num`.
    """
    _, marker, value = error.partition(_GOT_MARKER)
    return value if marker else ""


def partition_errors(errors: list[str]) -> tuple[set[int], list[str]]:
    """Split `validate`'s output into `(row indices at fault, errors that are not row-scoped)`.

    LIVES HERE, NEXT TO THE FORMAT IT PARSES. `_validate_row` builds every row-scoped message from
    `label = f"rows[{index}]"` -- both the `rows[N]: ...` form and `_validate_after`'s
    `rows[N].after[M] ...` form -- and a caller that wants to drop a bad ROW rather than a whole FILE
    has to know which errors are which. Putting the regex in `shell.py` would make the message format
    an undeclared cross-module contract, which is the shape that breaks silently the first time
    someone rewords an error string.

    STRUCTURAL ERRORS ARE EVERYTHING ELSE, and they are correctly not row-scoped: `rows: missing or
    not a list` describes the container, and `apex: ...` describes a sibling key. Neither has a
    partial answer -- there is no subset of the file you could keep and still be describing what the
    author wrote.

    Returns indices as a SET because two errors routinely name one row (a gate declaring neither
    `blocked_by` nor `resolved_by` trips both), and the caller wants rows to drop, not errors to
    count.
    """
    bad_rows: set[int] = set()
    structural: list[str] = []
    for error in errors:
        index = _row_error_index(error)
        if index is None:
            structural.append(error)
        else:
            bad_rows.add(index)
    return bad_rows, structural
