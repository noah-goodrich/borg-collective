"""Tests for the compass shell: real files under tmp_path, a fixed epoch, no private map content."""

from __future__ import annotations

import datetime
import json
import os
import subprocess
from pathlib import Path

import pytest

from borg_core import paths
from borg_core.compass import shell
from borg_core.link import cli
from borg_core.link import shell as link_shell

MOMENT = int(datetime.datetime(2026, 3, 10, 12, 0, 0).timestamp())
TODAY = "2026-03-10"


def _write(root: Path, relative: str, text: str) -> None:
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def _synthetic_map(root: Path) -> Path:
    _write(root, f"log/{TODAY}.md", "# Log\n\n## Today's leg\n\n- Wire up alpha reporting\n")
    _write(
        root,
        "destinations/alpha.md",
        "---\nid: alpha\ndomain: work\nstatus: active\ndefinition: approved\ntarget: 2026-03-15\n"
        "repositories:\n  - widgets\n---\n\n### W1 Build\n- status: active\n- [x] a\n- [ ] b\n",
    )
    _write(root, "destinations/broken.md", "no frontmatter at all\n")
    _write(root, "README.md", "| Destination | Due |\n|---|---|\n| alpha | 2026-03-15 |\n")
    _write(
        root, "parking-lot.md", "- [ ] revisit | parked: 2026-03-01 | look: 2026-03-10 | seen: 1 | last: 2026-03-05\n"
    )
    return root


def test_today_is_the_local_date_of_the_epoch():
    assert shell.today_from_epoch(MOMENT) == TODAY


def test_an_absent_directory_is_found_false_and_nothing_else(tmp_path):
    missing = tmp_path / "no-such-map"
    assert shell.read_compass(MOMENT, ["widgets"], missing) == {"found": False, "map_dir": str(missing)}


def test_a_path_that_is_a_file_not_a_directory_is_found_false(tmp_path):
    _write(tmp_path, "map", "i am a file")
    assert shell.read_compass(MOMENT, [], tmp_path / "map")["found"] is False


def test_an_empty_directory_has_no_map_in_it_so_it_is_found_false(tmp_path):
    assert shell.read_compass(MOMENT, ["widgets"], tmp_path) == {"found": False, "map_dir": str(tmp_path)}
    _write(tmp_path, "unrelated.txt", "not part of a map")
    assert shell.read_compass(MOMENT, ["widgets"], tmp_path)["found"] is False


@pytest.mark.parametrize("entry", ["log", "destinations"])
def test_any_one_map_entry_makes_the_directory_a_map(tmp_path, entry):
    (tmp_path / entry).mkdir()
    compass = shell.read_compass(MOMENT, ["widgets"], tmp_path)
    assert compass["found"] is True
    assert (compass["leg"], compass["destinations"], compass["parking"], compass["warnings"]) == (None, [], [], [])
    assert compass["repositories"] == {"widgets": {"destination": None, "on_leg": False}}


@pytest.mark.parametrize("entry", ["README.md", "parking-lot.md"])
def test_a_lone_readme_or_parking_lot_makes_the_directory_a_map(tmp_path, entry):
    _write(tmp_path, entry, "")
    assert shell.read_compass(MOMENT, [], tmp_path)["found"] is True


def test_a_synthetic_map_is_read_end_to_end_and_a_malformed_file_only_warns(tmp_path):
    compass = shell.read_compass(MOMENT, ["widgets", "other"], _synthetic_map(tmp_path))
    assert compass["today"] == TODAY
    assert compass["leg"] == {"text": "Wire up alpha reporting"}
    (alpha,) = compass["destinations"]
    assert (alpha["id"], alpha["due"], alpha["state"]) == ("alpha", "2026-03-15", "at-risk")
    assert alpha["next_waypoint"] == {"name": "Build", "status": "active", "done": 1, "total": 2}
    assert compass["parking"][0]["due"] is True
    assert compass["repositories"] == {
        "widgets": {"destination": "alpha", "on_leg": True},
        "other": {"destination": None, "on_leg": False},
    }
    assert [w.split(":")[0] for w in compass["warnings"]] == ["destinations/broken.md"]


def test_only_todays_log_is_read(tmp_path):
    _write(tmp_path, "log/2026-03-09.md", "## Today's leg\n- yesterday's leg\n")
    assert shell.read_compass(MOMENT, [], tmp_path)["leg"] is None


def test_non_markdown_files_in_destinations_are_ignored(tmp_path):
    _write(tmp_path, "destinations/notes.txt", "---\nid: x\nstatus: active\n---\n")
    assert shell.read_compass(MOMENT, [], tmp_path)["destinations"] == []


def test_an_unreadable_file_becomes_a_warning_and_is_otherwise_absent(tmp_path):
    (tmp_path / "destinations" / "dir.md").mkdir(parents=True)
    _write(tmp_path, "destinations/ok.md", "---\nid: ok\nstatus: frozen\n---\n")
    compass = shell.read_compass(MOMENT, [], tmp_path)
    assert [d["id"] for d in compass["destinations"]] == ["ok"]
    assert compass["warnings"][0].startswith("destinations/dir.md: unreadable")


def test_invalid_utf8_is_replaced_not_raised(tmp_path):
    (tmp_path / "README.md").write_bytes(b"| Destination | Due |\n|---|---|\n| alpha \xff | 2026-04-01 |\n")
    _write(tmp_path, "destinations/alpha.md", "---\nid: alpha\nstatus: active\n---\n")
    assert shell.read_compass(MOMENT, [], tmp_path)["destinations"][0]["due"] == "2026-04-01"


def test_the_reader_forks_nothing(tmp_path, monkeypatch):
    def refuse(*args, **kwargs):
        raise AssertionError(f"compass reader forked: {args!r} {kwargs!r}")

    monkeypatch.setattr(subprocess, "Popen", refuse)
    monkeypatch.setattr(subprocess, "run", refuse)
    monkeypatch.setattr(os, "system", refuse)
    assert shell.read_compass(MOMENT, ["widgets"], _synthetic_map(tmp_path))["found"] is True


# -- the map directory's resolution ------------------------------------------------------------------------------


def test_map_dir_honours_the_override(monkeypatch, tmp_path):
    monkeypatch.setenv("BORG_MAP_DIR", str(tmp_path / "elsewhere"))
    assert paths.map_dir() == tmp_path / "elsewhere"


@pytest.mark.parametrize("blank", [None, ""])
def test_map_dir_defaults_to_home_dev_map_when_unset_or_blank(monkeypatch, tmp_path, blank):
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    if blank is None:
        monkeypatch.delenv("BORG_MAP_DIR", raising=False)
    else:
        monkeypatch.setenv("BORG_MAP_DIR", blank)
    assert paths.map_dir() == tmp_path / "dev" / "map"


def test_read_compass_resolves_its_directory_from_the_environment_by_default(monkeypatch, tmp_path):
    monkeypatch.setenv("BORG_MAP_DIR", str(_synthetic_map(tmp_path / "m")))
    assert shell.read_compass(MOMENT, [])["found"] is True


# -- the wire ----------------------------------------------------------------------------------------------------


@pytest.fixture()
def wired(tmp_path, monkeypatch):
    borg_dir = tmp_path / "borg-dir"
    borg_dir.mkdir()
    workspace = tmp_path / "ws" / "widgets"
    workspace.mkdir(parents=True)
    (borg_dir / "registry.json").write_text(
        json.dumps({"projects": {"widgets": {"path": str(workspace)}}}), encoding="utf-8"
    )
    monkeypatch.setenv("BORG_DIR", str(borg_dir))
    for name in ("XDG_CONFIG_HOME", "BORG_REGISTRY", "BORG_NO_REAP", "BORG_ORCHESTRATOR_ROOT"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr(link_shell, "live_windows", lambda: [])
    monkeypatch.setattr(link_shell, "now_epoch", lambda: MOMENT)
    monkeypatch.setenv("BORG_ORCHESTRATOR_ROOT", str(tmp_path))
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_json_carries_compass_found_false_for_an_absent_map_and_stays_version_two(wired, monkeypatch):
    absent = wired / "no-map"
    monkeypatch.setenv("BORG_MAP_DIR", str(absent))
    document = cli._document("", False, "json", True)  # pylint: disable=protected-access
    assert document["version"] == 2
    assert document["compass"] == {"found": False, "map_dir": str(absent)}


def test_json_compass_names_the_documents_repositories_in_every_scope(wired, monkeypatch):
    monkeypatch.setenv("BORG_MAP_DIR", str(_synthetic_map(wired / "map")))
    queen = cli._document("", False, "json", True)  # pylint: disable=protected-access
    monkeypatch.chdir(wired / "ws" / "widgets")
    scoped = cli._document("", False, "json", True)  # pylint: disable=protected-access
    assert queen["scope"]["kind"] == "orchestrator"
    assert scoped["scope"]["kind"] == "repository"
    for document in (queen, scoped):
        assert document["compass"]["repositories"] == {"widgets": {"destination": "alpha", "on_leg": True}}


def _refusing_reader(monkeypatch):
    def refuse(*args, **kwargs):
        raise AssertionError("compass was read on a surface that does not carry it")

    monkeypatch.setattr(shell, "read_compass", refuse)


def test_porcelain_document_carries_no_compass_and_reads_no_map(wired, monkeypatch):
    monkeypatch.setenv("BORG_MAP_DIR", str(_synthetic_map(wired / "map")))
    _refusing_reader(monkeypatch)
    assert "compass" not in cli._document("", False, "porcelain", True)  # pylint: disable=protected-access


def test_human_document_carries_the_compass_the_page_renders(wired, monkeypatch):
    monkeypatch.setenv("BORG_MAP_DIR", str(_synthetic_map(wired / "map")))
    document = cli._document("", False, "human", True)  # pylint: disable=protected-access
    assert document["compass"]["found"] is True
    assert document["compass"]["leg"] == {"text": "Wire up alpha reporting"}


def test_the_hint_page_reads_no_map(wired, monkeypatch):
    monkeypatch.setenv("BORG_MAP_DIR", str(_synthetic_map(wired / "map")))
    _refusing_reader(monkeypatch)
    elsewhere = wired / "elsewhere"
    elsewhere.mkdir()
    monkeypatch.chdir(elsewhere)
    document = cli._document("", False, "human", True)  # pylint: disable=protected-access
    assert document["scope"]["unregistered"] is True
    assert "compass" not in document
