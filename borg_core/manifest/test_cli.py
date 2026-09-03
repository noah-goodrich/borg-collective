"""Tests for the manifest write verbs (AC5).

The load-bearing case in this file is `test_add_row_refuses_an_invalid_manifest_and_the_bad_row_survives`
and its contrast twin. Everything else here is ordinary CRUD; that pair is the reason the module
exists in the shape it does, and it is the one to run a mutation against.

MEASURED: pointing `_read_for_write` at `shell.discover` turns FOUR of these red -- that case plus
the three refusal paths, because `discover` collapses "absent", "not JSON" and "not an object" into
one generic miss and so cannot name which happened. Four rather than one is the honest number and is
recorded here because the first draft of this docstring guessed one.
"""

import json
import os

import pytest

from borg_core.manifest import cli
from borg_core.manifest import shell


def _path(repository, name="demo"):
    return os.path.join(repository, ".borg", "programs", f"{name}.json")


def _read(repository, name="demo"):
    with open(_path(repository, name), encoding="utf-8") as handle:
        return json.load(handle)


def _run(*argv):
    return cli.main(list(argv))


@pytest.fixture(name="repository")
def _repository(tmp_path):
    return str(tmp_path / "repo")


# ── scaffold ─────────────────────────────────────────────────────────────────────────────────────
def test_scaffold_writes_an_empty_manifest_with_the_apex_and_desc(repository):
    assert _run("scaffold", "--repository", repository, "--name", "demo",
                "--apex", "o/r#1", "--title", "Apex", "--desc", "A demo.") == 0
    doc = _read(repository)
    assert doc == {"apex": {"ref": "o/r#1", "title": "Apex"}, "desc": "A demo.", "rows": []}


def test_scaffold_with_no_apex_is_still_valid(repository):
    # core._validate_apex: "No apex at all is valid, not a problem" -- work small enough to need no
    # tracker legitimately has none, and pointing at one that does not exist is worse.
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert _read(repository) == {"rows": []}


def test_scaffold_never_clobbers_an_existing_manifest(repository):
    """The negative that makes idempotence meaningful: a re-plan must not delete a declared program.

    MUTATION: drop the `os.path.exists` guard in `_cmd_scaffold` and this row vanishes, because the
    fresh scaffold writes `rows: []` over it.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#7", "--why", "keep me")
    assert _run("scaffold", "--repository", repository, "--name", "demo", "--desc", "different") == 0
    doc = _read(repository)
    assert [row["ref"] for row in doc["rows"]] == ["o/r#7"]
    assert "desc" not in doc, "an existing manifest is left exactly as it is, not merged into"


# ── add-row ──────────────────────────────────────────────────────────────────────────────────────
def test_add_row_appends_and_derives_the_order_within_a_lane(repository):
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "build")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2", "--lane", "build")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#3", "--lane", "docs")
    rows = {row["ref"]: (row["lane"], row["order"]) for row in _read(repository)["rows"]}
    assert rows == {"o/r#1": ("build", "1"), "o/r#2": ("build", "2"), "o/r#3": ("docs", "1")}


def test_add_row_skips_prerequisite_orders_when_numbering(repository):
    """A dash-ordered row carries no number and sorts first, so numbering must not count it.

    Numbering after a prerequisite would claim a position the author deliberately left unnumbered.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1",
         "--lane", "build", "--order", "–")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2", "--lane", "build")
    rows = {row["ref"]: row["order"] for row in _read(repository)["rows"]}
    assert rows == {"o/r#1": "–", "o/r#2": "1"}


def test_add_row_updates_rather_than_duplicating_an_existing_ref(repository):
    """Append-or-update, because `/borg-link-up` runs every session.

    A plain append would produce a duplicate ref, which `core.validate` rejects outright -- so the
    second invocation would refuse the whole file for the ordinary case of a PR already declared.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1",
         "--lane", "build", "--why", "hand-written reason")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1",
                "--status", "merged") == 0
    rows = _read(repository)["rows"]
    assert len(rows) == 1, "one ref, one row"
    assert rows[0]["status"] == "merged"
    assert rows[0]["why"] == "hand-written reason", "a field the caller did not pass survives"


def test_a_duplicate_ref_would_have_been_refused_by_the_validator(repository):
    """The premise the test above depends on, asserted directly rather than assumed."""
    from borg_core.manifest import core
    doc = {"rows": [{"ref": "o/r#1", "order": "1"}, {"ref": "o/r#1", "order": "2"}]}
    assert any("duplicate ref" in error for error in core.validate(doc))


# ── close ────────────────────────────────────────────────────────────────────────────────────────
def test_close_sets_the_status_by_ref(repository):
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1")
    assert _run("close", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 0
    assert _read(repository)["rows"][0]["status"] == "merged"


def test_close_refuses_an_undeclared_ref_and_names_what_is_declared(repository, capsys):
    """Not an implicit add: a wrong ref at close time is something the author needs told."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1")
    assert _run("close", "--repository", repository, "--name", "demo", "--ref", "o/r#99") == 1
    err = capsys.readouterr().err
    assert "no row declares o/r#99" in err
    assert "o/r#1" in err, "the declared refs are named so the author can see the typo"


# ── the strict read: the reason this module is not built on shell.discover ────────────────────────
def test_add_row_refuses_an_invalid_manifest_and_the_bad_row_survives(repository, capsys):
    """READ-MODIFY-WRITE MUST REFUSE, NEVER SALVAGE.

    `shell._load_manifest` drops a failing row and returns the survivors, which is right for
    rendering. Through a write path it means a verb asked to ADD one row DELETES another, with a
    warning as the only trace -- exactly what
    `docs/plans/directives/2026-09-01-refuse-the-manifest-stop-salvaging-rows.md` says to make
    structurally impossible.

    MUTATION: point `_read_for_write` at `shell.discover` and this goes red on the surviving-row
    assertion. Three refusal-path cases go red with it -- see the module docstring for why that is
    four and not one.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "build")
    doc = _read(repository)
    doc["rows"].append({"ref": "o/r#2", "lane": "build", "why": "no order, so invalid"})
    with open(_path(repository), "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=2, sort_keys=True)

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#3") == 1
    assert "refusing to rewrite an invalid manifest" in capsys.readouterr().err

    after = _read(repository)
    assert [row["ref"] for row in after["rows"]] == ["o/r#1", "o/r#2"], "the invalid row is still there"
    assert not any(row["ref"] == "o/r#3" for row in after["rows"]), "and nothing was added"


def test_the_salvaging_reader_would_have_dropped_that_row(repository):
    """The contrast twin, so the test above is a claim about a REAL alternative and not a strawman."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "build")
    doc = _read(repository)
    doc["rows"].append({"ref": "o/r#2", "lane": "build", "why": "no order, so invalid"})
    with open(_path(repository), "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=2, sort_keys=True)

    manifests, warnings = shell.discover([repository])
    assert [row["ref"] for row in manifests[0]["rows"]] == ["o/r#1"], "discover keeps only the valid row"
    assert any("dropped" in warning for warning in warnings)


def test_add_row_refuses_a_missing_manifest_by_name(repository, capsys):
    assert _run("add-row", "--repository", repository, "--name", "absent", "--ref", "o/r#1") == 1
    assert "no manifest at" in capsys.readouterr().err


def test_add_row_refuses_a_file_that_is_not_json(repository, capsys):
    os.makedirs(os.path.join(repository, ".borg", "programs"), exist_ok=True)
    with open(_path(repository), "w", encoding="utf-8") as handle:
        handle.write("{ not json\n")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 1
    assert "not valid JSON" in capsys.readouterr().err


def test_add_row_refuses_a_json_document_that_is_not_an_object(repository, capsys):
    os.makedirs(os.path.join(repository, ".borg", "programs"), exist_ok=True)
    with open(_path(repository), "w", encoding="utf-8") as handle:
        json.dump(["a", "list"], handle)
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 1
    assert "top level is list" in capsys.readouterr().err


def test_a_ref_the_validator_rejects_is_refused_on_the_way_in(repository, capsys):
    """AC ids and bare paths are not refs, so a skill cannot smuggle one in through this verb."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "AC1") == 1
    assert "must be a GitHub ref" in capsys.readouterr().err


def test_the_written_stem_is_basenamed_so_a_name_cannot_escape_the_directory(repository):
    """`write_manifest` basenames the stem; this asserts the CLI agrees, so both land on one path."""
    assert _run("scaffold", "--repository", repository, "--name", "../escape") == 0
    assert os.path.exists(_path(repository, "escape"))
    assert not os.path.exists(os.path.join(repository, ".borg", "escape.json"))


# ── regressions from the 2026-09-03 blind review ─────────────────────────────────────────────────
def test_a_lane_move_rederives_the_order_instead_of_carrying_a_stale_one(repository):
    """THE REVIEW'S ONE DATA-CORRUPTION FINDING, pinned.

    `--lane` alone used to set only the lane, carrying the row's old order into the new lane. Two
    rows then claimed one position -- which `core.validate` ACCEPTS, because it checks duplicate
    refs and not duplicate orders -- so `core.lanes` sorted the newcomer into the middle and
    `core.derive_edges` re-pointed a stacked edge at it. An UNTOUCHED row was demoted a position and
    declared to depend on a row the author never ordered against it.

    MUTATION: drop the `if moving and not args.order` branch in `_cmd_add_row` and this goes red on
    the edge assertion, which is the one that matters -- the order assertion alone would not show
    that a third row's dependencies changed.
    """
    from borg_core.manifest import core
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "contract")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2", "--lane", "contract")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#9", "--lane", "cutover")

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#9",
                "--lane", "contract") == 0

    doc = _read(repository)
    orders = [row["order"] for row in doc["rows"] if row["lane"] == "contract"]
    assert len(orders) == len(set(orders)), f"two rows claim one position: {orders}"
    edges = {(e["parent"], e["child"]) for e in core.derive_edges(doc) if e["kind"] == "stacked"}
    assert ("o/r#1", "o/r#2") in edges, "the untouched pair keeps its declared edge"
    assert ("o/r#1", "o/r#9") not in edges, "the moved row is not spliced ahead of it"


def test_an_explicit_order_still_wins_over_the_derived_one_on_a_move(repository):
    """The fix fills the gap the caller left; it does not override the caller."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "a")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2", "--lane", "b")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2",
         "--lane", "a", "--order", "7")
    assert [r["order"] for r in _read(repository)["rows"] if r["ref"] == "o/r#2"] == ["7"]


def test_a_padded_lane_buckets_the_way_core_lanes_buckets_it(repository):
    """`core.lanes` strips the lane; this module used a bare `str()`, so `" a "` was a third bucket.

    Two rows then derived order "1" into what every consumer reads as ONE lane.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "a")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2", "--lane", "  a  ")
    rows = _read(repository)["rows"]
    assert {row["lane"] for row in rows} == {"a"}, "one canonical lane, not two spellings"
    assert sorted(row["order"] for row in rows) == ["1", "2"]


def test_status_is_written_on_a_NEW_row(repository):
    """cli.py's add-branch `--status` was executed by no test, so deleting it kept every gate green.

    A row written with no status reads as an unknown state, so it is excluded from every ready-set
    answer and renders unresolved rather than merged.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--status", "merged")
    assert _read(repository)["rows"][0]["status"] == "merged"


def test_add_row_and_close_require_a_ref_at_exit_2(repository, capsys):
    """The guard that distinguishes "you forgot a flag" (rc 2) from "your manifest is bad" (rc 1)."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    assert _run("add-row", "--repository", repository, "--name", "demo") == 2
    assert "--ref is required" in capsys.readouterr().err
    assert _run("close", "--repository", repository, "--name", "demo") == 2


def test_a_non_utf8_manifest_is_refused_by_name_not_by_traceback(repository):
    """An editor-mangled or truncated file is bytes, not a codec lecture."""
    os.makedirs(os.path.join(repository, ".borg", "programs"), exist_ok=True)
    with open(_path(repository), "wb") as handle:
        handle.write(b'{"rows": [], "desc": "\xff\xfe bad bytes"}')
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 1
