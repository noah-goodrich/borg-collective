"""UTC ISO-8601 timestamp formatting, shared by `borg_core.link` and `borg_core.recon`.

`borg_core/paths.py`'s own docstring sets the precedent this module follows: `borg_dir()` and
`registry_path()` existed as byte-identical copies in two packages and that was tolerated, but a
third copy would not have been -- pylint's duplicate-code check is what forces consolidation at that
point. The same `datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")` / `datetime.fromtimestamp
(..., tz=timezone.utc).strftime(...)` shape existed three times: `borg_core/link/core.py`'s
`format_iso`, `borg_core/recon/core.py`'s `epoch_to_iso`, and an inline literal at
`borg_core/recon/cli.py:71`.

Kept genuinely neutral rather than folded into either package: `link` and `recon` are independently
owned per CLAUDE.md's per-project directive discipline, and importing one package's internals into
the other would violate that even though the string constant is trivial. UNCONDITIONALLY PURE except
`now_iso`, which reads the wall clock on purpose -- callers that must keep one shared instant across a
whole document (see `borg_core/link/cli.py`'s `_document`) should call `shell.now_epoch()` once and
format it with `epoch_to_iso`, not call `now_iso()` directly.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

ISO_FORMAT = "%Y-%m-%dT%H:%M:%SZ"

# An ISO-8601 timestamp anywhere inside prose: optional fractional seconds, optional Z or ±HH[:]MM
# offset. The Item contract's `changed` field is prose ("updated <ISO>; state=open"), so consumers
# comparing recency must extract, not parse the whole string.
_ISO_IN_PROSE = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?")


def iso_in_prose_to_utc(text: str) -> str:
    """The first ISO-8601 timestamp inside `text`, normalized to UTC, or "" (sorts oldest).

    Offset-aware: `2026-08-21T17:30:00-07:00` IS newer than `2026-08-21T23:00:00Z`, and nothing in
    the recon Item contract requires UTC — comparing unnormalized strings would hand a recency
    comparison to whichever source happens to phrase its zone. A timestamp with no offset is taken
    as UTC (the contract's own examples are Z-suffixed); an unparseable match sorts oldest rather
    than raising. Lives here rather than in a recon core module because Domain modules are
    Demeter-strict by config (pyproject [tool.clean-arch.module_map]) and datetime mechanics are
    exactly what this module exists to own.
    """
    found = _ISO_IN_PROSE.findall(text)
    if not found:
        return ""
    raw = found[0].replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return ""
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    # JUSTIFICATION: astimezone/isoformat on a datetime built two lines up is not cross-layer reach.
    return parsed.astimezone(timezone.utc).isoformat()  # pylint: disable=clean-arch-demeter


def epoch_to_iso(epoch_seconds: int) -> str:
    """UTC ISO-8601 for `epoch_seconds`, in the exact grammar a corresponding strptime parser using
    ISO_FORMAT would parse back."""
    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc).strftime(ISO_FORMAT)


def now_iso() -> str:
    """The current instant, formatted the same way as `epoch_to_iso`. Reads the wall clock -- see the
    module docstring for why most callers should prefer threading one shared epoch through
    `epoch_to_iso` instead."""
    return datetime.now(timezone.utc).strftime(ISO_FORMAT)
