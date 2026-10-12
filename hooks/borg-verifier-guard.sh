#!/usr/bin/env bash
# borg-verifier-guard.sh — PreToolUse hook (matcher: Bash): keep borg-verifier read-only by enforcement, not
# by instruction.
#
# agents/borg-verifier.md needs Bash to re-run the verification command it is given, and its prompt says
# "never modify files, branches, or PR state". Frontmatter cannot narrow that grant: a `disallowedTools` entry
# with a specifier (`Bash(gh pr merge *)`) removes ALL of Bash, plugin agents ignore frontmatter `hooks` and
# `permissionMode`, and a plugin cannot ship `permissions.deny`. A PreToolUse hook keyed on `agent_type` is
# the one lever left. Captured 2026-10-12 from a live spawn: inside the plugin agent the payload carries
# `agent_type: "borg-collective:borg-verifier"`; the borg-setup copy in ~/.claude/agents reports the bare
# `borg-verifier`. Every other caller is a no-op that allows.
#
# For the verifier, an ALLOWLIST for git and gh (the lesson of the 2026-10-10 scout-shell-allowlist directive,
# where three reviews each beat a denylist):
#   - every word whose basename is `git` or `gh`, anywhere in a command, must start a read-only invocation from
#     the tables below, so `drone exec p -- git push`, `find -exec git push` and `env git push` are all seen;
#     a dashed `git-push` / `gh-ext` binary is denied outright;
#   - `bash|sh|zsh|... -c '<script>'` is parsed recursively, so the `bash -c` form every agent is told to use
#     for pipelines still works; heredoc bodies are skipped as data, except that an unquoted body is checked
#     for command substitution;
#   - anything the parser cannot see through is denied: command substitution, `$VAR` / `$'...'` / zsh `=cmd`
#     expansion, brace expansion, a glob in a command position, eval/alias/trap/parallel/watch/tmux and other
#     command runners, a shell or interpreter reading stdin, inline interpreter code (`python -c`, `perl -e`,
#     awk `system()`), GIT_*/GH_*/PAGER environment injection, and `drone` subcommands other than `exec`.
# Other commands (make, pytest, bats, drone exec) pass: the verifier's job is to run them. NOT A SANDBOX: a
# Makefile target or script file that runs `gh pr merge`, or a GitHub write through a client other than gh
# (curl with a pasted token), is opaque to any command-text hook, and file writes outside git (`rm`, `>`)
# remain instruction-only.
#
# Contract: denies with exit 2 and the reason on stderr. Fails CLOSED for the verifier (missing python3, a
# payload that will not parse, an internal error) and OPEN for everyone else. The fast path is pure bash
# builtins: a payload that never mentions borg-verifier exits 0 without forking. Kill switch:
# BORG_VERIFIER_GUARD=0.

set -uo pipefail

[[ "${BORG_VERIFIER_GUARD:-1}" == "0" ]] && exit 0

INPUT=""
IFS= read -r -d "" INPUT || true
[[ "$INPUT" == *borg-verifier* ]] || exit 0

if ! command -v python3 >/dev/null 2>&1; then
    echo "borg verifier guard: python3 is missing, so a borg-verifier Bash call cannot be checked; denying." >&2
    exit 2
fi

# Read with `read -d ""` outside any command substitution: bash 3.2 mis-parses a heredoc nested in $( )
# when it holds a backtick or an unbalanced quote (see tests/hook_bash32_parse.bats).
read -r -d "" GUARD <<'PY' || true
import fnmatch, json, re, sys

VERIFIER_TYPES = ("borg-collective:borg-verifier", "borg-verifier")

# git: global options allowed before the subcommand, read-only subcommands, and list-only rules for
# subcommands that also have write forms.
GIT_GLOBAL_FLAGS = ("--no-pager", "-P", "--no-optional-locks")
GIT_READ = ("blame", "cat-file", "describe", "diff", "for-each-ref", "grep", "log", "ls-files", "ls-tree",
            "merge-base", "rev-list", "rev-parse", "shortlog", "show", "show-ref", "status")
GIT_LIST_ONLY = ("branch", "reflog", "remote", "stash", "worktree")
GIT_BRANCH_FLAGS = ("--show-current", "--list", "-l", "-a", "--all", "-r", "--remotes", "-v", "-vv",
                    "--verbose", "--color", "--no-color", "--column", "--no-column", "--abbrev", "--no-abbrev",
                    "-i", "--ignore-case", "--omit-empty")
GIT_BRANCH_VALUE_FLAGS = ("--contains", "--no-contains", "--merged", "--no-merged", "--points-at", "--format",
                          "--sort")
GH_READ = {"pr": ("checks", "diff", "list", "status", "view"), "issue": ("list", "status", "view"),
           "run": ("list", "view", "watch"), "repo": ("view",), "auth": ("status",)}

SHELLS = ("bash", "sh", "zsh", "dash", "ksh", "mksh", "fish", "csh", "tcsh", "ash", "rbash", "yash", "oksh",
          "posh")
DENIED = ("eval", "alias", "hash", "enable", "trap", "fc", "parallel", "watch", "tmux", "screen", "su", "ssh",
          "script", "expect", "osascript", "pwsh", "powershell", "nu", "xonsh", "elvish", "vim", "nvim", "vi",
          "ex", "emacs", "hub", "glab", "jj")
KEYWORDS = ("if", "then", "else", "elif", "do", "while", "until", "!", "{", "coproc", "noglob", "nocorrect", "-",
            "select")
INTERP_RE = re.compile(r"^(python[0-9.]*|perl[0-9.]*|ruby|node|nodejs|php|bun|deno|lua|luajit|Rscript|tclsh|irb)$")
INLINE_SHORT = {"python": "c", "perl": "eE", "ruby": "e", "node": "ep", "nodejs": "ep", "php": "r", "bun": "e",
                "lua": "e", "luajit": "e", "Rscript": "e"}
INLINE_LONG = ("--eval", "--print")
INTERP_VALUE_FLAGS = {
    "python": ("-W", "-X", "-Q"), "perl": ("-I", "-M", "-m", "-x"), "ruby": ("-I", "-r", "-C", "-E", "-F"),
    "node": ("-r", "--require", "--import", "--loader", "--experimental-loader", "-C", "--conditions",
             "--input-type", "--env-file", "--title"),
    "nodejs": ("-r", "--require", "--import", "--loader", "-C"), "php": ("-c", "-d", "-z"),
    "bun": ("-r", "--preload", "--cwd", "--env-file"), "lua": ("-l",), "luajit": ("-l",),
}
INTERP_INFO_FLAGS = ("-V", "--version", "-h", "--help")
AWK_RE = re.compile(r"^[gmn]?awk$")
AWK_VALUE_OPTS = ("-F", "-v", "-f")
XARGS_VALUE_OPTS = ("-I", "-J", "-L", "-n", "-P", "-s", "-E", "-d", "-a", "--max-args", "--max-procs",
                    "--delimiter", "--arg-file", "--eof")
WRAPPER_VALUE_OPTS = {
    "command": (), "builtin": (), "exec": ("-a",), "nohup": (), "time": (), "chronic": (), "unbuffer": (),
    "caffeinate": ("-t", "-w"), "stdbuf": ("-i", "-o", "-e"), "ionice": ("-c", "-n", "-p"), "nice": ("-n",),
    "sudo": ("-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T"), "doas": ("-u", "-C"),
}
SENSITIVE = (("git", "gh", "find", "drone", "env", "timeout", "run-in", "xargs", "source", ".", "python",
              "python3", "perl", "ruby", "node", "php", "bun", "deno", "awk") + SHELLS + DENIED
             + tuple(WRAPPER_VALUE_OPTS))
DASHED_RE = re.compile(r"^(git|gh)-[A-Za-z0-9_-]+$")
ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
ENV_INJECT_RE = re.compile(r"^(GIT_[A-Za-z0-9_]*|GH_[A-Za-z0-9_]*|PAGER|EDITOR|VISUAL|BROWSER|BASH_ENV)(=|$)")
SPECIAL_PARAMS = "@*-"      # $0..$9 are digits (isalnum); $? $# $$ $! expand to numbers only and stay literal
OPS = ("<<<", "<<-", "&&", "||", ";;", "|&", ">>", "<<", ">&", "<&", "&>", ">|", "<>")
REDIRECTS = ("<", ">", ">>", "<<", "<<-", "<<<", ">&", "<&", "&>", ">|", "<>")
MAX_DEPTH = 4


class Deny(Exception):
    pass


class Word(object):
    __slots__ = ("chars", "dynamic")

    def __init__(self):
        self.chars = []       # (char, quoted)
        self.dynamic = None   # reason string once the shell would expand this word

    @property
    def text(self):
        return "".join(c for c, _ in self.chars)

    @property
    def quoted(self):
        return any(q for _, q in self.chars)

    def add(self, c, quoted):
        self.chars.append((c, quoted))

    def glob_pattern(self):
        """The word as an fnmatch pattern when it holds an unquoted glob character, else None."""
        if not any(not q and c in "*?[" for c, q in self.chars):
            return None
        return "".join(c if not q or c not in "*?[" else "[%s]" % c for c, q in self.chars)

    def has_brace_expansion(self):
        unq = "".join(c if not q else "\0" for c, q in self.chars)
        for m in re.finditer(r"\{([^{}]*)\}", unq):
            if "," in m.group(1) or ".." in m.group(1):
                return True
        return False


def is_param_start(c):
    return c.isalnum() or c == "_" or c == "{" or (c != "" and c in SPECIAL_PARAMS)


def has_substitution(line):
    k = 0
    while k < len(line):
        if line[k] == "\\":
            k += 2
            continue
        if line[k] == "`" or line.startswith("$(", k):
            return True
        k += 1
    return False


def read_heredocs(src, i, pending):
    """Skip heredoc bodies starting at i (just past the newline); return the index after the last one."""
    n = len(src)
    for delim, quoted, strip in pending:
        while i < n:
            j = src.find("\n", i)
            j = n if j < 0 else j
            line = src[i:j]
            i = j + 1
            if (line.lstrip("\t") if strip else line) == delim:
                break
            if not quoted and has_substitution(line):
                raise Deny("an unquoted heredoc body runs $( ) or backticks, which hides the command it runs")
    return min(i, n)


def lex(src):
    """Shell-ish tokens: ('word', Word) and ('op', str). Raises Deny on what it will not see through."""
    toks = []
    pending = []        # heredocs whose bodies start after the next unquoted newline
    i, n = 0, len(src)
    w = None
    hd_next = None      # set (to strip-tabs bool) when the next word is a heredoc delimiter

    def emit():
        nonlocal w, hd_next
        if w is None:
            return
        toks.append(("word", w))
        if hd_next is not None:
            pending.append((w.text, w.quoted, hd_next))
            hd_next = None
        w = None

    while i < n:
        c = src[i]
        if c in " \t\r":
            emit()
            i += 1
            continue
        if c == "\\":
            if i + 1 < n and src[i + 1] == "\n":
                i += 2
                continue
            w = w or Word()
            w.add(src[i + 1] if i + 1 < n else "\\", True)
            i += 2
            continue
        if c == "'":
            j = src.find("'", i + 1)
            if j < 0:
                raise Deny("unterminated single quote")
            w = w or Word()
            for ch in src[i + 1:j]:
                w.add(ch, True)
            i = j + 1
            continue
        if c == '"':
            w = w or Word()
            i = lex_double(src, i + 1, w)
            continue
        if c == "`":
            raise Deny("backtick command substitution hides the command it runs")
        if c == "$":
            nx = src[i + 1] if i + 1 < n else ""
            if nx == "(":
                raise Deny("$( ) substitution hides the command it runs")
            w = w or Word()
            if nx in ("'", '"'):
                w.dynamic = "$'...' / $\"...\" quoting"
            elif is_param_start(nx):
                w.dynamic = "$ expansion"
            w.add("$", False)
            i += 1
            continue
        if c == "#" and w is None:
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "<>" and src.startswith("(", i + 1):
            raise Deny("process substitution hides the command it runs")
        if c in ";&|()<>\n":
            emit()
            op = next((o for o in OPS if src.startswith(o, i)), c)
            toks.append(("op", op))
            i += len(op)
            if op in ("<<", "<<-"):
                hd_next = op == "<<-"
            elif op == "\n" and pending:
                i = read_heredocs(src, i, pending)
                pending = []
            continue
        if w is None and c == "=" and i + 1 < n and (src[i + 1].isalnum() or src[i + 1] in "_.-"):
            w = Word()
            w.dynamic = "zsh =command expansion"
        w = w or Word()
        w.add(c, False)
        i += 1
    emit()
    return toks


def lex_double(src, i, w):
    n = len(src)
    while i < n:
        c = src[i]
        if c == '"':
            return i + 1
        if c == "\\" and i + 1 < n and src[i + 1] in '$`"\\\n':
            if src[i + 1] != "\n":
                w.add(src[i + 1], True)
            i += 2
            continue
        if c == "`":
            raise Deny("backtick command substitution hides the command it runs")
        if c == "$":
            nx = src[i + 1] if i + 1 < n else ""
            if nx == "(":
                raise Deny("$( ) substitution hides the command it runs")
            if is_param_start(nx):
                w.dynamic = "$ expansion"
        w.add(c, True)
        i += 1
    raise Deny("unterminated double quote")


def simple_commands(toks):
    cmds, cur, skip = [], [], False
    for kind, v in toks:
        if kind == "op":
            if v in REDIRECTS:
                skip = True
                continue
            cmds.append(cur)
            cur, skip = [], False
            continue
        if skip:
            skip = False
            continue
        cur.append(v)
    cmds.append(cur)
    return [c for c in cmds if c]


def base(t):
    return t.rstrip("/").rsplit("/", 1)[-1]


def option_name(t):
    return t.split("=", 1)[0]


def abbreviates(t, full, min_len):
    name = option_name(t)
    return len(name) >= min_len and name.startswith("--") and full.startswith(name)


def check_git_list_only(sub, rest):
    texts = [a.text for a in rest]
    first = texts[0] if texts else ""
    if sub == "branch":
        listing, positional, k = "--list" in texts or "-l" in texts, False, 0
        while k < len(texts):
            t = texts[k]
            if t in GIT_BRANCH_VALUE_FLAGS:
                k += 2
                continue
            if option_name(t) in GIT_BRANCH_VALUE_FLAGS + GIT_BRANCH_FLAGS:
                k += 1
                continue
            if t.startswith("-"):
                raise Deny("`git branch %s` is not a listing option" % t)
            positional = True
            k += 1
        if positional and not listing:
            raise Deny("`git branch <name>` creates a branch; list with --list <pattern> or --show-current")
    elif sub == "remote":
        if texts and not (texts in (["-v"], ["--verbose"]) or first in ("get-url", "show")):
            raise Deny("`git remote %s` is not read-only; use git remote -v, get-url or show" % first)
    elif sub == "reflog":
        if first in ("expire", "delete"):
            raise Deny("`git reflog %s` rewrites the reflog" % first)
    elif sub == "worktree":
        if first != "list":
            raise Deny("only `git worktree list` is read-only")
    elif sub == "stash":
        if first not in ("list", "show"):
            raise Deny("only `git stash list` and `git stash show` are read-only (bare `git stash` writes)")


def check_git(args):
    k = 0
    while k < len(args):
        t = args[k].text
        if t == "-C":
            k += 2
            continue
        if t.startswith("-C") or t in GIT_GLOBAL_FLAGS:
            k += 1
            continue
        if t == "--version" and k == len(args) - 1:
            return
        if t.startswith("-"):
            raise Deny("git option %r before the subcommand is not allowed (only -C, --no-pager, -P, "
                       "--no-optional-locks)" % t)
        break
    if k >= len(args):
        raise Deny("a bare `git` word (or a path ending in /git) must start a read-only git command")
    sub = args[k].text
    rest = args[k + 1:]
    if sub in GIT_LIST_ONLY:
        check_git_list_only(sub, rest)
    elif sub not in GIT_READ:
        raise Deny("`git %s` is not read-only. Allowed: git %s, and listing forms of git %s"
                   % (sub, "|".join(GIT_READ), "|".join(GIT_LIST_ONLY)))
    for a in rest:
        if abbreviates(a.text, "--output", 3):
            raise Deny("`git %s %s` writes a file (--output, or an abbreviation of it)" % (sub, a.text))
        if sub == "grep" and (abbreviates(a.text, "--open-files-in-pager", 4) or a.text.startswith("-O")):
            raise Deny("`git grep %s` runs a pager program" % a.text)


def check_gh(args):
    k = 0
    while k < len(args):
        t = args[k].text
        if t in ("-R", "--repo"):
            k += 2
            continue
        if t.startswith("--repo=") or (t.startswith("-R") and len(t) > 2):
            k += 1
            continue
        if t.startswith("-"):
            raise Deny("gh option %r before the command is not allowed (only -R/--repo)" % t)
        break
    if k >= len(args):
        raise Deny("a bare `gh` word must start a read-only gh command")
    group = args[k].text
    if group == "api":
        return check_gh_api(args[k + 1:])
    sub = args[k + 1].text if k + 1 < len(args) else ""
    if group not in GH_READ or sub not in GH_READ[group]:
        allowed = "; ".join("gh %s %s" % (g, "|".join(s)) for g, s in sorted(GH_READ.items()))
        raise Deny("`gh %s %s` is not read-only. Allowed: %s; GET-only gh api" % (group, sub, allowed))


def check_gh_api(args):
    def value(j, rest):
        return rest if rest else (args[j + 1].text if j + 1 < len(args) else "")

    j = 0
    while j < len(args):
        t = args[j].text
        if t.startswith("--"):
            name, _, val = t.partition("=")
            if name in ("--field", "--raw-field", "--input"):
                raise Deny("`gh api %s` sends a request body, which makes it a write" % name)
            if name == "--method" and value(j, val).upper() != "GET":
                raise Deny("`gh api --method %s` is a write; only GET is allowed" % value(j, val))
            if name == "--header" and "method" in value(j, val).lower():
                raise Deny("`gh api --header` may not override the HTTP method")
        elif t.startswith("-") and len(t) > 1:
            cluster = t[1:]
            for idx, c in enumerate(cluster):
                if c in "fF":
                    raise Deny("`gh api -%s` sends a request body, which makes it a write" % c)
                if c in "XHpqt":
                    v = value(j, cluster[idx + 1:])
                    if c == "X" and v.upper() != "GET":
                        raise Deny("`gh api -X %s` is a write; only GET is allowed" % v)
                    if c == "H" and "method" in v.lower():
                        raise Deny("`gh api -H` may not override the HTTP method")
                    break
        elif t.lstrip("/").startswith("graphql"):
            raise Deny("`gh api graphql` can run mutations; use gh pr view --json instead")
        j += 1


def shell_script(words, i):
    """For a shell word at i: (has_c, operand_word_or_None, operand_is_a_script_file)."""
    j, has_c, stdin_flag = i + 1, False, False
    while j < len(words):
        t = words[j].text
        if t == "--":
            j += 1
            break
        if not t.startswith("-") and not t.startswith("+"):
            break
        if t in ("-o", "+o", "-O", "+O", "--rcfile", "--init-file"):
            j += 2
            continue
        if not t.startswith("--"):
            has_c = has_c or "c" in t[1:]
            stdin_flag = stdin_flag or "s" in t[1:]
        j += 1
    operand = words[j] if j < len(words) else None
    return has_c, operand, operand is not None and not stdin_flag


def skip_xargs(words, pos):
    n, j, replace = len(words), pos + 1, False
    while j < n and words[j].text.startswith("-") and words[j].text != "--":
        t = words[j].text
        replace = replace or t[:2] in ("-I", "-J", "-i") or option_name(t) == "--replace"
        j += 2 if t in XARGS_VALUE_OPTS else 1
    if j < n and words[j].text == "--":
        j += 1
    if replace and j < n:
        b = base(words[j].text)
        if b in SHELLS or INTERP_RE.match(b) or AWK_RE.match(b):
            raise Deny("`xargs -I` into %s splices stdin into code, which cannot be checked" % b)
    return j


def skip_wrapper(b, words, pos):
    """Index of the command a wrapper word at pos runs, or None when b is not a wrapper."""
    n = len(words)
    if b in KEYWORDS:
        return pos + 1
    if b in ("function", "repeat"):
        return pos + 2
    if b == "xargs":
        return skip_xargs(words, pos)
    if b == "env":
        j = pos + 1
        while j < n:
            t = words[j].text
            if t in ("-S", "--split-string") or t.startswith("-S") or t.startswith("--split-string"):
                raise Deny("`env -S` re-splits a string into a command, which cannot be checked")
            if t in ("-u", "--unset", "-C", "--chdir"):
                j += 2
            elif t == "--":
                j += 1
                break
            elif t.startswith("-") or ASSIGN_RE.match(t):
                j += 1
            else:
                break
        return j
    if b in WRAPPER_VALUE_OPTS or b == "timeout":
        vo = WRAPPER_VALUE_OPTS.get(b, ("-s", "-k", "--signal", "--kill-after"))
        j = pos + 1
        while j < n and words[j].text.startswith("-") and words[j].text != "--":
            j += 2 if words[j].text in vo else 1
        if j < n and words[j].text == "--":
            j += 1
        return j + 1 if b == "timeout" else j
    if b == "run-in":
        return pos + 2
    if b == "drone" and pos + 1 < n and words[pos + 1].text == "exec":
        for j in range(pos + 2, n):
            if words[j].text == "--":
                return j + 1
    return None


def command_positions(words):
    work, seen = [0], []
    while work:
        pos = work.pop()
        while pos < len(words) and ASSIGN_RE.match(words[pos].text):
            pos += 1
        while pos < len(words) and pos not in seen:
            seen.append(pos)
            b = base(words[pos].text)
            if b == "find":
                work.extend(j + 1 for j in range(pos + 1, len(words))
                            if words[j].text in ("-exec", "-execdir", "-ok", "-okdir"))
            nxt = skip_wrapper(b, words, pos)
            if nxt is None:
                break
            pos = nxt
    return seen


def check_interpreter(b, words, pos):
    key = re.sub(r"[0-9.]+$", "", b)
    short = INLINE_SHORT.get(key, "")
    vflags = INTERP_VALUE_FLAGS.get(key, ())
    j, info = pos + 1, False
    while j < len(words):
        t = words[j].text
        if t == "--":
            j += 1
            break
        if t == "-" or not t.startswith("-"):
            break
        info = info or t in INTERP_INFO_FLAGS
        if t in INLINE_LONG:
            raise Deny("`%s %s` runs inline code this guard cannot see; put it in a test file" % (b, t))
        step = 2 if t in vflags else 1
        if not t.startswith("--"):
            for idx, c in enumerate(t[1:]):
                if c in short:
                    raise Deny("`%s %s` runs inline code this guard cannot see; put it in a test file" % (b, t))
                if key == "python" and c == "m":
                    return
                if "-" + c in vflags:
                    step = 1 if t[idx + 2:] else 2
                    break
        j += step
    operand = words[j].text if j < len(words) else None
    if key == "deno":
        if operand in (None, "eval", "repl"):
            raise Deny("`deno %s` runs code this guard cannot see" % (operand or ""))
        return
    if operand in (None, "-") and not info:
        raise Deny("`%s` with no script file reads code from stdin, which cannot be checked" % b)


def check_command_position(words, pos):
    b = base(words[pos].text)
    nxt = words[pos + 1].text if pos + 1 < len(words) else ""
    if b in DENIED:
        raise Deny("`%s` runs commands this guard cannot see" % b)
    if b == "drone" and nxt != "exec":
        raise Deny("`drone %s` changes container state; the verifier may only use drone exec" % nxt)
    if b in ("npm", "pnpm", "yarn") and nxt == "version":
        raise Deny("`%s version` commits and tags in git" % b)
    if b in ("source", ".") and (nxt in ("", "-") or nxt.startswith("/dev/")):
        raise Deny("`%s %s` reads commands from a stream, which cannot be checked" % (b, nxt))
    if INTERP_RE.match(b):
        check_interpreter(b, words, pos)
    if AWK_RE.match(b):
        j = pos + 1
        while j < len(words) and words[j].text.startswith("-") and words[j].text != "--":
            if words[j].text.startswith("-f"):
                return
            j += 2 if words[j].text in AWK_VALUE_OPTS else 1
        if j < len(words) and words[j].text == "--":
            j += 1
        prog = words[j].text if j < len(words) else ""
        if "system" in prog or "|" in prog:
            raise Deny("this awk program runs commands (system() or a | pipe), which cannot be checked")
    if b in SHELLS:
        has_c, _, has_operand = shell_script(words, pos)
        if not has_c and not has_operand:
            raise Deny("`%s` with no -c and no script file reads commands from stdin, which cannot be "
                       "checked" % b)


def check(src, depth):
    if depth > MAX_DEPTH:
        raise Deny("shell -c nesting deeper than %d" % MAX_DEPTH)
    for words in simple_commands(lex(src)):
        positions = command_positions(words)
        for idx, w in enumerate(words):
            if w.dynamic:
                raise Deny("%r uses %s, so the command it names cannot be checked" % (w.text, w.dynamic))
            if w.has_brace_expansion():
                raise Deny("%r uses brace expansion, so the command it names cannot be checked" % w.text)
            pat = w.glob_pattern()
            if pat and idx in positions and any(fnmatch.fnmatchcase(s, base(pat)) for s in SENSITIVE):
                raise Deny("glob %r in a command position could expand to a command name" % w.text)
            if ENV_INJECT_RE.match(w.text):
                raise Deny("%r changes how git/gh or a shell behaves" % w.text.split("=", 1)[0])
            if DASHED_RE.match(base(w.text)):
                raise Deny("%r is a git/gh subcommand binary; call git or gh with a read-only subcommand"
                           % w.text)
        for i, w in enumerate(words):
            b = base(w.text)
            if b == "git":
                check_git(words[i + 1:])
            elif b == "gh":
                check_gh(words[i + 1:])
            elif b in SHELLS:
                has_c, script, _ = shell_script(words, i)
                if has_c and script is not None:
                    check(script.text, depth + 1)
                elif has_c:
                    raise Deny("`%s -c` with no script" % b)
        for pos in positions:
            check_command_position(words, pos)


def deny(reason):
    sys.stderr.write("borg verifier guard: Bash denied for borg-verifier.\n  - %s\n" % reason)
    sys.stderr.write("borg-verifier is read-only. git is limited to %s and listing forms of %s; gh to pr "
                     "view/diff/checks/list/status, issue and run reads, repo view, auth status and GET-only "
                     "api. Run the verification command as given; if it cannot run, report it instead of "
                     "working around this guard. Kill switch: BORG_VERIFIER_GUARD=0.\n"
                     % ("|".join(GIT_READ), "|".join(GIT_LIST_ONLY)))
    return 2


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except ValueError:
        return deny("the hook payload mentions borg-verifier but is not valid JSON, so the caller cannot be "
                    "established")
    if not isinstance(data, dict) or data.get("agent_type") not in VERIFIER_TYPES:
        return 0
    if data.get("tool_name") != "Bash":
        return 0
    ti = data.get("tool_input")
    cmd = ti.get("command") if isinstance(ti, dict) else None
    if not isinstance(cmd, str):
        return deny("tool_input.command is missing")
    try:
        check(cmd, 0)
    except Deny as exc:
        return deny(str(exc))
    return 0


try:
    rc = main()
except Exception as exc:
    sys.stderr.write("borg verifier guard: internal error (%s: %s); denying\n" % (type(exc).__name__, exc))
    rc = 2
sys.exit(rc)
PY

printf '%s' "$INPUT" | python3 -I -c "$GUARD"
rc=$?
[[ $rc -eq 0 ]] && exit 0
exit 2
