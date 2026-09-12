"""AC6 + AC7: every verdict in this module is PRODUCED BY THE PRODUCTION RESOLVER, never supplied.

THE RULE THIS FILE EXISTS TO OBEY (`reference_test_supplies_derived_value`): `borg recon` shipped
completely dead for months because every test put `BORG_REGISTRY` into the environment itself, so the
one line production had to derive was the one line no test ever executed. A planstate suite that
handed `derive` a dict of verdicts would prove the report FORMATTER works and nothing about whether a
single annotation was ever resolved.

So:

- `path:` runs against a REAL filesystem -- files this test creates in a tmpdir, resolved by
  `shell.exists` through `derive.derive`.
- `pytest:` FORKS A REAL RUNNER. The passing case is a real test file that really passes; the failing
  case is a real test file that really fails, and the verdicts come from the child's real exit code.
- `pr:` goes through `borg_core.link.shell.start_fetch` / `finish_fetch` -- the same resolver
  `borg link` uses -- via its own `BORG_LINK_FETCH_FIXTURE` seam, which replays a RECORDED ANSWER
  through `grid.replayed_items` and `grid.fetch_answered` and leaves every downstream decision
  (`attempted`, `status`, the `merged` comparison) to production code. The seam is the repository's
  own, added for exactly this: a recorded `gh` answer is not a supplied verdict.

MUTATION-CHECKED. Breaking `core.verdict_for_pr`'s `state == "merged"` test, or
`shell.resolve_prs`'s call into `link_shell`, turns the `pr:` cases red; breaking
`core.verdict_for_suite`'s `code == 0` test turns the `pytest:` cases red. Recorded in the branch's
commit message.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from borg_core.planstate import core, derive as derive_mod

PASSING_TEST = "def test_true():\n    assert True\n"
FAILING_TEST = "def test_false():\n    assert False\n"


def _plan(annotation: str, text: str = "AC1 the criterion") -> str:
    return f"- [ ] {text}\n  - Verify: prose nobody executes.\n  - Evidence: `{annotation}`\n"


def _write(root: Path, name: str, body: str) -> Path:
    target = root / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body, encoding="utf-8")
    return target


def _verdicts(root: Path, plan_text: str) -> list[tuple[str, str]]:
    """Run the WHOLE production path -- parse, validate, resolve, report -- and return
    `(verdict, evidence)` per criterion. Nothing is stubbed."""
    plan = _write(root, "PROJECT_PLAN.md", plan_text)
    report = derive_mod.derive(plan, root)
    return [(row["verdict"], row["evidence"]) for row in report["criteria"]]


def test_a_path_that_exists_passes_and_one_that_does_not_fails(tmp_path):
    _write(tmp_path, "docs/boris-workflow.md", "real bytes on a real disk\n")
    verdicts = _verdicts(tmp_path, _plan("path:docs/boris-workflow.md") + _plan("path:docs/gone.md", "AC2 absent"))
    assert [verdict for verdict, _ in verdicts] == [core.PASS, core.FAIL]
    assert "exists" in verdicts[0][1] and "does not exist" in verdicts[1][1]


def test_a_missing_suite_path_is_unknown_and_never_fail(tmp_path):
    # The directive's second Risk: "the pin rotted" and "the work regressed" are different facts.
    verdicts = _verdicts(tmp_path, _plan("pytest:borg_core/gone/"))
    assert verdicts[0][0] == core.UNKNOWN
    assert "pin rotted" in verdicts[0][1]


def test_a_real_pytest_run_decides_pass_and_fail_from_the_childs_exit_code(tmp_path, monkeypatch):
    # A REAL FORK. `shell.run_suite` builds the argv, `proc.run_capture` runs it, and the verdict is
    # the child's actual status -- the production evidence path end to end.
    monkeypatch.setenv("BORG_PLANSTATE_SUITE_TIMEOUT", "180")
    _write(tmp_path, "suite/test_green.py", PASSING_TEST)
    _write(tmp_path, "suite/test_red.py", FAILING_TEST)
    verdicts = _verdicts(
        tmp_path,
        _plan("pytest:suite/test_green.py") + _plan("pytest:suite/test_red.py", "AC2 red"),
    )
    assert verdicts[0][0] == core.PASS, verdicts
    assert verdicts[1][0] == core.FAIL, verdicts
    assert "exited 0" in verdicts[0][1]


def test_a_runner_that_cannot_be_started_is_unknown_not_fail(tmp_path, monkeypatch):
    # `bats` may or may not be installed on this machine, so the absence is FORCED rather than
    # assumed -- PATH is emptied, `proc.run_capture` returns None, and production maps None to
    # unknown. Assuming a binary is missing from a system directory is the exact ubuntu-vs-macOS
    # premise failure CLAUDE.md's "Learned" records.
    monkeypatch.setenv("PATH", str(tmp_path / "empty-bin"))
    _write(tmp_path, "tests/thing.bats", "@test 'x' { true; }\n")
    verdicts = _verdicts(tmp_path, _plan("bats:tests/thing.bats"))
    assert verdicts[0][0] == core.UNKNOWN
    assert "could not be run" in verdicts[0][1]


def _record(tmp_path: Path, nodes: dict) -> Path:
    target = tmp_path / "fetch.json"
    target.write_text(json.dumps({"nodes": nodes}), encoding="utf-8")
    return target


def test_a_merged_pr_passes_through_the_same_resolver_borg_link_uses(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(_record(tmp_path, {"o/r#42": {"state": "MERGED"}})))
    verdicts = _verdicts(tmp_path, _plan("pr:o/r#42"))
    assert verdicts[0] == (core.PASS, "pr:o/r#42 is merged")


def test_an_open_pr_fails_and_a_closed_one_fails_by_state_not_by_default(tmp_path, monkeypatch):
    monkeypatch.setenv(
        "BORG_LINK_FETCH_FIXTURE",
        str(_record(tmp_path, {"o/r#1": {"state": "OPEN"}, "o/r#2": {"state": "CLOSED"}})),
    )
    verdicts = _verdicts(tmp_path, _plan("pr:o/r#1") + _plan("pr:o/r#2", "AC2 closed"))
    assert verdicts[0] == (core.FAIL, "pr:o/r#1 is open, not merged")
    assert verdicts[1] == (core.FAIL, "pr:o/r#2 is closed, not merged")


def test_a_degraded_github_source_is_unknown_and_never_fail(tmp_path, monkeypatch):
    # The directive's third Risk. An unreadable recording takes `link.shell._read_fetch_fixture`'s
    # first degradation rung -- `attempted: False` -- which is the same rung an uninstalled `gh`
    # takes, so this drives the real degrade policy rather than a stand-in for it.
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(tmp_path / "no-such-recording.json"))
    verdicts = _verdicts(tmp_path, _plan("pr:o/r#42"))
    assert verdicts[0][0] == core.UNKNOWN
    assert "unreachable" in verdicts[0][1]


def test_a_ref_the_source_did_not_answer_for_is_unknown(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(_record(tmp_path, {"o/r#1": {"state": "MERGED"}})))
    verdicts = _verdicts(tmp_path, _plan("pr:o/r#1") + _plan("pr:o/r#2", "AC2 unanswered"))
    assert verdicts[0][0] == core.PASS
    assert verdicts[1][0] == core.UNKNOWN
    assert "did not resolve" in verdicts[1][1]


def test_a_plan_with_no_pr_annotation_asks_github_nothing(tmp_path, monkeypatch):
    # `resolve_prs`' early return, pinned by subprocess count in the same spirit as
    # tests/link_sweep.bats pins the sweep's.
    forks = []
    monkeypatch.setattr("borg_core.proc.run_background", lambda argv: forks.append(argv))
    _write(tmp_path, "docs/x.md", "x\n")
    _verdicts(tmp_path, _plan("path:docs/x.md"))
    assert forks == []


def test_derive_resolves_this_repositorys_own_directive(tmp_path):
    """AC6 says "a REAL PROJECT_PLAN.md and a real directive", not only synthetic fixtures. Asserts
    the shape the parser must survive -- 120-wrapped, four-space sub-bullets, continuation lines --
    without asserting any particular verdict, which would make the suite a hostage to the corpus.

    `root=tmp_path` IS LOAD-BEARING AND IS NOT A STUB. That directive's own AC6 carries
    `Evidence: pytest:borg_core/planstate/` -- resolving it against the REPOSITORY would fork a
    pytest run over this very package from inside it, which recurses until something runs out. An
    empty root makes every suite pin resolve `unknown` through the production missing-path branch,
    which is the branch this case wants anyway. No verdict is supplied; only the root is chosen."""
    here = Path(__file__).resolve()
    directive = here.parents[2] / "docs/plans/directives/2026-09-09-link-up-criteria-reconciliation.md"
    if not directive.exists():
        pytest.skip("the directive is not present in this checkout")
    report = derive_mod.derive(directive, tmp_path)
    assert report["counts"]["total"] >= 9
    annotated = [row for row in report["criteria"] if row["kind"]]
    assert annotated, "the directive's own `- Evidence:` sub-bullets must parse"
    assert all(row["verdict"] in (core.PASS, core.FAIL, core.UNKNOWN) for row in report["criteria"])
    assert all(row["evidence"] for row in report["criteria"])


def test_the_env_is_not_leaking_a_fetch_fixture_into_the_other_suites():
    # Guards the guard: if some other module exported BORG_LINK_FETCH_FIXTURE process-wide, the
    # `pr:` cases above would be reading a recording nobody in this file wrote.
    assert "BORG_LINK_FETCH_FIXTURE" not in os.environ
