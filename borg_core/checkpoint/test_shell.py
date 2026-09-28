"""Tests for the two ambient reads: the clock and the session identity."""

from borg_core.checkpoint import core, shell


def test_session_id_reads_the_claude_code_variable(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "3b0f70ca-74cd-4cbf-bac3-8ca94764cf41")
    assert shell.session_id() == "3b0f70ca-74cd-4cbf-bac3-8ca94764cf41"


def test_session_id_is_empty_when_unset(monkeypatch):
    # A bare terminal and a Cortex Code session are SUPPORTED states, not errors.
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    assert shell.session_id() == ""


def test_stem_carries_the_session_tag_when_one_is_available(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "3b0f70ca-74cd-4cbf-bac3-8ca94764cf41")
    assert shell.checkpoint_stem().endswith("-3b0f70")


def test_stem_degrades_without_a_session_and_stays_well_formed(monkeypatch):
    monkeypatch.delenv("CLAUDE_CODE_SESSION_ID", raising=False)
    stem = shell.checkpoint_stem()
    assert len(stem) == len("2026-09-28-160432")
    assert stem.count("-") == 3


def test_repeated_calls_in_one_session_are_stable_in_shape(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "deadbeef-0000-0000-0000-000000000000")
    stems = [shell.checkpoint_stem() for _ in range(5)]
    assert all(s.endswith("-deadbe") for s in stems)
    assert all(len(s) == len("2026-09-28-160432-deadbe") for s in stems)


def test_suffix_length_is_the_module_constant(monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_SESSION_ID", "abcdefghijklmnop")
    assert shell.checkpoint_stem().split("-")[-1] == "abcdef"
    assert core.SUFFIX_LENGTH == 6
