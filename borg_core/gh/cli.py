"""`python3 -m borg_core.gh.cli` -- the engine behind `borg pr gate` and `borg pr merge-train`.

    gate <n> [--repo R] [--wait] [--timeout S] [--json]
        Exit 0 green, 1 failing, 2 pending (or --wait timeout), 3 cancelled without ever getting a runner.
    merge-train <n...> [--repo R] [--method squash] [--dry-run] [--yes]
        Per PR in order: update-branch if behind, wait for checks, rerun a runner-less cancel once, merge
        pinned to the gated head. Stops at the first problem: 1 failing, 2 timeout, 3 runner-less twice,
        4 conflict, 5 head moved since the gate (re-gate), 64 usage or gh error.

merge-train MERGES. Only a human or the orchestrator main loop may run it; workflow agents and nanoprobes
must never call it (merge steps inside workflows refuse, and the authority is not theirs).
"""

from __future__ import annotations

import argparse
import json
import sys
import time

from borg_core.gh import core, shell

USAGE = 64
CONFLICT, HEAD_MOVED = 4, 5


def _say(msg: str) -> None:
    print(msg, file=sys.stderr)


def _emit(doc, args: argparse.Namespace) -> None:
    if args.json or not sys.stdout.isatty():
        print(json.dumps(doc, indent=2))


def _waiter(n: int, args: argparse.Namespace, on_no_runner=None) -> dict:
    deadline = time.monotonic() + args.timeout
    return core.wait_for_verdict(lambda: shell.view(n, args.repo), lambda: time.sleep(args.interval),
                                 lambda: time.monotonic() >= deadline, on_no_runner)


def _gate(args: argparse.Namespace) -> int:
    n = args.pr
    if args.wait:
        doc = _waiter(n, args)
    else:
        doc = core.classify(shell.view(n, args.repo))
    out = {"n": n, "head": doc["head"], "state": doc["state"], "verdict": doc["verdict"],
           "checks": doc["checks"], "failing": doc["failing"]}
    c = doc["checks"]
    _say(f"#{n} {doc['verdict']}: {c['pass']} pass, {c['fail']} fail, {c['pending']} pending, "
         f"{c['cancelled_no_runner']} cancelled without a runner" + (f" (failing: {', '.join(doc['failing'])})"
                                                                     if doc["failing"] else ""))
    _emit(out, args)
    return core.EXIT[doc["verdict"]]


class _Train:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.report: list[dict] = []

    def log(self, n: int, action: str, result: str, head: str, **extra) -> None:
        self.report.append({"n": n, "action": action, "result": result, "head": head, **extra})

    def stop(self, code: int, msg: str) -> int:
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
        return self._wait_and_merge(n)

    def _update(self, n: int, head: str) -> int:
        rc, msg = shell.update_branch(n, self.args.repo)
        if rc != 0:
            self.log(n, "update-branch", "conflict", head)
            return self.stop(CONFLICT, f"#{n} update-branch failed (conflict?): {msg}")
        self.log(n, "update-branch", "ok", head)
        return 0

    def _wait_and_merge(self, n: int) -> int:
        a = self.args
        reran = {"done": False}

        def rerun(doc: dict) -> bool:
            if reran["done"] or not doc["rerun_run_ids"]:
                return False
            for run_id in doc["rerun_run_ids"]:
                shell.rerun_failed(run_id, a.repo)
            reran["done"] = True
            self.log(n, "rerun", "requested", doc["head"])
            return True

        doc = _waiter(n, a, rerun)
        head = doc["head"]
        blocked = {core.FAILING: (1, "failing", f"#{n} failing: {', '.join(doc['failing'])}"),
                   core.NO_RUNNER: (3, "cancelled-no-runner",
                                    f"#{n} cancelled without a runner again after one rerun"),
                   core.PENDING: (2, "timeout", f"#{n} checks still pending after {a.timeout:g}s")}
        if doc["verdict"] in blocked:
            code, result, msg = blocked[doc["verdict"]]
            self.log(n, "wait", result, head)
            return self.stop(code, msg)
        self.log(n, "wait", "green", head)
        return self._merge(n, head)

    def _merge(self, n: int, head: str) -> int:
        rc, msg = shell.merge(n, head, self.args.method, self.args.repo)
        if rc != 0:
            lowered = msg.lower()
            if "head branch was modified" in lowered or "match" in lowered:
                self.log(n, "merge", "head-moved", head)
                return self.stop(HEAD_MOVED, f"#{n} head moved since the gate (re-gate required): {msg}")
            self.log(n, "merge", "error", head)
            return self.stop(USAGE, f"#{n} merge failed: {msg}")
        sha = (shell.view(n, self.args.repo).get("mergeCommit") or {}).get("oid")
        self.log(n, "merge", "merged", head, merge_sha=sha)
        _say(f"#{n} merged ({sha or 'sha unknown'})")
        return 0


def _merge_train(args: argparse.Namespace) -> int:
    if not args.dry_run and not args.yes and not sys.stdin.isatty():
        _say("borg pr merge-train: stdin is not a TTY; pass --yes to confirm a non-interactive merge "
             "(workflow agents and nanoprobes must not run this)")
        return USAGE
    train = _Train(args)
    for n in args.prs:
        code = train.one(n)
        if code:
            return code
    _emit(train.report, args)
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="borg pr", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("verb", choices=("gate", "merge-train"))
    parser.add_argument("prs", nargs="+", type=int, metavar="n", help="PR number(s); gate takes exactly one")
    parser.add_argument("--repo", default="", help="owner/name (default: the current checkout's repo)")
    parser.add_argument("--json", action="store_true", help="JSON on stdout (automatic when not a TTY)")
    parser.add_argument("--wait", action="store_true", help="gate: poll until a terminal verdict")
    parser.add_argument("--timeout", type=float, default=1800.0, help="wait ceiling in seconds (default 1800)")
    parser.add_argument("--interval", type=float, default=20.0, help="poll interval in seconds (default 20)")
    parser.add_argument("--method", default="squash", choices=("squash", "merge", "rebase"))
    parser.add_argument("--dry-run", action="store_true", help="merge-train: print the plan, mutate nothing")
    parser.add_argument("--yes", action="store_true", help="merge-train: confirm when stdin is not a TTY")
    return parser


def main(argv: list[str] | None = None) -> int:
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
        return USAGE
    except BrokenPipeError:
        return 0


if __name__ == "__main__":
    sys.exit(main())
