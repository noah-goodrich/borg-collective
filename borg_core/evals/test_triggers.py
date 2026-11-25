"""Tests for borg_core.evals.triggers and triggers_cli: suite rules, the plugin-list abort, grading, the report."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from borg_core.evals import triggers, triggers_cli

REPO = Path(__file__).resolve().parents[2]
BUILD = "/tmp/build/borg-collective"


def _case(n: int, fire: bool, text: str | None = None) -> dict:
    case = {"id": f"pane-{n:02d}", "query": text or f"query number {n}", "should_fire": fire}
    if not fire:
        case["competitor"] = "borg-switch"
    return case


def _suite(positives: int = 12, near: int = 8) -> list[dict]:
    return [_case(i, True) for i in range(positives)] + [_case(100 + i, False) for i in range(near)]


def _init(*plugins: tuple[str, str, str]) -> dict:
    return {
        "type": "system",
        "subtype": "init",
        "plugins": [{"name": n, "source": s, "path": p} for n, s, p in plugins],
    }


OURS = ("borg-collective", "borg-collective@inline", BUILD)
BUILTIN = ("cc-plugin-agents-md", "cc-plugin-agents-md@builtin", "/x")
OTHER = ("hookify", "hookify@claude-plugins-official", "/y")


def test_a_balanced_suite_is_admissible():
    assert not triggers.validate_suite("pane", _suite())


def test_a_suite_under_twenty_cases_is_refused():
    assert any("need at least 20" in p for p in triggers.validate_suite("pane", _suite(10, 8)))


def test_a_suite_under_forty_percent_near_misses_is_refused():
    problems = triggers.validate_suite("pane", _suite(14, 6))
    assert any("near-misses" in p for p in problems)
    assert not any("near-misses" in p for p in triggers.validate_suite("pane", _suite(12, 8)))


def test_malformed_cases_are_each_named():
    cases = _suite()
    cases[0]["id"] = "other-01"
    cases[1]["id"] = cases[2]["id"]
    cases[3]["query"] = cases[4]["query"]
    cases[5]["should_fire"] = "yes"
    del cases[-1]["competitor"]
    cases.append("junk")
    text = "\n".join(triggers.validate_suite("pane", cases))
    for needle in (
        "must be a string starting",
        "duplicate id",
        "duplicate query",
        "true or false",
        "competitor",
        "an object",
    ):
        assert needle in text


def test_a_suite_that_is_not_an_array_is_refused():
    assert triggers.validate_suite("pane", {"a": 1}) == ["pane: a suite is a JSON array of cases"]


def test_a_query_that_names_the_skill_is_a_hint():
    cases = _suite()
    cases[0]["query"] = "please run /pane now"
    assert any("names the skill" in p for p in triggers.validate_suite("pane", cases))
    assert triggers._names_skill("borg-link-up", "do the borg-link-up thing")
    assert not triggers._names_skill("pane", "split the pane to the right")


def test_the_split_is_sixty_forty_stable_and_stratified():
    cases = _suite(12, 8)
    train, held = triggers.split_cases(cases)
    assert (len(train), len(held)) == (13, 7)
    assert {c["should_fire"] for c in held} == {True, False}
    again, _ = triggers.split_cases(list(reversed(cases)))
    assert {c["id"] for c in again} == {c["id"] for c in train}


def test_floor_a_wrong_plugin_list_aborts():
    # in-situ: the build loaded, but the list differs from the enabled set
    init = _init(OURS, BUILTIN)
    problems = triggers.plugin_problems(init, "in-situ", BUILD, ["borg-collective", "hookify"])
    assert any("missing ['hookify']" in p for p in problems)
    extra = triggers.plugin_problems(_init(OURS, OTHER), "in-situ", BUILD, ["borg-collective"])
    assert any("extra ['hookify']" in p for p in extra)
    assert not triggers.plugin_problems(_init(OURS, OTHER, BUILTIN), "in-situ", BUILD, ["borg-collective", "hookify"])


def test_floor_a_bare_run_loads_no_plugin_and_aborts_in_both_modes():
    bare = _init()
    for mode in triggers.MODES:
        assert any("loads no plugin" in p for p in triggers.plugin_problems(bare, mode, BUILD, ["borg-collective"]))


def test_an_installed_copy_instead_of_the_build_aborts():
    installed = ("borg-collective", "borg-collective@noah-local", "/home/x/.claude/plugins/cache/borg-collective")
    assert any("build under review" in p for p in triggers.plugin_problems(_init(installed), "isolated", BUILD))


def test_isolated_allows_only_the_build_and_the_bundled_plugins():
    assert not triggers.plugin_problems(_init(OURS, BUILTIN), "isolated", BUILD)
    assert any("other plugins" in p for p in triggers.plugin_problems(_init(OURS, OTHER), "isolated", BUILD))


def test_no_init_event_and_an_unknown_mode_abort():
    assert triggers.plugin_problems(None, "isolated", BUILD)
    assert triggers.plugin_problems(_init(OURS), "bare", BUILD) == ["unknown mode 'bare'"]


def _stream(skills: list[str], init: dict | None = None) -> str:
    events = [init or _init(OURS, BUILTIN)]
    for skill in skills:
        block = {"type": "tool_use", "name": "Skill", "input": {"skill": skill}}
        events.append({"type": "assistant", "message": {"content": [{"type": "text", "text": "hi"}, block]}})
    events.append({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {}}]}})
    events.append({"type": "assistant", "message": {"content": "plain"}})
    events.append({"type": "result", "total_cost_usd": 0.01, "num_turns": 2})
    return "not json\n" + "\n".join(json.dumps(e) for e in events) + "\n[1]\n"


def test_parse_stream_reads_init_skill_calls_and_result():
    parsed = triggers.parse_stream(_stream(["borg-collective:pane", "other"]))
    assert parsed["invoked"] == ["pane", "other"]
    assert parsed["init"]["subtype"] == "init"
    assert parsed["result"]["num_turns"] == 2


@pytest.mark.parametrize(
    ("fire", "invoked", "verdict"),
    [
        (True, ["pane"], "pass"),
        (True, [], "fail"),
        (True, ["borg-next"], "fail"),
        (False, [], "pass"),
        (False, ["borg-next"], "pass"),
        (False, ["pane"], "fail"),
    ],
)
def test_grading_is_one_sided_per_label(fire, invoked, verdict):
    assert triggers.grade("pane", {"should_fire": fire}, invoked)[0] == verdict


def test_summary_reports_recall_and_specificity_with_intervals():
    rows = [{"should_fire": True, "verdict": "pass"}] * 9 + [{"should_fire": True, "verdict": "fail"}]
    rows += [{"should_fire": False, "verdict": "pass"}] * 5 + [{"should_fire": False, "verdict": "error"}]
    out = triggers.summarize(rows)
    assert (out["recall"]["k"], out["recall"]["n"]) == (9, 10)
    assert (out["specificity"]["k"], out["specificity"]["n"]) == (5, 5)
    assert out["unscored"] == 1
    assert 0.0 < out["all"]["interval"][0] < out["all"]["interval"][1] <= 1.0


def _write_skill(root: Path, name: str, extra: str = "") -> None:
    (root / name).mkdir(parents=True)
    (root / name / "SKILL.md").write_text(f'---\nname: {name}\ndescription: "does {name}"\n{extra}---\nbody\n')


def test_frontmatter_and_listing_exclude_model_hidden_skills(tmp_path):
    skills = tmp_path / "skills"
    _write_skill(skills, "pane")
    _write_skill(skills, "hidden", "disable-model-invocation: true\n")
    assert list(triggers_cli.self_firing_skills(skills)) == ["pane"]
    count, chars = triggers_cli.listing_size(skills)
    assert count == 1 and chars == len("- borg-collective:pane: does pane")
    assert triggers_cli.frontmatter(tmp_path / "skills" / "pane" / "SKILL.md")["name"] == "pane"


def test_validate_names_a_self_firing_skill_with_no_suite_and_a_suite_for_a_hidden_skill(tmp_path, capsys):
    skills, suites = tmp_path / "skills", tmp_path / "triggers"
    _write_skill(skills, "pane")
    _write_skill(skills, "hidden", "disable-model-invocation: true\n")
    suites.mkdir()
    (suites / "hidden.json").write_text("[]")
    assert triggers_cli.main(["validate", "--dir", str(suites), "--skills", str(skills), "--complete"]) == 1
    out = capsys.readouterr().out
    assert "pane: self-firing, no suite" in out and "hidden: a suite for a skill that is not self-firing" in out
    (suites / "hidden.json").unlink()
    assert triggers_cli.main(["validate", "--dir", str(suites), "--skills", str(skills)]) == 0
    assert triggers_cli.main(["validate", "--dir", str(suites), "--skills", str(skills), "--complete"]) == 1
    (suites / "pane.json").write_text(json.dumps(_suite()))
    assert triggers_cli.main(["validate", "--dir", str(suites), "--skills", str(skills), "--complete"]) == 0
    (suites / "pane.json").write_text("{nope")
    assert triggers_cli.main(["validate", "--dir", str(suites), "--skills", str(skills)]) == 1


def test_grade_aborts_on_a_wrong_plugin_list_and_records_nothing(tmp_path, capsys):
    suite = tmp_path / "pane.json"
    suite.write_text(json.dumps(_suite()))
    stream = tmp_path / "s.jsonl"
    stream.write_text(_stream(["pane"], _init(BUILTIN)))
    verdicts = tmp_path / "v.jsonl"
    argv = ["grade", "--suite", str(suite), "--id", "pane-00", "--stream", str(stream), "--mode", "isolated"]
    argv += ["--plugin-dir", BUILD, "--verdicts", str(verdicts)]
    assert triggers_cli.main(argv) == triggers_cli.ABORT
    assert capsys.readouterr().out.startswith("ABORT ")
    assert not verdicts.exists()


def test_grade_writes_a_row_and_exit_codes_follow_the_verdict(tmp_path, capsys):
    suite = tmp_path / "pane.json"
    suite.write_text(json.dumps(_suite()))
    stream = tmp_path / "s.jsonl"
    stream.write_text(_stream(["borg-collective:pane"]))
    verdicts, expect = tmp_path / "v.jsonl", tmp_path / "e.txt"
    expect.write_text("borg-collective\n")
    base = ["grade", "--suite", str(suite), "--stream", str(stream), "--mode", "in-situ", "--plugin-dir", BUILD]
    base += ["--verdicts", str(verdicts), "--expect-file", str(expect)]
    assert triggers_cli.main(base + ["--id", "pane-00"]) == 0
    assert triggers_cli.main(base + ["--id", "pane-100"]) == 1
    assert triggers_cli.main(base + ["--id", "nope"]) == 2
    rows = [json.loads(line) for line in verdicts.read_text().splitlines()]
    assert [r["verdict"] for r in rows] == ["pass", "fail"]
    assert rows[1]["reason"].startswith("misfire") and rows[1]["competitor"] == "borg-switch"
    assert "VERDICT pass" in capsys.readouterr().out


def test_report_prints_accuracy_and_writes_misfires_with_their_split(tmp_path, capsys):
    (tmp_path / "pane.json").write_text(json.dumps(_suite()))
    rows = [
        {
            "mode": "isolated",
            "skill": "pane",
            "id": "pane-00",
            "should_fire": True,
            "verdict": "fail",
            "reason": "missed",
            "invoked": [],
            "query": "q",
            "competitor": None,
        },
        {
            "mode": "in-situ",
            "skill": "pane",
            "id": "pane-100",
            "should_fire": False,
            "verdict": "pass",
            "reason": "",
            "invoked": [],
            "query": "q",
            "competitor": "borg-switch",
        },
    ]
    verdicts, misfires = tmp_path / "v.jsonl", tmp_path / "m.json"
    verdicts.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    assert (
        triggers_cli.main(["report", "--verdicts", str(verdicts), "--dir", str(tmp_path), "--misfires", str(misfires)])
        == 0
    )
    out = capsys.readouterr().out
    assert "isolated" in out and "in-situ" in out and "recall 0/1" in out
    written = json.loads(misfires.read_text())
    assert [m["id"] for m in written["pane"]] == ["pane-00"]
    assert written["pane"][0]["split"] in ("train", "held-out")


def test_plugins_lists_enabled_names_once_and_survives_a_broken_cli():
    listed = json.dumps(
        [{"id": "a@x", "enabled": True}, {"id": "a@y", "enabled": True}, {"id": "b@x", "enabled": False}]
    )
    assert triggers_cli.enabled_plugin_names(lambda argv: listed) == ["a"]
    assert triggers_cli.enabled_plugin_names(lambda argv: "garbage") == []


def test_main_prints_plugins_and_listing(capsys, monkeypatch):
    monkeypatch.setattr(triggers_cli, "enabled_plugin_names", lambda: ["a", "b"])
    assert triggers_cli.main(["plugins"]) == 0
    assert triggers_cli.main(["listing", "--skills", str(REPO / "skills")]) == 0
    out = capsys.readouterr().out
    assert "a\nb" in out and "listed " in out and " skills, " in out
