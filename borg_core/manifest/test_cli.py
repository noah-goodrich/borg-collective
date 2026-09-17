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
    os.makedirs(os.path.join(repository, ".borg", "programs"), exist_ok=True)
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
    programs = tmp_path / ".borg" / "programs"
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
