"""Skill trigger suites, the PURE half (plan #480 step 4, AC4): suite validation, the plugin-list abort, grading.

A trigger suite is `evals/triggers/<skill>.json`, a JSON array of labeled queries for ONE self-firing skill::

    {"id": "pane-01", "skill": "pane", "query": "split the pane to the right", "should_fire": true}
    {"id": "pane-09", "skill": "pane", "query": "...a request that belongs to a competing skill...",
     "should_fire": false, "competitor": "borg-switch"}

`id`, `skill`, `should_fire` and `query` are the fields the Cortex probe's cases (evals/cortex-skill-trigger) use too.

A `should_fire: false` case is a NEAR-MISS: a request that sits next to the skill (a competing skill's job, a shared
word) and must NOT load it. A suite needs at least 20 cases and at least 40% near-misses (testing-tiers.md: one-sided
cases give one-sided optimization). The prompt never names the skill under test.

TWO MODES. `isolated` runs `claude -p --plugin-dir <build> --setting-sources project`, so only the build under review
(plus Claude Code's own `cc-plugin-*` bundled plugins) is loaded. `in-situ` runs the same with the user's real plugin
set, which is the only mode that measures competition between skills. A `claude -p` that became `--bare` loads NO plugin
and every near-miss would pass for the wrong reason, so every run reads the plugin list from the `system/init` event and
ABORTS on a mismatch (`plugin_problems`) before any verdict is recorded.

Nothing here touches a clock, a subprocess or the network; `triggers_cli` is the I/O half.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any

from borg_core.evals.runstats import wilson

PLUGIN = "borg-collective"
MODES = ("isolated", "in-situ")
MIN_CASES = 20
MIN_NEAR_MISS = 0.4
MIN_POSITIVE = 8
TRAIN_SHARE = 0.6
BUILTIN_PREFIX = "cc-plugin-"


def short_name(skill: str) -> str:
    """`borg-collective:pane` and `pane` are the same skill."""
    return skill.rsplit(":", 1)[-1]


def validate_suite(skill: str, cases: Any) -> list[str]:
    """Every way a suite is too small, too one-sided, malformed or hinting. An empty list means it is admissible."""
    if not isinstance(cases, list):
        return [f"{skill}: a suite is a JSON array of cases"]
    problems: list[str] = []
    seen_ids: set[str] = set()
    seen_queries: set[str] = set()
    for index, case in enumerate(cases):
        problems += _case_problems(skill, index, case, seen_ids, seen_queries)
    near = sum(1 for c in cases if isinstance(c, dict) and c.get("should_fire") is False)
    positive = sum(1 for c in cases if isinstance(c, dict) and c.get("should_fire") is True)
    if len(cases) < MIN_CASES:
        problems.append(f"{skill}: {len(cases)} cases, need at least {MIN_CASES}")
    if cases and near / len(cases) < MIN_NEAR_MISS:
        problems.append(f"{skill}: {near} near-misses of {len(cases)}, need at least {MIN_NEAR_MISS:.0%}")
    if positive < MIN_POSITIVE:
        problems.append(f"{skill}: {positive} should-fire cases, need at least {MIN_POSITIVE}")
    return problems


def _case_problems(skill: str, index: int, case: Any, seen_ids: set[str], seen_queries: set[str]) -> list[str]:
    where = f"{skill}[{index}]"
    if not isinstance(case, dict):
        return [f"{where}: a case is an object"]
    problems = []
    case_id, query = case.get("id"), case.get("query")
    id_problem = _id_problem(skill, case_id, seen_ids)
    problems += [f"{where}: {id_problem}"] if id_problem else []
    if not isinstance(query, str) or not query.strip():
        problems.append(f"{where}: query must be a non-empty string")
    else:
        if query.strip().lower() in seen_queries:
            problems.append(f"{where}: duplicate query")
        seen_queries.add(query.strip().lower())
        if _names_skill(skill, query):
            problems.append(f"{where}: the query names the skill under test ({skill})")
    if case.get("skill") != skill:
        problems.append(f"{where}: skill must be '{skill}' (the same field the Cortex probe cases carry)")
    if not isinstance(case.get("should_fire"), bool):
        problems.append(f"{where}: should_fire must be true or false")
    if case.get("should_fire") is False and not case.get("competitor"):
        problems.append(f"{where}: a near-miss names its competitor (the skill or tool whose job this is)")
    return problems


def _id_problem(skill: str, case_id: Any, seen_ids: set[str]) -> str:
    """What is wrong with a case id, or "" (and the id is remembered)."""
    if not isinstance(case_id, str) or not case_id.startswith(f"{skill}-"):
        return f"id must be a string starting '{skill}-'"
    if case_id in seen_ids:
        return f"duplicate id {case_id}"
    seen_ids.add(case_id)
    return ""


def _names_skill(skill: str, query: str) -> bool:
    """A slash form, the plugin prefix, or (for a hyphenated name) the name itself. `pane` is also an English word."""
    low = query.lower()
    return f"/{skill}" in low or f"{PLUGIN}:{skill}" in low or ("-" in skill and skill in low)


def split_cases(cases: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """The 60/40 train / held-out split step 6 needs: stable, stratified by label, a function of the case id only.

    Inside each label the cases are ordered by sha256 of the id; the first ceil(60%) are train. Adding a case never
    moves another case across the line except by displacing the boundary one place within its own label.
    """
    train: list[dict[str, Any]] = []
    held: list[dict[str, Any]] = []
    for label in (True, False):
        group = sorted((c for c in cases if c["should_fire"] is label), key=lambda c: _digest(c["id"]))
        cut = -(-len(group) * 6 // 10)
        train += group[:cut]
        held += group[cut:]
    return train, held


def _digest(case_id: str) -> str:
    return hashlib.sha256(case_id.encode("utf-8")).hexdigest()


def plugin_problems(
    init: dict[str, Any] | None, mode: str, plugin_dir: str, expected: list[str] | None = None
) -> list[str]:
    """The abort rule. Empty means the run really loaded what the mode claims; anything else means ABORT.

    `init` is the `system/init` event. Both modes need the build under review loaded from `plugin_dir` (source
    `borg-collective@inline`: an installed copy would grade the previous release). `isolated` allows nothing else but
    Claude Code's bundled `cc-plugin-*`; `in-situ` needs the loaded set to equal `expected` (the enabled plugin names).
    """
    if init is None:
        return ["no system/init event in the stream: the run never started"]
    if mode not in MODES:
        return [f"unknown mode {mode!r}"]
    plugins = [p for p in init.get("plugins") or [] if isinstance(p, dict)]
    names = sorted({str(p.get("name")) for p in plugins if not str(p.get("name")).startswith(BUILTIN_PREFIX)})
    problems = []
    ours = [p for p in plugins if p.get("name") == PLUGIN]
    inline = [p for p in ours if p.get("source") == f"{PLUGIN}@inline" and p.get("path") == plugin_dir]
    no_plugin = [f"{PLUGIN} is not loaded (a --bare run loads no plugin); loaded: {names or 'none'}"]
    not_build = [f"{PLUGIN} is not the build under review at {plugin_dir}: {[p.get('source') for p in ours]}"]
    problems += no_plugin if not ours else (not_build if not inline else [])
    if mode == "isolated" and names != [PLUGIN] and ours:
        problems.append(f"isolated run loaded other plugins: {[n for n in names if n != PLUGIN]}")
    if mode == "in-situ" and expected is not None:
        want = sorted(set(expected) | {PLUGIN})
        if names != want:
            missing, extra = sorted(set(want) - set(names)), sorted(set(names) - set(want))
            problems.append(f"plugin list mismatch: missing {missing}, extra {extra}")
    return problems


def parse_stream(text: str) -> dict[str, Any]:
    """From a stream-json capture: the init event, every skill the model invoked (short names, in order), the result."""
    init: dict[str, Any] | None = None
    invoked: list[str] = []
    result: dict[str, Any] | None = None
    for line in text.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        if event.get("type") == "system" and event.get("subtype") == "init" and init is None:
            init = event
        elif event.get("type") == "result":
            result = event
        elif event.get("type") == "assistant":
            invoked += _skill_calls(event)
    return {"init": init, "invoked": invoked, "result": result}


def _skill_calls(event: dict[str, Any]) -> list[str]:
    content = (event.get("message") or {}).get("content")
    if not isinstance(content, list):
        return []
    found = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == "Skill":
            skill = (block.get("input") or {}).get("skill")
            if isinstance(skill, str):
                found.append(short_name(skill))
    return found


def run_problems(parsed: dict[str, Any]) -> list[str]:
    """A run that never produced an answer (a session limit, an auth failure, a budget stop before the first turn).

    Without this a refusal text reads as "the skill did not load" and grades a should-fire case as a miss.
    """
    result = parsed["result"]
    if result is None:
        return ["no result event in the stream: the run was cut off"]
    if result.get("is_error"):
        return [f"the run failed before answering: {str(result.get('result'))[:120]}"]
    return []


def cli_version(init: dict[str, Any] | None) -> str | None:
    """The Claude Code version the run reported. Runs of different versions are never pooled."""
    return (init or {}).get("claude_code_version")


def grade(skill: str, case: dict[str, Any], invoked: list[str]) -> tuple[str, str]:
    """(verdict, reason). A positive passes iff the skill loaded; a near-miss passes iff it did NOT load."""
    fired = skill in invoked
    other = [name for name in invoked if name != skill]
    if case["should_fire"]:
        if fired:
            return "pass", ""
        return "fail", f"missed: loaded {other or 'no skill'}"
    if fired:
        return "fail", "misfire: loaded the skill on a near-miss"
    return "pass", ""


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Accuracy with its Wilson interval, split into recall (should-fire) and specificity (near-miss).

    Each row is {"should_fire": bool, "verdict": "pass"|"fail"|...}; skip and error rows are counted, not scored.
    """
    scored = [r for r in rows if r["verdict"] in ("pass", "fail")]
    out: dict[str, Any] = {"unscored": len(rows) - len(scored)}
    for name, subset in (
        ("all", scored),
        ("recall", [r for r in scored if r["should_fire"]]),
        ("specificity", [r for r in scored if not r["should_fire"]]),
    ):
        passes = sum(1 for r in subset if r["verdict"] == "pass")
        out[name] = {"k": passes, "n": len(subset), "interval": wilson(passes, len(subset))}
    return out
