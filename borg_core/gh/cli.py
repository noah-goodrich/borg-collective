"""`python3 -m borg_core.gh.cli` -- the engine behind `borg pr gate` and `borg pr merge-train`.

    gate <n> [--repo R] [--wait] [--timeout S] [--json]
        Exit 0 green, 1 failing, 2 pending (or --wait timeout), 3 cancelled without ever getting a runner.
    merge-train <n...> [--repo R] [--method squash] [--dry-run] [--yes]
        Per PR in order: update-branch if behind, wait for checks on the new head, rerun a runner-less cancel
        once, merge pinned to the gated head. Stops at the first problem: 1 failing, 2 timeout (one deadline
        for the whole train), 3 runner-less twice, 4 conflict, 5 head moved or unknown (re-gate), 6 gh error,
        7 PR closed or not mergeable.
    Usage errors exit 64 for both verbs.

merge-train MERGES. Only a human or the orchestrator main loop may run it; workflow agents and nanoprobes
must never call it. Nothing in this code can tell an agent from a human (no agent-context marker exists, and
--yes is a documented flag), so the prohibition is a rule, not a gate: it lives in the agent-facing rules.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from typing import NoReturn

from borg_core.gh import core, shell

USAGE = 64
CONFLICT, HEAD_MOVED, GH_ERROR, NOT_MERGEABLE = 4, 5, 6, 7
EMPTY_ROLLUP_GRACE_POLLS = 3


def _say(msg: str) -> None:
    print(msg, file=sys.stderr)


def _emit(doc, args: argparse.Namespace) -> None:
    # JUSTIFICATION: stdlib stream/regex/method access is a two-step chain by design
    if args.json or not sys.stdout.isatty():  # pylint: disable=clean-arch-demeter
        print(json.dumps(doc, indent=2))


# JUSTIFICATION: independent keyword-passed knobs of the poll loop; a config object would just rename them
def _waiter(  # pylint: disable=too-many-arguments,too-many-positional-arguments
    n: int, args: argparse.Namespace, deadline: float, on_no_runner=None, stale_head: str = "", empty_grace: int = 0
) -> dict:
    return core.wait_for_verdict(
        lambda: shell.view(n, args.repo),
        lambda: time.sleep(args.interval),
        lambda: time.monotonic() >= deadline,
        on_no_runner,
        stale_head=stale_head,
        empty_grace=empty_grace,
    )


def _gate(args: argparse.Namespace) -> int:
    n = args.pr
    if args.wait:
        doc = _waiter(n, args, time.monotonic() + args.timeout)
    else:
        doc = core.classify(shell.view(n, args.repo))
    out = {
        "n": n,
        "head": doc["head"],
        "state": doc["state"],
        "verdict": doc["verdict"],
        "checks": doc["checks"],
        "failing": doc["failing"],
    }
    c = doc["checks"]
    failing = f" (failing: {', '.join(doc['failing'])})" if doc["failing"] else ""
    _say(
        f"#{n} {doc['verdict']}: {c['pass']} pass, {c['fail']} fail, {c['pending']} pending, "
        f"{c['cancelled_no_runner']} cancelled without a runner{failing}"
    )
    _emit(out, args)
    return core.EXIT[doc["verdict"]]


class _Train:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.report: list[dict] = []
        self.deadline = time.monotonic() + args.timeout

    def log(self, n: int, action: str, result: str, head: str, **extra) -> None:
        """Append one step to the machine-readable report."""
        self.report.append({"n": n, "action": action, "result": result, "head": head, **extra})

    def stop(self, code: int, msg: str) -> int:
        """Say `msg`, emit the report so far, and return the exit code `code`."""
        _say(msg)
        _emit(self.report, self.args)
        return code

    def one(self, n: int) -> int:
        """Process one PR. Returns 0 to continue the train, else the exit code that stops it."""
        v = shell.view(n, self.args.repo)
        head = v.get("headRefOid", "")
        if v.get("state") == "MERGED":
            self.log(n, "merge", "already-merged", head)
            return 0
        if v.get("state") == "CLOSED":
            self.log(n, "merge", "closed", head)
            return self.stop(NOT_MERGEABLE, f"#{n} is closed without being merged; train stopped")
        if v.get("mergeStateStatus") == "DIRTY":
            self.log(n, "update-branch", "conflict", head)
            return self.stop(CONFLICT, f"#{n} has merge conflicts; train stopped before touching later PRs")
        behind = v.get("mergeStateStatus") == "BEHIND"
        if self.args.dry_run:
            if behind:
                self.log(n, "update-branch", "planned", head)
            self.log(n, "merge", "planned", head)
            return 0
        if behind:
            code = self._update(n, head)
            if code:
                return code
        return self._wait_and_merge(n, head if behind else "")

    def _update(self, n: int, head: str) -> int:
        rc, msg = shell.update_branch(n, self.args.repo)
        if rc != 0:
            if "conflict" in msg.lower():
                self.log(n, "update-branch", "conflict", head)
                return self.stop(CONFLICT, f"#{n} update-branch hit a conflict: {msg}")
            self.log(n, "update-branch", "error", head)
            return self.stop(GH_ERROR, f"#{n} update-branch failed: {msg}")
        self.log(n, "update-branch", "ok", head)
        return 0

    def _wait_and_merge(self, n: int, stale_head: str) -> int:
        a = self.args
        reran = {"done": False}

        def rerun(doc: dict) -> bool:
            if reran["done"] or not doc["rerun_run_ids"]:
                return False
            for run_id in doc["rerun_run_ids"]:
                rc, msg = shell.rerun_failed(run_id, a.repo)
                if rc != 0 and "in progress" not in msg.lower():
                    raise shell.GhError(f"gh run rerun {run_id} failed: {msg}")
                if rc != 0:  # still running: not rerunnable yet, so keep waiting and try again
                    self.log(n, "rerun", "deferred-in-progress", doc["head"])
                    return True
            reran["done"] = True
            self.log(n, "rerun", "requested", doc["head"])
            return True

        doc = _waiter(n, a, self.deadline, rerun, stale_head, EMPTY_ROLLUP_GRACE_POLLS)
        head = doc["head"]
        blocked = {
            core.FAILING: (1, "failing", f"#{n} failing: {', '.join(doc['failing'])}"),
            core.NO_RUNNER: (3, "cancelled-no-runner", f"#{n} cancelled without a runner again after one rerun"),
            core.PENDING: (2, "timeout", f"#{n} checks still pending when the train deadline ({a.timeout:g}s) hit"),
        }
        if doc["verdict"] in blocked:
            code, result, msg = blocked[doc["verdict"]]
            self.log(n, "wait", result, head)
            return self.stop(code, msg)
        self.log(n, "wait", "green", head)
        return self._merge(n, head)

    def _merge(self, n: int, head: str) -> int:
        if not head:
            self.log(n, "merge", "no-head", head)
            return self.stop(HEAD_MOVED, f"#{n} has no known head commit to pin the merge to; re-gate")
        rc, msg = shell.merge(n, head, self.args.method, self.args.repo)
        if rc != 0:
            return self._merge_failed(n, head, msg)
        sha = (shell.view(n, self.args.repo).get("mergeCommit") or {}).get("oid")
        self.log(n, "merge", "merged", head, merge_sha=sha)
        _say(f"#{n} merged ({sha or 'sha unknown'})")
        return 0

    def _merge_failed(self, n: int, head: str, msg: str) -> int:
        lowered = msg.lower()
        if "head branch was modified" in lowered or "match-head-commit" in lowered or "head sha" in lowered:
            self.log(n, "merge", "head-moved", head)
            return self.stop(HEAD_MOVED, f"#{n} head moved since the gate (re-gate required): {msg}")
        now = shell.view(n, self.args.repo)
        if now.get("state") == "CLOSED":
            self.log(n, "merge", "closed", head)
            return self.stop(NOT_MERGEABLE, f"#{n} was closed before it could merge: {msg}")
        if now.get("mergeStateStatus") == "DIRTY":
            self.log(n, "merge", "conflict", head)
            return self.stop(CONFLICT, f"#{n} has merge conflicts: {msg}")
        if now.get("headRefOid") and now.get("headRefOid") != head:
            self.log(n, "merge", "head-moved", head)
            return self.stop(HEAD_MOVED, f"#{n} head moved since the gate (re-gate required): {msg}")
        self.log(n, "merge", "error", head)
        return self.stop(GH_ERROR, f"#{n} merge failed ({now.get('mergeStateStatus') or 'state unknown'}): {msg}")


def _merge_train(args: argparse.Namespace) -> int:
    # JUSTIFICATION: stdlib stream/regex/method access is a two-step chain by design
    if not args.dry_run and not args.yes and not sys.stdin.isatty():  # pylint: disable=clean-arch-demeter
        _say(
            "borg pr merge-train: stdin is not a TTY; pass --yes to confirm a non-interactive merge "
            "(workflow agents and nanoprobes must not run this)"
        )
        return USAGE
    train = _Train(args)
    for n in args.prs:
        # JUSTIFICATION: stdlib stream/regex/method access is a two-step chain by design
        code = train.one(n)  # pylint: disable=clean-arch-demeter
        if code:
            return code
    _emit(train.report, args)
    return 0


class _Parser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        """Usage errors exit 64: argparse's default 2 collides with the pending verdict."""
        self.print_usage(sys.stderr)
        self.exit(USAGE, f"{self.prog}: error: {message}\n")


def _seconds(minimum_exclusive: bool):
    """argparse type factory: a float >= 0 (> 0 when `minimum_exclusive`); NaN is rejected."""

    def parse(text: str) -> float:
        try:
            value = float(text)
        except ValueError:
            raise argparse.ArgumentTypeError(f"not a number: {text!r}") from None
        if math.isnan(value) or value < 0 or (minimum_exclusive and value == 0):
            raise argparse.ArgumentTypeError(f"must be {'> 0' if minimum_exclusive else '>= 0'}: {text}")
        return value

    return parse


def _build_parser() -> argparse.ArgumentParser:
    parser = _Parser(prog="borg pr", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("verb", choices=("gate", "merge-train"))
    parser.add_argument("prs", nargs="+", type=int, metavar="n", help="PR number(s); gate takes exactly one")
    parser.add_argument("--repo", default="", help="owner/name (default: the current checkout's repo)")
    parser.add_argument("--json", action="store_true", help="JSON on stdout (automatic when not a TTY)")
    parser.add_argument("--wait", action="store_true", help="gate: poll until a terminal verdict")
    parser.add_argument(
        "--timeout",
        type=_seconds(False),
        default=1800.0,
        help="wait ceiling in seconds; one deadline for a whole merge-train (default 1800)",
    )
    parser.add_argument("--interval", type=_seconds(True), default=20.0, help="poll interval in seconds (default 20)")
    parser.add_argument("--method", default="squash", choices=("squash", "merge", "rebase"))
    parser.add_argument("--dry-run", action="store_true", help="merge-train: print the plan, mutate nothing")
    parser.add_argument("--yes", action="store_true", help="merge-train: confirm when stdin is not a TTY")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point for `borg pr`; return the process exit code."""
    args = _build_parser().parse_args(argv)
    try:
        if args.verb == "gate":
            if len(args.prs) != 1:
                _say("borg pr gate: takes exactly one PR number")
                return USAGE
            args.pr = args.prs[0]
            return _gate(args)
        return _merge_train(args)
    except shell.GhError as exc:
        _say(f"borg pr {args.verb}: {exc}")
        return GH_ERROR
    except BrokenPipeError:
        return 0


if __name__ == "__main__":
    sys.exit(main())
