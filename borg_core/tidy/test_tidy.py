"""Tests for the cairn-leftover cleanup: matching, dry-run, backup-before-delete, idempotence."""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core.tidy import cli, core, shell


def _seed(tmp_path: Path) -> tuple[Path, Path]:
    config, state = tmp_path / "config" / "borg", tmp_path / "state" / "borg"
    (state / "cairn-inbox").mkdir(parents=True)
    (state / "cairn-inbox" / "a.json").write_text("{}", encoding="utf-8")
    (state / ".cairn-last-write").write_text("1", encoding="utf-8")
    config.mkdir(parents=True)
    (config / "cairn-hits.log").write_text("hit\n", encoding="utf-8")
    (config / "registry.json").write_text("{}", encoding="utf-8")
    (config / "cairn-notes-by-operator.md").write_text("mine", encoding="utf-8")
    return config, state


def _run(config: Path, state: Path, *extra: str) -> None:
    cli.main(["cairn-leftovers", "--config-root", str(config), "--state-root", str(state), *extra])


def test_matching_is_by_exact_name_not_glob() -> None:
    assert core.is_cairn_leftover("cairn-hits.log")
    assert core.is_cairn_leftover(".cairn-write-failed")
    assert not core.is_cairn_leftover("cairn-notes-by-operator.md")
    assert not core.is_cairn_leftover("registry.json")


def test_dry_run_changes_nothing(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    config, state = _seed(tmp_path)
    _run(config, state, "--dry-run")
    assert (config / "cairn-hits.log").exists() and (state / "cairn-inbox").is_dir()
    assert not (state / "tidy-backups").exists()
    assert "would remove" in capsys.readouterr().out


def test_real_run_backs_up_then_deletes_only_the_known_names(tmp_path: Path) -> None:
    config, state = _seed(tmp_path)
    _run(config, state)
    assert not (config / "cairn-hits.log").exists()
    assert not (state / "cairn-inbox").exists() and not (state / ".cairn-last-write").exists()
    assert (config / "registry.json").exists() and (config / "cairn-notes-by-operator.md").exists()
    (backup,) = list((state / "tidy-backups").iterdir())
    assert (backup / "config" / "cairn-hits.log").read_text(encoding="utf-8") == "hit\n"
    assert (backup / "state" / "cairn-inbox" / "a.json").read_text(encoding="utf-8") == "{}"


def test_backup_name_does_not_trip_the_cairn_verify(tmp_path: Path) -> None:
    config, state = _seed(tmp_path)
    _run(config, state)
    assert not [p for p in state.iterdir() if "cairn" in p.name]


def test_second_run_is_a_noop_and_writes_no_backup(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    config, state = _seed(tmp_path)
    _run(config, state)
    before = sorted((state / "tidy-backups").iterdir())
    capsys.readouterr()
    _run(config, state)
    assert sorted((state / "tidy-backups").iterdir()) == before
    assert "nothing to clean" in capsys.readouterr().out


def test_delete_is_skipped_when_the_backup_fails(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    config, state = _seed(tmp_path)

    def boom(*_args: object, **_kw: object) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(shell, "back_up", boom)
    with pytest.raises(OSError):
        _run(config, state)
    assert (config / "cairn-hits.log").exists() and (state / "cairn-inbox").is_dir()


def test_missing_roots_are_tolerated(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    _run(tmp_path / "nope", tmp_path / "nada")
    assert "nothing to clean" in capsys.readouterr().out


def test_symlink_leftover_is_unlinked_not_followed(tmp_path: Path) -> None:
    config, state = tmp_path / "c", tmp_path / "s"
    config.mkdir()
    state.mkdir()
    target = tmp_path / "precious"
    target.mkdir()
    (target / "keep.txt").write_text("keep", encoding="utf-8")
    (config / "cairn-inbox").symlink_to(target)
    _run(config, state)
    assert not (config / "cairn-inbox").exists(follow_symlinks=False)
    assert (target / "keep.txt").exists()
