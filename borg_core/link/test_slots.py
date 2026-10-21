"""share_slots: one pick per group per round, shown in the existing order."""

from __future__ import annotations

from borg_core.link import slots


def _rows(*groups: str) -> list[dict]:
    return [{"g": group, "n": index} for index, group in enumerate(groups)]


def test_share_slots_takes_turns_between_groups_and_keeps_the_original_order():
    rows = _rows("a", "a", "a", "a", "b", "b")
    assert [r["n"] for r in slots.share_slots(rows, 4, "g")] == [0, 1, 4, 5]


def test_share_slots_one_group_is_the_first_n_and_a_short_group_gives_turns_back():
    assert [r["n"] for r in slots.share_slots(_rows("a", "a", "a"), 2, "g")] == [0, 1]
    assert [r["n"] for r in slots.share_slots(_rows("a", "a", "a", "b"), 3, "g")] == [0, 1, 3]


def test_share_slots_zero_limit_and_empty_input_give_nothing():
    assert slots.share_slots(_rows("a"), 0, "g") == [] and slots.share_slots([], 5, "g") == []
