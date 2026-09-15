"""AC9: an evidence annotation can never cause command execution from file content.

TWO ASSERTIONS PER CASE, AND THE SECOND IS THE ONE THAT MATTERS. "Rejected" alone would pass even if
the annotation had been handed to a shell first and the verdict computed afterwards. Every case here
therefore also pins that NOTHING FORKED, by wrapping `borg_core.proc.run_background` -- which
`borg_core/proc.py`'s own header establishes as the single place in `borg_core` where a subprocess is
constructed at all, and which `test_grid.py`'s `record_forks` probe already uses for the same reason.

THE PLAN FILE IS WRITTEN TO DISK AND PARSED, not passed in as a string. The attack surface under
test is "a document a human edits and a nanoprobe writes", so the bytes have to travel the real
route: file -> `shell.read_text` -> `core.parse_criteria` -> `core.validate_annotation`.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from borg_core.planstate import core, derive as derive_mod

# Each of these is a real shell construct. Under `shell=True`, or under any `" ".join(argv)`, the
# first would delete a directory, the second and third would execute `id`, the fourth would pipe,
# and the fifth would smuggle a second command past a `$`-anchored regex on the newline.
CRAFTED = [
    "path:docs/x.md; rm -rf /tmp/borg-planstate-canary",
    "pytest:borg_core/`id`/",
    "bats:tests/$(id).bats",
    "path:docs/x.md | tee /tmp/pwned",
    "pytest:borg_core/ && id",
    "path:docs/x.md > /tmp/pwned",
    "pr:o/r#1; id",
    "pr:$(id)/r#1",
    "path:../../../../etc/passwd",
    "path:/etc/passwd",
]

# EMBEDDED IN A FILE THESE ARE NOT THE SAME STRING -- a newline splits the sub-bullet in two and the
# parser never sees the tail -- so they are exercised against the validator DIRECTLY. The newline
# case is the one `\Z`-rather-than-`$` anchoring exists for: `$` matches before a trailing newline,
# so a `$`-anchored pattern would accept `path:docs/x.md\n; id` whole.
CRAFTED_DIRECT = CRAFTED + [
    "path:docs/x.md\n; id",
    "pytest:borg_core/\nid",
]


@pytest.fixture(name="forks")
def _forks(monkeypatch):
    """Every subprocess construction in `borg_core`, recorded. Returns the (empty, if all is well)
    list of argvs. `run_background` is wrapped rather than `subprocess.Popen`, because that is the
    chokepoint `proc.py` documents and `run_capture` composes."""
    seen: list[list[str]] = []

    def _record(argv):
        seen.append(list(argv))
        return None

    monkeypatch.setattr("borg_core.proc.run_background", _record)
    return seen


def _plan_with(root: Path, annotation: str) -> Path:
    plan = root / "PROJECT_PLAN.md"
    plan.write_text(f"- [ ] AC1 crafted.\n  - Evidence: {annotation}\n", encoding="utf-8")
    return plan


@pytest.mark.parametrize("annotation", CRAFTED)
def test_a_crafted_annotation_is_rejected_as_unknown_and_forks_nothing(annotation, tmp_path, forks):
    plan = _plan_with(tmp_path, annotation)
    report = derive_mod.derive(plan, tmp_path)
    row = report["criteria"][0]
    assert row["verdict"] == core.UNKNOWN, row
    assert row["kind"] == ""
    assert row["would_flip"] is False
    assert row["evidence"], "a rejection must record why"
    assert forks == [], f"{annotation!r} reached a subprocess"


@pytest.mark.parametrize("annotation", CRAFTED_DIRECT)
def test_the_validator_itself_refuses_every_crafted_annotation(annotation):
    # The gate, asserted directly as well as through `derive`, so a future caller that forgets to
    # route through `derive` still has the rule pinned at the only place it lives.
    assert core.validate_annotation(annotation)["ok"] is False


def test_a_crafted_annotation_is_never_written_into_any_argv(tmp_path, forks):
    # The complement of the fork count: even a LEGITIMATE annotation in the same file must not carry
    # its neighbour's bytes. One valid `bats:` pin alongside four crafted ones -- exactly one argv,
    # and nothing in it came from the crafted lines.
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests/real.bats").write_text("@test 'x' { true; }\n", encoding="utf-8")
    body = ["- [ ] AC0 legitimate.\n  - Evidence: `bats:tests/real.bats`\n"]
    body += [f"- [ ] AC{n} crafted.\n  - Evidence: {raw}\n" for n, raw in enumerate(CRAFTED[:4], start=1)]
    plan = tmp_path / "PROJECT_PLAN.md"
    plan.write_text("".join(body), encoding="utf-8")
    derive_mod.derive(plan, tmp_path)
    assert len(forks) == 1
    argv = forks[0]
    assert argv[0] == "bats"
    assert argv[1].endswith("/tests/real.bats")
    for element in argv:
        for metacharacter in [";", "`", "$(", "|", "&", "<", ">", "\n"]:
            assert metacharacter not in element


def test_no_shell_true_anywhere_in_the_package():
    """The rule stated as a property of the source, not only of the behaviour. A `shell=True` added
    later would make every case above pass and the package unsafe."""
    package = Path(__file__).resolve().parent
    for module in sorted(package.glob("*.py")):
        if module.name.startswith("test_"):
            continue
        body = module.read_text(encoding="utf-8")
        assert "shell=True" not in body, module.name
        assert "os.system" not in body, module.name
