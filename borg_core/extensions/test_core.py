"""Oracles for the pure extension core.

Every behaviour is pinned in the firing direction AND the direction that proves it discriminates,
because the defect this whole feature guards against is a mechanism that reports success while
measuring nothing.
"""

from __future__ import annotations

import ast
from pathlib import Path

from borg_core.extensions import core


# ── purity ───────────────────────────────────────────────────────────────────────────────────────

def test_core_imports_nothing_impure():
    """The clean-architecture linter classifies by BASENAME and its W9004 allow-list permits
    `pathlib`, `json` and `datetime` -- so it would wave through a filesystem import into this
    module while `make lint` printed 10.00/10. This pins an exact set of top-level import ROOTS,
    which is the narrower claim the linter cannot make, and it catches the aliased spelling
    (`from pathlib import Path as P`) that a name blacklist misses.
    """
    tree = ast.parse(Path(core.__file__).read_text(encoding="utf-8"))
    roots = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            roots.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            roots.add(node.module.split(".")[0])
    assert roots == {"__future__"}, f"core.py grew an impure import: {sorted(roots)}"


# ── parse ────────────────────────────────────────────────────────────────────────────────────────

def test_a_file_with_no_prefer_tool_key_is_prose():
    """Every extension that exists today is plain prose. They must parse unchanged -- this type is
    additive, so no existing artifact is read by rules it was not written to satisfy."""
    parsed = core.parse("Ask which JIRA ticket this work targets, then read it.")
    assert parsed["type"] == core.TYPE_PROSE
    assert parsed["prefer"] == ""
    assert parsed["body"] == "Ask which JIRA ticket this work targets, then read it."


def test_prefer_tool_keys_are_parsed_and_backticks_stripped():
    parsed = core.parse(
        "- Prefer-tool: `dev-workflow:create-pr`\n"
        "- Instead-of: `gh pr create`\n"
        "- Requires: skill:dev-workflow:create-pr\n"
        "\nDelegate PR creation.\n"
    )
    assert parsed["type"] == core.TYPE_PREFER_TOOL
    assert parsed["prefer"] == "dev-workflow:create-pr"
    assert parsed["instead_of"] == "gh pr create"
    assert parsed["requires"] == "skill:dev-workflow:create-pr"
    assert parsed["body"] == "Delegate PR creation."


def test_prose_discussing_a_key_does_not_become_the_value():
    """An extension file is prose that will often DISCUSS its own keys. Unanchored matching returns
    the sentence doing the discussing -- the same hazard that bit Step 0.75's sibling annotation.
    Verified by mutation: dropping the `- ` anchor in `_key` makes this return the sentence."""
    parsed = core.parse(
        "This file explains that Prefer-tool: is how a preference is declared.\n"
        "- Prefer-tool: the-real-tool\n"
    )
    assert parsed["prefer"] == "the-real-tool"


def test_a_restated_key_cannot_override_the_header():
    parsed = core.parse("- Prefer-tool: first\n- Prefer-tool: second\n")
    assert parsed["prefer"] == "first"


# ── precedence: "the layer that owns the fact wins" ──────────────────────────────────────────────

def test_prose_precedence_is_unchanged_repository_wins():
    layers = {core.MACHINE: {"type": core.TYPE_PROSE}, core.REPOSITORY: {"type": core.TYPE_PROSE}}
    assert core.winner(layers) == core.REPOSITORY


def test_prefer_tool_inverts_it_machine_wins():
    """A public repository cannot know what is installed on this machine, and this one was scrubbed
    once already to remove employer references. A checked-in file must not override a personal
    machine's tool choice."""
    layers = {
        core.MACHINE: {"type": core.TYPE_PREFER_TOOL, "prefer": "employer-plugin:create-pr"},
        core.REPOSITORY: {"type": core.TYPE_PREFER_TOOL, "prefer": "gh"},
    }
    assert core.winner(layers) == core.MACHINE


def test_one_layer_present_wins_regardless_of_type():
    assert core.winner({core.REPOSITORY: {"type": core.TYPE_PREFER_TOOL}}) == core.REPOSITORY
    assert core.winner({core.MACHINE: {"type": core.TYPE_PROSE}}) == core.MACHINE


def test_no_layers_is_empty_not_a_default():
    assert core.winner({}) == ""


# ── conflict reporting ───────────────────────────────────────────────────────────────────────────

def test_same_key_in_both_layers_is_a_conflict():
    layers = {
        core.MACHINE: {"type": core.TYPE_PREFER_TOOL, "prefer": "a"},
        core.REPOSITORY: {"type": core.TYPE_PREFER_TOOL, "prefer": "b"},
    }
    assert core.conflicted(layers) is True


def test_different_keys_are_layering_not_conflict():
    """Two layers asserting different keys is the mechanism working as designed. Reporting it would
    make the loader chatty on every skill invocation, against the standing terseness rule."""
    layers = {
        core.MACHINE: {"type": core.TYPE_PREFER_TOOL, "prefer": "a"},
        core.REPOSITORY: {"type": core.TYPE_PREFER_TOOL, "instead_of": "gh pr create"},
    }
    assert core.conflicted(layers) is False


def test_one_layer_cannot_conflict_with_itself():
    assert core.conflicted({core.MACHINE: {"prefer": "a"}}) is False


# ── requirement parsing ──────────────────────────────────────────────────────────────────────────

def test_both_requirement_kinds_parse():
    assert core.requirement({"requires": "command:gh"}) == ("command", "gh")
    assert core.requirement({"requires": "skill:dev-workflow:create-pr"}) == (
        "skill", "dev-workflow:create-pr")


def test_an_unrecognized_or_malformed_requirement_is_empty_not_an_exception():
    """A preference this machine cannot even parse is a dead preference, not a crash -- the caller's
    contract is to degrade to the default."""
    for raw in ("", "nonsense", "wat:thing", "command:", ":gh"):
        assert core.requirement({"requires": raw}) == ("", ""), raw


# ── liveness ─────────────────────────────────────────────────────────────────────────────────────

def test_status_reports_live_and_dead_from_the_probe():
    parsed = {"type": core.TYPE_PREFER_TOOL}
    assert core.status(parsed, True) == "live"
    assert core.status(parsed, False) == "dead"


def test_a_prefer_tool_with_no_checkable_requirement_is_unprobed_NOT_live():
    """The whole point of `- Requires:` is that absence has to be checkable. A file that omits it
    has opted out of being checked and must not be reported as working -- that is the silent-success
    failure this type exists to avoid."""
    assert core.status({"type": core.TYPE_PREFER_TOOL}, None) == "unprobed"


def test_prose_extensions_are_not_graded():
    assert core.status({"type": core.TYPE_PROSE}, None) == "n/a"
