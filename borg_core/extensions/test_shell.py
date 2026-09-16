"""Oracles for the impure rungs: discovery, probing, and the absence contract."""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core.extensions import core, shell


PREFER = (
    "- Prefer-tool: `dev-workflow:create-pr`\n"
    "- Instead-of: `gh pr create`\n"
    "- Requires: command:definitely-not-a-real-binary-xyz\n"
    "\nDelegate PR creation.\n"
)


@pytest.fixture()
def machine(tmp_path, monkeypatch):
    """A sandboxed machine layer. `borg_dir()` is resolved through `paths`, so this monkeypatches
    the environment the wrapper is supposed to export rather than the function -- the zsh->Python
    boundary loses unexported shell variables, and a test that supplies what production derives
    proves nothing about production."""
    cfg = tmp_path / "config"
    monkeypatch.setenv("XDG_CONFIG_HOME", str(cfg))
    monkeypatch.setenv("BORG_DIR", str(cfg / "borg"))
    return cfg / "borg"


def _write(base: Path, kind: str, name: str, hook: str, text: str) -> Path:
    path = base / kind / name / f"{hook}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def test_both_layer_paths_are_offered(tmp_path, machine):
    paths = shell.layer_paths("skill-extensions", "borg-plan", "01-context", str(tmp_path))
    assert paths[core.MACHINE].endswith("extensions/skill-extensions/borg-plan/01-context.md")
    assert paths[core.REPOSITORY].endswith(".borg/skill-extensions/borg-plan/01-context.md")


def test_a_missing_extension_is_absent_not_an_error(tmp_path, machine):
    assert shell.read_layers("skill-extensions", "nope", "01-context", str(tmp_path)) == {}


def test_each_layer_is_read_independently(tmp_path, machine):
    _write(machine / "extensions", "skill-extensions", "borg-plan", "01-context", "machine prose")
    layers = shell.read_layers("skill-extensions", "borg-plan", "01-context", str(tmp_path))
    assert set(layers) == {core.MACHINE}
    _write(tmp_path / ".borg", "skill-extensions", "borg-plan", "01-context", "repo prose")
    layers = shell.read_layers("skill-extensions", "borg-plan", "01-context", str(tmp_path))
    assert set(layers) == {core.MACHINE, core.REPOSITORY}


def test_probe_command_both_directions():
    """`sh` exists on every platform this runs on; the xyz name does not. Both directions, because a
    probe that only ever returns one answer is the defect being guarded against."""
    assert shell.probe({"requires": "command:sh"}) is True
    assert shell.probe({"requires": "command:definitely-not-a-real-binary-xyz"}) is False


def test_probe_returns_None_when_there_is_nothing_to_probe():
    """None is not failure -- conflating it with False would call a good prose extension dead."""
    assert shell.probe({}) is None
    assert shell.probe({"requires": "garbage"}) is None


def test_survey_reports_a_DEAD_preference_rather_than_hiding_it(tmp_path, machine):
    """The absence contract. A preference whose requirement is unmet must appear, and must appear as
    dead -- a silently-inert preference reads as working, which is worse than having none."""
    _write(machine / "extensions", "skill-extensions", "borg-assimilate", "02-output", PREFER)
    rows = shell.survey(str(tmp_path))
    assert len(rows) == 1
    assert rows[0]["status"] == "dead"
    assert rows[0]["layer"] == core.MACHINE
    assert rows[0]["prefer"] == "dev-workflow:create-pr"


def test_survey_reports_a_LIVE_preference(tmp_path, machine):
    _write(machine / "extensions", "skill-extensions", "borg-assimilate", "02-output",
           PREFER.replace("definitely-not-a-real-binary-xyz", "sh"))
    rows = shell.survey(str(tmp_path))
    assert [r["status"] for r in rows] == ["live"]


def test_survey_ignores_prose_extensions(tmp_path, machine):
    """Prose extensions are not graded and must not clutter `borg doctor`."""
    _write(machine / "extensions", "skill-extensions", "borg-plan", "01-context", "just prose")
    assert shell.survey(str(tmp_path)) == []


def test_survey_finds_the_agent_layer_and_its_brief_hook(tmp_path, machine):
    """`borg-nanoprobe` is an AGENT: no phases, one load point. Its extensions live under a
    different noun so the two kinds cannot be confused."""
    _write(machine / "extensions", "agent-extensions", "borg-nanoprobe", "brief",
           PREFER.replace("definitely-not-a-real-binary-xyz", "sh"))
    rows = shell.survey(str(tmp_path))
    assert [(r["kind"], r["hook"]) for r in rows] == [("agent-extensions", "brief")]


def test_the_machine_layer_wins_a_prefer_tool_conflict_on_disk(tmp_path, machine):
    """The precedence rule, exercised through real files rather than hand-built dicts."""
    _write(machine / "extensions", "skill-extensions", "borg-assimilate", "02-output",
           PREFER.replace("definitely-not-a-real-binary-xyz", "sh"))
    _write(tmp_path / ".borg", "skill-extensions", "borg-assimilate", "02-output",
           "- Prefer-tool: `gh`\n- Requires: command:sh\n")
    rows = shell.survey(str(tmp_path))
    assert len(rows) == 1
    assert rows[0]["layer"] == core.MACHINE
    assert rows[0]["prefer"] == "dev-workflow:create-pr"
    assert rows[0]["conflicted"] is True


def test_repo_root_finds_the_git_root_and_falls_back(tmp_path):
    (tmp_path / ".git").mkdir()
    nested = tmp_path / "a" / "b"
    nested.mkdir(parents=True)
    assert shell.repo_root(str(nested)) == str(tmp_path.resolve())
    bare = tmp_path.parent / "no-git-here"
    bare.mkdir(exist_ok=True)
    assert shell.repo_root(str(bare)) == str(bare.resolve())
