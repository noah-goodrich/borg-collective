#!/usr/bin/env python3
"""programs.py — borg-native program manifests, and the `declared` edges derived from them.

WHY THIS EXISTS. `gather.derive_stacked_edges` recovers `stacked` edges from branch topology, which
only ever links PRs **inside one repo** (a base branch is a repo-local name). The entire point of the
viz program is cross-*repo* chains, and those are not derivable from any mechanical signal: nothing in
git or the GitHub API says `platform#834` must merge before `warehouse#302`. That ordering exists only
in the head of whoever planned the program.

So it has to be *declared*. This module reads borg's own declaration of it.

THE SHAPE, and one deliberate divergence. The manifest mirrors the shape of a stacked-PR program —
`{program, apex, note, rows[]}` with `lane` + `order` per row — because that shape already expresses
what is needed: `order` is a declared merge sequence, and rows carry their own refs so a lane can span
repos. Three principles come with it: **declared, never derived**; `gate.kind` closed to
`decision`/`verification`; and **validate-everything-then-fail before writing anything**.

The divergence: **rows key on `ref`**, not `repo` + `number`. `ref` is already "the one canonical key
used everywhere" (SCHEMA.md) — `items[]`, `edges[]`, the actions map and the annotation join all key
off it. Keying rows the same way means derived edges need no ref normalization, which removes a whole
silent-failure class: a wrong `Owner/repo` -> `repo#num` transform yields edges whose endpoints match
no item, so they disappear from the graph without ever raising.

INDEPENDENCE. This reads borg's artifacts and nothing else. Manifests are discovered only under a
project's own `.borg/programs/`. No external plugin's file, schema, or path appears here or in the
fixtures; borg must work identically on a machine that has never heard of one.

WHAT IS NOT DERIVED HERE. `gate.blocked_by` is prose ("waiting on Kelly's review"), so it is never
string-matched into an edge — a blocker with no ref is correct input, not a defect, and guessing would
manufacture edges pointing at nothing. Those gates are counted and reported instead.
"""

from __future__ import annotations

import json
import os
import re
from typing import Any

# Closed vocabulary, deliberately. `decision` means a human must *choose*; `verification` means
# someone must *run* something. The distinction matters because a `verification` with declared
# outcomes is never a blocker on a *person* — anyone can run it — so it must not be routed to the
# awaiting-you tier the way a `decision` is.
GATE_KINDS = {"decision", "verification"}

# Rows whose `order` is one of these are merged pre-stack prerequisites: real ancestors of the chain
# with no declared position among themselves. They keep their file order (see _sort_key).
PREREQ_ORDERS = {"-", "–", "—", ""}

DEFAULT_LANE = "_default"


def _rows(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """The manifest's rows, or an empty list. Never raises on a malformed value."""
    rows = manifest.get("rows")
    return [r for r in rows if isinstance(r, dict)] if isinstance(rows, list) else []


def looks_like_manifest(doc: Any) -> bool:
    """Positive shape check, so discovery cannot mistake unrelated JSON for a manifest.

    Discovery globs a directory; a stray file that happens to live there must be skipped rather than
    half-parsed into edges. Requires a `rows` list specifically — the one field every manifest has and
    that arbitrary config JSON is unlikely to carry.
    """
    return isinstance(doc, dict) and isinstance(doc.get("rows"), list)


def _validate_apex(apex: Any) -> list[str]:
    """Problems with a manifest's optional apex. No apex at all is valid, not a problem.

    Core-rule exception: a program small enough to need no diagram and no gates legitimately has no
    tracker, and pointing at one that does not exist is worse than pointing at nothing.
    """
    if apex is None:
        return []
    if not isinstance(apex, dict):
        return ["apex: must be an object when present"]
    if not str(apex.get("ref") or "").strip():
        return ["apex: present but has no ref"]
    return []


def _validate_gate(gate: Any, label: str) -> list[str]:
    """Problems with one row's optional gate."""
    if gate is None:
        return []
    if not isinstance(gate, dict):
        return [f"{label}: gate must be an object"]

    errors = []
    kind = str(gate.get("kind") or "").strip()
    if kind not in GATE_KINDS:
        errors.append(
            f"{label}: gate.kind must be one of {sorted(GATE_KINDS)}, got {kind or '(empty)'}"
        )
    for field in ("blocked_by", "resolved_by"):
        if not str(gate.get(field) or "").strip():
            # A blocker with no pointer at its settlement is the defect this field exists to prevent:
            # it parks work for weeks while naming nothing that would unpark it.
            errors.append(f"{label}: gate.{field} is required")
    return errors


def validate(manifest: dict[str, Any]) -> list[str]:
    """Every problem with a manifest, in one pass. Empty list means valid.

    Reports ALL offending rows rather than stopping at the first, so a manifest is fixed in one edit
    instead of N runs. Callers must treat a non-empty result as fatal BEFORE writing anything —
    a malformed manifest that half-writes is worse than one that is rejected.
    """
    if not isinstance(manifest.get("rows"), list):
        return ["rows: missing or not a list"]

    errors = _validate_apex(manifest.get("apex"))
    seen: dict[str, int] = {}

    for i, row in enumerate(_rows(manifest)):
        label = f"rows[{i}]"
        ref = str(row.get("ref") or "").strip()
        if not ref:
            errors.append(f"{label}: missing ref")
        elif ref in seen:
            # A duplicated ref would produce two chain positions for one item and make the derived
            # edge set depend on iteration order.
            errors.append(f"{label}: duplicate ref {ref} (already at rows[{seen[ref]}])")
        else:
            seen[ref] = i

        if "order" not in row:
            errors.append(f"{label}: missing order")

        errors.extend(_validate_gate(row.get("gate"), label))

    return errors


def _sort_key(row: dict[str, Any], index: int) -> tuple[int, int, int]:
    """Sort rows within a lane by declared merge order.

    Prerequisites (`–`) come first in file order — a hand-authored list is itself a declaration, and
    they carry no number to sort on. Numbered rows follow, by the integer in `order`, which covers
    both lane-prefixed ids (`E1`, `I2`) and plain single-stack integers (`1`, `2`). A number that
    cannot be parsed falls back to file position rather than being dropped.
    """
    order = str(row.get("order") or "").strip()
    if order in PREREQ_ORDERS:
        return (0, index, index)
    match = re.search(r"(\d+)", order)
    return (1, int(match.group(1)) if match else index, index)


def lanes(manifest: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    """Rows grouped by lane and sorted into declared merge order within each lane.

    A manifest with no `lane` on any row is single-stack mode and yields one lane. Rows missing a ref
    are excluded — they cannot be an edge endpoint, and `validate` has already reported them.
    """
    grouped: dict[str, list[tuple[tuple[int, int, int], dict[str, Any]]]] = {}
    for i, row in enumerate(_rows(manifest)):
        if not str(row.get("ref") or "").strip():
            continue
        lane = str(row.get("lane") or "").strip() or DEFAULT_LANE
        grouped.setdefault(lane, []).append((_sort_key(row, i), row))
    return {lane: [r for _, r in sorted(rs, key=lambda p: p[0])] for lane, rs in sorted(grouped.items())}


def derive_edges(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """Declared edges from one manifest: `stacked` along each lane, `apex` to the tracker.

    Consecutive rows in a lane yield a `stacked` edge — that is what a declared merge order *means*,
    and it is the only construct here that can span repos, since each row names its own ref.

    An `apex` edge is emitted per row when the manifest has one. `apex` groups (SCHEMA.md: chain edges
    group, blocking edges do not), so it keeps a multi-lane program together as one workstream. A
    program with no apex — the small-single-ticket case — gets no apex edges rather than edges
    pointing at a tracker that does not exist.
    """
    by_lane = lanes(manifest)
    edges: list[dict[str, Any]] = []

    for rows in by_lane.values():
        for parent, child in zip(rows, rows[1:]):
            p, c = str(parent["ref"]).strip(), str(child["ref"]).strip()
            if p != c:
                edges.append({"parent": p, "child": c, "kind": "stacked", "source": "declared"})

    apex = manifest.get("apex")
    apex_ref = str(apex.get("ref") or "").strip() if isinstance(apex, dict) else ""
    if apex_ref:
        for rows in by_lane.values():
            for row in rows:
                ref = str(row["ref"]).strip()
                if ref != apex_ref:
                    edges.append(
                        {"parent": apex_ref, "child": ref, "kind": "apex", "source": "declared"}
                    )

    return sorted(edges, key=lambda e: (e["kind"], e["child"], e["parent"]))


def unmapped_gates(manifest: dict[str, Any]) -> list[dict[str, str]]:
    """Gates that state a blocker in prose, which is therefore not expressible as an edge.

    PM4. These are reported, never guessed at. "Waiting on Kelly's review" names a real blocker with
    no ref to point at; string-matching it into an edge would invent a dependency. Surfacing the count
    keeps them visible instead of silently absent from the graph.
    """
    out = []
    for row in _rows(manifest):
        gate = row.get("gate")
        if not isinstance(gate, dict):
            continue
        blocked_by = str(gate.get("blocked_by") or "").strip()
        if blocked_by:
            out.append(
                {
                    "ref": str(row.get("ref") or "").strip(),
                    "kind": str(gate.get("kind") or "").strip(),
                    "blocked_by": blocked_by,
                    "resolved_by": str(gate.get("resolved_by") or "").strip(),
                }
            )
    return sorted(out, key=lambda g: g["ref"])


def programs_dir(project_dir: str) -> str:
    """borg's one location for program manifests, alongside checkpoints and knowledge."""
    return os.path.join(project_dir, ".borg", "programs")


def discover(project_dirs: list[str]) -> tuple[list[dict[str, Any]], list[str]]:
    """Load every manifest under the given projects' `.borg/programs/`.

    Returns `(manifests, warnings)`. Takes explicit directories rather than reaching for the registry
    itself: the caller resolves registered project paths, keeping this core pure and testable with no
    shell or config dependency (Architecture Rules — "logic goes in a testable core").

    Nothing here is fatal. A missing directory, unreadable file, malformed JSON, non-manifest JSON, or
    invalid manifest is skipped with a NAMED warning — one bad file must never blank the spine, and an
    unnamed skip is indistinguishable from a file that was never there.
    """
    manifests: list[dict[str, Any]] = []
    warnings: list[str] = []

    for project_dir in project_dirs:
        directory = programs_dir(project_dir)
        try:
            names = sorted(n for n in os.listdir(directory) if n.endswith(".json"))
        except OSError:
            continue  # No programs for this project. The common case, not a problem.

        for name in names:
            path = os.path.join(directory, name)
            try:
                with open(path) as fh:
                    doc = json.load(fh)
            except (OSError, ValueError) as exc:
                warnings.append(f"{path}: unreadable or invalid JSON ({exc})")
                continue

            if not looks_like_manifest(doc):
                warnings.append(f"{path}: not a program manifest (no rows list) — skipped")
                continue

            errors = validate(doc)
            if errors:
                warnings.append(f"{path}: invalid manifest — {'; '.join(errors)}")
                continue

            doc.setdefault("program", os.path.splitext(name)[0])
            doc["_path"] = path
            manifests.append(doc)

    return manifests, warnings


def edges_from(manifests: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """All declared edges across manifests, deduplicated and byte-stable.

    Two programs naming the same dependency is normal, not an error, so identical edges collapse.
    """
    seen: dict[tuple[str, str, str], dict[str, Any]] = {}
    for manifest in manifests:
        for edge in derive_edges(manifest):
            seen.setdefault((edge["kind"], edge["parent"], edge["child"]), edge)
    return sorted(seen.values(), key=lambda e: (e["kind"], e["child"], e["parent"]))
