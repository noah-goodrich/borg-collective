"""Oracles for the pure reconcile core.

Every behaviour is pinned in the firing direction AND the direction proving it discriminates. The
defect this whole plan guards against is a report that looks informative while describing nothing.
"""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.reconcile import core


def _row(ref="o/r#1", status=None, gate=None, lane="a", order="1"):
    row = {"ref": ref, "lane": lane, "order": order}
    if status is not None:
        row["status"] = status
    if gate is not None:
        row["gate"] = gate
    return row


# ── purity ───────────────────────────────────────────────────────────────────────────────────────

def test_core_imports_nothing_impure():
    """The linter classifies by BASENAME and its W9004 allow-list permits `pathlib`, `json` and
    `datetime` — so it would wave a filesystem import into this module while `make lint` printed
    10.00/10. An exact root set is the narrower claim, and it catches the aliased spelling a name
    blacklist misses."""
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
    assert roots == {"__future__"}, f"core.py grew an impure import: {sorted(roots)}"


def test_core_calls_no_write_verb():
    """THIS MODULE WRITES NOTHING, and that is the design rather than a stage. Asserted structurally
    because "it currently happens not to write" and "it cannot write" read the same until someone
    adds a line. A reconcile writer already exists (`merge-tree/coordinator.py::sync_borg`) and is
    owned by AC7's retirement directive, whose recorded trap deletes rows at exit 0.

    CHECKED BY AST, NOT BY TEXT. The first version grepped the source for `subprocess`, `open(` and
    `os.` — and failed on this module's own DOCSTRING, which legitimately names those words while
    promising not to use them. A prose mention is not a call; only the call graph is evidence."""
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    called = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            fn = node.func
            if isinstance(fn, ast.Name):
                called.add(fn.id)
            elif isinstance(fn, ast.Attribute):
                called.add(fn.attr)
    forbidden = {"open", "write", "write_text", "writelines", "mkdir", "replace_file",
                 "dump", "run", "Popen", "system", "unlink", "rename"}
    leaked = called & forbidden
    assert not leaked, f"core.py calls a write/exec verb: {sorted(leaked)}"


# ── the three kinds, each discriminating ─────────────────────────────────────────────────────────

def test_agreement_is_not_a_finding():
    """The discriminating case for the whole module. A row whose declared status matches the live
    answer must produce NOTHING — a report that fires on agreement is noise, and noise is how a
    report stops being read."""
    assert core.report([_row(status="merged")], {"o/r#1": ("merged", "swept")}) == []
    assert core.summary([]) == ""


def test_a_stale_declared_status_is_reported():
    findings = core.report([_row(status="open")], {"o/r#1": ("merged", "swept")})
    assert [f["kind"] for f in findings] == [core.STALE_DECLARED]
    assert "declared open" in findings[0]["detail"]
    assert "resolved merged" in findings[0]["detail"]


def test_a_decision_gate_on_a_merged_ref_is_reported_even_when_the_status_AGREES():
    """The #158 class, and the reason it cannot fold into `stale_declared`. Here declared and
    resolved BOTH say merged, so there is no status disagreement at all — the gate is the finding.
    A check ordered the other way round would miss exactly this row."""
    findings = core.report([_row(status="merged", gate={"kind": "decision"})],
                           {"o/r#1": ("merged", "swept")})
    assert [f["kind"] for f in findings] == [core.MERGED_DECISION_GATE]


def test_a_decision_gate_on_an_UNMERGED_ref_is_not_a_finding():
    """Discriminates the case above: the gate alone is not the problem, the merge is."""
    assert core.report([_row(status="open", gate={"kind": "decision"})],
                       {"o/r#1": ("open", "swept")}) == []


def test_a_NON_decision_gate_on_a_merged_ref_is_not_the_158_class():
    """Only a `decision` gate. A `review` or `deploy` gate on a merged ref is ordinary."""
    findings = core.report([_row(status="merged", gate={"kind": "review"})],
                           {"o/r#1": ("merged", "swept")})
    assert findings == []


# ── the resolve-source guard, which is the self-refutation guard ─────────────────────────────────

def test_a_row_with_NO_live_answer_is_unresolved_not_stale():
    """ORDER IS LOAD-BEARING. With no live state there is nothing to contradict, and a
    `stale_declared` finding would be comparing the declared status against itself — the
    self-refuting shape ("no longer open (state OPEN)") this repository shipped two days ago."""
    for source in ("declared", "unknown", ""):
        findings = core.report([_row(status="open")], {"o/r#1": ("open", source)})
        assert [f["kind"] for f in findings] == [core.UNRESOLVED], source
        assert "declared open" not in findings[0]["detail"]


def test_a_ref_absent_from_the_resolver_is_reported_not_dropped():
    """A row the resolver never reached is a fact. Silently omitting it is how a report comes to
    describe fewer rows than the manifest has."""
    findings = core.report([_row(ref="o/r#7", status="open")], {})
    assert [f["kind"] for f in findings] == [core.UNRESOLVED]
    assert findings[0]["ref"] == "o/r#7"


def test_a_row_with_no_declared_status_is_not_stale():
    """Absence is not disagreement. `state` is 0/24 across this repository's manifests today, so
    treating a missing status as stale would report every row in every file."""
    assert core.report([_row(status=None)], {"o/r#1": ("merged", "swept")}) == []


# ── shape and ordering ───────────────────────────────────────────────────────────────────────────

def test_findings_sort_most_actionable_first():
    rows = [_row(ref="o/r#3", status=None),
            _row(ref="o/r#2", status="merged", gate={"kind": "decision"}),
            _row(ref="o/r#1", status="open")]
    resolved = {"o/r#1": ("merged", "swept"), "o/r#2": ("merged", "swept")}
    assert [f["kind"] for f in core.report(rows, resolved)] == [
        core.STALE_DECLARED, core.MERGED_DECISION_GATE, core.UNRESOLVED]


def test_malformed_input_is_skipped_not_fatal():
    """A manifest is data from disk; a non-dict row or a row with no ref must not crash a report."""
    assert core.report(None, None) == []
    assert core.report(["not a dict", None, {}, {"ref": ""}], {}) == []
