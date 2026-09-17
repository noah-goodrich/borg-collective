"""Oracles for reconcile's impure rungs: the resolvable-kind predicate and the manifest read.

The second arm of `test_dropping_in_a_jira_adapter_makes_the_SAME_ref_resolvable` is the one that
matters: it proves discovery is a PREDICATE rather than an allow-list, and it is the work machine's
future stated as a test rather than promised in prose.
"""

from __future__ import annotations

import ast
import json
from pathlib import Path

import pytest

from borg_core.reconcile import shell


@pytest.fixture()
def adapter_dir(tmp_path, monkeypatch):
    """An adapter search path holding only what a case plants."""
    d = tmp_path / "adapters"
    d.mkdir()
    monkeypatch.setenv("BORG_RECON_ADAPTER_PATH", str(d))
    return d


def _adapter(directory: Path, source: str) -> Path:
    """An EXECUTABLE named recon-adapter-<source>. The exec bit is load-bearing: discovery checks
    it, so a non-executable file is not an adapter and must not register a source."""
    p = directory / f"recon-adapter-{source}"
    p.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    p.chmod(0o755)
    return p


def _repo_with_rows(tmp_path, rows, stem="prog"):
    """A repository holding one VALID manifest.

    The rows must actually validate, and the first draft's did not: `o/r#one` is not a GitHub ref
    and the rows carried no `order`, so `discover()` rejected both files and returned nothing. The
    ambiguity assertion below then passed for the WRONG REASON — not because two manifests are
    ambiguous, but because zero were found. Caught only because a second, discriminating assertion
    in the same case failed.
    """
    programs = tmp_path / ".borg" / "programs"
    programs.mkdir(parents=True, exist_ok=True)
    (programs / f"{stem}.json").write_text(json.dumps({"program": stem, "rows": rows}),
                                           encoding="utf-8")
    return str(tmp_path)


# ── the predicate, and the arm that proves it is not an allow-list ───────────────────────────────

def test_only_a_discovered_adapter_makes_a_kind_resolvable(adapter_dir):
    assert shell.resolvable_kinds() == set()
    _adapter(adapter_dir, "github")
    assert shell.resolvable_kinds() == {"github"}


def test_dropping_in_a_jira_adapter_makes_the_SAME_ref_resolvable(adapter_dir):
    """THE ARM THAT PROVES A PREDICATE. The identical jira ref is unresolvable with only a github
    adapter present and resolvable once a jira adapter exists — with NO code change between the two
    assertions. That is the work machine's future: it gains jira by dropping in a file."""
    ref = "DE-2107"
    _adapter(adapter_dir, "github")
    assert shell.unresolvable_refs([{"ref": ref}]) == [ref]
    _adapter(adapter_dir, "jira")
    assert shell.unresolvable_refs([{"ref": ref}]) == []


def test_a_NON_executable_adapter_file_registers_nothing(adapter_dir):
    """Discovery checks the exec bit, so a plain file named like an adapter is not one. Without this
    case, `touch recon-adapter-jira` would appear to enable a source it cannot run."""
    (adapter_dir / "recon-adapter-jira").write_text("not executable", encoding="utf-8")
    assert shell.resolvable_kinds() == set()


def test_an_UNTRACKED_kind_never_becomes_resolvable_even_with_an_adapter(adapter_dir):
    """`link` is not in TRACKED_REF_KINDS — a URL is context a human attached, not work whose state
    anyone resolves. Planting `recon-adapter-link` must not change that, because the predicate is
    tracked-AND-discovered, not discovered alone."""
    _adapter(adapter_dir, "link")
    assert "link" not in shell.resolvable_kinds()
    assert shell.unresolvable_refs([{"ref": "https://x.test/a"}]) == ["https://x.test/a"]


def test_no_source_name_is_hardcoded_in_the_predicate():
    """Structural, not behavioural. The whole point is that no source string appears on the path, so
    a machine gains a source by adding a file. A literal "github" in this module would be the
    allow-list the design exists to avoid."""
    src = Path(shell.__file__).read_text(encoding="utf-8")
    code = "\n".join(
        line for line in src.splitlines()
        if not line.lstrip().startswith("#")
    )
    # Docstrings legitimately NAME the sources when explaining the rule, so strip them the same way
    # the AST purity checks do rather than grepping raw text — the lesson from the no-write test
    # that failed on its own docstring.
    tree = ast.parse(src)
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            code = code.replace(node.value, "")
    assert "github" not in code, "a source name is hardcoded on the predicate path"
    assert "jira" not in code


def test_unresolvable_refs_keeps_row_order_and_skips_junk():
    rows = [{"ref": "DE-1"}, "not a dict", {}, {"ref": ""}, {"ref": "DE-2"}]
    assert shell.unresolvable_refs(rows, {"github"}) == ["DE-1", "DE-2"]


# ── the manifest read ────────────────────────────────────────────────────────────────────────────

def test_rows_are_read_from_a_single_manifest(tmp_path):
    repo = _repo_with_rows(tmp_path, [{"ref": "o/r#1", "lane": "a", "order": "1"}])
    assert len(shell.manifest_rows(repo)) == 1


def test_the_fixture_actually_produces_a_DISCOVERABLE_manifest(tmp_path):
    """Guards the guard. If the fixture's rows stop validating, every case below reads `[]` and the
    ambiguity assertion passes vacuously — which is exactly what happened in the first draft."""
    repo = _repo_with_rows(tmp_path, [{"ref": "o/r#1", "lane": "a", "order": "1"}])
    assert shell.manifest_rows(repo), "fixture manifest is not discoverable — rows do not validate"


def test_several_manifests_without_a_name_is_ambiguous_and_reads_nothing(tmp_path):
    """Mirrors `manifest.cli resolve` rules 2 and 4 — never a guess — WITHOUT importing that CLI. A
    library reaching into a command-line module for a rule is the altitude mistake the
    recon-retirement gate was moved to avoid."""
    repo = _repo_with_rows(tmp_path, [{"ref": "o/r#1", "lane": "a", "order": "1"}], stem="one")
    _repo_with_rows(tmp_path, [{"ref": "o/r#2", "lane": "a", "order": "1"}], stem="two")
    assert shell.manifest_rows(repo) == []
    # Discriminates: naming one resolves it.
    assert len(shell.manifest_rows(repo, "one")) == 1


def test_a_missing_or_unreadable_manifest_reads_as_empty(tmp_path):
    assert shell.manifest_rows(str(tmp_path)) == []
    assert shell.manifest_rows(str(tmp_path / "absent")) == []


def test_shell_calls_no_write_verb():
    """The read half of a read-only feature. AST call graph, not text — the same check `test_core`
    carries, for the same reason."""
    tree = ast.parse(Path(shell.__file__).read_text(encoding="utf-8"))
    called = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            fn = node.func
            if isinstance(fn, ast.Name):
                called.add(fn.id)
            elif isinstance(fn, ast.Attribute):
                called.add(fn.attr)
    forbidden = {"open", "write", "write_text", "writelines", "mkdir", "dump",
                 "run", "Popen", "system", "unlink", "rename", "replace"}
    leaked = called & forbidden
    assert not leaked, f"shell.py calls a write/exec verb: {sorted(leaked)}"
