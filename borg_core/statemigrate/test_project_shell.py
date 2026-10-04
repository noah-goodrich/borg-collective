"""project_cli against a fully sandboxed HOME / XDG dirs. Nothing here may touch the real machine."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from borg_core import paths
from borg_core.statemigrate import project_cli as cli


@pytest.fixture(name="box")
def _box(tmp_path, monkeypatch):
    for var, sub in (
        ("HOME", "home"),
        ("XDG_CONFIG_HOME", "config"),
        ("XDG_STATE_HOME", "state"),
        ("XDG_DATA_HOME", "data"),
    ):
        monkeypatch.setenv(var, str(tmp_path / sub))
    monkeypatch.delenv("BORG_DIR", raising=False)
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    (tmp_path / "config" / "borg").mkdir(parents=True)
    return tmp_path


def _registry(box: Path, projects: dict) -> None:
    (box / "config" / "borg" / "registry.json").write_text(json.dumps({"projects": projects}))


def _proj(box: Path, name: str, state: str | None = '{"status":"idle"}') -> Path:
    directory = box / "dev" / name
    (directory / ".borg").mkdir(parents=True)
    if state is not None:
        (directory / ".borg" / "state.json").write_text(state)
    return directory


def _git_init(directory: Path) -> str:
    subprocess.run(["git", "-C", str(directory), "init", "-q"], check=True)
    out = subprocess.run(
        ["git", "-C", str(directory), "rev-parse", "--path-format=absolute", "--git-common-dir"],
        capture_output=True,
        text=True,
        check=True,
    )
    return out.stdout.strip()


def _backups(box: Path) -> list[Path]:
    return list((box / "state" / "borg" / "tidy-backups").glob("*/projects/*/state.json"))


def test_copy_removes_legacy_and_empty_dir_and_backs_up(box, capsys):
    d = _proj(box, "a")
    _registry(box, {"a": {"path": str(d), "repo": None}})
    cli.main([])
    new = paths.project_state_file(d, None)
    assert json.loads(new.read_text()) == {"status": "idle"}
    assert not (d / ".borg").exists()
    assert _backups(box)
    capsys.readouterr()
    cli.main([])
    assert "nothing to migrate" in capsys.readouterr().out


def test_other_borg_contents_survive(box):
    d = _proj(box, "a")
    (d / ".borg" / "checkpoints").mkdir()
    (d / ".borg" / "checkpoints" / "c.md").write_text("x")
    _registry(box, {"a": {"path": str(d)}})
    cli.main([])
    assert not (d / ".borg" / "state.json").exists()
    assert (d / ".borg" / "checkpoints" / "c.md").read_text() == "x"


def test_keep_new_when_both_exist(box):
    d = _proj(box, "a", '{"v":"old"}')
    _registry(box, {"a": {"path": str(d)}})
    new = paths.project_state_file(d, None)
    new.parent.mkdir(parents=True)
    new.write_text('{"v":"new"}')
    cli.main([])
    assert json.loads(new.read_text()) == {"v": "new"}
    assert not (d / ".borg").exists()
    assert json.loads(_backups(box)[0].read_text()) == {"v": "old"}


def test_dry_run_touches_nothing(box, capsys):
    d = _proj(box, "a")
    _registry(box, {"a": {"path": str(d)}})
    cli.main(["--dry-run"])
    assert "would copy" in capsys.readouterr().out
    assert (d / ".borg" / "state.json").exists()
    assert not (box / "state").exists()


def test_refuses_git_backed_entry_without_repo(box, capsys):
    d = _proj(box, "a")
    _git_init(d)
    _registry(box, {"a": {"path": str(d), "repo": None}})
    with pytest.raises(SystemExit) as exc:
        cli.main([])
    assert exc.value.code == 2
    assert "backfill-repo" in capsys.readouterr().err
    assert (d / ".borg" / "state.json").exists()


def test_git_backed_with_repo_uses_registry_repo_key(box):
    d = _proj(box, "a")
    repo = _git_init(d)
    _registry(box, {"a": {"path": str(d), "repo": repo}})
    cli.main([])
    assert paths.project_state_file(d, repo).is_file()
    assert not paths.project_state_file(d, None).exists()


def test_tracked_legacy_is_copied_but_kept(box):
    d = _proj(box, "a")
    repo = _git_init(d)
    subprocess.run(["git", "-C", str(d), "add", "-f", ".borg/state.json"], check=True)
    _registry(box, {"a": {"path": str(d), "repo": repo}})
    cli.main([])
    assert paths.project_state_file(d, repo).is_file()
    assert (d / ".borg" / "state.json").exists()


def test_path_option_names_an_unregistered_file(box):
    d = _proj(box, "stray")
    _registry(box, {})
    cli.main(["--path", str(d / ".borg" / "state.json")])
    assert paths.project_state_file(d, None).is_file()
    assert not (d / ".borg").exists()


def test_corrupt_legacy_fails_and_is_kept(box):
    d = _proj(box, "a", "{broken")
    _registry(box, {"a": {"path": str(d)}})
    with pytest.raises(SystemExit) as exc:
        cli.main([])
    assert exc.value.code == 1
    assert (d / ".borg" / "state.json").exists()
