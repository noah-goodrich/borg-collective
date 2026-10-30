"""Grade one recorded Cortex Code run of borg's agents, guard and run logger. Stdlib only.

A run directory is what evals/cortex-agents/live.sh records from two headless Cortex sessions in a throwaway git
repository (the probe):

    meta.json                  probe path, session flags, the installed scout/grunt pins, cortex version, date
    stream-assume.jsonl        stream-json of session 1: no borg guard, the Cortex facts borg's support rests on
    stream-alias.jsonl         stream-json of session 1b: the alias call alone, so its billing is attributable
    stream-guarded.jsonl       stream-json of session 2: the branch's model guard and run logger registered
    payloads/*.json            every PreToolUse(Task), SubagentStart and SubagentStop payload Cortex sent
    histories/<id>.history.jsonl  the parent session and subagent histories Cortex wrote
    branch-state/agents.jsonl  the rows the branch's borg-nanoprobe-log.sh wrote in session 2
    probe-git-log.txt, probe-grunt.txt  what the grunt left in the probe repository

Modes (each prints `CHECK pass|fail|skip <id> <message>` lines; the caller owns PASS/FAIL accounting):

    grade <run>                 the live claims, A1-A4 (sessions 1 and 1b) and G0-G5, L1-L3 (session 2)
    replay <run> <repo>         re-runs <repo>'s guard and logger on the recorded payloads (R1, R2): deterministic
    mutate <run> <kind> <dest>  writes a known-bad copy of <run> that one check must reject (see MUTATIONS)
    sanitize <run> <dest>       copies <run> with paths, home and ids replaced and free text trimmed, for recorded/

Exit: 0 clean, 1 a check failed, 2 usage, 3 the premise is broken (the session did not make the scripted calls, or
an input is missing), so a model that skipped a step reads as "not measured", never as a pass.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

STEPS_ASSUME = ("A4-name", "A2-fullid")
# A1 runs alone: Cortex records no model on an alias request's history, so which model served it is read from the
# session's billing (result.modelUsage), which is only attributable when nothing else ran in that session.
STEPS_ALIAS = ("A1-alias",)
STEPS_GUARDED = ("G1-explore", "G2-sfod", "G3-alias", "G4-scout", "G5-grunt")
# What the branch's guard decides for each scripted call when Cortex runs it (exit 0 allow, 2 deny).
EXPECTED_GUARD = {
    "A4-name": 0,
    "A2-fullid": 2,
    "A1-alias": 2,
    "G1-explore": 2,
    "G2-sfod": 2,
    "G3-alias": 2,
    "G4-scout": 0,
    "G5-grunt": 0,
}
GUARD_MARK = "borg agent model guard"
AGENT_ID_RE = re.compile(r"agentId: ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})")
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
# The other ids Cortex writes: model tool-call ids (toolu_bdrk_...) and its server's numeric thread and message ids.
TOOL_ID_RE = re.compile(r"toolu_[A-Za-z0-9_]+")
NUM_ID_RE = re.compile(r'("[A-Za-z_]*(?:_id|Id)": ?")([0-9]{6,})(")')
INVENTED_TOOL, INVENTED_NUM = "toolu_invented_", "100000"
# Words the sanitizer itself writes (/home/user, /work/probe, /work/run, /work/tmp): never a user name to hunt for,
# even when a sandboxed HOME happens to be named after one of them.
_PLACEHOLDER_WORDS = frozenset({"home", "user", "work", "probe", "run", "tmp"})


class Premise(Exception):
    """The run cannot answer the question (a missing input or an unscripted session)."""


def load_jsonl(path: Path) -> list[dict]:
    out = []
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if isinstance(rec, dict):
                out.append(rec)
    return out


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise Premise(f"cannot read {path.name}: {exc}") from exc
    if not isinstance(data, dict):
        raise Premise(f"{path.name} is not a JSON object")
    return data


def result_text(block: dict) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(str(c.get("text", "")) for c in content if isinstance(c, dict))
    return ""


class Session:
    """One headless session's stream: its id and the main-session task calls, keyed by description."""

    def __init__(self, path: Path, steps: tuple[str, ...]):
        events = load_jsonl(path)
        init = next((e for e in events if e.get("type") == "system" and e.get("subtype") == "init"), None)
        if init is None or not init.get("session_id"):
            raise Premise(f"{path.name}: no init event with a session_id")
        self.session_id = str(init["session_id"])
        result = next((e for e in events if e.get("type") == "result"), None)
        usage = (result or {}).get("modelUsage")
        self.billed = sorted(usage) if isinstance(usage, dict) else []
        calls: dict[str, list[dict]] = {}
        results: dict[str, str] = {}
        for e in events:
            if e.get("parent_tool_use_id") is not None:
                continue
            for b in (e.get("message") or {}).get("content") or []:
                if not isinstance(b, dict):
                    continue
                if e.get("type") == "assistant" and b.get("type") == "tool_use" and b.get("name") == "task":
                    inp = b.get("input") if isinstance(b.get("input"), dict) else {}
                    calls.setdefault(str(inp.get("description", "")), []).append({"id": b.get("id"), "input": inp})
                elif e.get("type") == "user" and b.get("type") == "tool_result":
                    results[str(b.get("tool_use_id"))] = result_text(b)
        missing = [s for s in steps if len(calls.get(s, [])) != 1]
        if missing:
            raise Premise(f"{path.name}: the session did not make each scripted call exactly once: {missing}")
        self.calls = {s: calls[s][0] for s in steps}
        self.results = results

    def result(self, step: str) -> str:
        return self.results.get(str(self.calls[step]["id"]), "")

    def agent_id(self, step: str) -> str | None:
        m = AGENT_ID_RE.search(self.result(step))
        return m.group(1) if m else None


class Run:
    def __init__(self, run: Path):
        self.dir = run
        self.meta = load_json(run / "meta.json")
        self.assume = Session(run / "stream-assume.jsonl", STEPS_ASSUME)
        self.alias = Session(run / "stream-alias.jsonl", STEPS_ALIAS)
        self.guarded = Session(run / "stream-guarded.jsonl", STEPS_GUARDED)
        self.payloads = []
        for p in sorted((run / "payloads").glob("*.json")):
            try:
                rec = json.loads(p.read_text(encoding="utf-8"))
            except ValueError:
                continue
            if isinstance(rec, dict):
                self.payloads.append(rec)
        self.rows = {str(r.get("id")): r for r in load_jsonl(run / "branch-state" / "agents.jsonl")}

    def first_model(self, agent_id: str | None) -> tuple[str | None, str | None]:
        """(model, thinking_effort) of the first assistant line that names a model, or (None, None)."""
        if not agent_id:
            return None, None
        for rec in load_jsonl(self.dir / "histories" / f"{agent_id}.history.jsonl"):
            if rec.get("role") == "assistant" and isinstance(rec.get("model"), str):
                eff = rec.get("thinking_effort")
                return rec["model"], eff if isinstance(eff, str) else None
        return None, None

    def events(self, name: str, session: Session) -> list[dict]:
        return [
            p for p in self.payloads if p.get("hook_event_name") == name and p.get("session_id") == session.session_id
        ]

    def start_type(self, agent_id: str | None, session: Session) -> str | None:
        for p in self.events("SubagentStart", session):
            if agent_id and p.get("agent_id") == agent_id:
                return p.get("agent_type")
        return None


class Out:
    def __init__(self):
        self.failed = 0

    def check(self, ok: bool, cid: str, msg: str) -> None:
        print(f"CHECK {'pass' if ok else 'fail'} {cid} {msg}")
        if not ok:
            self.failed += 1

    @staticmethod
    def skip(cid: str, msg: str) -> None:
        print(f"CHECK skip {cid} {msg}")


def grade(run: Run) -> int:
    meta, a, g, out = run.meta, run.assume, run.guarded, Out()
    pin_model, pin_effort = meta.get("scout_pin_model"), meta.get("scout_pin_effort")
    grunt_model = meta.get("grunt_pin_model")
    pa_model, pa_effort = run.first_model(a.session_id)
    pg_model, pg_effort = run.first_model(g.session_id)
    if not (pa_model and pa_effort and pg_model and pg_effort):
        raise Premise("no parent session history with a model and effort (was the run --private?)")
    if pa_effort == pin_effort or pg_effort == pin_effort:
        raise Premise(
            f"session effort {pa_effort}/{pg_effort} equals the scout's pin {pin_effort}: A3/L1 could not "
            "tell inherit from honor; rerun with another --effort"
        )
    if pa_model.startswith("claude-haiku") or not (pin_model and grunt_model):
        raise Premise("the session model must not be a Haiku (A1/A2 tell it apart) and meta must carry the pins")

    # Session 1: the facts the design rests on (no borg guard registered).
    aid = a.agent_id("A4-name")
    model, effort = run.first_model(aid)
    out.check(
        run.start_type(aid, a) == "borg-collective:borg-scout" and model == pin_model,
        "A4",
        f"subagent_type borg-collective:borg-scout resolved to the installed agent and ran its pin {pin_model} "
        f"(got type={run.start_type(aid, a)} model={model})",
    )
    out.check(
        effort == pa_effort and effort != pin_effort,
        "A3",
        f"Cortex ignores the agent's effort: {pin_effort}; the subagent ran the session's {pa_effort} (got {effort})",
    )
    want = a.calls["A2-fullid"]["input"].get("model")
    model, _ = run.first_model(a.agent_id("A2-fullid"))
    out.check(
        bool(want) and model == want,
        "A2",
        f"a per-call full model id is honored: Explore with model {want} ran {model}",
    )
    # A1 reads billing: Cortex writes no model on an alias request's history line, so the alias session ran
    # nothing but this one subagent, and a Haiku in its billing would mean the alias was honored.
    s1b = run.alias
    alias = s1b.calls["A1-alias"]["input"].get("model")
    ran = s1b.agent_id("A1-alias") is not None and run.start_type(s1b.agent_id("A1-alias"), s1b) == "Explore"
    haiku = [m for m in s1b.billed if m.startswith("claude-haiku")]
    out.check(
        alias == "haiku" and ran and bool(s1b.billed) and not haiku,
        "A1",
        f"a per-call alias is ignored: Explore with model {alias} ran, and its session billed {s1b.billed} "
        f"with no Haiku (ran={ran})",
    )

    # Session 2: the branch's guard and run logger, registered the way borg setup registers them.
    denied = {"G1-explore": "is not allowed", "G2-sfod": "pins no model", "G3-alias": "alias, which Cortex ignores"}
    for step, cid in (("G1-explore", "G1"), ("G2-sfod", "G2"), ("G3-alias", "G3")):
        text = g.result(step)
        out.check(
            GUARD_MARK in text and denied[step] in text and g.agent_id(step) is None,
            cid,
            f"{step} was denied by the guard with '{denied[step]}' and no subagent started",
        )
    starts = run.events("SubagentStart", g)
    out.check(len(starts) == 2, "G0", f"only the two allowed calls started a subagent (got {len(starts)})")
    sid = g.agent_id("G4-scout")
    out.check(
        sid is not None and run.start_type(sid, g) == "borg-collective:borg-scout",
        "G4",
        "the namespaced scout with no override was allowed and ran",
    )
    gid = g.agent_id("G5-grunt")
    log = (
        (run.dir / "probe-git-log.txt").read_text(encoding="utf-8") if (run.dir / "probe-git-log.txt").is_file() else ""
    )
    body = (run.dir / "probe-grunt.txt").read_text(encoding="utf-8") if (run.dir / "probe-grunt.txt").is_file() else ""
    out.check(
        gid is not None
        and run.start_type(gid, g) == "borg-collective:borg-grunt"
        and "eval: grunt write" in log
        and body.strip() == "OK",
        "G5",
        "the namespaced grunt was allowed, wrote out/grunt.txt and committed it",
    )

    row = run.rows.get(str(sid), {})
    out.check(
        row.get("model") == pin_model and row.get("effort") == pg_effort and row.get("zero_commit") is None,
        "L1",
        f"the logger recorded the scout's model {pin_model} and the session effort {pg_effort} "
        f"(got model={row.get('model')} effort={row.get('effort')} zero_commit={row.get('zero_commit')})",
    )
    row = run.rows.get(str(gid), {})
    out.check(
        row.get("model") == grunt_model and row.get("zero_commit") is False,
        "L2",
        f"the logger saw the grunt's write and commit: zero_commit false, model {grunt_model} "
        f"(got zero_commit={row.get('zero_commit')} model={row.get('model')})",
    )
    stops = {str(p.get("agent_id")) for p in run.events("SubagentStop", g)}
    out.check(
        stops == set(run.rows) and len(stops) == 2,
        "L3",
        f"one logger row per subagent stop in the guarded session (stops={len(stops)} rows={len(run.rows)})",
    )
    return 1 if out.failed else 0


def _payload_step(run: Run, payload: dict) -> str | None:
    for session in (run.assume, run.alias, run.guarded):
        if payload.get("session_id") != session.session_id:
            continue
        for step, call in session.calls.items():
            if call["id"] == payload.get("tool_use_id"):
                return step
    return None


def _replay_guard(run: Run, bash: str, guard: Path, env: dict) -> tuple[int, list[str]]:
    """R1: (payloads replayed, disagreements) for every recorded Task payload of a scripted call."""
    seen, wrong = 0, []
    for p in run.payloads:
        step = (
            _payload_step(run, p) if p.get("hook_event_name") == "PreToolUse" and p.get("tool_name") == "Task" else None
        )
        if step is None:
            continue
        seen += 1
        rc = subprocess.run(
            [bash, str(guard)], input=json.dumps(p), capture_output=True, text=True, env=env, check=False, timeout=60
        ).returncode
        live = (2 if GUARD_MARK in run.guarded.result(step) else 0) if step in run.guarded.calls else None
        if rc != EXPECTED_GUARD[step] or live not in (None, rc):
            wrong.append(f"{step}: rc {rc}, expected {EXPECTED_GUARD[step]}, live {live}")
    return seen, wrong


def _replay_logger(run: Run, bash: str, logger: Path, env: dict, tmp: Path) -> tuple[int, list[str]]:
    """R2: (stops replayed, disagreements) after running the logger on each recorded stop and its history."""
    mism, n = [], 0
    for p in run.events("SubagentStop", run.guarded):
        aid = str(p.get("agent_id"))
        hist = run.dir / "histories" / f"{aid}.history.jsonl"
        if not hist.is_file():
            mism.append(f"{aid}: no recorded history")
            continue
        shutil.copy(hist, tmp / f"{aid}.history.jsonl")
        payload = dict(p, agent_transcript_path=str(tmp / f"{aid}.json"))
        hook_env = dict(env, XDG_STATE_HOME=str(tmp / "state"), XDG_CONFIG_HOME=str(tmp / "config"))
        subprocess.run(
            [bash, str(logger)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=hook_env,
            check=False,
            timeout=60,
        )
        n += 1
    replayed = {str(r.get("id")): r for r in load_jsonl(tmp / "state" / "borg" / "agents.jsonl")}
    for aid, live in run.rows.items():
        got = replayed.get(aid, {})
        mism.extend(
            f"{aid[:8]} {k}: replay {got.get(k)!r} live {live.get(k)!r}"
            for k in ("agent_type", "model", "effort", "zero_commit")
            if got.get(k) != live.get(k)
        )
    return n, mism


def replay(run: Run, repo: Path) -> int:
    out = Out()
    bash = shutil.which("bash")
    guard = repo / "hooks" / "borg-agent-model-guard.sh"
    logger = repo / "hooks" / "borg-nanoprobe-log.sh"
    if not bash or not guard.is_file():
        raise Premise("bash or hooks/borg-agent-model-guard.sh not found")
    # The guard shells out to python3: put this interpreter's directory first so the hook finds one.
    env = dict(
        os.environ,
        PATH=os.pathsep.join([str(Path(sys.executable).parent), os.environ.get("PATH", "")]),
        CORTEX_PROJECT_DIR="/work/probe",
    )
    env.pop("BORG_AGENT_MODEL_GUARD", None)
    seen, wrong = _replay_guard(run, bash, guard, env)
    out.check(
        seen == len(EXPECTED_GUARD) and not wrong,
        "R1",
        f"the guard decides every recorded Task payload as expected and as it did live ({seen} replayed"
        f"{'; ' + '; '.join(wrong) if wrong else ''})",
    )
    if not shutil.which("jq", path=env["PATH"]) or not logger.is_file():
        out.skip("R2", "jq not found: the run logger cannot be replayed here")
        return 1 if out.failed else 0
    tmp = Path(tempfile.mkdtemp(prefix="cortex-agents-replay."))
    try:
        n, mism = _replay_logger(run, bash, logger, env, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    out.check(
        n == len(run.rows) and n > 0 and not mism,
        "R2",
        f"the logger, replayed on the recorded stops and histories, writes the rows it wrote live "
        f"({n} replayed{'; ' + '; '.join(mism) if mism else ''})",
    )
    return 1 if out.failed else 0


def _rewrite_jsonl(path: Path, fn) -> None:
    path.write_text("".join(json.dumps(fn(rec)) + "\n" for rec in load_jsonl(path)), encoding="utf-8")


def _set_first_assistant(path: Path, key: str, value: str) -> None:
    done = [False]

    def fn(rec):
        if not done[0] and rec.get("role") == "assistant" and isinstance(rec.get("model"), str):
            done[0] = True
            return dict(rec, **{key: value})
        return rec

    _rewrite_jsonl(path, fn)


def _bad_alias_honored(run: Run, dest: Path) -> None:
    """A1: Cortex started honoring aliases (the guard's full-id rule would be needless)."""

    def bill_haiku(rec):
        if rec.get("type") == "result" and isinstance(rec.get("modelUsage"), dict):
            rec["modelUsage"] = {"claude-haiku-5-5": {"outputTokens": 1}}
        return rec

    _rewrite_jsonl(dest / "stream-alias.jsonl", bill_haiku)


def _bad_effort_honored(run: Run, dest: Path) -> None:
    """A3: Cortex started honoring the agent's effort pin."""
    path = dest / "histories" / f"{run.assume.agent_id('A4-name')}.history.jsonl"
    _set_first_assistant(path, "thinking_effort", str(run.meta.get("scout_pin_effort")))


def _bad_name_unresolved(run: Run, dest: Path) -> None:
    """A4: the namespaced name resolved to some other agent."""
    aid = run.assume.agent_id("A4-name")
    for p in sorted((dest / "payloads").glob("*.json")):
        rec = json.loads(p.read_text(encoding="utf-8"))
        if rec.get("agent_id") == aid:
            p.write_text(json.dumps(dict(rec, agent_type="borg-scout")), encoding="utf-8")


def _bad_guard_silent(run: Run, dest: Path) -> None:
    """G1: the guard let Explore through."""
    tid = run.guarded.calls["G1-explore"]["id"]

    def fn(rec):
        for b in (rec.get("message") or {}).get("content") or []:
            if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("tool_use_id") == tid:
                b["content"] = "ok\n\nagentId: 00000000-0000-4000-8000-00000000ffff"
        return rec

    _rewrite_jsonl(dest / "stream-guarded.jsonl", fn)


def _bad_logger_row(field_values: dict, step: str):
    """L1 / L2: the logger regressed to the pre-fix behavior on the row of `step`'s subagent."""

    def apply(run: Run, dest: Path) -> None:
        aid = run.guarded.agent_id(step)
        _rewrite_jsonl(
            dest / "branch-state" / "agents.jsonl",
            lambda rec: dict(rec, **field_values) if rec.get("id") == aid else rec,
        )

    return apply


# kind -> (the check that must reject it, the function that writes it)
_BAD = {
    "alias-honored": ("A1", _bad_alias_honored),
    "effort-honored": ("A3", _bad_effort_honored),
    "name-unresolved": ("A4", _bad_name_unresolved),
    "guard-silent": ("G1", _bad_guard_silent),
    "logger-null": ("L1", _bad_logger_row({"model": None, "effort": None}, "G4-scout")),
    "logger-zero": ("L2", _bad_logger_row({"zero_commit": True}, "G5-grunt")),
}
MUTATIONS = {kind: target for kind, (target, _) in _BAD.items()}


def mutate(run_dir: Path, kind: str, dest: Path) -> None:
    """Known-bad copies: what the run would look like if a fact or a fix were false. Each names the check it breaks."""
    if kind not in _BAD:
        raise SystemExit(f"unknown mutation: {kind}")
    shutil.rmtree(dest, ignore_errors=True)
    shutil.copytree(run_dir, dest)
    _BAD[kind][1](Run(dest), dest)


def _trim_history(rec: dict) -> dict:
    """A history line keeps what the checks read: role, model, effort and the tool calls and results. A user line's
    text blocks (Cortex injects its system reminders there, with the account and user name) are dropped."""
    blocks = []
    for b in rec.get("content") or []:
        if not isinstance(b, dict) or b.get("type") == "thinking":
            continue
        if b.get("type") == "text":
            if rec.get("role") == "user":
                continue
            b = dict(b, text=str(b.get("text", ""))[:400])
        elif b.get("type") == "tool_result" and isinstance(b.get("tool_result"), dict):
            tr = dict(b["tool_result"])
            tr.pop("metrics", None)
            if isinstance(tr.get("content"), list):
                tr["content"] = [
                    dict(c, text=str(c.get("text", ""))[:300]) for c in tr["content"] if isinstance(c, dict)
                ]
            b = dict(b, tool_result=tr)
        blocks.append(b)
    return dict(rec, content=blocks)


def _trim_stream(rec: dict) -> dict | None:
    kind = rec.get("type")
    if kind == "system" and rec.get("subtype") == "init":
        return {k: rec.get(k) for k in ("type", "subtype", "session_id", "cwd", "model", "permissionMode")}
    if kind == "result":
        return {k: rec.get(k) for k in ("type", "subtype", "is_error", "num_turns", "result", "modelUsage")}
    if kind not in ("assistant", "user"):
        return None
    msg = rec.get("message") or {}
    blocks = []
    for b in msg.get("content") or []:
        if not isinstance(b, dict) or b.get("type") == "thinking":
            continue
        if b.get("type") == "text":
            if kind == "user":
                continue
            b = dict(b, text=str(b.get("text", ""))[:400])
        elif b.get("type") == "tool_result":
            b = dict(b, content=result_text(b)[:1500])
        blocks.append(b)
    if not blocks:
        return None
    return {
        "type": kind,
        "parent_tool_use_id": rec.get("parent_tool_use_id"),
        "session_id": rec.get("session_id"),
        "message": {"role": msg.get("role"), "content": blocks},
    }


# Applied to each file's RAW text before anything is trimmed, so a truncation can never cut a path in half and slip
# past the replacement. Temp directories (both macOS spellings) become the probe; any home becomes /home/user.
_TEMP_PROBE_RE = re.compile(r"(?:/private)?/var/folders/[^/\s\"']+/[^/\s\"']+/T/borg-cortex-eval\.[A-Za-z0-9]+")
_TEMP_ANY_RE = re.compile(r"(?:/private)?/var/folders/[^\s\"']+")
_HOME_RE = re.compile(r"/Users/[^/\s\"']+")


def _leaks(text: str) -> list[str]:
    """Identity and path patterns that must not survive into recorded/ (the sanitize step refuses to write)."""
    found = [
        pat for pat in (r"/Users/", r"/var/folders", r"/private/", r"snowflakecomputing\.com") if re.search(pat, text)
    ]
    found.extend(
        f"user name {word!r}"
        for word in {os.environ.get("USER", ""), Path.home().name} - _PLACEHOLDER_WORDS
        if len(word) >= 3 and re.search(r"(?i)\b" + re.escape(word) + r"\b", text)
    )
    if any(not u.startswith("00000000-0000-4000-8000-") for u in UUID_RE.findall(text)):
        found.append("an id that was not replaced")
    if any(not t.startswith(INVENTED_TOOL) for t in TOOL_ID_RE.findall(text)):
        found.append("a tool-call id that was not replaced")
    if any(not m.group(2).startswith(INVENTED_NUM) for m in NUM_ID_RE.finditer(text)):
        found.append("a numeric thread or message id that was not replaced")
    return found


def _redactor(run_dir: Path, meta: dict):
    """A function that replaces the probe, run and home paths (literal first, then by pattern) in raw text."""
    probe = str(meta.get("probe", ""))
    pairs = {probe: "/work/probe", str(run_dir): "/work/run", str(Path.home()): "/home/user"}
    if probe.startswith("/private/"):
        pairs[probe[len("/private") :]] = "/work/probe"
    literals = sorted(((k, v) for k, v in pairs.items() if k), key=lambda kv: -len(kv[0]))

    def redact(text: str) -> str:
        for old, new in literals:
            text = text.replace(old, new)
        text = _TEMP_PROBE_RE.sub("/work/probe", text)
        text = _TEMP_ANY_RE.sub("/work/tmp", text)
        return _HOME_RE.sub("/home/user", text)

    return redact


def _redacted_jsonl(path: Path, redact) -> list[dict]:
    out = []
    for line in redact(path.read_text(encoding="utf-8", errors="replace")).splitlines():
        if line.strip().startswith("{"):
            try:
                out.append(json.loads(line))
            except ValueError:
                continue
    return out


def _write_stage(run_dir: Path, stage: Path, redact) -> None:
    """The trimmed, path-redacted copy of every file the checks read."""
    for sub in ("payloads", "histories", "branch-state"):
        (stage / sub).mkdir(parents=True)
    for name in ("stream-assume.jsonl", "stream-alias.jsonl", "stream-guarded.jsonl"):
        kept = [r for r in (_trim_stream(x) for x in _redacted_jsonl(run_dir / name, redact)) if r is not None]
        (stage / name).write_text("".join(json.dumps(r) + "\n" for r in kept), encoding="utf-8")
    for p in sorted((run_dir / "payloads").glob("*.json")):
        rec = json.loads(redact(p.read_text(encoding="utf-8")))
        rec.pop("last_assistant_message", None)
        if isinstance(rec.get("tool_input"), dict) and isinstance(rec["tool_input"].get("prompt"), str):
            rec["tool_input"]["prompt"] = rec["tool_input"]["prompt"][:300]
        (stage / "payloads" / p.name).write_text(json.dumps(rec, indent=1) + "\n", encoding="utf-8")
    for h in sorted((run_dir / "histories").glob("*.history.jsonl")):
        lines = (json.dumps(_trim_history(r)) + "\n" for r in _redacted_jsonl(h, redact))
        (stage / "histories" / h.name).write_text("".join(lines), encoding="utf-8")
    for rel in ("branch-state/agents.jsonl", "probe-git-log.txt", "probe-grunt.txt", "meta.json"):
        if (run_dir / rel).is_file():
            (stage / rel).write_text(redact((run_dir / rel).read_text(encoding="utf-8")), encoding="utf-8")


def _id_maps(blobs: list[str]) -> tuple[dict, dict, dict]:
    """Real id -> invented id for the three shapes, numbered in first-seen order over `blobs`, so a re-sanitize of the
    same run is byte-identical and a real id maps to the same invented one in every file (the checks join on them)."""
    uuids: dict[str, str] = {}
    tools: dict[str, str] = {}
    nums: dict[str, str] = {}
    for blob in blobs:
        for u in UUID_RE.findall(blob):
            uuids.setdefault(u, f"00000000-0000-4000-8000-{len(uuids) + 1:012d}")
        for t in TOOL_ID_RE.findall(blob):
            if not t.startswith(INVENTED_TOOL):
                tools.setdefault(t, f"{INVENTED_TOOL}{len(tools) + 1:04d}")
        for m in NUM_ID_RE.finditer(blob):
            nums.setdefault(m.group(2), f"{INVENTED_NUM}{len(nums) + 1:05d}")
    return uuids, tools, nums


def _replace_ids(stage: Path) -> list[str]:
    """Every id becomes an invented one, in file contents and names. Returns the leaks that survived."""
    files = sorted(f for f in stage.rglob("*") if f.is_file())
    texts = {f: f.read_text(encoding="utf-8") for f in files}
    uuids, tools, nums = _id_maps([f.name + "\n" + texts[f] for f in files])

    def rewrite(text: str) -> str:
        text = UUID_RE.sub(lambda m: uuids[m.group(0)], text)
        text = TOOL_ID_RE.sub(lambda m: tools.get(m.group(0), m.group(0)), text)
        return NUM_ID_RE.sub(lambda m: m.group(1) + nums[m.group(2)] + m.group(3), text)

    leaks = []
    for f in files:
        text = rewrite(texts[f])
        f.unlink()
        target = f.with_name(rewrite(f.name))
        target.write_text(text, encoding="utf-8")
        leaks.extend(f"{target.relative_to(stage)}: {x}" for x in _leaks(text))
    return leaks


def sanitize(run_dir: Path, dest: Path) -> None:
    """recorded/: every path and home replaced, free text trimmed, then every id replaced by an invented one."""
    redact = _redactor(run_dir, load_json(run_dir / "meta.json"))
    tmp = Path(tempfile.mkdtemp(prefix="cortex-agents-sanitize."))
    try:
        stage = tmp / "run"
        _write_stage(run_dir, stage, redact)
        leaks = _replace_ids(stage)
        if leaks:
            raise Premise("sanitize refused, these would have been recorded: " + "; ".join(sorted(set(leaks))[:10]))
        shutil.rmtree(dest, ignore_errors=True)
        shutil.copytree(stage, dest)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[0] not in ("grade", "replay", "mutate", "sanitize"):
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        print(
            "usage: check.py grade <run> | replay <run> <repo> | mutate <run> <kind> <dest> | sanitize <run> <dest>",
            file=sys.stderr,
        )
        return 2
    try:
        if argv[0] == "grade":
            return grade(Run(Path(argv[1])))
        if argv[0] == "replay" and len(argv) == 3:
            return replay(Run(Path(argv[1])), Path(argv[2]))
        if argv[0] == "mutate" and len(argv) == 4:
            mutate(Path(argv[1]), argv[2], Path(argv[3]))
            return 0
        if argv[0] == "sanitize" and len(argv) == 3:
            sanitize(Path(argv[1]), Path(argv[2]))
            return 0
    except Premise as exc:
        print(f"PREMISE {exc}")
        return 3
    print("usage: wrong number of arguments", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
