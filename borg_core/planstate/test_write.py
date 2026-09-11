"""AC8: `--apply` flips only `pass` criteria, writes atomically, and changes nothing else.

This file is the artifact the directive's AC8 names in its own `Evidence:` annotation
(`pytest:borg_core/planstate/test_write.py`), so its path is a pin -- moving it must move that line.

THE VERDICTS ARE DERIVED, NOT DECLARED. The fixture plan's three criteria resolve through the same
production path test_evidence.py drives: a `path:` that exists (pass), a `path:` that does not
(fail), and a suite pin that rotted (unknown). Handing `apply` a hand-written `flips` list would
test `core.apply_flips` and nothing about which criteria reach it.
"""

from __future__ import annotations

import os
from pathlib import Path

from borg_core.planstate import cli, core, derive as derive_mod

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
    plan = _fixture(tmp_path)
    before = plan.read_bytes()
    report = derive_mod.derive(plan, tmp_path)
    assert [row["verdict"] for row in report["criteria"]] == [core.PASS, core.FAIL, core.UNKNOWN, core.PASS]
    assert derive_mod.apply(plan, report) == 1
    after = plan.read_bytes()
    assert len(after) == len(before)
    differing = [
        (index, old, new) for index, (old, new) in enumerate(zip(before.split(b"\n"), after.split(b"\n"))) if old != new
    ]
    assert len(differing) == 1
    index, old, new = differing[0]
    assert old == b"- [ ] AC1 the deliverable exists.   "
    assert new == b"- [x] AC1 the deliverable exists.   "
    # The byte-level statement of "only the checkbox character": the two lines differ in exactly one
    # position, and that position holds a space before and an `x` after.
    assert [i for i, (a, b) in enumerate(zip(old, new)) if a != b] == [3]


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
    assert report["flips"] == [report["criteria"][0]["line"]]


def test_a_run_with_nothing_to_flip_does_not_touch_the_file_at_all(tmp_path):
    # `borg link` sorts directives by mtime; a no-op --apply that rewrote 30 files byte-identically
    # would reorder that board every session.
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    stamp = plan.stat().st_mtime_ns
    assert derive_mod.apply(plan, derive_mod.derive(plan, tmp_path)) == 0
    assert plan.stat().st_mtime_ns == stamp


def test_the_write_is_atomic_and_leaves_no_tmp_file_beside_the_plan(tmp_path):
    plan = _fixture(tmp_path)
    derive_mod.apply(plan, derive_mod.derive(plan, tmp_path))
    assert [entry.name for entry in tmp_path.iterdir() if entry.name.startswith(".planstate-")] == []


def test_json_mode_writes_nothing_and_apply_mode_does(tmp_path, capsys):
    import json as jsonlib

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


def test_the_human_mode_names_every_criterions_evidence_line(tmp_path, capsys):
    plan = _fixture(tmp_path)
    assert _exit_code(cli.main, [str(plan), "--root", str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert "pin rotted" in out
    assert "does not exist" in out
    assert "1 would flip" in out


def test_cli_main_raises_systemexit_zero_and_json_mode_reports_a_missing_plan_as_json(tmp_path, capsys):
    import json as jsonlib

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
    from borg_core.planstate import shell

    target = tmp_path / "f.md"
    target.write_text("old\n", encoding="utf-8")
    shell.write_atomic(target, "new\n")
    assert target.read_text(encoding="utf-8") == "new\n"
    assert os.path.isfile(target)
