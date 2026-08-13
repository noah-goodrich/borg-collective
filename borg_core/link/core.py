"""Pure logic for the `borg link` leaves and the registry/reap chokepoint.

This module is UNCONDITIONALLY free of raw I/O: no subprocess, no file open(), no network, no
environment reads, no clock reads. Every function here takes already-gathered data as arguments and
returns plain data structures or strings. All I/O (filesystem reads, subprocess calls, environment
and clock lookups) lives in shell.py, which calls into this module for the actual logic.

Ports the pure half of: _borg_relative_time, _borg_iso_to_epoch, _borg_cortex_countdown (borg.zsh),
_borg_should_reap (lib/reaper.sh), borg_registry_with_state's merge algebra and borg_reap_overlay's
decision logic (lib/registry.zsh), _borg_active_count, and the title/ship-date/slug/sort/plan
primitives the deep dive and the four collectors share.

PHASE 2 SCOPE: the human table's ordering (project_sort_key/order_projects) and the pure document
assembler (assemble) now live here too. No renderer lives here yet -- the porcelain/overview/deep
flip is still Phase 3 (see PROJECT_PLAN.md).
"""

from __future__ import annotations

import re
from datetime import datetime, timezone

ISO_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
REAPABLE_STATUSES = ("active", "waiting")
DEFAULT_STATUS = "idle"
DEFAULT_REAP_STALE_HOURS = 12

# jq emits "-" as a sentinel for an empty column in the reap overlay's @tsv stream, because zsh's
# `read` with a whitespace IFS collapses consecutive tabs and would shift every later field left.
# The zsh loop maps the sentinel back (lib/registry.zsh:221-222); so does reap_overlay below. The
# consequence is inherited, not chosen: a tmux_window whose literal value is "-" is treated as absent.
TSV_EMPTY_SENTINEL = "-"

# The `--json` document's format-version, bumped whenever the wire shape changes (see assemble's
# docstring). Not a parameter: it is a property of the assembler, not an input any caller chooses.
DOCUMENT_VERSION = 1

# The human table's three-key sort (project_sort_key) ranks status ascending: waiting < active <
# idle. See project_sort_key's docstring for the full writeup of all four judgment calls baked in.
_STATUS_RANK = {"waiting": 0, "active": 1, "idle": 2}

# Catches archived rows AND any truly-unknown status -- both fall into jq's `else 3` bucket at
# borg.zsh:303-310; do not give archived its own rank without re-deriving the whole sort.
_OTHER_STATUS_RANK = 3

# The third sort key's substitute for a jq-falsy last_activity (missing, JSON null, or false). An
# empty string is jq-truthy and is therefore NOT replaced -- see project_sort_key's docstring.
_NO_ACTIVITY_SENTINEL = "0"

_HEADING_PREFIX = re.compile(r"^#* *")

# The relative-time ladder from borg.zsh:70-75, in order, as (exclusive upper bound, renderer).
# A table rather than an if-chain only because the chain's seven returns exceed pylint's limit; the
# thresholds and their outputs are the shell's, unchanged.
_RELATIVE_BUCKETS = (
    (60, lambda _diff: "just now"),
    (3600, lambda diff: f"{diff // 60}m ago"),
    (86400, lambda diff: f"{diff // 3600}h ago"),
    (172800, lambda _diff: "yesterday"),
)


def iso_to_epoch(ts: str | None) -> int | None:
    """Epoch seconds for an ISO-8601 UTC timestamp, or None if it cannot be parsed.

    Ports borg.zsh:2697 `_borg_iso_to_epoch`:
        TZ=UTC date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s || TZ=UTC date -d "$1" +%s

    DELIBERATE DEVIATION (signed off, recorded in PROJECT_PLAN.md): this grammar is STRICT where the
    shell's is platform-dependent and loose. BSD `date -j -u -f` additionally accepts trailing
    garbage ("...Zextra") and normalizes out-of-range dates ("2026-02-30T00:00:00Z" -> a real epoch);
    the GNU fallback used on Linux accepts a far larger grammar still (bare dates, offsets,
    "yesterday"). The two platforms therefore accept DIFFERENT input sets today. One strict grammar
    normalizes a pre-existing platform split rather than introducing a new one, and no value borg
    itself writes is affected -- every writer uses `date -u +%Y-%m-%dT%H:%M:%SZ`.
    """
    if not ts:
        return None
    try:
        parsed = datetime.strptime(ts, ISO_FORMAT).replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None
    # JUSTIFICATION: a method call on a datetime this function just built, not a foreign object graph.
    return int(parsed.timestamp())  # pylint: disable=clean-arch-demeter


def relative_time(ts: str | None, now_epoch: int) -> str:
    """Human relative time ("2h ago", "yesterday", "3d ago"), mirroring borg.zsh:63-76.

    Empty, None or the literal string "null" -> "never". An UNPARSEABLE timestamp echoes the input
    back verbatim -- not "never" -- because zsh's `|| { echo "$ts"; return; }` does. That is the
    opposite of should_reap's treatment of the same condition, and both are deliberate.

    A future timestamp yields a negative diff and lands in the first branch ("just now"); there is no
    future branch in the original and none is added here.
    """
    if not ts or ts == "null":
        return "never"
    epoch = iso_to_epoch(ts)
    if epoch is None:
        return ts
    diff = now_epoch - epoch
    for limit, render in _RELATIVE_BUCKETS:
        if diff < limit:
            return render(diff)
    return f"{diff // 86400}d ago"


def countdown(reset_at: str | None, now_epoch: int) -> str:
    """Time remaining until `reset_at`, mirroring _borg_cortex_countdown (borg.zsh:2380-2394).

    Unparseable or empty -> "?". Already past -> "now". The zero minute is NOT suppressed: two hours
    exactly renders "2h 0m", verbatim as the shell emits it.
    """
    reset_epoch = iso_to_epoch(reset_at)
    if reset_epoch is None:
        return "?"
    diff = reset_epoch - now_epoch
    if diff <= 0:
        return "now"
    hours = diff // 3600
    minutes = (diff % 3600) // 60
    seconds = diff % 60
    if hours > 0:
        return f"{hours}h {minutes}m"
    if minutes > 0:
        return f"{minutes}m {seconds}s"
    return f"{seconds}s"


def _age_hours(delta_seconds: int) -> int:
    """Whole hours in `delta_seconds`, TRUNCATING toward zero the way shell arithmetic does.

    Not floor division. zsh evaluates `(( -100 / 3600 ))` as 0 while Python's `-100 // 3600` is -1,
    and the difference is observable: with BORG_REAP_STALE_HOURS=0 and a timestamp 100 seconds in the
    FUTURE, the shell computes an age of 0 and reaps; floor division would give -1 and keep. Both
    rows are in tests/fixtures/reaper-cases.tsv.
    """
    if delta_seconds >= 0:
        return delta_seconds // 3600
    return -((-delta_seconds) // 3600)


def should_reap(
    status: str,
    last_activity: str | None,
    live: bool,
    now_epoch: int,
    threshold_hours: int | None,
) -> bool:
    """Whether a project's status should be downgraded to idle, mirroring lib/reaper.sh:19-37.

    The CHECK ORDER is load-bearing and was probed against the live shell:

    1. Status not exactly "active" or "waiting" -> keep. Case-sensitive: "Active" is not reapable.
    2. A live window -> keep, regardless of age.
    3. No last_activity (None, "", or the literal "null") -> REAP. This sits BEFORE the threshold
       check because a garbage threshold still reaps a project with no timestamp.
    4. An unparseable last_activity -> REAP. (relative_time echoes such input back instead; the two
       functions genuinely disagree, and that is the shell's behavior.)
    5. A non-integer threshold -> keep. This is where the shell's `[ "$age_h" -ge "abc" ]` prints
       "integer expression expected" and returns 2, which every `if` caller reads as false.
    6. age_hours >= threshold_hours.
    """
    if status not in REAPABLE_STATUSES:
        return False
    if live:
        return False  # a live window is never reaped, regardless of age
    if not last_activity or last_activity == "null":
        return True
    epoch = iso_to_epoch(last_activity)
    if epoch is None:
        return True
    if threshold_hours is None:
        return False
    return _age_hours(now_epoch - epoch) >= threshold_hours


def overlay_state(entry: dict, state: dict) -> dict:
    """Merge one project's state.json over its registry entry, mirroring lib/registry.zsh:174-180.

    The state wins on every field EXCEPT that a project whose PRE-MERGE registry status was exactly
    "archived" keeps that status. Only `.status` is protected -- last_activity and every other field
    are overwritten even on an archived project, matching the jq. Never mutates its arguments.
    """
    was_archived = entry.get("status") == "archived"
    merged = {**entry, **state}
    if was_archived:
        merged["status"] = "archived"
    return merged


def with_state(registry: dict, states: dict[str, dict]) -> dict:
    """Apply every project's state.json overlay, then default missing statuses to idle.

    Mirrors borg_registry_with_state's merge half (lib/registry.zsh:165-184). The default uses jq's
    `//=`, which also replaces `false` -- reproduced here. Never mutates the input registry.
    """
    projects = registry.get("projects") or {}
    merged: dict[str, dict] = {}
    for name, entry in projects.items():
        state = states.get(name)
        merged[name] = overlay_state(entry, state) if state else dict(entry)
        if not merged[name].get("status"):
            merged[name]["status"] = DEFAULT_STATUS
    return {**registry, "projects": merged}


def resolve_window(name: str, entry: dict) -> str:
    """The tmux window a project is expected to own, mirroring lib/registry.zsh:221.

    Falls back to the project name when tmux_window is missing, None, empty, the literal "null", or
    the TSV empty sentinel "-".
    """
    window = entry.get("tmux_window")
    if window in (None, "", "null", TSV_EMPTY_SENTINEL):
        return name
    return str(window)


def reap_overlay(
    registry: dict,
    live_windows: list[str],
    now_epoch: int,
    threshold_hours: int | None,
) -> dict:
    """Downgrade every stale active/waiting project to idle, mirroring lib/registry.zsh:209-243.

    Display-path only: the caller's state.json files are untouched, and the original status is kept
    under `_reaped_from` so callers can report what was auto-downgraded. Never mutates its arguments.

    Liveness is a WHOLE-STRING, LITERAL match. The shell used `grep -qx` without `-F`, which compiled
    the window name as a basic regex, so `troth.site` matched a live `troth-site`. That was fixed in
    zsh rather than reproduced here -- see the `-qxF` comment at lib/registry.zsh:243. The two
    implementations therefore agree, which is the point: this is the chokepoint PROJECT_PLAN.md's
    Risks section names as the port's top divergence hazard.
    """
    live = set(live_windows)
    projects = registry.get("projects") or {}
    updated: dict[str, dict] = {}
    for name, entry in projects.items():
        status = entry.get("status", "")
        last_activity = entry.get("last_activity")
        if last_activity == TSV_EMPTY_SENTINEL:
            last_activity = ""
        is_live = resolve_window(name, entry) in live
        if should_reap(status, last_activity, is_live, now_epoch, threshold_hours):
            updated[name] = {**entry, "_reaped_from": status, "status": DEFAULT_STATUS}
        else:
            updated[name] = dict(entry)
    return {**registry, "projects": updated}


def active_count(registry: dict) -> int:
    """Projects needing attention, mirroring _borg_active_count (borg.zsh:114-116).

    Counts the registry AS PASSED, so the caller decides whether the reap overlay has been applied.
    """
    projects = registry.get("projects") or {}
    return sum(1 for entry in projects.values() if entry.get("status") in REAPABLE_STATUSES)


def project_paths(registry: dict) -> list[tuple[str, str]]:
    """(name, path) for every project, mirroring the collectors' `[.key, (.value.path // "")] | @tsv`.

    A null or missing path becomes "". Order is the registry's JSON insertion order, which json.loads
    preserves and which the aggregate directive/assimilated sections depend on. Callers apply their
    own skip rules.
    """
    projects = registry.get("projects") or {}
    return [(name, entry.get("path") or "") for name, entry in projects.items()]


def heading_title(text: str) -> str:
    """A markdown file's title, mirroring `head -1 "$f" | sed 's/^#* *//'`.

    Splits on "\\n" only -- NOT str.splitlines(), which also breaks on \\r, \\x0b, \\x0c and U+2028,
    none of which `head -1` treats as a line ending. A trailing \\r from a CRLF file is preserved,
    exactly as sed leaves it.
    """
    first = text.split("\n", 1)[0]
    return _HEADING_PREFIX.sub("", first)


def ship_date(text: str) -> str:
    """The ship date from an assimilated plan, mirroring
    `grep -m1 'Shipped:' "$f" | sed 's/.*Shipped: *//' | sed 's/ .*//'`.

    Finds the FIRST line containing "Shipped:" (unanchored, case-sensitive), takes what follows the
    LAST occurrence on that line (sed's `.*` is greedy), strips leading SPACES only, and truncates at
    the first space. No matching line -> "" (grep's exit 1 is swallowed by the pipeline).
    """
    for line in text.split("\n"):
        if "Shipped:" in line:
            value = line.rpartition("Shipped:")[2].lstrip(" ")
            return value.split(" ", 1)[0]
    return ""


def slug_from_filename(name: str) -> str:
    """Strip exactly one trailing ".md", mirroring zsh's `${${f:t}%.md}`.

    Not Path.stem, which strips any suffix: "a.txt" stays "a.txt" and "a.md.md" becomes "a.md".
    """
    if name.endswith(".md"):
        return name[: -len(".md")]
    return name


def sort_assimilated(entries: list[dict]) -> list[dict]:
    """Newest-first by filename, mirroring `sort -r -k1,1` over `<filename>\\t<path>\\t<project>`.

    The key includes the ".md" suffix because the shell sorts the basename, not the slug, and the
    (path, project) tail reproduces sort's last-resort whole-line comparison on ties.

    DEVIATION, recorded: Python sorts by codepoint; zsh's glob sort and coreutils `sort` use LOCALE
    collation, where punctuation is ignored at the primary level. Measured impact across all 374 real
    plan filenames under ~/dev is zero; it becomes observable only when a filename mixes case or uses
    "_" where a sibling uses "-".
    """
    return sorted(
        entries,
        key=lambda e: (e.get("filename", ""), e.get("path", ""), e.get("project", "")),
        reverse=True,
    )


def sort_checkpoints(filenames: list[str], limit: int = 3) -> list[str]:
    """Newest-first by NAME, capped, mirroring `find ... | sort -r | head -3` (borg.zsh:466).

    By name, not mtime: checkpoint filenames are ISO-stamped, and a fresh `git clone` gives every
    file the same checkout mtime. The shell already sorted by name here; this only makes it explicit.
    """
    return sorted(filenames, reverse=True)[:limit]


def plan_objective(text: str) -> str:
    """The Objective line from a PROJECT_PLAN.md, mirroring borg.zsh:455:

        grep -A2 "^## Objective" | grep -v "^## Objective" | grep -v "^$" | head -1

    grep -A2 yields the heading plus the two lines after it; the filters drop the heading and blank
    lines and take the first survivor. An objective that starts three or more lines below the heading
    is therefore NOT found -- that is the shell's behavior and it is preserved.
    """
    lines = text.split("\n")
    for index, line in enumerate(lines):
        if line.startswith("## Objective"):
            for candidate in lines[index + 1 : index + 3]:
                if candidate != "":
                    return candidate
            return ""
    return ""


def plan_progress(text: str) -> tuple[int, int]:
    """(met, total) acceptance criteria, mirroring borg.zsh:458-459's two `grep -c` calls.

    DELIBERATE DEVIATION (signed off, pinned in tests/cli_contract.bats): the shell writes
    `criteria_done=$(grep -c '^\\- \\[x\\]' ... || echo 0)`, and `grep -c` exits 1 when it matches
    nothing, so the substitution captures BOTH grep's own "0" and the fallback's "0". The variable
    becomes the two-line string "0\\n0" and a plan with nothing completed renders

        Progress: 0
        0/2 criteria met

    across two lines. Every fresh plan hits it. Returning integers is the fix; it is recorded as a
    deviation rather than allowed to look like an accident of the rewrite.
    """
    total = 0
    met = 0
    for line in text.split("\n"):
        if line.startswith("- ["):
            total += 1
            if line.startswith("- [x]"):
                met += 1
    return met, total


def jq_interp(value: object) -> str:
    """Reproduce jq's `\\(...)` string interpolation for the cortex-wake fields.

    None -> "null" (not Python's "None"), True -> "true", False -> "false", str unchanged. This is
    why a wake whose `.project` is JSON null renders the literal four-character string "null" and is
    therefore NOT skipped by the caller's emptiness guard -- matching the shell. Non-string scalars
    fall through to str() and are outside the contract.
    """
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return value
    return str(value)


def format_iso(epoch_seconds: int) -> str:
    """UTC ISO-8601 for `epoch_seconds`, in the exact grammar iso_to_epoch parses back.

    Uses the same ISO_FORMAT constant as the parser -- never re-hardcode the literal here.
    """
    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc).strftime(ISO_FORMAT)


def project_sort_key(entry: dict) -> tuple[int, int, str]:
    """The human table's three-key sort, ported from the jq at borg.zsh:303-310 (byte-identical text
    also at :255-262 and :543-550): pinned first, then waiting < active < idle < other, then
    last_activity ascending as a raw string compare.

    Four judgment calls, all deliberate:
      (a) `pinned` uses `is True`, NOT truthiness -- jq's `.value.pinned == true` treats the STRING
          "true" and the number 1 as unpinned.
      (b) All THREE keys are ASCENDING -- never reverse=True, never a negated key. last_activity
          ascending means OLDEST FIRST, which looks like a bug and is not. cmd_next
          (borg.zsh:1029-1030) uses a DIFFERENT direction-mixed sort; do not copy it here.
      (c) last_activity is compared as a RAW STRING (lexicographic ISO), never converted to an
          epoch -- the "0" sentinel only sorts first because "0" < "2".
      (d) The sentinel substitutes only for jq-falsy values (JSON null / false / a missing key). An
          EMPTY STRING is truthy in jq, so "" passes through as "" and sorts before "0".
    """
    pinned = 0 if entry.get("pinned") is True else 1
    rank = _STATUS_RANK.get(entry.get("status"), _OTHER_STATUS_RANK)
    activity = entry.get("last_activity")
    if activity is None or activity is False:
        activity = _NO_ACTIVITY_SENTINEL
    return (pinned, rank, str(activity))


def public_entry(entry: dict, now_epoch: int) -> dict:
    """A registry entry as it may cross the `--json` wire: every key EXCEPT those starting with "_",
    plus one derived key.

    Keys beginning with "_" are reap_overlay's internal display annotations (`_reaped_from`,
    core.py's reap_overlay) and are deliberately NOT part of the JSON contract. `relative_activity`
    is the ONE derived field, computed with the document's single shared epoch.
    """
    public = {k: v for k, v in entry.items() if not k.startswith("_")}
    public["relative_activity"] = relative_time(public.get("last_activity"), now_epoch)
    return public


def visible_projects(registry: dict, show_all: bool, now_epoch: int) -> dict[str, dict]:
    """The projects a `borg link` invocation shows, keyed by name, with public_entry applied.

    Ports the archived filter FUSED into the jq pipeline at borg.zsh:302, which runs BEFORE the
    sort. Insertion order is preserved -- it is the tie-break order_projects's stable sort relies on.
    """
    projects = registry.get("projects") or {}
    return {
        name: public_entry(entry, now_epoch)
        for name, entry in projects.items()
        if show_all or entry.get("status") != "archived"
    }


def order_projects(projects: dict[str, dict]) -> list[str]:
    """The display order for `projects`, mirroring jq's stable sort_by.

    Python's sort is stable, reproducing jq's stable sort_by falling back to registry insertion
    order on a full three-key tie.
    """
    return sorted(projects, key=lambda name: project_sort_key(projects[name]))


def capacity(active: int, limit: int) -> dict:
    """The capacity block feeding borg.zsh:406-411's warning, with a strict `>` comparison mirroring
    `(( active_count > BORG_MAX_ACTIVE ))` at borg.zsh:407."""
    return {"active": active, "limit": limit, "over_limit": active > limit}


# JUSTIFICATION: one flat argument per top-level key of the document; a bag parameter or a
# dataclass here would hide the contract this function exists to state.
def assemble(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    generated_at, show_all, capacity, projects, order, directives, assimilated, cortex_pending, focus
) -> dict:
    """Assemble the `borg link --json` document from already-gathered data. Pure: no clock, no shell
    import, no os.environ.

    `order` is NOT redundant with `projects`' key order: jq's `keys` builtin sorts alphabetically;
    only `keys_unsorted`/`to_entries` preserve insertion order, so any consumer must read `.order`
    directly and never derive it from `.projects`.

    Building the projects map as {name: projects[name] for name in order} is what makes A3's
    `(.order|length) == (.projects|length)` structurally true and emits the map in display order.

    A name in `order` that is absent from `projects` raises KeyError; callers must derive `order`
    from the same map they pass as `projects`.
    """
    return {
        "version": DOCUMENT_VERSION,
        "generated_at": generated_at,
        "show_all": show_all,
        "capacity": capacity,
        "order": order,
        "projects": {name: projects[name] for name in order},
        "directives": directives,
        "assimilated": assimilated,
        "cortex_pending": cortex_pending,
        "focus": focus,
    }
