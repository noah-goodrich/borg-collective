"""Direct tests for borg_core.timefmt — added with iso_in_prose_to_utc (opus round-3 finding 4).

Every earlier exercise of this function ran through recon's dedup_cross_source, which never reaches
the unparseable-timestamp branch; per the repo's own rule, tests drive the real branches directly.
"""

from borg_core import timefmt


class TestIsoInProseToUtc:
    def test_extracts_and_normalizes_a_z_timestamp_from_prose(self):
        assert timefmt.iso_in_prose_to_utc("updated 2026-08-21T23:00:00Z; state=open") == "2026-08-21T23:00:00+00:00"

    def test_an_offset_timestamp_normalizes_to_utc(self):
        # -07:00 17:30 is 00:30Z next day — the whole point of normalizing before comparing.
        assert timefmt.iso_in_prose_to_utc("2026-08-21T17:30:00-07:00") == "2026-08-22T00:30:00+00:00"

    def test_a_naive_timestamp_is_taken_as_utc(self):
        assert timefmt.iso_in_prose_to_utc("2026-08-21T10:00:00") == "2026-08-21T10:00:00+00:00"

    def test_no_timestamp_in_text_returns_empty(self):
        assert timefmt.iso_in_prose_to_utc("no dates here") == ""

    def test_a_regex_matching_but_unparseable_timestamp_returns_empty(self):
        # Matches _ISO_IN_PROSE's shape but is not a real datetime — must sort oldest, never raise.
        assert timefmt.iso_in_prose_to_utc("2026-13-45T99:99:99") == ""

    def test_fractional_seconds_survive_normalization(self):
        got = timefmt.iso_in_prose_to_utc("2026-08-21T10:00:00.500000Z")
        assert got.startswith("2026-08-21T10:00:00.5")


def test_epoch_to_iso_round_trip_shape():
    assert timefmt.epoch_to_iso(1704171845) == "2024-01-02T05:04:05Z"
