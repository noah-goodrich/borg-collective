"""PURE reconcile logic: manifest rows plus resolved states in, contradiction report out.

NO I/O OF ANY KIND -- no filesystem, no subprocess, no network, no clock. Callers hand this module
rows that someone else read and states that someone else resolved. `shell.py` owns every impure
rung, and `test_core.py` pins the purity by AST import walk rather than trusting the
clean-architecture linter, whose W9004 allow-list already permits `pathlib`, `json` and `datetime`.

THIS MODULE WRITES NOTHING, AND THAT IS THE DESIGN RATHER THAN A STAGE. A reconcile WRITER already
exists -- `merge-tree/coordinator.py::sync_borg` -- and is owned by
`docs/plans/directives/2026-08-31-retire-merge-tree-programs-into-borg-core.md`, whose recorded trap
is that repointing `discover` without changing `sync_borg` "permanently delete[s] rows ... exit 0".
So the writing half is AC7's work on a path with four known silent-dataloss routes, and the reporting
half needs none of it: the derived-vs-declared join is already built and already pure in
`borg_core/link/grid.py::resolve_state`, and `borg link` already sweeps adapters on every
invocation. What was missing is only the comparison and a place to say it.

A CONTRADICTION IS REPORTED, NEVER REPAIRED. Every function here returns findings; none proposes an
edit. That is the same altitude `recon/core.py::project_contradictions` chose for the checkpoint
case, and it is why this module cannot cause the dataloss the writer's directive describes.
"""

from __future__ import annotations

# Report kinds, most-actionable first. The order is the reporting order.
STALE_DECLARED = "stale_declared"
MERGED_DECISION_GATE = "merged_decision_gate"
UNRESOLVED = "unresolved"

KIND_ORDER = (STALE_DECLARED, MERGED_DECISION_GATE, UNRESOLVED)

# The state sources that count as a live answer. Mirrors `grid.RESOLVED_STATE_SOURCES` rather than
# re-deriving it: a swept adapter answer and a targeted fetch are both live, a declared field is the
# thing being checked, and unknown is the absence of an answer. Duplicated as a literal ONLY because
# importing `link.grid` here would make this module depend on the renderer to compare two strings.
RESOLVED_SOURCES = ("swept", "fetched")

# A gate kind whose whole purpose is to hold work back. A `decision` gate on an already-merged ref is
# the #158 class: the thing it was gating happened anyway, so either the gate is stale or the merge
# was premature. Both are facts a human needs; neither is something a machine should silently fix.
GATE_DECISION = "decision"

MERGED = "merged"


def _text(value: object) -> str:
    """A field as a stripped string. Non-strings become "" rather than their repr."""
    return value.strip() if isinstance(value, str) else ""


def row_finding(row: dict, resolved_state: str, state_source: str) -> dict | None:
    """The one finding this row yields, or None when declared and resolved agree.

    Three cases, and the ORDER OF THE CHECKS IS LOAD-BEARING:

    1. No live answer at all (`state_source` not in RESOLVED_SOURCES) -> `unresolved`. Checked FIRST,
       because with no live state there is nothing to contradict and every later comparison would be
       against a value that came from the manifest itself. Reporting a row as `stale_declared` by
       comparing its declared status to its own declared status is the self-refuting shape this
       repository keeps shipping.
    2. A `decision` gate on a ref that resolved merged -> `merged_decision_gate`, EVEN IF the
       declared status also says merged. The gate is the finding, not the status, so this cannot be
       folded into case 3.
    3. Declared status disagrees with the live one -> `stale_declared`.

    A row with no declared status is NOT a finding. Absence is not disagreement, and `state` is 0/24
    across this repository's manifests today, so treating absence as stale would report every row.
    """
    ref = _text(row.get("ref"))
    if not ref:
        return None

    if state_source not in RESOLVED_SOURCES:
        return {"kind": UNRESOLVED, "ref": ref,
                "detail": f"no live answer (source {state_source or 'unknown'})"}

    gate = row.get("gate")
    gate_kind = _text(gate.get("kind")) if isinstance(gate, dict) else ""
    if gate_kind == GATE_DECISION and resolved_state == MERGED:
        return {"kind": MERGED_DECISION_GATE, "ref": ref,
                "detail": f"a {GATE_DECISION} gate on a ref that resolved {MERGED}"}

    declared = _text(row.get("status"))
    if declared and declared != resolved_state:
        return {"kind": STALE_DECLARED, "ref": ref,
                "detail": f"declared {declared}, resolved {resolved_state} ({state_source})"}

    return None


def report(rows: list | None, resolved: dict | None) -> list:
    """Findings for a manifest's rows, most-actionable kind first.

    `resolved` maps ref -> `(state, state_source)`, which is exactly what
    `grid.resolve_state` returns per ref. A ref absent from `resolved` is treated as having no live
    answer, which routes it to `unresolved` rather than dropping it -- a row the resolver never
    reached is a fact, and silently omitting it is how a report comes to describe fewer rows than
    the manifest has.
    """
    findings = []
    for row in rows or []:
        if not isinstance(row, dict):
            continue
        state, source = (resolved or {}).get(_text(row.get("ref")), ("", ""))
        finding = row_finding(row, state, source)
        if finding:
            findings.append(finding)
    findings.sort(key=lambda f: (KIND_ORDER.index(f["kind"]) if f["kind"] in KIND_ORDER else 99,
                                 f["ref"]))
    return findings


def summary(findings: list | None) -> str:
    """One line per finding, most-actionable first. Empty string when nothing contradicts."""
    if not findings:
        return ""
    return "\n".join(f"{f['ref']} {f['kind']}: {f['detail']}" for f in findings or [])
