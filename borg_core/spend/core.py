"""Requests, prices, cold rewrites, causes and PRs from parsed transcripts, then the report dict. Pure."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime

from borg_core.spend.parse import CI_WAIT_KIND, PR_URL, Assist, Transcript
from borg_core.spend.pricing import COLD_WRITE_TOKENS, Rate, rate_for

LONG_TOOL_S = 300
IDLE_S = 300
HOURS_S = 120 * 60
PARTS = ("fresh", "output", "write_5m", "write_1h", "read")

FIRST = "first request"
COMPACTION = "compaction"
HOURS = "woken after hours or days"
CI = "waiting on CI"
LONG_TOOL = "long tool call"
IDLE = "idle outside tool calls"
UNDER = "under 5 min"


@dataclass(frozen=True)
# JUSTIFICATION: a flat record of one request; the token counts are the facts the report sums
class Request:  # pylint: disable=too-many-instance-attributes
    """One deduplicated API request (all entries sharing a message id merged)."""

    transcript: str
    agent: bool
    agent_type: str
    model: str
    start: datetime
    end: datetime
    fresh: int
    out: int
    write_5m: int
    write_1h: int
    read: int
    calls: tuple[tuple[str, float | None], ...]
    prs: tuple[str, ...]

    @property
    def write(self) -> int:
        """Total cache-write tokens."""
        return self.write_5m + self.write_1h

    @property
    def context(self) -> int:
        """Prompt size: fresh input plus cache writes plus cache reads."""
        return self.fresh + self.write + self.read

    @property
    def rate(self) -> Rate | None:
        """The model's rate, None when unknown."""
        return rate_for(self.model)

    @property
    def priced(self) -> bool:
        """False when the model has no rate."""
        return self.rate is not None

    def parts(self) -> dict[str, float]:
        """USD per cost part; all zero for an unpriced model."""
        rate = self.rate
        if rate is None:
            return dict.fromkeys(PARTS, 0.0)
        return {
            "fresh": self.fresh * rate.fresh / 1e6,
            "output": self.out * rate.out / 1e6,
            "write_5m": self.write_5m * rate.write_5m / 1e6,
            "write_1h": self.write_1h * rate.write_1h / 1e6,
            "read": self.read * rate.read / 1e6,
        }

    @property
    def cost(self) -> float:
        """Total USD."""
        return sum(self.parts().values())

    @property
    def write_cost(self) -> float:
        """USD of the cache write alone."""
        parts = self.parts()
        return parts["write_5m"] + parts["write_1h"]

    @property
    def cold(self) -> bool:
        """A cold rewrite: a cache write over the threshold."""
        return self.write > COLD_WRITE_TOKENS


def _merge(group: list[Assist]) -> Assist:
    first = min(group, key=lambda a: a.ts)
    tools = {t.id: t for a in group for t in a.tools}
    split = [a.write_5m for a in group if a.write_5m is not None]
    return Assist(
        first.msg_id, first.model, first.ts,
        max(a.fresh for a in group), max(a.out for a in group),
        max(a.write_total for a in group), max(split) if split else None,
        max(a.write_1h for a in group), max(a.read for a in group), tuple(tools.values()),
    )  # fmt: skip


def _request(tr: Transcript, group: list[Assist]) -> Request:
    merged = _merge(group)
    end = max(a.ts for a in group)
    write_1h = merged.write_1h
    # No split reported: every cache-write token is a 5m write.
    write_5m = merged.write_5m if merged.write_5m is not None else max(merged.write_total - write_1h, 0)
    calls, prs = [], []
    for tool in merged.tools:
        done = tr.results.get(tool.id)
        calls.append((tool.kind, (done[0] - end).total_seconds() if done else None))
        match = PR_URL.search(done[1]) if done and tool.pr else None
        if match:
            prs.append(match.group(0))
    return Request(
        tr.key, tr.agent, tr.agent_type, merged.model, merged.ts, end,
        merged.fresh, merged.out, write_5m, write_1h, merged.read, tuple(calls), tuple(prs),
    )  # fmt: skip


def build_requests(tr: Transcript) -> list[Request]:
    """Deduplicate a transcript's assistant entries by message id; ordered by start time."""
    groups: dict[str, list[Assist]] = defaultdict(list)
    for assist in tr.assists:
        groups[assist.msg_id].append(assist)
    return sorted((_request(tr, g) for g in groups.values()), key=lambda r: r.start)


def classify_cold(prev: Request | None, req: Request, boundaries: list[datetime]) -> str:
    """Why the cache was cold for `req`, from the measured duration of the previous request's tool calls."""
    if prev is None:
        return FIRST
    if any(prev.end <= b <= req.start for b in boundaries):
        return COMPACTION
    gap = (req.start - prev.end).total_seconds()
    if gap >= HOURS_S:
        return HOURS
    timed = [(dur, kind) for kind, dur in prev.calls if dur is not None]
    dur, kind = max(timed, default=(0.0, ""))
    if dur >= LONG_TOOL_S:
        return CI if kind == CI_WAIT_KIND else f"{LONG_TOOL} ({kind})"
    return IDLE if gap >= IDLE_S else UNDER


def cold_causes(transcripts: list[Transcript], keep) -> dict[str, dict]:
    """Cold rewrites in the window grouped by cause: count, tokens and write cost."""
    causes: dict[str, dict] = {}
    for tr in transcripts:
        reqs = build_requests(tr)
        for idx, req in enumerate(reqs):
            if not (req.cold and keep(req)):
                continue
            row = causes.setdefault(classify_cold(reqs[idx - 1] if idx else None, req, tr.boundaries), _blank())
            row["count"] += 1
            row["tokens"] += req.write
            row["cost"] += req.write_cost
    return causes


def _blank() -> dict:
    return {"count": 0, "tokens": 0, "cost": 0.0}


def _side(reqs: list[Request]) -> dict:
    models: dict[str, int] = defaultdict(int)
    for req in reqs:
        models[req.model] += 1
    return {"requests": len(reqs), "cost": sum(r.cost for r in reqs), "models": dict(sorted(models.items()))}


def _agent_types(reqs: list[Request]) -> list[dict]:
    rows: dict[str, dict] = {}
    for req in reqs:
        row = rows.setdefault(req.agent_type or "unknown", {"type": req.agent_type or "unknown", **_blank()})
        row["count"] += 1
        row["cost"] += req.cost
    return sorted(rows.values(), key=lambda r: -r["cost"])


def _prs(transcripts: list[Transcript], reqs: list[Request], since, until) -> list[str]:
    """PR URLs from PR-create tool results, plus the harness's own `pr-link` records, deduplicated by URL."""
    found = [(r.start, url) for r in reqs for url in r.prs]
    found += [
        (ts, url)
        for tr in transcripts
        for ts, url in tr.pr_links
        if (since is None or ts >= since) and (until is None or ts <= until)
    ]
    return list(dict.fromkeys(url for _, url in sorted(found)))


def _per(total: float, count: int) -> float | None:
    return total / count if count else None


def build_report(transcripts: list[Transcript], since: datetime | None = None, until: datetime | None = None) -> dict:
    """The report document for a session's transcripts, bounded on request start time."""

    def keep(req: Request) -> bool:
        return (since is None or req.start >= since) and (until is None or req.start <= until)

    reqs = [r for tr in transcripts for r in build_requests(tr) if keep(r)]
    main, agents = [r for r in reqs if not r.agent], [r for r in reqs if r.agent]
    total = sum(r.cost for r in reqs)
    main_cost, agent_cost = sum(r.cost for r in main), sum(r.cost for r in agents)
    parts = {p: sum(r.parts()[p] for r in reqs) for p in PARTS}
    prs = _prs(transcripts, reqs, since, until)
    causes = cold_causes(transcripts, keep)
    cold_cost = sum(r.write_cost for r in reqs if r.cold)
    unpriced = [r for r in reqs if not r.priced]
    return {
        "window": {
            "start": min((r.start for r in reqs), default=None),
            "end": max((r.end for r in reqs), default=None),
        },
        "total_usd": total,
        "main": {**_side(main), "share": main_cost / total if total else 0.0},
        "agents": {
            **_side(agents),
            "share": agent_cost / total if total else 0.0,
            "by_type": _agent_types(agents),
        },
        "parts": parts,
        "requests": {"main": len(main), "agents": len(agents), "total": len(reqs)},
        "prs": prs,
        "per_pr": {
            "cost": _per(total, len(prs)),
            "requests": _per(len(reqs), len(prs)),
            "agent_requests": _per(len(agents), len(prs)),
        },
        "agent_avg_context": _per(sum(r.context for r in agents), len(agents)),
        "cold": {
            "count": sum(c["count"] for c in causes.values()),
            "tokens": sum(c["tokens"] for c in causes.values()),
            "cost": cold_cost,
            "share": cold_cost / total if total else 0.0,
            "by_cause": dict(sorted(causes.items(), key=lambda kv: -kv[1]["cost"])),
        },
        "unpriced": {"requests": len(unpriced), "models": sorted({r.model for r in unpriced})},
    }


def pr_repositories(prs: list[str]) -> list[str]:
    """The distinct owner/repo of each PR URL, in order of first appearance."""
    return list(dict.fromkeys(PR_URL.match(url).group(1) for url in prs if PR_URL.match(url)))


def cross_check(found: list[str], listed: list[str]) -> dict[str, list[str]]:
    """Compare PR URLs the transcripts say were opened with those `gh pr list` returned."""
    return {
        "only_transcripts": sorted(set(found) - set(listed)),
        "only_gh": sorted(set(listed) - set(found)),
        "both": sorted(set(found) & set(listed)),
    }
