"""The overlay entry point prints exactly what `borg link` builds its view from."""

import json

from borg_core.link import overlay, shell


def test_main_prints_the_link_overlay_as_json(monkeypatch, capsys):
    doc = {"projects": {"a": {"status": "waiting", "path": "/x"}}}
    monkeypatch.setattr(shell, "registry_with_state", lambda: doc)
    assert overlay.main() == 0
    assert json.loads(capsys.readouterr().out) == doc
