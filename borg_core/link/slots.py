"""Slot sharing: the pure pick behind every capped list of owned rows (directive one-owned-next-list, AC7)."""

from __future__ import annotations


def share_slots(rows: list[dict], limit: int, key: str) -> list[dict]:
    """At most `limit` of `rows`, chosen one per group per round, shown in their existing order (AC7).

    Groups are the distinct `row[key]` values in first-seen order: the first row of each group, then the second of
    each, and so on until `limit`. One group gives the first `limit` rows. Shared by `nextpick.core.cap_rows` and
    the Queen page's own row cap, so neither lets one repository's queue push another's rows off the page.
    """
    queues: dict[str, list[int]] = {}
    for index, row in enumerate(rows):
        queues.setdefault(str(row.get(key) or ""), []).append(index)
    picked: set[int] = set()
    depth = 0
    while len(picked) < limit and any(len(queue) > depth for queue in queues.values()):
        for queue in queues.values():
            if depth < len(queue) and len(picked) < limit:
                picked.add(queue[depth])
        depth += 1
    return [row for index, row in enumerate(rows) if index in picked]
