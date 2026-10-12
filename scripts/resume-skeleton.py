#!/usr/bin/env python3
"""resume-skeleton.py -- allowlist extractor that turns a real Claude Code record
into a public-repo-safe CAPTURED SKELETON (resume design, slice S0a).

Extractor version: v3  (tests/fixtures/resume/fixtures.json records this per fixture)

This is the single rule set for the repo: the capture hook
(scripts/spike-resume-payloads.sh) pipes every payload through `--stdin`.
Nothing here is a denylist. A value or key survives only if it is positively recognised:
  - JSON structure, booleans and null;
  - numbers, only under the keys in NUM_CAPS (clamped to a cap); every other number becomes 0;
  - object keys that are in the fixed KNOWN_KEYS list; every other key is renamed "<key>";
  - strings under a key in ENUM_RULES, only if they are in that key's closed set, or
    fullmatch its strict regex and are not credential-shaped (SUSPICIOUS_RE);
  - the usage-limit sentence, only under a LIMIT_KEYS key and only when it fullmatches
    the closed grammar LIMIT_RE (closed sets for kind, month and timezone; digits for the
    rest), so no free text can ride inside it;
  - an exact string from CANNED (fixed Claude Code system messages, no user data);
  - identifiers (UUIDs, agent ids, request ids) are NOT kept: they map to fixed fake
    values, stable within one run so parent/child links still line up;
  - ISO timestamps become a fixed increasing fake series;
  - cwd / path keys become fixed fake paths.
Every other string becomes the placeholder "<str>" (in arrays too).

Usage:
  resume-skeleton.py jsonl FILE [START:END]   1-based inclusive line range (default all)
  resume-skeleton.py json  FILE
  resume-skeleton.py --stdin                  stdin JSON/JSONL -> stdout, one line per record
  resume-skeleton.py scrub                    alias of --stdin
Run with `python3 -I`.
"""

import json
import re
import sys

VERSION = "v3"


def _s(*vals):
    return frozenset(vals)


# Closed set (frozenset) or strict fullmatch regex per enum-like key.
ENUM_RULES = {
    "error": _s(
        "rate_limit",
        "authentication_failed",
        "billing_error",
        "invalid_request",
        "server_error",
        "max_output_tokens",
        "unknown",
    ),
    "type": _s(
        "assistant",
        "user",
        "system",
        "text",
        "tool_use",
        "tool_result",
        "message",
        "result",
        "thinking",
        "attachment",
        "summary",
        "permission-mode",
        "pr-link",
        "cost-state",
        "last-prompt",
        "queue-operation",
        "file-history-snapshot",
        "custom-title",
        "agent-name",
        "progress",
        "launched",
        "started",
        "failed",
        "atis-latch",
        "mode",
    ),
    "subtype": _s(
        "stop_hook_summary",
        "turn_duration",
        "api_error",
        "informational",
        "local_command",
        "compact_boundary",
        "away_summary",
        "init",
        "success",
    ),
    "role": _s("user", "assistant", "system"),
    "level": _s("info", "suggestion", "warning", "error", "debug"),
    "stop_reason": _s("end_turn", "tool_use", "max_tokens", "stop_sequence", "pause_turn", "refusal"),
    "userType": _s("external", "internal"),
    "entrypoint": _s("cli", "sdk-cli", "sdk-ts", "sdk-py", "mcp", "claude-vscode"),
    "service_tier": _s("standard", "priority", "batch"),
    "status": _s("started", "launched", "running", "completed", "failed", "killed", "cancelled", "pending"),
    "source": _s("startup", "resume", "clear", "compact"),
    "permissionMode": _s("default", "acceptEdits", "bypassPermissions", "plan", "auto", "dontAsk"),
    "agentType": _s("general-purpose", "Explore", "Plan"),
    "hook_event_name": _s(
        "StopFailure",
        "SessionStart",
        "SessionEnd",
        "SubagentStart",
        "SubagentStop",
        "Notification",
        "PreToolUse",
        "PostToolUse",
        "UserPromptSubmit",
        "Stop",
        "PreCompact",
    ),
    "notification_type": _s(
        "idle_prompt",
        "permission_prompt",
        "auth_success",
        "elicitation_dialog",
        "quota_auto_resume_scheduled",
        "quota_auto_resume_started",
        "quota_auto_resume_succeeded",
        "quota_auto_resume_failed",
        "quota_auto_resume_cancelled",
    ),
    "model": re.compile(
        r"claude-(opus|sonnet|haiku|fable)-[0-9]{1,2}(-[0-9]{1,2})?(-[0-9]{8})?(\[1m\])?"
        r"|claude-3(-[57])?-(opus|sonnet|haiku)(-[0-9]{8})?"
        r"|(opus|sonnet|haiku|fable)(\[1m\])?|<synthetic>"
    ),
    "version": re.compile(r"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,4}"),
}
ENUM_RULES["stopReason"] = ENUM_RULES["stop_reason"]
ENUM_RULES["defaultModel"] = ENUM_RULES["model"]
ENUM_RULES["event"] = ENUM_RULES["hook_event_name"]
ENUM_RULES["mode"] = ENUM_RULES["permissionMode"]
ENUM_RULES["permission_mode"] = ENUM_RULES["permissionMode"]

# Credential-shaped text is rejected in values and keys, whatever the key.
SUSPICIOUS_RE = re.compile(
    r"sk[-_]|ghp_|gho_|ghs_|ghu_|github_pat|AKIA|ASIA|xox[a-z]-|eyJ|AIza|Bearer|Basic |"
    r"://|@|_live_|_test_|pk_|[0-9a-fA-F]{16,}|[A-Za-z0-9+/_=-]{24,}|"
    r"secret|passw|token|api[_-]?key|credential|private",
    re.I,
)

# Object keys are an allowlist too: unknown or suspicious keys map to "<key>".
KNOWN_KEYS = frozenset(
    """agentCount agentId agentType apiErrorStatus cache_creation_input_tokens
    cache_read_input_tokens content cwd defaultModel description durationMs entrypoint
    error error_details hook_event_name id input input_tokens isApiErrorMessage isSidechain
    isMeta key label last_assistant_message message model name output_tokens parentUuid
    permissionMode permission_mode phase requestId result role runId script scriptPath
    session_id sessionId spawnDepth startTime status stop_reason stop_sequence subtype
    summary taskId text timestamp totalTokens totalToolCalls transcript_path
    agent_transcript_path agent_id agent_type parent_session_id source truncatedAfterOutput
    type usage userType uuid version workflowName workflowPhase workflowProgress
    notification_type stop_hook_active tool_name tool_use_id toolUseID toolUseId
    logicalParentUuid leafUuid promptId messageId level gitBranch service_tier mode event
    stopReason endTime createdAt updatedAt projectPath""".split()
)

LIMIT_KINDS = "weekly|session|daily|monthly|Opus|Sonnet|Haiku|weekly Opus|weekly Sonnet|weekly Haiku"
LIMIT_MONTHS = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
LIMIT_ZONES = (
    "UTC|America/(New_York|Chicago|Denver|Phoenix|Los_Angeles|Anchorage|Toronto|Vancouver|Sao_Paulo)"
    "|Europe/(London|Dublin|Paris|Berlin|Madrid|Amsterdam)"
    "|Asia/(Tokyo|Seoul|Shanghai|Singapore|Kolkata|Dubai)"
    "|Australia/(Sydney|Melbourne)|Pacific/Auckland"
)
# Closed grammar: scripts/spike-resume-payloads.sh repeats these lists for the pane
# allowlist; tests/resume_fixtures.bats checks both accept and reject the same probes.
LIMIT_RE = re.compile(
    r"You've hit your (%s) limit \u00b7 resets "
    r"((%s) [0-9]{1,2} at )?[0-9]{1,2}(:[0-9]{2})?[ap]m"
    r"( \((%s)\))?" % (LIMIT_KINDS, LIMIT_MONTHS, LIMIT_ZONES)
)
LIMIT_KEYS = frozenset(["text", "last_assistant_message", "message", "content"])

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

# Numbers can encode text (char codes, a bigint), so they survive only under these keys,
# clamped to [0, cap]. Numbers under any other key, and inside arrays, become 0.
NUM_CAPS = {
    "input_tokens": 10**7,
    "output_tokens": 10**7,
    "cache_creation_input_tokens": 10**7,
    "cache_read_input_tokens": 10**7,
    "totalTokens": 10**8,
    "apiErrorStatus": 599,
    "durationMs": 86400000,
    "spawnDepth": 100,
    "agentCount": 1000,
    "totalToolCalls": 100000,
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
ISO_RE = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")
FAKE_HOME = "/Users/noah/dev/example"


def enum_ok(key, v):
    rule = ENUM_RULES.get(key)
    if rule is None:
        return False
    if isinstance(rule, frozenset):
        return v in rule
    return SUSPICIOUS_RE.search(v) is None and rule.fullmatch(v) is not None


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
        if v == "" or v in CANNED or (key in LIMIT_KEYS and LIMIT_RE.fullmatch(v)):
            return v
        if key in ID_KEYS:
            return self.ident(v)
        if key in TS_KEYS and ISO_RE.match(v):
            return self.stamp()
        if key in PATH_KEYS:
            return self.path(key, v)
        if enum_ok(key, v):
            return v
        return "<str>"

    def number(self, key, v):
        cap = NUM_CAPS.get(key)
        if cap is None:
            return 0
        try:
            return min(max(int(v), 0), cap)
        except (OverflowError, ValueError):
            return 0

    def walk(self, node, key=None, in_array=False):
        if isinstance(node, dict):
            out = {}
            for k, v in node.items():
                known = k in KNOWN_KEYS
                out["<key>" if not known else k] = self.walk(v, k if known else None)
            return out
        if isinstance(node, list):
            return [self.walk(v, key, True) for v in node]
        if isinstance(node, str):
            return self.string(key, node)
        if isinstance(node, bool) or node is None:
            return node
        return self.number(None if in_array else key, node)


def dumps(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))


def skeleton_lines(text, rng=None):
    f = Faker()
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if rng:
        a, b = rng
        lines = lines[a - 1 : b]
    return [dumps(f.walk(json.loads(ln))) for ln in lines]


def stdin_lines(text):
    """One JSON document (possibly multi-line) or JSONL. Raises on bad JSON."""
    try:
        return [dumps(Faker().walk(json.loads(text)))]
    except ValueError:
        return skeleton_lines(text)


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd in ("--stdin", "scrub"):
        print("\n".join(stdin_lines(sys.stdin.read())))
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
        print(dumps(Faker().walk(json.loads(text))))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
