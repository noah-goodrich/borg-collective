"""I/O for the reader census: scanning a tree, and reading the declared table."""

from __future__ import annotations

import re
from pathlib import Path

from borg_core.census import core

TOKEN = re.compile(r"\.borg/[a-z][a-z-]*")

# The surfaces a store can be referenced FROM. Executable code and CLAUDE.md, and nothing else --
# a mention in docs/, a directive or a checkpoint is history or argument, not a live promise, and
# treating those as references would make every retro that DESCRIBES a retired store fail the gate
# that retired it.
CODE_DIRS = ("borg_core", "lib", "hooks", "bin")

# THE GATE'S OWN IMPLEMENTATION IS EXCLUDED, and the precedent is `tests/prose_contracts.bats`'s
# retired-annotation case, which excludes `lib/promote-next.sh` by path because that file names the
# retired form ON PURPOSE, in the docstring recording why it was retired -- "a historical note is
# not a live convention". Same shape here: this package's prose has to be free to name
# `.borg/knowledge` and the other stores it governs, and a census that discovered its own
# explanation would report the document as the defect. Excluded BY PATH rather than by a cleverer
# pattern, for the same reason that case gives: a pattern smart enough to tell an explanation from a
# reference is a pattern that will eventually be wrong about both.
EXCLUDED = ("borg_core/census",)
CODE_GLOBS = ("*.zsh",)
DOCS = ("CLAUDE.md",)

ROW = re.compile(
    r"^\|\s*`(?P<token>\.borg/[a-z][a-z-]*)`\s*\|\s*(?P<kind>\w+)\s*\|\s*(?P<reader>[^|]+?)\s*\|"
)


def _scan(paths: list[Path]) -> set[str]:
    tokens: set[str] = set()
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        tokens.update(TOKEN.findall(text))
    return tokens


def _code_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for directory in CODE_DIRS:
        base = root / directory
        if base.is_dir():
            files.extend(
                p
                for p in base.rglob("*")
                if p.is_file()
                and p.suffix != ".pyc"
                and not any(part in p.as_posix() for part in EXCLUDED)
            )
    for pattern in CODE_GLOBS:
        files.extend(root.glob(pattern))
    return files


def discover(root: Path) -> dict[str, set[str]]:
    """Every `.borg/<name>` token referenced under `root`, mapped to the surfaces it appears on."""
    found: dict[str, set[str]] = {}
    for token in _scan(_code_files(root)):
        found.setdefault(token, set()).add("code")
    for token in _scan([root / name for name in DOCS]):
        found.setdefault(token, set()).add("docs")
    return found


def declared(census_file: Path) -> dict[str, dict[str, str]]:
    """Parse the census table. Rows are `| \\`.borg/x\\` | kind | reader | ... |`.

    A regex over a markdown table rather than a data file, deliberately: the census is a document a
    person reads when deciding whether to add a store, and a JSON blob beside a prose explanation
    would be two artifacts that can disagree. The table IS the explanation.
    """
    rows: dict[str, dict[str, str]] = {}
    if not census_file.is_file():
        return rows
    for line in census_file.read_text(encoding="utf-8").splitlines():
        match = ROW.match(line.strip())
        if match:
            rows[match["token"]] = {
                "kind": match["kind"],
                "reader": match["reader"].strip().strip("`"),
            }
    return rows


def reader_mentions(root: Path, rows: dict[str, dict[str, str]]) -> dict[str, bool]:
    """Whether each declared reader file exists AND mentions its own store."""
    mentions: dict[str, bool] = {}
    for token, row in rows.items():
        reader = row.get("reader", core.NO_READER)
        if reader == core.NO_READER or row.get("kind") == core.KIND_PROSE:
            mentions[token] = False
            continue
        path = root / reader
        mentions[token] = path.is_file() and token in path.read_text(
            encoding="utf-8", errors="replace"
        )
    return mentions
