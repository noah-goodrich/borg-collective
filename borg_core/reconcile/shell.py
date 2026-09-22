"""The impure rungs of reconcile: which ref kinds this machine can resolve, and reading a manifest.

Everything that touches the filesystem lives here so `core.py` stays pure and AST-pinnable. Nothing
here decides policy -- the contradiction rules are `core`'s, and this module only answers "is there
a resolver for this kind on this machine" and "what rows does that file hold".

THIS MODULE ALSO WRITES NOTHING. It is the read half of a read-only feature; the writer is AC7's,
and `test_shell.py` asserts the absence by AST call graph the same way `test_core.py` does.
"""

from __future__ import annotations

from borg_core.manifest import refs, shell as manifest_shell
from borg_core.recon import shell as recon_shell


def resolvable_kinds() -> set[str]:
    """The TRACKED ref kinds this machine has a resolver for, by DISCOVERY not by allow-list.

    A kind is resolvable when it is in `refs.TRACKED_REF_KINDS` AND an executable named
    `recon-adapter-<kind>` is discoverable. `recon_shell.discover_adapters()` is reused verbatim
    rather than reimplemented -- it already globs `recon-adapter-*` across the search path with the
    config dir shadowing the repo dir, and taking the source from the filename is what makes adding
    a source a FILE rather than a commit.

    THE POINT OF THE SET IS THAT NO SOURCE NAME APPEARS HERE. On this machine the result is
    `{"github"}`, because `lib/recon/adapters/` holds exactly one adapter. On a machine with
    `recon-adapter-jira` dropped in it becomes `{"github", "jira"}` with no code change, which is
    the work machine's future and is asserted as a test rather than promised in prose.

    `link` is excluded for free: it is not in TRACKED_REF_KINDS, because a URL is context a human
    attached rather than work whose state anyone can resolve.
    """
    try:
        discovered = {source for source, _path in recon_shell.discover_adapters()}
    except OSError:
        # An unreadable adapter dir is "cannot look". The safe degrade here is NARROWER: with no
        # kinds resolvable, every ref lands in `unresolvable_refs` and is REPORTED rather than
        # quietly treated as resolved. `manifest/cli.py::_authorable_kinds` wraps the same call in
        # the opposite direction -- there a degraded path must never WIDEN what is authorable, so it
        # keeps its built-in github. Same call, opposite safe direction, on purpose at both sites.
        return set()
    return {kind for kind in refs.TRACKED_REF_KINDS if kind in discovered}


def unresolvable_refs(rows: list | None, kinds: set[str] | None = None) -> list[str]:
    """Refs whose kind this machine cannot resolve, in row order.

    Reported rather than silently skipped, because a row nobody can resolve is exactly the state
    that wedges every row behind it -- and a reconcile report that omits it would describe a chain
    as healthier than it is. Kinds are passed in so a caller can test the predicate without a
    filesystem, and default to this machine's when omitted.
    """
    available = resolvable_kinds() if kinds is None else kinds
    out = []
    for row in rows or []:
        if not isinstance(row, dict):
            continue
        ref = refs.text(row.get("ref"))
        if not ref:
            continue
        if refs.ref_kind(ref) not in available:
            out.append(ref)
    return out


def manifest_rows(repository_dir: str, name: str = "") -> list:
    """The rows of one manifest under `repository_dir`, or `[]` when there is none to read.

    Uses `manifest_shell.discover`, which is already PUBLIC, rather than adding a read seam to the
    manifest package. That is deliberate: the other machine is working AC5 inside
    `borg_core/manifest/` right now, and an additive read-only helper there would still be a
    conflict in a file being edited. Reusing the existing public entry point costs one extra
    directory walk and zero collision.

    `name` selects by `_id` when several manifests exist; omitted, the single manifest wins and
    several is ambiguous, which returns `[]`. That mirrors `manifest.cli resolve`'s rules 2 and 4
    rather than inventing a second selection policy -- deliberately WITHOUT importing that CLI,
    because a library reaching into a command-line module for a rule is the altitude mistake the
    recon-retirement gate was moved to avoid.

    `[]` on every failure is the refusing direction: a manifest this cannot read is not one to
    report contradictions about.
    """
    try:
        manifests, _warnings = manifest_shell.discover([repository_dir])
    except OSError:
        return []
    if not manifests:
        return []
    if name:
        manifests = [m for m in manifests if str(m.get("_id") or "") == name]
    if len(manifests) != 1:
        return []
    rows = manifests[0].get("rows")
    return rows if isinstance(rows, list) else []
