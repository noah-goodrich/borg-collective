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
import subprocess

import pytest

from borg_core.manifest import cli
from borg_core.manifest import shell


def _path(repository, name="demo"):
    return os.path.join(repository, shell.STACKS_DIRNAME, f"{name}.json")


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
    # `program` IS EXPECTED, and its absence was the defect these two cases used to pin. Every
    # manifest under `.stacks/` must carry a top-level `program` equal to its filename stem --
    # merge-tree/test_s4_manifests.py's `test_program_id_matches_filename_and_is_a_slug` enforces
    # it, and it went red on the first scaffolded plan manifest. See core.py's VOCABULARY note: AC7
    # retires the WORD as a name for new things, never the on-disk key.
    assert doc == {
        "apex": {"ref": "o/r#1", "title": "Apex"},
        "desc": "A demo.",
        "program": "demo",
        "rows": [],
    }


def test_scaffold_with_no_apex_is_still_valid(repository):
    # core._validate_apex: "No apex at all is valid, not a problem" -- work small enough to need no
    # tracker legitimately has none, and pointing at one that does not exist is worse.
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert _read(repository) == {"program": "demo", "rows": []}


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
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#3", "--lane", "docs", "--new-lane")
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
    `docs/plans/assimilated/2026-09-01-refuse-the-manifest-stop-salvaging-rows.md` says to make
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


def test_the_reader_refuses_the_whole_file_rather_than_dropping_that_row(repository):
    """The read-side twin: discover no longer salvages, so no caller can write back a shortened manifest."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "build")
    doc = _read(repository)
    doc["rows"].append({"ref": "o/r#2", "lane": "build", "why": "no order, so invalid"})
    with open(_path(repository), "w", encoding="utf-8") as handle:
        json.dump(doc, handle, indent=2, sort_keys=True)

    manifests, warnings = shell.discover([repository])
    assert manifests == [], "discover refuses the file whole"
    assert any("invalid manifest" in warning for warning in warnings)
    assert [row["ref"] for row in _read(repository)["rows"]] == ["o/r#1", "o/r#2"], "and the disk is untouched"


def test_add_row_refuses_a_missing_manifest_by_name(repository, capsys):
    assert _run("add-row", "--repository", repository, "--name", "absent", "--ref", "o/r#1") == 1
    assert "no manifest at" in capsys.readouterr().err


def test_add_row_refuses_a_file_that_is_not_json(repository, capsys):
    os.makedirs(os.path.join(repository, shell.STACKS_DIRNAME), exist_ok=True)
    with open(_path(repository), "w", encoding="utf-8") as handle:
        handle.write("{ not json\n")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 1
    assert "not valid JSON" in capsys.readouterr().err


def test_add_row_refuses_a_json_document_that_is_not_an_object(repository, capsys):
    os.makedirs(os.path.join(repository, shell.STACKS_DIRNAME), exist_ok=True)
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
    assert not os.path.exists(os.path.join(repository, "escape.json"))


# ── regressions from the 2026-09-03 blind review ─────────────────────────────────────────────────
def test_a_lane_move_rederives_the_order_instead_of_carrying_a_stale_one(repository):
    """THE REVIEW'S ONE DATA-CORRUPTION FINDING, pinned.

    `--lane` alone used to set only the lane, carrying the row's old order into the new lane. Two
    rows then claimed one position -- which `core.validate` ACCEPTS, because it checks duplicate
    refs and not duplicate orders -- so `core.lanes` sorted the newcomer into the middle and
    `core.derive_edges` re-pointed a stacked edge at it. An UNTOUCHED row was demoted a position and
    declared to depend on a row the author never ordered against it.

    MUTATION: drop the `if moving and not args.order` branch in `_cmd_add_row` and this goes red on
    the ORDER assertion -- `two rows claim one position: ['1', '2', '1']` -- because that assertion
    comes first. Measured, after an earlier version of this docstring claimed the EDGE assertion
    instead: both fire, but only one gets reported, and the order of assertions decides which. The
    EDGE assertion is still the one that matters, because it is what shows a THIRD row's declared
    dependencies changed, so it is kept and stated separately rather than folded into the first.
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
    os.makedirs(os.path.join(repository, shell.STACKS_DIRNAME), exist_ok=True)
    with open(_path(repository), "wb") as handle:
        handle.write(b'{"rows": [], "desc": "\xff\xfe bad bytes"}')
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 1


def test_a_lane_move_preserves_a_declared_prerequisite_instead_of_numbering_it(repository):
    """ROUND 2's finding on ROUND 1's fix, and the inversion is the mirror of the one it repaired.

    `core.PREREQ_ORDERS` is not a missing number, it is a declaration that the row has no position
    and sorts FIRST -- `core._sort_key` gives it a 0-bucket. The rederivation added for the lane-move
    bug numbered it anyway, so a `"–"` row moved into a lane holding "1" and "2" came out at "3",
    `core.lanes` put it LAST, and `derive_edges` emitted `#3 -> #1`: the ancestor declared to depend
    on the whole chain it precedes.

    MUTATION: drop `and not prerequisite` and this goes red on the MARKER assertion --
    `the prerequisite marker was replaced by '3'` at the `in core.PREREQ_ORDERS` check, which is the
    first of the three. Measured, not guessed: the first version of this note said "the edge
    assertion", which is the SAME error the same commit corrected on the sibling test six lines up,
    made again in the same edit. Whichever assertion comes first is the one reported; naming another
    is a claim about ordering, and this file's ordering is marker, then lane position, then edges.
    """
    from borg_core.manifest import core
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1",
         "--lane", "contract", "--order", "–")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2",
         "--lane", "cutover", "--new-lane")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#3", "--lane", "cutover")

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1",
                "--lane", "cutover") == 0

    doc = _read(repository)
    moved = next(row for row in doc["rows"] if row["ref"] == "o/r#1")
    assert moved["order"] in core.PREREQ_ORDERS, f"the prerequisite marker was replaced by {moved['order']!r}"
    assert [row["ref"] for row in core.lanes(doc)["cutover"]] == ["o/r#1", "o/r#2", "o/r#3"], \
        "a prerequisite sorts FIRST in its new lane, not last"
    edges = {(e["parent"], e["child"]) for e in core.derive_edges(doc)}
    assert ("o/r#3", "o/r#1") not in edges, "the ancestor must not be declared to depend on its own chain"


def test_a_lane_move_does_not_outrank_an_untouched_row_whose_order_holds_no_digit(repository):
    """ROUND 3: the lane-move rederivation was still wrong, in a third way.

    `core._sort_key` falls back to a row's FILE INDEX when its `order` holds no digit, so `"abc"` at
    index 3 sorts as though it were order 3. `_next_order` used to extract digits and SKIP such a
    row entirely, deriving "1" for a moved row -- which then landed AHEAD of the untouched row and
    was declared its parent. Round 2's prerequisite guard did not close this: `"abc"` is not a
    prerequisite.

    The fix is not a third string rule but a delegation: `_next_order` now asks `core._sort_key` for
    each row's effective position instead of paraphrasing how it is computed. Both earlier defects
    in that function were paraphrase bugs -- a bare `str()` where core strips, and digit extraction
    where core falls back to the index.

    MUTATION: replace the `core._sort_key` call in `_next_order` with the old digit-extraction loop
    and this goes red on the lane-order assertion.
    """
    from borg_core.manifest import core
    _run("scaffold", "--repository", repository, "--name", "demo")
    for n in (1, 2, 3):
        _run("add-row", "--repository", repository, "--name", "demo", "--ref", f"o/r#{n}", "--lane", "filler")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#7",
         "--lane", "target", "--order", "abc", "--new-lane")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#9", "--lane", "other", "--new-lane")

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#9",
                "--lane", "target", "--new-lane") == 0

    doc = _read(repository)
    assert [row["ref"] for row in core.lanes(doc)["target"]] == ["o/r#7", "o/r#9"], \
        "the newcomer appends after the untouched digit-free row, it does not outrank it"
    edges = {(e["parent"], e["child"]) for e in core.derive_edges(doc)}
    assert ("o/r#9", "o/r#7") not in edges, "the untouched row must not be re-parented onto the newcomer"


# ── `resolve` (AC5.1 / AC5.9) ────────────────────────────────────────────────────────────────────

def _repo_with(tmp_path, manifests: dict, plan_slug: str | None = None):
    """A repository carrying `{stem: program_key_or_None}` manifests and an optional plan slug."""
    programs = tmp_path / ".stacks"
    programs.mkdir(parents=True, exist_ok=True)
    for stem, program in manifests.items():
        doc: dict[str, object] = {"rows": []}
        if program:
            doc["program"] = program
        (programs / f"{stem}.json").write_text(json.dumps(doc), encoding="utf-8")
    if plan_slug is not None:
        # PROSE MENTIONING THE ANNOTATION COMES FIRST, deliberately. With the annotation first the
        # reader returns before ever reaching the prose, so an unanchored match would survive
        # mutation — the ordering, not the anchor, would be doing the work. Verified: with the prose
        # above it, dropping the `startswith` anchor turns these cases red.
        (tmp_path / "PROJECT_PLAN.md").write_text(
            "# Plan\n\n"
            "*This plan explains that a `- Plan-slug:` annotation is how the slug is declared, and "
            "that prose about it must not be mistaken for it.*\n\n"
            f"- Plan-slug: `{plan_slug}`\n", encoding="utf-8")
    return str(tmp_path)


def test_resolve_rule1_no_manifest_refuses_and_names_the_directory(tmp_path, capsys):
    """Rule 1. This is the no-op-and-propose path, not an error to work around: `/borg-link-up`
    writes a proposal line and carries on, because creation belongs to `/borg-plan`."""
    rc = cli.main(["resolve", "--repository", str(tmp_path)])
    assert rc == 1
    assert "no manifest" in capsys.readouterr().err


def test_resolve_rule2_exactly_one_manifest_yields_its_stem(tmp_path, capsys):
    """Rule 2, and the overwhelmingly common case: measured across 22 registered repositories, 1 has
    any manifest and 0 has more than one."""
    repo = _repo_with(tmp_path, {"only-one": None})
    assert cli.main(["resolve", "--repository", repo]) == 0
    assert capsys.readouterr().out.strip() == "only-one"


def test_resolve_rule2_uses_the_STEM_not_the_program_key(tmp_path, capsys):
    """A manifest whose `program` differs from its filename resolves to the FILENAME, because that
    is what the write verbs take as `--name`. Two files in this tree deliberately differ, and
    writing back via a program-derived name once spawned a second file — "two copies of one program
    that then diverge silently"."""
    repo = _repo_with(tmp_path, {"three-repo-program": "auth-hardening"})
    assert cli.main(["resolve", "--repository", repo]) == 0
    assert capsys.readouterr().out.strip() == "three-repo-program"


def test_resolve_rule3_several_manifests_pick_the_one_matching_the_DECLARED_slug(tmp_path, capsys):
    """Rule 3. `_id` is stamped by `shell._load_manifest` — a declared `program` verbatim, else the
    stem — so this costs no schema change."""
    repo = _repo_with(tmp_path, {"alpha": "alpha-thing", "beta": "beta-thing"},
                      plan_slug="beta-thing")
    assert cli.main(["resolve", "--repository", repo]) == 0
    assert capsys.readouterr().out.strip() == "beta"


def test_resolve_rule3_matches_a_stem_derived_id_too(tmp_path, capsys):
    """A manifest with no `program` key has `_id == stem`, so a slug naming the stem resolves."""
    repo = _repo_with(tmp_path, {"alpha": None, "beta": None}, plan_slug="beta")
    assert cli.main(["resolve", "--repository", repo]) == 0
    assert capsys.readouterr().out.strip() == "beta"


def test_resolve_rule4_several_and_no_declared_slug_refuses_by_name(tmp_path, capsys):
    """Rule 4. NEVER A GUESS: picking one of several would silently bind a session's row to another
    program's chain, and `core.validate` cannot catch that — both are well-formed."""
    repo = _repo_with(tmp_path, {"alpha": None, "beta": None})
    assert cli.main(["resolve", "--repository", repo]) == 1
    err = capsys.readouterr().err
    assert "no plan slug declared" in err
    assert "alpha" in err and "beta" in err


def test_resolve_rule4_several_with_a_slug_matching_nothing_refuses(tmp_path, capsys):
    repo = _repo_with(tmp_path, {"alpha": None, "beta": None}, plan_slug="matches-nothing")
    assert cli.main(["resolve", "--repository", repo]) == 1
    assert "ambiguous" in capsys.readouterr().err


def test_resolve_NEVER_re_derives_a_slug_from_the_objective(tmp_path, capsys):
    """AC5.9's explicit assertion. A plan whose Objective would slugify to one of the candidate
    stems, but which declares NO annotation, must still refuse — otherwise the computed-slug defect
    that produced a silently-passing Step 0.75 reappears here."""
    repo = _repo_with(tmp_path, {"alpha": None, "beta": None})
    (tmp_path / "PROJECT_PLAN.md").write_text(
        "# Plan\n*Established: 2026-09-16*\n\n## Objective\n\nalpha\n", encoding="utf-8")
    assert cli.main(["resolve", "--repository", repo]) == 1
    assert "no plan slug declared" in capsys.readouterr().err


def test_resolve_ignores_PROSE_mentioning_the_annotation(tmp_path, capsys):
    """The plan file discusses its own annotation — this repository's does, directly below it — so an
    unanchored match returns the prose. `_repo_with` plants exactly that paragraph."""
    repo = _repo_with(tmp_path, {"alpha": None, "beta": None}, plan_slug="beta")
    assert cli.main(["resolve", "--repository", repo]) == 0
    assert capsys.readouterr().out.strip() == "beta"


def test_resolve_WRITES_NOTHING(tmp_path, capsys):
    """AC5.1: read-only. Asserted by mtime AND content over every file under the repository, for all
    four rules, because "it looked read-only" is not a property — a manifest rewritten with
    identical bytes would still be a write, and `_load_manifest` stamps `_id`/`_path` into the doc
    it returns, which is exactly the kind of thing that gets persisted by accident."""
    repo = _repo_with(tmp_path, {"alpha": "alpha-thing", "beta": "beta-thing"}, plan_slug="beta-thing")
    before = {p: (p.stat().st_mtime_ns, p.read_bytes())
              for p in tmp_path.rglob("*") if p.is_file()}
    for argv in (["resolve", "--repository", repo],
                 ["resolve", "--repository", str(tmp_path / "absent")]):
        cli.main(argv)
        capsys.readouterr()
    after = {p: (p.stat().st_mtime_ns, p.read_bytes())
             for p in tmp_path.rglob("*") if p.is_file()}
    assert before == after, "resolve mutated the repository"


def test_resolve_needs_no_name_while_the_write_verbs_still_demand_one(tmp_path, capsys):
    """`resolve` exists to DISCOVER the stem, so `--name` cannot be parser-required. The requirement
    moved to the dispatch, which is the trade the flat parser makes — so this pins both halves: the
    verb that must not require it, and a verb that still must."""
    repo = _repo_with(tmp_path, {"only-one": None})
    assert cli.main(["resolve", "--repository", repo]) == 0
    capsys.readouterr()
    assert cli.main(["close", "--repository", repo, "--ref", "o/r#1"]) == 2
    assert "--name is required" in capsys.readouterr().err


# ── the lane guard (AC5.8) ───────────────────────────────────────────────────────────────────────
def test_add_row_refuses_a_lane_that_is_not_already_declared(repository, capsys):
    """A one-letter lane typo forked the chain silently; measured 2026-09-15.

    `--lane aplha` for `alpha` was ACCEPTED by `core.validate` -- a fork is not malformed, just
    wrong -- and started a second root whose ordering restarted at 1. The guard is on the writer
    rather than the validator because rejecting an unknown lane in `validate` would forbid ever
    adding a second lane, and the live shape is multi-lane.

    MUTATION: delete the `_unknown_lane` call in `_cmd_add_row` and this goes green again.
    """
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "alpha")
    capsys.readouterr()

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2",
                "--lane", "aplha") == 1
    err = capsys.readouterr().err
    assert "unknown lane 'aplha'" in err
    assert "'alpha'" in err, "the refusal must NAME the declared lanes, or the author cannot see the typo"
    assert [row["ref"] for row in _read(repository)["rows"]] == ["o/r#1"], "nothing may be written"


def test_add_row_permits_a_new_lane_when_it_is_declared_deliberately(repository):
    """The discriminating direction: a typo never passes --new-lane, so the flag is the whole gate."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "alpha")

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2",
                "--lane", "beta", "--new-lane") == 0
    lanes = {row["ref"]: row["lane"] for row in _read(repository)["rows"]}
    assert lanes == {"o/r#1": "alpha", "o/r#2": "beta"}


def test_add_row_the_first_lane_in_an_empty_manifest_is_free(repository):
    """There is nothing to typo against yet, so the guard must not demand --new-lane on row one."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    assert _run("add-row", "--repository", repository, "--name", "demo",
                "--ref", "o/r#1", "--lane", "alpha") == 0


def test_add_row_without_a_lane_is_never_a_typo(repository):
    """An omitted --lane resolves to DEFAULT_LANE -- the single-stack case, which names nothing."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1", "--lane", "alpha")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#2") == 0


# ── the writer ref-kind gate (AC5.10) ────────────────────────────────────────────────────────────
def test_add_row_refuses_a_tracked_kind_this_machine_cannot_resolve(repository, capsys, monkeypatch, tmp_path):
    """A jira parent with no adapter WEDGES every row behind it, and does so silently.

    `grid.RESOLVED_STATE_SOURCES` is `(swept, fetched)`, so a kind nothing sweeps never resolves and
    `ready_set`'s "unknown is not merged" blocks the children forever -- while `refs.expects_github`
    deliberately suppresses the SIGNALS line for jira. Measured 2026-09-15: a jira parent produced
    `{'state': 'known', 'refs': []}`, a confident empty answer.

    MUTATION: delete the `_unauthorable_ref` call in `_cmd_add_row` and this goes green.
    """
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(tmp_path / "no-adapters"))
    _run("scaffold", "--repository", repository, "--name", "demo")
    capsys.readouterr()

    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "PROJ-2107") == 1
    assert "no resolver for jira" in capsys.readouterr().err
    assert _read(repository)["rows"] == [], "nothing may be written"


def test_add_row_admits_the_same_jira_ref_once_an_adapter_exists(repository, monkeypatch, tmp_path):
    """The discriminating direction, and the proof this is a PREDICATE rather than an allow-list.

    The work machine's future stated as a test: the identical ref that is refused above becomes
    authorable when `recon-adapter-jira` is discoverable -- with no code change and no second ruling.
    """
    adapters = tmp_path / "adapters"
    adapters.mkdir()
    stub = adapters / "recon-adapter-jira"
    stub.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    stub.chmod(0o755)
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters))

    _run("scaffold", "--repository", repository, "--name", "demo")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "PROJ-2107") == 0
    assert [row["ref"] for row in _read(repository)["rows"]] == ["PROJ-2107"]


def test_add_row_never_authors_a_reference_kind(repository, capsys):
    """Refused for the OPPOSITE reason: `ready_set` skips a link parent, so it is inert rather than
    wedging. It is still not this writer's to create -- a reference is context a human attaches."""
    _run("scaffold", "--repository", repository, "--name", "demo")
    capsys.readouterr()
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "https://x.co/a") == 1
    assert "Reference kinds are context a human attaches" in capsys.readouterr().err


def test_add_row_still_authors_github_refs(repository, monkeypatch, tmp_path):
    """github is resolvable without any adapter -- `grid` carries a built-in targeted fetch."""
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(tmp_path / "none"))
    _run("scaffold", "--repository", repository, "--name", "demo")
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 0


# ── `.stacks/` is the ONE manifest root; `.borg/chains` and `.borg/programs` are retired ─────────
# Step (c) of the chain -> stack rename. Every test below that used to pin a two-root rule (a stem in both
# roots refused, `--root borg` creating under `.borg/chains`) is replaced by the rule that took its place: a
# manifest under a retired root is never read, and the repository is told so, by name.
def _legacy_path(repository, name="demo", directory="chains"):
    return os.path.join(repository, ".borg", directory, f"{name}.json")


def _put_legacy(repository, name, directory="chains"):
    """A VALID manifest under a retired root: the premise that makes "not read" a decision, not an accident."""
    path = _legacy_path(repository, name, directory)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"program": name, "rows": [{"ref": "acme/ledger#1", "order": "1"}]}, handle)
    return path


def _put_stacks(repository, name="demo"):
    os.makedirs(os.path.join(repository, shell.STACKS_DIRNAME), exist_ok=True)
    with open(_path(repository, name), "w", encoding="utf-8") as handle:
        json.dump({"program": name, "rows": []}, handle)


def _root_args(root):
    return ["--root", root] if root else []


def test_resolve_finds_a_stacks_manifest(repository, capsys):
    _put_stacks(repository, "alpha")
    assert _run("resolve", "--repository", repository) == 0
    assert capsys.readouterr().out.strip() == "alpha"


def test_resolve_never_counts_a_retired_root_manifest_and_names_the_repository_and_the_migration(repository, capsys):
    """A VALID manifest under `.borg/chains` is not a candidate: it is not read, and the warning says so.

    MUTATION: restore the `.borg/chains` read in `shell.manifest_roots` and `bravo` becomes a second candidate,
    so `resolve` stops printing a bare `alpha`.
    """
    _put_stacks(repository, "alpha")
    _put_legacy(repository, "bravo")
    assert _run("resolve", "--repository", repository) == 0
    captured = capsys.readouterr()
    assert captured.out.strip() == "alpha"
    assert repository in captured.err and "borg stack migrate" in captured.err


@pytest.mark.parametrize("directory", ["chains", "programs"])
def test_resolve_on_a_repository_holding_only_retired_manifests_says_no_manifest_and_why(repository, capsys, directory):
    """Not an empty answer presented as the truth: exit 1, and the reason names the repository and the cure."""
    _put_legacy(repository, "alpha", directory)
    assert _run("resolve", "--repository", repository) == 1
    err = capsys.readouterr().err
    assert "no manifest under" in err
    assert repository in err and f".borg/{directory}" in err and "borg stack migrate" in err


def test_a_stem_in_both_roots_is_no_longer_a_refusal_only_the_stacks_copy_is_read(repository, capsys):
    """The old both-roots refusal is gone with the second root: `.stacks/` wins, the retired copy is warned about."""
    _put_stacks(repository, "alpha")
    _put_legacy(repository, "alpha")
    assert _run("resolve", "--repository", repository) == 0
    captured = capsys.readouterr()
    assert captured.out.strip() == "alpha"
    assert "declared in both" not in captured.err and "borg stack migrate" in captured.err


def test_scaffold_refuses_by_name_when_a_root_it_must_check_is_unreadable(repository, capsys):
    """MUTATION: delete the `unreadable_roots` refusal in `_cmd_scaffold` and this goes red."""
    _put_stacks(repository, "alpha")
    stacks = os.path.join(repository, shell.STACKS_DIRNAME)
    os.chmod(stacks, 0)
    try:
        if os.access(stacks, os.R_OK):
            pytest.skip("permissions are not enforced (running as root)")
        assert _run("scaffold", "--repository", repository, "--name", "alpha") == 1
        assert stacks in capsys.readouterr().err
    finally:
        os.chmod(stacks, 0o755)
    assert os.listdir(stacks) == ["alpha.json"]
    assert not os.path.exists(os.path.join(repository, ".borg"))


def test_add_row_on_a_stacks_manifest_writes_back_to_stacks(repository):
    _put_stacks(repository)
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "acme/ledger#1") == 0
    with open(_path(repository), encoding="utf-8") as handle:
        assert [r["ref"] for r in json.load(handle)["rows"]] == ["acme/ledger#1"]
    assert not os.path.exists(os.path.join(repository, ".borg", "chains")), "nothing lands under .borg"


def test_close_on_a_stacks_manifest_writes_back_to_stacks(repository):
    _put_stacks(repository)
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "acme/ledger#1")
    assert _run("close", "--repository", repository, "--name", "demo", "--ref", "acme/ledger#1",
                "--status", "merged") == 0
    with open(_path(repository), encoding="utf-8") as handle:
        assert json.load(handle)["rows"][0]["status"] == "merged"
    assert not os.path.exists(os.path.join(repository, ".borg"))


def test_add_row_on_a_manifest_only_under_a_retired_root_refuses_and_names_the_migration(repository, capsys):
    """The old both-roots refusal, replaced: the retired copy is not edited, and the author is told where it went.

    MUTATION: restore the `.borg/chains` lookup in `shell.locate_manifest` and the edit lands in the retired file.
    """
    legacy = _put_legacy(repository, "demo")
    with open(legacy, "rb") as handle:
        before = handle.read()
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "acme/ledger#2") == 1
    err = capsys.readouterr().err
    assert "no manifest at" in err and repository in err and "borg stack migrate" in err
    with open(legacy, "rb") as handle:
        assert handle.read() == before, "the retired copy is untouched"
    assert not os.path.exists(os.path.join(repository, shell.STACKS_DIRNAME))


@pytest.mark.parametrize("verb", ["scaffold", "add-row", "close", "resolve"])
def test_root_borg_is_refused_by_name_on_every_verb_and_nothing_is_touched(repository, capsys, verb):
    """`--root borg` named the retired root. It exits non-zero, says why, points at `.stacks/`, writes nothing.

    MUTATION: delete the `ROOT_BORG` check in `cli.main` and `scaffold` creates `.stacks/demo.json` (exit 0).
    """
    assert _run(verb, "--repository", repository, "--name", "demo", "--ref", "acme/ledger#1", "--root", "borg") == 1
    err = capsys.readouterr().err
    assert "--root borg" in err and "no longer accepted" in err and ".stacks/" in err and "borg stack migrate" in err
    assert not os.path.exists(repository), "refused before anything was read or created"


def test_scaffold_refuses_to_shadow_a_manifest_that_is_still_under_a_retired_root(repository, capsys):
    """The old both-roots refusal, moved to the one verb that creates: an empty `.stacks/` twin would shadow the
    real manifest and make `borg stack migrate` refuse the stem. MUTATION: delete `locate_unmigrated`'s check in
    `_cmd_scaffold` and this writes `.stacks/demo.json` over nothing, exit 0."""
    legacy = _put_legacy(repository, "demo")
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 1
    err = capsys.readouterr().err
    assert legacy in err and "borg stack migrate" in err and "refusing to scaffold" in err
    assert not os.path.exists(os.path.join(repository, shell.STACKS_DIRNAME))


def test_scaffold_does_not_recreate_a_manifest_that_already_lives_in_stacks(repository, capsys):
    _put_stacks(repository)
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert "exists:" in capsys.readouterr().out
    assert not os.path.exists(_legacy_path(repository))


def test_scaffold_does_not_replace_a_manifest_whose_name_differs_only_in_case(repository, capsys):
    path = _path(repository, "alpha")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"program": "alpha", "rows": [{"ref": "acme/ledger#1", "status": "open"}]}, handle)
    if not os.path.exists(os.path.join(os.path.dirname(path), "ALPHA.json")):
        pytest.skip("case-sensitive filesystem")
    assert _run("scaffold", "--repository", repository, "--name", "Alpha") == 0
    with open(path, encoding="utf-8") as handle:
        assert len(json.load(handle)["rows"]) == 1


# ── a `.stacks` that is a symlink to a retired directory is read, so it is not "unmigrated" ──────
def _alias_roots(repository):
    """`.stacks` as a symlink to `.borg/chains`, holding one manifest named `alpha`."""
    chains = os.path.dirname(_put_legacy(repository, "alpha"))
    os.symlink(chains, os.path.join(repository, shell.STACKS_DIRNAME))
    return chains


def test_a_stacks_symlink_to_a_retired_directory_is_read_once_and_raises_no_unmigrated_warning(repository, capsys):
    """MUTATION: drop the realpath de-duplication in `shell.unmigrated_warnings` and the directory `.stacks` already
    reads is ALSO reported as holding unread manifests, a false alarm for a repository that is working."""
    chains = _alias_roots(repository)
    assert _run("resolve", "--repository", repository) == 0
    captured = capsys.readouterr()
    assert captured.out.strip() == "alpha" and "borg stack migrate" not in captured.err
    assert _run("add-row", "--repository", repository, "--name", "alpha", "--ref", "acme/ledger#1") == 0
    assert os.listdir(chains) == ["alpha.json"], "one real file, no sibling written"
    with open(_legacy_path(repository, "alpha"), encoding="utf-8") as handle:
        assert [r["ref"] for r in json.load(handle)["rows"]] == ["acme/ledger#1"]


def test_not_found_messages_name_the_one_root_and_only_name_a_retired_one_when_it_holds_manifests(repository, capsys):
    assert _run("resolve", "--repository", repository) == 1
    err = capsys.readouterr().err
    assert shell.STACKS_DIRNAME in err and os.path.join(".borg", "chains") not in err
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "acme/ledger#1") == 1
    err = capsys.readouterr().err
    assert shell.STACKS_DIRNAME in err and os.path.join(".borg", "chains") not in err


# ── scaffold: where a NEW manifest is created ────────────────────────────────────────────────────
def _git_init(repository, ignore=None):
    os.makedirs(repository, exist_ok=True)
    subprocess.run(["git", "init", "-q"], cwd=repository, check=True, capture_output=True)
    if ignore:
        with open(os.path.join(repository, ".gitignore"), "w", encoding="utf-8") as handle:
            handle.write(ignore + "\n")


def test_scaffold_root_stacks_writes_under_stacks_and_reports_it(repository, capsys):
    assert _run("scaffold", "--repository", repository, "--name", "demo", "--root", "stacks") == 0
    assert os.path.isfile(_path(repository))
    assert not os.path.exists(_legacy_path(repository))
    out = capsys.readouterr().out.splitlines()
    assert out[0] == f"scaffolded: {_path(repository)}"
    assert out[1].startswith(f"root: {os.path.join(repository, shell.STACKS_DIRNAME)} (") and "--root stacks" in out[1]


def test_scaffold_default_is_stacks_when_nothing_exists(repository, capsys):
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert os.path.isfile(_path(repository))
    assert not os.path.exists(_legacy_path(repository))
    out = capsys.readouterr().out.splitlines()
    assert out[1].startswith(f"root: {os.path.join(repository, shell.STACKS_DIRNAME)} (") and "default" in out[1]


def test_scaffold_default_follows_an_existing_stacks_dir(repository, capsys):
    os.makedirs(os.path.join(repository, ".stacks"))
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert os.path.isfile(_path(repository))
    assert ".stacks/ already exists" in capsys.readouterr().out


def test_scaffold_default_is_stacks_even_when_an_ignored_borg_dir_exists(repository):
    _git_init(repository, ".borg/")
    os.makedirs(os.path.join(repository, ".borg", "chains"))
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert os.path.isfile(_path(repository))
    assert not os.path.exists(_legacy_path(repository))


def test_scaffold_default_is_stacks_in_a_repository_already_holding_an_empty_borg_chains(repository, capsys):
    _git_init(repository)
    os.makedirs(os.path.join(repository, ".borg", "chains"))
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert os.path.isfile(_path(repository))
    assert not os.path.exists(_legacy_path(repository))
    assert capsys.readouterr().out.splitlines()[1].startswith(f"root: {os.path.join(repository, '.stacks')} (")


def test_scaffold_default_is_stacks_in_a_fresh_git_repository(repository, capsys):
    _git_init(repository)
    assert _run("scaffold", "--repository", repository, "--name", "demo") == 0
    assert os.path.isfile(_path(repository))
    assert capsys.readouterr().out.splitlines()[1].startswith(f"root: {os.path.join(repository, '.stacks')} (")


@pytest.mark.parametrize("root_args", [(), ("--root", "stacks")])
def test_scaffold_refuses_by_name_when_git_ignores_stacks(repository, capsys, root_args):
    """Never a silent fallback, and nothing is created: the refusal names the ignore, and there is no other root
    left to offer. MUTATION: swallow `StacksIgnored` and scaffold into the ignored path, and the existence check
    goes red."""
    _git_init(repository, ".stacks/")
    assert _run("scaffold", "--repository", repository, "--name", "demo", *root_args) == 1
    err = capsys.readouterr().err
    assert err.startswith("demo: refusing to scaffold") and "ignores" in err and "--root borg" not in err
    assert not os.path.exists(_path(repository)) and not os.path.exists(_legacy_path(repository))
    assert not os.path.exists(os.path.join(repository, shell.STACKS_DIRNAME))


def test_root_borg_is_no_way_past_an_ignored_stacks(repository, capsys):
    """The old escape hatch is closed: with `.stacks/` ignored, `--root borg` is refused rather than honoured."""
    _git_init(repository, ".stacks/")
    assert _run("scaffold", "--repository", repository, "--name", "demo", "--root", "borg") == 1
    assert "no longer accepted" in capsys.readouterr().err
    assert not os.path.exists(_legacy_path(repository)) and not os.path.exists(_path(repository))


@pytest.mark.parametrize("first,second", [("", "stacks"), ("stacks", "")])
def test_scaffold_is_idempotent_across_the_root_spellings(repository, capsys, first, second):
    _run("scaffold", "--repository", repository, "--name", "demo", *_root_args(first))
    capsys.readouterr()
    assert _run("scaffold", "--repository", repository, "--name", "demo", *_root_args(second)) == 0
    out = capsys.readouterr().out
    assert out.startswith("exists: ") and "scaffolded" not in out
    assert not os.path.exists(_legacy_path(repository))


def test_scaffold_still_refuses_beside_an_unreadable_root(repository, capsys):
    _put_stacks(repository, "alpha")
    stacks = os.path.join(repository, shell.STACKS_DIRNAME)
    os.chmod(stacks, 0)
    try:
        if os.access(stacks, os.R_OK):
            pytest.skip("root can read a mode-0 directory")
        assert _run("scaffold", "--repository", repository, "--name", "demo") == 1
        assert "refusing to scaffold" in capsys.readouterr().err
    finally:
        os.chmod(stacks, 0o755)
    assert not os.path.exists(_legacy_path(repository))


def test_scaffold_rejects_an_invalid_root_value(repository):
    with pytest.raises(SystemExit) as raised:
        _run("scaffold", "--repository", repository, "--name", "demo", "--root", "elsewhere")
    assert raised.value.code == 2
    assert not os.path.exists(repository)


@pytest.mark.parametrize("root", [None, "stacks"])
def test_scaffold_does_not_replace_a_stacks_manifest_whose_name_differs_only_in_case(repository, capsys, root):
    """MUTATION: drop the filesystem fallback in `locate_manifest` and `.stacks/ALPHA.json` is emptied."""
    os.makedirs(os.path.join(repository, shell.STACKS_DIRNAME))
    path = os.path.join(repository, shell.STACKS_DIRNAME, "ALPHA.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"program": "ALPHA", "rows": [{"ref": "acme/ledger#1", "status": "open"}]}, handle)
    if not os.path.exists(_path(repository, "alpha")):
        pytest.skip("case-sensitive filesystem")
    extra = ["--root", root] if root else []
    assert _run("scaffold", "--repository", repository, "--name", "alpha", *extra) == 0
    assert capsys.readouterr().out.startswith("exists: ")
    with open(path, encoding="utf-8") as handle:
        assert len(json.load(handle)["rows"]) == 1


@pytest.mark.parametrize("root", [None, "stacks"])
def test_scaffold_names_a_stacks_path_that_is_a_file(repository, capsys, root):
    _git_init(repository, ".borg/")
    with open(os.path.join(repository, shell.STACKS_DIRNAME), "w", encoding="utf-8") as handle:
        handle.write("not a directory")
    extra = ["--root", root] if root else []
    assert _run("scaffold", "--repository", repository, "--name", "demo", *extra) == 1
    err = capsys.readouterr().err
    assert "not a directory" in err and shell.STACKS_DIRNAME in err and "Errno" not in err


# ── authored `_`-prefixed keys survive an in-place edit (PR #341 fix round 1) ────────────────────
def _author_a_comment(repository):
    _run("scaffold", "--repository", repository, "--name", "demo")
    doc = _read(repository)
    doc.update({"_comment": "hand-written, not derived", "_note": ["kept", "too"]})
    with open(_path(repository), "w", encoding="utf-8") as handle:
        json.dump(doc, handle)


def _assert_comment_kept_and_stamps_absent(repository):
    doc = _read(repository)
    assert doc["_comment"] == "hand-written, not derived" and doc["_note"] == ["kept", "too"]
    assert "_id" not in doc and "_path" not in doc


def test_add_row_preserves_an_authored_underscore_key(repository):
    _author_a_comment(repository)
    assert _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 0
    _assert_comment_kept_and_stamps_absent(repository)


def test_close_preserves_an_authored_underscore_key(repository):
    _author_a_comment(repository)
    _run("add-row", "--repository", repository, "--name", "demo", "--ref", "o/r#1")
    assert _run("close", "--repository", repository, "--name", "demo", "--ref", "o/r#1") == 0
    _assert_comment_kept_and_stamps_absent(repository)
