"""Skill trigger suites, the I/O half (pure logic: borg_core/evals/triggers.py). Called by evals/triggers/*.sh.

    python3 -m borg_core.evals.triggers_cli validate [--dir evals/triggers] [--skills skills] [--complete]
    python3 -m borg_core.evals.triggers_cli plugins                      # enabled plugin names, one per line
    python3 -m borg_core.evals.triggers_cli grade --suite F --id ID --stream F --mode M --plugin-dir D
                                                  [--expect-file F] [--verdicts F]
    python3 -m borg_core.evals.triggers_cli report --verdicts F --dir D [--misfires F]
    python3 -m borg_core.evals.triggers_cli listing [--skills skills]

Exit codes: 0 fine, 1 a suite or a verdict problem, 2 a malformed request, 3 ABORT (the run's plugin list does not
match its mode: no verdict is graded, the caller records an `error`, never a pass).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

from borg_core.evals import triggers

ABORT = 3
Runner = Callable[[list[str]], str]


def _run(argv: list[str]) -> str:
    return subprocess.run(argv, capture_output=True, text=True, check=False, timeout=60).stdout


def enabled_plugin_names(runner: Runner = _run) -> list[str]:
    """Names of the plugins `claude plugin list --json` reports enabled in any scope, sorted and distinct."""
    try:
        listed = json.loads(runner(["claude", "plugin", "list", "--json"]))
    except (ValueError, OSError, subprocess.SubprocessError):
        return []
    enabled = [p for p in listed if isinstance(p, dict) and p.get("enabled") and p.get("id")]
    names = {str(p["id"]).split("@", maxsplit=1)[0] for p in enabled}
    return sorted(names)


def frontmatter(path: Path) -> dict[str, str]:
    """The top-level `key: value` lines of a SKILL.md frontmatter (values unquoted); enough for name and flags."""
    parts = path.read_text(encoding="utf-8").split("---")
    fields: dict[str, str] = {}
    for line in parts[1].splitlines() if len(parts) > 2 else []:
        match = re.match(r"^([A-Za-z-]+):\s*(.*)$", line)
        if match:
            fields[match[1]] = match[2].strip().strip('"')
    return fields


def self_firing_skills(skills_dir: Path) -> dict[str, dict[str, str]]:
    """Skills the model may load: no `disable-model-invocation: true`. Name to frontmatter."""
    found = {}
    for path in sorted(skills_dir.glob("*/SKILL.md")):
        fields = frontmatter(path)
        if fields.get("disable-model-invocation") != "true":
            found[path.parent.name] = fields
    return found


def listing_size(skills_dir: Path) -> tuple[int, int]:
    """(listed skills, characters) of the model's listing: one `- borg-collective:<name>: <description>` per skill."""
    lines = [f"- {triggers.PLUGIN}:{n}: {f.get('description', '')}" for n, f in self_firing_skills(skills_dir).items()]
    return len(lines), sum(len(line) for line in lines)


def load_suite(path: Path) -> Any:
    """The parsed JSON of one suite file."""
    return json.loads(path.read_text(encoding="utf-8"))


def cmd_validate(args: argparse.Namespace) -> int:
    """Every self-firing skill has an admissible suite, and no suite exists for a skill the model cannot load."""
    suites = {p.stem: p for p in sorted(Path(args.dir).glob("*.json"))}
    firing = self_firing_skills(Path(args.skills))
    problems: list[str] = []
    for skill in sorted(set(firing) - set(suites) if args.complete else []):
        problems.append(f"{skill}: self-firing, no suite at {args.dir}/{skill}.json")
    for skill, path in suites.items():
        if skill not in firing:
            problems.append(f"{skill}: a suite for a skill that is not self-firing")
            continue
        try:
            cases = load_suite(path)
        except ValueError as exc:
            problems.append(f"{skill}: not JSON ({exc})")
            continue
        found = triggers.validate_suite(skill, cases)
        problems += found
        if not found:
            near = sum(1 for c in cases if not c["should_fire"])
            print(f"suite {skill}: {len(cases)} cases, {near} near-misses")
    for line in problems:
        print(f"PROBLEM {line}")
    return 1 if problems else 0


def cmd_grade(args: argparse.Namespace) -> int:
    """Abort on a plugin-list mismatch, else grade one case and append the verdict row."""
    skill = Path(args.suite).stem
    case = next((c for c in load_suite(Path(args.suite)) if c.get("id") == args.id), None)
    if case is None:
        print(f"no case {args.id} in {args.suite}", file=sys.stderr)
        return 2
    parsed = triggers.parse_stream(Path(args.stream).read_text(encoding="utf-8", errors="replace"))
    expected = None
    if args.expect_file:
        expected = [n for n in Path(args.expect_file).read_text(encoding="utf-8").split() if n]
    aborts = triggers.plugin_problems(parsed["init"], args.mode, args.plugin_dir, expected)
    if aborts:
        print("ABORT " + "; ".join(aborts))
        return ABORT
    verdict, reason = triggers.grade(skill, case, parsed["invoked"])
    row = {"mode": args.mode, "skill": skill, "id": args.id, "should_fire": case["should_fire"], "verdict": verdict}
    row.update({"reason": reason, "invoked": parsed["invoked"], "query": case["query"]})
    row["competitor"] = case.get("competitor")
    if args.verdicts:
        with open(args.verdicts, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    print(f"VERDICT {verdict} {reason}".rstrip())
    return 0 if verdict == "pass" else 1


def cmd_report(args: argparse.Namespace) -> int:
    """Accuracy per skill and mode with Wilson intervals; the misfires (with their split) go to `--misfires`."""
    rows = [json.loads(line) for line in Path(args.verdicts).read_text(encoding="utf-8").splitlines() if line.strip()]
    misfires: dict[str, list[dict[str, Any]]] = {}
    for mode in triggers.MODES:
        for skill in sorted({r["skill"] for r in rows}):
            mine = [r for r in rows if r["mode"] == mode and r["skill"] == skill]
            if not mine:
                continue
            print(f"{mode:9} {skill:24} {_fmt(triggers.summarize(mine))}")
    for skill in sorted({r["skill"] for r in rows}):
        cases = load_suite(Path(args.dir) / f"{skill}.json")
        train, _held = triggers.split_cases(cases)
        train_ids = {c["id"] for c in train}
        for r in rows:
            if r["skill"] == skill and r["verdict"] == "fail":
                split = "train" if r["id"] in train_ids else "held-out"
                keep = ("mode", "id", "should_fire", "query", "competitor", "invoked", "reason")
                misfires.setdefault(skill, []).append({**{k: r[k] for k in keep}, "split": split})
    if args.misfires:
        Path(args.misfires).write_text(json.dumps(misfires, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


def _fmt(summary: dict[str, Any]) -> str:
    parts = []
    for name in ("all", "recall", "specificity"):
        part = summary[name]
        low, high = part["interval"] or (0.0, 0.0)
        parts.append(f"{name} {part['k']}/{part['n']} [{low:.2f},{high:.2f}]")
    return "  ".join(parts) + (f"  unscored {summary['unscored']}" if summary["unscored"] else "")


def _parser() -> argparse.ArgumentParser:
    # JUSTIFICATION: argparse's builder API is a chain by design
    p = argparse.ArgumentParser(prog="borg_core.evals.triggers_cli", description=__doc__.splitlines()[0])
    # JUSTIFICATION: argparse's builder API is a chain by design
    sub = p.add_subparsers(dest="cmd", required=True)  # pylint: disable=clean-arch-demeter
    # JUSTIFICATION: argparse's builder API is a chain by design
    v = sub.add_parser("validate")  # pylint: disable=clean-arch-demeter
    v.add_argument("--dir", default="evals/triggers")
    v.add_argument("--skills", default="skills")
    v.add_argument("--complete", action="store_true", help="every self-firing skill must have a suite")
    # JUSTIFICATION: argparse's builder API is a chain by design
    sub.add_parser("plugins")  # pylint: disable=clean-arch-demeter
    # JUSTIFICATION: argparse's builder API is a chain by design
    g = sub.add_parser("grade")  # pylint: disable=clean-arch-demeter
    g.add_argument("--suite", required=True)
    g.add_argument("--id", required=True)
    g.add_argument("--stream", required=True)
    g.add_argument("--mode", required=True, choices=triggers.MODES)
    g.add_argument("--plugin-dir", required=True)
    g.add_argument("--expect-file")
    g.add_argument("--verdicts")
    # JUSTIFICATION: argparse's builder API is a chain by design
    r = sub.add_parser("report")  # pylint: disable=clean-arch-demeter
    r.add_argument("--verdicts", required=True)
    r.add_argument("--dir", default="evals/triggers")
    r.add_argument("--misfires")
    # JUSTIFICATION: argparse's builder API is a chain by design
    sub.add_parser("listing").add_argument("--skills", default="skills")  # pylint: disable=clean-arch-demeter
    return p


def main(argv: list[str] | None = None) -> int:
    """CLI entry; see the module docstring for the subcommands and exit codes."""
    args = _parser().parse_args(argv)
    if args.cmd == "plugins":
        print("\n".join(enabled_plugin_names()))
        return 0
    if args.cmd == "listing":
        count, chars = listing_size(Path(args.skills))
        print(f"listed {count} skills, {chars} characters")
        return 0
    return {"validate": cmd_validate, "grade": cmd_grade, "report": cmd_report}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
