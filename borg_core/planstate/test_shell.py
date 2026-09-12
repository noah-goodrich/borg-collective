"""The I/O layer's degradation branches, which the end-to-end cases above never reach.

Each one is a rung on the "nothing here is ever fatal" ladder `shell.py`'s header promises, and each
is the shape CLAUDE.md's "Learned" records as shipping SILENT: an empty environment variable that
becomes `float("")`, a kind with no runner, a write that cannot complete.
"""

from __future__ import annotations

import json
import os

import pytest

from borg_core.planstate import shell


@pytest.mark.parametrize(
    "raw,expected",
    [
        (None, shell.DEFAULT_SUITE_TIMEOUT_SECONDS),
        ("", shell.DEFAULT_SUITE_TIMEOUT_SECONDS),
        ("not-a-number", shell.DEFAULT_SUITE_TIMEOUT_SECONDS),
        ("12.5", 12.5),
    ],
)
def test_suite_timeout_survives_unset_empty_and_garbage(raw, expected, monkeypatch):
    # `_borg_py` passes its whole config surface through by name and an unset variable arrives as
    # the EMPTY STRING -- the exact `int("")` bug that made `borg recon` non-functional.
    if raw is None:
        monkeypatch.delenv("BORG_PLANSTATE_SUITE_TIMEOUT", raising=False)
    else:
        monkeypatch.setenv("BORG_PLANSTATE_SUITE_TIMEOUT", raw)
    assert shell.suite_timeout() == expected


def test_run_suite_returns_none_for_a_kind_with_no_runner(tmp_path):
    # Unreachable through `derive` (the validator closes on the four kinds first), which is exactly
    # why it is asserted here: a fifth kind added to `core._KINDS` without a runner must degrade to
    # `unknown`, not raise KeyError out of the module.
    assert shell.run_suite(tmp_path, "make", "Makefile") is None


def test_pr_state_reads_a_real_fetch_result_and_not_a_hand_built_dict(tmp_path, monkeypatch):
    """The translation `core.verdict_for_pr` used to do itself, pinned against the layout
    `link.shell.finish_fetch` ACTUALLY produces.

    A hand-built `{"attempted": True, "items": {...}}` here would be the
    `reference_test_supplies_derived_value` shape: it would keep passing after `link.shell` renamed
    `items`, which is the exact silent downgrade -- every `pr:` criterion `unknown` forever -- that
    moving this reach out of the pure module is for. So the dict comes from `resolve_prs`, through
    the repository's own recorded-answer seam."""
    recording = tmp_path / "fetch.json"
    recording.write_text(json.dumps({"nodes": {"o/r#42": {"state": "MERGED"}}}), encoding="utf-8")
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(recording))

    fetch = shell.resolve_prs(["o/r#42"])
    assert shell.pr_state(fetch, "o/r#42") == (True, "merged")
    # Answered for, but nothing held: "looked, learned nothing", which is not the same as "could
    # not look" and must not collapse into it.
    assert shell.pr_state(fetch, "o/r#99") == (True, None)


def test_pr_state_reports_an_unasked_or_failed_source_as_not_looked(tmp_path, monkeypatch):
    monkeypatch.setenv("BORG_LINK_FETCH_FIXTURE", str(tmp_path / "no-such-recording.json"))
    assert shell.pr_state(shell.resolve_prs(["o/r#42"]), "o/r#42") == (False, None)
    # No refs at all never asks, so it is `attempted: False` too -- the early return in `resolve_prs`.
    assert shell.pr_state(shell.resolve_prs([]), "o/r#42") == (False, None)


def test_read_text_returns_none_for_a_file_that_is_not_there(tmp_path):
    assert shell.read_text(tmp_path / "absent.md") is None


def test_write_atomic_cleans_up_its_tmp_file_when_the_write_fails(tmp_path, monkeypatch):
    target = tmp_path / "plan.md"
    target.write_text("original\n", encoding="utf-8")

    def _boom(src, dst):
        raise OSError("no rename today")

    monkeypatch.setattr(os, "replace", _boom)
    with pytest.raises(OSError):
        shell.write_atomic(target, "replacement\n")
    assert target.read_text(encoding="utf-8") == "original\n"
    assert [entry.name for entry in tmp_path.iterdir() if entry.name.startswith(".planstate-")] == []
