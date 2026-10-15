"""The compass: a pure reading of the owner's plain-file map. Text in, dicts out.

The map is a directory of markdown files, every one of them optional (`log/<date>.md`, `destinations/<id>.md`,
`README.md`, `parking-lot.md`). This module turns their TEXT into the `compass` block `borg link --json` carries.
It performs no I/O, reads no environment and no clock: `shell.py` reads the files, the cli boundary hands in
`today`, and `borg_core/compass/test_core.py` pins the import roots by AST walk because W9004's allow-list would
wave a `pathlib` or `os` import through.

NEVER RAISES ON CONTENT. A missing file is simply absent from the arguments, a malformed destination is skipped
with a `warnings` entry naming the file, and a line that does not parse is ignored. The reader reports what it
found; it does not judge the map. The one exception is `today`, which is the caller's and must be an ISO date.

STATE RULE (`destination_state`): status done, killed, frozen or proposed give that word; an active destination
with no due date is "undated"; due before today is "late"; due within 7 days (inclusive) with the next waypoint
not COMPLETE is "at-risk"; anything else is "on-track". "Complete" means at least one criterion and all of them
checked, so a destination with no next waypoint at all is not complete and a due date inside the window is
at-risk: the reader has no evidence of progress and says so rather than reporting calm.
"""

# The Demeter check reads `match.group(...)` and `date.fromisoformat(...)` as strangers' chains; a delegate per
# call would only relocate the dots.
# JUSTIFICATION: re.Match and datetime.date are stdlib value types this module owns no wrapper for.
# pylint: disable=clean-arch-demeter

from __future__ import annotations

import datetime
import re

STATUSES = ("active", "frozen", "proposed", "done", "killed")
WAYPOINT_STATUSES = ("proposed", "active", "done", "dropped")
AT_RISK_DAYS = 7

_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
_HEADING = re.compile(r"^###\s+W(\d+)\b[ \t]*(.*?)\s*$")
_ANY_HEADING = re.compile(r"^#{1,6}\s")
_CRITERION = re.compile(r"^\s*[-*]\s+\[([ xX])\]")
_WAYPOINT_STATUS = re.compile(r"^\s*[-*]\s+status:\s*(\w+)\s*$", re.IGNORECASE)
_LEG_HEADING = re.compile(r"^##\s+today['’]s leg\s*$", re.IGNORECASE)
_BULLET = re.compile(r"^\s*[-*]\s+(.*\S)\s*$")


def absent(map_dir: str) -> dict:
    """The compass of a map directory that does not exist: found false and nothing else."""
    return {"found": False, "map_dir": map_dir}


def as_date(text: str | None) -> datetime.date | None:
    """A strict YYYY-MM-DD as a date, else None. Never raises."""
    if not text or not _DATE.fullmatch(text):
        return None
    try:
        return datetime.date.fromisoformat(text)
    except ValueError:
        return None


def _word_in(needle: str, haystack: str) -> bool:
    """`needle` as a whole word in `haystack`, case-insensitive. A hyphen is part of a word, so `home` is not
    found inside `home-reno`: repository and destination ids are hyphenated names."""
    if not needle:
        return False
    return re.search(rf"(?<![\w-]){re.escape(needle)}(?![\w-])", haystack, re.IGNORECASE) is not None


def parse_frontmatter(text: str) -> dict | None:
    """The `key: value` lines between the leading `---` fences, or None when the file has no frontmatter.

    A key with an empty value followed by `- item` lines becomes a list; `[a, b]` is read as a list too. Quotes
    around a scalar are stripped. Comment lines and lines that are not `key: value` are ignored.
    """
    lines = text.lstrip("﻿").splitlines()
    index = 0
    while index < len(lines) and not lines[index].strip():
        index += 1
    if index >= len(lines) or lines[index].strip() != "---":
        return None
    fields: dict = {}
    key: str | None = None
    for line in lines[index + 1 :]:
        if line.strip() == "---":
            return fields
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        item = re.match(r"^-\s+(.*\S)\s*$", stripped)
        if item and key is not None and isinstance(fields.get(key), list):
            fields[key].append(_unquote(item.group(1)))
            continue
        pair = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*)$", stripped)
        if not pair:
            continue
        key, value = pair.group(1).lower(), pair.group(2).strip()
        fields[key] = _scalar_or_list(value)
    return None  # an unclosed fence is malformed, not "frontmatter that ran to the end of the file"


def _unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _scalar_or_list(value: str) -> str | list:
    if not value:
        return []
    if value.startswith("[") and value.endswith("]"):
        return [_unquote(part.strip()) for part in value[1:-1].split(",") if part.strip()]
    return _unquote(value)


def _body_after_frontmatter(text: str) -> list[str]:
    lines = text.lstrip("﻿").splitlines()
    fences = [i for i, line in enumerate(lines) if line.strip() == "---"]
    return lines[fences[1] + 1 :] if len(fences) >= 2 else []


def parse_waypoints(body: list[str]) -> list[dict]:
    """The `### W<n> <name>` sections of a destination body: name, status, checked count, total criteria.

    The name is the heading text after `W<n>`, or `W<n>` itself when the heading carries nothing else. The status
    is the first `- status:` line in the section; a section without one has status None and is never "next".
    """
    waypoints: list[dict] = []
    current: dict | None = None
    for line in body:
        heading = _HEADING.match(line)
        if heading:
            name = heading.group(2).lstrip(":-–— ") or f"W{heading.group(1)}"
            current = {"name": name, "status": None, "done": 0, "total": 0}
            waypoints.append(current)
            continue
        if _ANY_HEADING.match(line):
            current = None
            continue
        if current is None:
            continue
        status = _WAYPOINT_STATUS.match(line)
        if status and current["status"] is None:
            word = status.group(1).lower()
            current["status"] = word if word in WAYPOINT_STATUSES else None
            continue
        criterion = _CRITERION.match(line)
        if criterion:
            current["total"] += 1
            current["done"] += criterion.group(1) != " "
    return waypoints


def next_waypoint(waypoints: list[dict]) -> dict | None:
    """The first active waypoint, else the first proposed one, else None."""
    for wanted in ("active", "proposed"):
        for waypoint in waypoints:
            if waypoint["status"] == wanted:
                return dict(waypoint)
    return None


def parse_destination(filename: str, text: str) -> tuple[dict | None, list[str]]:
    """One destination file as `(destination, warnings)`. A malformed file is `(None, [reason])`, never a raise.

    Malformed means: no frontmatter, no `id`, or a `status` outside the five known words. `due` is left None
    here, because it comes from the README and `build_compass` joins it.
    """
    fields = parse_frontmatter(text)
    if fields is None:
        return None, [f"{filename}: no frontmatter, skipped"]
    ident = fields.get("id")
    if not isinstance(ident, str) or not ident:
        return None, [f"{filename}: frontmatter has no id, skipped"]
    status = str(fields.get("status") or "").lower()
    if status not in STATUSES:
        return None, [f"{filename}: status {status!r} is not one of {', '.join(STATUSES)}, skipped"]
    repositories = fields.get("repositories") or []
    if isinstance(repositories, str):
        repositories = [repositories]
    return {
        "id": ident,
        "domain": _text_or_none(fields.get("domain")),
        "status": status,
        "definition": _text_or_none(fields.get("definition")),
        "target": _text_or_none(fields.get("target")),
        "repositories": [str(name) for name in repositories],
        "next_waypoint": next_waypoint(parse_waypoints(_body_after_frontmatter(text))),
        "due": None,
        "state": None,
    }, []


def _text_or_none(value: object) -> str | None:
    return value if isinstance(value, str) and value else None


def parse_leg(log_text: str | None) -> dict | None:
    """The current leg from a day's log: the first bullet under `## Today's leg`, or None.

    A bullet beginning "Not chosen yet" means no leg has been chosen, and so does a missing log, a missing
    heading or a heading with no bullet before the next `## ` heading.
    """
    if not log_text:
        return None
    inside = False
    for line in log_text.splitlines():
        if _LEG_HEADING.match(line.strip()):
            inside = True
            continue
        if not inside:
            continue
        if line.startswith("## "):
            return None
        bullet = _BULLET.match(line)
        if bullet:
            text = bullet.group(1).strip()
            return None if text.lower().startswith("not chosen yet") else {"text": text}
    return None


def _cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def parse_due_dates(readme_text: str | None, ids: list[str]) -> tuple[dict[str, str | None], list[str]]:
    """Each destination id's due date from the README's destinations table, plus warnings.

    The header row is the first pipe row with one cell naming a destination and another naming a date or due
    column. A row belongs to the destination whose id appears as a whole word in its first cell; a date cell is
    a YYYY-MM-DD date (found anywhere in the cell) or text beginning TBD, which is None. A destination with no
    row is simply absent from the result.
    """
    if not readme_text:
        return {}, []
    rows = [line for line in readme_text.splitlines() if line.strip().startswith("|")]
    header = None
    for position, line in enumerate(rows):
        cells = [cell.lower() for cell in _cells(line)]
        dest_col = next((i for i, cell in enumerate(cells) if "destination" in cell), None)
        date_col = next(
            (i for i, cell in enumerate(cells) if i != dest_col and ("date" in cell or "due" in cell)), None
        )
        if dest_col is not None and date_col is not None:
            header = (position, date_col)
            break
    if header is None:
        return {}, ["README.md: no destinations table with a date or due column found"]
    start, date_col = header
    dues: dict[str, str | None] = {}
    for line in rows[start + 1 :]:
        cells = _cells(line)
        if not cells or all(set(cell) <= set("-: ") for cell in cells):
            continue
        for ident in ids:
            if ident not in dues and _word_in(ident, cells[0]):
                found = _DATE.search(cells[date_col]) if date_col < len(cells) else None
                dues[ident] = found.group(0) if found and as_date(found.group(0)) else None
    return dues, []


def _count(value: str) -> int:
    """A non-negative integer from ASCII digits, else 0.

    `str.isdigit` is true for characters such as superscripts that `int` rejects, and `int` itself refuses a digit
    run past the interpreter's conversion limit, so the guard is ASCII-only and the conversion is still caught.
    """
    if not (value.isascii() and value.isdigit()):
        return 0
    try:
        return int(value)
    except ValueError:
        return 0


def parse_parking(text: str | None, today: datetime.date) -> list[dict]:
    """The unchecked `- [ ] <text> | parked: D | look: D | seen: N | last: D` lines of the parking lot.

    A field that is absent or does not parse is None (`seen` falls back to 0); `due` is true when `look` is on
    or before today. Checked items and lines that are not list items are ignored.
    """
    items: list[dict] = []
    for line in (text or "").splitlines():
        match = re.match(r"^\s*[-*]\s+\[ \]\s*(.*)$", line)
        if not match:
            continue
        segments = [segment.strip() for segment in match.group(1).split("|")]
        fields = {}
        for segment in segments[1:]:
            pair = re.match(r"^(parked|look|seen|last)\s*:\s*(.*)$", segment, re.IGNORECASE)
            if pair:
                fields[pair.group(1).lower()] = pair.group(2).strip()
        look = as_date(fields.get("look"))
        items.append(
            {
                "text": segments[0],
                "parked": fields.get("parked") if as_date(fields.get("parked")) else None,
                "look": fields.get("look") if look else None,
                "seen": _count(fields.get("seen", "")),
                "last": fields.get("last") if as_date(fields.get("last")) else None,
                "due": look is not None and look <= today,
            }
        )
    return items


def destination_state(destination: dict, today: datetime.date) -> str:
    """The destination's one-word state; see the module docstring for the rule."""
    status = str(destination["status"])
    if status != "active":
        return status
    due = as_date(destination["due"])
    if due is None:
        return "undated"
    if due < today:
        return "late"
    waypoint = destination["next_waypoint"]
    complete = waypoint is not None and 0 < waypoint["total"] == waypoint["done"]
    if (due - today).days <= AT_RISK_DAYS and not complete:
        return "at-risk"
    return "on-track"


def map_repositories(
    destinations: list[dict], names: list[str], leg: dict | None, parents: dict[str, str] | None = None
) -> dict[str, dict]:
    """For each registry repository name: the destination that owns it and whether the leg names it.

    A repository belongs to the first destination listing it under `repositories`, else to the destination whose
    id equals its name, else to none. `on_leg` is true when the leg text contains the destination id or the
    repository name as a whole word.

    `parents` is `{worktree: repository}` (`link.worktree.repository_parents`): a worktree with no mapping of its own
    INHERITS its repository's destination, because it is that repository's checkout and not a repository of its own.
    Its `on_leg` is the repository's OR its own: a worktree whose own name the leg text names stays on today's leg even
    when its repository is not, exactly as it read before the inheritance existed, so the entry is not copied whole.
    AN EXPLICIT MAPPING ALWAYS WINS: a worktree the map itself names (listed under a
    destination's `repositories`, or the name of a destination) keeps that entry, so inheritance only fills a hole.
    A head with no mapping hands its unmapped entry only to an unmapped worktree and never erases a mapped one.
    This is the one place the inheritance is applied, and every reader of the block (`borg next`'s ranking, the Queen
    board's suffix) gets it from here. A parent that is not among `names` is ignored.
    """
    leg_text = leg["text"] if leg else ""
    mapped: dict[str, dict] = {}
    explicit: set[str] = set()
    for name in names:
        owner = next((d for d in destinations if name in d["repositories"]), None) or next(
            (d for d in destinations if d["id"] == name), None
        )
        on_leg = _word_in(name, leg_text) or (owner is not None and _word_in(owner["id"], leg_text))
        mapped[name] = {"destination": owner["id"] if owner else None, "on_leg": on_leg}
        if owner is not None:
            explicit.add(name)
    for child, head in (parents or {}).items():
        if child in mapped and head in mapped and child not in explicit:
            mapped[child] = {
                "destination": mapped[head]["destination"],
                "on_leg": mapped[head]["on_leg"] or mapped[child]["on_leg"],
            }
    return mapped


def leg_priority(compass: dict | None, name: str) -> tuple[int, str]:
    """`(bucket, due)`: where a repository sorts among candidates for `borg next`. Lower is earlier.

    Bucket 0 is a repository on today's leg; 1 is a repository whose active destination has a due date, ordered by
    that date (so the nearest, and a late one before any other, comes first); 2 is an active destination with no
    date; 3 is everything else: a frozen, done, killed or proposed destination, and a repository no destination
    claims. With no map (None, or `found` false) every repository gets `(0, "")`, a constant, so a stable sort on
    a key that starts with this is exactly the sort it was before.
    """
    if not compass or not compass.get("found"):
        return 0, ""
    entry = (compass.get("repositories") or {}).get(name) or {}
    if entry.get("on_leg"):
        return 0, ""
    owner = next((d for d in compass.get("destinations") or [] if d.get("id") == entry.get("destination")), None)
    if owner is None or owner.get("status") != "active":
        return 3, ""
    due = owner.get("due")
    return (1, due) if as_date(due) else (2, "")


def collect_destinations(destination_files: list[tuple[str, str]], warnings: list[str]) -> list[dict]:
    """Every parseable destination in file order; a skipped file (malformed, or a repeated id) adds to `warnings`."""
    destinations: list[dict] = []
    for filename, text in destination_files:
        destination, problems = parse_destination(filename, text)
        warnings.extend(problems)
        if destination is None:
            continue
        if any(seen["id"] == destination["id"] for seen in destinations):
            warnings.append(f"{filename}: id {destination['id']!r} already declared, skipped")
            continue
        destinations.append(destination)
    return destinations


# JUSTIFICATION: the one assembly step of the block; each argument is a distinct file's text or a caller fact, and
# each step of the assembly keeps its own intermediate.
# pylint: disable-next=too-many-arguments,too-many-positional-arguments,too-many-locals
def build_compass(
    map_dir: str,
    today: str,
    log_text: str | None,
    destination_files: list[tuple[str, str]],
    readme_text: str | None,
    parking_text: str | None,
    repository_names: list[str],
    read_warnings: list[str] | None = None,
    parents: dict[str, str] | None = None,
) -> dict:
    """The `compass` block for a map directory that exists, from the text of its files.

    `destination_files` is `(filename, text)` in the order to report them; a later file reusing an earlier id
    is skipped with a warning. `read_warnings` are the shell's (a file it could not read) and lead the list.
    `parents` is `{worktree: repository}`, see `map_repositories`.
    """
    moment = datetime.date.fromisoformat(today)
    warnings = list(read_warnings or [])
    destinations = collect_destinations(destination_files, warnings)
    dues, due_warnings = parse_due_dates(readme_text, [d["id"] for d in destinations])
    warnings.extend(due_warnings)
    for destination in destinations:
        destination["due"] = dues.get(destination["id"])
        destination["state"] = destination_state(destination, moment)
    leg = parse_leg(log_text)
    return {
        "found": True,
        "map_dir": map_dir,
        "today": today,
        "leg": leg,
        "destinations": destinations,
        "parking": parse_parking(parking_text, moment),
        "repositories": map_repositories(destinations, repository_names, leg, parents),
        "warnings": warnings,
    }
