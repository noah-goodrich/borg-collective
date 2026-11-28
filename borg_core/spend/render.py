"""The human page for a report dict. Pure."""

from __future__ import annotations

from borg_core.spend.core import PARTS

PART_LABELS = {
    "fresh": "fresh input",
    "output": "output",
    "write_5m": "5m cache writes",
    "write_1h": "1h cache writes",
    "read": "cache reads",
}


def _usd(value: float | None) -> str:
    return "n/a" if value is None else f"${value:,.2f}"


def _num(value: float | None) -> str:
    return "n/a" if value is None else f"{value:,.1f}"


def _pct(value: float) -> str:
    return f"{value * 100:.0f}%"


def _when(value) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%SZ") if value else "n/a"


def _models(models: dict[str, int]) -> str:
    return ", ".join(f"{name} x{n}" for name, n in models.items()) or "none"


def render(report: dict, session: str) -> str:
    """The report as a plain-text page."""
    win, req, cold, per = report["window"], report["requests"], report["cold"], report["per_pr"]
    lines = [
        f"Session spend {session}",
        f"  window         {_when(win['start'])} .. {_when(win['end'])}",
        f"  total          {_usd(report['total_usd'])}  ({req['total']} requests)",
        f"  main           {_usd(report['main']['cost'])}  {_pct(report['main']['share'])}  "
        f"{req['main']} requests  [{_models(report['main']['models'])}]",
        f"  agents         {_usd(report['agents']['cost'])}  {_pct(report['agents']['share'])}  "
        f"{req['agents']} requests  [{_models(report['agents']['models'])}]",
        "  cost parts",
        *(f"    {PART_LABELS[p]:<16} {_usd(report['parts'][p])}" for p in PARTS),
        f"  PRs opened     {len(report['prs'])}",
        *(f"    {url}" for url in report["prs"]),
        f"  per PR         {_usd(per['cost'])}, {_num(per['requests'])} requests, "
        f"{_num(per['agent_requests'])} agent requests",
        f"  agent context  {_num(report['agent_avg_context'])} tokens per agent request",
        f"  cold rewrites  {cold['count']}  {cold['tokens']:,} tokens  {_usd(cold['cost'])}  "
        f"{_pct(cold['share'])} of total",
        *(
            f"    {cause:<34} {row['count']:>4}  {row['tokens']:>12,} tokens  {_usd(row['cost'])}"
            for cause, row in cold["by_cause"].items()
        ),
        f"  unpriced: {report['unpriced']['requests']} requests"
        + (
            f" (models: {', '.join(report['unpriced']['models'])}) counted at $0, total is a floor"
            if report["unpriced"]["requests"]
            else ""
        ),
    ]
    return "\n".join(lines)


def render_cross_check(check: dict[str, list[str]]) -> str:
    """The cross-check result: PRs found in only one of the two lists."""
    lines = [f"cross-check: {len(check['both'])} PRs in both lists"]
    lines += [f"  only in transcripts: {url}" for url in check["only_transcripts"]]
    lines += [f"  only in gh pr list:  {url}" for url in check["only_gh"]]
    if not (check["only_transcripts"] or check["only_gh"]):
        lines.append("  the two lists match")
    return "\n".join(lines)
