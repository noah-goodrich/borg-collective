"""The arrival brief: four lines from one `borg link --json` document, and the hook driver around them."""

from __future__ import annotations

import ast
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import pytest

from borg_core.link import arrival, arrival_hook, core, headlog, picture, render
from borg_core.link.test_render import _repository_doc, _focus

DAY = 86400


def _generated(checkpoint: str, days: int) -> str:
    """`generated_at` that is `days` whole days (and an hour) after the checkpoint's local stamp, in any timezone."""
    stamp = arrival.checkpoint_epoch(checkpoint)
    assert stamp is not None
    return datetime.fromtimestamp(stamp + days * DAY + 3600, timezone.utc).strftime(core.ISO_FORMAT)


HEAD = "tl;dr: Shipped the doorways slices and merged #440.\nsecond line of the same paragraph.\n\n## 1. Goal\n- x"


def _doc(*, checkpoint: str = "2026-10-19-162310-0e958b.md", days: int = 1, rows: list | None = None, **entry) -> dict:
    focus = _focus(
        name="p",
        entry={"path": "/ws/p", "status": "idle", "relative_activity": "3h ago", **entry},
        checkpoints=[checkpoint] if checkpoint else [],
        checkpoint_head=HEAD if checkpoint else "",
        since={"head_moves": 4},
        assimilated=[{"slug": "2026-10-19-done", "ship_date": "2026-10-19"}, {"slug": "old", "ship_date": "2026-09-01"}],
    )
    doc = _repository_doc(focus=focus, generated_at=_generated(checkpoint or "2026-10-19", days))
    doc["waiting"] = {"rows": rows or [], "hidden_lines": [], "degraded": None}
    return doc


def _lines(doc: dict) -> list[str]:
    return arrival.brief(doc).split("\n")


def test_the_brief_is_a_rule_and_four_labelled_lines():
    lines = _lines(_doc())
    assert lines[0].startswith("▸ p ─")
    assert [line.split("  ")[0].strip() for line in lines[1:]] == ["last time", "next", "watch out", "since then"]
    assert "yesterday · Shipped the doorways slices and merged #440. second line" in lines[1]


def test_since_then_leads_with_derived_facts():
    since = _lines(_doc())[4]
    assert "HEAD moved 4 times" in since and "1 shipped (2026-10-19-done)" in since and "last active 3h ago" in since
    assert since.index("HEAD moved") < since.index("last active")


def test_every_line_fits_the_page_even_with_hostile_free_text():
    doc = _doc(summary="s" * 500, waiting_reason="w" * 300, has_uncommitted_changes=True)
    doc["focus"]["checkpoint_head"] = "tl;dr: " + "very long words " * 40
    rows = [{"project": "r" * 60, "item": "session", "next_step": "n" * 200, "owner": "YOU", "ref": None}]
    doc["waiting"]["rows"] = rows
    for line in _lines(doc):
        assert picture.visible_len(line) <= render.PAGE_COLUMNS


def test_next_is_the_repository_pages_own_line_plus_the_owner():
    """The brief and `/borg-link` cannot disagree: same fixture, same line."""
    rows = [{"project": "p", "item": "session", "next_step": "reply to session", "owner": "YOU", "ref": None}]
    doc = _doc(rows=rows)
    page_last = picture.plain(render.document(doc)).rstrip("\n").split("\n")[-1].strip()
    nxt = _lines(doc)[2]
    assert nxt.startswith(" next        ")
    assert nxt.strip()[len("next") :].strip() == page_last[len("next") :].strip() + "  owner: yours"
    ready = _doc()
    assert render.next_action(ready)[1] == ""
    assert _lines(ready)[2].strip().endswith("borg next")
    assert "owner" not in _lines(ready)[2]


def test_the_command_is_never_cut_when_the_label_is_long():
    rows = [{"project": "r" * 80, "item": "session", "next_step": "n" * 200, "owner": "YOU", "ref": None}]
    nxt = _lines(_doc(rows=rows))[2]
    assert "…" in nxt and "borg next  owner: yours" in nxt and picture.visible_len(nxt) <= render.PAGE_COLUMNS


def test_an_old_checkpoint_leads_watch_out_with_stale():
    doc = _doc(checkpoint="2026-10-02-0900.md", days=17, has_uncommitted_changes=True)
    watch = _lines(doc)[3]
    assert watch.startswith(" watch out   STALE: checkpoint is 17d old")
    assert "uncommitted work left behind" in watch
    assert "STALE" not in _lines(_doc())[3]
    assert "nothing flagged" in _lines(_doc())[3]


def test_other_watch_out_facts():
    doc = _doc(clock_divergence={"detected": True, "delta_seconds": 2700}, waiting_reason="permission")
    doc["capacity"] = {"active": 5, "limit": 3, "over_limit": True}
    doc["waiting"]["degraded"] = "gh failed"
    watch = _lines(doc)[3]
    for fact in ("clock skew ~45m", "waiting: permission", "5 active, limit 3", "PR sweep degraded"):
        assert fact in watch


def test_facts_that_do_not_fit_are_counted_never_cut():
    doc = _doc(summary="x", waiting_reason="w" * 70, has_uncommitted_changes=True, checkpoint="2026-10-02-0900.md", days=20)
    watch = _lines(doc)[3]
    assert watch.startswith(" watch out   STALE: checkpoint is 20d old") and "more" in watch
    assert picture.visible_len(watch) <= render.PAGE_COLUMNS


def test_no_checkpoint_says_so_and_still_has_four_lines():
    lines = _lines(_doc(checkpoint=""))
    assert "no checkpoint yet" in lines[1] and len(lines) == 5
    assert "HEAD moved" in lines[4]


def test_a_document_with_nothing_in_it_still_renders():
    lines = _lines({"focus": {"name": "x"}})
    assert len(lines) == 5 and "nothing recorded" in lines[4]


def test_unavailable_is_one_line_that_says_so():
    line = arrival.unavailable("borg link\nexited 1")
    assert "\n" not in line and "unavailable" in line and "borg link exited 1" in line
    assert len(arrival.unavailable("x" * 500)) <= render.PAGE_COLUMNS


@pytest.mark.parametrize(
    ("cwd", "root", "mode"),
    [
        ("/h/dev", "/h/dev", "orchestrator"),
        ("/h/dev/", "/h/dev", "orchestrator"),
        ("/h/dev", "/h/dev//", "orchestrator"),
        ("/h/dev/borg", "/h/dev", "project"),
        ("/h/devx", "/h/dev", "project"),
        ("/", "/", "orchestrator"),
    ],
)
def test_session_mode_matches_the_shell_function(cwd, root, mode):
    assert arrival.session_mode(cwd, root) == mode


def test_session_title_is_the_directory_name():
    assert arrival.session_title("/Users/n/dev/borg-collective/") == "borg-collective"


def test_arrival_imports_only_pure_roots():
    tree = ast.parse(Path(arrival.__file__).read_text(encoding="utf-8"))
    roots = {
        (node.module or "").split(".")[0] if isinstance(node, ast.ImportFrom) else alias.name.split(".")[0]
        for node in ast.walk(tree)
        for alias in (node.names if isinstance(node, (ast.Import, ast.ImportFrom)) else [])
    }
    assert roots <= {"__future__", "re", "datetime", "borg_core"}


# ── core + shell: the additive `focus.since` ─────────────────────────────────────────────────────────────


def test_checkpoint_epoch_reads_the_filename_stamp():
    assert arrival.checkpoint_epoch("2026-10-19-162310-0e958b.md") > arrival.checkpoint_epoch("2026-10-19-1623.md")
    assert arrival.checkpoint_epoch("2026-10-19.md") < arrival.checkpoint_epoch("2026-10-19-0001.md")
    assert arrival.checkpoint_epoch("notes.md") is None
    assert arrival.checkpoint_epoch("2026-13-45-0000.md") is None


def test_count_head_moves_counts_commits_merges_and_pulls_after_the_stamp():
    def entry(epoch: int, message: str) -> str:
        return f"{'0' * 40} {'1' * 40} A <a@b> {epoch} +0000\t{message}"

    log = "\n".join(
        [
            entry(100, "commit: old"),
            entry(300, "commit: new"),
            entry(400, "checkout: moving from a to b"),
            entry(500, "pull: Fast-forward"),
            entry(600, "commit (merge): x"),
            "garbage",
        ]
    )
    assert arrival.count_head_moves(log, 200) == 3
    assert arrival.count_head_moves(log, 10_000) == 0


def test_read_head_moves_reads_the_reflog_without_forking_git(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    assert headlog.read_head_moves(str(tmp_path), 0) is None  # no reflog yet
    log = tmp_path / ".git" / "logs"
    log.mkdir(exist_ok=True)
    (log / "HEAD").write_text(f"{'0' * 40} {'1' * 40} A <a@b> 500 +0000\tcommit: x\n", encoding="utf-8")
    assert headlog.read_head_moves(str(tmp_path), 100) == 1
    assert headlog.read_head_moves(str(tmp_path), None) is None
    assert headlog.read_head_moves(None, 100) is None


# ── the hook driver ──────────────────────────────────────────────────────────────────────────────────────


def _input(**fields) -> str:
    return json.dumps({"session_id": "s", "cwd": "/ws/p", "hook_event_name": "SessionStart", "source": "startup", **fields})


@pytest.fixture(name="calls")
def _calls(monkeypatch):
    seen: list[list[str]] = []
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", "/ws")
    monkeypatch.setattr(arrival_hook, "find_repository", lambda cwd: cwd.rsplit("/", 1)[-1])

    def ask(argv):
        seen.append(argv)
        return "▶ merge #1 · p · 1 waiting\n" if argv[:2] == ["borg", "next"] else json.dumps(_doc())

    monkeypatch.setattr(arrival_hook, "_ask", ask)
    return seen


def test_a_repository_session_asks_for_exactly_one_document(calls):
    out = arrival_hook.run(_input())
    assert calls == [["borg", "link", "p", "--json"]]
    assert "last time" in out["systemMessage"] and out["hookSpecificOutput"]["sessionTitle"] == "p"


def test_the_title_is_only_set_when_none_exists(calls):
    assert "hookSpecificOutput" not in arrival_hook.run(_input(session_title="kept", source="resume"))
    assert calls


@pytest.mark.parametrize("source", ["clear", "compact", "fork", "", "other"])
def test_other_sources_print_nothing(calls, source):
    assert arrival_hook.run(_input(source=source)) is None
    assert calls == []


def test_the_queen_gets_the_verdict_line_and_no_title(calls):
    out = arrival_hook.run(_input(cwd="/ws"))
    assert out == {"systemMessage": "▶ merge #1 · p · 1 waiting"}
    assert calls == [["borg", "next", "--line"]]


def test_failures_are_loud(monkeypatch, calls):
    def boom(_argv):
        raise RuntimeError("borg link exited 1")

    monkeypatch.setattr(arrival_hook, "_ask", boom)
    out = arrival_hook.run(_input())
    assert "unavailable" in out["systemMessage"] and "\n" not in out["systemMessage"] and len(out) == 1
    assert "unavailable" in arrival_hook.run("not json")["systemMessage"]


def test_a_bad_document_is_loud_not_a_crash(monkeypatch, calls):
    monkeypatch.setattr(arrival_hook, "_ask", lambda _argv: "[1, 2]")
    assert "unavailable" in arrival_hook.run(_input())["systemMessage"]
    monkeypatch.setattr(arrival_hook, "_ask", lambda _argv: "{oops")
    assert "unavailable" in arrival_hook.run(_input())["systemMessage"]


def test_the_queen_needs_exactly_one_line(monkeypatch, calls):
    monkeypatch.setattr(arrival_hook, "_ask", lambda _argv: "a\nb\n")
    assert "unavailable" in arrival_hook.run(_input(cwd="/ws"))["systemMessage"]


def test_find_repository_prefers_the_marker_file(tmp_path):
    nested = tmp_path / "a" / "b"
    nested.mkdir(parents=True)
    assert arrival_hook.find_repository(str(nested)) == "b"
    (tmp_path / "a" / ".borg-project").write_text("named\n", encoding="utf-8")
    assert arrival_hook.find_repository(str(nested)) == "named"


def test_ask_translates_every_failure(monkeypatch):
    def raiser(exc):
        def run(*_a, **_k):
            raise exc

        return run

    monkeypatch.setattr(subprocess, "run", raiser(FileNotFoundError()))
    with pytest.raises(RuntimeError, match="not found"):
        arrival_hook._ask(["borg", "x"])  # pylint: disable=protected-access
    monkeypatch.setattr(subprocess, "run", raiser(subprocess.TimeoutExpired("borg", 1)))
    with pytest.raises(RuntimeError, match="timed out"):
        arrival_hook._ask(["borg", "x"])  # pylint: disable=protected-access
    monkeypatch.setattr(subprocess, "run", lambda *_a, **_k: subprocess.CompletedProcess([], 3, "", ""))
    with pytest.raises(RuntimeError, match="exited 3"):
        arrival_hook._ask(["borg", "x"])  # pylint: disable=protected-access
    monkeypatch.setattr(subprocess, "run", lambda *_a, **_k: subprocess.CompletedProcess([], 0, "ok", ""))
    assert arrival_hook._ask(["borg", "x"]) == "ok"  # pylint: disable=protected-access


def test_main_prints_json_and_honours_the_opt_out(monkeypatch, capsys, calls):
    monkeypatch.setattr("sys.stdin", __import__("io").StringIO(_input()))
    assert arrival_hook.main() == 0
    assert json.loads(capsys.readouterr().out)["systemMessage"]
    monkeypatch.setenv("BORG_NO_SESSION_HOOKS", "1")
    assert arrival_hook.main() == 0 and capsys.readouterr().out == ""
