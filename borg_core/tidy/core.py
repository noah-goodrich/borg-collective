"""Which machine-local files are cairn leftovers. Pure: names in, verdicts out.

Cairn (the retired knowledge-graph service) left five machine-local artifacts behind. No code path
writes or reads any of them now (the census, `docs/state-census.md`, proves it), so they are dead
weight, and `borg tidy --cairn-leftovers` is the one-shot that removes them.

MATCHING IS BY EXACT NAME, not by a `cairn*` glob. A glob is how a future operator file that happens
to contain the word gets deleted; five known names is the whole set and the list is the audit trail.
"""

from __future__ import annotations

CAIRN_LEFTOVERS = (
    "cairn-hits.log",
    "cairn-inbox",
    "cairn-heartbeat-last",
    ".cairn-last-write",
    ".cairn-write-failed",
)


def is_cairn_leftover(name: str) -> bool:
    """True when `name` (a bare entry name, not a path) is one of the five known cairn artifacts."""
    return name in CAIRN_LEFTOVERS
