"""S4 acceptance tests: the committed program manifests in THIS repo are valid, discoverable,
versionable, and derive edges.

S4 (comms-delivery-surfaces AC4) lands hand-authored manifests in their owning repos. These tests
gate that landing: they run in CI against whatever `.borg/programs/*.json` this repo carries, so a
future manifest that is malformed, misnamed, or silently ignored fails the build instead of failing
the chain map. The cross-repo + skill-consumption half (K3/AC3) lives in evals/s4-k3/ — it needs
live refs and a model run, so it is on-demand, not CI.
"""

from __future__ import annotations

import json
import os
import re
import subprocess

import programs

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROGRAMS_DIR = os.path.join(REPO_ROOT, ".borg", "programs")

SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
FULL_REF_RE = re.compile(r"^[\w.-]+/[\w.-]+#\d+$")


def _manifest_paths() -> list[str]:
    if not os.path.isdir(PROGRAMS_DIR):
        return []
    return sorted(os.path.join(PROGRAMS_DIR, n) for n in os.listdir(PROGRAMS_DIR) if n.endswith(".json"))


def _load(path: str) -> dict:
    with open(path) as fh:
        return json.load(fh)


def test_this_repo_declares_at_least_one_program():
    # S4's point: the declaration surface must not be empty in the repo that owns viz-program.
    assert _manifest_paths(), f"no manifests under {PROGRAMS_DIR} — S4 not landed"


def test_every_manifest_validates_clean():
    for path in _manifest_paths():
        errors = programs.validate(_load(path))
        assert errors == [], f"{os.path.basename(path)}: {errors}"


def test_program_id_matches_filename_and_is_a_slug():
    # Lifecycle naming rule: the id IS user-facing (it becomes the project id in every view), so it
    # is a kebab-case slug, and the filename tracks it so discovery and humans agree on the name.
    for path in _manifest_paths():
        stem = os.path.splitext(os.path.basename(path))[0]
        program = str(_load(path).get("program") or "")
        assert program == stem, f"{os.path.basename(path)}: program {program!r} != filename stem"
        assert SLUG_RE.match(program), f"{program!r} is not a kebab-case slug"


def test_every_row_ref_is_full_form():
    # Full owner/repo#num refs are self-addressing (the gp keymap, chain renderers, dedup) — the
    # short form has no owner and cannot be resolved off-machine.
    for path in _manifest_paths():
        doc = _load(path)
        refs = [r.get("ref", "") for r in doc.get("rows", []) if isinstance(r, dict)]
        apex = doc.get("apex")
        if isinstance(apex, dict) and apex.get("ref"):
            refs.append(apex["ref"])
        for ref in refs:
            assert FULL_REF_RE.match(str(ref)), f"{os.path.basename(path)}: ref {ref!r} not owner/repo#num"


def test_manifests_carry_a_desc_sentence():
    # `desc` renders under the program heading in every chain view; a manifest without one produces
    # a heading with no context, which fails the reading-first format contract.
    for path in _manifest_paths():
        desc = str(_load(path).get("desc") or "").strip()
        assert desc, f"{os.path.basename(path)}: missing desc"


def test_discovery_finds_them_with_zero_warnings():
    manifests, warnings = programs.discover([REPO_ROOT])
    assert warnings == [], warnings
    found = {m["program"] for m in manifests}
    expected = {os.path.splitext(os.path.basename(p))[0] for p in _manifest_paths()}
    assert expected <= found, f"discovery missed {expected - found}"


def test_edges_derive_without_self_edges():
    manifests, _ = programs.discover([REPO_ROOT])
    edges = programs.edges_from(manifests)
    assert edges, "manifests declare no edges — a manifest that declares nothing is dead weight"
    for e in edges:
        assert e["parent"] != e["child"], f"self-edge: {e}"
        assert e["source"] == "declared"


def test_manifests_are_not_gitignored():
    # The carve-out (!.borg/programs/) is what makes S4 possible; if a future .gitignore edit
    # regresses it, the manifests silently stop being versioned. check-ignore exits 0 when ignored.
    for path in _manifest_paths():
        rel = os.path.relpath(path, REPO_ROOT)
        proc = subprocess.run(
            ["git", "-C", REPO_ROOT, "check-ignore", rel],
            capture_output=True,
            text=True,
            timeout=15,
        )
        assert proc.returncode != 0, f"{rel} is gitignored — the carve-out regressed"
