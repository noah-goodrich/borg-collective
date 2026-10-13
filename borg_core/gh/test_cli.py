"""End-to-end tests of `borg_core.gh.cli` against a fake `gh` executable on PATH.

The fake reads a scenario from `$FAKE_GH_DIR/scenario.json` and appends every argv to `calls.jsonl`:

    views[n]        list of `gh pr view` JSON payloads; consumed in order, the last one repeats
    update_branch[n] / rerun[n] / merge[n]   {"rc": int, "stderr": str}; default rc 0
"""

from __future__ import annotations

import json
import os
import stat
import sys
import time

import pytest

from borg_core.gh import cli

FAKE = """#!/usr/bin/env python3
import json, os, sys
d = os.environ["FAKE_GH_DIR"]
argv = sys.argv[1:]
with open(os.path.join(d, "calls.jsonl"), "a") as f:
    f.write(json.dumps(argv) + "\\n")
sc = json.load(open(os.path.join(d, "scenario.json")))
def reply(table, key):
    r = sc.get(table, {}).get(key, {})
    sys.stderr.write(r.get("stderr", ""))
    sys.stdout.write(r.get("stdout", ""))
    sys.exit(r.get("rc", 0))
if argv[:2] == ["pr", "view"]:
    n = argv[2]
    pos = os.path.join(d, "pos-" + n)
    i = int(open(pos).read()) if os.path.exists(pos) else 0
    seq = sc["views"][n]
    open(pos, "w").write(str(i + 1))
    print(json.dumps(seq[min(i, len(seq) - 1)]))
    sys.exit(0)
if argv[:2] == ["pr", "update-branch"]:
    reply("update_branch", argv[2])
if argv[:2] == ["pr", "merge"]:
    reply("merge", argv[2])
if argv[:2] == ["run", "rerun"]:
    reply("rerun", argv[2])
sys.stderr.write("fake gh: unexpected " + repr(argv))
sys.exit(97)
"""

OK = {
    "__typename": "CheckRun",
    "name": "ci",
    "status": "COMPLETED",
    "conclusion": "SUCCESS",
    "startedAt": "2026-10-13T10:00:00Z",
    "detailsUrl": "https://github.com/o/r/actions/runs/555/job/9",
}
FAIL = dict(OK, name="lint", conclusion="FAILURE")
PEND = {
    "__typename": "CheckRun",
    "name": "ci",
    "status": "IN_PROGRESS",
    "conclusion": "",
    "startedAt": "2026-10-13T10:00:00Z",
}
NORUNNER = dict(OK, name="ci", conclusion="CANCELLED", startedAt="0001-01-01T00:00:00Z")


def view(checks, head="aaa", merge_state="CLEAN", state="OPEN"):
    return {
        "statusCheckRollup": checks,
        "headRefOid": head,
        "mergeStateStatus": merge_state,
        "state": state,
        "mergeCommit": None,
    }


@pytest.fixture
def fake(tmp_path, monkeypatch):
    bindir = tmp_path / "bin"
    bindir.mkdir()
    gh = bindir / "gh"
    gh.write_text(FAKE.replace("#!/usr/bin/env python3", f"#!{sys.executable}"))
    gh.chmod(gh.stat().st_mode | stat.S_IXUSR)
    state = tmp_path / "state"
    state.mkdir()
    monkeypatch.setenv("PATH", f"{bindir}{os.pathsep}{os.environ['PATH']}")
    monkeypatch.setenv("FAKE_GH_DIR", str(state))

    class Fake:
        def scenario(self, **kw):
            (state / "scenario.json").write_text(json.dumps(kw))

        def calls(self):
            p = state / "calls.jsonl"
            return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []

        def mutating(self):
            return [c for c in self.calls() if c[:2] != ["pr", "view"]]

    return Fake()


FAST = ["--interval", "0.01", "--timeout", "0.3"]


def run(capsys, *argv):
    rc = cli.main(list(argv))
    out = capsys.readouterr()
    return rc, out.out, out.err


def test_gate_green(fake, capsys):
    fake.scenario(views={"7": [view([OK, dict(OK, name="skipped", conclusion="SKIPPED")])]})
    rc, out, err = run(capsys, "gate", "7", "--json")
    doc = json.loads(out)
    assert rc == 0 and doc["verdict"] == "green" and doc["checks"]["pass"] == 2 and doc["head"] == "aaa"
    assert "#7" in err


def test_gate_failing_names_the_check(fake, capsys):
    fake.scenario(views={"7": [view([OK, FAIL])]})
    rc, out, _ = run(capsys, "gate", "7", "--json")
    assert rc == 1 and json.loads(out)["failing"] == ["lint"]


def test_gate_pending(fake, capsys):
    fake.scenario(views={"7": [view([PEND])]})
    rc, out, _ = run(capsys, "gate", "7", "--json")
    assert rc == 2 and json.loads(out)["checks"]["pending"] == 1


def test_gate_cancelled_without_runner_is_exit_3_but_cancelled_after_start_is_failing(fake, capsys):
    fake.scenario(views={"7": [view([NORUNNER])], "8": [view([dict(NORUNNER, startedAt="2026-10-13T10:00:00Z")])]})
    assert run(capsys, "gate", "7", "--json")[0] == 3
    assert run(capsys, "gate", "8", "--json")[0] == 1


def test_gate_wait_times_out_with_exit_2_after_polling(fake, capsys):
    fake.scenario(views={"7": [view([PEND])]})
    rc, _, _ = run(capsys, "gate", "7", "--wait", "--json", *FAST)
    assert rc == 2 and len(fake.calls()) > 2


def test_gate_wait_returns_when_checks_turn_green(fake, capsys):
    fake.scenario(views={"7": [view([PEND]), view([PEND]), view([OK])]})
    rc, _, _ = run(capsys, "gate", "7", "--wait", "--json", *FAST)
    assert rc == 0


def test_gate_passes_repo_through(fake, capsys):
    fake.scenario(views={"7": [view([OK])]})
    run(capsys, "gate", "7", "--repo", "o/r", "--json")
    assert fake.calls()[0][-2:] == ["--repo", "o/r"]


def test_train_happy_path_orders_prs_and_pins_head(fake, capsys):
    fake.scenario(views={"1": [view([OK], head="h1")], "2": [view([OK], head="h2")]})
    rc, out, _ = run(capsys, "merge-train", "1", "2", "--yes", *FAST)
    report = json.loads(out)
    assert rc == 0 and [r["n"] for r in report if r["action"] == "merge"] == [1, 2]
    merges = [c for c in fake.calls() if c[:2] == ["pr", "merge"]]
    assert merges[0][:3] == ["pr", "merge", "1"] and "--match-head-commit" in merges[0]
    assert merges[0][merges[0].index("--match-head-commit") + 1] == "h1"
    assert {"--squash", "--delete-branch"} <= set(merges[0]) and merges[1][2] == "2"


def test_train_updates_branch_when_behind(fake, capsys):
    fake.scenario(views={"1": [view([OK], merge_state="BEHIND", head="old"), view([OK], head="new")]})
    rc, out, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 0 and ["pr", "update-branch", "1", "--rebase"] in fake.calls()
    merge = [c for c in fake.calls() if c[:2] == ["pr", "merge"]][0]
    assert merge[merge.index("--match-head-commit") + 1] == "new"


def test_train_conflict_stops_with_4_and_leaves_later_prs_untouched(fake, capsys):
    fake.scenario(
        views={"1": [view([OK], merge_state="BEHIND")], "2": [view([OK])]},
        update_branch={"1": {"rc": 1, "stderr": "merge conflict"}},
    )
    rc, out, err = run(capsys, "merge-train", "1", "2", "--yes", *FAST)
    assert rc == 4 and "#1" in err
    assert json.loads(out)[-1]["result"] == "conflict"
    assert not [c for c in fake.calls() if len(c) > 2 and c[2] == "2"]


def test_train_dirty_pr_is_a_conflict_without_calling_update(fake, capsys):
    fake.scenario(views={"1": [view([OK], merge_state="DIRTY")]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 4 and not fake.mutating()


def test_train_pending_times_out_with_2_and_never_merges(fake, capsys):
    fake.scenario(views={"1": [view([PEND])]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 2 and not fake.mutating()


def test_train_reruns_a_runnerless_cancel_once_then_merges(fake, capsys):
    fake.scenario(views={"1": [view([OK]), view([NORUNNER]), view([PEND]), view([OK])]})
    rc, out, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 0
    assert fake.calls().count(["run", "rerun", "555", "--failed"]) == 1
    assert "rerun" in [r["action"] for r in json.loads(out)]


def test_train_second_runnerless_cancel_stops_with_3(fake, capsys):
    fake.scenario(views={"1": [view([NORUNNER])]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 3
    assert fake.calls().count(["run", "rerun", "555", "--failed"]) == 1
    assert not [c for c in fake.calls() if c[:2] == ["pr", "merge"]]


def test_train_head_moved_surfaces_match_head_refusal_as_5(fake, capsys):
    fake.scenario(
        views={"1": [view([OK], head="h1")]},
        merge={"1": {"rc": 1, "stderr": "Head branch was modified. Review and try the merge again."}},
    )
    rc, out, err = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 5 and "re-gate" in err and json.loads(out)[-1]["result"] == "head-moved"


def test_train_stops_at_first_failure(fake, capsys):
    fake.scenario(views={"1": [view([OK])], "2": [view([FAIL])], "3": [view([OK])]})
    rc, out, _ = run(capsys, "merge-train", "1", "2", "3", "--yes", *FAST)
    assert rc == 1
    merged = [c[2] for c in fake.calls() if c[:2] == ["pr", "merge"]]
    assert merged == ["1"] and not [c for c in fake.calls() if len(c) > 2 and c[2] == "3"]
    assert json.loads(out)[-1] == {"n": 2, "action": "wait", "result": "failing", "head": "aaa"}


def test_train_dry_run_makes_no_mutating_calls(fake, capsys):
    fake.scenario(views={"1": [view([OK], merge_state="BEHIND")]})
    rc, out, _ = run(capsys, "merge-train", "1", "--dry-run", *FAST)
    assert rc == 0 and not fake.mutating()
    assert [r["action"] for r in json.loads(out)] == ["update-branch", "merge"]


def test_train_requires_yes_without_a_tty(fake, capsys, monkeypatch):
    fake.scenario(views={"1": [view([OK])]})
    monkeypatch.setattr(sys.stdin, "isatty", lambda: False)
    rc, _, err = run(capsys, "merge-train", "1", *FAST)
    assert rc == 64 and "--yes" in err and not fake.mutating()


def test_gh_failure_is_exit_6(fake, capsys):
    fake.scenario(views={"7": []})
    rc, _, err = run(capsys, "gate", "7")
    assert rc == 6 and "gh" in err


def test_usage_errors_exit_64_not_argparse_2(fake, capsys):
    for argv in (
        ["gate", "abc"],
        ["gate", "7", "--bogus"],
        ["nope", "7"],
        ["gate", "7", "--interval", "-1"],
        ["gate", "7", "--timeout", "-5"],
        ["gate"],
    ):
        with pytest.raises(SystemExit) as e:
            cli.main(argv)
        assert e.value.code == 64, argv


def test_train_refuses_an_empty_head_and_does_not_merge(fake, capsys):
    fake.scenario(views={"1": [dict(view([OK]), headRefOid="")]})
    rc, _, err = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 5 and "head" in err and not fake.mutating()


def test_train_waits_for_a_new_head_after_update_branch(fake, capsys):
    old = view([OK], merge_state="BEHIND", head="old")
    fake.scenario(views={"1": [old, view([OK], head="old"), view([OK], head="old"), view([OK], head="new")]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    merge = [c for c in fake.calls() if c[:2] == ["pr", "merge"]][0]
    assert rc == 0 and merge[merge.index("--match-head-commit") + 1] == "new"


def test_train_never_merges_the_old_head_if_the_head_never_changes(fake, capsys):
    fake.scenario(views={"1": [view([OK], merge_state="BEHIND", head="old"), view([OK], head="old")]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 2 and not [c for c in fake.calls() if c[:2] == ["pr", "merge"]]


def test_train_treats_an_empty_rollup_as_pending_until_checks_register(fake, capsys):
    fake.scenario(views={"1": [view([], head="h"), view([PEND], head="h"), view([OK], head="h")]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 0
    assert len([c for c in fake.calls() if c[:2] == ["pr", "view"]]) >= 3


def test_train_empty_rollup_forever_merges_after_grace_for_repos_without_checks(fake, capsys):
    fake.scenario(views={"1": [view([], head="h")]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", "--interval", "0.01", "--timeout", "5")
    assert rc == 0 and [c for c in fake.calls() if c[:2] == ["pr", "merge"]]


def test_gate_empty_rollup_stays_green_without_wait(fake, capsys):
    fake.scenario(views={"7": [view([])]})
    assert run(capsys, "gate", "7", "--json")[0] == 0


def test_failing_check_is_never_rerun(fake, capsys):
    fake.scenario(views={"1": [view([FAIL, NORUNNER])]})
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 1 and not [c for c in fake.calls() if c[:2] == ["run", "rerun"]]


def test_unrelated_merge_error_is_not_head_moved(fake, capsys):
    fake.scenario(
        views={"1": [view([OK])]},
        merge={"1": {"rc": 1, "stderr": "Pull request is not mergeable: required status check missing"}},
    )
    rc, out, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 6 and json.loads(out)[-1]["result"] == "error"


def test_conflict_appearing_at_merge_time_is_exit_4(fake, capsys):
    fake.scenario(
        views={"1": [view([OK]), view([OK]), view([OK], merge_state="DIRTY")]},
        merge={"1": {"rc": 1, "stderr": "Pull request is not mergeable"}},
    )
    rc, out, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 4 and json.loads(out)[-1]["result"] == "conflict"


def test_closed_pr_is_exit_7_and_never_merged(fake, capsys):
    fake.scenario(views={"1": [view([OK], state="CLOSED")]})
    rc, _, err = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 7 and "closed" in err.lower() and not fake.mutating()


def test_update_branch_non_conflict_failure_is_a_gh_error(fake, capsys):
    fake.scenario(
        views={"1": [view([OK], merge_state="BEHIND")]},
        update_branch={"1": {"rc": 1, "stderr": "HTTP 502 bad gateway"}},
    )
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 6


def test_rerun_refused_while_in_progress_is_pending_not_fatal(fake, capsys):
    fake.scenario(
        views={"1": [view([NORUNNER]), view([PEND]), view([OK])]},
        rerun={"555": {"rc": 1, "stderr": "run 555 is still in progress; cannot be rerun"}},
    )
    rc, _, _ = run(capsys, "merge-train", "1", "--yes", *FAST)
    assert rc == 0


def test_train_timeout_is_train_wide(fake, capsys):
    fake.scenario(views={"1": [view([PEND])], "2": [view([PEND])]})
    t0 = time.monotonic()
    rc, _, _ = run(capsys, "merge-train", "1", "2", "--yes", "--interval", "0.01", "--timeout", "0.3")
    assert rc == 2 and time.monotonic() - t0 < 0.6


def test_help_does_not_claim_workflows_refuse_the_verb(capsys):
    with pytest.raises(SystemExit):
        cli.main(["merge-train", "--help"])
    assert "refuse" not in capsys.readouterr().out.lower()


def test_help_says_merge_train_is_not_for_agents(capsys):
    with pytest.raises(SystemExit) as e:
        cli.main(["merge-train", "--help"])
    assert e.value.code == 0
    assert "never" in capsys.readouterr().out.lower()
