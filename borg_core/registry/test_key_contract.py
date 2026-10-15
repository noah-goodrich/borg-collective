"""The registry's `projects` -> `repositories` key rename, CONTRACT phase: the file uses only `repositories`,
the old key is no longer read (a `projects`-only file fails loudly, never reads as empty), a new file is born
with `repositories`, and `migrate-key` flips an old file idempotently. Temp files only."""

import json

import pytest

from borg_core import paths
from borg_core.manifest import shell as manifest_shell
from borg_core.recon import shell as recon_shell
from borg_core.registry import cli, core, shell

ENTRIES = {"alpha": {"path": "/a", "status": "idle"}, "beta": {"path": "/b"}}


@pytest.fixture()
def registry_file(tmp_path, monkeypatch):
    path = tmp_path / "registry.json"
    monkeypatch.setenv("BORG_REGISTRY", str(path))
    monkeypatch.delenv("BORG_DIR", raising=False)
    return path


def _write(path, doc):
    path.write_text(json.dumps(doc), encoding="utf-8")


def _backups(path):
    return sorted(path.parent.glob(f"{path.name}.bak.*"))


# ── the reader refuses the retired key ───────────────────────────────────────


def test_require_registry_key_passes_the_new_shape_and_non_objects_through():
    doc = {"repositories": ENTRIES, "extra": 1}
    assert paths.require_registry_key(doc) is doc
    assert paths.require_registry_key(["x"]) == ["x"]
    assert paths.require_registry_key(None) is None
    assert paths.require_registry_key({}) == {}


def test_require_registry_key_raises_on_a_projects_only_document():
    with pytest.raises(paths.LegacyRegistryKey, match="migrate-key"):
        paths.require_registry_key({"projects": ENTRIES}, "/x/registry.json")


def test_require_registry_key_reads_repositories_when_both_are_present():
    doc = {"projects": {"old": {}}, "repositories": ENTRIES}
    assert paths.require_registry_key(doc) is doc


def test_read_registry_of_a_projects_only_file_errors_and_is_not_empty(registry_file):
    _write(registry_file, {"projects": ENTRIES})
    with pytest.raises(ValueError, match="retired 'projects' key") as exc:
        shell.read_registry()
    assert "borg setup" in str(exc.value)
    assert json.loads(registry_file.read_text(encoding="utf-8")) == {"projects": ENTRIES}


def test_a_write_path_never_replaces_a_projects_only_file(registry_file):
    _write(registry_file, {"projects": ENTRIES})
    with pytest.raises(ValueError, match="retired 'projects' key"):
        shell.registry_merge("gamma", {"path": "/g"})
    assert json.loads(registry_file.read_text(encoding="utf-8")) == {"projects": ENTRIES}


def test_read_registry_reads_a_new_shape_file(registry_file):
    _write(registry_file, {"repositories": ENTRIES})
    assert shell.read_registry() == {"repositories": ENTRIES}


def test_recon_loader_refuses_a_projects_only_file_and_reads_the_new_one(registry_file):
    _write(registry_file, {"projects": ENTRIES})
    with pytest.raises(ValueError, match="retired 'projects' key"):
        recon_shell.load_registry_repositories(str(registry_file), None)
    _write(registry_file, {"repositories": ENTRIES})
    assert recon_shell.load_registry_repositories(str(registry_file), None) == ENTRIES


def test_manifest_sweep_warns_on_a_projects_only_registry():
    manifests, warnings = manifest_shell.discover_registered({"projects": ENTRIES})
    assert manifests == []
    assert len(warnings) == 1 and "retired 'projects' key" in warnings[0]


# ── the writer ───────────────────────────────────────────────────────────────


def test_writer_round_trips_repositories(registry_file):
    _write(registry_file, {"repositories": ENTRIES, "extra": 1})
    shell.registry_merge("gamma", {"path": "/g"})
    on_disk = json.loads(registry_file.read_text(encoding="utf-8"))
    assert "projects" not in on_disk
    assert set(on_disk["repositories"]) == {"alpha", "beta", "gamma"}
    assert on_disk["extra"] == 1
    shell.registry_remove("gamma")
    assert set(json.loads(registry_file.read_text(encoding="utf-8"))["repositories"]) == {"alpha", "beta"}


def test_a_new_registry_is_born_with_repositories(registry_file):
    shell.registry_merge("gamma", {"path": "/g"})
    on_disk = json.loads(registry_file.read_text(encoding="utf-8"))
    assert set(on_disk) == {"repositories"}
    assert set(on_disk["repositories"]) == {"gamma"}


def test_initializing_read_creates_repositories(registry_file):
    assert shell.read_registry() == {"repositories": {}}
    assert json.loads(registry_file.read_text(encoding="utf-8")) == {"repositories": {}}


# ── migrate-key ──────────────────────────────────────────────────────────────


def test_plan_key_migration_verdicts():
    assert core.plan_key_migration({"projects": ENTRIES, "x": 1})[0] == "migrate"
    assert core.plan_key_migration({"projects": 1, "repositories": 2}) == ("both", None)
    assert core.plan_key_migration({"repositories": ENTRIES}) == ("already", None)
    assert core.plan_key_migration({"other": 1}) == ("neither", None)
    assert core.plan_key_migration([1]) == ("invalid", None)


def test_plan_key_migration_keeps_key_order():
    _, renamed = core.plan_key_migration({"a": 1, "projects": ENTRIES, "z": 2})
    assert list(renamed) == ["a", "repositories", "z"]


def test_dry_run_reports_and_writes_nothing(registry_file, capsys):
    _write(registry_file, {"projects": ENTRIES})
    before = registry_file.read_bytes()
    _run(["migrate-key", "--dry-run"])
    assert "would rename" in capsys.readouterr().out
    assert registry_file.read_bytes() == before
    assert not _backups(registry_file)


def _run(argv):
    with pytest.raises(SystemExit) as exc:
        cli.main(argv)
    assert exc.value.code == 0


def test_real_run_renames_backs_up_and_second_run_is_a_noop(registry_file, capsys):
    _write(registry_file, {"projects": ENTRIES})
    original = registry_file.read_bytes()

    _run(["migrate-key"])
    assert "renamed" in capsys.readouterr().out
    assert json.loads(registry_file.read_text(encoding="utf-8")) == {"repositories": ENTRIES}
    backups = _backups(registry_file)
    assert len(backups) == 1
    assert backups[0].read_bytes() == original

    migrated = registry_file.read_bytes()
    _run(["migrate-key"])
    assert "already uses 'repositories'" in capsys.readouterr().out
    assert registry_file.read_bytes() == migrated
    assert _backups(registry_file) == backups


def test_both_keys_is_left_alone(registry_file, capsys):
    _write(registry_file, {"projects": {"a": {}}, "repositories": ENTRIES})
    before = registry_file.read_bytes()
    _run(["migrate-key"])
    assert "has both" in capsys.readouterr().out
    assert registry_file.read_bytes() == before
    assert not _backups(registry_file)


def test_neither_key_and_missing_file_do_nothing(registry_file, capsys):
    _run(["migrate-key"])
    assert "nothing to migrate" in capsys.readouterr().out
    assert not registry_file.exists()
    _write(registry_file, {"other": 1})
    _run(["migrate-key"])
    assert "neither" in capsys.readouterr().out


def test_non_object_and_corrupt_files_fail_loudly(registry_file):
    _write(registry_file, [1, 2])
    with pytest.raises(ValueError, match="not a JSON object"):
        shell.migrate_key(False)
    registry_file.write_text("{nope", encoding="utf-8")
    with pytest.raises(ValueError, match="not valid JSON"):
        shell.migrate_key(False)


def test_unknown_option_is_rejected(registry_file):
    _write(registry_file, {"projects": ENTRIES})
    with pytest.raises(SystemExit) as exc:
        cli.main(["migrate-key", "--bogus"])
    assert exc.value.code == 1
    assert not _backups(registry_file)
