"""The impure rungs of extension resolution: finding files and probing requirements.

Everything that touches the filesystem lives here so `core.py` can stay pure and be pinned by an
AST import walk. Nothing in this module decides policy -- precedence, liveness and parsing are
`core`'s, and this module only answers "does this path exist" and "is this requirement satisfied".
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from borg_core import paths
from borg_core.extensions import core


def layer_paths(kind: str, name: str, hook: str, root: str) -> dict:
    """The two candidate paths for one extension, keyed by layer.

    `kind` is `skill-extensions` or `agent-extensions`. The machine layer is deliberately resolved
    through `paths` rather than `$HOME` directly, because a shell variable is not an environment
    variable at the zsh->Python boundary and this module is invoked both ways.
    """
    machine = Path(paths.borg_dir()) / "extensions" / kind / name / f"{hook}.md"
    repository = Path(root) / ".borg" / kind / name / f"{hook}.md"
    return {core.MACHINE: str(machine), core.REPOSITORY: str(repository)}


def read_layers(kind: str, name: str, hook: str, root: str) -> dict:
    """`{layer: parsed}` for whichever of the two layers exists. Missing files are simply absent.

    A file that exists but cannot be read is treated as absent rather than raising: the loader's
    standing contract is to skip silently, and an unreadable personal extension must not break the
    skill that reads it.
    """
    out: dict[str, dict] = {}
    for layer, path in layer_paths(kind, name, hook, root).items():
        try:
            text = Path(path).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        parsed = core.parse(text)
        parsed["path"] = path
        out[layer] = parsed
    return out


def _skill_present(target: str) -> bool:
    """Is `<plugin>:<name>` installed as a skill anywhere in the plugin tree?

    Matches on the directory layout Claude Code actually uses -- `.../<plugin>/<version>/skills/
    <name>/SKILL.md` -- rather than shelling to a CLI, because this runs inside `borg doctor` and a
    subprocess per probe is a cost the caller pays on every invocation.
    """
    plugin, _, skill = target.partition(":")
    if not plugin or not skill:
        return False
    root = Path.home() / ".claude" / "plugins" / "cache"
    if not root.is_dir():
        return False
    try:
        return any(root.glob(f"*/{plugin}/*/skills/{skill}/SKILL.md"))
    except OSError:
        return False


def probe(parsed: dict) -> bool | None:
    """Is this extension's declared requirement satisfied? `None` when there is nothing to probe.

    `None` is not a failure -- it is "this file did not declare a checkable requirement", which
    `core.status` reports as `unprobed`. Conflating it with `False` would call a perfectly good
    prose extension dead.
    """
    kind, target = core.requirement(parsed)
    if not kind:
        return None
    if kind == "command":
        return shutil.which(target) is not None
    return _skill_present(target)


def repo_root(start: str = "") -> str:
    """The git root containing `start`, else `start` itself. No subprocess: walks for `.git`."""
    here = Path(start or os.getcwd()).resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists():
            return str(candidate)
    return str(here)


def survey(repo: str = "") -> list[dict]:
    """Every `prefer-tool` extension discoverable from here, with its layer, winner and liveness.

    This is what `borg doctor` prints. It reports DEAD and UNPROBED preferences because a preference
    that silently does nothing is the failure mode this type was designed against -- per the cairn
    decommission, an uninstrumented capture surface hides its own failure.
    """
    root = repo_root(repo)
    rows: list[dict] = []
    for kind, names in (("skill-extensions", _dirs(kind="skill-extensions", root=root)),
                        ("agent-extensions", _dirs(kind="agent-extensions", root=root))):
        for name in names:
            for hook in (*core.PROSE_HOOKS, "brief"):
                layers = read_layers(kind, name, hook, root)
                if not layers:
                    continue
                win = core.winner(layers)
                parsed = layers.get(win, {})
                if parsed.get("type") != core.TYPE_PREFER_TOOL:
                    continue
                rows.append({
                    "kind": kind,
                    "name": name,
                    "hook": hook,
                    "layer": win,
                    "prefer": parsed.get("prefer", ""),
                    "instead_of": parsed.get("instead_of", ""),
                    "requires": parsed.get("requires", ""),
                    "status": core.status(parsed, probe(parsed)),
                    "conflicted": core.conflicted(layers),
                    "path": parsed.get("path", ""),
                })
    return rows


def _dirs(kind: str, root: str) -> list[str]:
    """Extension subject names present in either layer, deduped and sorted."""
    found: set[str] = set()
    for base in (Path(paths.borg_dir()) / "extensions" / kind, Path(root) / ".borg" / kind):
        try:
            found.update(p.name for p in base.iterdir() if p.is_dir())
        except OSError:
            continue
    return sorted(found)
