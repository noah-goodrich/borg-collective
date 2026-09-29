"""Unit tests for the census's pure classification."""

from borg_core.census import core


def _row(kind="store", reader="lib/reader.sh"):
    return {"kind": kind, "reader": reader}


def test_referenced_and_undeclared_is_a_violation():
    found = core.violations({".borg/orphan": {"code"}}, {}, {})
    assert len(found) == 1 and "absent from the census" in found[0]


def test_referenced_with_no_reader_is_a_violation():
    found = core.violations({".borg/o": {"code"}}, {".borg/o": _row(reader=core.NO_READER)}, {})
    assert "NO READER declared" in found[0]


def test_a_docs_only_promise_is_a_violation_and_names_the_surface():
    found = core.violations({".borg/lore": {"docs"}}, {}, {})
    assert "docs" in found[0]


def test_a_stale_reader_declaration_is_a_violation():
    rows = {".borg/w": _row()}
    found = core.violations({".borg/w": {"code"}}, rows, {".borg/w": False}, {".borg/w": True})
    assert "stale" in found[0]


def test_a_well_formed_store_passes():
    rows = {".borg/w": _row()}
    assert core.violations({".borg/w": {"code"}}, rows, {".borg/w": True}, {".borg/w": True}) == []


def test_state_three_needs_no_row_and_passes():
    # Never discovered, so never judged. No machinery, by design.
    assert core.violations({}, {}, {}) == []


def test_prose_and_retired_kinds_waive_the_reader_requirement():
    for kind in (core.KIND_PROSE, core.KIND_RETIRED):
        rows = {".borg/x": _row(kind=kind, reader=core.NO_READER)}
        assert core.violations({".borg/x": {"docs"}}, rows, {}) == []


def test_dynamic_waives_the_mention_check_but_still_demands_a_reader():
    rows = {".borg/k": _row(kind=core.KIND_DYNAMIC)}
    exists = {".borg/k": True}
    assert core.violations({".borg/k": {"code"}}, rows, {".borg/k": False}, exists) == []

    nameless = {".borg/k": _row(kind=core.KIND_DYNAMIC, reader=core.NO_READER)}
    assert "NAME the reader" in core.violations({".borg/k": {"code"}}, nameless, {})[0]


def test_a_declared_but_unreferenced_store_is_reported_as_dead_weight():
    found = core.violations({}, {".borg/gone": _row()}, {})
    assert "referenced nowhere" in found[0]


def test_prose_and_retired_rows_are_exempt_from_the_dead_weight_check():
    for kind in (core.KIND_PROSE, core.KIND_RETIRED):
        assert core.violations({}, {".borg/x": _row(kind=kind, reader=core.NO_READER)}, {}) == []


# ── dynamic waives the mention, never the file ──────────────────────────────
#
# Found by the verify gate's reviewer, which pointed a `dynamic` row at a nonexistent file and got a
# clean pass. That made docs/state-census.md's own "the gate proves the named file exists" claim
# false for four of nine rows -- an undisclosed weakness in a document whose whole subject is
# disclosed weaknesses.


def test_dynamic_still_requires_the_reader_file_to_exist():
    rows = {".borg/k": _row(kind=core.KIND_DYNAMIC, reader="lib/gone.sh")}
    found = core.violations({".borg/k": {"code"}}, rows, {".borg/k": False}, {".borg/k": False})
    assert "does not exist" in found[0]
    assert "never the file" in found[0]


def test_dynamic_passes_when_the_reader_exists_but_never_mentions_it():
    rows = {".borg/k": _row(kind=core.KIND_DYNAMIC)}
    assert core.violations({".borg/k": {"code"}}, rows, {".borg/k": False}, {".borg/k": True}) == []


def test_store_rows_still_need_the_mention_even_when_the_file_exists():
    rows = {".borg/w": _row()}
    found = core.violations({".borg/w": {"code"}}, rows, {".borg/w": False}, {".borg/w": True})
    assert "stale" in found[0]
