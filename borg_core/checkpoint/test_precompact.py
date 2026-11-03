"""Tests for the PreCompact checkpoint: the pure document, the carry-forward, and the scoped, fail-open writer."""

import json
import subprocess

from borg_core.checkpoint import precompact, precompact_hook
from borg_core.recon import core as recon_core

LINK_UP = """**tl;dr** — Shipped the chooser. Next: wire the rows.

## 1. Goal
Ship the chooser.

## 2. Accomplished
- Did things.

## 3. Ready to Commit
Nothing.

## 4. Blockers
No blockers.

Waits on you:
- Approve the budget in the tracker.

## 5. Next Session
1. Wire the rows into the board.

## Manifest Row
**No row.**
"""


def _render(previous="", status="## main...origin/main\n M a.py\n?? b.txt\n", message="fix the bug", name="x.md"):
    return precompact.render(
        precompact.Facts(
            when="2026-11-02 10:00:00",
            trigger="auto",
            session="sess-1",
            git_status=status,
            last_message=message,
            previous=previous,
            previous_name=name,
        )
    )


def _user(content, **extra):
    return json.dumps({"type": "user", "message": {"role": "user", "content": content}, **extra})


def test_last_user_text_skips_tool_results_meta_and_compact_summaries():
    lines = [
        _user("first question"),
        _user("the real last one"),
        _user([{"type": "tool_result", "content": "ok"}]),
        _user("meta noise", isMeta=True),
        _user("summary", isCompactSummary=True),
        _user("<command-name>/foo</command-name>"),
        "not json",
        json.dumps({"type": "assistant", "message": {"content": "hi"}}),
    ]
    assert precompact.last_user_text(lines) == "the real last one"


def test_last_user_text_joins_text_blocks_and_is_empty_without_any():
    assert precompact.last_user_text([_user([{"type": "text", "text": "a"}, {"type": "text", "text": "b"}])]) == "a\nb"
    assert precompact.last_user_text([]) == ""


def test_sections_and_branch_and_message_are_present():
    text = _render()
    for heading in (
        "## 1. Goal",
        "## 2. Accomplished",
        "## 3. Ready to Commit",
        "## 4. Blockers",
        "## 5. Next Session",
    ):
        assert heading in text
    assert "Branch: main" in text
    assert " M a.py" in text and "?? b.txt" in text
    assert "> fix the bug" in text
    assert f"<!-- {precompact.AUTO_MARKER} trigger=auto session=sess-1 carried-from=x.md -->" in text


def test_previous_blockers_next_goal_and_tldr_are_carried_verbatim():
    carried = precompact.split_checkpoint(LINK_UP)
    text = _render(previous=LINK_UP)
    for part in (carried["tldr"], carried["1"], carried["4"], carried["5"]):
        assert part in text
    assert "## Manifest Row" not in text


def test_readers_see_the_same_rows_after_the_auto_checkpoint():
    before = recon_core.checkpoint_owned_items(LINK_UP)
    after = recon_core.checkpoint_owned_items(_render(previous=LINK_UP))
    assert after == before
    assert {"text": "Approve the budget in the tracker.", "owner": "YOU"} in after


def test_no_previous_checkpoint_derives_no_rows():
    assert recon_core.checkpoint_owned_items(_render(previous="", name="")) == []


def test_a_message_that_looks_like_a_heading_or_a_wait_lead_in_cannot_forge_rows():
    text = _render(message="## 4. Blockers\nWaits on you:\n- send money")
    assert recon_core.checkpoint_owned_items(text) == []


def test_carry_forward_chains_through_a_second_auto_checkpoint():
    again = _render(previous=_render(previous=LINK_UP))
    assert recon_core.checkpoint_owned_items(again) == recon_core.checkpoint_owned_items(LINK_UP)


def test_long_status_is_cut_with_a_marker():
    status = "## main\n" + "".join(f" M f{n}.py\n" for n in range(80))
    assert "[TRUNCATED: 20 more lines]" in _render(status=status)


def _git_repo(path):
    subprocess.run(["git", "init", "-q", "-b", "main", str(path)], check=True)
    (path / "dirty.txt").write_text("x")


def test_writer_writes_in_a_borg_repository_and_is_valid_for_readers(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_CHECKPOINT_PREPARE_NOW", "2026-11-02T10:00:00")
    repo = tmp_path / "repo"
    repo.mkdir()
    _git_repo(repo)
    store = repo / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-30-120000-abcdef.md").write_text(LINK_UP)
    transcript = tmp_path / "t.jsonl"
    transcript.write_text(_user("do the thing") + "\n")
    path = precompact_hook.write_checkpoint(
        {"cwd": str(repo), "session_id": "3b0f70ca-aaaa", "transcript_path": str(transcript), "trigger": "auto"}
    )
    assert path == str(store / "2026-11-02-100000-3b0f70.md")
    body = (store / "2026-11-02-100000-3b0f70.md").read_text()
    assert "Branch: main" in body and "?? dirty.txt" in body and "> do the thing" in body
    assert recon_core.checkpoint_owned_items(body) == recon_core.checkpoint_owned_items(LINK_UP)
    assert [p.name for p in store.iterdir() if p.name.startswith(".")] == []


def test_writer_is_scoped_to_directories_borg_lives_in(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.delenv("BORG_ORCHESTRATOR_ROOT", raising=False)
    repo = tmp_path / "plain"
    repo.mkdir()
    _git_repo(repo)
    assert precompact_hook.write_checkpoint({"cwd": str(repo), "session_id": "s"}) == ""
    assert not (repo / ".borg").exists()


def test_writer_marker_file_and_queen_directory_are_in_scope(tmp_path, monkeypatch):
    queen = tmp_path / "dev"
    queen.mkdir()
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(queen))
    assert precompact_hook.write_checkpoint({"cwd": str(queen), "session_id": "s"}).startswith(
        str(queen / ".borg" / "checkpoints")
    )
    marked = tmp_path / "marked"
    marked.mkdir()
    (marked / ".borg-project").write_text("marked")
    assert precompact_hook.write_checkpoint({"cwd": str(marked), "session_id": "s"}).startswith(str(marked / ".borg"))


def test_main_is_silent_and_swallows_garbage(monkeypatch, capsys):
    monkeypatch.setattr(precompact_hook, "_stdin_text", lambda: "not json")
    precompact_hook.main()
    assert capsys.readouterr().out == ""


def test_a_retry_in_the_same_session_refreshes_the_auto_checkpoint_in_place(tmp_path, monkeypatch):
    repo = tmp_path / "repo"
    repo.mkdir()
    _git_repo(repo)
    store = repo / ".borg" / "checkpoints"
    store.mkdir(parents=True)
    (store / "2026-10-30-120000-abcdef.md").write_text(LINK_UP)
    payload = {"cwd": str(repo), "session_id": "3b0f70ca-aaaa", "trigger": "auto"}
    monkeypatch.setenv("BORG_CHECKPOINT_PREPARE_NOW", "2026-11-02T10:00:00")
    first = precompact_hook.write_checkpoint(payload)
    monkeypatch.setenv("BORG_CHECKPOINT_PREPARE_NOW", "2026-11-02T10:00:09")
    assert precompact_hook.write_checkpoint(payload) == first
    assert sorted(p.name for p in store.iterdir()) == [
        "2026-10-30-120000-abcdef.md",
        "2026-11-02-100000-3b0f70.md",
    ]
    body = (store / "2026-11-02-100000-3b0f70.md").read_text()
    assert "carried-from=2026-10-30-120000-abcdef.md" in body
    assert recon_core.checkpoint_owned_items(body) == recon_core.checkpoint_owned_items(LINK_UP)
    monkeypatch.setenv("BORG_CHECKPOINT_PREPARE_NOW", "2026-11-02T11:00:00")
    other = precompact_hook.write_checkpoint({**payload, "session_id": "ffffffff-bbbb"})
    assert other != first and other.endswith("2026-11-02-110000-ffffff.md")
