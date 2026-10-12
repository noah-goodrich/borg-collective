#!/usr/bin/env python3
"""resume-skeleton.py -- allowlist extractor that turns a real Claude Code record
into a public-repo-safe CAPTURED SKELETON (resume design, slice S0a).

Extractor version: v1  (tests/fixtures/resume/fixtures.json records this per fixture)

Nothing here is a denylist. A value survives only if it is positively recognised:
  - JSON structure (object keys that look like identifiers), booleans, numbers, null;
  - strings under an enum-like key (ENUM_KEYS) whose value is a short token;
  - an exact usage-limit sentence that matches LIMIT_RE;
  - an exact string from CANNED (fixed Claude Code system messages, no user data);
  - identifiers (UUIDs, agent ids, request ids) are NOT kept: they map to fixed fake
    values, stable within one run so parent/child links still line up;
  - ISO timestamps become a fixed increasing fake series;
  - cwd / path keys become fixed fake paths.
Every other string becomes the placeholder "<str>".

Usage:
  resume-skeleton.py jsonl FILE [START:END]   1-based inclusive line range (default all)
  resume-skeleton.py json  FILE
  resume-skeleton.py scrub                    stdin JSON/JSONL -> stdout (for tests)
Run with `python3 -I`.
"""

import json
import re
import sys

VERSION = "v1"

ENUM_KEYS = {
    "type",
    "subtype",
    "error",
    "role",
    "model",
    "defaultModel",
    "stop_reason",
    "level",
    "agentType",
    "userType",
    "entrypoint",
    "version",
    "status",
    "event",
    "hook_event_name",
    "permissionMode",
    "mode",
    "service_tier",
    "workflowName",
    "notification_type",
    "stopReason",
}
ENUM_VALUE_RE = re.compile(r"^[A-Za-z0-9_.:<>-]{1,40}$")

LIMIT_RE = re.compile(
    r"^You've hit your ([A-Za-z]{3,12}( [A-Za-z]{3,12})?) limit \u00b7 resets "
    r"([A-Z][a-z]{2} [0-9]{1,2} at )?[0-9]{1,2}(:[0-9]{2})?[ap]m"
    r"( \([A-Za-z_]+/[A-Za-z_]+\))?$"
)

CANNED = {
    "Prompt is too long",
    "Request timed out",
    "Login expired \u00b7 Please run /login",
    "[Request interrupted by user]",
    "[Request interrupted by user for tool use]",
    "API Error: Your computer went to sleep mid-response. The response above may be incomplete.",
    "API Error: The response stopped arriving. The response above may be incomplete.",
    "API Error: Connection lost mid-response. The response above may be incomplete.",
}

ID_KEYS = {
    "uuid",
    "parentUuid",
    "leafUuid",
    "sessionId",
    "session_id",
    "agentId",
    "requestId",
    "toolUseId",
    "tool_use_id",
    "id",
    "runId",
    "taskId",
    "key",
    "promptId",
    "messageId",
    "sourceToolAssistantUUID",
    "logicalParentUuid",
    "parentToolUseID",
    "toolUseID",
    "agent_id",
    "parent_session_id",
}
TS_KEYS = {"timestamp", "startTime", "endTime", "createdAt", "updatedAt"}
PATH_KEYS = {"cwd", "projectPath", "scriptPath", "transcript_path", "agent_transcript_path"}

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,40}$")
ISO_RE = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")
FAKE_HOME = "/Users/noah/dev/example"


class Faker:
    def __init__(self):
        self.ids = {}
        self.ts = 0

    def ident(self, v):
        if v in self.ids:
            return self.ids[v]
        n = len(self.ids) + 1
        if UUID_RE.match(v):
            out = "00000000-0000-4000-8000-%012d" % n
        elif re.match(r"^a[0-9a-f]{16}$", v):
            out = "a%016d" % n
        elif v.startswith("req_"):
            out = "req_FAKE%06d" % n
        elif v.startswith("toolu_"):
            out = "toolu_FAKE%06d" % n
        elif v.startswith("wf_"):
            out = "wf_fake%03d" % n
        elif v.startswith("v2:"):
            out = "v2:fake%03d" % n
        else:
            out = "<id-%d>" % n
        self.ids[v] = out
        return out

    def stamp(self):
        self.ts += 1
        return "2026-01-01T00:%02d:%02d.000Z" % (self.ts // 60 % 60, self.ts % 60)

    def path(self, key, v):
        if key == "transcript_path" or key == "agent_transcript_path":
            return FAKE_HOME + "/.claude/projects/-Users-noah-dev-example/<sid>.jsonl"
        if key == "scriptPath":
            return FAKE_HOME + "/.claude/workflows/scripts/example.js"
        return FAKE_HOME

    def string(self, key, v):
        if v == "" or v in CANNED or LIMIT_RE.fullmatch(v):
            return v
        if key in ID_KEYS:
            return self.ident(v)
        if key in TS_KEYS and ISO_RE.match(v):
            return self.stamp()
        if key in PATH_KEYS:
            return self.path(key, v)
        if key in ENUM_KEYS and ENUM_VALUE_RE.match(v) and not UUID_RE.match(v):
            return v
        return "<str>"

    def walk(self, node, key=None):
        if isinstance(node, dict):
            out = {}
            for k, v in node.items():
                nk = k if KEY_RE.match(k) else "<key>"
                out[nk] = self.walk(v, k)
            return out
        if isinstance(node, list):
            return [self.walk(v, key) for v in node]
        if isinstance(node, str):
            return self.string(key, node)
        return node


def skeleton_lines(text, rng=None):
    f = Faker()
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if rng:
        a, b = rng
        lines = lines[a - 1 : b]
    return [json.dumps(f.walk(json.loads(ln)), ensure_ascii=False, separators=(",", ":")) for ln in lines]


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "scrub":
        text = sys.stdin.read()
        print("\n".join(skeleton_lines(text)))
        return 0
    path = argv[2]
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if cmd == "jsonl":
        rng = None
        if len(argv) > 3:
            a, b = argv[3].split(":")
            rng = (int(a), int(b))
        print("\n".join(skeleton_lines(text, rng)))
    elif cmd == "json":
        f = Faker()
        print(json.dumps(f.walk(json.loads(text)), ensure_ascii=False, separators=(",", ":")))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
