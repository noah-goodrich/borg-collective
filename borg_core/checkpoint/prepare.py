"""Pure assembler for `borg checkpoint-prepare`: already-read facts in, one plain-text document out.

UNCONDITIONALLY free of raw I/O: no clock, no environment, no subprocess, no filesystem. The impure reads live in
`prepare_shell.py`; this module only decides what the document says, in what order, with what bounds. That split
is what makes the two properties that matter pinnable by pytest on literals: the document's SHAPE (the next slice's
SKILL.md relies on these exact headers) and its BOUNDS (a document over the Bash tool's inline ceiling arrives as a
file path plus a preview, which costs the model the very request this command exists to save).

WHY THE FORMAT IS WHAT IT IS. The document is injected into a skill before the model sees it, so a reader is a
language model that treats text as potential instruction. Two rules follow.

  1. Anything that originates outside this repository's own code is DATA. Multi-line text (extension bodies, git
     output) is printed between fence lines, and a body line that starts with a fence delimiter gets a leading
     backslash, so a body can never close its own fence. Single-line text (a refusal reason, a prefer-tool value)
     is printed as a JSON string -- double quotes, escapes, no way to span lines.
  2. The bounds are hard. Each extension body is cut at `MAX_BODY_BYTES`, git status at `MAX_STATUS_LINES`, and
     the whole at `MAX_OUTPUT_BYTES`; every cut leaves a `[TRUNCATED: ...]` marker, because a silently shortened
     extension is a silently ignored instruction.

The fixed headers are documented in docs/plans/directives/2026-10-14-link-up-prepare.md.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass

VERSION_LINE = "borg checkpoint-prepare v1"

MAX_OUTPUT_BYTES = 24576
MAX_BODY_BYTES = 6144
MAX_STATUS_LINES = 60
MAX_LINE_BYTES = 200
MAX_QUOTED_CHARS = 300
MAX_COLLISION_SUFFIX = 1000

FENCE_BEGIN = "----- BEGIN QUOTED DATA: "
FENCE_END = "----- END QUOTED DATA: "
FENCE_TAIL = " -----"

HOOKS = ("01-context", "02-output", "03-followup")
LAYERS = ("machine", "repository")

NOT_PRESENT = "not present"
NO_EXTENSION = "no extension present"


@dataclass(frozen=True)
class ExtensionLayer:
    """One extension file that exists: where it is and what it says."""

    path: str
    body: str
    # The file's real size when the reader stopped short of the end of it; 0 means `body` is the whole file.
    total_bytes: int = 0


@dataclass(frozen=True)
class Extension:
    """One hook point: its two layers (None when the file is absent) and the precedence note."""

    hook: str
    machine: ExtensionLayer | None = None
    repository: ExtensionLayer | None = None
    precedence: str = NO_EXTENSION


@dataclass(frozen=True)
class PreferRow:
    """One resolved prefer-tool preference for the borg-link-up subject."""

    hook: str
    layer: str
    status: str
    prefer: str
    instead_of: str


@dataclass(frozen=True)
# JUSTIFICATION: thirteen plain facts gathered by `prepare_shell.gather`; bundling them would only rename them.
class Facts:  # pylint: disable=too-many-instance-attributes
    """Everything the impure layer read. Every field defaults to the "nothing known" value."""

    root: str = "unknown"
    checkpoint_path: str = "unknown"
    plan: str = ""
    git_status: str | None = None
    git_reason: str = "not read"
    manifest_stem: str = ""
    manifest_refusal: str = "not read"
    pr_ref: str = ""
    pr_url: str = ""
    pr_reason: str = "not read"
    prefer: tuple[PreferRow, ...] = ()
    extensions: tuple[Extension, ...] = ()
    problems: tuple[str, ...] = ()


def _one_line(text: str) -> str:
    """`text` with every control or line-breaking character replaced, so it cannot span lines."""
    return "".join(char if char.isprintable() else "?" for char in text)


def _squash(text: str) -> str:
    """Whitespace runs (newlines included) collapsed to single spaces."""
    return " ".join(text.split())


def quote(text: str) -> str:
    """`text` as a JSON string on one line, cut at `MAX_QUOTED_CHARS`. For single-line external data."""
    return json.dumps(_squash(text)[:MAX_QUOTED_CHARS], ensure_ascii=False)


def _cut_bytes(text: str, limit: int) -> str:
    """`text` cut to at most `limit` UTF-8 bytes, on a character boundary."""
    return text.encode("utf-8", errors="replace")[:limit].decode("utf-8", errors="ignore")


def _label(hook: str) -> str:
    return hook.upper().replace("-", "_")


def _escape(line: str) -> str:
    """A body line that could be read as a fence delimiter is printed with a leading backslash."""
    if line.startswith(FENCE_BEGIN) or line.startswith(FENCE_END):
        return "\\" + line
    return line


def _fence(label: str, lines: list[str], marker: str) -> list[str]:
    """The fence lines for `label`; `marker` (when non-empty) is the last line inside the fence."""
    inner = [_escape(line) for line in lines]
    if marker:
        inner.append(marker)
    return [f"{FENCE_BEGIN}{label}{FENCE_TAIL}", *inner, f"{FENCE_END}{label}{FENCE_TAIL}"]


def _body_lines(body: str, limit: int, total: int = 0) -> tuple[list[str], str]:
    """`(lines, marker)` for one extension body, cut at `limit` bytes. The marker is "" when nothing was cut.

    `total` is the file's real size when the reader was itself bounded, so the marker never understates what was
    left out.
    """
    raw = max(len(body.encode("utf-8", errors="replace")), total)
    if raw <= limit:
        return body.splitlines(), ""
    marker = f"[TRUNCATED: extension body cut at {limit} bytes; {raw - limit} bytes omitted]"
    return _cut_bytes(body, limit).splitlines(), marker


def _git_block(status: str | None, reason: str) -> list[str]:
    if status is None:
        return [f"GIT_STATUS: unavailable: {_one_line(reason)}"]
    lines = status.splitlines()
    kept = [_cut_bytes(line, MAX_LINE_BYTES) for line in lines[:MAX_STATUS_LINES]]
    omitted = len(lines) - len(kept)
    marker = f"[TRUNCATED: git status limited to {MAX_STATUS_LINES} lines; {omitted} lines omitted]" if omitted else ""
    return ["GIT_STATUS:", *_fence("GIT_STATUS", kept, marker)]


def _prefer_lines(rows: tuple[PreferRow, ...]) -> list[str]:
    if not rows:
        return ["PREFER_TOOL: none"]
    return [
        f"PREFER_TOOL: hook={_one_line(r.hook)} layer={_one_line(r.layer)} status={_one_line(r.status)} "
        f"prefer={quote(r.prefer)} instead_of={quote(r.instead_of)}"
        for r in rows
    ]


def _extension_lines(extension: Extension, body_limit: int) -> list[str]:
    label = f"EXTENSION_{_label(extension.hook)}"
    out: list[str] = []
    for layer_name, layer in (("MACHINE", extension.machine), ("REPOSITORY", extension.repository)):
        if layer is None:
            out.append(f"{label}_{layer_name}: {NOT_PRESENT}")
            continue
        out.append(f"{label}_{layer_name}: {_one_line(layer.path)}")
        lines, marker = _body_lines(layer.body, body_limit, layer.total_bytes)
        out.extend(_fence(f"{label}_{layer_name}", lines, marker))
    out.append(f"{label}_PRECEDENCE: {_one_line(extension.precedence)}")
    return out


def _status_line(problems: tuple[str, ...]) -> str:
    reasons = [_squash(p) for p in problems if _squash(p)]
    return f"STATUS: fallback: {'; '.join(reasons)}" if reasons else "STATUS: ok"


def _assemble(facts: Facts, body_limit: int) -> list[str]:
    lines = [
        VERSION_LINE,
        f"PROJECT_ROOT: {_one_line(facts.root)}",
        f"CHECKPOINT_PATH: {_one_line(facts.checkpoint_path)}",
    ]
    lines.append(f"PLAN: {_one_line(facts.plan) if facts.plan else 'none'}")
    lines.extend(_git_block(facts.git_status, facts.git_reason))
    if facts.manifest_stem:
        lines.append(f"MANIFEST_RESOLVE: {_one_line(facts.manifest_stem)}")
    else:
        lines.append(f"MANIFEST_RESOLVE: refused: {quote(facts.manifest_refusal)}")
    if facts.pr_ref:
        lines.append(f"PR_REF: {_one_line(facts.pr_ref)} {_one_line(facts.pr_url)}")
    else:
        lines.append(f"PR_REF: none: {quote(facts.pr_reason)}")
    lines.extend(_prefer_lines(facts.prefer))
    by_hook = {e.hook: e for e in facts.extensions}
    for hook in HOOKS:
        lines.extend(_extension_lines(by_hook.get(hook, Extension(hook=hook)), body_limit))
    lines.append(_status_line(facts.problems))
    return lines


def _whole_lines(text: str) -> str:
    """`text` up to and including its last newline, so a cut never leaves half a line."""
    return text[: text.rfind("\n") + 1]


def _hard_cap(lines: list[str]) -> str:
    """The final guarantee: the document is at most `MAX_OUTPUT_BYTES`, ending in its STATUS line."""
    text = "\n".join(lines) + "\n"
    if len(text.encode("utf-8", errors="replace")) <= MAX_OUTPUT_BYTES:
        return text
    tail = f"[TRUNCATED: document cut at {MAX_OUTPUT_BYTES} bytes]\n{lines[-1]}\n"
    room = MAX_OUTPUT_BYTES - len(tail.encode("utf-8", errors="replace"))
    head = _whole_lines(_cut_bytes("\n".join(lines[:-1]) + "\n", max(room, 0)))
    return _cut_bytes(head + tail, MAX_OUTPUT_BYTES)


def render(facts: Facts) -> str:
    """The whole document, newline-terminated, at most `MAX_OUTPUT_BYTES`.

    Bodies are cut at `MAX_BODY_BYTES` first. Six bodies at that size would still overshoot the total cap, so the
    body limit halves until the document fits (down to zero, which leaves only the markers); `_hard_cap` then
    covers whatever is left, which can only be non-body input of pathological size.
    """
    limit = MAX_BODY_BYTES
    while True:
        lines = _assemble(facts, limit)
        fits = len(("\n".join(lines) + "\n").encode("utf-8", errors="replace")) <= MAX_OUTPUT_BYTES
        if fits or limit == 0:
            break
        limit = limit // 2 if limit >= 64 else 0
    return _hard_cap(lines)


def skeleton(reason: str) -> str:
    """A complete document that knows nothing, for when even gathering the facts failed."""
    return render(Facts(problems=(reason,)))


def first_free_path(root: str, stem: str, exists: Callable[[str], bool]) -> str:
    """`<root>/.borg/checkpoints/<stem>.md`, advanced to `<stem>-2.md`, `-3`, ... until `exists` says it is free.

    The skill's existence loop, moved to the host so the printed path is already the one to write. `exists` is a
    parameter so the loop is pinnable with a fake set. Bounded: a directory that claims every name is an error the
    caller turns into a fallback, not a reason to spin.
    """
    directory = f"{root.rstrip('/')}/.borg/checkpoints"
    path = f"{directory}/{stem}.md"
    suffix = 2
    while exists(path):
        if suffix > MAX_COLLISION_SUFFIX:
            raise ValueError(f"no free checkpoint name for {stem} after {MAX_COLLISION_SUFFIX} tries")
        path = f"{directory}/{stem}-{suffix}.md"
        suffix += 1
    return path
