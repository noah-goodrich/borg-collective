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
    repositories = {"zz": {"status": "idle", "last_activity": "x"}, "aa": {"status": "idle", "last_activity": "x"}}
    assert [i["name"] for i in core.rank(repositories)] == ["aa", "zz"]


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
        "repo": "",
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
    " # repository · item      next step          owner ready",
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


def test_render_chooser_collapses_quiet_repositories_into_one_trailing_line():
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


def _qrow(n, repository, status, step="", reason=""):
    return {"n": n, "project": repository, "status": status, "next_step": step, "waiting_reason": reason}


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


def _pr(num, title="feat(next): add the thing", **kw):
    base = {
        "ref": f"o/r#{num}",
        "title": title,
        "state": "open",
        "draft": False,
        "checks": "pass",
        "mergeable": "MERGEABLE",
        "review_decision": None,
        "owner": "you",
    }
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


def test_work_items_review_required_is_waiting_not_a_merge_you_can_do():
    row = _one(_pr(7, review_decision="REVIEW_REQUIRED"))
    assert (row["next_step"], row["owner"], row["ready"]) == ("await review #7", "—", "… wait")
    assert row["ref"] == "o/r#7"
    row = _one(_pr(8, review_decision="APPROVED"))
    assert (row["next_step"], row["owner"]) == ("merge #8", "YOU")
    row = _one(_pr(9, review_decision="REVIEW_REQUIRED", checks="fail"))
    assert row["next_step"] == "fix #9 CI"


def _stack(*prs):
    rows, _ = core.work_items([_rank("p")], {"p": list(prs)}, {}, {})
    return {r["ref"]: r for r in rows}


def test_work_items_stacked_child_waits_on_its_open_parent_never_merge_now():
    rows = _stack(
        _pr(1, head_ref="feat/a", base_ref="main"),
        _pr(2, head_ref="feat/b", base_ref="feat/a"),
    )
    child = rows["o/r#2"]
    assert (child["next_step"], child["owner"], child["ready"]) == ("await #1", "—", "… wait")
    parent = rows["o/r#1"]
    assert (parent["next_step"], parent["owner"], parent["ready"]) == ("merge #1", "YOU", "✔ now")


def test_work_items_stacked_child_keeps_its_own_work_rules_above_the_wait():
    base = {"base_ref": "feat/a"}
    parent = _pr(1, head_ref="feat/a", base_ref="main")
    assert _stack(parent, _pr(2, draft=True, **base))["o/r#2"]["next_step"] == "finish #2"
    assert _stack(parent, _pr(2, mergeable="CONFLICTING", **base))["o/r#2"]["next_step"] == "resolve conflicts #2"
    assert _stack(parent, _pr(2, checks="fail", **base))["o/r#2"]["next_step"] == "fix #2 CI"
    assert _stack(parent, _pr(2, review_decision="CHANGES_REQUESTED", **base))["o/r#2"]["next_step"] == (
        "address review #2"
    )
    row = _stack(parent, _pr(2, review_decision="REVIEW_REQUIRED", **base))["o/r#2"]
    assert row["next_step"] == "await #1"


def test_work_items_base_without_an_open_parent_behaves_as_before():
    parent = _pr(1, head_ref="feat/a", base_ref="main")
    for extra in ({"base_ref": "main"}, {"base_ref": "feat/gone"}, {"base_ref": ""}, {}):
        row = _stack(parent, _pr(2, head_ref="feat/b", **extra))["o/r#2"]
        assert (row["next_step"], row["owner"], row["ready"]) == ("merge #2", "YOU", "✔ now")
    merged = _pr(1, state="merged", head_ref="feat/a", base_ref="main")
    assert _stack(merged, _pr(2, base_ref="feat/a"))["o/r#2"]["next_step"] == "merge #2"


def test_work_items_stack_parent_must_be_in_the_same_repository():
    other = _pr(1, head_ref="feat/a", base_ref="main", ref="o/other#1")
    assert _stack(other, _pr(2, base_ref="feat/a"))["o/r#2"]["next_step"] == "merge #2"


def test_work_items_review_required_rows_do_not_fill_the_cap():
    prs = [_pr(n, review_decision="REVIEW_REQUIRED") for n in range(1, 8)] + [_pr(20), _pr(21)]
    rows, _ = core.work_items([_rank("p")], {"p": prs}, {}, {})
    shown, hidden = core.cap_rows(rows)
    assert [r["ref"] for r in shown] == ["o/r#20", "o/r#21"]
    assert hidden["overflow"] == 0


def test_pr_url_rides_to_the_wire_row_and_session_rows_have_none():
    url = "https://github.com/example-org/example-repo/pull/6"
    ranked = [_rank("p", "waiting", "needs input")]
    work, _ = core.work_items(ranked, {"p": [_pr(6, url=url)]}, {}, {})
    rows = core.numbered_rows(work, ranked)
    assert [(r["ref"], r["url"]) for r in rows] == [(None, ""), ("o/r#6", url)]


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
    rows, _ = core.work_items([_rank("p")], {}, {"p": PLAN}, {})
    assert len(rows) == 1
    assert (rows[0]["item"], rows[0]["owner"], rows[0]["ready"]) == ("next-chooser", "AGENT", "○")
    assert rows[0]["next_step"].startswith(PLAN_STEP) and len(rows[0]["next_step"]) <= 22
    rows, _ = core.work_items([_rank("p")], {"p": [_pr(1)]}, {"p": PLAN}, {})
    assert [r["next_step"] for r in rows] == ["merge #1"]
    done = {"name": "x", "text": "- [x] **AC1 — done.**\n"}
    rows, quiet = core.work_items([_rank("p")], {}, {"p": done}, {})
    assert rows == [] and quiet == ["p"]


PLAN_STEP = "AC5 The sweep sees ev…"


def _cp(*items, mtime=None):
    return {"items": [{"text": t, "owner": o} for o, t in items], "mtime": mtime}


def test_work_items_checkpoint_fallback_and_quiet_and_order():
    ranked = [_rank("a"), _rank("b"), _rank("c")]
    rows, quiet = core.work_items(ranked, {"c": [_pr(1)]}, {}, {"a": _cp(("AGENT", "do the thing"))})
    assert quiet == ["b"]
    assert [r["project"] for r in rows] == ["a", "c"]
    assert (rows[0]["item"], rows[0]["next_step"], rows[0]["owner"], rows[0]["ready"]) == ("", "do the thing", "AGENT", "")
    assert rows[0]["detail"] == "do the thing" and rows[0]["ref"] is None


def test_work_items_checkpoint_row_cuts_next_step_and_keeps_detail_whole():
    text = "w" * 120
    rows, _ = core.work_items([_rank("p")], {}, {}, {"p": _cp(("YOU", text))})
    assert len(rows[0]["next_step"]) == core.NEXT_STEP_MAX and rows[0]["next_step"].endswith("…")
    assert rows[0]["detail"] == text and rows[0]["owner"] == "YOU"


def test_work_items_row_order_inside_one_repository():
    waiting = {**_rank("p"), "status": "waiting", "waiting_reason": "needs input"}
    prs = [_pr(3, mergeable="CONFLICTING"), _pr(2)]
    checkpoint = _cp(("AGENT", "next one"), ("YOU", "wait one"), ("YOU", "wait two"))
    rows, _ = core.work_items([waiting], {"p": prs}, {"p": PLAN}, {"p": checkpoint})
    assert [(r["owner"], r["next_step"]) for r in rows] == [
        ("YOU", "reply to session"),
        ("YOU", "merge #2"),
        ("YOU", "wait one"),
        ("YOU", "wait two"),
        ("AGENT", "resolve conflicts #3"),
    ]


def test_work_items_next_session_rows_follow_the_plan_row_or_stand_in_for_it():
    checkpoint = _cp(("YOU", "wait"), ("AGENT", "first"), ("AGENT", "second"))
    rows, _ = core.work_items([_rank("p")], {}, {"p": PLAN}, {"p": checkpoint})
    assert [(r["owner"], r["next_step"]) for r in rows] == [("YOU", "wait"), ("AGENT", PLAN_STEP)]
    rows, _ = core.work_items([_rank("p")], {}, {}, {"p": checkpoint})
    assert [(r["owner"], r["next_step"]) for r in rows] == [("YOU", "wait"), ("AGENT", "first"), ("AGENT", "second")]
    rows, _ = core.work_items([_rank("p")], {"p": [_pr(1)]}, {}, {"p": checkpoint})
    assert [(r["owner"], r["next_step"]) for r in rows] == [("YOU", "merge #1"), ("YOU", "wait")]


def test_work_items_a_checkpoint_newer_than_the_plan_replaces_the_plan_row():
    plan = {**PLAN, "mtime": 100.0}
    newer = _cp(("AGENT", "from the checkpoint"), mtime=200.0)
    older = _cp(("AGENT", "from the checkpoint"), mtime=50.0)
    rows, _ = core.work_items([_rank("p")], {}, {"p": plan}, {"p": newer})
    assert [r["next_step"] for r in rows] == ["from the checkpoint"]
    rows, _ = core.work_items([_rank("p")], {}, {"p": plan}, {"p": older})
    assert [r["next_step"] for r in rows] == [PLAN_STEP]


def test_work_items_freshness_needs_both_mtimes_and_a_tie_keeps_the_plan():
    checkpoint = _cp(("AGENT", "from the checkpoint"), mtime=100.0)
    for plan in ({**PLAN, "mtime": None}, PLAN, {**PLAN, "mtime": 100.0}):
        rows, _ = core.work_items([_rank("p")], {}, {"p": plan}, {"p": checkpoint})
        assert [r["next_step"] for r in rows] == [PLAN_STEP]
    rows, _ = core.work_items([_rank("p")], {}, {"p": {**PLAN, "mtime": 1.0}}, {"p": {**checkpoint, "mtime": None}})
    assert [r["next_step"] for r in rows] == [PLAN_STEP]


def test_short_title_strips_prefix_and_truncates():
    assert core.short_title("feat(next): interactive chooser with an earned suggestion") == "interactive choos…"
    assert core.short_title("fix!: tiny") == "tiny"
    assert core.short_title("plain title here") == "plain title here"
    assert len(core.short_title("x" * 40)) == 18


def test_numbered_rows_adds_n_status_and_default_waiting_reason():
    ranked = [{"name": "a", "status": "waiting"}, {"name": "b", "status": "idle"}]
    work = [
        {
            "project": "a",
            "item": "session",
            "next_step": "reply to session",
            "owner": "YOU",
            "ready": "✔ 1d ago",
            "ref": None,
            "age": "1d ago",
            "waiting_reason": "why",
        },
        {"project": "b", "item": "", "next_step": "x", "owner": "—", "ready": "", "ref": None, "age": "2d ago"},
    ]
    rows = core.numbered_rows(work, ranked)
    assert [(r["n"], r["status"], r["waiting_reason"]) for r in rows] == [(1, "waiting", "why"), (2, "idle", "")]


NOW = 1_790_000_000
OLD = "updated 2026-07-01T00:00:00Z; state=open; draft"
FRESH = "updated 2026-09-20T00:00:00Z; state=open; draft"


def _work(ranked, items, now=NOW):
    rows, _ = core.work_items(ranked, items, {}, {}, now_epoch=now)
    return rows


def _you_rows(count):
    return [{"project": "p", "item": f"i{n}", "owner": "YOU", "ref": f"o/r#{n}", "stale": False} for n in range(count)]


def test_cap_rows_shows_at_most_five_you_rows_in_existing_order():
    shown, hidden = core.cap_rows(_you_rows(8))
    assert [r["ref"] for r in shown] == [f"o/r#{n}" for n in range(5)]
    assert hidden == {"agent": 0, "stale": 0, "overflow": 3, "unowned": 0}


def test_cap_rows_collapses_agent_and_unowned_rows_into_a_count():
    work = [{"owner": "AGENT", "stale": False}, {"owner": "—", "stale": False}, *_you_rows(2)]
    shown, hidden = core.cap_rows(work)
    assert [r["owner"] for r in shown] == ["YOU", "YOU"]
    assert hidden == {"agent": 1, "stale": 0, "overflow": 0, "unowned": 1}


def test_cap_rows_counts_a_blank_owner_as_unowned_and_a_stale_draft_as_stale_only():
    work = [{"owner": "", "stale": False}, {"owner": "—", "stale": True}, {"owner": "AGENT", "stale": False}]
    shown, hidden = core.cap_rows(work)
    assert shown == [] and hidden == {"agent": 1, "stale": 1, "overflow": 0, "unowned": 1}


def test_cap_rows_all_returns_everything_uncounted():
    work = [{"owner": "AGENT", "stale": True}, *_you_rows(7)]
    shown, hidden = core.cap_rows(work, show_all=True)
    assert shown == work and hidden == {"agent": 0, "stale": 0, "overflow": 0, "unowned": 0}


def test_hidden_lines_fixed_order_and_no_zeros():
    assert core.hidden_lines({"agent": 4, "stale": 2, "overflow": 1, "unowned": 3}) == [
        "+1 more decisions",
        "+4 agent tasks",
        "+3 unowned",
        "+2 stale drafts",
    ]
    assert core.hidden_lines({"agent": 0, "stale": 0, "overflow": 0, "unowned": 0}) == []
    assert core.hidden_lines({"agent": 4, "stale": 2, "overflow": 1}) == [
        "+1 more decisions",
        "+4 agent tasks",
        "+2 stale drafts",
    ]


def test_first_next_is_the_first_row_that_is_not_a_stale_draft_with_its_full_text():
    work = [
        {"project": "p", "next_step": "old draft", "owner": "AGENT", "stale": True},
        {"project": "p", "next_step": "cut step", "detail": "the whole step text", "owner": "—", "stale": False},
        {"project": "p", "next_step": "later", "owner": "AGENT", "stale": False},
    ]
    assert core.first_next(work) == {
        "project": "p",
        "next_step": "cut step",
        "detail": "the whole step text",
        "owner": "—",
    }
    assert core.first_next([{"project": "p", "next_step": "x", "owner": "AGENT"}])["detail"] == "x"
    assert core.first_next([{"owner": "AGENT", "stale": True}]) is None
    assert core.first_next([]) is None


def test_render_chooser_prints_the_summary_lines_before_the_rule():
    rows = [{"n": 1, "project": "a", "item": "x", "next_step": "merge #1", "owner": "YOU", "ready": "✔ now"}]
    lines = core.render_chooser(rows, suggestion=None, hidden={"agent": 3, "stale": 1, "overflow": 0, "unowned": 0})
    assert lines[2 + 1 + 1 : 2 + 1 + 3] == ["+3 agent tasks", "+1 stale drafts"]


def test_stale_drafts_are_flagged_only_past_thirty_days():
    rows = _work([_rank("p")], {"p": [_pr(1, draft=True, changed=OLD), _pr(2, draft=True, changed=FRESH)]})
    assert [(r["ref"], r["stale"]) for r in rows] == [("o/r#1", True), ("o/r#2", False)]
    _, hidden = core.cap_rows(rows)
    assert hidden["stale"] == 1 and hidden["agent"] == 1


def test_stale_needs_a_clock_a_draft_and_a_timestamp():
    assert not _work([_rank("p")], {"p": [_pr(1, draft=True, changed=OLD)]}, now=0)[0]["stale"]
    assert not _work([_rank("p")], {"p": [_pr(1, changed=OLD)]})[0]["stale"]
    assert not _work([_rank("p")], {"p": [_pr(1, draft=True)]})[0]["stale"]


def test_repositories_sharing_a_repo_do_not_repeat_a_pr():
    ranked = [{**_rank("reveal"), "repo": "/g"}, {**_rank("reveal-data-consistency"), "repo": "/g"}]
    rows = _work(ranked, {"reveal": [_pr(4)], "reveal-data-consistency": [_pr(4), _pr(5)]})
    assert [(r["project"], r["ref"]) for r in rows] == [("reveal", "o/r#4"), ("reveal-data-consistency", "o/r#5")]


def test_null_or_different_repo_is_a_group_of_one():
    ranked = [{**_rank("a"), "repo": ""}, {**_rank("b"), "repo": ""}, {**_rank("c"), "repo": "/other"}]
    rows = _work(ranked, {"a": [_pr(4)], "b": [_pr(4)], "c": [_pr(4)]})
    assert [r["project"] for r in rows] == ["a", "b", "c"]


def test_sessions_are_never_deduped_across_a_repo_group():
    ranked = [{**_rank("a", "waiting"), "repo": "/g"}, {**_rank("b", "waiting"), "repo": "/g"}]
    assert [r["item"] for r in _work(ranked, {})] == ["session", "session"]


def _card_row(**over):
    row = {
        "project": "alpha",
        "item": "ship the thing",
        "next_step": "merge #7",
        "owner": "YOU",
        "ready": "✔ now",
        "ref": "o/alpha#7",
        "waiting_reason": "",
    }
    return {**row, **over}


def _assert_fits(card):
    assert 1 <= len(card) <= core.CARD_LINES
    assert all(len(line) <= core.CARD_WIDTH for line in card), card


def test_card_ends_in_the_exact_command_and_carries_the_next_step():
    card = core.chooser_card(_card_row())
    _assert_fits(card)
    assert card[-1] == "borg next --open alpha --chosen"
    assert card[0] == "alpha · ship the thing"
    assert "merge #7" in card
    assert "o/alpha#7 · YOU · ✔ now" in card


def test_card_command_carries_shown_only_when_asked():
    assert core.chooser_card(_card_row(), shown=True)[-1] == "borg next --open alpha --chosen --shown"


def test_card_three_states_waiting_session_pr_and_plan_row():
    waiting = _card_row(
        item="", next_step="reply to session", ready="✔ 2d", ref=None, waiting_reason="needs a call on the schema"
    )
    pr = _card_row(next_step="await review #9", owner="—", ready="… wait")
    plan = _card_row(item="AC5", next_step="finish the cards", owner="AGENT", ready="○", ref=None)
    for row in (waiting, pr, plan):
        card = core.chooser_card(row)
        _assert_fits(card)
        assert card[-1] == "borg next --open alpha --chosen"
        assert row["next_step"] in card
    assert core.chooser_card(waiting)[0] == "alpha"
    assert "“needs a call on the schema”" in core.chooser_card(waiting)
    assert "—" in core.chooser_card(pr)[1]


def test_card_long_label_and_next_step_are_cut_with_an_ellipsis():
    row = _card_row(item="x" * 80, next_step="word " * 40, waiting_reason="y" * 90)
    card = core.chooser_card(row)
    _assert_fits(card)
    assert card[0].endswith("…") and card[0].startswith("alpha · xxx")
    assert any(line.endswith("…") for line in card[1:-1])
    assert card[-1] == "borg next --open alpha --chosen"


def test_card_long_ref_is_never_cut():
    ref = "some-org/some-very-long-repository-name#1234"
    card = core.chooser_card(_card_row(ref=ref))
    assert any(line.startswith(ref) for line in card)


def test_card_long_command_wraps_whole_and_label_lines_give_way():
    name = "a-repository-with-a-quite-long-name"
    card = core.chooser_card(_card_row(project=name, waiting_reason="why"), shown=True)
    _assert_fits(card)
    command = card[card.index(next(line for line in card if line.startswith("borg next --open"))) :]
    assert len(command) == 3
    assert " ".join(part.strip() for part in command) == f"borg next --open {name} --chosen --shown"
    assert card[0].startswith(name) and any("merge #7" in line for line in card)
    assert not any("why" in line for line in card)


def test_card_with_a_name_wider_than_the_card_keeps_it_whole():
    name = "n" * 50
    card = core.chooser_card(_card_row(project=name))
    assert any(name in line for line in card)
    assert card[-1].endswith("--chosen")
