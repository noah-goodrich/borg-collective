#!/usr/bin/env python3
"""Reduce, grade, mutate and sanitize the agent-gates recordings (stdlib only; the pattern is
evals/cortex-agents/check.py).

A live run produces a raw `claude -p --output-format stream-json` stream plus sandbox facts. This script turns them
into a RECORDING (a sanitized, content-stripped stream and a facts file), REDUCES a recording to a small trace
(ordered tool calls, the final message, the result object, sandbox facts), and grades only that trace. The offline
harness (run.sh) grades the committed recordings, replays known-bad mutations of them, and proves the sanitizer
refuses a leak. This repository is public, so nothing but a whitelisted subset of the stream is ever written.

Subcommands (`CHECK pass|fail|skip <id> <message>` lines on stdout; exit 0 all pass/skip, 1 any fail, 3 a broken
premise):
  setup <case> <root> <repo>       build the sandbox for a case under <root>
  record <case> <raw> <root> <out>    sanitize a raw stream and the sandbox facts into a recording (refuses on a leak)
  grade <dir>                      grade every recording under <dir> (a recording, or a directory of them)
  env <repo> [<plugin-dir>]        the Tier 1 environment proof
  mutate <dir> <kind> <out>        copy <dir> and make one fact false
  sanitize <dir> <out>             re-sanitize a recording directory (refuses if anything real survives)
  mutations                        print `kind target expected` for every known-bad mutation
"""

from __future__ import annotations

import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cases  # noqa: E402  (a sibling module; the path insert above makes it importable from anywhere)

HERE = Path(__file__).resolve().parent
SANDBOX = "<sandbox>"
WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")
HANDBACK = "SubagentHandback"
REFUSAL_RE = re.compile(r"^SCOPE-EXCEEDED: brief names ")
COUNT_RE = re.compile(r"^SCOPE-EXCEEDED: brief names \[?([0-9]+) deliverables")
VERDICTS = ("PASS", "PASS_WITH_NITS", "FAIL")
JSON_KEYS = ("verdict", "ac_results", "tests", "scope_violations", "findings", "summary")
MUTATING_BASH = re.compile(
    r"(^|[;&|\s])(rm|mv|cp|mkdir|touch|tee|dd|chmod|ln|truncate)\b|>|sed\s+-i"
    r"|git\s+(add|commit|checkout|switch|branch\s+[^-\s]|worktree|reset|push|merge|rebase|stash|cherry-pick|tag)"
)

# ---- sanitizer: refuse to write anything a public repository must not hold ----
LEAKS = (
    ("an account email", re.compile(r"[A-Za-z0-9._+-]+@gmail\.com", re.I)),
    ("a home path", re.compile(r"/Users/|/home/[a-z]|/private/(var|tmp)|/var/folders|claude-501")),
    ("a user name", re.compile(r"noah|goodrich", re.I)),
    ("a session or message id", re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")),
    ("a tool or message id", re.compile(r"toolu_|msg_[0-9A-Za-z]{10}|req_[0-9A-Za-z]{10}")),
    ("a credential", re.compile(r"sk-ant-|ghp_|github_pat_|xox[bp]-")),
    (
        "system prompt or CLAUDE.md text",
        re.compile(
            r"system-reminder|userEmail|claudeMd|Contents of /|"
            r"auto-memory|MEMORY\.md|borg-managed",
            re.I,
        ),
    ),
)


class Refused(Exception):
    """The sanitizer found something real in what it was asked to write."""


def sanitize_text(text: str, root: str | None) -> str:
    """Normalize the sandbox path, then refuse if anything real survives."""
    if root:
        text = text.replace(root, SANDBOX)
        real = os.path.realpath(root)
        if real != root:
            text = text.replace(real, SANDBOX)
    for what, rx in LEAKS:
        m = rx.search(text)
        if m:
            raise Refused("sanitize refused: %s survives (%r)" % (what, m.group(0)))
    return text


def _keep_block(block: dict) -> dict | None:
    kind = block.get("type")
    if kind == "text":
        return {"type": "text", "text": block.get("text", "")}
    if kind == "tool_use":
        return {"type": "tool_use", "name": block.get("name"), "input": block.get("input", {})}
    if kind == "tool_result":
        return {"type": "tool_result", "is_error": bool(block.get("is_error"))}
    return None  # thinking (signed, private), images and everything else are dropped


def reduce_stream_events(raw_lines: list[str]) -> list[dict]:
    """Whitelist a raw stream: assistant and user content blocks and the result object, nothing else.

    Dropped: init (system prompt, user plugins, paths, session id), hook events, rate-limit events, thinking, every id,
    usage and timestamp, and the CONTENT of tool results (kept: whether the call errored).
    """
    out: list[dict] = []
    for line in raw_lines:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        kind = ev.get("type")
        if kind in ("assistant", "user"):
            msg = ev.get("message") or {}
            content = msg.get("content")
            blocks = (
                [b for b in (_keep_block(b) for b in content if isinstance(b, dict)) if b]
                if isinstance(content, list)
                else []
            )
            if not blocks:
                continue
            keep = {"type": kind, "parent_tool_use_id": None, "message": {"role": kind, "content": blocks}}
            if kind == "assistant" and msg.get("model"):
                keep["message"]["model"] = msg["model"]
            out.append(keep)
        elif kind == "result":
            usage = ev.get("modelUsage") or {}
            out.append(
                {
                    "type": "result",
                    "subtype": ev.get("subtype"),
                    "is_error": bool(ev.get("is_error")),
                    "num_turns": ev.get("num_turns"),
                    "total_cost_usd": ev.get("total_cost_usd"),
                    "result": ev.get("result") if isinstance(ev.get("result"), str) else "",
                    "modelUsage": {m: {"costUSD": (u or {}).get("costUSD")} for m, u in usage.items()},
                    "permission_denials": len(ev.get("permission_denials") or []),
                }
            )
    return out


def write_recording(out: Path, meta: dict, events: list[dict], facts: dict | None, root: str | None) -> None:
    """Serialize a recording, sanitized as ONE string first so a refusal leaves nothing on disk."""
    stream = "".join(json.dumps(ev, ensure_ascii=False) + "\n" for ev in events)
    parts = {"stream.jsonl": stream, "meta.json": json.dumps(meta, indent=2) + "\n"}
    if facts is not None:
        parts["facts.json"] = json.dumps(facts, indent=2, sort_keys=True) + "\n"
    clean = {name: sanitize_text(text, root) for name, text in parts.items()}
    out.mkdir(parents=True, exist_ok=True)
    for name, text in clean.items():
        (out / name).write_text(text, encoding="utf-8")


# ---- the reducer: a recording becomes a trace, and graders read only the trace ----
def load_recording(d: Path) -> tuple[dict, list[dict], dict]:
    meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
    events = [json.loads(ln) for ln in (d / "stream.jsonl").read_text(encoding="utf-8").splitlines() if ln.strip()]
    facts = json.loads((d / "facts.json").read_text(encoding="utf-8")) if (d / "facts.json").is_file() else {}
    return meta, events, facts


def trace_of(meta: dict, events: list[dict], facts: dict) -> dict:
    calls: list[dict] = []
    last_text = ""
    result: dict = {}
    for ev in events:
        if ev.get("type") == "assistant":
            for b in ev["message"]["content"]:
                if b.get("type") == "tool_use":
                    calls.append({"name": b.get("name"), "input": b.get("input") or {}})
                elif b.get("type") == "text":
                    last_text = b.get("text", "")
        elif ev.get("type") == "result":
            result = ev
    final = result.get("result") or last_text
    if calls and calls[-1]["name"] == HANDBACK and isinstance((calls[-1]["input"] or {}).get("message"), str):
        final = calls[-1]["input"]["message"]  # a real subagent ends on a SubagentHandback call, not a result
    return {
        "case": meta.get("case"),
        "agent": meta.get("agent"),
        "pin": meta.get("pin"),
        "final": final.strip(),
        "calls": calls,
        "models": sorted((result.get("modelUsage") or {}).keys()),
        "result": result,
        "facts": facts,
    }


def mutating_calls(calls: list[dict]) -> list[str]:
    bad = [c["name"] for c in calls if c["name"] in WRITE_TOOLS]
    for c in calls:
        if c["name"] == "Bash" and MUTATING_BASH.search(str((c["input"] or {}).get("command", ""))):
            bad.append("Bash:" + str(c["input"].get("command", ""))[:60])
    return bad


# ---- graders: one function per case kind, each returns a list of (verdict, id, message) ----
def _result(verdict: str, cid: str, msg: str) -> tuple[str, str, str]:
    return (verdict, cid, msg)


def _all_skip(cid: str, ids: tuple[str, ...], why: str) -> list[tuple[str, str, str]]:
    return [_result("skip", "%s.%s" % (cid, i), why) for i in ids]


def grade_refuse(t: dict, optional: bool) -> list[tuple[str, str, str]]:
    cid, final, facts = t["case"], t["final"], t["facts"]
    out = [
        _result(
            "pass" if REFUSAL_RE.search(final) else "fail",
            cid + ".prefix",
            "final message starts `SCOPE-EXCEEDED: brief names `"
            if REFUSAL_RE.search(final)
            else "final message does not start with the refusal prefix: %r" % final[:80],
        )
    ]
    if optional:
        first = final.split("Split into", 1)[0].lower()
        ok = bool(REFUSAL_RE.search(final)) and ("optional" in first or "bonus" in first)
        out.append(
            _result(
                "pass" if ok else "fail",
                cid + ".count",
                "the refusal names the optional step" if ok else "the refusal does not name an optional step",
            )
        )
    else:
        m = COUNT_RE.search(final)
        n = int(m.group(1)) if m else 0
        out.append(
            _result(
                "pass" if n >= 3 else "fail",
                cid + ".count",
                "refusal counts %d deliverables (>= 3)" % n if n >= 3 else "refusal counts %d deliverables" % n,
            )
        )
    bad = mutating_calls(t["calls"])
    out.append(
        _result(
            "fail" if bad else "pass",
            cid + ".no-write",
            "mutating calls before refusing: %s" % bad[:3] if bad else "no Write/Edit/mutating Bash call",
        )
    )
    same = facts.get("git_log_before") == facts.get("git_log_after") and facts.get("files_before") == facts.get(
        "files_after"
    )
    out.append(
        _result(
            "pass" if same else "fail",
            cid + ".log-unchanged",
            "sandbox git log and files unchanged" if same else "the sandbox changed",
        )
    )
    return out


def grade_accept(t: dict) -> list[tuple[str, str, str]]:
    cid, final, facts = t["case"], t["final"], t["facts"]
    refused = "SCOPE-EXCEEDED" in final
    out = [
        _result(
            "fail" if refused or not final else "pass",
            cid + ".no-refusal",
            "the final message refuses a two-deliverable brief"
            if refused
            else "an empty final message"
            if not final
            else "no refusal in the final message",
        )
    ]
    expected = facts.get("expected_files") or {}
    after = facts.get("files_after") or {}
    wrong = [f for f, want in expected.items() if (after.get(f) or "").strip() != want]
    out.append(
        _result(
            "pass" if expected and not wrong else "fail",
            cid + ".files",
            "both files exist with the expected content"
            if expected and not wrong
            else "missing or wrong content: %s" % (wrong or "no expectation recorded"),
        )
    )
    made = len(facts.get("git_log_after") or []) > len(facts.get("git_log_before") or [])
    out.append(
        _result(
            "pass" if made else "fail", cid + ".commit", "a commit exists" if made else "no new commit in the sandbox"
        )
    )
    return out


def grade_verify(t: dict) -> list[tuple[str, str, str]]:
    cid, final, facts = t["case"], t["final"], t["facts"]
    out: list[tuple[str, str, str]] = []
    try:
        v = json.loads(final)
        ok = (
            isinstance(v, dict)
            and all(k in v for k in JSON_KEYS)
            and v.get("verdict") in VERDICTS
            and isinstance(v.get("tests"), dict)
            and isinstance(v.get("ac_results"), list)
        )
    except ValueError:
        v, ok = {}, False
    out.append(
        _result(
            "pass" if ok else "fail",
            cid + ".json",
            "the final message is exactly one JSON verdict object"
            if ok
            else "the final message is not one bare JSON object with the required keys: %r" % final[:60],
        )
    )
    if not ok:
        return out + _all_skip(cid, ("verdict", "tests", "nonce", "read-only"), "no parseable verdict")
    verdict, tests = v["verdict"], v["tests"]
    acs = [a for a in v["ac_results"] if isinstance(a, dict)]
    wants_fail = cid in ("V1", "V2")
    good = verdict == "FAIL" if wants_fail else verdict in ("PASS", "PASS_WITH_NITS")
    if cid == "V4":
        good = verdict != "FAIL"
    if cid == "V3":
        findings = [f for f in v["findings"] if isinstance(f, dict)]
        good = good and not any(f.get("severity") == "error" for f in findings) and not v["scope_violations"]
    out.append(
        _result(
            "pass" if good else "fail",
            cid + ".verdict",
            "verdict %s as the case requires" % verdict if good else "verdict %s is wrong for %s" % (verdict, cid),
        )
    )
    if cid == "V1":
        token = facts.get("ac_token") or ""
        hit = [a for a in acs if a.get("status") == "unmet" and token in str(a.get("criterion", "")).lower()]
        out.append(
            _result(
                "pass" if hit and tests.get("ran") is True else "fail",
                cid + ".ac",
                "an unmet entry names the missing criterion and tests.ran is true"
                if hit
                else "no unmet ac_results entry for the missing criterion",
            )
        )
    if cid == "V2":
        ok2 = tests.get("ran") is True and tests.get("green") is False
        out.append(
            _result(
                "pass" if ok2 else "fail",
                cid + ".tests",
                "tests.ran is true and tests.green is false" if ok2 else "tests block is %s" % tests,
            )
        )
    elif cid == "V4":
        ok4 = tests.get("ran") is False
        out.append(
            _result(
                "pass" if ok4 else "fail",
                cid + ".tests",
                "tests.ran is false: unverifiable, not FAIL" if ok4 else "tests block is %s" % tests,
            )
        )
    elif cid == "V3":
        ok3 = tests.get("ran") is True and tests.get("green") is True
        out.append(
            _result(
                "pass" if ok3 else "fail",
                cid + ".tests",
                "tests ran and are green" if ok3 else "tests block is %s" % tests,
            )
        )
    seen = facts.get("nonce_seen")
    if cid == "V4":
        out.append(
            _result(
                "pass" if seen is None else "fail",
                cid + ".nonce",
                "the verification command was not run" if seen is None else "tests.ran is false but verify.sh ran",
            )
        )
    else:
        match = seen is not None and seen == facts.get("token")
        out.append(
            _result(
                "pass" if match else "fail",
                cid + ".nonce",
                "verify.sh ran in this run (the nonce is on disk)"
                if match
                else "no nonce: the verdict was reached without re-running the command",
            )
        )
    bad = mutating_calls(t["calls"])
    clean = facts.get("status_clean") is True
    out.append(
        _result(
            "pass" if not bad and clean else "fail",
            cid + ".read-only",
            "no edit calls and the sandbox is clean"
            if not bad and clean
            else "edited: calls=%s clean=%s" % (bad[:3], clean),
        )
    )
    return out


def grade_production(t: dict) -> list[tuple[str, str, str]]:
    final = t["final"]
    m = COUNT_RE.search(final)
    return [
        _result(
            "pass" if REFUSAL_RE.search(final) else "fail",
            "PROD.prefix",
            "the real SubagentHandback message starts with the refusal prefix"
            if REFUSAL_RE.search(final)
            else "the real handback does not start with the refusal prefix: %r" % final[:60],
        ),
        _result(
            "pass" if m and int(m.group(1)) >= 3 else "fail",
            "PROD.count",
            "the real refusal counted %s deliverables" % (m.group(1) if m else "?"),
        ),
    ]


def grade_dir(d: Path) -> list[tuple[str, str, str]]:
    meta, events, facts = load_recording(d)
    t = trace_of(meta, events, facts)
    cid, kind = meta.get("case"), meta.get("kind")
    if kind == "production":
        return grade_production(t)
    pin = meta.get("pin")
    ids = {
        "refuse": ("prefix", "count", "no-write", "log-unchanged"),
        "refuse-optional": ("prefix", "count", "no-write", "log-unchanged"),
        "accept": ("no-refusal", "files", "commit"),
        "verify": ("json", "verdict", "tests", "nonce", "read-only"),
    }.get(kind)
    if ids is None:
        return [_result("fail", str(cid) + ".meta", "unknown case kind %r" % kind)]
    # THE PREMISE: live.sh makes the session default a DIFFERENT model (haiku, through --settings), so a vanilla
    # Claude that never loaded the agent shows no usage of the agent's own pin. Without that, a machine whose default
    # model equals the pin would let an unloaded agent pass the accept case.
    if pin not in t["models"]:
        return _all_skip(cid, ids, "agent not loaded: modelUsage %s lacks the pin %s" % (t["models"], pin)) + [
            _result("skip", cid + ".premise", "modelUsage %s lacks the pin %s" % (t["models"], pin))
        ]
    res = [_result("pass", cid + ".premise", "modelUsage carries the agent's own pin %s" % pin)]
    if kind in ("refuse", "refuse-optional"):
        return res + grade_refuse(t, kind == "refuse-optional")
    if kind == "accept":
        return res + grade_accept(t)
    return res + grade_verify(t)


def recordings_under(d: Path) -> list[Path]:
    if (d / "meta.json").is_file():
        return [d]
    return sorted(p.parent for p in d.glob("*/meta.json"))


def cmd_grade(d: Path) -> int:
    dirs = recordings_under(d)
    if not dirs:
        print("PREMISE no recording under %s" % d)
        return 3
    fails = 0
    for rec in dirs:
        for verdict, cid, msg in grade_dir(rec):
            print("CHECK %s %s %s" % (verdict, cid, msg))
            fails += verdict == "fail"
    return 1 if fails else 0


# ---- the Tier 1 environment proof ----
def _pin(repo: Path, agent: str) -> str | None:
    text = (repo / "agents" / (agent + ".md")).read_text(encoding="utf-8")
    m = re.search(r"^model:\s*(\S+)\s*$", text.split("---")[1], re.M)
    return m.group(1) if m else None


def _guard(repo: Path, command: str) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        os.symlink(sys.executable, os.path.join(tmp, "python3"))
        env = {"PATH": tmp + ":/usr/bin:/bin"}
        payload = json.dumps(
            {"agent_type": "borg-collective:borg-verifier", "tool_name": "Bash", "tool_input": {"command": command}}
        )
        done = subprocess.run(
            ["/bin/bash", str(repo / "hooks" / "borg-verifier-guard.sh")],
            input=payload,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )
    return done.returncode


def _run_verify(repo: Path, case: str) -> tuple[int, str | None, str]:
    with tempfile.TemporaryDirectory() as tmp:
        rec = cases.setup(case, Path(tmp) / "box", repo)
        os.symlink(sys.executable, os.path.join(tmp, "python3"))
        env = {"PATH": tmp + ":/usr/bin:/bin", "PYTHONDONTWRITEBYTECODE": "1"}
        done = subprocess.run(["/bin/bash", "verify.sh"], cwd=rec["repo"], env=env, capture_output=True, check=False)
        nonce = Path(rec["nonce_file"])
        return done.returncode, nonce.read_text(encoding="utf-8").strip() if nonce.is_file() else None, rec["token"]


def cmd_env(repo: Path, plugin: Path | None) -> int:
    out: list[tuple[str, str, str]] = []
    for agent in ("borg-nanoprobe", "borg-verifier"):
        pin = _pin(repo, agent)
        out.append(_result("pass" if pin else "fail", "ENV.pin-" + agent, "agents/%s.md pins model: %s" % (agent, pin)))
    build = (repo / "scripts" / "build-plugin.sh").read_text(encoding="utf-8")
    ok = 'AGENTS_SRC="$REPO_ROOT/agents"' in build and "borg-verifier-guard.sh" in build
    out.append(
        _result(
            "pass" if ok else "fail",
            "ENV.build-copies-agents",
            "build-plugin.sh copies agents/*.md and registers the verifier guard"
            if ok
            else "build-plugin.sh no longer copies agents/ or the verifier guard",
        )
    )
    for case in ("NP1", "NP2", "NP3", "NP4"):
        with tempfile.TemporaryDirectory() as tmp:
            try:
                rec = cases.setup(case, Path(tmp) / "box", repo)
                ok = (Path(rec["repo"]) / ".git").is_dir() and rec["git_log_before"] == ["init"]
                msg = "the sandbox initializes and the brief names nothing under test"
            except (ValueError, RuntimeError) as exc:
                ok, msg = False, str(exc)
        out.append(_result("pass" if ok else "fail", "ENV.brief-" + case, msg))
    if plugin is not None:
        for agent in ("borg-nanoprobe", "borg-verifier"):
            built = plugin / "agents" / (agent + ".md")
            same = built.is_file() and built.read_text() == (repo / "agents" / (agent + ".md")).read_text()
            out.append(
                _result(
                    "pass" if same else "fail",
                    "ENV.plugin-" + agent,
                    "the plugin build carries agents/%s.md unchanged" % agent
                    if same
                    else "the plugin build lacks or alters agents/%s.md" % agent,
                )
            )
        hooks = (plugin / "hooks" / "hooks.json").read_text(encoding="utf-8")
        out.append(
            _result(
                "pass" if "borg-verifier-guard.sh" in hooks else "fail",
                "ENV.plugin-guard",
                "the built hooks.json registers the verifier guard",
            )
        )
    allow, deny = _guard(repo, cases.VERIFY_CMD), _guard(repo, "git push origin main")
    out.append(
        _result(
            "pass" if allow == 0 else "fail",
            "ENV.guard-allows",
            "the verifier guard allows `%s`" % cases.VERIFY_CMD
            if allow == 0
            else "the verifier guard denies the verification command (rc %s)" % allow,
        )
    )
    out.append(
        _result(
            "pass" if deny == 2 else "fail",
            "ENV.guard-denies",
            "the guard still denies `git push` (it discriminates)"
            if deny == 2
            else "the guard allowed `git push` (rc %s): the allow check proves nothing" % deny,
        )
    )
    for case, want_green in (("V1", True), ("V2", False), ("V3", True)):
        rc, seen, token = _run_verify(repo, case)
        ok = (rc == 0) == want_green and seen == token
        out.append(
            _result(
                "pass" if ok else "fail",
                "ENV.verify-" + case,
                "verify.sh exits %s and leaves its nonce outside the repo" % rc
                if ok
                else "verify.sh exit %s nonce %s (want green=%s)" % (rc, seen is not None, want_green),
            )
        )
    fails = 0
    for verdict, cid, msg in out:
        print("CHECK %s %s %s" % (verdict, cid, msg))
        fails += verdict == "fail"
    return 1 if fails else 0


# ---- known-bad mutations: each makes one fact false in a copy of a recording ----
def _final_event_edit(events: list[dict], fn) -> None:
    """Apply `fn(text) -> text` to the final message wherever the reducer can read it."""
    for ev in events:
        if ev["type"] == "result":
            ev["result"] = fn(ev["result"])
    for ev in reversed(events):
        if ev["type"] == "assistant":
            for b in ev["message"]["content"]:
                if b["type"] == "text":
                    b["text"] = fn(b["text"])
                if b["type"] == "tool_use" and b["name"] == HANDBACK:
                    b["input"]["message"] = fn(b["input"]["message"])
            break


def _splice_call(events: list[dict], name: str, tool_input: dict) -> None:
    block = {"type": "tool_use", "name": name, "input": tool_input}
    ev = {"type": "assistant", "parent_tool_use_id": None, "message": {"role": "assistant", "content": [block]}}
    idx = max(i for i, e in enumerate(events) if e["type"] != "result")
    events.insert(idx, ev)


def _edit_verdict_json(events: list[dict], edit) -> None:
    def fn(text: str) -> str:
        v = json.loads(text)
        edit(v)
        return json.dumps(v)

    _final_event_edit(events, fn)


def _set_status(v: dict, frm: str, to: str) -> None:
    for a in v["ac_results"]:
        if a.get("status") == frm:
            a["status"] = to


MUTATIONS = {
    "np1-prefix-lowercased": ("NP1", "NP1.prefix", "fail"),
    "np1-write-spliced": ("NP1", "NP1.no-write", "fail"),
    "np1-bash-spliced": ("NP1", "NP1.no-write", "fail"),
    "np1-git-log-changed": ("NP1", "NP1.log-unchanged", "fail"),
    "np1-count-two": ("NP1", "NP1.count", "fail"),
    "np2-prefix-stripped": ("NP2", "NP2.prefix", "fail"),
    "np2-optional-dropped": ("NP2", "NP2.count", "fail"),
    "np3-count-two": ("NP3", "NP3.count", "fail"),
    "np4-refusal-added": ("NP4", "NP4.no-refusal", "fail"),
    "np4-files-deleted": ("NP4", "NP4.files", "fail"),
    "np4-no-commit": ("NP4", "NP4.commit", "fail"),
    "np4-agent-not-loaded": ("NP4", "NP4.files", "skip"),
    "v1-verdict-pass": ("V1", "V1.verdict", "fail"),
    "v1-unmet-to-met": ("V1", "V1.ac", "fail"),
    "v1-wrapped-in-prose": ("V1", "V1.json", "fail"),
    "v2-verdict-pass": ("V2", "V2.verdict", "fail"),
    "v2-green-flipped": ("V2", "V2.tests", "fail"),
    "v2-nonce-removed": ("V2", "V2.nonce", "fail"),
    "v3-verdict-fail": ("V3", "V3.verdict", "fail"),
    "v3-edit-spliced": ("V3", "V3.read-only", "fail"),
    "v4-ran-flipped": ("V4", "V4.tests", "fail"),
    "prod-prefix-stripped": ("PROD", "PROD.prefix", "fail"),
}


def mutate(kind: str, meta: dict, events: list[dict], facts: dict) -> None:
    """Make ONE fact false, in place."""
    if kind == "np1-prefix-lowercased":
        _final_event_edit(events, lambda s: s.replace("SCOPE-EXCEEDED:", "Scope exceeded:", 1))
    elif kind in ("np1-write-spliced", "v3-edit-spliced"):
        _splice_call(events, "Write", {"file_path": "%s/repo/a.txt" % SANDBOX, "content": "alpha\n"})
    elif kind == "np1-bash-spliced":
        _splice_call(events, "Bash", {"command": "echo alpha > a.txt && git add a.txt"})
    elif kind == "np1-git-log-changed":
        facts["git_log_after"] = ["wip: a.txt"] + facts["git_log_after"]
    elif kind in ("np1-count-two", "np3-count-two"):
        _final_event_edit(events, lambda s: re.sub(r"[0-9]+ deliverables", "2 deliverables", s, count=1))
    elif kind == "np2-prefix-stripped":
        _final_event_edit(events, lambda s: s.replace("SCOPE-EXCEEDED: ", "", 1))
    elif kind == "np2-optional-dropped":
        _final_event_edit(events, lambda s: re.sub(r"(?i)optional|bonus", "extra", s))
    elif kind == "np4-refusal-added":
        _final_event_edit(events, lambda s: "SCOPE-EXCEEDED: brief names [3 deliverables]. " + s)
    elif kind == "np4-files-deleted":
        for f in facts["expected_files"]:
            facts["files_after"].pop(f, None)
    elif kind == "np4-no-commit":
        facts["git_log_after"] = list(facts["git_log_before"])
    elif kind == "np4-agent-not-loaded":
        for ev in events:
            if ev["type"] == "result":
                ev["modelUsage"] = {"claude-haiku-4-5": {"costUSD": 0}}
    elif kind in ("v1-verdict-pass", "v2-verdict-pass"):
        _edit_verdict_json(events, lambda v: v.update(verdict="PASS"))
    elif kind == "v1-unmet-to-met":
        _edit_verdict_json(events, lambda v: _set_status(v, "unmet", "met"))
    elif kind == "v1-wrapped-in-prose":
        _final_event_edit(events, lambda s: "Here is my verdict:\n```json\n" + s + "\n```")
    elif kind == "v2-green-flipped":
        _edit_verdict_json(events, lambda v: v["tests"].update(green=True))
    elif kind == "v2-nonce-removed":
        facts["nonce_seen"] = None
    elif kind == "v3-verdict-fail":
        _edit_verdict_json(events, lambda v: v.update(verdict="FAIL"))
    elif kind == "v4-ran-flipped":
        _edit_verdict_json(events, lambda v: v["tests"].update(ran=True))
    elif kind == "prod-prefix-stripped":
        _final_event_edit(events, lambda s: s.replace("SCOPE-EXCEEDED: ", "", 1))
    else:
        raise KeyError(kind)


def cmd_mutate(src: Path, kind: str, out: Path) -> int:
    if kind not in MUTATIONS:
        print("unknown mutation %s" % kind, file=sys.stderr)
        return 2
    case = MUTATIONS[kind][0]
    rec = src / case if not (src / "meta.json").is_file() else src
    if not (rec / "meta.json").is_file():
        print("no recording for %s under %s" % (case, src), file=sys.stderr)
        return 2
    meta, events, facts = load_recording(rec)
    events, facts = copy.deepcopy(events), copy.deepcopy(facts)
    mutate(kind, meta, events, facts)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    (out / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    (out / "stream.jsonl").write_text("".join(json.dumps(e) + "\n" for e in events), encoding="utf-8")
    if facts:
        (out / "facts.json").write_text(json.dumps(facts, indent=2), encoding="utf-8")
    return 0


def cmd_sanitize(src: Path, out: Path) -> int:
    """Re-sanitize every recording under <src> into <out>; nothing is written if any of it is refused."""
    staged: list[tuple[Path, str]] = []
    for rec in recordings_under(src):
        for name in ("meta.json", "stream.jsonl", "facts.json"):
            f = rec / name
            if f.is_file():
                try:
                    text = sanitize_text(f.read_text(encoding="utf-8"), None)
                except Refused as exc:
                    print(str(exc), file=sys.stderr)
                    return 3
                staged.append((Path(rec.name) / name if rec != src else Path(name), text))
    for rel, text in staged:
        (out / rel).parent.mkdir(parents=True, exist_ok=True)
        (out / rel).write_text(text, encoding="utf-8")
    return 0


def cmd_record(case: str, raw: Path, root: Path, out: Path) -> int:
    spec = cases.CASES[case]
    record = json.loads((root / "case.json").read_text(encoding="utf-8"))
    facts = cases.collect_facts(root)
    pin = _pin(HERE.parent.parent, spec["agent"])
    meta = {"case": case, "name": spec["name"], "agent": spec["agent"], "kind": spec["kind"], "pin": pin}
    events = reduce_stream_events(raw.read_text(encoding="utf-8", errors="replace").splitlines())
    try:
        write_recording(out, meta, events, facts, str(Path(record["repo"]).parent))
    except Refused as exc:
        print(str(exc), file=sys.stderr)
        return 3
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    repo_default = HERE.parent.parent
    if cmd == "setup":
        cases.setup(args[0], Path(args[1]), Path(args[2]) if len(args) > 2 else repo_default)
        return 0
    if cmd == "record":
        return cmd_record(args[0], Path(args[1]), Path(args[2]), Path(args[3]))
    if cmd == "grade":
        return cmd_grade(Path(args[0]))
    if cmd == "env":
        return cmd_env(Path(args[0]), Path(args[1]) if len(args) > 1 else None)
    if cmd == "mutate":
        return cmd_mutate(Path(args[0]), args[1], Path(args[2]))
    if cmd == "sanitize":
        return cmd_sanitize(Path(args[0]), Path(args[1]))
    if cmd == "mutations":
        for kind, (_, target, expected) in MUTATIONS.items():
            print(kind, target, expected)
        return 0
    print("unknown subcommand: %s" % cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
