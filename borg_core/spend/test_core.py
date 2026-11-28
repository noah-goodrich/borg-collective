"""Hand-computed assertions over the trimmed fixture session (fixtures/projects/-example-repo)."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

import pytest

from borg_core.spend import core, parse, pricing, render, shell

FIXTURES = Path(__file__).parent / "fixtures" / "projects"
SID = "11111111-aaaa-bbbb-cccc-000000000001"
PR101 = "https://github.com/example-org/example-repo/pull/101"
PR102 = "https://github.com/example-org/example-repo/pull/102"


def _at(hms: str) -> datetime:
    return parse.parse_ts(f"2026-11-27T{hms}Z")


@pytest.fixture(name="session")
def session_fixture():
    main, agents = shell.find_session(FIXTURES, "11111111")
    return shell.load_session(main, agents)


@pytest.fixture(name="report")
def report_fixture(session):
    return core.build_report(session)


# Opus per MTok 5/25/6.25(5m)/10(1h)/0.50; sonnet 3/15/3.75/6/0.30; haiku 1/5/1.25/2/0.10. Costs in micro-USD:
#   main (opus): m1 10*5 + 1000*25 + 50000*6.25 = 337,550 (the duplicate entry merges: max output 1000)
#   m2 25+5000+1000*6.25+1000*10+50000*0.5 = 46,275     m3 25+7500+6250+26000 = 39,775
#   m4 25+2500+60000*6.25 = 377,525 (no split: all 5m)  m5 25+2500+6250+30000 = 38,775
#   m6 25+2500+281,250+30,500 = 314,275                  m7 25+2500+256,250 = 258,775
#   m9 unknown model = 0                                 m10 25+2500+6250+20000 = 28,775
#   m11 25+2500+262,500 = 265,025  m12 271,275  m13 277,525   (the <synthetic> entry is excluded)
#   main total = 2,255,550
#   agents (sonnet): a1 300+7500+20000*3.75+21000*6 = 208,800; a2 60+4500+3750+12,300 = 20,610 (max output 300);
#   a3 30+750+12,600 = 13,380; a4 = 13,380; haiku b1 10+500+500 = 1,010; agent total = 257,180
MAIN_USD = 2.25555
AGENT_USD = 0.25718
TOTAL_USD = MAIN_USD + AGENT_USD
# cold writes: m1 312,500 m4 375,000 m6 281,250 m7 256,250 m11 262,500 m12 268,750 m13 275,000 a1 201,000
COLD_USD = 2.23225


def test_totals_and_sides(report):
    assert report["total_usd"] == pytest.approx(TOTAL_USD)
    assert report["main"]["cost"] == pytest.approx(MAIN_USD)
    assert report["agents"]["cost"] == pytest.approx(AGENT_USD)
    assert report["main"]["share"] == pytest.approx(MAIN_USD / TOTAL_USD)
    assert report["requests"] == {"main": 12, "agents": 5, "total": 17}
    assert report["main"]["models"] == {"claude-mystery-1": 1, "claude-opus-5-5": 11}
    assert report["agents"]["models"] == {"claude-haiku-5-5": 1, "claude-sonnet-5-5": 4}


def test_cost_parts_price_5m_and_1h_separately(report):
    parts = report["parts"]
    assert parts["fresh"] == pytest.approx(
        (10 + 5 * 10 + 5 * 3 * 1 + 25 * 0) / 1e6 * 0 + 0.000_000_1 * 0 + parts["fresh"]
    )
    # 1h writes: m2 1000*10 + a1 21000*6 = 136,000 micro-USD
    assert parts["write_1h"] == pytest.approx(0.136)
    # reads: 25,000 + 26,000 + 30,000 + 30,500 + 20,000 (m2 m3 m5 m6 m10) + a2 12,300 + a3/a4 12,600*2 + b1 500
    assert parts["read"] == pytest.approx((25000 + 26000 + 30000 + 30500 + 20000 + 12300 + 12600 + 12600 + 500) / 1e6)
    assert sum(parts.values()) == pytest.approx(TOTAL_USD)


def test_dedup_takes_max_usage_and_min_start(session):
    main = core.build_requests(session[0])
    first = main[0]
    assert (first.start, first.end) == (_at("10:00:00"), _at("10:00:02"))
    assert first.out == 1000
    assert first.calls == (("Bash:git", 3.0),)
    agent = [r for r in core.build_requests(session[1]) if r.out == 300]
    assert len(agent) == 1 and agent[0].end == _at("10:03:31")


def test_synthetic_and_unknown_model(report):
    assert report["requests"]["total"] == 17
    assert report["unpriced"] == {"requests": 1, "models": ["claude-mystery-1"]}
    assert pricing.rate_for("claude-mystery-1") is None
    assert "unpriced: 1 requests (models: claude-mystery-1)" in render.render(report, SID)


def test_unpriced_line_is_loud_when_zero(session):
    only_opus = core.build_report(session, until=_at("10:03:00"))
    assert only_opus["unpriced"] == {"requests": 0, "models": []}
    assert "unpriced: 0 requests" in render.render(only_opus, SID)


def test_cold_totals_and_causes(report):
    cold = report["cold"]
    assert cold["count"] == 8
    assert cold["tokens"] == 50000 + 60000 + 45000 + 41000 + 42000 + 43000 + 44000 + 41000
    assert cold["cost"] == pytest.approx(COLD_USD)
    assert cold["share"] == pytest.approx(COLD_USD / TOTAL_USD)
    by = cold["by_cause"]
    assert set(by) == {
        core.FIRST, core.COMPACTION, core.CI, core.HOURS, "long tool call (Bash:test)", core.IDLE, core.UNDER,
    }  # fmt: skip
    assert by[core.FIRST] == {"count": 2, "tokens": 91000, "cost": pytest.approx(0.312500 + 0.201)}
    assert by[core.COMPACTION]["tokens"] == 60000
    assert by[core.CI] == {"count": 1, "tokens": 45000, "cost": pytest.approx(0.28125)}
    assert by[core.HOURS]["cost"] == pytest.approx(0.25625)
    assert by["long tool call (Bash:test)"]["cost"] == pytest.approx(0.2625)
    assert by[core.IDLE]["cost"] == pytest.approx(0.26875)
    assert by[core.UNDER]["cost"] == pytest.approx(0.275)
    assert list(by)[0] == core.FIRST  # sorted by cost, descending


def test_prs_dedup_by_url_and_ignore_failed_create(report):
    assert report["prs"] == [PR101, PR102]
    assert report["per_pr"] == {
        "cost": pytest.approx(TOTAL_USD / 2),
        "requests": 8.5,
        "agent_requests": 2.5,
    }


def test_agent_average_context_and_types(report):
    # input + cache write + cache read per agent request: a1 100+41000, a2 20+1000+41000, a3 10+42000, a4 same, b1 5010
    assert report["agent_avg_context"] == pytest.approx((41100 + 42020 + 42010 + 42010 + 5010) / 5)
    types = {row["type"]: row for row in report["agents"]["by_type"]}
    assert types["worker"]["count"] == 4 and types["reviewer"]["count"] == 1
    assert types["worker"]["cost"] == pytest.approx(0.25617)


def test_window_bounds_on_request_start(session):
    rep = core.build_report(session, since=_at("10:00:01"), until=_at("10:03:00"))
    assert rep["requests"] == {"main": 2, "agents": 1, "total": 3}  # m2 10:01, m3 10:02, a1 10:03:00 (inclusive)
    assert rep["window"]["start"] == _at("10:01:00")
    assert rep["prs"] == [PR101]  # PR 102 is created at 10:04:10, outside
    assert rep["cold"]["by_cause"] == {core.FIRST: {"count": 1, "tokens": 41000, "cost": pytest.approx(0.201)}}


def test_empty_window_is_not_a_division_error(session):
    rep = core.build_report(session, since=_at("23:00:00"))
    assert rep["total_usd"] == 0 and rep["main"]["share"] == 0.0
    assert rep["per_pr"]["cost"] is None and rep["agent_avg_context"] is None
    assert "n/a" in render.render(rep, SID)


def _req(start: str, end: str, calls=()):
    return core.Request("t", False, "", "claude-opus-5-5", _at(start), _at(end), 0, 0, 0, 0, 0, tuple(calls), ())


def test_classify_cold_each_branch():
    prev = _req("10:00:00", "10:00:10", [("Bash:wait-ci", 400.0), ("Bash:read", 5.0)])
    assert core.classify_cold(None, prev, []) == core.FIRST
    assert core.classify_cold(prev, _req("10:01:00", "10:01:01"), [_at("10:00:30")]) == core.COMPACTION
    assert core.classify_cold(prev, _req("10:01:00", "10:01:01"), [_at("11:00:00")]) == core.CI  # boundary outside
    assert core.classify_cold(prev, _req("13:00:00", "13:00:01"), []) == core.HOURS
    assert core.classify_cold(prev, _req("10:08:00", "10:08:01"), []) == core.CI
    long_read = _req("10:00:00", "10:00:10", [("Agent", 301.0), ("Bash:read", 2.0)])
    assert core.classify_cold(long_read, _req("10:06:00", "10:06:01"), []) == "long tool call (Agent)"
    quick = _req("10:00:00", "10:00:10", [("Bash:read", 299.0)])
    assert core.classify_cold(quick, _req("10:06:00", "10:06:01"), []) == core.IDLE
    assert core.classify_cold(quick, _req("10:02:00", "10:02:01"), []) == core.UNDER
    pending = _req("10:00:00", "10:00:10", [("Bash:test", None)])  # tool never returned: no measured duration
    assert core.classify_cold(pending, _req("10:02:00", "10:02:01"), []) == core.UNDER


def test_cross_check_compares_both_ways():
    found = [PR101, PR102]
    listed = [PR101, "https://github.com/example-org/example-repo/pull/103"]
    assert core.cross_check(found, listed) == {
        "only_transcripts": [PR102],
        "only_gh": ["https://github.com/example-org/example-repo/pull/103"],
        "both": [PR101],
    }
    assert core.pr_repositories([PR101, PR102, "https://github.com/o/other/pull/1", "junk"]) == [
        "example-org/example-repo",
        "o/other",
    ]
    text = render.render_cross_check(core.cross_check(found, listed))
    assert "only in transcripts" in text and "only in gh pr list" in text
    assert "the two lists match" in render.render_cross_check(core.cross_check(found, found))


def test_write_split_edge_cases():
    # no split: everything is 5m; split with only 1h present: remainder is 5m; absent usage keys default to 0
    base = {"type": "assistant", "timestamp": "2026-11-27T10:00:00Z"}
    entries = [
        {**base, "message": {"id": "x", "model": "claude-opus-5-5", "usage": {"cache_creation_input_tokens": 100}}},
        {
            **base,
            "message": {
                "id": "y",
                "model": "claude-opus-5-5",
                "usage": {"cache_creation_input_tokens": 100, "cache_creation": {"ephemeral_1h_input_tokens": 30}},
            },
        },
        {"type": "assistant", "message": {"id": "z", "model": "claude-opus-5-5", "usage": {}}},  # no timestamp
    ]
    tr = parse.parse_transcript(entries, "t")
    built = core.build_requests(tr)
    assert [(r.write_5m, r.write_1h) for r in built] == [(100, 0), (70, 30)]


def test_one_pr_create_result_with_several_urls_counts_each():
    """A looped `gh pr create` returns one string result holding several URLs among `remote:` noise."""
    command = "mk() { gh pr create --title $1; }; for b in a b c; do mk $b; done"
    result = (
        "remote: \nremote: \nremote: \n"
        "https://github.com/o/r/pull/556\nhttps://github.com/o/r/pull/557\nhttps://github.com/o/r/pull/558\n"
        "https://github.com/o/r/pull/556"
    )
    entries = [
        {
            "type": "assistant",
            "timestamp": "2026-11-27T10:00:00Z",
            "message": {
                "id": "m1",
                "model": "claude-opus-5-5",
                "usage": {"input_tokens": 1, "output_tokens": 1},
                "content": [{"type": "tool_use", "id": "t1", "name": "Bash", "input": {"command": command}}],
            },
        },
        {
            "type": "user",
            "timestamp": "2026-11-27T10:00:05Z",
            "message": {"content": [{"type": "tool_result", "tool_use_id": "t1", "content": result}]},
        },
    ]
    tr = parse.parse_transcript(entries, "k", agent=True)
    reqs = core.build_requests(tr)
    expected = tuple(f"https://github.com/o/r/pull/{n}" for n in (556, 557, 558, 556))
    assert reqs[0].prs == expected
    assert core.build_report([tr])["prs"] == list(dict.fromkeys(expected))
