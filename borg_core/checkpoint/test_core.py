"""Unit tests for the pure checkpoint-name logic."""

from datetime import datetime

import pytest

from borg_core.checkpoint import core
from borg_core.link import core as link_core


def test_stem_is_second_resolution_with_a_session_tag():
    moment = datetime(2026, 9, 28, 16, 4, 32)
    assert core.checkpoint_stem(moment, "3b0f70") == "2026-09-28-160432-3b0f70"


def test_stem_degrades_to_the_timestamp_when_there_is_no_session():
    moment = datetime(2026, 9, 28, 16, 4, 32)
    assert core.checkpoint_stem(moment, "") == "2026-09-28-160432"


def test_two_sessions_in_the_same_second_get_different_stems():
    # THE COLLISION THIS EXISTS TO CLOSE. Same repo, same second, two sessions -- which is what
    # happened on the live registry, twice, inside the same minute.
    moment = datetime(2026, 9, 25, 17, 4, 11)
    first = core.checkpoint_stem(moment, core.short_suffix("3b0f70ca-74cd-4cbf-bac3-8ca94764cf41"))
    second = core.checkpoint_stem(moment, core.short_suffix("a67b27b6-a11d-fbf7-d000-000000000000"))
    assert first != second


def test_short_suffix_is_traceable_to_its_session():
    # A tag rather than randomness, so a bylined duplicate pair on a `borg link` page can be traced
    # back to the sessions that wrote it.
    assert core.short_suffix("3b0f70ca-74cd-4cbf-bac3-8ca94764cf41") == "3b0f70"


@pytest.mark.parametrize(
    "hostile",
    ["../../etc/passwd", "a/b/c", "  spaces  ", "UPPER-CASE-ID", "!!!", "\n\t"],
)
def test_short_suffix_cannot_produce_a_path_or_a_surprise(hostile):
    # The value arrives from the environment and must not be trusted. Whatever it is, the tag is
    # alphanumeric, lowercase, and short -- so it can never escape the checkpoints directory.
    suffix = core.short_suffix(hostile)
    assert suffix.isalnum() or suffix == ""
    assert len(suffix) <= core.SUFFIX_LENGTH
    assert "/" not in suffix and suffix == suffix.lower()


def test_short_suffix_is_empty_for_an_empty_session():
    assert core.short_suffix("") == ""


# ── Sort safety against the 120 legacy names already on disk ─────────────────
#
# borg_core.link.core.order_checkpoints sorts by NAME descending, deliberately (a fresh clone gives
# every file the same mtime). So a new format that sorted wrongly against the legacy
# YYYY-MM-DD-HHMM shape would silently reorder history. These pin both directions.


def test_new_stem_sorts_after_an_earlier_legacy_minute():
    rows = [("2026-09-28-1603.md", "p"), ("2026-09-28-160432-3b0f70.md", "p")]
    assert [name for name, _ in link_core.order_checkpoints(rows)][0] == "2026-09-28-160432-3b0f70.md"


def test_new_stem_sorts_before_a_later_legacy_minute():
    # The subtle direction: "1605" vs "160432" compare at the 4th character, where '4' < '5'.
    rows = [("2026-09-28-1605.md", "p"), ("2026-09-28-160432-3b0f70.md", "p")]
    assert [name for name, _ in link_core.order_checkpoints(rows)][0] == "2026-09-28-1605.md"


def test_a_legacy_name_sorts_first_among_names_sharing_its_minute():
    # "1604" is a prefix of "160432", so the legacy name is the older of the two. Chronologically
    # it is ambiguous -- 16:04 could be any second -- but the order must at least be STABLE.
    rows = [("2026-09-28-160432-3b0f70.md", "p"), ("2026-09-28-1604.md", "p")]
    assert [name for name, _ in link_core.order_checkpoints(rows)] == [
        "2026-09-28-160432-3b0f70.md",
        "2026-09-28-1604.md",
    ]


def test_mixed_legacy_and_new_names_order_chronologically_across_a_day():
    rows = [
        ("2026-09-28-0900.md", "p"),
        ("2026-09-28-120000-aaaaaa.md", "p"),
        ("2026-09-28-1130.md", "p"),
        ("2026-09-28-235959-ffffff.md", "p"),
    ]
    assert [name for name, _ in link_core.order_checkpoints(rows)] == [
        "2026-09-28-235959-ffffff.md",
        "2026-09-28-120000-aaaaaa.md",
        "2026-09-28-1130.md",
        "2026-09-28-0900.md",
    ]
