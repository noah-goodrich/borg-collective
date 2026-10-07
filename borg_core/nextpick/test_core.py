"""Oracles for the pure nextpick core. Expected orders are derived BY HAND from cmd_next's jq."""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.nextpick import core

W = "w"


def _fixture():
    return {
        "a-wait-new": {"status": "waiting", "tmux_window": W, "last_activity": "2026-10-04"},
        "b-wait-old": {"status": "waiting", "tmux_window": W, "last_activity": "2026-09-01"},
        "c-wait-nowin": {"status": "waiting", "tmux_window": "", "last_activity": "2026-10-04"},
        "d-act": {"status": "active", "tmux_window": W, "last_activity": "2026-10-05"},
        "e-idle": {"status": "idle", "tmux_window": W, "last_activity": "2026-10-05"},
        "f-idle": {"status": "idle", "tmux_window": W, "last_activity": "2026-10-05"},
        "g-never": {"status": "idle"},
        "h-weird": {"status": "weird", "last_activity": "2026-10-05"},
        "i-pin-idle": {"status": "idle", "pinned": True, "tmux_window": W, "last_activity": "2026-08-01"},
        "j-pin-null": {"status": "idle", "pinned": True},
        "k-empty-act": {"status": "idle", "last_activity": ""},
        "l-empty-win": {"status": "idle", "tmux_window": W, "last_activity": ""},
        "m-null-win": {"status": "idle", "tmux_window": W, "last_activity": None},
        "z-arch": {"status": "archived", "pinned": True, "tmux_window": W, "last_activity": "2026-10-05"},
    }


def test_rank_order_and_scores_match_the_jq_by_hand():
    ranked = core.rank(_fixture())
    got = [(i["name"], i["score"]) for i in ranked]
    assert got == [
        ("i-pin-idle", 215),  # 200 + 10 + 5
        ("j-pin-null", 160),  # 200 + 10 - 50
        ("b-wait-old", 105),  # tie at 105: older last_activity first
        ("a-wait-new", 105),
        ("c-wait-nowin", 100),  # empty window earns no +5
        ("d-act", 55),
        ("l-empty-win", 15),  # tie at 15: "" sorts first, then name order e, f
        ("e-idle", 15),
        ("f-idle", 15),
        ("k-empty-act", 10),  # "" is NOT null: no -50
        ("h-weird", 0),  # unknown status scores 0
        ("m-null-win", -35),  # 10 + 5 - 50
        ("g-never", -40),  # 10 - 50
    ]


def test_archived_is_excluded_even_when_pinned():
    assert "z-arch" not in [i["name"] for i in core.rank(_fixture())]


def test_equal_score_and_activity_fall_back_to_name_order_regardless_of_insertion():
    projects = {"zz": {"status": "idle", "last_activity": "x"}, "aa": {"status": "idle", "last_activity": "x"}}
    assert [i["name"] for i in core.rank(projects)] == ["aa", "zz"]


def test_items_carry_the_fields_cmd_next_reads_with_jq_defaults():
    item = core.rank({"p": {"status": "idle"}})[0]
    assert item == {
        "name": "p",
        "score": -40,
        "status": "idle",
        "summary": "",
        "waiting_reason": "",
        "last_activity": "",
        "pinned": False,
        "path": "null",
    }


def test_rank_empty_registry():
    assert core.rank({}) == []


def _ranked():
    return core.rank(_fixture())


def _row(**over):
    base = {
        "ts": "t",
        "session": "s",
        "ranked": _ranked(),
        "rec": "i-pin-idle",
        "opened": "i-pin-idle",
        "opened_after_s": 3.0,
        "active": "d-act",
        "switch": False,
        "chooser": True,
        "scripted": False,
    }
    base.update(over)
    return core.log_row(**base)


def test_log_row_shape_and_top3():
    row = _row(shown=True)
    assert set(row) == {
        "ts",
        "session",
        "shown",
        "top3",
        "rec",
        "opened",
        "opened_after_s",
        "active",
        "switch",
        "chooser",
        "scripted",
    }
    assert row["shown"] is True
    assert row["top3"] == [
        {"project": "i-pin-idle", "rank": 1, "score": 215, "status": "idle"},
        {"project": "j-pin-null", "rank": 2, "score": 160, "status": "idle"},
        {"project": "b-wait-old", "rank": 3, "score": 105, "status": "waiting"},
    ]


def test_log_row_non_chooser_blanks_shown_rec_opened():
    row = _row(chooser=False, shown=True)
    assert (row["shown"], row["rec"], row["opened"], row["opened_after_s"]) == (False, None, None, None)
    assert row["active"] == "d-act" and row["top3"]


def test_log_row_short_ranking():
    assert _row(ranked=[])["top3"] == []


def _rows(n, followed, **over):
    rows = []
    for i in range(n):
        opened = "a" if i < followed else "b"
        row = {"chooser": True, "scripted": False, "rec": "a", "opened": opened}
        row.update(over)
        rows.append(row)
    return rows


def test_gate_needs_min_rows():
    assert core.gate(_rows(19, 19)) is False


def test_gate_below_threshold():
    assert core.gate(_rows(20, 11)) is False


def test_gate_at_threshold():
    assert core.gate(_rows(20, 12)) is True


def test_gate_ignores_scripted_rows():
    assert core.gate(_rows(20, 20, scripted=True)) is False


def test_gate_ignores_non_chooser_rows():
    assert core.gate(_rows(20, 20, chooser=False)) is False


def test_gate_counts_only_eligible_rows_toward_minimum():
    assert core.gate(_rows(19, 19) + _rows(5, 5, scripted=True)) is False
    assert core.gate(_rows(20, 20) + _rows(50, 0, scripted=True)) is True


def test_core_imports_nothing_impure():
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = set()
    pure_link = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
            if node.module == "borg_core.link":
                pure_link.update(a.name for a in node.names)
    assert roots == {"__future__", "typing", "borg_core"}, f"core.py grew an impure import: {sorted(roots)}"
    assert pure_link == {"grid", "picture", "render"}, f"only borg_core.link's pure Domain modules: {pure_link}"


BLANK = {"item": "", "next_step": "", "owner": "", "ready": ""}


def _doc():
    nodes = {
        "o/r#1": {"ref": "o/r#1", "state": "open", "ready": True},
        "o/r#2": {"ref": "o/r#2", "state": "open", "ready": True},
    }
    gates = [
        {"ref": "o/r#1", "kind": "decision", "blocked_by": "answer triage Qs"},
        {"ref": "o/r#2", "kind": "review", "blocked_by": "wat"},
    ]
    manifest = {
        "path": "/d/borg/.borg/chains/x.json",
        "nodes": nodes,
        "gates": gates,
        "ready": {"state": "known", "refs": ["o/r#1", "o/r#2"]},
    }
    unlooked = {
        "path": "/d/ingle/.borg/chains/y.json",
        "nodes": {},
        "gates": [],
        "ready": {"state": "unlooked", "refs": []},
    }
    return {"grid": {"manifests": [manifest, unlooked]}}


def _ranked_paths():
    return [
        {"name": "borg", "path": "/d/borg"},
        {"name": "ingle", "path": "/d/ingle"},
        {"name": "bare", "path": "null"},
    ]


def test_chooser_rows_route_with_the_pages_own_router():
    rows = core.chooser_rows(_ranked_paths(), _doc())
    assert rows[0] == {
        "n": 1,
        "project": "borg",
        "item": "o/r#1",
        "next_step": "answer triage Qs",
        "owner": "yours",
        "ready": "●",
    }
    assert [r["n"] for r in rows] == [1, 2, 3]


def test_chooser_rows_unrecognized_gate_kind_is_unsure():
    doc = _doc()
    doc["grid"]["manifests"][0]["ready"]["refs"] = ["o/r#2"]
    assert core.chooser_rows(_ranked_paths(), doc)[0]["owner"] == "unsure"


def test_chooser_rows_ungated_ready_row_is_mine():
    doc = _doc()
    doc["grid"]["manifests"][0]["gates"] = []
    assert core.chooser_rows(_ranked_paths(), doc)[0]["owner"] == "mine"


def test_chooser_rows_blank_without_manifest_or_when_unlooked():
    rows = core.chooser_rows(_ranked_paths(), _doc())
    assert {k: rows[1][k] for k in BLANK} == BLANK
    assert {k: rows[2][k] for k in BLANK} == BLANK


def test_chooser_rows_blank_for_missing_document():
    for doc in (None, {}):
        rows = core.chooser_rows(_ranked_paths(), doc)
        assert [r["project"] for r in rows] == ["borg", "ingle", "bare"]
        assert all({k: r[k] for k in BLANK} == BLANK for r in rows)


def _three():
    return [
        {"n": 1, "project": "borg", "item": "hygiene", "next_step": "/borg-assimilate", "owner": "yours", "ready": "●"},
        {"n": 2, "project": "borg", "item": "research", "next_step": "merge #252", "owner": "mine", "ready": "●"},
        {"n": 3, "project": "ingle", "item": "", "next_step": "", "owner": "", "ready": ""},
    ]


GOLDEN_HEAD = [
    "WHERE COULD YOUR FOCUS GO?",
    "───────────────────────────────────────────────────────────",
    " # project · item           next step           owner ready",
    " 1 borg · hygiene           /borg-assimilate    yours ●",
    " 2 borg · research          merge #252          mine  ●",
    " 3 ingle",
    "───────────────────────────────────────────────────────────",
]


def test_render_chooser_golden_without_suggestion():
    assert core.render_chooser(_three(), suggestion=None) == GOLDEN_HEAD + ["⏎ top · 1-9 open · q quit"]


def test_render_chooser_golden_with_suggestion():
    got = core.render_chooser(_three(), suggestion="1 borg")
    assert got == GOLDEN_HEAD + ["▸ suggested: 1 borg", "⏎ top · 1-9 open · q quit"]


def test_render_chooser_truncates_long_cells_to_width():
    row = {"n": 1, "project": "p" * 80, "item": "i", "next_step": "s" * 40, "owner": "unsure", "ready": "○"}
    lines = core.render_chooser([row], suggestion="1 " + "p" * 80)
    assert all(len(line) <= 59 for line in lines)
    assert "…" in lines[3]
    assert lines[3].endswith("○")


def test_suggestion_for_both_branches():
    assert core.suggestion_for(_three(), _rows(20, 20)) == "1 borg"
    assert core.suggestion_for(_three(), _rows(19, 19)) is None
    assert core.suggestion_for([], _rows(20, 20)) is None
