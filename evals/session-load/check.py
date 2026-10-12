"""Grade ONE headless session's stream-json against the authored exactly-once numbers.

Stdlib only. Reads what the SESSION reported (the `init` event's `skills` and `plugins`, and the
`hook_started` events), not what an install path looks like. The one filesystem read is the NON-borg
hook baseline: `hook_started` carries the event name but not the command, so the borg share of an
event's count is the observed total minus the hooks other plugins and settings.json register.

Output is `CHECK pass|fail <skills|hooks> <message>` lines, one per assertion, then one `COUNT` line
per mode. The caller (run.sh) turns those into PASS/FAIL and owns the per-mode execution floors.

Exit: 0 clean, 1 an assertion failed, 3 the premise is broken (no init event in the stream).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

# AUTHORED NUMBERS: borg-owned hook commands per lifecycle event, as scripts/build-plugin.sh writes them
# into the plugin's hooks.json (tests/session_load_floor.bats pins these against that file). Only the
# events a headless `-p` session fires on its own are listed; Notification and the tool events need
# a TTY or a tool call.
AUTHORED_HOOKS = {"SessionStart": 1, "Stop": 2}
PLUGIN_NAME = "borg-collective"


def _load_events(path: Path) -> list[dict]:
    events = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                events.append(json.loads(line))
            except ValueError:
                continue
    return events


# Claude Code bundles a skill with this bare name; a bare `simplify` in the session list is the built-in unless
# an extension symlink of that name exists under <claude-home>/skills.
BUILTIN_SKILLS = {"simplify"}


def authored_skills(repo: Path) -> list[str]:
    """Skills a session lists. `user-invocable: false` skills are hidden from the list by design."""
    names = []
    for p in (repo / "skills").glob("*/SKILL.md"):
        head = p.read_text(encoding="utf-8", errors="replace").split("---")[1:2]
        if head and "user-invocable: false" in head[0]:
            continue
        names.append(p.parent.name)
    return sorted(names)


def borg_scripts(repo: Path) -> set[str]:
    return {p.name for p in (repo / "hooks").glob("*.sh")}


def _commands(hooks: object) -> dict[str, list[str]]:
    """`{event: [command basenames]}` from either a settings `hooks` record or a plugin hooks.json."""
    out: dict[str, list[str]] = {}
    if not isinstance(hooks, dict):
        return out
    if isinstance(hooks.get("hooks"), dict):
        hooks = hooks["hooks"]
    for event, blocks in hooks.items():
        for block in blocks if isinstance(blocks, list) else []:
            for h in block.get("hooks", []) if isinstance(block, dict) else []:
                cmd = h.get("command") if isinstance(h, dict) else None
                if isinstance(cmd, str):
                    out.setdefault(event, []).append(cmd.split()[0].rstrip('"').split("/")[-1] if cmd else "")
    return out


def _read_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def check_skills(init: dict, repo: Path, claude_home: Path) -> list[tuple[bool, str]]:
    seen = Counter()
    for name in init.get("skills", []):
        base = name.split(":")[-1]
        if ":" not in name and base in BUILTIN_SKILLS and not (claude_home / "skills" / base).exists():
            continue
        seen[base] += 1
    wanted = authored_skills(repo)
    results = []
    present = 0
    for skill in wanted:
        n = seen.get(skill, 0)
        if n == 1:
            present += 1
            results.append((True, f"skill {skill}: registered once"))
        elif n == 0:
            results.append((False, f"skill {skill}: shortfall, observed 0 of 1 authored (installed copy lacks it)"))
        else:
            results.append((False, f"skill {skill}: surplus, observed {n} of 1 authored (registered {n} times)"))
    plugins = [p for p in init.get("plugins", []) if p.get("name") == PLUGIN_NAME]
    if len(plugins) == 1:
        results.append((True, f"plugin {PLUGIN_NAME}: loaded once"))
    else:
        paths = ", ".join(str(p.get("path")) for p in plugins) or "none"
        results.append((False, f"plugin {PLUGIN_NAME}: observed {len(plugins)} of 1 authored ({paths})"))
    results.append((present == len(wanted), f"skills: observed {present} of {len(wanted)} authored registered exactly once"))
    return results


def check_hooks(events: list[dict], init: dict, repo: Path, claude_home: Path) -> list[tuple[bool, str]]:
    own = borg_scripts(repo)
    fired = Counter(e.get("hook_event") for e in events if e.get("subtype") == "hook_started")
    others: Counter = Counter()
    literal: dict[str, list[str]] = {}
    sources = [(claude_home / "settings.json", True)]
    for p in init.get("plugins", []):
        sources.append((Path(str(p.get("path", ""))) / "hooks" / "hooks.json", p.get("name") == PLUGIN_NAME))
    for path, borg_ok in sources:
        raw = _read_json(path)
        if raw is None:
            continue
        for event, cmds in _commands(
            raw.get("hooks") if path.name == "settings.json" and isinstance(raw, dict) else raw
        ).items():
            for cmd in cmds:
                if cmd in own:
                    if path.name == "settings.json":
                        literal.setdefault(event, []).append(cmd)
                else:
                    others[event] += 1
    results = []
    for event, authored in sorted(AUTHORED_HOOKS.items()):
        observed = fired.get(event, 0) - others[event]
        extra = literal.get(event, [])
        hint = f" (literal settings.json entries: {', '.join(extra)})" if extra else ""
        if observed == authored:
            results.append((True, f"hooks {event}: fired {observed} of {authored} authored borg hooks"))
        elif observed < authored:
            results.append((False, f"hooks {event}: shortfall, fired {observed} of {authored} authored{hint}"))
        else:
            results.append((False, f"hooks {event}: surplus, fired {observed} of {authored} authored{hint}"))
    return results


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--events", required=True, type=Path)
    ap.add_argument("--repo", required=True, type=Path)
    ap.add_argument("--claude-home", required=True, type=Path)
    ap.add_argument("--mode", choices=("skills", "hooks", "both"), default="both")
    args = ap.parse_args(argv)

    events = _load_events(args.events)
    init = next((e for e in events if e.get("subtype") == "init"), None)
    if init is None:
        print(
            f"premise broken: no init event in {args.events} -- the session never started; rerun with claude logged in",
            file=sys.stderr,
        )
        return 3
    rows: list[tuple[str, bool, str]] = []
    if args.mode in ("skills", "both"):
        rows += [("skills", ok, msg) for ok, msg in check_skills(init, args.repo, args.claude_home)]
    if args.mode in ("hooks", "both"):
        rows += [("hooks", ok, msg) for ok, msg in check_hooks(events, init, args.repo, args.claude_home)]
    for mode, ok, msg in rows:
        print(f"CHECK {'pass' if ok else 'fail'} {mode} {msg}")
    return 0 if all(ok for _, ok, _ in rows) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
