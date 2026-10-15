"""Tests for the impure reads behind `borg checkpoint-prepare` and its exit-0-always CLI."""

import json
import os
import subprocess
from datetime import datetime
from pathlib import Path

import pytest

from borg_core import proc
from borg_core.checkpoint import prepare, prepare_cli, prepare_shell


@pytest.fixture(autouse=True)
def _sandbox(tmp_path, monkeypatch):
    """Machine-layer extensions and the git identity live in the sandbox, never the developer's."""
    monkeypatch.setenv("BORG_DIR", str(tmp_path / "borgdir"))
    monkeypatch.setenv("HOME", str(tmp_path / "home"))
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    monkeypatch.delenv(prepare_shell.NOW_OVERRIDE_ENV, raising=False)


def _git_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    return repo


# ------------------------------------------------------------------------------------------ budget


def test_budget_slice_is_the_cap_while_time_remains(monkeypatch):
    monkeypatch.setattr(prepare_shell.time, "monotonic", lambda: 100.0)
    budget = prepare_shell.Budget(20.0)
    assert budget.slice(5.0) == 5.0
    assert budget.slice(50.0) == 20.0


def test_budget_slice_is_zero_once_spent(monkeypatch):
    clock = iter([100.0, 125.0, 125.0])
    monkeypatch.setattr(prepare_shell.time, "monotonic", lambda: next(clock))
    budget = prepare_shell.Budget(20.0)
    assert budget.remaining() == 0.0
    assert budget.slice(5.0) == 0.0


def test_run_skips_the_subprocess_when_the_budget_is_spent(monkeypatch):
    calls = []
    monkeypatch.setattr(proc, "run_capture", lambda *a, **k: calls.append(a) or (0, ""))
    budget = prepare_shell.Budget(0.0)
    assert prepare_shell._run(["git", "status"], budget, 5.0) is None
    assert calls == []


# --------------------------------------------------------------------------------------------- clock


def test_now_honours_a_valid_override_and_ignores_garbage(monkeypatch):
    monkeypatch.setenv(prepare_shell.NOW_OVERRIDE_ENV, "2026-10-14T10:10:10")
    assert prepare_shell.now() == datetime(2026, 10, 14, 10, 10, 10)
    monkeypatch.setenv(prepare_shell.NOW_OVERRIDE_ENV, "not a time")
    assert prepare_shell.now().year >= 2026


# ----------------------------------------------------------------------------------- root and plan


def test_repository_root_is_the_git_toplevel_from_a_subdirectory(tmp_path):
    repo = _git_repo(tmp_path)
    sub = repo / "a" / "b"
    sub.mkdir(parents=True)
    root = prepare_shell.repository_root(str(sub), prepare_shell.Budget())
    assert Path(root).resolve() == repo.resolve()


def test_repository_root_falls_back_to_the_cwd_outside_a_repository(tmp_path):
    plain = tmp_path / "plain"
    plain.mkdir()
    assert prepare_shell.repository_root(str(plain), prepare_shell.Budget()) == str(plain)


def test_plan_path_prefers_the_root_file_then_docs_plans(tmp_path):
    assert prepare_shell.plan_path(str(tmp_path)) == ""
    (tmp_path / "docs" / "plans").mkdir(parents=True)
    (tmp_path / "docs" / "plans" / "PROJECT_PLAN.md").write_text("x")
    assert prepare_shell.plan_path(str(tmp_path)).endswith(os.path.join("docs", "plans", "PROJECT_PLAN.md"))
    (tmp_path / "PROJECT_PLAN.md").write_text("x")
    assert prepare_shell.plan_path(str(tmp_path)) == str(tmp_path / "PROJECT_PLAN.md")


# ------------------------------------------------------------------------------------ git status


def test_git_status_reports_the_branch_line_and_changes(tmp_path):
    repo = _git_repo(tmp_path)
    (repo / "new.txt").write_text("x")
    out, reason = prepare_shell.git_status(str(repo), prepare_shell.Budget())
    assert reason == ""
    assert out is not None and out.startswith("## ") and "?? new.txt" in out


def test_git_status_outside_a_repository_is_a_reason_not_an_error(tmp_path):
    out, reason = prepare_shell.git_status(str(tmp_path), prepare_shell.Budget())
    assert out is None and "exited" in reason


def test_git_status_without_git_installed(monkeypatch, tmp_path):
    monkeypatch.setattr(prepare_shell.shutil, "which", lambda name: None)
    assert prepare_shell.git_status(str(tmp_path), prepare_shell.Budget()) == (None, "git not installed")


def test_git_status_that_times_out(monkeypatch, tmp_path):
    monkeypatch.setattr(proc, "run_capture", lambda *a, **k: None)
    out, reason = prepare_shell.git_status(str(tmp_path), prepare_shell.Budget())
    assert out is None and "in time" in reason


def test_git_status_does_not_touch_the_index(tmp_path):
    repo = _git_repo(tmp_path)
    tracked = repo / "t.txt"
    tracked.write_text("one")
    subprocess.run(["git", "-C", str(repo), "add", "t.txt"], check=True)
    subprocess.run(
        ["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t.invalid", "commit", "-qm", "i"], check=True
    )
    tracked.write_text("one")  # same bytes, new stat: a plain `git status` would refresh the index
    index = repo / ".git" / "index"
    before = index.stat().st_mtime_ns
    prepare_shell.git_status(str(repo), prepare_shell.Budget())
    assert index.stat().st_mtime_ns == before


# ------------------------------------------------------------------------------------- manifest


def test_manifest_resolve_refuses_with_the_first_stderr_line(tmp_path):
    stem, reason = prepare_shell.manifest_resolve(str(tmp_path))
    assert stem == "" and reason.startswith("no manifest")


def test_manifest_resolve_returns_the_stem_for_one_manifest(tmp_path):
    from borg_core.manifest import cli as manifest_cli

    assert manifest_cli.main(["scaffold", "--repository", str(tmp_path), "--name", "s1", "--desc", "d"]) == 0
    assert prepare_shell.manifest_resolve(str(tmp_path)) == ("s1", "")


def test_manifest_resolve_survives_a_systemexit(monkeypatch, tmp_path):
    def boom(argv):
        raise SystemExit(2)

    monkeypatch.setattr(prepare_shell.manifest_cli, "main", boom)
    assert prepare_shell.manifest_resolve(str(tmp_path)) == ("", "resolve refused without a reason")


# ---------------------------------------------------------------------------------------------- PR


def _gh(monkeypatch, *, answer, head=(0, "topic\n")):
    monkeypatch.setattr(prepare_shell.shutil, "which", lambda name: f"/bin/{name}")

    def fake(argv, timeout=None, cwd=None):
        return head if argv[0] == "git" else answer

    monkeypatch.setattr(proc, "run_capture", fake)


def test_pull_request_reads_owner_repo_number_and_url(monkeypatch, tmp_path):
    body = json.dumps({"number": 7, "url": "https://github.com/own/rep/pull/7"})
    _gh(monkeypatch, answer=(0, body))
    assert prepare_shell.pull_request(str(tmp_path), prepare_shell.Budget()) == (
        "own/rep#7",
        "https://github.com/own/rep/pull/7",
        "",
    )


@pytest.mark.parametrize(
    "answer, head, expected",
    [
        (None, (0, "topic\n"), "did not answer"),
        ((1, ""), (0, "topic\n"), "exited 1"),
        ((0, "not json"), (0, "topic\n"), "unexpected shape"),
        ((0, json.dumps({"number": 7})), (0, "topic\n"), "unexpected shape"),
        ((0, json.dumps({"number": 7, "url": "https://evil.example/x y/pull/7"})), (0, "t\n"), "not a pull request"),
        ((0, json.dumps({"number": 8, "url": "https://github.com/o/r/pull/7"})), (0, "t\n"), "not a pull request"),
        ((0, "{}"), (1, ""), "detached HEAD"),
    ],
)
def test_pull_request_failures_become_reasons(monkeypatch, tmp_path, answer, head, expected):
    _gh(monkeypatch, answer=answer, head=head)
    ref, url, reason = prepare_shell.pull_request(str(tmp_path), prepare_shell.Budget())
    assert (ref, url) == ("", "") and expected in reason


def test_pull_request_without_gh(monkeypatch, tmp_path):
    monkeypatch.setattr(prepare_shell.shutil, "which", lambda name: None)
    assert prepare_shell.pull_request(str(tmp_path), prepare_shell.Budget()) == ("", "", "gh not installed")


# ------------------------------------------------------------------------------------ extensions


def _write_ext(base: Path, hook: str, text: str) -> Path:
    path = base / "skill-extensions" / "borg-link-up" / f"{hook}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def test_extensions_absent_everywhere(tmp_path):
    found, rows = prepare_shell.extensions(str(tmp_path))
    assert rows == ()
    assert [e.hook for e in found] == list(prepare.HOOKS)
    assert all(e.machine is None and e.repository is None and e.precedence == prepare.NO_EXTENSION for e in found)


def test_extensions_both_layers_prose_repository_wins(tmp_path):
    _write_ext(tmp_path / "borgdir" / "extensions", "01-context", "machine text\n")
    _write_ext(tmp_path / ".borg", "01-context", "repo text\n")
    first = prepare_shell.extensions(str(tmp_path))[0][0]
    assert first.machine is not None and first.machine.body == "machine text\n"
    assert first.repository is not None and first.repository.body == "repo text\n"
    assert "repository layer wins" in first.precedence


def test_extensions_prefer_tool_row_and_machine_wins(tmp_path):
    _write_ext(tmp_path / "borgdir" / "extensions", "02-output", "- Prefer-tool: `mycli`\n- Instead-of: `gh`\n")
    _write_ext(tmp_path / ".borg", "02-output", "prose only\n")
    found, rows = prepare_shell.extensions(str(tmp_path))
    assert "machine layer wins" in found[1].precedence
    assert [(r.hook, r.layer, r.prefer, r.instead_of) for r in rows] == [("02-output", "machine", "mycli", "gh")]


def test_extensions_same_key_in_both_layers_is_flagged(tmp_path):
    _write_ext(tmp_path / "borgdir" / "extensions", "03-followup", "- Prefer-tool: a\n")
    _write_ext(tmp_path / ".borg", "03-followup", "- Prefer-tool: b\n")
    assert "both assert the same key" in prepare_shell.extensions(str(tmp_path))[0][2].precedence


def test_extensions_single_layer_note(tmp_path):
    _write_ext(tmp_path / ".borg", "01-context", "x")
    assert prepare_shell.extensions(str(tmp_path))[0][0].precedence == "only the repository layer is present"


def test_read_layer_is_bounded_and_reports_the_real_size(tmp_path):
    big = tmp_path / "big.md"
    big.write_bytes(b"a" * (prepare_shell.READ_CAP_BYTES + 5000))
    layer = prepare_shell._read_layer(str(big))
    assert layer is not None
    assert len(layer.body) == prepare_shell.READ_CAP_BYTES
    assert layer.total_bytes == prepare_shell.READ_CAP_BYTES + 5000


def test_read_layer_treats_unreadable_and_directories_as_absent(tmp_path):
    assert prepare_shell._read_layer(str(tmp_path / "missing.md")) is None
    assert prepare_shell._read_layer(str(tmp_path)) is None


def test_read_layer_survives_invalid_utf8(tmp_path):
    path = tmp_path / "bad.md"
    path.write_bytes(b"ok \xff\xfe bytes")
    layer = prepare_shell._read_layer(str(path))
    assert layer is not None and layer.body.startswith("ok ")


# ----------------------------------------------------------------------------------------- gather


def test_gather_on_an_empty_repository_has_no_problems(tmp_path, monkeypatch):
    monkeypatch.setenv(prepare_shell.NOW_OVERRIDE_ENV, "2026-10-14T10:10:10")
    monkeypatch.setattr(prepare_shell.shutil, "which", lambda name: "/usr/bin/git" if name == "git" else None)
    repo = _git_repo(tmp_path)
    facts = prepare_shell.gather(str(repo), "3b0f70ca-74cd")
    assert facts.problems == ()
    assert facts.checkpoint_path.endswith("/.borg/checkpoints/2026-10-14-101010-3b0f70.md")
    assert facts.pr_reason == "gh not installed"
    assert facts.git_status is not None


def test_source_dir_is_the_directory_holding_borg_core(tmp_path, monkeypatch):
    monkeypatch.setenv(prepare_shell.NOW_OVERRIDE_ENV, "2026-10-14T10:10:10")
    found = Path(prepare_shell.source_dir())
    assert found.is_absolute()
    assert (found / "borg_core" / "checkpoint" / "prepare_shell.py").is_file()
    assert prepare_shell.gather(str(_git_repo(tmp_path))).source_dir == str(found)


def test_gather_advances_the_checkpoint_name_past_an_existing_file(tmp_path, monkeypatch):
    monkeypatch.setenv(prepare_shell.NOW_OVERRIDE_ENV, "2026-10-14T10:10:10")
    repo = _git_repo(tmp_path)
    taken = repo / ".borg" / "checkpoints"
    taken.mkdir(parents=True)
    (taken / "2026-10-14-101010.md").write_text("x")
    assert prepare_shell.gather(str(repo)).checkpoint_path.endswith("2026-10-14-101010-2.md")


def test_gather_turns_a_raising_step_into_a_problem_and_keeps_going(tmp_path, monkeypatch):
    def boom(root):
        raise RuntimeError("disk on fire")

    monkeypatch.setattr(prepare_shell, "plan_path", boom)
    facts = prepare_shell.gather(str(_git_repo(tmp_path)))
    assert facts.plan == ""
    assert any("plan lookup failed: RuntimeError: disk on fire" in p for p in facts.problems)
    assert facts.extensions


def test_gather_flags_a_missing_cwd(tmp_path):
    facts = prepare_shell.gather(str(tmp_path / "nope"))
    assert any("cwd is not a directory" in p for p in facts.problems)


@pytest.mark.skipif(os.geteuid() == 0, reason="root can read a mode 000 directory")
def test_gather_flags_an_unreadable_cwd(tmp_path):
    locked = tmp_path / "locked"
    locked.mkdir()
    locked.chmod(0)
    try:
        facts = prepare_shell.gather(str(locked))
    finally:
        locked.chmod(0o755)
    assert any("cwd is not readable" in p for p in facts.problems)


# ------------------------------------------------------------------------------------------ CLI


def test_build_with_bad_arguments_is_a_skeleton_with_a_fallback(capsys):
    text = prepare_cli.build(["--no-such-flag"])
    assert text.splitlines()[0] == "borg checkpoint-prepare v1"
    assert text.splitlines()[-1].startswith("STATUS: fallback: bad arguments:")
    assert capsys.readouterr().err == ""


def test_build_turns_a_crash_into_a_skeleton(monkeypatch):
    def boom(cwd, session):
        raise RuntimeError("kaput")

    monkeypatch.setattr(prepare_cli.prepare_shell, "gather", boom)
    assert prepare_cli.build([]).splitlines()[-1] == "STATUS: fallback: internal error: RuntimeError: kaput"


def test_build_passes_cwd_and_session_through(tmp_path, monkeypatch):
    seen = []

    def spy(cwd, session):
        seen.append((cwd, session))
        return prepare.Facts()

    monkeypatch.setattr(prepare_cli.prepare_shell, "gather", spy)
    prepare_cli.build(["--cwd", str(tmp_path), "--session", "abc"])
    assert seen == [(str(tmp_path), "abc")]


def test_main_writes_the_document_to_stdout_and_returns_zero(tmp_path, capsysbinary):
    assert prepare_cli.main(["--cwd", str(tmp_path)]) == 0
    assert capsysbinary.readouterr().out.startswith(b"borg checkpoint-prepare v1\n")


def test_main_returns_zero_on_a_closed_pipe(monkeypatch, tmp_path):
    class Closed:
        class buffer:  # noqa: N801 - mimics sys.stdout.buffer
            @staticmethod
            def write(data):
                raise BrokenPipeError

            @staticmethod
            def flush():
                raise BrokenPipeError

        @staticmethod
        def fileno():
            raise OSError("no fd")

    monkeypatch.setattr(prepare_cli.sys, "stdout", Closed)
    assert prepare_cli.main(["--cwd", str(tmp_path)]) == 0
