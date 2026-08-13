"""Tests for borg_core.recon.cli — the dispatch layer (arg parsing, --json, output shape)."""

import json
import stat

import pytest

from borg_core.recon import cli


def _make_executable(path, content):
    path.write_text(content)
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


@pytest.fixture()
def isolated_env(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_DIR", str(tmp_path / "borg-dir"))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_RECON_LIB_DIR", raising=False)
    adapters_dir = tmp_path / "adapters"
    adapters_dir.mkdir()
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters_dir))
    registry = tmp_path / "registry.json"
    registry.write_text(json.dumps({"projects": {"alpha": {"path": str(tmp_path / "alpha")}}}))
    monkeypatch.setenv("BORG_REGISTRY", str(registry))
    return tmp_path, adapters_dir


def test_run_list_adapters_none_found(isolated_env, capsys):
    exit_code = cli._run("", "", "", False, True)
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "No recon adapters found" in out


def test_run_list_adapters_found(isolated_env, capsys):
    _tmp, adapters_dir = isolated_env
    _make_executable(adapters_dir / "recon-adapter-demo", "#!/usr/bin/env bash\necho hi\n")
    exit_code = cli._run("", "", "", False, True)
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "demo" in out


def test_run_missing_registry_dies(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("BORG_REGISTRY", str(tmp_path / "nope.json"))
    with pytest.raises(SystemExit):
        cli._run("", "", "", False, False)


def test_run_resolves_registry_from_borg_dir_when_env_override_absent(tmp_path, monkeypatch, capsys):
    """With no BORG_REGISTRY in the environment the registry must still resolve from BORG_DIR.

    This is the exact condition every real `borg recon` invocation runs under: borg.zsh assigns
    BORG_REGISTRY as a shell variable without `export`, so the child process never received it and
    recon died with "no registry at " before doing anything. Dying LATER, at adapter discovery, is
    the proof that the registry check passed.
    """
    borg_dir = tmp_path / "borg-dir"
    borg_dir.mkdir()
    (borg_dir / "registry.json").write_text(json.dumps({"projects": {}}))
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    monkeypatch.delenv("BORG_REGISTRY", raising=False)
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(tmp_path / "no-adapters-here"))

    with pytest.raises(SystemExit):
        cli._run("", "", "", False, False)

    err = capsys.readouterr().err
    assert "no registry at" not in err
    assert "no recon adapters found" in err


def test_run_no_adapters_dies(isolated_env):
    with pytest.raises(SystemExit):
        cli._run("", "", "", False, False)


def test_run_sources_filter_matches_nothing_dies(isolated_env):
    _tmp, adapters_dir = isolated_env
    _make_executable(adapters_dir / "recon-adapter-demo", "#!/usr/bin/env bash\necho hi\n")
    with pytest.raises(SystemExit):
        cli._run("", "nonexistent-source", "", False, False)


def test_run_json_output(isolated_env, capsys):
    _tmp, adapters_dir = isolated_env
    _make_executable(
        adapters_dir / "recon-adapter-demo",
        '#!/usr/bin/env bash\ncat <<\'JSON\'\n{"source":"demo","summary":"ok","items":[]}\nJSON\n',
    )
    exit_code = cli._run("2025-01-01T00:00:00Z", "", "", True, False)
    out = capsys.readouterr().out
    assert exit_code == 0
    doc = json.loads(out)
    assert doc["since"] == "2025-01-01T00:00:00Z"


def test_run_digest_output(isolated_env, capsys):
    _tmp, adapters_dir = isolated_env
    _make_executable(
        adapters_dir / "recon-adapter-demo",
        '#!/usr/bin/env bash\ncat <<\'JSON\'\n{"source":"demo","summary":"ok","items":[]}\nJSON\n',
    )
    exit_code = cli._run("2025-01-01T00:00:00Z", "", "", False, False)
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "Recon sweep" in out


def test_die_writes_to_stderr_and_exits(capsys):
    with pytest.raises(SystemExit) as exc:
        cli._die("boom")
    assert exc.value.code == 1
    assert "boom" in capsys.readouterr().err
