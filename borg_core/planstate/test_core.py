"""AC6's parser half, plus the purity walk `pyproject.toml`'s Domain list cannot supply.

Every case here is over `core.py` alone, which is pure -- so these are the only tests in the package
that legitimately hand a function its inputs. Every test that produces a VERDICT lives in
test_evidence.py and drives the real resolver; see that module's header for why the split matters.
"""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.planstate import core

PLAN = """# A plan

## Acceptance criteria

- [ ] AC1 an unannotated criterion carrying only prose.
  - Verify: someone reads it and decides.
- [x] AC2 a criterion that is already checked.
  - Verify: prose again.
  - Evidence: `path:README.md`
- [ ] AC3 a criterion whose annotation is malformed.
  - Evidence: `wat:borg_core/`
- [ ] AC4 a criterion with a real annotation.

  - Evidence: `pytest:borg_core/planstate/`

Some closing prose that is not a criterion.
"""


def test_parses_every_criterion_and_no_prose_line():
    criteria = core.parse_criteria(PLAN)
    assert [entry["text"][:3] for entry in criteria] == ["AC1", "AC2", "AC3", "AC4"]
    assert [entry["checked"] for entry in criteria] == [False, True, False, False]


def test_an_unannotated_criterion_has_no_annotation_and_does_not_borrow_the_next_one():
    criteria = core.parse_criteria(PLAN)
    assert criteria[0]["annotation"] is None
    assert criteria[0]["annotation_line"] is None


def test_backticks_are_stripped_and_the_verify_sibling_is_never_matched():
    criteria = core.parse_criteria(PLAN)
    assert criteria[1]["annotation"] == "path:README.md"


def test_a_blank_line_between_the_criterion_and_its_evidence_does_not_end_the_scan():
    # The 120-wrap in this repository's own directives puts blank lines inside a criterion's block.
    # Stopping at the first blank line reads every such file as unannotated.
    criteria = core.parse_criteria(PLAN)
    assert criteria[3]["annotation"] == "pytest:borg_core/planstate/"


def test_the_criterion_test_matches_link_cores_counter_exactly():
    # A file where `borg link` says 1/4 and planstate says 1/5 has two truths in it. Asserted
    # against the real `plan_progress`, not against a transcription of it.
    from borg_core.link import core as link_core

    met, total = link_core.plan_progress(PLAN)
    criteria = core.parse_criteria(PLAN)
    assert (met, total) == (sum(1 for entry in criteria if entry["checked"]), len(criteria))


def test_every_kind_validates_and_reports_its_kind_and_value():
    for raw, kind, value in [
        ("pr:stillpoint-labs/ingle#42", "pr", "stillpoint-labs/ingle#42"),
        ("path:docs/plans", "path", "docs/plans"),
        ("bats:tests/link.bats", "bats", "tests/link.bats"),
        ("pytest:borg_core/planstate/", "pytest", "borg_core/planstate/"),
    ]:
        gate = core.validate_annotation(raw)
        assert gate["ok"], gate["reason"]
        assert (gate["kind"], gate["value"]) == (kind, value)


def test_a_malformed_or_absent_annotation_is_refused_with_a_reason_and_never_raises():
    for raw in [None, "", "wat:borg_core/", "pytest:", "pr:borg-collective#191", "path:/etc/passwd", "path:../../x"]:
        gate = core.validate_annotation(raw)
        assert gate["ok"] is False
        assert gate["reason"]


def test_the_pr_gate_is_manifest_parse_ref_and_not_a_second_regex():
    # Same vocabulary as the fetch path, asserted by agreement rather than by reading the source.
    from borg_core.manifest import core as manifest_core

    for ref in ["o/r#1", "o/r#007", "borg-collective#191", "PROJ-12", "o/r#x"]:
        assert core.validate_annotation(f"pr:{ref}")["ok"] is (manifest_core.parse_ref(ref) is not None)


def test_apply_flips_changes_only_the_checkbox_byte():
    before = "- [ ] AC1 trailing spaces survive   \n- [ ] AC2\n"
    after = core.apply_flips(before, [0])
    assert after == "- [x] AC1 trailing spaces survive   \n- [ ] AC2\n"
    assert len(after) == len(before)


def test_apply_flips_is_a_no_op_on_an_already_checked_or_out_of_range_line():
    before = "- [x] AC1\n- [ ] AC2\n"
    assert core.apply_flips(before, [0, 99, -3]) == before


def test_core_imports_nothing_impure():
    """The AST walk test_picture.py and test_render.py both carry, for the reason their pyproject
    paragraphs give: W9004's allow-list permits `pathlib`, `json` and `datetime`, so the linter is
    the coarser gate and an exact ROOT set is what actually blocks an impurity. Deliberately blind to
    WHICH `borg_core` sibling is imported; any root outside the set fails."""
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
    assert roots == {"__future__", "re", "borg_core"}
