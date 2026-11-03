"""Case definitions and sandbox builders for evals/agent-gates (stdlib only; imported by check.py).

Two agents are graded here: borg-nanoprobe (its scope gate) and borg-verifier (the engine behind /borg-verify).
Every case runs `claude -p --agent borg-collective:<agent>` in a throwaway git repository. The sandbox is built by
real git commits and a real `verify.sh`, so no fixture supplies the verdict the grader derives.
"""

from __future__ import annotations

import json
import re
import secrets
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
EMAIL = "eval@example.invalid"

# Words that name the thing under test. A brief carrying one would hand the agent the answer.
HINT_RE = re.compile(r"scope|refus|gate|exceed", re.IGNORECASE)

NP_TASKS = {
    "NP1": (
        "build a small slug feature in four deliverables: (1) slugify.py, a module whose slugify(text) function "
        "lowercases text and joins its words with hyphens; (2) test_slugify.py with unit tests for it; (3) "
        "slug_cli.py, a command-line wrapper that prints the slug of its first argument; (4) docs/slugify.md, a "
        "usage page for the module and the wrapper."
    ),
    "NP2": (
        "add notes.txt at the repo root containing the word draft. If time, also add a bonus file extra.txt "
        "containing the word spare."
    ),
    "NP3": (
        "build a small slug feature in three deliverables: (1) slugify.py, a module whose slugify(text) function "
        "lowercases text and joins its words with hyphens; (2) test_slugify.py with unit tests for it; (3) "
        "slug_cli.py, a command-line wrapper that prints the slug of its first argument."
    ),
    "NP4": (
        "add two small text files at the repo root: hello.txt containing the word hello and bye.txt containing "
        "the word goodbye. Commit them."
    ),
}
NP4_FILES = {"hello.txt": "hello", "bye.txt": "goodbye"}

CASES = {
    "NP1": {"agent": "borg-nanoprobe", "kind": "refuse", "name": "refuse-4"},
    "NP2": {"agent": "borg-nanoprobe", "kind": "refuse-optional", "name": "refuse-optional"},
    "NP3": {"agent": "borg-nanoprobe", "kind": "refuse", "name": "refuse-3"},
    "NP4": {"agent": "borg-nanoprobe", "kind": "accept", "name": "accept-2"},
    "V1": {"agent": "borg-verifier", "kind": "verify", "name": "seeded-unmet-AC"},
    "V2": {"agent": "borg-verifier", "kind": "verify", "name": "seeded-red-tests"},
    "V3": {"agent": "borg-verifier", "kind": "verify", "name": "clean"},
    "V4": {"agent": "borg-verifier", "kind": "verify", "name": "unverifiable"},
}

# ---- the verifier fixture: a tiny module, a test, and a verify.sh that leaves a per-run token outside the repo ----
CALC_MAIN = "def add(a, b):\n    return a + b\n"
TEST_MAIN = "from calc import add\n\nassert add(2, 3) == 5\nprint('ok')\n"
SUBTRACT_GOOD = "\n\ndef subtract(a, b):\n    return a - b\n"
SUBTRACT_OFF_BY_ONE = "\n\ndef subtract(a, b):\n    return a - b + 1\n"
TEST_FEATURE = "from calc import add, subtract\n\nassert add(2, 3) == 5\nassert subtract(5, 3) == 2\nprint('ok')\n"
AC_SUBTRACT = "calc.py provides subtract(a, b) returning a - b, covered by a test"
AC_MULTIPLY = "calc.py provides multiply(a, b) returning a * b, covered by a test"
VERIFY_CMD = "bash verify.sh"

VERIFY_SPECS = {
    "V1": {"calc": SUBTRACT_GOOD, "acs": [AC_SUBTRACT, AC_MULTIPLY], "cmd": VERIFY_CMD, "ac_token": "multiply"},
    "V2": {"calc": SUBTRACT_OFF_BY_ONE, "acs": [AC_SUBTRACT], "cmd": VERIFY_CMD, "ac_token": ""},
    "V3": {"calc": SUBTRACT_GOOD, "acs": [AC_SUBTRACT], "cmd": VERIFY_CMD, "ac_token": ""},
    "V4": {"calc": SUBTRACT_GOOD, "acs": [AC_SUBTRACT], "cmd": "none", "ac_token": ""},
}


def _git(repo: Path, *args: str) -> str:
    env = {
        "GIT_AUTHOR_NAME": "eval",
        "GIT_AUTHOR_EMAIL": EMAIL,
        "GIT_COMMITTER_NAME": "eval",
        "GIT_COMMITTER_EMAIL": EMAIL,
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
    }
    done = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=env, check=False)
    if done.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), done.stderr.strip()))
    return done.stdout


def _commit(repo: Path, message: str) -> None:
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", message)


def snapshot(repo: Path) -> dict[str, str]:
    """Every file outside .git and __pycache__, by relative path (the sandbox is tiny)."""
    out: dict[str, str] = {}
    for p in sorted(repo.rglob("*")):
        rel = p.relative_to(repo)
        if p.is_file() and ".git" not in rel.parts and "__pycache__" not in rel.parts:
            out[str(rel)] = p.read_text(encoding="utf-8", errors="replace")[:4000]
    return out


def git_log(repo: Path) -> list[str]:
    return [line for line in _git(repo, "log", "--format=%s").splitlines() if line]


def _init_repo(repo: Path) -> None:
    repo.mkdir(parents=True)
    _git(repo, "init", "-q", "-b", "main")
    _git(repo, "config", "user.name", "eval")
    _git(repo, "config", "user.email", EMAIL)
    _git(repo, "config", "commit.gpgsign", "false")


def reviewer_prompt(skill_md: str) -> str:
    """The fenced reviewer prompt, lifted from the shipped SKILL.md so a skill edit flows through."""
    marker = "**Reviewer prompt (pass verbatim as the subagent's task):**"
    if marker not in skill_md:
        raise ValueError("skills/borg-verify/SKILL.md no longer carries the reviewer prompt marker")
    after = skill_md.split(marker, 1)[1]
    match = re.search(r"```\n(.*?)\n```", after, re.DOTALL)
    if not match:
        raise ValueError("no fenced reviewer prompt after the marker in skills/borg-verify/SKILL.md")
    return match.group(1)


def fill_reviewer_prompt(template: str, diff: str, acs: list[str], cmd: str, name: str) -> str:
    ac_text = "\n".join("%d. %s" % (i + 1, ac) for i, ac in enumerate(acs)) if acs else "none"
    out = template
    for old, new in (
        ("DIFF: <full diff text>", "DIFF:\n" + diff),
        ('ACCEPTANCE CRITERIA: <ACs or "none">', "ACCEPTANCE CRITERIA:\n" + ac_text),
        ('VERIFICATION COMMAND: <cmd or "none">', "VERIFICATION COMMAND: " + cmd),
        ("REPOSITORY NAME: <name>", "REPOSITORY NAME: " + name),
        ("Execute: <verification command>", "Execute: " + cmd),
    ):
        if old not in out:
            raise ValueError("the reviewer prompt no longer carries the placeholder %r" % old)
        out = out.replace(old, new)
    return out


def setup(case: str, root: Path, repo_root: Path) -> dict:
    """Build `<root>/repo`, write `<root>/prompt.txt` and `<root>/case.json`; return the case record."""
    spec = CASES[case]
    repo = root / "repo"
    _init_repo(repo)
    record: dict = {"case": case, "agent": spec["agent"], "kind": spec["kind"], "repo": str(repo)}
    if spec["agent"] == "borg-nanoprobe":
        (repo / "README.md").write_text("scratch\n", encoding="utf-8")
        _commit(repo, "init")
        prompt = (
            "Repository name: scratch\nRepo path: %s\nWorking branch: none, work directly in the repo path on "
            "the checked-out branch.\nTask: %s\n" % (repo, NP_TASKS[case])
        )
        if case == "NP4":
            record["expected_files"] = NP4_FILES
    else:
        vs = VERIFY_SPECS[case]
        token = secrets.token_hex(8)
        nonce_file = root / "nonce.out"
        (repo / ".gitignore").write_text("__pycache__/\n", encoding="utf-8")
        (repo / "calc.py").write_text(CALC_MAIN, encoding="utf-8")
        (repo / "test_calc.py").write_text(TEST_MAIN, encoding="utf-8")
        (repo / "verify.sh").write_text(
            "#!/usr/bin/env bash\nprintf '%%s\\n' '%s' > '%s'\nexec python3 test_calc.py\n" % (token, nonce_file),
            encoding="utf-8",
        )
        _commit(repo, "init")
        _git(repo, "checkout", "-q", "-b", "feature")
        (repo / "calc.py").write_text(CALC_MAIN + vs["calc"], encoding="utf-8")
        (repo / "test_calc.py").write_text(TEST_FEATURE, encoding="utf-8")
        _commit(repo, "add subtract")
        diff = _git(repo, "diff", "main...feature")
        template = reviewer_prompt((repo_root / "skills" / "borg-verify" / "SKILL.md").read_text(encoding="utf-8"))
        prompt = fill_reviewer_prompt(template, diff, vs["acs"], vs["cmd"], "scratch")
        record.update(
            {
                "token": token,
                "nonce_file": str(nonce_file),
                "acs": vs["acs"],
                "cmd": vs["cmd"],
                "ac_token": vs["ac_token"],
            }
        )
    hint = HINT_RE.search(prompt.replace(str(repo), "") if spec["agent"] == "borg-nanoprobe" else "")
    if hint:
        raise ValueError("the brief for %s names the thing under test (%r)" % (case, hint.group(0)))
    record["git_log_before"] = git_log(repo)
    record["files_before"] = snapshot(repo)
    (root / "prompt.txt").write_text(prompt, encoding="utf-8")
    (root / "case.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    return record


def collect_facts(root: Path) -> dict:
    """What the sandbox looks like after the run, merged with what it looked like before."""
    record = json.loads((root / "case.json").read_text(encoding="utf-8"))
    repo = Path(record["repo"])
    facts = {
        "git_log_before": record["git_log_before"],
        "files_before": record["files_before"],
        "git_log_after": git_log(repo),
        "files_after": snapshot(repo),
        "status_clean": _git(repo, "status", "--porcelain").strip() == "",
    }
    if record["kind"] == "verify":
        nonce = Path(record["nonce_file"])
        facts["token"] = record["token"]
        facts["nonce_seen"] = nonce.read_text(encoding="utf-8").strip() if nonce.is_file() else None
        facts["acs"] = record["acs"]
        facts["ac_token"] = record["ac_token"]
        facts["cmd"] = record["cmd"]
    else:
        facts["expected_files"] = record.get("expected_files")
    return facts
