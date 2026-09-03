"""The manifest WRITE verbs, which the lifecycle skills call (AC5).

Three verbs, one per moment in a row's life:

    scaffold   `/borg-plan` -- create `<repository>/.borg/programs/<name>.json` with an apex and no
               rows. Idempotent and NEVER clobbering.
    add-row    `/borg-link-up` -- append a row for a ref, or update the one already carrying it.
    close      `/borg-assimilate` -- set a row's status, by ref.

WHY A CLI AT ALL, RATHER THAN THE SKILLS WRITING JSON. A skill is markdown: asking one to emit a
valid manifest means asking a model to satisfy `core.validate` freehand on every invocation, and the
failure mode is a file that is wrong on disk with the author already gone. The architecture rule in
CLAUDE.md says logic goes in a testable core and shell is a wrapper; this is the core, so the skills
carry an invocation instead of a schema.

NOT ADDED TO `merge-tree/coordinator.py`, which is where `borg chain list|plan|sync` still go. That
module is what AC7 retires, so a fourth verb there would be built to be deleted. These land in
`borg_core.manifest` beside the writer they use.

── THE READ HERE IS STRICT, AND THAT IS THE WHOLE DESIGN ────────────────────────────────────────────

`shell._load_manifest` SALVAGES: a row that fails validation is dropped, the survivors are returned,
and a warning names the loss. That is right for RENDERING -- one bad row must not blank the grid, and
the measured cost of the old whole-file drop was 12 declared refs becoming 5.

It is catastrophic for READ-MODIFY-WRITE. Salvage on the way in plus `write_manifest` on the way out
means a row the author declared is deleted from disk by a verb that was asked to add a different one,
with the validator's own warning as the only trace. `refuse-the-manifest-stop-salvaging-rows` names
exactly that: "make it structurally impossible for a sync to delete a row the author declared."

So `_read_for_write` re-implements neither the loader nor the validator: it reads the raw bytes,
validates whole, and REFUSES whole. The asymmetry mirrors `write_manifest`'s own -- reads for
rendering degrade, reads for writing refuse -- and the reason is the same one that docstring gives:
a wrong document on the way in is wrong on disk forever, and the author is standing right there.

A consequence worth stating: these verbs cannot repair a manifest that is already invalid. They
report the validator's reasons and change nothing. That is the intended behaviour, not a gap --
salvaging is what they exist not to do.

A second consequence, measured rather than assumed: the strict read is also what lets a refusal NAME
its cause. Swapping it for `shell.discover` turns four tests red, not one, because that path reports
"absent", "not JSON" and "not an object" identically -- so the distinction the author needs is lost
along with the rows.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

from borg_core.manifest import core
from borg_core.manifest import shell

_ORDER_UNSET = ""


def _manifest_path(repository_dir: str, name: str) -> str:
    """Where `name` lands. Mirrors `write_manifest`'s stem handling so both agree on one path."""
    stem = os.path.basename(name)
    return os.path.join(shell.manifest_dir(repository_dir), stem if stem.endswith(".json") else f"{stem}.json")


def _read_for_write(repository_dir: str, name: str) -> dict[str, Any]:
    """The manifest at `name`, validated whole. Raises `shell.InvalidManifest` rather than salvaging.

    See the module docstring for why this does not go through `shell.discover`. `_path`/`_id` are
    never stamped here, so what comes back is already the declared body.
    """
    path = _manifest_path(repository_dir, name)
    try:
        with open(path, encoding="utf-8") as handle:
            doc = json.load(handle)
    except FileNotFoundError as exc:
        raise shell.InvalidManifest(f"{name}: no manifest at {path}", []) from exc
    except json.JSONDecodeError as exc:
        raise shell.InvalidManifest(f"{name}: not valid JSON ({exc})", []) from exc
    except UnicodeDecodeError as exc:
        # A manifest is UTF-8 by construction -- `write_manifest` writes it with
        # `ensure_ascii=False` -- but a file mangled by an editor, a bad merge or a truncated
        # transfer is bytes this decoder cannot read. Refusing by NAME keeps this module's one
        # vocabulary for an unreadable input; letting it escape gave a UnicodeDecodeError traceback,
        # which tells the author about a codec rather than about their file.
        raise shell.InvalidManifest(f"{name}: not valid UTF-8 ({exc})", []) from exc
    if not isinstance(doc, dict):
        raise shell.InvalidManifest(f"{name}: top level is {type(doc).__name__}, not an object", [])
    errors = core.validate(doc)
    if errors:
        raise shell.InvalidManifest(
            f"{name}: refusing to rewrite an invalid manifest — {'; '.join(errors)}", errors
        )
    return doc


def _row_index(manifest: dict[str, Any], ref: str) -> int | None:
    """Where `ref` already sits, or None. Exact match: `core` treats refs as opaque tokens."""
    for index, row in enumerate(manifest.get("rows") or []):
        if isinstance(row, dict) and str(row.get("ref") or "").strip() == ref:
            return index
    return None


def _lane_of(value: Any) -> str:
    """A lane name bucketed the way `core.lanes` buckets it: stripped, empty falling to the default.

    THIS MUST MATCH `core.lanes` CHARACTER FOR CHARACTER or the CLI and the reader disagree about
    which rows share a lane. It did not: this module used a bare `str(...)` while `core.lanes` uses
    `_text(...) or DEFAULT_LANE`, which strips. So a lane written `" contract "` -- hand-authored, or
    passed straight through from `--lane` -- was a DIFFERENT bucket to the order derivation below and
    the SAME lane to every consumer, and two rows landed on order "1" in one lane. Measured before
    the fix: two `add-row` calls, one padded and one not, both derived "1".
    """
    return str(value or "").strip() or core.DEFAULT_LANE


def _next_order(manifest: dict[str, Any], lane: str, skip_index: int = -1) -> str:
    """The next declared order within `lane`, ignoring the row at `skip_index`.

    Prerequisite rows (`core.PREREQ_ORDERS` -- the dashes and the empty string) carry no number and
    sort first, so they are SKIPPED rather than counted: numbering after them would claim a position
    the author deliberately left unnumbered. An empty lane starts at 1.

    `skip_index` exists for the lane MOVE below: the row being moved must not count itself when its
    new position is derived, or a move into its own lane would renumber it past its neighbours.
    """
    highest = 0
    for index, row in enumerate(manifest.get("rows") or []):
        if not isinstance(row, dict) or index == skip_index:
            continue
        if _lane_of(row.get("lane")) != lane:
            continue
        order = str(row.get("order") or "").strip()
        if order in core.PREREQ_ORDERS:
            continue
        digits = "".join(char for char in order if char.isdigit())
        if digits:
            highest = max(highest, int(digits))
    return str(highest + 1)


def _cmd_scaffold(args: argparse.Namespace) -> int:
    """Create the manifest if it is absent. Never overwrite one that exists.

    IDEMPOTENT BY DESIGN, because `/borg-plan` is not opt-in (AC5) and therefore runs on repositories
    that already have a manifest. Clobbering there would delete a whole declared program on a
    re-plan, so an existing file is reported and left exactly as it is -- at exit 0, since "already
    scaffolded" is the desired end state and not a failure.
    """
    path = _manifest_path(args.repository, args.name)
    if os.path.exists(path):
        print(f"exists: {path}")
        return 0
    manifest: dict[str, Any] = {"rows": []}
    if args.desc:
        manifest["desc"] = args.desc
    if args.apex:
        apex: dict[str, Any] = {"ref": args.apex}
        if args.title:
            apex["title"] = args.title
        manifest["apex"] = apex
    written = shell.write_manifest(args.repository, manifest, args.name)
    print(f"scaffolded: {written}")
    return 0


def _cmd_add_row(args: argparse.Namespace) -> int:
    """Append a row for `--ref`, or update the row already carrying it.

    APPEND-OR-UPDATE, NOT APPEND. `core.validate` rejects a duplicate ref outright ("two chain
    positions for one item"), so a second `add-row` for the same ref would refuse the whole file --
    and `/borg-link-up` runs every session, so a re-run for a PR already declared is the ordinary
    case rather than the exceptional one. Updating keeps that idempotent; only the fields the caller
    actually passed are touched, so a hand-written `why` survives a status refresh.
    """
    manifest = _read_for_write(args.repository, args.name)
    lane = _lane_of(args.lane)
    index = _row_index(manifest, args.ref)
    if index is None:
        row: dict[str, Any] = {"ref": args.ref, "lane": lane, "order": args.order or _next_order(manifest, lane)}
        if args.why:
            row["why"] = args.why
        if args.status:
            row["status"] = args.status
        manifest.setdefault("rows", []).append(row)
        action = "added"
    else:
        row = manifest["rows"][index]
        # A LANE MOVE RE-DERIVES THE ORDER, and skipping this corrupted the chain. The update loop
        # used to set only the fields passed, so `--lane` alone carried the row's OLD order into the
        # new lane: measured, moving a row with order "1" into a lane already holding "1" and "2"
        # produced orders ['1','2','1'], which `core.validate` ACCEPTS (it checks duplicate refs, not
        # duplicate orders). `core.lanes` then sorted the newcomer into the middle and
        # `core.derive_edges` re-pointed a stacked edge at it, so an UNTOUCHED row was demoted a
        # position and declared to depend on a row the author never ordered against it -- and
        # `ready_set` stopped announcing it. An explicit `--order` still wins; this only fills the
        # gap the caller left.
        moving = args.lane and _lane_of(args.lane) != _lane_of(row.get("lane"))
        # A PREREQUISITE STAYS A PREREQUISITE ACROSS A LANE MOVE. `core.PREREQ_ORDERS` (the three
        # dashes and the empty string) is not a missing number, it is a DECLARATION that the row has
        # no position and sorts first -- `core._sort_key` returns a 0-bucket for it. Numbering it on
        # a move destroys that: measured, a row at `"–"` moved into a lane holding "1" and "2" came
        # out as order "3", `core.lanes` put it LAST instead of first, and `derive_edges` emitted
        # `#3 -> #1` -- the ancestor now declared to depend on the whole chain it precedes. Exactly
        # the inversion the rederivation was added to prevent, in the other direction. Prerequisites
        # are not exotic: core.py records 7 of 16 rows in the live manifests using U+2013.
        prerequisite = str(row.get("order") or "").strip() in core.PREREQ_ORDERS
        for key, value in (("lane", lane if args.lane else ""), ("order", args.order),
                           ("why", args.why), ("status", args.status)):
            if value:
                row[key] = value
        if moving and not args.order and not prerequisite:
            row["order"] = _next_order(manifest, lane, skip_index=index)
        action = "updated"
    written = shell.write_manifest(args.repository, manifest, args.name)
    print(f"{action}: {args.ref} (lane {row.get('lane')}, order {row.get('order')}) -> {written}")
    return 0


def _cmd_close(args: argparse.Namespace) -> int:
    """Set a row's status by ref. Refuses when the ref is not declared.

    A MISSING REF IS AN ERROR HERE AND NOT AN IMPLICIT ADD, which is the difference between this and
    `add-row`. `/borg-assimilate` closes work it believes was declared; if the ref is absent, either
    the row was never added or the ref is wrong, and both are things the author needs told rather
    than papered over by a row appearing at close time with no `why` and no lane.
    """
    manifest = _read_for_write(args.repository, args.name)
    index = _row_index(manifest, args.ref)
    if index is None:
        declared = [str(r.get("ref")) for r in manifest.get("rows") or [] if isinstance(r, dict)]
        print(
            f"{args.name}: no row declares {args.ref} — declared refs are {declared or 'none'}",
            file=sys.stderr,
        )
        return 1
    manifest["rows"][index]["status"] = args.status
    written = shell.write_manifest(args.repository, manifest, args.name)
    print(f"closed: {args.ref} status={args.status} -> {written}")
    return 0


_VERBS = ("scaffold", "add-row", "close")


def _build_parser() -> argparse.ArgumentParser:
    """One FLAT parser with a positional verb, not `add_subparsers`.

    Subparsers are the natural fit for three verbs with different flags, and this is deliberately not
    them: the clean-architecture linter reports `parser.add_subparsers(...).add_parser(...)` and the
    `set_defaults` that follows as Law-of-Demeter chains (W9006), five of them, and the three sibling
    CLIs in this package (`link`, `recon`, `registry`) are all flat for the same reason. Five inline
    disables to keep argparse boilerplate would be noise sitting on top of a rule the rest of the
    package satisfies by construction.

    The cost is that every flag parses for every verb -- `--apex` is accepted on `close` and ignored.
    That is the same shape as `link/cli.py`'s `--deep`, which is parsed and ignored on purpose, and
    the verb handlers below read only the flags they use, so an inapplicable flag cannot change what
    is written.
    """
    parser = argparse.ArgumentParser(prog="borg_core.manifest.cli", description=__doc__.splitlines()[0])
    parser.add_argument("verb", choices=_VERBS)
    parser.add_argument("--repository", required=True, help="repository root (the directory holding .borg/)")
    parser.add_argument("--name", required=True, help="manifest file stem under .borg/programs/")
    parser.add_argument("--ref", default="", help="the row's ref (add-row, close)")
    parser.add_argument("--lane", default="", help=f"lane name (add-row; default {core.DEFAULT_LANE})")
    parser.add_argument("--order", default=_ORDER_UNSET, help="declared order; derived from the lane when omitted")
    parser.add_argument("--why", default="", help="one line on why this row exists (add-row)")
    parser.add_argument("--status", default="", help=f"{core.STATE_OPEN}|{core.STATE_MERGED}|{core.STATE_CLOSED}")
    parser.add_argument("--apex", default="", help="apex ref (scaffold)")
    parser.add_argument("--title", default="", help="apex title (scaffold)")
    parser.add_argument("--desc", default="", help="one-line program description (scaffold)")
    return parser


def main(argv: list[str] | None = None) -> int:
    """Dispatch, turning a refusal into a named non-zero exit rather than a traceback.

    `InvalidManifest` carries the validator's reasons; printing them is the whole contract with the
    author, since these verbs deliberately cannot repair what they refuse.

    `--ref` IS REQUIRED BY THE VERB, NOT BY THE PARSER, because the flat parser above shares one flag
    set across three verbs and `scaffold` legitimately has no ref. Checking it here keeps the
    requirement where the verb that has it lives.
    """
    args = _build_parser().parse_args(argv)
    if args.verb in ("add-row", "close") and not args.ref:
        print(f"{args.verb}: --ref is required", file=sys.stderr)
        return 2
    handlers = {"scaffold": _cmd_scaffold, "add-row": _cmd_add_row, "close": _cmd_close}
    if args.verb == "close" and not args.status:
        args.status = core.STATE_MERGED
    try:
        return int(handlers[args.verb](args))
    except shell.InvalidManifest as refusal:
        print(str(refusal), file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"{args.name}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":  # pragma: no cover - module entry point
    sys.exit(main())
