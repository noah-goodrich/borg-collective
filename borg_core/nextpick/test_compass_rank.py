"""`borg next`'s ranking with the compass: leg first, nearest due date, undated, then frozen/done/unmapped.

The compass block is BUILT BY THE READER (`compass.core.build_compass`) from synthetic map text, never typed as a
dict, so the shape under test is the shape the wire carries. No real map is read (conftest points BORG_MAP_DIR at a
directory that does not exist; the cases that read a directory write their own under tmp_path).
"""

from __future__ import annotations

import io
import json
from pathlib import Path

import pytest

from borg_core.compass import core as compass_core
from borg_core.nextpick import cli, core

TODAY = "2026-03-10"
README = (
    "| Destination | Due |\n|---|---|\n"
    "| alpha | 2026-04-30 |\n| beta | 2026-03-01 |\n| gamma | 2026-03-20 |\n| delta | TBD |\n| eps | TBD |\n"
)
LOG = "## Today's leg\n\n- Push alpha forward\n"


def _destination(ident: str, status: str, repository: str) -> tuple[str, str]:
    return f"destinations/{ident}.md", f"---\nid: {ident}\nstatus: {status}\nrepositories:\n  - {repository}\n---\n"


DESTINATIONS = [
    _destination("alpha", "active", "on-leg"),
    _destination("beta", "active", "late"),
    _destination("gamma", "active", "soon"),
    _destination("delta", "active", "undated"),
    _destination("eps", "frozen", "frozen"),
]


def _entry(status: str = "idle", activity: str = "2026-03-05", **extra) -> dict:
    return {"status": status, "last_activity": activity, "tmux_window": "w", **extra}


def _repositories() -> dict:
    # Scored to go the OTHER way from the compass: the pinned, waiting ones would lead on score alone.
    return {
        "unmapped": _entry("waiting", pinned=True),
        "frozen": _entry("waiting"),
        "undated": _entry("active"),
        "soon": _entry("waiting"),
        "late": _entry("idle"),
        "on-leg": _entry("idle", "2026-01-01"),
        "retired": {"status": "archived", "last_activity": "2026-03-05"},
    }


def _compass(log: str | None = LOG, repositories: dict | None = None) -> dict:
    names = list(_repositories() if repositories is None else repositories)
    return compass_core.build_compass("/maps/synthetic", TODAY, log, DESTINATIONS, README, None, names)


def _names(ranked: list[dict]) -> list[str]:
    return [item["name"] for item in ranked]


def test_the_compass_orders_leg_then_nearest_due_then_undated_then_the_rest():
    ranked = core.rank(_repositories(), _compass())
    assert _names(ranked) == ["on-leg", "late", "soon", "undated", "unmapped", "frozen"]


def test_inside_a_bucket_the_existing_score_and_activity_tie_breaks_decide():
    # `unmapped` (pinned, waiting) beats `frozen` (waiting) on score; both sit in the last bucket.
    last = _names(core.rank(_repositories(), _compass()))[-2:]
    assert last == ["unmapped", "frozen"]
    two_on_leg = {"a-leg": _entry("idle"), "b-leg": _entry("waiting")}
    block = compass_core.build_compass(
        "/m", TODAY, "## Today's leg\n\n- a-leg and b-leg\n", [], None, None, list(two_on_leg)
    )
    assert _names(core.rank(two_on_leg, block)) == ["b-leg", "a-leg"]


def test_a_late_destination_comes_before_one_due_later():
    ranked = _names(core.rank(_repositories(), _compass(log=None)))
    assert ranked.index("late") < ranked.index("soon") < ranked.index("undated")


def test_with_no_leg_nothing_is_on_it_and_the_due_dates_lead():
    assert _names(core.rank(_repositories(), _compass(log=None)))[:4] == ["late", "soon", "on-leg", "undated"]


def test_a_pinned_repository_off_the_leg_no_longer_outranks_one_on_it():
    assert _names(core.rank(_repositories(), _compass()))[0] == "on-leg"
    assert _names(core.rank(_repositories()))[0] == "unmapped"


@pytest.mark.parametrize("block", [None, compass_core.absent("/maps/none")])
def test_with_no_map_the_order_is_exactly_what_it_was(block):
    assert core.rank(_repositories(), block) == core.rank(_repositories())
    # By hand: 305 (pinned waiting), 105 twice (name order), 55, then 15 twice (older activity first).
    assert _names(core.rank(_repositories(), block)) == ["unmapped", "frozen", "soon", "undated", "on-leg", "late"]


def test_archived_stays_excluded_with_a_map():
    assert "retired" not in _names(core.rank(_repositories(), _compass()))


def test_log_rows_carry_the_compass_order():
    repositories = _repositories()
    args = cli._parser().parse_known_args(["--pick", "1"])[0]  # pylint: disable=protected-access
    row = cli.build_row(args, repositories, cli.datetime.now(cli.UTC), _compass())
    assert (row["rec"], row["opened"]) == ("on-leg", "on-leg")


def _with_worktree() -> dict:
    """`_repositories()` plus a worktree of `on-leg`, tied to it only by the registry's `repo` key."""
    common = "/code/on-leg/.git"
    repositories = _repositories()
    repositories["on-leg"]["repo"] = common
    repositories["on-leg-wt"] = _entry("idle", "2026-01-01", repo=common)
    return repositories


def test_a_worktree_ranks_with_its_repository_not_as_unmapped(monkeypatch, tmp_path):
    repositories = _with_worktree()
    unaware = compass_core.build_compass("/m", TODAY, LOG, DESTINATIONS, README, None, list(repositories))
    assert _names(core.rank(repositories, unaware))[-1] == "on-leg-wt"
    monkeypatch.setenv("BORG_MAP_DIR", str(_write_map(tmp_path / "map")))
    monkeypatch.setattr(cli.compass_shell, "today_from_epoch", lambda _moment: TODAY)
    ranked = _names(core.rank(repositories, cli.read_compass(repositories)))
    assert ranked[:2] == ["on-leg", "on-leg-wt"]
    assert ranked[2:] == ["late", "soon", "undated", "unmapped", "frozen"]


def test_a_worktree_inherits_its_repositorys_destination_and_leg_flag_once_in_the_block():
    repositories = _with_worktree()
    block = compass_core.build_compass(
        "/m", TODAY, LOG, DESTINATIONS, README, None, list(repositories), parents={"on-leg-wt": "on-leg"}
    )
    expected = {"destination": "alpha", "on_leg": True}
    assert block["repositories"]["on-leg"] == expected
    assert block["repositories"]["on-leg-wt"] == expected


# -- the non-interactive choice: `--top` --------------------------------------------------------------------------


def _write_map(root: Path) -> Path:
    for relative, text in [("log/" + TODAY + ".md", LOG), ("README.md", README), *DESTINATIONS]:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    return root


def _top(monkeypatch, capsys, index: str, stdin: str | None = None) -> tuple[int, str]:
    payload = json.dumps({"projects": _repositories()}) if stdin is None else stdin
    monkeypatch.setattr("sys.stdin", io.StringIO(payload))
    code = cli.main(["--top", index])
    return code, capsys.readouterr().out


def test_top_without_a_map_answers_in_the_score_order(monkeypatch, capsys):
    code, out = _top(monkeypatch, capsys, "0")
    assert (code, json.loads(out)["name"]) == (0, "unmapped")


def test_top_answers_in_the_compass_order_from_the_environment(monkeypatch, capsys, tmp_path):
    map_dir = _write_map(tmp_path / "map")
    monkeypatch.setenv("BORG_MAP_DIR", str(map_dir))
    monkeypatch.setattr(cli.compass_shell, "today_from_epoch", lambda _moment: TODAY)
    answers = [json.loads(_top(monkeypatch, capsys, str(n))[1])["name"] for n in range(3)]
    assert answers == ["on-leg", "late", "soon"]


def test_top_out_of_range_prints_nothing_and_succeeds(monkeypatch, capsys):
    assert _top(monkeypatch, capsys, "99") == (0, "")


def test_top_fails_loudly_when_it_cannot_read_the_registry(monkeypatch, capsys):
    assert _top(monkeypatch, capsys, "0", stdin="not json") == (1, "")


def test_top_entry_carries_the_fields_cmd_next_reads(monkeypatch, capsys):
    _, out = _top(monkeypatch, capsys, "0")
    assert {"name", "status", "summary", "waiting_reason", "last_activity", "pinned", "path"} <= set(json.loads(out))


def test_an_unreadable_map_degrades_to_no_map(monkeypatch):
    def boom(*_args, **_kwargs):
        raise OSError("home is gone")

    monkeypatch.setattr(cli.compass_shell, "read_compass", boom)
    assert cli.read_compass({"a": {}}) is None
