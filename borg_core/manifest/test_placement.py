"""Tests for `placement.choose_scaffold_root`, the pure decision behind `scaffold`."""

from __future__ import annotations

import pytest

from borg_core.manifest import placement

# ── choose_scaffold_root: where scaffold creates a NEW manifest ──────────────────────────────────
_S = "/r/.stacks"


def _choose(override="", stacks=False, stacks_ignored=False):
    return placement.choose_scaffold_root(override, stacks, _S, stacks_ignored)


@pytest.mark.parametrize(
    "kwargs",
    [{}, {"stacks": True}, {"override": "stacks"}, {"override": "stacks", "stacks": True}, {"override": "bogus"}],
)
def test_choose_scaffold_root_always_answers_the_stacks_directory(kwargs):
    """There is ONE root: every outcome is `.stacks/`, whatever else is true. An override that names nothing
    known falls through to the derived rules rather than becoming a crash, since the CLI rejects it first.

    MUTATION: return any other directory from a rule and its case goes red.
    """
    assert _choose(**kwargs)[0] == _S


def test_choose_scaffold_root_names_a_distinct_reason_for_every_outcome():
    reasons = [_choose(override="stacks")[1], _choose(stacks=True)[1], _choose()[1]]
    assert all(reasons) and len(set(reasons)) == len(reasons)
    assert "--root" in reasons[0] and "already exists" in reasons[1] and reasons[2] == "default"


@pytest.mark.parametrize("kwargs", [{}, {"stacks": True}, {"override": "stacks"}])
def test_choose_scaffold_root_refuses_a_stacks_dir_git_ignores(kwargs):
    """Every route to `.stacks/` refuses by name when git would ignore it -- never a silent fallback, and there is
    no second root to fall back to."""
    with pytest.raises(placement.StacksIgnored) as caught:
        _choose(stacks_ignored=True, **kwargs)
    message = str(caught.value)
    assert _S in message and "ignores" in message and "--root borg" not in message


def test_the_retired_borg_root_is_not_a_choice_and_its_refusal_names_the_way_forward():
    """`--root borg` is parsed only to be refused: it is not among the choices, and the message points at `.stacks/`
    and at the migration for manifests that never moved."""
    assert placement.ROOT_BORG not in placement.ROOT_CHOICES
    assert "--root borg" in placement.BORG_ROOT_REFUSAL
    assert ".stacks/" in placement.BORG_ROOT_REFUSAL and "borg stack migrate" in placement.BORG_ROOT_REFUSAL
