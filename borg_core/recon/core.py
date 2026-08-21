"""Pure logic for the recon fan-out engine (ports lib/recon.sh).

This module is UNCONDITIONALLY free of raw I/O: no subprocess, no file open(), no network, no
environment reads. Every function here takes already-gathered data as arguments and returns plain
data structures or strings. All I/O (filesystem walks, subprocess calls, environment lookups) lives
in shell.py, which calls into this module for the actual logic.

Mirrors lib/recon.sh's Recon Contract v0:
  Item = {project, source, ref, title, state, changed, owner, action_needed, urgency, one_line}
  Track = {source, summary, items, ok, dropped}
"""

from __future__ import annotations

import json
import re
from typing import Any

from borg_core import timefmt

VALID_OWNERS = {"you", "agent", "unknown"}
VALID_URGENCIES = {"now", "this_week", "fyi"}
REQUIRED_ITEM_STRING_FIELDS = ("project", "source", "ref", "title", "state", "changed", "one_line")

_RESOLVED_STATE_RE = re.compile(r"resolv|close|merg|done|fixed|shipped|complete", re.IGNORECASE)

# Re-exported: mirrors _recon_epoch_to_iso. The same shape as borg_core.link.core.format_iso and a
# recon/cli.py inline; see borg_core/timefmt.py's module docstring for why the third copy was
# consolidated there instead of re-derived here.
epoch_to_iso = timefmt.epoch_to_iso


def resolve_since(
    explicit_since: str,
    checkpoint_epoch: int | None,
    marker_value: str | None,
    fallback_epoch: int,
) -> str:
    """Resolve the `since` marker. Precedence mirrors _recon_resolve_since:

    1. explicit ISO ts (if non-empty)
    2. newest .borg checkpoint mtime (already resolved to an epoch by the caller)
    3. the last-run marker value (already read + trimmed by the caller)
    4. fallback epoch (caller computes "24h ago" or similar)
    """
    if explicit_since:
        return explicit_since
    if checkpoint_epoch is not None:
        return epoch_to_iso(checkpoint_epoch)
    if marker_value:
        return marker_value
    return epoch_to_iso(fallback_epoch)


def dedup_adapters(candidates: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Dedup discovered adapter candidates by source name, first-on-path wins.

    Args:
        candidates: ordered list of (source, absolute_path) tuples, in search-path order
            (already filtered to executable files by the caller).

    Mirrors _recon_discover_adapters's dedup pass.
    """
    seen: set[str] = set()
    result: list[tuple[str, str]] = []
    for source, path in candidates:
        if source in seen:
            continue
        seen.add(source)
        result.append((source, path))
    return result


def validate_track(track: Any) -> bool:
    """Validate a track object: {"source": str, "summary": str, "items": list}."""
    if not isinstance(track, dict):
        return False
    return (
        isinstance(track.get("source"), str)
        and isinstance(track.get("summary"), str)
        and isinstance(track.get("items"), list)
    )


def validate_item(item: Any) -> bool:
    """Validate one Item against the v0 schema (required fields + enum constraints)."""
    if not isinstance(item, dict):
        return False
    for field in REQUIRED_ITEM_STRING_FIELDS:
        if not isinstance(item.get(field), str):
            return False
    if item.get("owner") not in VALID_OWNERS:
        return False
    if not isinstance(item.get("action_needed"), bool):
        return False
    if item.get("urgency") not in VALID_URGENCIES:
        return False
    return True


def build_failed_track(source: str, rc: int | str) -> dict:
    """Synthetic failed-track object, mirrors the failure path of _recon_run_adapter."""
    return {
        "source": source,
        "summary": f"track failed (rc={rc}) or emitted malformed output",
        "items": [],
        "ok": False,
    }


def build_postprocess_failed_track(source: str) -> dict:
    """Synthetic failed-track object for a post-processing (jq-equivalent) failure."""
    return {"source": source, "summary": "post-processing failed", "items": [], "ok": False}


def normalize_track(track: dict) -> dict:
    """Filter a validated track's items to schema-valid ones, counting drops.

    Mirrors the jq post-processing step in _recon_run_adapter: keep only schema-valid items,
    tag ok=true, and record how many items were dropped.
    """
    items = track.get("items", [])
    valid_items = [item for item in items if validate_item(item)]
    dropped = len(items) - len(valid_items)
    result = dict(track)
    result["ok"] = True
    result["dropped"] = dropped
    result["items"] = valid_items
    return result


def process_adapter_output(source: str, raw: str | None, rc: int) -> dict:
    """Turn one adapter's raw subprocess output into a normalized track object.

    Mirrors _recon_run_adapter's decision tree end to end, minus the actual subprocess call
    (the caller/shell.py supplies raw stdout + return code).
    """
    if rc != 0 or not raw:
        return build_failed_track(source, rc)
    try:
        parsed = json.loads(raw)
    except (ValueError, TypeError):
        return build_failed_track(source, rc)
    if not validate_track(parsed):
        return build_failed_track(source, rc)
    try:
        return normalize_track(parsed)
    except (TypeError, KeyError):
        return build_postprocess_failed_track(source)


_ISO_TS = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")


def _changed_ts(item: dict) -> str:
    """The first ISO-8601 timestamp inside an item's prose `changed` field, or "" (sorts oldest)."""
    match = _ISO_TS.search(str(item.get("changed") or ""))
    return match.group(0) if match else ""


def dedup_cross_source(tracks: list[dict]) -> tuple[list[dict], list[dict]]:
    """Drop cross-source duplicates of the same ref before the project merge.

    Two sources reporting the same ref are the same artifact reported twice — both flowing through
    inflates every downstream count (measured 2026-08-21: one PR rendered twice inside a single
    spine workstream the day a second adapter existed). Identity here is the IDENTICAL ref string
    only; linking a Jira `PROJ-123` to the `org/repo#45` it tracks is entity resolution and stays
    out of scope.

    The newest `changed` wins. `changed` is PROSE by contract (the github adapter emits
    "updated <ISO>; state=..."), so the comparison extracts the first ISO-8601 timestamp from the
    string — comparing the raw prose lexically would make the winner depend on each source's phrasing
    prefix, not on time. Extracted timestamps compare lexically (ISO sorts); an item with no
    timestamp in `changed` compares as oldest. Ties keep the first track's item, and track order is
    adapter discovery order, so the outcome is deterministic. Each track records how many of its
    items lost as `deduped`. When the winner and a loser disagree on `state`, that is a real
    contradiction between sources — emitted for the human, never resolved silently, same policy as
    the checkpoint-vs-source detector.

    Returns `(tracks, contradictions)` with each track's `items` filtered and `deduped` set.
    """
    winners: dict[str, dict] = {}
    for track in tracks:
        for item in track.get("items", []):
            ref = item.get("ref")
            if not ref:
                continue
            best = winners.get(ref)
            if best is None or _changed_ts(item) > _changed_ts(best):
                winners[ref] = item

    contradictions: list[dict] = []
    deduped_tracks: list[dict] = []
    for track in tracks:
        kept: list[dict] = []
        lost = 0
        for item in track.get("items", []):
            ref = item.get("ref")
            winner = winners.get(ref) if ref else None
            if winner is None or winner is item:
                kept.append(item)
                continue
            lost += 1
            if item.get("state") != winner.get("state"):
                # The digest renders project/ref/note; the *_says keys carry the detail for the
                # /borg-recon synthesis, named for what they are (this is source-vs-source, not the
                # checkpoint-vs-source shape project_contradictions emits).
                contradictions.append(
                    {
                        "project": winner.get("project"),
                        "ref": ref,
                        "kept_says": f"{winner.get('source')} reports state {winner.get('state')!r} (newer)",
                        "dropped_says": f"{item.get('source')} reports state {item.get('state')!r}",
                        "note": (
                            "two sources disagree on this item's state — the newer report "
                            "was kept, confirm which is right"
                        ),
                    }
                )
        result = dict(track)
        result["items"] = kept
        result["deduped"] = lost
        deduped_tracks.append(result)
    return deduped_tracks, contradictions


def merge_by_project(tracks: list[dict]) -> dict[str, list[dict]]:
    """Merge all track item arrays into a flat item list grouped by project.

    Mirrors _recon_merge_by_project (jq group_by).
    """
    by_project: dict[str, list[dict]] = {}
    for track in tracks:
        for item in track.get("items", []):
            project = item.get("project")
            if not isinstance(project, str):
                continue
            by_project.setdefault(project, []).append(item)
    return by_project


def extract_checkpoint_blockers(checkpoint_text: str) -> str:
    """Extract the raw '## 4. Blockers' section text from a checkpoint's markdown body.

    Mirrors the awk one-liner in _recon_checkpoint_blockers: captures lines after a
    '## 4. Blockers' (or '## 4 Blockers') heading up to (not including) the next '## ' heading.
    """
    lines: list[str] = []
    capturing = False
    heading_re = re.compile(r"^## *4\.? *Blockers")
    next_heading_re = re.compile(r"^## ")
    for line in checkpoint_text.splitlines():
        # JUSTIFICATION: calling .match() on a locally-compiled re.Pattern, not cross-layer reach.
        if heading_re.match(line):  # pylint: disable=clean-arch-demeter
            capturing = True
            continue
        # JUSTIFICATION: calling .match() on a locally-compiled re.Pattern, not cross-layer reach.
        if next_heading_re.match(line):  # pylint: disable=clean-arch-demeter
            capturing = False
            continue
        if capturing:
            lines.append(line)
    return "\n".join(lines)


def project_contradictions(project: str, blockers_text: str, items: list[dict]) -> list[dict]:
    """Detect stale-blocker contradictions for one project.

    An Item shows a resolved-ish state while the project's checkpoint still lists its ref as a
    blocker. Mirrors _recon_project_contradictions.
    """
    if not blockers_text:
        return []
    results = []
    for item in items:
        state = item.get("state", "")
        ref = item.get("ref", "")
        if not isinstance(state, str) or not isinstance(ref, str):
            continue
        if not _RESOLVED_STATE_RE.search(state):
            continue
        if not ref:
            continue
        if ref not in blockers_text:
            continue
        results.append(
            {
                "project": project,
                "ref": ref,
                "checkpoint_says": "listed as a blocker in the latest checkpoint",
                "source_says": f"{state} — {item.get('one_line', '')}",
                "note": ("checkpoint still calls this blocked, but the source shows it resolved — confirm and update"),
            }
        )
    return results


def build_sources_summary(tracks: list[dict]) -> list[dict]:
    """Build the terse per-source summary list embedded in the assembled doc."""
    return [
        {
            "source": track.get("source"),
            "summary": track.get("summary"),
            "ok": track.get("ok", True),
            "count": len(track.get("items", [])),
            "dropped": track.get("dropped", 0),
            "deduped": track.get("deduped", 0),
        }
        for track in tracks
    ]


def assemble(
    since: str,
    generated_at: str,
    sources: list[dict],
    items_by_project: dict[str, list[dict]],
    contradictions: list[dict],
) -> dict:
    """Build the final reconciled document from its parts (mirrors _recon_assemble)."""
    return {
        "since": since,
        "generated_at": generated_at,
        "sources": sources,
        "items_by_project": items_by_project,
        "contradictions": contradictions,
    }


def _urgency_rank(urgency: str) -> int:
    return {"now": 0, "this_week": 1, "fyi": 2}.get(urgency, 3)


def _urgency_label(rank: int) -> str:
    labels = ["now", "this_week", "fyi"]
    return labels[rank] if 0 <= rank < len(labels) else "fyi"


def _render_sources_section(sources: list[dict]) -> list[str]:
    lines = ["Sources:"]
    for src in sources:
        line = f"  {src.get('source')}: {src.get('summary')}"
        if not src.get("ok", True):
            line += "  [FAILED]"
        dropped = src.get("dropped") or 0
        if dropped > 0:
            line += f"  (dropped {dropped} malformed)"
        deduped = src.get("deduped") or 0
        if deduped > 0:
            line += f"  (deduped {deduped} cross-source)"
        lines.append(line)
    lines.append("")
    return lines


def _render_contradictions_section(contradictions: list[dict]) -> list[str]:
    if not contradictions:
        return []
    lines = [f"Contradictions to resolve ({len(contradictions)}):"]
    for c in contradictions:
        lines.append(f"  ⚠ [{c.get('project')}] {c.get('ref')} — {c.get('note')}")
    lines.append("")
    return lines


def _render_item_line(item: dict) -> str:
    suffix = f"({item.get('owner')}, {item.get('urgency')}"
    if item.get("action_needed"):
        suffix += ", action"
    suffix += ")"
    return f"    - {item.get('one_line')}  {suffix}"


def _render_by_project_section(items_by_project: dict[str, list[dict]]) -> list[str]:
    if not items_by_project:
        return ["  (no activity since the mark — quiet sweep)"]
    ranked = sorted(
        (
            (min((_urgency_rank(i.get("urgency", "fyi")) for i in items), default=3), project, items)
            for project, items in items_by_project.items()
        ),
        key=lambda t: t[0],
    )
    lines: list[str] = []
    for rank, project, items in ranked:
        lines.append(f"● {project}  [{_urgency_label(rank)}]")
        for item in sorted(items, key=lambda i: _urgency_rank(i.get("urgency", "fyi"))):
            lines.append(_render_item_line(item))
        lines.append("")
    return lines


def render_digest(doc: dict) -> str:
    """Render the terse, most-urgent-first by-project digest from a reconciled doc.

    Mirrors _recon_print_digest's jq template.
    """
    lines = [
        f"Recon sweep — since {doc.get('since', '')}  (generated {doc.get('generated_at', '')})",
        "",
    ]
    lines.extend(_render_sources_section(doc.get("sources", [])))
    lines.extend(_render_contradictions_section(doc.get("contradictions", [])))
    lines.append("By project (most urgent first):")
    lines.append("")
    lines.extend(_render_by_project_section(doc.get("items_by_project", {})))
    lines.append("Run /borg-recon for the full morning link-up: reconcile, Yours-vs-Mine action lists,")
    lines.append("and a recommended parallel kickoff batch.")
    return "\n".join(lines)
