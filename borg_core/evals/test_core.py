"""Pure-core tests: glob semantics, ledger problems, and the selector's three outcomes."""

from __future__ import annotations

import ast
from pathlib import Path
from typing import Any

from borg_core.evals import core

LEDGER: dict[str, Any] = {
    "version": 1,
    "evals": {
        "evals/a": {"covers": ["evals/a/**", "skills/x/**", "borg_core/mod/*.py"]},
        "evals/b": {"covers": ["borg_core/**/shared.py"]},
    },
    "items": {
        "skills/x": {"eval": "evals/a"},
        "skills/y": {"waiver": "later", "review_by": "2026-12-01"},
    },
}
DISK = ["skills/x", "skills/y"]
EXIST = {"evals/a", "evals/b"}


def problems(ledger=LEDGER, disk=DISK, exist=EXIST, today="2026-10-03"):
    return core.ledger_problems(ledger, disk, exist, today)


def test_core_imports_nothing_impure() -> None:
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module}
    roots |= {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
    assert roots == {"__future__", "re", "typing"}


def test_glob_star_stays_in_segment_and_doublestar_crosses() -> None:
    assert core.matches("borg_core/mod/a.py", ["borg_core/mod/*.py"])
    assert not core.matches("borg_core/mod/sub/a.py", ["borg_core/mod/*.py"])
    assert core.matches("borg_core/a/b/shared.py", ["borg_core/**/shared.py"])
    assert core.matches("skills/x/SKILL.md", ["skills/x/**"])
    assert not core.matches("skills/xy/SKILL.md", ["skills/x/**"])
    assert not core.matches("skills/x", ["skills/x/**"])
    assert core.matches("a/b.c", ["a/b.?"]) and not core.matches("a/bcc", ["a/b?"])
    assert not core.matches("a/bxc", ["a/b.c"])


def test_clean_ledger_has_no_problems() -> None:
    assert problems() == []


def test_unlisted_item_is_named() -> None:
    out = problems(disk=[*DISK, "skills/zz-test"])
    assert any(line.startswith("skills/zz-test:") and "not in the ledger" in line for line in out)


def test_row_for_a_deleted_item_fails() -> None:
    assert any("skills/y" in line and "does not exist" in line for line in problems(disk=["skills/x"]))


def test_missing_eval_path_is_named() -> None:
    out = problems(exist={"evals/b"})
    assert any(line.startswith("evals/a:") and "missing" in line for line in out)


def test_item_pointing_at_unknown_eval_fails() -> None:
    bad = {**LEDGER, "items": {**LEDGER["items"], "skills/x": {"eval": "evals/nope"}}}
    assert any("no row in `evals`" in line for line in problems(bad))


def test_expired_waiver_fails_and_boundary_day_passes() -> None:
    assert any("expired" in line for line in problems(today="2026-12-02"))
    assert problems(today="2026-12-01") == []


def test_waiver_needs_reason_date_and_exactly_one_form() -> None:
    def with_row(row):
        return {**LEDGER, "items": {**LEDGER["items"], "skills/y": row}}

    assert any("no reason" in line for line in problems(with_row({"waiver": " ", "review_by": "2026-12-01"})))
    assert any("review_by" in line for line in problems(with_row({"waiver": "x"})))
    assert any("review_by" in line for line in problems(with_row({"waiver": "x", "review_by": "soon"})))
    assert any("exactly one" in line for line in problems(with_row({"eval": "evals/a", "waiver": "x"})))
    assert any("exactly one" in line for line in problems(with_row({})))
    assert any("must be an object" in line for line in problems(with_row("evals/a")))


def test_eval_row_needs_covers_and_version() -> None:
    bad = {"version": 2, "evals": {"evals/a": {"covers": []}, "evals/b": "x"}, "items": {}}
    out = problems(bad, disk=[])
    assert sum("covers" in line for line in out) == 2
    assert any("version" in line for line in out)


def test_select_picks_only_covering_evals() -> None:
    got = core.select(LEDGER, ["skills/x/SKILL.md"])
    assert got.evals == ["evals/a"] and not got.select_all
    assert core.select(LEDGER, ["borg_core/q/shared.py"]).evals == ["evals/b"]
    assert core.select(LEDGER, ["skills/x/SKILL.md", "borg_core/q/shared.py"]).evals == ["evals/a", "evals/b"]


def test_select_nothing_says_so() -> None:
    got = core.select(LEDGER, ["README.md", "skills/y/SKILL.md"])
    assert got.evals == [] and not got.select_all and "nothing to run" in got.reason
    assert core.select(LEDGER, []).evals == []


def test_shared_machinery_selects_all() -> None:
    for path in ("evals/ledger.json", "Makefile", "borg_core/evals/core.py", "evals/common.sh"):
        got = core.select(LEDGER, ["README.md", path])
        assert got.select_all and got.evals == ["evals/a", "evals/b"], path


def test_a_per_eval_file_is_not_shared_machinery() -> None:
    assert not core.select(LEDGER, ["evals/a/run.sh"]).select_all
