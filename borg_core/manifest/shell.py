"""I/O layer for the manifest reader: every filesystem and subprocess read it needs.

Every function here that touches the filesystem, subprocess, the environment or the clock lives in
this module. Logic (parsing, validating, ranking, selecting) is delegated to core.py -- this module
never reimplements it.

Ports the I/O half of merge-tree/programs.py:274-331 (its `programs_dir`, `discover`) and adds the
two entry points the one-front-door `link` needs: `discover_registered`, which globs EVERY registered
repository rather than one, and `repository_slug`, which answers "which `owner/repo` is this
directory?" the same way the recon github adapter does.

WHY THIS DOES NOT IMPORT borg_core.link.core. `discover_registered` needs the registry's project
paths, and `borg_core.link.core.project_paths` already extracts them (mirroring jq's
`[.key, (.value.path // "")] | @tsv`). Importing it would point an arrow from `manifest` at `link`,
and `link` is about to become the CONSUMER of this package -- the arrow belongs the other way round.
The local extraction is a handful of lines, far under pylint's `min-similarity-lines = 8`, and
deliberately does NOT reproduce jq's `//` sentinel semantics for a numeric-false path, because a
registry `path` is a string or absent and nothing else. The right consolidation is a neutral
top-level home (the borg_core/paths.py precedent) that BOTH readers call, which cannot land until
`link` is being edited too; until then the exposure is the silent one -- an extractor that returns
`[]` after a registry-shape change would sweep nothing and say nothing -- and that is closed here by
warning when a non-empty registry yields no usable path.

NO READ HERE IS EVER FATAL. A missing directory, an unreadable one, malformed JSON, non-manifest
JSON, an invalid manifest, a missing git, a non-repository directory, a registry of the wrong shape,
a remote URL that is not even valid UTF-8 -- every one of them is a NAMED warning or an empty string
and a skip. One bad file must never blank the grid, and an unnamed skip is indistinguishable from a
file that was never there.

THE ONE WRITE HERE IS THE OPPOSITE, deliberately. `write_manifest` raises `InvalidManifest` and
writes nothing. The rule above is not a house style, it is a consequence of what a read is for: a
reader serves a page about N manifests and must not let one file blank the other N-1, and the person
who could fix the file is not necessarily present. A writer serves ONE document whose author is
standing right there, and a document that is wrong on the way in is wrong on disk until someone
notices. Degrading a write means silently storing less than the author declared -- so writes refuse
whole and hand the reasons back. Do not "make this consistent" by softening the writer.
"""

from __future__ import annotations

import json
import os
import tempfile
from typing import Any

from borg_core import proc
from borg_core.manifest import core

# `git remote get-url` on a healthy checkout is instant, but a repository whose object store sits on
# a stale network mount can block indefinitely, and this runs once per registered repository on a
# command whose whole point is being reflexive. The adapter has no timeout because it is not on the
# reflexive path; this is a deliberate addition, and a timeout degrades to "" exactly like a missing
# remote does.
GIT_TIMEOUT_SECONDS = 5


def manifest_dir(repository_dir: str) -> str:
    """borg's one location for manifests: `<repository>/.borg/programs`.

    The single path constant, and the whole of the location rule. Nothing outside this directory is
    ever opened -- not `<repository>/.borg/anything.json`, not a manifest-shaped file in the
    repository root. What CHANGED with the hardened spec's B6 is not this rule but the sweep: every
    registered repository's copy of this directory is globbed, not just the one in scope.

    The `programs` literal in the RETURN VALUE is what is on disk and stays until a rename directive
    moves it. The FUNCTION is not named after it: "program" is retired, and a new public symbol in a
    new package is exactly where the retired word must not reappear.
    """
    return os.path.join(repository_dir, ".borg", "programs")


def _load_manifest(path: str, name: str) -> tuple[dict | None, str]:
    """One manifest file as `(manifest, warning)`. BOTH can now be meaningful at once.

    That is a contract change and it is the point: a manifest whose rows partly validate returns the
    surviving rows AND a warning naming what was dropped (see `_drop_invalid_rows`). A caller must
    therefore test the warning and the manifest INDEPENDENTLY -- `if manifest is None: append(warning)`
    silently swallows the message on exactly the case it was added for.

    Three distinct skips, each NAMED: unreadable/malformed JSON, valid JSON that is not a manifest
    (a stray `settings.json` in the directory), and a manifest that fails validation, whose errors
    are joined into the warning rather than swallowed.

    TWO DERIVED KEYS ARE ADDED, both underscore-prefixed so the declared body stays exactly what is
    on disk: `_path`, which must always reflect where this copy was read from (the literal key name
    is a cross-module contract -- merge-tree's writer strips exactly that key), and `_id`, the
    manifest's identity for display. `_id` reads a declared top-level `program` key VERBATIM when
    there is one, because that is what is on disk, and falls back to the filename stem. What it does
    NOT do is write a `program` key back into the document: reading a retired word is unavoidable,
    synthesizing one into newly-created output is not.
    """
    try:
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, f"{path}{_UNREADABLE}{exc})"

    if not core.looks_like_manifest(doc):
        return None, f"{path}: not a manifest (no rows list) -- skipped"

    errors = core.validate(doc)
    warning = ""
    if errors:
        doc, warning = _drop_invalid_rows(doc, path, errors)
        if doc is None:
            return None, warning

    doc["_id"] = str(doc.get("program") or "").strip() or os.path.splitext(name)[0]
    doc["_path"] = path
    return doc, warning


def _drop_invalid_rows(doc: dict, path: str, errors: list[str]) -> tuple[dict | None, str]:
    """A manifest with its failing rows removed, or `(None, warning)` when nothing can be salvaged.

    ONE BAD ROW MUST NOT COST THE FILE. Before this, any validation error dropped the whole manifest:
    a single missing `gate.resolved_by` in row 3 deleted rows 1..14 from the grid, and `▸ CHAINS` then
    rendered its "no manifest declares work here" placeholder as though the repository simply had
    none. Measured on the AC2 fixtures at the time: 12 declared refs became 5. A reader could not
    distinguish *nothing declared* from *everything hidden by one typo*.

    THE FILE IS STILL DROPPED WHOLE in three cases, and each is a case with no partial answer:
      * a STRUCTURAL error (`rows: missing or not a list`, `apex: ...`) -- it describes the container
        or a sibling key, so there is no subset of rows that would make the file mean what its author
        wrote;
      * EVERY row failing -- there is no page to render and nothing is gained by pretending;
      * survivors that STILL do not validate (below).

    RE-VALIDATED AFTER THE DROP, and that is not belt-and-braces. Duplicate detection is
    cross-row: `_validate_row` flags the SECOND occurrence of a ref and leaves the first alone, so
    removing a row can legitimately clear an error on a row that was kept. Re-running is how the
    contract "a loaded manifest is a valid manifest" survives -- every downstream consumer assumes it,
    and none of them re-check.

    The warning names the count and carries the validator's own messages verbatim: a reader has to be
    able to tell "this project has 7 rows" from "this project has 8 rows and I am showing you 7".
    """
    bad_rows, structural = core.partition_errors(errors)
    joined = "; ".join(errors)
    rows = doc.get("rows") or []
    if structural or not bad_rows:
        return None, _invalid_manifest(path, errors)

    kept = [row for index, row in enumerate(rows) if index not in bad_rows]
    if not kept:
        return None, _invalid_manifest(path, errors)

    doc["rows"] = kept
    residual = core.validate(doc)
    if residual:
        return None, _invalid_manifest(path, residual)
    return doc, f"{path}: {len(bad_rows)} of {len(rows)} rows dropped -- {joined}"


# The two warning shapes that mean "a file here looks like a manifest and could not be used": the
# unreadable/invalid-JSON skip in `_load_manifest` and every `invalid manifest` arm of
# `_drop_invalid_rows`. Not the `not a manifest (no rows list)` skip, which describes a stray
# `settings.json` sitting in the directory rather than a manifest that failed, and not the
# `N of M rows dropped` arm, which is a manifest that DID load.
_INVALID_MANIFEST = ": invalid manifest -- "
_UNREADABLE = ": unreadable or invalid JSON ("
_REFUSAL_MARKERS = (_INVALID_MANIFEST, _UNREADABLE)


def _invalid_manifest(where: str, reasons: list[str]) -> str:
    """The one producer of the refusal message `refused_manifest_paths` parses.

    There were four hand-written copies of this f-string and a fifth literal in the marker tuple, in
    one file, while `refused_manifest_paths`'s docstring claimed "exactly one producer". Reword any
    copy and the CHAINS placeholder silently reverts to the false "no project manifests in the
    registry yet", with nothing red -- the tests build their warnings through `discover`, so both
    sides move together.
    """
    return f"{where}{_INVALID_MANIFEST}{'; '.join(reasons)}"


def refused_manifest_paths(warnings: list[str], under: str = "") -> list[str]:
    """The manifest paths a discovery pass refused, optionally narrowed to one repository.

    LIVES HERE, NEXT TO THE FORMAT IT PARSES, for the reason `core.partition_errors` gives about its
    own: `_load_manifest` and `_drop_invalid_rows` build these strings a dozen lines up, and a
    consumer that wants the paths back has to know the shape. Putting the parse in `link/render.py`
    would make the message format an undeclared cross-package contract -- the shape that breaks
    silently the first time someone rewords an error string. Reword one here and this moves with it.

    WHY A STRING PARSE AT ALL, rather than `discover` returning the paths structurally: `discover`'s
    `(manifests, warnings)` contract is consumed by the CLI, the coordinator and the grid, and
    widening it to carry a third value ripples through all three for one placeholder sentence. The
    format has exactly one producer, in this file, and one consumer, through this function.

    `under` narrows to one repository directory because warnings are registry-WIDE -- `discover_
    registered` sweeps every registered path -- and a manifest refused in some other repository must
    not change what THIS repository's page says about itself.
    """
    prefix = os.path.join(under, "") if under else ""
    found = []
    for warning in warnings:
        for marker in _REFUSAL_MARKERS:
            head, sep, _ = warning.partition(marker)
            if sep and (not prefix or head.startswith(prefix)):
                found.append(head)
                break
    return found


def _manifest_identity(manifest: dict) -> str:
    """A manifest's content identity: its declared body with every derived `_` key removed.

    Two registry entries can point at two DIFFERENT directories holding the SAME manifest -- a git
    worktree is the live case, since `.borg/programs/` is git-tracked, so `drone feature` produces a
    second checkout of every manifest and `borg add` registers it beside its parent. Their `_path`
    values differ, so no path-level dedup can see it, and the grid would render every node, every
    gate and every declared ref twice under one header.

    Keyed on the body rather than on the declared id because the id is not unique either (both copies
    declare the same one) and because two files that are byte-equal as JSON ARE the same declaration:
    rendering it twice is wrong whatever it is called.

    The strip is `core.declared_body`, shared with `write_manifest`, so "which keys are derived" has
    ONE answer for the reader and the writer both. It was written out by hand here before the writer
    existed; two hand-written copies is how the old writer came to strip `_path` and persist `_id`.
    """
    return json.dumps(core.declared_body(manifest), sort_keys=True)


def discover(repository_dirs: list[str]) -> tuple[list[dict], list[str]]:
    """Load every manifest under the given repositories' `.borg/programs/`.

    Returns `(manifests, warnings)`. Takes explicit directories so the pure selection and ranking in
    core.py can be exercised against any set of paths; `discover_registered` is the entry point that
    derives them from the registry.

    `except FileNotFoundError` MUST PRECEDE `except OSError` -- FileNotFoundError subclasses OSError,
    and reordering them would make every repository without a `.borg/programs` emit an "unreadable"
    warning, turning the silent common case into noise on every repository borg knows about. Inside
    that branch the isdir check is what distinguishes a typo'd path (warn by name) from a normal
    repository with no manifests (silent).

    DEDUPLICATED TWICE, because a duplicate arrives by two different routes and neither catches the
    other. Directories are collapsed on `os.path.realpath`, which absorbs a symlinked registry entry
    and the `/x/repo` vs `/x/repo/` pair that `os.path.join` would otherwise turn into two sweeps of
    one directory (indistinguishable afterwards -- the two manifests carry an IDENTICAL `_path`).
    Loaded manifests are then collapsed on content identity, which is the only thing that catches a
    worktree: a real second checkout at a real second path holding a real second copy of the same
    file. `os.path.realpath` does not stat, so a missing directory normalizes lexically and still
    reaches its "does not exist" warning.

    Manifests come back in `sorted()` filename order within each repository, so load order is
    deterministic across filesystems, and only `.json` files are read -- a README.md living beside
    the manifests produces zero warnings.
    """
    manifests: list[dict] = []
    warnings: list[str] = []
    swept: set[str] = set()
    bodies: set[str] = set()

    for repository_dir in repository_dirs:
        directory = manifest_dir(repository_dir)
        if os.path.realpath(directory) in swept:
            continue
        swept.add(os.path.realpath(directory))
        try:
            names = sorted(n for n in os.listdir(directory) if n.endswith(".json"))
        except FileNotFoundError:
            if not os.path.isdir(repository_dir):
                # A typo'd or stale registry path must not be indistinguishable from "no manifests":
                # the repository itself is missing, so name it.
                warnings.append(f"{repository_dir}: repository directory does not exist")
            continue  # repository exists, no .borg/programs -- the common case, not a problem
        except OSError as exc:
            # Unreadable (permissions, I/O) is never silent: zero manifests from a real directory
            # would look exactly like a correct empty sweep.
            warnings.append(f"{directory}: unreadable ({exc})")
            continue

        for name in names:
            manifest, warning = _load_manifest(os.path.join(directory, name), name)
            # A WARNING NOW ACCOMPANIES A LOADED MANIFEST, so this can no longer be `if manifest is
            # None`. A partially-salvaged file returns BOTH -- the rows that validated and a warning
            # naming the ones dropped -- and gating the append on the manifest being None would
            # silently swallow exactly the message that explains why the picture is short.
            if warning:
                warnings.append(warning)
            if manifest is None:
                continue
            identity = _manifest_identity(manifest)
            if identity in bodies:
                continue
            bodies.add(identity)
            manifests.append(manifest)

    return manifests, warnings


def _registered_paths(registry: Any) -> tuple[list[str], list[str]]:
    """`(paths, warnings)`: every registered repository path, in registry order, blanks dropped.

    Blank and the literal string "null" are dropped, and that is not defensive padding: `jq` renders
    a JSON null as the four characters `null`, every zsh reader guards
    `[[ -z "$ppath" || "$ppath" == "null" ]]`, and -- worse -- passing "" to manifest_dir would yield
    the RELATIVE path `.borg/programs`, making discovery read whatever directory the process happens
    to be sitting in. One entry with no path is skipped silently, matching every other collector in
    borg_core.

    TYPE-CHECKED, NOT TRUTH-CHECKED. `registry.get("projects") or {}` covers missing, null and empty
    but not a wrong TYPE: `{"projects": ["/a", "/b"]}` reached `.values()` and raised AttributeError
    straight out of `discover_registered`, taking down the whole invocation from inside the module
    whose header promises nothing here is ever fatal. `borg_core.registry.shell.read_registry`
    validates JSON syntax and nothing else, so a hand-edited or half-migrated registry arrives here
    intact.

    A REGISTRY THAT DECLARES PROJECTS AND YIELDS NO PATH WARNS. Zero manifests and zero warnings is
    the silent-blindness shape this repository has been burned by twice (the usage-watch and
    `borg recon` incidents in CLAUDE.md's "Learned"): if the registry schema moves under this
    extractor -- a renamed key, a different null sentinel, paths stored elsewhere -- the sweep goes
    quiet and `link` renders a confidently empty grid. One warning is the whole tripwire. It stays
    per-REGISTRY rather than per-entry so a single pathless project cannot make it noisy.
    """
    if not isinstance(registry, dict):
        return [], [f"registry: not an object ({type(registry).__name__}) -- no repositories swept"]
    projects = registry.get("projects")
    if not projects:
        return [], []
    if not isinstance(projects, dict):
        return [], [f"registry: projects is not an object ({type(projects).__name__}) -- no repositories swept"]

    paths = []
    for entry in projects.values():
        path = str(entry.get("path") or "") if isinstance(entry, dict) else ""
        if path and path != "null":
            paths.append(path)
    if not paths:
        return [], [f"registry: {len(projects)} project(s) registered but none carry a usable path"]
    return paths, []


def discover_registered(registry: Any) -> tuple[list[dict], list[str]]:
    """Every manifest under EVERY registered repository's `.borg/programs/`. B6's enforcing half.

    DISCOVERY IS GLOBAL; SELECTION IS SCOPED -- stated once in core.py's module docstring ("WHERE
    MANIFESTS COME FROM") and enforced here. The sweep is a local glob over ~14 directories,
    milliseconds; the narrowing happens in core.select_for_repository, on what a manifest declares
    rather than on where its file sits.

    IT DERIVES THE PATHS ITSELF, and must keep doing so. Accepting a path list here would make this
    function a one-line alias for `discover` and move the derivation into the caller -- where a test
    would then supply it, and the registry-reading line production actually runs would be the one
    line no test ever executes. That is exactly how `borg recon` shipped completely non-functional
    (CLAUDE.md, "Learned"), and the mandatory B6 regression test builds a registry rather than a path
    list for precisely this reason.

    The caller supplies the registry dict rather than this function reading it, so the same registry
    snapshot threads through a whole document; `borg_core.registry.shell.read_registry` is the reader.
    """
    paths, warnings = _registered_paths(registry)
    manifests, sweep_warnings = discover(paths)
    return manifests, warnings + sweep_warnings


def _git_origin_url(repository_dir: str) -> str:
    """`git -C <dir> remote get-url origin`, or "" for every failure mode there is.

    Mirrors recon-adapter-github:80's `git -C "$PPATH" remote get-url origin 2>/dev/null || echo ""`:
    stderr discarded, a non-zero exit yielding the empty string rather than aborting. Only TRAILING
    NEWLINES are stripped, matching what `$(...)` does. `.strip()` would be wrong, not merely
    different: a remote configured as `" https://github.com/owner/repo"` is rejected today by the
    character-class test exactly as the adapter's `case` glob rejects it, and stripping the leading
    space would accept it and report a slug for a repository the adapter emits no items for -- the
    one-sided divergence this whole function exists to avoid.

    Never raises; borg_core.proc.run_capture owns that policy, including the non-UTF-8 remote URL
    that would otherwise raise UnicodeDecodeError past both `OSError` and `subprocess.SubprocessError`.
    Every failure is "" -- the same answer a repository with no origin gives, because for this
    function's purpose they are the same answer.
    """
    captured = proc.run_capture(
        ["git", "-C", repository_dir, "remote", "get-url", "origin"],
        timeout=GIT_TIMEOUT_SECONDS,
    )
    if captured is None:
        return ""
    returncode, stdout = captured
    return stdout.rstrip("\n") if returncode == 0 else ""


def repository_slug(repository_dir: str) -> str:
    """The `owner/repo` this directory's origin remote names, or "" when there is not exactly one.

    Three steps, and only the first two are I/O -- `core.slug_from_remote` holds the rule table and
    the argument for each of its rules:

      :77  the directory must contain a `.git` entry (see below).
      :80  the remote is `git remote get-url origin`; any failure is "".
      :81-101  the URL must resolve to exactly one GitHub `owner/name` -- core.slug_from_remote.

    `.git` MAY BE A FILE, and that is a deliberate departure from what
    lib/recon/adapters/recon-adapter-github:77 used to test. A linked git worktree's `.git` is a file
    containing `gitdir: ...`, and `git remote get-url origin` answers correctly inside one, so the
    old `isdir` test made every worktree select no manifests at all -- an empty grid, which is the
    failure B6 exists to remove. `drone feature` creates worktrees and `borg add` registers them;
    `/Users/noah/dev/reveal-data-consistency` is one in the live registry today. The adapter's test
    was changed to `[ -e ]` in the same commit, because a fix on one side only would make `link`
    render manifests `recon` has no items for.

    An EXISTENCE test and not nothing at all: `git remote get-url origin` run in a plain
    SUBDIRECTORY of a repository succeeds and returns the PARENT's remote, so dropping the check
    would give `<repo>/packages/web` its parent's slug and select the parent's manifests under a
    header naming the subdirectory.
    """
    if not os.path.exists(os.path.join(repository_dir, ".git")):
        return ""
    return core.slug_from_remote(_git_origin_url(repository_dir))


class InvalidManifest(ValueError):
    """A write was refused because the document does not validate. Carries the reasons.

    A ValueError subclass rather than a new root, so a caller that already catches ValueError around
    a write keeps working, and one that wants to tell "this manifest is wrong" apart from "the disk
    is wrong" can. `errors` is `core.validate`'s list, unjoined, because the CLI seam prints one
    reason per line and re-splitting a joined string is how a message format becomes a contract.
    """

    def __init__(self, message: str, errors: list[str]) -> None:
        super().__init__(message)
        self.errors = errors


def _write_refusal(name: str, errors: list[str], slug: str) -> InvalidManifest:
    """The exception a refused write raises, with a `did you mean` on every fixable ref.

    The offending value comes back through `core.offending_value`, which owns the `, got ` token
    beside the six messages that write it -- hand-parsing it here made the format an undeclared
    cross-module contract that a reword would silently break. The `if got` and `.strip()` guards the
    hand-rolled version carried were both dead: `suggest_full_ref("")` already answers "", and every
    producer interpolates an already-stripped value.

    The suggestion is appended to the REASON, never applied to the document -- see
    `core.suggest_full_ref`. It exists because the overwhelmingly common defect is an author (now
    usually a model) writing `repo#12` for a PR in the repository it is standing in, and the fix is
    one token it cannot guess from the error text alone.
    """
    detailed = []
    for error in errors:
        suggestion = core.suggest_full_ref(core.offending_value(error), slug)
        detailed.append(f"{error} -- did you mean {suggestion}?" if suggestion else error)
    return InvalidManifest(_invalid_manifest(name, detailed), detailed)


def write_manifest(repository_dir: str, manifest: dict, name: str) -> str:
    """Write a manifest to `<repository>/.borg/programs/<name>.json`. The ONLY writer.

    THE ONE PLACE THIS MODULE'S "nothing here is ever fatal" RULE DOES NOT APPLY, and the asymmetry
    is the point. A reader that dies on one bad file blanks the whole grid, so reads degrade: a bad
    row is dropped, named in a warning, and the surviving rows still render. A WRITE has the opposite
    failure mode -- a document that is wrong on the way in is wrong on disk forever, and the author
    is standing right there able to fix it. So this validates all, then refuses whole: `InvalidManifest`
    before anything is opened, never a partial file. Callers surface the reasons; they do not salvage.

    NO `program` BACKFILL. The writer this replaces did `to_write.setdefault("program", program)`,
    which meant the commit retiring that word shipped a writer that kept writing it, three files from
    a loader that explicitly refuses to synthesize it. What goes to disk is exactly
    `core.declared_body(manifest)` -- the author's keys, no `_path`, no `_id`.

    `name` IS A FILE STEM AND IS BASENAMED HERE, not by the caller. The old writer took the caller's
    `filename` verbatim, so path discipline lived at every call site and a caller passing a manifest's
    declared id -- which may contain a slash -- could write outside the directory. `.json` is appended
    when absent so both `add-row` (passing a stem) and a rewrite (passing an existing basename) land
    on one path.

    ATOMIC VIA `mkstemp` IN THE TARGET DIRECTORY, not a fixed `<path>.tmp`. Two syncs racing on one
    fixed name interleave their writes and can orphan a temp file inside a git-tracked directory;
    `mkstemp` gives each writer a private name, and `os.replace` within one filesystem is atomic.
    The temp file is removed if the replace never happens, so a failed write leaves no litter.

    `ensure_ascii=False` because the corpus contains real en-dashes (`core.PREREQ_ORDERS` treats
    U+2013 as a declared order) and escaping them to `\\u2013` rewrites bytes in a tracked file on a
    sync that changed nothing. `sort_keys=True` is kept from the old writer: a deterministic key order
    is what makes "the sync changed nothing" visible as an empty diff.
    """
    errors = core.validate(manifest)
    if errors:
        # THE SLUG IS RESOLVED ONLY WHEN A SUGGESTION IS POSSIBLE. `repository_slug` forks
        # `git remote get-url` -- measured at 46.8ms -- and `_write_refusal` uses it only for errors
        # carrying an offending value. A manifest rejected for `missing order`, `rows: not a list` or
        # a duplicate ref pays that fork for nothing.
        suggestible = any(core.offending_value(error) for error in errors)
        raise _write_refusal(name, errors, repository_slug(repository_dir) if suggestible else "")

    directory = manifest_dir(repository_dir)
    os.makedirs(directory, exist_ok=True)
    stem = os.path.basename(name)
    path = os.path.join(directory, stem if stem.endswith(".json") else f"{stem}.json")

    handle, tmp_path = tempfile.mkstemp(dir=directory, prefix=".write-", suffix=".json.tmp")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as fh:
            json.dump(core.declared_body(manifest), fh, indent=2, sort_keys=True, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp_path, path)
    except OSError:
        os.unlink(tmp_path)
        raise
    return path
