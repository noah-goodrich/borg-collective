"""Tests for `placement.choose_scaffold_root`, the pure decision behind `scaffold`."""

from __future__ import annotations

import pytest

from borg_core.manifest import placement


# ── choose_scaffold_root: where scaffold creates a NEW manifest ──────────────────────────────────
_S, _B = "/r/.stacks", "/r/.borg/chains"


def _choose(override="", stacks=False, borg=False, ignored=False, stacks_ignored=False):
    return placement.choose_scaffold_root(override, stacks, borg, ignored, (_S, _B), stacks_ignored)


@pytest.mark.parametrize(
    "kwargs,expected",
    [
        ({"override": "stacks"}, _S),
        ({"override": "stacks", "borg": True}, _S),
        ({"override": "borg"}, _B),
        ({"override": "borg", "stacks": True}, _B),
        ({"override": "borg", "ignored": True}, _B),
        ({"override": "borg", "stacks_ignored": True}, _B),
        ({"stacks": True, "borg": True}, _S),
        ({"stacks": True, "ignored": True}, _S),
        ({"borg": True, "ignored": True}, _S),
        ({"borg": True}, _S),
        ({"ignored": True}, _S),
        ({}, _S),
    ],
)
def test_choose_scaffold_root_first_match_wins(kwargs, expected):
    assert _choose(**kwargs)[0] == expected


def test_choose_scaffold_root_only_the_borg_override_returns_borgs_own_root():
    """MUTATION: restore the pre-expand `return borg_path` in any derived rule and its case goes red."""
    derived = [{}, {"stacks": True}, {"borg": True}, {"ignored": True}, {"stacks": True, "borg": True}]
    assert {_choose(**kwargs)[0] for kwargs in derived} == {_S}
    assert _choose(override="borg")[0] == _B


def test_choose_scaffold_root_names_a_reason_for_every_rule():
    reasons = [
        _choose(override="stacks")[1], _choose(override="borg")[1], _choose(stacks=True)[1],
        _choose(borg=True)[1], _choose(ignored=True)[1], _choose()[1],
    ]
    assert all(reasons) and len(set(reasons)) == len(reasons)
    assert "--root" in reasons[0] and "ignores" in reasons[4]
    assert "still read" in reasons[3]


@pytest.mark.parametrize(
    "kwargs",
    [{}, {"stacks": True}, {"borg": True}, {"ignored": True}, {"override": "stacks"}],
)
def test_choose_scaffold_root_refuses_a_stacks_dir_git_ignores(kwargs):
    """Every route to `.stacks/` refuses by name when git would ignore it -- never a silent fallback."""
    with pytest.raises(placement.StacksIgnored) as caught:
        _choose(stacks_ignored=True, **kwargs)
    assert _S in str(caught.value) and "--root borg" in str(caught.value) and "ignores" in str(caught.value)


def test_choose_scaffold_root_unknown_override_falls_through_to_the_derived_rules():
    assert _choose(override="bogus", ignored=True)[0] == _S
