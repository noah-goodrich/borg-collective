"""PURE: the `borg next` item the weekly eval sweep raises, decided from `sweep-last.json` and three facts.

No clock, filesystem or environment: the shell (borg_core/nextpick/shell.py `sweep_items`) reads the file and the
agent's plist mtime and passes the epochs in. The document contract is borg_core/evals/sweep/core.py (schema 1,
unknown keys ignored, an unknown schema is unreadable); `SWEEP_SCHEMA` here is pinned equal to it by a test.

THE RULES, for a waits-on-you item (owner YOU):

* the last sweep has a skip, an error or a fail, or was halted: name the cases, their reasons and the command to look;
* the sweep AGENT is installed and the last sweep is older than `STALE_DAYS` (a weekly job plus one day of slack):
  the silent-launchd-failure case;
* GRACE for a missing file: nothing until the agent has been installed for more than `STALE_DAYS`. A machine that
  never opted in (no plist) never nags, day one is quiet, and an agent installed but never run does nag once the
  week and its slack have passed;
* a file that is malformed or has an unknown schema is raised as unreadable only while the agent is installed.

Staleness and the missing-file nag need the agent installed (`installed_epoch` is not None); a failing sweep is
raised either way, because a manual run's failure is just as true.
"""

from __future__ import annotations

from typing import Any

SWEEP_SCHEMA = 1
STALE_DAYS = 8
SHOWN_CASES = 3
REASON_MAX = 70
_DAY = 86400


def sweep_summary(doc: Any) -> dict[str, Any] | None:
    """The document when it is a readable schema-1 summary, else None. Unknown keys are fine."""
    if not isinstance(doc, dict) or doc.get("schema") != SWEEP_SCHEMA:
        return None
    if not isinstance(doc.get("needs_attention"), bool) or not isinstance(doc.get("cases"), list):
        return None
    if not all(isinstance(c, dict) for c in doc["cases"]):
        return None
    return doc


def _cut(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[: limit - 1] + "…"


def _case_phrase(case: dict[str, Any]) -> str:
    label = f"{case.get('harness', '?')}/{case.get('case', '?')} {case.get('verdict', '?')}"
    reason = str(case.get("reason") or "")
    return f"{label} ({_cut(reason, REASON_MAX)})" if reason else label


def _attention_text(doc: dict[str, Any], look: str) -> str:
    halted = str(doc.get("halted") or "")
    bad = [c for c in doc["cases"] if c.get("verdict") in ("skip", "error", "fail")]
    parts = [_case_phrase(c) for c in bad[:SHOWN_CASES]]
    if len(bad) > SHOWN_CASES:
        parts.append(f"+{len(bad) - SHOWN_CASES} more")
    head = f"last eval sweep was halted: {_cut(halted, REASON_MAX)}" if halted else "last eval sweep needs a look"
    detail = "; ".join(parts)
    return f"{head}{': ' + detail if detail else ''}. Look: {look}"


def _missing(installed_days: float | None, look: str) -> list[dict[str, str]]:
    if installed_days is not None and installed_days > STALE_DAYS:
        text = f"the eval sweep agent was installed {int(installed_days)} days ago and has never produced a sweep"
        return [_item(f"{text}. Look: {look}")]
    return []


def _present(
    summary: dict[str, Any] | None, age_days: float | None, installed: bool, look: str
) -> list[dict[str, str]]:
    if summary is None or age_days is None:
        unreadable = f"sweep-last.json is unreadable (malformed or an unknown schema). Look: {look}"
        return [_item(unreadable)] if installed else []
    if installed and age_days > STALE_DAYS:
        return [_item(f"no eval sweep for {int(age_days)} days; the weekly launchd job is not running. Look: {look}")]
    return [_item(_attention_text(summary, look))] if summary["needs_attention"] else []


# JUSTIFICATION: six independent facts of one decision (file, clock, two stamps, command); a wrapper only renames them
def sweep_items(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    present: bool,
    doc: Any,
    now_epoch: float,
    ts_epoch: float | None,
    installed_epoch: float | None,
    look: str,
) -> list[dict[str, str]]:
    """Zero or one `{"text", "owner": "YOU"}` item. `present` is whether the file existed; `doc` its parsed JSON
    (None when it would not parse); `ts_epoch` the summary's own finish time; `installed_epoch` the agent's plist
    mtime, None when the agent is not installed; `look` the command to read the evidence."""
    installed_days = None if installed_epoch is None else (now_epoch - installed_epoch) / _DAY
    if not present:
        return _missing(installed_days, look)
    age_days = None if ts_epoch is None else (now_epoch - ts_epoch) / _DAY
    return _present(sweep_summary(doc), age_days, installed_epoch is not None, look)


def _item(text: str) -> dict[str, str]:
    return {"text": text, "owner": "YOU"}
