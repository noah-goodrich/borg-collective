"""Pure logic for the PR verbs: classify a check rollup and decide when a wait is over.

No subprocess, no clock of its own, no environment. `cli.py` supplies the I/O callables.
"""

from __future__ import annotations

import re
from typing import Callable

GREEN, FAILING, PENDING, NO_RUNNER = "green", "failing", "pending", "cancelled-no-runner"
EXIT = {GREEN: 0, FAILING: 1, PENDING: 2, NO_RUNNER: 3}
_ZERO_TIME = "0001-01-01T00:00:00Z"
_GOOD = {"SUCCESS", "SKIPPED", "NEUTRAL"}
_RUN_ID = re.compile(r"/actions/runs/(\d+)")


def _bucket(check: dict) -> str:
    """Return pass | fail | pending | no_runner for one rollup entry (CheckRun or StatusContext)."""
    if "state" in check and "conclusion" not in check:  # StatusContext
        state = (check.get("state") or "").upper()
        return {"SUCCESS": "pass", "PENDING": "pending", "EXPECTED": "pending"}.get(state, "fail")
    if (check.get("status") or "").upper() != "COMPLETED":
        return "pending"
    conclusion = (check.get("conclusion") or "").upper()
    if conclusion in _GOOD:
        return "pass"
    if conclusion == "CANCELLED" and (check.get("startedAt") or _ZERO_TIME) == _ZERO_TIME:
        return "no_runner"
    return "fail"


def _name(check: dict) -> str:
    return check.get("name") or check.get("context") or "?"


def classify(view: dict) -> dict:
    """Summarise a `gh pr view --json statusCheckRollup,...` payload into the gate document."""
    counts = {"pass": 0, "fail": 0, "pending": 0, "cancelled_no_runner": 0}
    failing: list[str] = []
    run_ids: list[str] = []
    for check in view.get("statusCheckRollup") or []:
        bucket = _bucket(check)
        counts["cancelled_no_runner" if bucket == "no_runner" else bucket] += 1
        if bucket == "fail":
            failing.append(_name(check))
        if bucket == "no_runner":
            found = _RUN_ID.search(check.get("detailsUrl") or "")
            if found and found.group(1) not in run_ids:
                run_ids.append(found.group(1))
    if counts["fail"]:
        verdict = FAILING
    elif counts["cancelled_no_runner"]:
        verdict = NO_RUNNER
    elif counts["pending"]:
        verdict = PENDING
    else:
        verdict = GREEN
    return {"head": view.get("headRefOid", ""), "state": view.get("state", ""), "verdict": verdict,
            "checks": counts, "failing": failing, "rerun_run_ids": run_ids,
            "merge_state": view.get("mergeStateStatus", "")}


def wait_for_verdict(fetch: Callable[[], dict], sleep: Callable[[], None], expired: Callable[[], bool],
                     on_no_runner: Callable[[dict], bool] | None = None, grace_polls: int = 3) -> dict:
    """Poll `fetch` until the verdict is terminal or `expired()`; return the last gate document.

    Terminal: green, failing, or no-runner. A no-runner verdict first goes to `on_no_runner(doc)`; if that
    returns True (a rerun was issued) the verdict is treated as pending for `grace_polls` consecutive polls,
    because the rollup can lag the rerun; past that it is terminal. Without a handler it is terminal at once.
    The returned doc carries `timed_out` True when `expired()` ended the wait while still pending.
    """
    seen_after_rerun = 0
    rerun_issued = False
    while True:
        doc = classify(fetch())
        doc["timed_out"] = False
        verdict = doc["verdict"]
        if verdict == NO_RUNNER:
            if rerun_issued:
                seen_after_rerun += 1
                if seen_after_rerun >= grace_polls:
                    return doc
            elif on_no_runner is not None and on_no_runner(doc):
                rerun_issued = True
            else:
                return doc
        elif verdict != PENDING:
            return doc
        else:
            seen_after_rerun = 0
        if expired():
            doc["timed_out"] = True
            return doc
        sleep()
