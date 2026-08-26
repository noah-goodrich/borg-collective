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


# ── AC2: the retirement gate lives at main(), not _run() (2026-08-26) ────────
# See docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md. All the tests above call
# `_run()` directly with json_only=False, adapters=False -- exercising the registry/adapter-discovery
# guards on purpose -- so a gate at main() cannot collide with any of them. These are the only cases
# in this file that call main() at all.


def test_main_bare_is_retired_and_names_borg_link(isolated_env):
    """`python3 -m borg_core.recon.cli` with no flags is the retired human digest path (AC2)."""
    with pytest.raises(SystemExit) as exc:
        cli.main([])
    assert exc.value.code != 0
    message = str(exc.value.code)
    assert "was retired" in message
    assert "borg link" in message


def test_main_json_reaches_the_engine_not_the_gate(isolated_env, capsys):
    """--json must NOT be retired -- it is the machine surface AC1 preserved (survival control).

    isolated_env's adapters dir is empty, so the engine's OWN "no recon adapters found" die is what
    a healthy --json invocation produces here -- and it is the proof the gate was cleared and the
    engine was reached at all, matching cli_contract.bats's "the recon MACHINE surface survives".
    """
    with pytest.raises(SystemExit) as exc:
        cli.main(["--json"])
    assert exc.value.code == 1
    err = capsys.readouterr().err
    assert "was retired" not in err
    assert "no recon adapters found" in err


def test_main_adapters_reaches_the_engine_not_the_gate(isolated_env, capsys):
    with pytest.raises(SystemExit) as exc:
        cli.main(["--adapters"])
    assert exc.value.code == 0
    out = capsys.readouterr().out
    assert "was retired" not in out
    assert "No recon adapters found" in out


def test_main_modifier_alone_does_not_open_the_gate(isolated_env):
    """--since/--sources/--projects are modifiers, not modes -- see the zsh sibling test in
    cli_contract.bats ("a recon modifier alone is not a machine flag") for why this needs its own
    case rather than trusting --json/--adapters coverage alone."""
    with pytest.raises(SystemExit) as exc:
        cli.main(["--sources", "github"])
    assert exc.value.code != 0
    assert "was retired" in str(exc.value.code)


def _item(project, ref, state="open", owner="agent", urgency="fyi", action_needed=False):
    return {
        "project": project,
        "source": "demo",
        "ref": ref,
        "title": ref,
        "state": state,
        "changed": "2025-01-01T00:00:00Z",
        "one_line": f"{ref} {state}",
        "owner": owner,
        "action_needed": action_needed,
        "urgency": urgency,
    }


def test_run_json_output_detects_contradiction_end_to_end(isolated_env, capsys):
    """AC1: drive _collect_contradictions through cli._run's real fan-out path, not a direct call.

    A checkpoint on disk lists PR-42 as a blocker; the adapter reports it resolved. Before this
    test, every existing test left by_project empty for every project, so the `if not items:
    continue` branch always fired and read_checkpoint_blockers()/project_contradictions() never
    ran (arc 48->50). This test forces a non-empty items list for a project that also has a real
    checkpoint on disk, so the full chain executes.
    """
    tmp, adapters_dir = isolated_env
    project_dir = tmp / "alpha"
    checkpoints_dir = project_dir / ".borg" / "checkpoints"
    checkpoints_dir.mkdir(parents=True)
    (checkpoints_dir / "2025-01-01-0000.md").write_text(
        "# Checkpoint\n\n## 4. Blockers\n- PR-42 still blocking release\n\n## 5. Next\n- n/a\n"
    )
    item = _item("alpha", "PR-42", state="resolved")
    _make_executable(
        adapters_dir / "recon-adapter-demo",
        f'#!/usr/bin/env bash\ncat <<\'JSON\'\n{{"source":"demo","summary":"ok","items":[{json.dumps(item)}]}}\nJSON\n',
    )

    exit_code = cli._run("2025-01-01T00:00:00Z", "", "", True, False)
    doc = json.loads(capsys.readouterr().out)

    assert exit_code == 0
    assert len(doc["contradictions"]) == 1
    contradiction = doc["contradictions"][0]
    assert contradiction["project"] == "alpha"
    assert contradiction["ref"] == "PR-42"
    assert "checkpoint" in contradiction["checkpoint_says"]
    assert "resolved" in contradiction["source_says"]


def test_run_projects_filter_excludes_other_projects_end_to_end(tmp_path, monkeypatch, capsys):
    """AC2: drive _filter_by_project through cli._run with an adapter that over-returns items.

    Before this test, every existing test passed keep_names=None/empty, so only the early-return
    path (`if not keep_names: return by_project`) ever ran; the actual filter (lines 61-62) was
    unverified. Here the registry only has 'alpha', but the adapter deliberately also emits an item
    for 'beta' (simulating an adapter that over-returns for other projects) to prove --projects is
    authoritative even over adapter output, not just registry scoping.
    """
    monkeypatch.setenv("BORG_DIR", str(tmp_path / "borg-dir"))
    monkeypatch.delenv("XDG_CONFIG_HOME", raising=False)
    monkeypatch.delenv("BORG_RECON_LIB_DIR", raising=False)
    adapters_dir = tmp_path / "adapters"
    adapters_dir.mkdir()
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(adapters_dir))
    registry = tmp_path / "registry.json"
    registry.write_text(
        json.dumps(
            {
                "projects": {
                    "alpha": {"path": str(tmp_path / "alpha")},
                    "beta": {"path": str(tmp_path / "beta")},
                }
            }
        )
    )
    monkeypatch.setenv("BORG_REGISTRY", str(registry))

    items = [_item("alpha", "PR-1"), _item("beta", "PR-2")]
    _make_executable(
        adapters_dir / "recon-adapter-demo",
        "#!/usr/bin/env bash\ncat <<'JSON'\n"
        + json.dumps({"source": "demo", "summary": "ok", "items": items})
        + "\nJSON\n",
    )

    exit_code = cli._run("2025-01-01T00:00:00Z", "", "alpha", True, False)
    doc = json.loads(capsys.readouterr().out)

    assert exit_code == 0
    assert "alpha" in doc["items_by_project"]
    assert "beta" not in doc["items_by_project"]
    assert [item["ref"] for item in doc["items_by_project"]["alpha"]] == ["PR-1"]
