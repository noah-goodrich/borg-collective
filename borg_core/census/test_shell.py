"""Tests for the census's I/O: discovery, table parsing, and reader resolution."""

from borg_core.census import shell


def _tree(root, *, code="", docs="", census=""):
    (root / "lib").mkdir(parents=True, exist_ok=True)
    (root / "docs").mkdir(parents=True, exist_ok=True)
    (root / "lib" / "reader.sh").write_text(code, encoding="utf-8")
    (root / "CLAUDE.md").write_text(docs, encoding="utf-8")
    (root / "docs" / "state-census.md").write_text(census, encoding="utf-8")
    return root


def test_discover_separates_code_from_docs(tmp_path):
    _tree(tmp_path, code="reads .borg/widgets\n", docs="names .borg/lore\n")
    found = shell.discover(tmp_path)
    assert found[".borg/widgets"] == {"code"}
    assert found[".borg/lore"] == {"docs"}


def test_discover_records_both_surfaces_for_one_token(tmp_path):
    _tree(tmp_path, code=".borg/both\n", docs=".borg/both\n")
    assert shell.discover(tmp_path)[".borg/both"] == {"code", "docs"}


def test_discover_ignores_the_gates_own_package(tmp_path):
    # The precedent is prose_contracts.bats excluding lib/promote-next.sh by path: this package's
    # prose must be free to name the stores it governs without reporting itself as the defect.
    census_pkg = tmp_path / "borg_core" / "census"
    census_pkg.mkdir(parents=True)
    (census_pkg / "core.py").write_text("# explains .borg/knowledge at length\n", encoding="utf-8")
    _tree(tmp_path)
    assert ".borg/knowledge" not in shell.discover(tmp_path)


def test_discover_ignores_docs_other_than_claude_md(tmp_path):
    # A directive or a retro that DESCRIBES a retired store is history, not a live promise. Treating
    # docs/ as a reference surface would make every retirement fail the gate that performed it.
    _tree(tmp_path)
    (tmp_path / "docs" / "some-retro.md").write_text(".borg/ancient\n", encoding="utf-8")
    assert ".borg/ancient" not in shell.discover(tmp_path)


def test_declared_parses_the_markdown_table(tmp_path):
    table = (
        "| store | kind | reader | note |\n| --- | --- | --- | --- |\n"
        "| `.borg/widgets` | store | `lib/reader.sh` | here |\n"
        "| `.borg/lore` | retired | - | gone |\n"
    )
    _tree(tmp_path, census=table)
    rows = shell.declared(tmp_path / "docs" / "state-census.md")
    assert rows[".borg/widgets"] == {"kind": "store", "reader": "lib/reader.sh"}
    assert rows[".borg/lore"]["kind"] == "retired"


def test_declared_is_empty_when_the_census_file_is_missing(tmp_path):
    assert shell.declared(tmp_path / "docs" / "nope.md") == {}


def test_reader_mentions_is_true_only_when_the_file_names_the_store(tmp_path):
    _tree(tmp_path, code="reads .borg/widgets\n")
    rows = {
        ".borg/widgets": {"kind": "store", "reader": "lib/reader.sh"},
        ".borg/absent": {"kind": "store", "reader": "lib/reader.sh"},
        ".borg/gone": {"kind": "store", "reader": "lib/missing.sh"},
    }
    mentions = shell.reader_mentions(tmp_path, rows)
    assert mentions[".borg/widgets"] is True
    assert mentions[".borg/absent"] is False
    assert mentions[".borg/gone"] is False


def test_discover_scans_agent_and_skill_prose_not_just_claude_md(tmp_path):
    # THE REAL MISS: agents/borg-nanoprobe.md told every nanoprobe to treat `.borg/knowledge/` as
    # "authoritative prior art" while CLAUDE.md's weaker promise was being retired in the same
    # change. A gate reading one rules file leaves the others carrying the promise it just removed.
    _tree(tmp_path)
    (tmp_path / "agents").mkdir()
    (tmp_path / "agents" / "worker.md").write_text("prefer .borg/lore\n", encoding="utf-8")
    (tmp_path / "skills" / "s").mkdir(parents=True)
    (tmp_path / "skills" / "s" / "SKILL.md").write_text("writes .borg/notes\n", encoding="utf-8")
    found = shell.discover(tmp_path)
    assert found[".borg/lore"] == {"docs"}
    assert found[".borg/notes"] == {"docs"}


def test_reader_exists_is_asked_separately_from_reader_mentions(tmp_path):
    _tree(tmp_path, code="reads nothing in particular\n")
    rows = {
        ".borg/here": {"kind": "dynamic", "reader": "lib/reader.sh"},
        ".borg/gone": {"kind": "dynamic", "reader": "lib/missing.sh"},
    }
    exists = shell.reader_exists(tmp_path, rows)
    mentions = shell.reader_mentions(tmp_path, rows)
    assert exists[".borg/here"] is True and exists[".borg/gone"] is False
    # The file exists but does not mention the store -- which is the whole point of `dynamic`.
    assert mentions[".borg/here"] is False
