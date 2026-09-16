"""PURE extension logic: layer precedence, `prefer-tool` parsing, and liveness.

No I/O of any kind -- no filesystem, no subprocess, no environment, no clock. Callers hand this
module text that someone else read and paths that someone else discovered. `shell.py` owns every
impure rung, and `borg_core/extensions/test_core.py` pins the purity by AST import walk rather than
trusting the clean-architecture linter, which classifies by basename and whose W9004 allow-list
already permits `pathlib`, `json` and `datetime`.

THE PRECEDENCE RULE IS "THE LAYER THAT OWNS THE FACT WINS", and it is one rule rather than a
per-type exception so that a reader can predict what a file does without knowing its type:

    prose extensions      -> the REPO layer wins. It asserts project policy ("plans here cite a
                             ticket"), the project owns that, and it should bind everyone who works
                             on the project. This is the pre-existing behaviour, unchanged: both
                             layers are read in order and the later one extends or overrides.
    prefer-tool extensions -> the MACHINE layer wins. It asserts something about the environment
                             ("this machine creates PRs via X"). A repository cannot know what is
                             installed on a given machine, and `borg-collective` is public and has
                             already been history-scrubbed once to remove employer references -- so
                             a checked-in file must never override a personal machine's tool choice.

Both rows are the same rule applied to different subjects. A future type inherits it by answering
one question: who owns the fact being asserted?
"""

from __future__ import annotations

# The three prose load points, in the order both existing consumers read them.
PROSE_HOOKS = ("01-context", "02-output", "03-followup")

# Layer names, ordered machine-first because that is the read order for prose.
MACHINE = "machine"
REPOSITORY = "repository"
LAYERS = (MACHINE, REPOSITORY)

# The keys a `prefer-tool` extension declares. `Prefer-tool` is what makes a file this type at all.
KEY_PREFER = "Prefer-tool"
KEY_INSTEAD_OF = "Instead-of"
KEY_REQUIRES = "Requires"

TYPE_PROSE = "prose"
TYPE_PREFER_TOOL = "prefer-tool"


def _key(line: str, name: str) -> str:
    """The value of a `- <name>: <value>` line, or "" when this line is not that key.

    Anchored on the leading `- ` deliberately. The same hazard that bit Step 0.75's sibling
    annotation applies here: an extension file is prose that will often DISCUSS its own keys, and an
    unanchored match returns the sentence doing the discussing. Backticks are stripped because the
    repository's own `- Plan-slug:` convention wraps values in them.
    """
    prefix = f"- {name}:"
    if not line.startswith(prefix):
        return ""
    value = line[len(prefix):].strip()
    if len(value) >= 2 and value.startswith("`") and value.endswith("`"):
        value = value[1:-1].strip()
    return value


def parse(text: str) -> dict:
    """Parse an extension file's declared keys out of its prose.

    Returns `{"type", "prefer", "instead_of", "requires"}`. A file with no `- Prefer-tool:` line is
    `prose` and carries no keys -- which is every extension that exists today, so the pre-existing
    files parse unchanged and need no migration.

    Only the FIRST occurrence of each key is taken, so a file that restates a key in its explanatory
    prose cannot override its own header.

    The body is deliberately NOT returned. It was, and nothing read it: the row `shell.survey` builds
    never carried it and neither CLI verb referenced it, so it was a field whose "first occurrence
    wins, restatements excluded" semantics had to be kept correct for no consumer. If an audit
    surface ever needs the prose, it can be added in the commit that needs it.
    """
    found: dict[str, str] = {}
    for line in text.splitlines():
        for name in (KEY_PREFER, KEY_INSTEAD_OF, KEY_REQUIRES):
            value = _key(line, name)
            if not value:
                continue
            found.setdefault(name, value)
            break
    return {
        "type": TYPE_PREFER_TOOL if KEY_PREFER in found else TYPE_PROSE,
        "prefer": found.get(KEY_PREFER, ""),
        "instead_of": found.get(KEY_INSTEAD_OF, ""),
        "requires": found.get(KEY_REQUIRES, ""),
    }


def _present(layers: dict) -> list[str]:
    """The layer names that actually have a parsed file, in read order.

    Shared by `winner` and `conflicted` because both are called on the same dict by the same caller
    and each used to re-derive this list. One definition means a third layer cannot be added to one
    and forgotten in the other.
    """
    return [name for name in LAYERS if layers.get(name)]


def winner(layers: dict) -> str:
    """Which layer's value applies, given `{layer: parsed}` for the layers that exist.

    Returns the layer name, or "" when neither layer has a file. The rule is the module docstring's:
    a `prefer-tool` assertion is owned by the machine, anything else by the repository.
    """
    present = _present(layers)
    if not present:
        return ""
    if len(present) == 1:
        return present[0]
    types = {layers[name].get("type") for name in present}
    if TYPE_PREFER_TOOL in types:
        return MACHINE
    return REPOSITORY


def conflicted(layers: dict) -> bool:
    """True when both layers assert the SAME key, so one of them is being overridden.

    Reported once by the caller rather than on every read: these files load on every skill
    invocation and the standing rule is that they stay terse. Two layers that assert DIFFERENT keys
    are layering as designed and are not a conflict.
    """
    present = _present(layers)
    if len(present) < 2:
        return False
    keys = []
    for name in present:
        parsed = layers[name]
        keys.append({k for k in ("prefer", "instead_of", "requires") if parsed.get(k)})
    return bool(keys[0] & keys[1])


def requirement(parsed: dict) -> tuple[str, str]:
    """Split a `- Requires:` value into `(kind, target)`; `("", "")` when absent or malformed.

    Two kinds, both cheap to probe: `command:<name>` and `skill:<plugin>:<name>`. An unrecognized
    kind returns empty rather than raising, because the caller's contract is to degrade to the
    default -- a preference this machine cannot even parse is a dead preference, not a crash.
    """
    raw = (parsed.get("requires") or "").strip()
    if ":" not in raw:
        return ("", "")
    split_at = raw.index(":")
    kind = raw[:split_at].strip().lower()
    target = raw[split_at + 1:].strip()
    if kind not in ("command", "skill") or not target:
        return ("", "")
    return (kind, target)


def status(parsed: dict, satisfied: bool | None) -> str:
    """The extension's liveness: `live`, `dead`, `unprobed`, or `n/a`.

    `satisfied` is what `shell.probe` returned -- `None` when there was nothing probeable. A
    `prefer-tool` extension with no parseable requirement is `unprobed`, NOT live: the whole point
    of the `- Requires:` line is that absence has to be checkable, so a file that omits it has opted
    out of being checked and must not be reported as working.
    """
    if parsed.get("type") != TYPE_PREFER_TOOL:
        return "n/a"
    if satisfied is None:
        return "unprobed"
    return "live" if satisfied else "dead"
