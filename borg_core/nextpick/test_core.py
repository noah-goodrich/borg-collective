"""Oracles for the pure nextpick core. Expected orders are derived BY HAND from cmd_next's jq."""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.link import core as link_core
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
    assert roots == {"__future__", "re", "typing", "borg_core"}, f"core.py grew an impure import: {sorted(roots)}"
    assert pure_link == {"core", "grid", "picture", "render"}, f"only borg_core.link's pure Domain modules: {pure_link}"


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
        "status": "",
        "age": "never",
        "waiting_reason": "",
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
    " # project · item         next step          owner ready",
    " 1 borg · hygiene         /borg-assimilate   yours ●",
    " 2 borg · research        merge #252         mine  ●",
    " 3 ingle",
    "───────────────────────────────────────────────────────────",
]


def test_render_chooser_golden_without_suggestion():
    assert core.render_chooser(_three(), suggestion=None) == GOLDEN_HEAD + ["⏎ top · 1-9 open · q quit"]


def test_render_chooser_golden_with_suggestion():
    got = core.render_chooser(_three(), suggestion="1 borg")
    assert got == GOLDEN_HEAD + ["▸ suggested: 1 borg", "⏎ top · 1-9 open · q quit"]


def test_render_chooser_collapses_quiet_projects_into_one_trailing_line():
    got = core.render_chooser(_three(), suggestion=None, quiet=["x", "y"])
    assert got[6] == "+2 quiet: x, y"
    assert got[7] == GOLDEN_HEAD[-1]
    long = core.render_chooser(_three(), suggestion=None, quiet=["q" * 30, "r" * 30])
    assert len(long[6]) == 59 and long[6].endswith("…")


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


def test_chooser_rows_carry_status_age_and_waiting_reason():
    ranked = [
        {
            "name": "w",
            "path": "null",
            "status": "waiting",
            "waiting_reason": "needs OK",
            "last_activity": "2026-10-05T09:00:00Z",
        }
    ]
    now = link_core.iso_to_epoch("2026-10-05T12:00:00Z")
    (row,) = core.chooser_rows(ranked, None, None, now)
    assert (row["status"], row["age"], row["waiting_reason"]) == ("waiting", "3h ago", "needs OK")


def test_chooser_rows_fall_back_to_checkpoint_but_prefer_the_manifest():
    rows = core.chooser_rows(_ranked_paths(), _doc(), {"borg": "cp", "ingle": "cp step"})
    assert rows[0]["next_step"] == "answer triage Qs"
    assert rows[1]["next_step"] == "cp step"


def _qrow(n, project, status, step="", reason=""):
    return {"n": n, "project": project, "status": status, "next_step": step, "waiting_reason": reason}


def test_split_quiet_partitions_idle_blank_rows_in_rank_order():
    rows = [
        _qrow(1, "a", "waiting", reason="why"),
        _qrow(2, "b", "idle"),
        _qrow(3, "c", "idle", step="do"),
        _qrow(4, "d", "active"),
        _qrow(5, "e", "idle"),
    ]
    kept, quiet = core.split_quiet(rows)
    assert [r["project"] for r in kept] == ["a", "c", "d"]
    assert [r["n"] for r in kept] == [1, 2, 3]
    assert quiet == ["b", "e"]


def test_checkpoint_next_step_numbered_list():
    text = "## 5. Next Session\n\n1. First  thing\n   wrapped\n2. Second\n"
    assert core.checkpoint_next_step(text) == "First thing wrapped"


def test_checkpoint_next_step_bullets_and_prose():
    assert core.checkpoint_next_step("## 5. Next Session\n\n- [ ] do it\n- more\n") == "[ ] do it"
    prose = "## 5. Next Session\nJust prose\nstill prose\n\nnext para\n"
    assert core.checkpoint_next_step(prose) == "Just prose still prose"


def test_checkpoint_next_step_missing_section_or_empty():
    assert core.checkpoint_next_step("## 1. Goal\n\nx\n") == ""
    assert core.checkpoint_next_step("") == ""
    assert core.checkpoint_next_step("## 5. Next Session\n\n## Manifest Row\nx\n") == ""


def test_checkpoint_next_step_ignores_tldr_preamble_and_truncates():
    text = "tl;dr: 5. Next Session is later\n\n## 1. Goal\n\nx\n\n## 5. Next Session\n\n1. " + "w" * 120 + "\n"
    step = core.checkpoint_next_step(text)
    assert len(step) == 80 and step.endswith("…") and step.startswith("w")


def _pr(num, title="feat(next): add the thing", **kw):
    base = {"ref": f"o/r#{num}", "title": title, "state": "open", "draft": False, "checks": "pass",
            "mergeable": "MERGEABLE", "review_decision": None, "owner": "you"}
    return {**base, **kw}


def _rank(name, status="idle", reason=""):
    return {"name": name, "status": status, "waiting_reason": reason, "last_activity": ""}


def _one(pr):
    rows, quiet = core.work_items([_rank("p")], {"p": [pr]}, {}, {})
    assert quiet == []
    assert len(rows) == 1
    return rows[0]


def test_work_items_pr_rule_precedence():
    assert _one(_pr(1, draft=True, checks="fail", mergeable="CONFLICTING"))["next_step"] == "finish #1"
    row = _one(_pr(2, mergeable="CONFLICTING", checks="fail"))
    assert (row["next_step"], row["owner"], row["ready"]) == ("resolve conflicts #2", "AGENT", "✗")
    row = _one(_pr(3, checks="fail", review_decision="CHANGES_REQUESTED"))
    assert (row["next_step"], row["owner"], row["ready"]) == ("fix #3 CI", "AGENT", "✗")
    row = _one(_pr(4, checks="pending", review_decision="CHANGES_REQUESTED"))
    assert (row["next_step"], row["owner"], row["ready"]) == ("#4 CI", "AGENT", "… run")
    row = _one(_pr(5, review_decision="CHANGES_REQUESTED"))
    assert (row["next_step"], row["owner"], row["ready"]) == ("address review #5", "AGENT", "○")
    for extra in ({"checks": "none"}, {"mergeable": "UNKNOWN"}, {}):
        row = _one(_pr(6, **extra))
        assert (row["next_step"], row["owner"], row["ready"], row["ref"]) == ("merge #6", "YOU", "✔ now", "o/r#6")
    row = _one(_pr(3, draft=True))
    assert (row["owner"], row["ready"]) == ("AGENT", "◌")


def test_work_items_ignores_closed_prs_and_author():
    rows, quiet = core.work_items([_rank("p")], {"p": [_pr(1, state="merged")]}, {}, {})
    assert rows == [] and quiet == ["p"]
    assert _one(_pr(7, owner="unknown"))["owner"] == "YOU"
    assert _one(_pr(8, owner="you", checks="fail"))["owner"] == "AGENT"


def test_work_items_several_prs_order_you_first_then_agent_by_number():
    prs = [_pr(9, checks="fail"), _pr(5, draft=True), _pr(12), _pr(3)]
    rows, _ = core.work_items([_rank("p")], {"p": prs}, {}, {})
    assert [r["ref"] for r in rows] == ["o/r#3", "o/r#12", "o/r#5", "o/r#9"]


def test_work_items_waiting_session_first():
    ranked = [_rank("p", "waiting", "needs input")]
    rows, _ = core.work_items(ranked, {"p": [_pr(2)]}, {}, {}, now_epoch=0)
    assert rows[0]["item"] == "session" and rows[0]["next_step"] == "reply to session"
    assert rows[0]["owner"] == "YOU" and rows[0]["ready"].startswith("✔ ")
    assert rows[0]["waiting_reason"] == "needs input" and rows[0]["ref"] is None
    assert rows[1]["next_step"] == "merge #2"


PLAN = {"name": "next-chooser", "text": "- [x] **AC1 — done.** x\n- [ ] **AC5 — The sweep sees every open PR.** y\n"}


def test_work_items_plan_row_and_suppression():
    rows, _ = core.work_items([_rank("p")], {}, {"p": PLAN}, {"p": "step"})
    assert len(rows) == 1
    assert (rows[0]["item"], rows[0]["owner"], rows[0]["ready"]) == ("next-chooser", "AGENT", "○")
    assert rows[0]["next_step"].startswith("AC5 The sweep sees") and len(rows[0]["next_step"]) <= 22
    rows, _ = core.work_items([_rank("p")], {"p": [_pr(1)]}, {"p": PLAN}, {})
    assert [r["next_step"] for r in rows] == ["merge #1"]
    done = {"name": "x", "text": "- [x] **AC1 — done.**\n"}
    rows, quiet = core.work_items([_rank("p")], {}, {"p": done}, {})
    assert rows == [] and quiet == ["p"]


def test_work_items_checkpoint_fallback_and_quiet_and_order():
    ranked = [_rank("a"), _rank("b"), _rank("c")]
    rows, quiet = core.work_items(ranked, {"c": [_pr(1)]}, {}, {"a": "do the thing"})
    assert quiet == ["b"]
    assert [r["project"] for r in rows] == ["a", "c"]
    assert (rows[0]["item"], rows[0]["next_step"], rows[0]["owner"], rows[0]["ready"]) == ("", "do the thing", "—", "")


def test_short_title_strips_prefix_and_truncates():
    assert core.short_title("feat(next): interactive chooser with an earned suggestion") == "interactive choos…"
    assert core.short_title("fix!: tiny") == "tiny"
    assert core.short_title("plain title here") == "plain title here"
    assert len(core.short_title("x" * 40)) == 18


def test_numbered_rows_adds_n_status_and_default_waiting_reason():
    ranked = [{"name": "a", "status": "waiting"}, {"name": "b", "status": "idle"}]
    work = [
        {"project": "a", "item": "session", "next_step": "reply to session", "owner": "YOU", "ready": "✔ 1d ago",
         "ref": None, "age": "1d ago", "waiting_reason": "why"},
        {"project": "b", "item": "", "next_step": "x", "owner": "—", "ready": "", "ref": None, "age": "2d ago"},
    ]
    rows = core.numbered_rows(work, ranked)
    assert [(r["n"], r["status"], r["waiting_reason"]) for r in rows] == [(1, "waiting", "why"), (2, "idle", "")]
