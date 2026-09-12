"""AC8 (as restated 2026-09-11) and AC2: `--apply` flips only `pass` criteria, stamps each flip with
its evidence in the SAME atomic write, and changes nothing else.

This file is the artifact the directive's AC8 names in its own `Evidence:` annotation
(`pytest:borg_core/planstate/test_write.py`), so its path is a pin -- moving it must move that line.

THE VERDICTS ARE DERIVED, NOT DECLARED. The fixture plan's four criteria resolve through the same
production path test_evidence.py drives: a `path:` that exists (pass), a `path:` that does not
(fail), a suite pin that rotted (unknown), and one already `[x]`. Handing `apply` a hand-written
`flips` list would test `core.apply_flips` and nothing about which criteria reach it.

AND THE INDICES ARE NOT ASSUMED STILL VALID. `test_a_line_inserted_above_the_target_...` is the
scenario `apply`'s own docstring has always described -- a human edits the plan while a suite runs --
and until 2026-09-11 the guard tested line SHAPE rather than criterion IDENTITY, so that edit flipped
the neighbour.
"""

from __future__ import annotations

import json as jsonlib
import os
import re
from pathlib import Path

from borg_core.planstate import cli, core, derive as derive_mod, shell

# AC8's "a pattern-matching suffix", written once as a pattern so no case here can pass by asserting
# on a literal the implementation also hard-codes. `[^)]*` rather than `.*` so a suffix that ran on
# past its own closing `)*` would not match.
ANNOTATION_RE = re.compile(rb" \*\(flipped by link-up: [^)\n]+\)\*\Z")

# One pass, one fail, one unknown, one already-`[x]`, and a decoy `- [ ]` inside an indented block
# that is NOT a criterion. Deliberately ugly: trailing whitespace on one line, a 120-ish wrap, and a
# criterion whose own text contains the string `- [ ]`.
PLAN = (
    "# Fixture plan\n"
    "\n"
    "## Acceptance criteria\n"
    "\n"
    "- [ ] AC1 the deliverable exists.   \n"
    "  - Verify: a human reads it.\n"
    "  - Evidence: `path:docs/shipped.md`\n"
    "- [ ] AC2 the deliverable does not exist, and this criterion says `- [ ]` in its own text.\n"
    "  - Evidence: `path:docs/never-written.md`\n"
    "- [ ] AC3 the pin rotted.\n"
    "  - Evidence: `pytest:borg_core/gone/`\n"
    "- [x] AC4 already checked, and its evidence still passes.\n"
    "  - Evidence: `path:docs/shipped.md`\n"
    "\n"
    "Closing prose.\n"
)


def _exit_code(entry, argv) -> int:
    """Run a `main`-shaped entrypoint and return the status it exited with. `cli.main` signals
    success as `SystemExit(0)`, the shape `borg_core/link/cli.py` established."""
    try:
        entry(argv)
    except SystemExit as exc:
        return int(exc.code or 0)
    return 0


def _fixture(root: Path) -> Path:
    (root / "docs").mkdir(parents=True, exist_ok=True)
    (root / "docs/shipped.md").write_text("shipped\n", encoding="utf-8")
    plan = root / "PROJECT_PLAN.md"
    plan.write_text(PLAN, encoding="utf-8")
    return plan


def test_the_run_flips_exactly_the_pass_and_the_file_is_otherwise_byte_identical(tmp_path):
    """AC8 as restated 2026-09-11: the only changes are the checkbox character and, appended to that
    same line, an annotation matching the fixed pattern. Every other byte is unchanged."""
    plan = _fixture(tmp_path)
    before = plan.read_bytes()
    report = derive_mod.derive(plan, tmp_path)
    assert [row["verdict"] for row in report["criteria"]] == [core.PASS, core.FAIL, core.UNKNOWN, core.PASS]
    assert derive_mod.apply(plan, report) == 1
    after = plan.read_bytes()

    old_lines = before.split(b"\n")
    new_lines = after.split(b"\n")
    # NO LINE MOVED: the file has exactly as many lines as it started with, so every index below
    # compares the same line to itself and not a shifted neighbour.
    assert len(new_lines) == len(old_lines)
    differing = [(i, o, n) for i, (o, n) in enumerate(zip(old_lines, new_lines)) if o != n]
    assert len(differing) == 1
    _, old, new = differing[0]
    assert old == b"- [ ] AC1 the deliverable exists.   "
    # THE DELTA, DECOMPOSED: strip the pattern-matching suffix off the new line and what remains must
    # be the old line with only its checkbox byte changed. Asserted in that order so a suffix that
    # did not match leaves nothing for the checkbox assertion to accidentally satisfy.
    suffix = ANNOTATION_RE.search(new)
    assert suffix, new
    body = new[: suffix.start()]
    assert [i for i, (a, b) in enumerate(zip(old, body)) if a != b] == [3]
    assert len(body) == len(old)
    assert body[3:4] == b"x" and old[3:4] == b" "
    # AC2: the flip carries its own evidence, verbatim from the row the verdict came from.
    assert suffix.group(0) == f" *(flipped by link-up: {report['criteria'][0]['evidence']})*".encode()


def test_the_fail_and_the_unknown_survive_the_same_run_untouched(tmp_path):
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    lines = plan.read_text(encoding="utf-8").split("\n")
    assert lines[7].startswith("- [ ] AC2")
    assert lines[9].startswith("- [ ] AC3")


def test_an_already_checked_criterion_is_not_rewritten_even_when_its_evidence_passes(tmp_path):
    plan = _fixture(tmp_path)
    report = derive_mod.derive(plan, tmp_path)
    assert report["criteria"][3]["verdict"] == core.PASS
    assert report["criteria"][3]["would_flip"] is False
    assert [entry["line"] for entry in report["flips"]] == [report["criteria"][0]["line"]]


def test_a_flip_entry_carries_the_identity_and_the_evidence_the_writer_needs(tmp_path):
    plan = _fixture(tmp_path)
    row = derive_mod.derive(plan, tmp_path)["flips"][0]
    assert row["text"] == "AC1 the deliverable exists."
    assert row["evidence"] == "path:docs/shipped.md exists"


def test_a_line_inserted_above_the_target_between_derive_and_apply_flips_nothing(tmp_path):
    """THE BUG. The indices in a report are captured during a derive that may have run a suite for
    minutes; a human editing the plan in that window shifts every one of them. The old guard tested
    only that the line at the index still started with `- [ ]`, which in an acceptance-criteria block
    is true of EVERY NEIGHBOUR -- so the criterion BELOW the target was flipped instead, silently and
    with the wrong evidence attached to it."""
    plan = _fixture(tmp_path)
    report = derive_mod.derive(plan, tmp_path)
    assert [entry["line"] for entry in report["flips"]] == [4]

    # A human adds a criterion above AC1 while the derive was running. Every index shifts by one, and
    # index 4 now holds AC2 -- a `- [ ]` line, and a criterion whose verdict was FAIL.
    lines = plan.read_text(encoding="utf-8").split("\n")
    lines.insert(4, "- [ ] AC0 added by a human mid-derive.")
    plan.write_text("\n".join(lines), encoding="utf-8")
    before = plan.read_bytes()

    assert derive_mod.apply(plan, report) == 0
    after = plan.read_bytes()
    assert after == before, "a shifted index must be a no-op, not a flip of the neighbour"
    assert b"- [ ] AC2 the deliverable does not exist" in after
    assert b"flipped by link-up" not in after


def test_a_run_with_nothing_to_flip_does_not_touch_the_file_at_all(tmp_path):
    # `borg link` sorts directives by mtime; a no-op --apply that rewrote 30 files byte-identically
    # would reorder that board every session.
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    stamp = plan.stat().st_mtime_ns
    assert derive_mod.apply(plan, derive_mod.derive(plan, tmp_path)) == 0
    assert plan.stat().st_mtime_ns == stamp


def test_an_annotated_criterion_reopened_by_hand_is_reflipped_without_a_second_annotation(tmp_path):
    # The recovery case: someone un-ticks a box the engine annotated (or a crash left one half
    # written). Re-running must restore the checkbox and NOT stack a second attribution on the line.
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    text = plan.read_text(encoding="utf-8")
    plan.write_text(text.replace("- [x] AC1", "- [ ] AC1", 1), encoding="utf-8")

    assert derive_mod.apply(plan, derive_mod.derive(plan, tmp_path)) == 1
    after = plan.read_text(encoding="utf-8")
    assert after == text
    assert after.count("flipped by link-up") == 1


def test_the_write_is_atomic_and_leaves_no_tmp_file_beside_the_plan(tmp_path):
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    assert [entry.name for entry in tmp_path.iterdir() if entry.name.startswith(".planstate-")] == []


def test_json_mode_writes_nothing_and_apply_mode_does(tmp_path, capsys):
    plan = _fixture(tmp_path)
    before = plan.read_bytes()
    # `main` ALWAYS exits -- success is `SystemExit(0)`, mirroring `link/cli.py`. A test that called
    # it bare would be asserting on an exception, so the contract is stated instead.
    assert _exit_code(cli.main, [str(plan), "--json", "--root", str(tmp_path)]) == 0
    report = jsonlib.loads(capsys.readouterr().out)
    assert plan.read_bytes() == before
    assert report["counts"]["would_flip"] == 1

    assert _exit_code(cli.main, [str(plan), "--json", "--apply", "--root", str(tmp_path)]) == 0
    applied = jsonlib.loads(capsys.readouterr().out)
    assert applied["applied"] == 1
    assert plan.read_bytes() != before

    # AC2's verify clause, LITERALLY: the fixture plan's one passing annotated criterion goes through
    # `--apply`, and the resulting FILE carries `flipped by link-up` on exactly that criterion's line.
    # The old clause grepped the SKILL for the format string, which would have stayed green through
    # total failure of the behaviour it names.
    marked = [line for line in plan.read_text(encoding="utf-8").split("\n") if "flipped by link-up" in line]
    assert len(marked) == 1
    assert marked[0].startswith("- [x] AC1 the deliverable exists.")


def test_the_human_mode_names_every_criterions_evidence_line(tmp_path, capsys):
    plan = _fixture(tmp_path)
    assert _exit_code(cli.main, [str(plan), "--root", str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert "pin rotted" in out
    assert "does not exist" in out
    assert "1 would flip" in out


def test_cli_main_raises_systemexit_zero_and_json_mode_reports_a_missing_plan_as_json(tmp_path, capsys):
    assert _exit_code(cli.main, [str(tmp_path / "no-such-plan.md"), "--json"]) == 1
    payload = jsonlib.loads(capsys.readouterr().out)
    assert "error" in payload


def test_derive_refuses_a_plan_it_cannot_read(tmp_path):
    missing = tmp_path / "nope.md"
    raised = False
    try:
        derive_mod.derive(missing, tmp_path)
    except FileNotFoundError:
        raised = True
    assert raised


def test_repo_root_walks_up_for_dot_git(tmp_path):
    (tmp_path / ".git").mkdir()
    nested = tmp_path / "docs/plans/directives"
    nested.mkdir(parents=True)
    plan = nested / "x.md"
    plan.write_text("- [ ] AC1\n", encoding="utf-8")
    assert derive_mod.repo_root(plan) == tmp_path.resolve()


def test_repo_root_falls_back_to_the_containing_directory_outside_a_repository(tmp_path):
    # `tmp_path` is under /private/var on macOS and /tmp on Linux; neither has a `.git` ancestor,
    # but the assertion is written so that a machine where one DOES exist still reads correctly.
    plan = tmp_path / "loose.md"
    plan.write_text("- [ ] AC1\n", encoding="utf-8")
    root = derive_mod.repo_root(plan)
    assert (root / ".git").exists() or root == tmp_path.resolve()


def test_write_atomic_replaces_contents_without_changing_the_inode_path(tmp_path):
    target = tmp_path / "f.md"
    target.write_text("old\n", encoding="utf-8")
    shell.write_atomic(target, "new\n")
    assert target.read_text(encoding="utf-8") == "new\n"
    assert os.path.isfile(target)
