"""Unit tests for borg_core.link.render -- the three pure human renderers.

These pin the sub-behaviours a byte-exact golden diff cannot localize: which branch fired, which
default applied, where a fold broke. The four goldens under tests/fixtures/link/ remain the primary
oracle (exercised end to end via tests/cli_contract.bats); these are the microscope.
"""

import datetime
import shutil
import subprocess
import time

import pytest

from borg_core.link import render


def _doc(**overrides) -> dict:
    base = {
        "total_projects": 0,
        "order": [],
        "projects": {},
        "directives": [],
        "assimilated": [],
        "cortex_pending": [],
        "capacity": {"active": 0, "limit": 3, "over_limit": False},
        "focus": None,
    }
    base.update(overrides)
    return base


def test_overview_empty_registry_vs_all_archived_are_different_sentences():
    empty = render.overview(_doc(total_projects=0))
    assert "No projects registered. Run: borg scan" in empty

    all_archived = render.overview(_doc(total_projects=2, order=[], projects={}))
    assert "No projects to show. Run: borg link --all" in all_archived
    assert "No projects registered" not in all_archived


def test_overview_discovery_tip_gated_on_total_projects_not_len_order():
    # One visible + one archived: total_projects is 2 (unfiltered), so the tip must NOT appear even
    # though len(order) == 1.
    doc = _doc(
        total_projects=2,
        order=["solo"],
        projects={"solo": {"source": "cli", "status": "idle", "relative_activity": "never"}},
    )
    out = render.overview(doc)
    assert "Tip: run 'borg scan'" not in out
    assert "solo" in out


def test_overview_lone_archived_prints_both_tip_and_all_filtered_sentence():
    doc = _doc(total_projects=1, order=[], projects={})
    out = render.overview(doc)
    assert "Tip: run 'borg scan'" in out
    assert "No projects to show. Run: borg link --all" in out


def test_porcelain_empty_returns_exactly_empty_string():
    assert render.porcelain(_doc()) == ""


def test_porcelain_cuts_at_80_with_no_ellipsis():
    long_summary = "x" * 90
    doc = _doc(
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "last_activity": "", "summary": long_summary}},
    )
    row = render.porcelain(doc)
    field = row.split("\t")[4].rstrip("\n")
    assert field == "x" * 80
    assert "..." not in field


@pytest.mark.parametrize("length,expect_ellipsis", [(49, False), (50, False), (51, True)])
def test_overview_summary_truncation_boundary_and_ellipsis(length, expect_ellipsis):
    summary = "x" * length
    doc = _doc(
        total_projects=1,
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "relative_activity": "never", "summary": summary}},
    )
    out = render.overview(doc)
    if expect_ellipsis:
        assert "x" * 50 + "..." in out
    else:
        assert summary in out
        assert "x" * length + "..." not in out


def test_deep_path_line_omitted_entirely_when_path_is_the_string_null():
    doc = _doc(
        focus={
            "name": "p",
            "entry": {"path": "null"},
            "plan": None,
            "checkpoints": [],
            "checkpoint_head": "",
            "directives": [],
            "assimilated": [],
        }
    )
    out = render.deep(doc)
    assert "Path:" not in out


def test_deep_status_line_appears_exactly_once_and_ends_in_the_status_word():
    doc = _doc(
        focus={
            "name": "p",
            "entry": {"path": "null", "status": "active"},
            "plan": None,
            "checkpoints": [],
            "checkpoint_head": "",
            "directives": [],
            "assimilated": [],
        }
    )
    out = render.deep(doc)
    status_lines = [line for line in out.split("\n") if "Status:" in line]
    assert len(status_lines) == 1
    assert status_lines[0].endswith("active")


def test_deep_objective_omitted_with_no_placeholder_when_empty():
    doc = _doc(
        focus={
            "name": "p",
            "entry": {"path": "null"},
            "plan": {"objective": "", "met": 0, "total": 2},
            "checkpoints": [],
            "checkpoint_head": "",
            "directives": [],
            "assimilated": [],
        }
    )
    out = render.deep(doc)
    assert "Objective:" not in out
    assert "0/2 criteria met" in out


def test_checkpoint_head_indents_blank_lines_to_two_spaces():
    head = "# Checkpoint\n\nBody.\n"[:-1]  # mirrors shell.read_latest_checkpoint_head's join
    out = render._checkpoint_head_block(head)  # pylint: disable=protected-access
    lines = out.split("\n")
    assert lines[1] == "  "


def test_checkpoint_head_no_spurious_trailing_blank_for_a_short_checkpoint():
    text = "# Checkpoint one\n\nBody one.\n"
    head = "\n".join(text.split("\n")[:20])
    out = render._checkpoint_head_block(head)  # pylint: disable=protected-access
    assert out.count("\n") == 3


class TestFoldS:
    def test_no_break_needed(self):
        assert render._fold_s("short", width=70) == ["short"]  # pylint: disable=protected-access

    def test_breaks_after_last_space_at_or_before_width(self):
        text = "a" * 68 + " " + "b" * 10
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 68 + " "
        assert lines[1] == "b" * 10
        assert not lines[1].startswith(" ")

    def test_hard_break_when_no_space_in_window(self):
        text = "a" * 140
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 70
        assert lines[1] == "a" * 70

    def test_exactly_width_does_not_break(self):
        text = "a" * 70
        assert render._fold_s(text, width=70) == [text]  # pylint: disable=protected-access

    def test_width_plus_one_breaks(self):
        text = "a" * 71
        lines = render._fold_s(text, width=70)  # pylint: disable=protected-access
        assert lines[0] == "a" * 70
        assert lines[1] == "a"

    @pytest.mark.skipif(shutil.which("fold") is None, reason="no `fold` binary on this host")
    @pytest.mark.parametrize(
        "text,width",
        [
            ("short", 70),
            ("a" * 68 + " " + "b" * 10, 70),
            ("a" * 140, 70),
            ("a" * 70, 70),
            ("a" * 71, 70),
            ("aa bbb cc", 6),
            ("   abc def ghi", 5),
            ("abc def " * 5, 6),
            ("a b c d e f g h i j k l m n o p", 3),
            ("", 70),
            ("     ", 4),
            ("word " * 20, 20),
        ],
    )
    def test_matches_real_fold_s_binary(self, text, width):
        """Differential, not hardcoded: shells out to whatever `fold -s` this host actually has
        (BSD on macOS CI, GNU in a devcontainer) so the assertion is correct by construction on
        every platform instead of pinning one vendor's output. This is the test that would have
        caught the original `_fold_s` divergence -- see the PR body for the RED-before-fix run."""
        proc = subprocess.run(
            ["fold", "-s", "-w", str(width)],
            input=text,
            capture_output=True,
            text=True,
            check=True,
        )
        # `fold` never appends a newline that wasn't already on the (newline-free) input, so its
        # stdout is directly comparable to `"\n".join(lines)` with no trailing-newline massaging.
        got = render._fold_s(text, width=width)  # pylint: disable=protected-access
        assert "\n".join(got) == proc.stdout


def test_overview_directives_assimilated_capacity_and_cortex_row_all_render():
    doc = _doc(
        total_projects=2,
        order=["a", "b"],
        projects={
            "a": {"source": "desktop", "status": "active", "relative_activity": "2h ago", "summary": "s"},
            "b": {"source": "coco", "status": "waiting", "relative_activity": "1h ago", "summary": "s"},
        },
        directives=[{"project": "a", "title": "Directive one"}],
        assimilated=[{"project": "a", "title": "Shipped one", "ship_date": "2026-01-01"}],
        cortex_pending=[{"project": "a", "reset_at": "x", "countdown": "1h 0m"}],
        capacity={"active": 5, "limit": 3, "over_limit": True},
    )
    out = render.overview(doc)
    assert "[D]" in out
    assert "[X]" in out
    assert "waiting <<<" in out
    assert "Directive one" in out
    assert "Shipped one" in out
    assert "resumes in 1h 0m" in out
    assert "sessions need attention" in out


def test_deep_dive_renders_checkpoints_directives_and_assimilated():
    doc = _doc(
        focus={
            "name": "p",
            "entry": {"path": "null", "status": "idle"},
            "plan": None,
            "checkpoints": ["2026-08-01.md"],
            "checkpoint_head": "line one\nline two",
            "directives": [{"slug": "s", "title": "Deep directive"}],
            "assimilated": [{"slug": "s", "title": "Deep shipped", "ship_date": "2026-01-01"}],
        }
    )
    out = render.deep(doc)
    assert "2026-08-01.md" in out
    assert "Deep directive" in out
    assert "Deep shipped (2026-01-01)" in out
    assert "line one" in out


def test_render_reads_no_clock(monkeypatch):
    # render.py's stated purity contract: every relative_activity/countdown/generated_at is already
    # baked into the document by ONE shell.now_epoch() call in cli._document. A second clock read
    # here would reintroduce the straddle the port removed.
    def _boom(*_args, **_kwargs):
        raise AssertionError("render.py must not read the clock")

    monkeypatch.setattr(time, "time", _boom)
    monkeypatch.setattr(datetime, "datetime", type("Boom", (), {"now": _boom}))

    doc = _doc(
        total_projects=1,
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "relative_activity": "2h ago", "summary": "s"}},
        focus={
            "name": "a",
            "entry": {"path": "null", "status": "idle"},
            "plan": None,
            "checkpoints": [],
            "checkpoint_head": "",
            "directives": [],
            "assimilated": [],
        },
    )
    render.porcelain(doc)
    render.overview(doc)
    render.deep(doc)


def test_overview_assimilated_omits_parens_when_ship_date_empty():
    # Regression for the zsh-port bug: a missing "Shipped:" line produced ship_date="", and the
    # old f"({item['ship_date']})" rendered a bare, empty "()" after the title. A title that
    # itself ends in a parenthetical (e.g. "(C6)") must survive untouched -- only the DATE's own
    # parens are conditional, never a suffix stripped from the title.
    doc = _doc(
        total_projects=1,
        order=["a"],
        projects={"a": {"source": "cli", "status": "idle", "relative_activity": "2h ago", "summary": "s"}},
        assimilated=[
            {"project": "ingle", "title": "T-4 mutation gate", "ship_date": ""},
            {"project": "borg-collective", "title": "recon migration ledger (C6)", "ship_date": "2026-08-12"},
        ],
    )
    out = render.overview(doc)
    assert "[ingle] T-4 mutation gate\x1b[0m\n" in out
    assert "()" not in out
    assert "[borg-collective] recon migration ledger (C6) (2026-08-12)" in out


def test_deep_dive_assimilated_omits_parens_when_ship_date_empty():
    doc = _doc(
        focus={
            "name": "p",
            "entry": {"path": "null", "status": "idle"},
            "plan": None,
            "checkpoints": [],
            "checkpoint_head": "",
            "directives": [],
            "assimilated": [{"slug": "s", "title": "Deep shipped (C6)", "ship_date": ""}],
        }
    )
    out = render.deep(doc)
    assert "Deep shipped (C6)\x1b[0m\n" in out
    assert "()" not in out
