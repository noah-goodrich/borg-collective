"""Pure logic for checkpoint filenames.

UNCONDITIONALLY free of raw I/O: no clock, no environment, no randomness, no filesystem. The
moment and the session identity are arguments, because a name generator whose inputs are ambient is
a name generator no test can pin.

WHY THIS MODULE EXISTS AT ALL. Checkpoint filenames used to be composed by an LLM following prose:
`skills/borg-link-up/SKILL.md` said to run `date +%Y-%m-%d-%H%M` and use its literal stdout. Two
consequences, both measured on the live registry in 2026-09. Minute resolution made a collision
reachable, and the skill's own collision guard -- check whether the target exists, and if so append
`-2` -- was scoped to ONE DIRECTORY, so two sessions in two worktrees of a single clone each looked
in their own store, each found the name free, and both wrote it. Three filenames existed twice with
different bodies; two of those pairs were written in the same minute.

A better sentence would not have fixed that, and the plan this implements says so in its own
acceptance criterion: the name now comes from code so the collision becomes UNREPRESENTABLE rather
than discouraged.
"""

from __future__ import annotations

from datetime import datetime

SUFFIX_LENGTH = 6


def short_suffix(session_id: str) -> str:
    """A short, stable, filename-safe tag for one session, or "" when there is no session.

    THE SESSION IS THE UNIT THAT DISAMBIGUATES, which is why this takes a session id rather than
    returning randomness. The collision being closed is TWO SESSIONS writing one repo in the same
    second; a per-session tag closes it by construction. Randomness would also close it, but it
    would close it anonymously -- with a session tag, a duplicate pair in a `borg link` byline can
    be traced back to the sessions that produced it, which is the whole reason the pair is
    interesting.

    Same-session same-second is NOT closed by this and deliberately so. A checkpoint is a multi-
    section document a human reviews before it is written; one session producing two of them inside
    one second is not a state worth carrying a counter for, and a counter would have to live
    somewhere, which is a new store -- the thing the parent plan exists to stop adding.

    Normalizes rather than slices raw: session ids are UUIDs today, but the value arrives from the
    environment and must not be trusted to be hex, to be lowercase, or to contain no path
    separators. Non-alphanumerics are dropped, the rest is lowercased, and the first
    SUFFIX_LENGTH characters are taken -- so a hostile or malformed value cannot produce a name that
    escapes its directory or collides with a legacy shape.
    """
    cleaned = "".join(char for char in session_id.lower() if char.isalnum())
    return cleaned[:SUFFIX_LENGTH]


def checkpoint_stem(moment: datetime, suffix: str) -> str:
    """The checkpoint filename WITHOUT its `.md` extension.

    `YYYY-MM-DD-HHMMSS-<suffix>`, degrading to `YYYY-MM-DD-HHMMSS` when there is no suffix. The
    caller appends `.md`, which keeps `skills/borg-link-up/SKILL.md`'s `<timestamp>.md` shape
    unchanged -- the skill substitutes a different token, not a different sentence structure.

    NAME-SORTABLE AGAINST THE LEGACY SHAPE, and this is a hard requirement rather than a nicety.
    `borg_core.link.core.order_checkpoints` sorts checkpoints by NAME descending -- deliberately,
    because a fresh `git clone` gives every file the same mtime -- so a new format that sorted
    wrongly against the 120 legacy `YYYY-MM-DD-HHMM` names already on disk would silently reorder
    history. Extending the time field rightward preserves the order: within one day, "1605" and
    "160432" compare at the fourth character, where '4' < '5', so 16:04:32 correctly precedes
    16:05; and a legacy "1604" is a prefix of "160432", so the shorter legacy name sorts first
    among names sharing that minute. Both directions are pinned by tests.

    Second resolution, not sub-second. It is the coarsest resolution at which the session suffix
    carries the whole burden of disambiguation, and a checkpoint is written by a human-reviewed
    skill, not in a loop.
    """
    stamp = moment.strftime("%Y-%m-%d-%H%M%S")
    return f"{stamp}-{suffix}" if suffix else stamp
