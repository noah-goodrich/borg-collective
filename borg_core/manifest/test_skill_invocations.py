"""Every `python3 -m borg_core.manifest.cli <verb>` a skill documents must be runnable as written.

The parser requires `--repository` on every verb and `--name` on every verb but `resolve`
(`cli.main`), and `add-row`/`close` also need `--ref`. link-up and assimilate once documented
add-row/close without them, so an agent following the skill verbatim exited 2 and manifests stayed
empty. MEASURED: deleting `--repository` from one documented line turns this red.
"""

import re
from pathlib import Path

import pytest

SKILLS = Path(__file__).resolve().parents[2] / "skills"
_INVOCATION = re.compile(r"python3 -m borg_core\.manifest\.cli\s+(?P<verb>[a-z-]+)(?P<rest>(?:[^\n]*\\\n)*[^\n]*)")
_REQUIRED = {
    "resolve": ("--repository",),
    "scaffold": ("--repository", "--name"),
    "add-row": ("--repository", "--name", "--ref"),
    "close": ("--repository", "--name", "--ref"),
}


def _invocations() -> list[tuple[str, str, str]]:
    found = []
    for skill in sorted(SKILLS.glob("*/SKILL.md")):
        for match in _INVOCATION.finditer(skill.read_text()):
            found.append((skill.parent.name, match["verb"], match["rest"]))
    return found


def test_the_skills_document_manifest_invocations_at_all() -> None:
    verbs = {verb for _, verb, _ in _invocations()}
    assert {"resolve", "add-row", "close", "scaffold"} <= verbs


@pytest.mark.parametrize("skill,verb,rest", _invocations())
def test_documented_invocation_carries_every_required_flag(skill: str, verb: str, rest: str) -> None:
    missing = [flag for flag in _REQUIRED[verb] if not re.search(rf"{flag}(\s|=)", rest)]
    assert not missing, f"skills/{skill}/SKILL.md documents `{verb}` without {missing}; it would exit 2"
