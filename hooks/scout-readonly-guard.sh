#!/usr/bin/env bash
# scout-readonly-guard.sh — PreToolUse hook (matcher: Bash): keep borg-scout read-only by enforcement.
#
# agents/borg-scout.md grants Bash so a cheap scout can run git/gh/jq/grep lookups instead of the Opus main
# session. Frontmatter cannot narrow Bash, so this hook is the grant's other half: without it the scout would
# be an unguarded shell. Scoped by the payload's `agent_type` the way borg-verifier-guard.sh is (plugin agent:
# `borg-collective:borg-scout`; borg-setup copy: bare `borg-scout`); every other caller is a no-op that allows.
#
# An ALLOWLIST built on a quote-aware lexer (the lesson of the 2026-10-10 scout-shell-allowlist directive:
# denylist guards lost three reviews). For the scout, a command is allowed only when ALL of this holds:
#   - it lexes cleanly: single quotes are literal; double quotes may not hold `$`, a backtick or a backslash;
#     unquoted text may not hold `$`, a backtick, a backslash, `;`, `&`, `<`, `>`, `(`, `)`, `{`, `}`, a newline
#     or a control character; an unquoted word may not start with `#`, `=`, `~`, `^` or a glob character;
#   - the only operator is a single `|`, and every pipeline segment is one allowlisted command, named bare
#     (no path, no `env`/`xargs`/`tee`/shell wrapper, no `VAR=x` prefix);
#   - each command passes its own table below: git and gh by subcommand, the rest by option rules.
#   - any `--output*` option (or an abbreviation of it) is denied everywhere except jq, and `-o` everywhere
#     except grep, rg and jq (`sort -o`, `git log -o` write files).
# Anything the lexer or a table cannot decide is denied. NOT A SANDBOX: it reads any file the user can, and a
# repository's own git config (textconv/diff drivers) is outside command text.
#
# Contract: deny exits 2 with the reason on stderr. Fails CLOSED for the scout (missing python3, an
# unparseable payload that names the scout, an internal error) and OPEN for everyone else. The fast path is pure
# bash builtins: a payload that never mentions borg-scout exits 0 without forking. Kill switch:
# BORG_SCOUT_GUARD=0.

set -uo pipefail

[[ "${BORG_SCOUT_GUARD:-1}" == "0" ]] && exit 0

INPUT=""
IFS= read -r -d "" INPUT || true
[[ "$INPUT" == *borg-scout* ]] || exit 0

if ! command -v python3 >/dev/null 2>&1; then
    echo "borg scout guard: python3 is missing, so a borg-scout Bash call cannot be checked; denying." >&2
    exit 2
fi

# Read with `read -d ""` outside any command substitution (bash 3.2 heredoc-in-$( ) parse bug, see
# tests/hook_bash32_parse.bats).
read -r -d "" GUARD <<'PY' || true
import json, re, sys

SCOUT_TYPES = ("borg-collective:borg-scout", "borg-scout")
GIT_READ = ("log", "show", "diff", "status", "rev-parse", "ls-files", "grep", "blame")
GIT_BAD_LONG = ("--output", "--ext-diff", "--textconv", "--open-files-in-pager", "--no-index", "--upload-pack",
                "--exec", "--receive-pack", "--config", "--exec-path", "--paginate", "--git-dir", "--work-tree")
GIT_LS_REMOTE_OK = ("--heads", "--tags", "--refs", "--symref", "--quiet")
GIT_BRANCH_OK = ("--list", "--show-current", "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose",
                 "--no-color", "--color", "--format", "--sort", "--contains", "--no-contains", "--merged",
                 "--no-merged", "--points-at")
GH_SUBS = {"pr": ("view", "list", "checks", "diff"), "issue": ("view", "list")}
GH_SEARCH = ("prs", "issues", "repos", "code", "commits")
GH_API_OK = ("--method", "-X", "--jq", "-q", "--paginate", "--slurp", "--include", "-i", "--silent", "--cache",
             "--template", "-t", "--verbose")
GH_API_VALUE = ("--jq", "--template", "--cache")
SIMPLE = ("jq", "rg", "grep", "head", "tail", "wc", "ls", "cat", "sort", "uniq", "cut", "find")
FIND_BAD = ("-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fls")
SORT_BAD_LONG = ("--output", "--compress-program")
RG_BAD_LONG = ("--pre", "--hostname-bin", "--search-zip")
UNIQ_VALUE = ("-f", "-s", "-w", "--skip-fields", "--skip-chars", "--check-chars")
CTRL_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")


class Deny(Exception):
    pass


class Word(object):
    def __init__(self):
        self.text = ""
        self.quoted = False


def lex(src):
    """Return a list of pipeline segments, each a list of Word. Raises Deny on anything doubtful."""
    segs, cur, w = [], [], None
    i, n = 0, len(src)
    if not src.strip():
        raise Deny("empty command")

    def emit():
        nonlocal w
        if w is not None:
            cur.append(w)
            w = None

    while i < n:
        c = src[i]
        if c in " \t":
            emit()
            i += 1
            continue
        if c == "'":
            j = src.find("'", i + 1)
            if j < 0:
                raise Deny("unterminated single quote")
            w = w or Word()
            w.text += src[i + 1:j]
            w.quoted = True
            i = j + 1
            continue
        if c == '"':
            j = i + 1
            w = w or Word()
            w.quoted = True
            while True:
                if j >= n:
                    raise Deny("unterminated double quote")
                d = src[j]
                if d == '"':
                    break
                if d in "$`\\":
                    raise Deny("%r inside double quotes can expand; use single quotes" % d)
                w.text += d
                j += 1
            i = j + 1
            continue
        if c == "|":
            if src.startswith("||", i) or src.startswith("|&", i):
                raise Deny("'%s' is not allowed; only a plain pipe" % src[i:i + 2])
            emit()
            if not cur:
                raise Deny("empty pipeline segment")
            segs.append(cur)
            cur = []
            i += 1
            continue
        if c in ";&<>(){}`$\\\n\r" or CTRL_RE.match(c):
            raise Deny("unquoted %r is not allowed (separator, redirect, expansion or control character)" % c)
        if w is None:
            if c in "#=~^*?[":
                raise Deny("a word may not start with an unquoted %r" % c)
            w = Word()
        elif c == "~" and w.text and w.text[-1] in ":=":
            raise Deny("tilde expansion is not allowed")
        w.text += c
        i += 1
    emit()
    if not cur:
        raise Deny("empty pipeline segment")
    segs.append(cur)
    return segs


def long_abbrev(opt, full):
    name = opt.split("=", 1)[0]
    return len(name) >= 3 and name.startswith("--") and full.startswith(name)


def bad_long(opt, bads):
    return any(long_abbrev(opt, b) for b in bads)


def has_short(arg, letters):
    return arg.startswith("-") and not arg.startswith("--") and any(ch in letters for ch in arg[1:])


def universal(cmd, args):
    if cmd == "jq":
        return
    for a in args:
        if a == "--":
            break
        if a.startswith("--output") or (a.startswith("--o") and long_abbrev(a, "--output")):
            raise Deny("%s: --output writes a file" % cmd)
        if a == "-o" and cmd not in ("grep", "rg"):
            raise Deny("%s: -o writes a file" % cmd)


def check_git(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] == "--no-pager":
            i += 1
        elif args[i] == "-C" and i + 1 < len(args) and not args[i + 1].startswith("-"):
            i += 2
        else:
            raise Deny("git: global option %r is not allowed (no -c, --git-dir, --exec-path, ...)" % args[i])
    if i >= len(args):
        raise Deny("git: no subcommand")
    sub, rest = args[i], args[i + 1:]
    if sub in GIT_READ:
        for a in rest:
            if a == "--":
                break
            if bad_long(a, GIT_BAD_LONG):
                raise Deny("git %s: option %r can write, run a program or read outside the repo" % (sub, a))
            if has_short(a, "oO"):
                raise Deny("git %s: short option %r writes a file or opens a pager" % (sub, a))
        return
    if sub == "ls-remote":
        for a in rest:
            if a.startswith("-") and a.split("=", 1)[0] not in GIT_LS_REMOTE_OK:
                raise Deny("git ls-remote: option %r is not allowed" % a)
            if "::" in a:
                raise Deny("git ls-remote: a transport helper URL runs a program")
        return
    if sub == "branch":
        if "--list" not in rest and "--show-current" not in rest:
            raise Deny("git branch: only --list and --show-current are read-only")
        for a in rest:
            if a.startswith("-") and a.split("=", 1)[0] not in GIT_BRANCH_OK:
                raise Deny("git branch: option %r is not allowed" % a)
        return
    raise Deny("git %s is not in the read-only allowlist" % sub)


def check_gh(args):
    if len(args) < 2:
        raise Deny("gh: need a subcommand")
    top, sub, rest = args[0], args[1], args[2:]
    if top == "api":
        return check_gh_api(args[1:])
    if top in GH_SUBS:
        ok = sub in GH_SUBS[top]
    elif top == "search":
        ok = sub in GH_SEARCH
    else:
        ok = False
    if not ok:
        raise Deny("gh %s %s is not in the read-only allowlist" % (top, sub))
    for a in rest:
        if a == "--web" or has_short(a, "w"):
            raise Deny("gh: --web / -w opens a browser")
        if a.split("=", 1)[0] in ("--hostname",):
            raise Deny("gh: --hostname is not allowed")


def check_gh_api(args):
    endpoints, i = 0, 0
    while i < len(args):
        a = args[i]
        name = a.split("=", 1)[0]
        if a.startswith("--"):
            if name not in GH_API_OK:
                raise Deny("gh api: option %r is not allowed (no -f/-F/--field/--raw-field/--input/-H/--hostname)" % a)
            if name == "--method":
                val = a.split("=", 1)[1] if "=" in a else (args[i + 1] if i + 1 < len(args) else "")
                if val.upper() != "GET":
                    raise Deny("gh api: only --method GET is allowed, got %r" % val)
                i += 1 if "=" in a else 2
                continue
            i += 2 if (name in GH_API_VALUE and "=" not in a) else 1
        elif a.startswith("-") and len(a) > 1:
            if a[:2] == "-X":
                val = a[2:].lstrip("=") if len(a) > 2 else (args[i + 1] if i + 1 < len(args) else "")
                if val.upper() != "GET":
                    raise Deny("gh api: only -X GET is allowed, got %r" % val)
                i += 1 if len(a) > 2 else 2
            elif a in ("-q", "-t"):
                i += 2
            elif a in ("-i",):
                i += 1
            else:
                raise Deny("gh api: short option %r is not allowed" % a)
        else:
            endpoints += 1
            if "://" in a or a.startswith("//"):
                raise Deny("gh api: an absolute URL is not allowed")
            i += 1
    if endpoints == 0:
        raise Deny("gh api: no endpoint")


def check_simple(cmd, args):
    if cmd == "jq":
        return
    if cmd == "find":
        for a in args:
            if a.startswith("-") and any(a == b or (b in ("-fprint", "-ok") and a.startswith(b)) for b in FIND_BAD):
                raise Deny("find: %s runs a program or writes a file" % a)
        return
    if cmd == "sort":
        for a in args:
            if a == "--":
                break
            if bad_long(a, SORT_BAD_LONG) or has_short(a, "o"):
                raise Deny("sort: %r writes a file or runs a program" % a)
    elif cmd == "rg":
        for a in args:
            if a == "--":
                break
            if bad_long(a, RG_BAD_LONG) or has_short(a, "z"):
                raise Deny("rg: %r runs a program" % a)
    elif cmd == "tail":
        for a in args:
            if a in ("--follow", "-F") or a.startswith("--follow=") or has_short(a, "f"):
                raise Deny("tail: follow never returns")
    elif cmd == "uniq":
        pos, skip = 0, False
        for a in args:
            if skip:
                skip = False
            elif a in UNIQ_VALUE:
                skip = True
            elif not a.startswith("-"):
                pos += 1
        if pos > 1:
            raise Deny("uniq: a second positional argument is an output file")


def check_segment(words):
    cmd = words[0].text
    if cmd not in SIMPLE and cmd not in ("git", "gh"):
        raise Deny("%r is not in the scout allowlist (git, gh, jq, rg, grep, find, head, tail, wc, ls, cat, sort, "
                   "uniq, cut)" % cmd)
    args = [x.text for x in words[1:]]
    universal(cmd, args)
    if cmd == "git":
        check_git(args)
    elif cmd == "gh":
        check_gh(args)
    else:
        check_simple(cmd, args)


def deny(reason):
    sys.stderr.write("borg scout guard: denied for borg-scout.\n  - %s\nThe scout's Bash is read-only: git/gh "
                     "reads, jq, rg, grep, find, head, tail, wc, ls, cat, sort, uniq, cut, joined by a plain pipe. "
                     "Kill switch: BORG_SCOUT_GUARD=0.\n" % reason)
    return 2


def main():
    try:
        data = json.loads(sys.stdin.read())
    except ValueError:
        return deny("unparseable hook payload")
    if not isinstance(data, dict) or data.get("agent_type") not in SCOUT_TYPES:
        return 0
    if data.get("tool_name") != "Bash":
        return 0
    ti = data.get("tool_input")
    cmd = ti.get("command") if isinstance(ti, dict) else None
    if not isinstance(cmd, str):
        return deny("Bash call without a command string")
    try:
        for seg in lex(cmd):
            check_segment(seg)
    except Deny as e:
        return deny(str(e))
    return 0


try:
    rc = main()
except Exception as e:
    rc = deny("internal error (%s), failing closed" % type(e).__name__)
sys.exit(rc)
PY

printf '%s' "$INPUT" | python3 -I -c "$GUARD"
rc=$?
[[ $rc -eq 0 ]] && exit 0
exit 2
