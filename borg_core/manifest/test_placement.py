"""Tests for `placement.choose_scaffold_root`, the pure decision behind `scaffold`."""

from __future__ import annotations

import pytest

from borg_core.manifest import placement


# ── choose_scaffold_root: where scaffold creates a NEW manifest ──────────────────────────────────
_S, _B = "/r/.stacks", "/r/.borg/chains"


def _choose(override="", stacks=False, borg=False, ignored=False):
    return placement.choose_scaffold_root(override, stacks, borg, ignored, (_S, _B))


@pytest.mark.parametrize(
    "kwargs,expected",
    [
        ({"override": "stacks"}, _S),
        ({"override": "stacks", "borg": True}, _S),
        ({"override": "borg", "stacks": True}, _B),
        ({"override": "borg", "ignored": True}, _B),
        ({"stacks": True, "borg": True}, _S),
        ({"stacks": True, "ignored": True}, _S),
        ({"borg": True, "ignored": True}, _B),
        ({"borg": True}, _B),
        ({"ignored": True}, _S),
        ({}, _B),
    ],
)
def test_choose_scaffold_root_first_match_wins(kwargs, expected):
    assert _choose(**kwargs)[0] == expected


def test_choose_scaffold_root_names_a_reason_for_every_rule():
    reasons = [
        _choose(override="stacks")[1], _choose(override="borg")[1], _choose(stacks=True)[1],
        _choose(borg=True)[1], _choose(ignored=True)[1], _choose()[1],
    ]
    assert all(reasons) and len(set(reasons)) == len(reasons)
    assert "--root" in reasons[0] and "ignores" in reasons[4]


def test_choose_scaffold_root_unknown_override_falls_through_to_the_derived_rules():
    assert _choose(override="bogus", ignored=True)[0] == _S
