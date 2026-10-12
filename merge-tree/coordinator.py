#!/usr/bin/env python3
"""coordinator.py — `borg chain`: supervisor between borg's own chain manifests and any
external system tracking the same chains. PM6/PM7.

WHAT THIS IS NOT. This module writes nothing on GitHub, renders no PR body, and knows no field
name from any external schema. It resolves intent, dispatches each write to its OWN native writer,
and reports disagreement. See the 2026-08-18 directive on manifests as a borg edge source,
"Two copies, on purpose" — the coordinator is the entire mitigation for drift between them, so it
must stay honest about drift rather than resolving it.

ONE READER, ONE WRITER (AC7). Manifests are read through `borg_core.manifest.shell.discover`, the
reader `borg link`, `add-row`, `close` and `resolve` also use, and written back through
`shell.write_manifest`, the only writer. This module used to carry a second copy of both and the two
disagreed about what a valid manifest is; there is one now. A manifest's identity is the `_id`
borg_core stamps on it (a declared top-level key read verbatim when the author wrote one, else the
filename stem), and `.stacks/` is swept alongside `.borg/chains/` and the legacy
`.borg/programs/`.

THE DISCOVERED TARGET. Exactly like a recon adapter (`BORG_RECON_ADAPTER_PATH`), the external
writer is discovered, never hardcoded: an executable named `borg-sync-target-<name>` on
`BORG_SYNC_TARGET_PATH` (or the machine-local default directory below). Absent target -> borg
operates on its own copy alone, successfully and silently (PM9).

THE SHIM CONTRACT this module expects of a discovered target (the shim itself lives outside this
repo — this directive defines the interface, not the file):

    borg-sync-target-<name> plan|sync

  stdin:  {"manifests": [<declared manifest body, see SCHEMA.md>, ...]}
  stdout: one JSON object:
          {"ok": bool, "rows": [{"ref": "owner/repo#num", "status": "..."}], "note": "..."}

  THE PAYLOAD IS THE DECLARED BODY AND NOTHING ELSE (`core.declared_body`): exactly the keys the
  author wrote, with every `_`-prefixed key (`_path`, `_id`, whatever borg derives later) stripped.
  WIRE CHANGE, 2026-10-12: the payload no longer carries a `program` key synthesized from the
  filename. The key is present only when the manifest's author wrote one, so a shim that identified
  manifests by it must tolerate its absence.

  `plan` MUST NOT write anything — it is the target's own dry run. `sync` performs the write (PR
  bodies, apex issues, whatever the target owns) as a side effect. Any translation between borg's
  `ref` and the target's own key shape happens inside the shim; this module never sees it.

THE THREE-WAY AUDIT (PM7). Compares borg's copy, the target's copy (via its `plan` dry run), and
reality (recon item states, keyed by `ref`). Every finding is reported through recon's existing
contradiction idiom (a plain dict naming what disagrees) — never auto-resolved. Negotiation here
means naming which side a fix would change, not applying one.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any

from borg_core.manifest import core, shell

ENV_VAR = "BORG_SYNC_TARGET_PATH"
TARGET_PREFIX = "borg-sync-target-"
DEFAULT_SEARCH_DIR = os.path.expanduser("~/.config/borg/sync-targets")

# States recon reports that mean "still open" — anything else (MERGED, CLOSED) is terminal. Used
# only to detect a copy claiming `merged` while reality disagrees; never to invent a status.
OPEN_STATES = {"OPEN", "DRAFT"}


def sync_target_search_dirs(env: dict[str, str] | None = None) -> list[str]:
    """Directories to search for a discovered target, in priority order.

    Mirrors `_recon_adapter_path`'s override-then-default shape. The override is colon-separated,
    same convention as `BORG_RECON_ADAPTER_PATH` and `PATH` itself.
    """
    env = env if env is not None else os.environ
    override = env.get(ENV_VAR, "")
    dirs = [d for d in override.split(":") if d]
    return dirs or [DEFAULT_SEARCH_DIR]


def discover_sync_target(search_dirs: list[str]) -> str | None:
    """The first executable `borg-sync-target-*` on the search path, or None.

    Only one target is ever dispatched to — "a" discovered target, not a fan-out — because there is
    one external system this directive names (the employer stacked-PR copy). First-on-path wins,
    matching the adapter dedup rule (`dedup_adapters`), for the same reason: deterministic across
    runs regardless of directory listing order.
    """
    for directory in search_dirs:
        try:
            names = sorted(os.listdir(directory))
        except OSError:
            continue
        for name in names:
            if not name.startswith(TARGET_PREFIX):
                continue
            path = os.path.join(directory, name)
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
    return None


def run_target(target_path: str, action: str, manifests: list[dict[str, Any]], timeout: int = 30) -> dict[str, Any]:
    """Invoke the discovered target and normalize its output. Fail-open, like a recon adapter.

    Any failure — non-zero exit, timeout, unparsable stdout — returns `{"ok": False, ...}` rather
    than raising. A broken shim must degrade the audit to "target unreachable", never crash the
    coordinator that is supposed to be watching for drift.
    """
    # Every `_`-prefixed key is discover()'s internal stamp, not part of the documented stdin contract
    # — `_path` carries machine-local absolute paths the target has no business seeing. The strip is
    # core.declared_body, the one definition the writer uses too, so "which keys are derived" cannot
    # disagree between what goes to disk and what goes over the wire.
    payload = json.dumps({"manifests": [core.declared_body(m) for m in manifests]})
    try:
        proc = subprocess.run(
            [target_path, action],
            input=payload,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "rows": [], "error": str(exc)}

    if proc.returncode != 0:
        return {"ok": False, "rows": [], "error": (proc.stderr or "").strip() or f"exit {proc.returncode}"}

    try:
        result = json.loads(proc.stdout or "{}")
    except ValueError as exc:
        return {"ok": False, "rows": [], "error": f"malformed target output: {exc}"}

    if not isinstance(result, dict):
        return {"ok": False, "rows": [], "error": "target output was not a JSON object"}

    result.setdefault("ok", True)
    result.setdefault("rows", [])
    return result


def flatten_rows(manifests: list[dict[str, Any]]) -> list[dict[str, str]]:
    """One row per (chain, ref, status) triple across all manifests, byte-stable."""
    rows = [
        {
            "chain": _id_of(m),
            "ref": str(row.get("ref") or "").strip(),
            "status": str(row.get("status") or "").strip(),
        }
        for m in manifests
        for row in core.manifest_rows(m)
        if str(row.get("ref") or "").strip()
    ]
    return sorted(rows, key=lambda r: (r["ref"], r["chain"]))


def _id_of(manifest: dict[str, Any]) -> str:
    """A manifest's identity: the `_id` borg_core stamped, else the stem of the `_path` it was read from.

    The stem fallback is for a dict that carries a source path but no `_id` (a hand-built one); a dict
    with neither yields "", which `sync_borg` treats as "never came from disk". It must NOT read the
    retired top-level key: that is what made a manifest with none look anonymous and be skipped.
    """
    identity = str(manifest.get("_id") or "").strip()
    if identity:
        return identity
    return os.path.splitext(os.path.basename(str(manifest.get("_path") or "")))[0]


def _by_ref(rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    # First occurrence wins, same determinism rule as everywhere else in this pipeline.
    out: dict[str, dict[str, str]] = {}
    for row in rows:
        out.setdefault(row["ref"], row)
    return out


def merged_but_open(rows: list[dict[str, str]], recon_states: dict[str, str], copy_name: str) -> list[dict[str, Any]]:
    """Rows a copy marks `merged` that recon reports as still open.

    Reality is recon's item state, not either copy's own say-so — a copy can go stale the moment
    someone rebases or the PR reopens. This is the one finding `local_audit` can make with no
    network call to the target at all (PM11).
    """
    findings = []
    for row in rows:
        state = recon_states.get(row["ref"])
        if state is None:
            continue
        if row["status"].strip().lower() == "merged" and state.upper() in OPEN_STATES:
            findings.append(
                {
                    "kind": "merged_but_open",
                    "ref": row["ref"],
                    "copy_says": f"{copy_name} marks it merged",
                    "reality_says": f"recon reports {state}",
                }
            )
    return sorted(findings, key=lambda f: f["ref"])


def three_way_audit(
    borg_rows: list[dict[str, str]],
    target_report: dict[str, Any] | None,
    recon_states: dict[str, str],
) -> list[dict[str, Any]]:
    """PM7. Compare borg's copy, the target's copy (its own `plan` dry run), and recon reality.

    `target_report` is `None` when no target was discovered (PM9's personal-machine case) — the
    two-copy comparisons are skipped entirely and only the reality check against borg's own copy
    runs. `target_report["ok"] is False` (target discovered but unreachable) is reported as its own
    finding rather than silently degrading to the no-target case, because those are different
    failures a human needs to tell apart.

    Never resolves anything. Every finding names which side disagrees; nothing here picks a winner.
    """
    findings = merged_but_open(borg_rows, recon_states, "borg's copy")

    if target_report is None:
        return findings

    if not target_report.get("ok", False):
        findings.append(
            {
                "kind": "target_unreachable",
                "ref": "",
                "copy_says": "",
                "reality_says": target_report.get("error", "target dry run failed"),
            }
        )
        return sorted(findings, key=lambda f: (f["kind"], f["ref"]))

    target_rows = [
        {"ref": str(r.get("ref") or "").strip(), "status": str(r.get("status") or "").strip()}
        for r in target_report.get("rows", [])
        if str(r.get("ref") or "").strip()
    ]
    findings += merged_but_open(target_rows, recon_states, "the sync target's copy")

    borg_by_ref = _by_ref(borg_rows)
    target_by_ref = _by_ref(target_rows)

    for ref in sorted(set(borg_by_ref) - set(target_by_ref)):
        findings.append(
            {
                "kind": "present_only_in_borg",
                "ref": ref,
                "copy_says": "in borg's copy",
                "reality_says": "absent from the target",
            }
        )
    for ref in sorted(set(target_by_ref) - set(borg_by_ref)):
        findings.append(
            {
                "kind": "present_only_in_target",
                "ref": ref,
                "copy_says": "absent from borg's copy",
                "reality_says": "in the target",
            }
        )
    for ref in sorted(set(borg_by_ref) & set(target_by_ref)):
        b, t = borg_by_ref[ref]["status"], target_by_ref[ref]["status"]
        if b and t and b != t:
            findings.append(
                {"kind": "status_disagreement", "ref": ref, "copy_says": f"borg: {b}", "reality_says": f"target: {t}"}
            )

    return sorted(findings, key=lambda f: (f["kind"], f["ref"]))


def local_audit(manifests: list[dict[str, Any]], recon_states: dict[str, str]) -> list[dict[str, Any]]:
    """PM11's Stop-time form: borg's copy against recon state only. No subprocess, no network.

    Deliberately the ONLY audit path safe to run unattended at session end — it never invokes the
    discovered target's dry run (a `gh pr view` per row) and never invokes `sync`. Wiring this into
    the `Stop` hook is gated on `2026-08-11-attention-routing.md` landing; this function is what
    that hook will eventually call.
    """
    return three_way_audit(flatten_rows(manifests), target_report=None, recon_states=recon_states)


def recon_states_from(recon_items: list[dict[str, Any]]) -> dict[str, str]:
    """`{ref: state}` from a recon items list, first occurrence wins."""
    out: dict[str, str] = {}
    for item in recon_items:
        ref = str(item.get("ref") or "").strip()
        state = str(item.get("state") or "").strip()
        if ref and state:
            out.setdefault(ref, state)
    return out


def load_recon_items(path: str | None) -> list[dict[str, Any]]:
    """Items for the reality check. Accepts either a raw items list or a full recon/gather doc.

    Raises SystemExit with a named message on an unreadable or unparsable file — every other
    failure path in this module names itself, and a raw traceback here would be the one exception.
    """
    if not path:
        return []
    try:
        if path == "-":
            raw = sys.stdin.read()
        else:
            with open(path) as fh:
                raw = fh.read()
        doc = json.loads(raw)
    except (OSError, ValueError) as exc:
        raise SystemExit(f"coordinator: cannot read recon items from {path}: {exc}") from exc
    if isinstance(doc, list):
        return doc
    if isinstance(doc, dict):
        if isinstance(doc.get("items"), list):
            return doc["items"]
        by_project = doc.get("items_by_project")
        if isinstance(by_project, dict):
            return [it for items in by_project.values() for it in (items or [])]
    return []


def sync_borg(manifests: list[dict[str, Any]]) -> tuple[list[str], list[str]]:
    """Rewrite each manifest through borg's OWN native writer (`shell.write_manifest`).

    Returns `(written_paths, warnings)`. Each manifest is written back to ITS OWN file, in whichever
    root holds it (`.stacks/`, `.borg/chains/` or the legacy `.borg/programs/`), found from the `_path`
    discover() stamped onto it. The earlier design keyed a shared map by chain name — so two projects
    declaring the same name collapsed to one entry, and the loser's manifest was silently written into
    the OTHER project's directory (the exact multi-repo pattern S4 proposes: the same manifest landed
    in each owning repo). Keying per-manifest makes that overwrite structurally impossible; the
    duplicate-name condition itself is still surfaced as a named warning because two same-named
    manifests will fight over edges downstream, and only a human knows which is right. Idempotent:
    re-validates and rewrites atomically even when nothing changed.

    The writer persists the DECLARED body only: no `_id`, no `_path`, and no top-level key the author
    did not write.
    """
    written: list[str] = []
    warnings: list[str] = []
    seen: dict[str, str] = {}
    for manifest in manifests:
        chain = _id_of(manifest)
        project_dir = _project_dir_of(manifest)
        source_path = str(manifest.get("_path") or "")
        if not chain or not project_dir:
            # NAMED ONLY WHEN THERE IS SOMETHING TO NAME, and the distinction is deliberate.
            #
            # A manifest with NO `_path` never came from `discover` (which always stamps it), so it
            # is a caller's hand-built dict rather than a file on disk -- nothing was lost and
            # `test_a_manifest_with_no_path_stamp_is_skipped_not_raised` pins that silence.
            #
            # A manifest WITH a `_path` that `_project_dir_of` cannot resolve is the opposite: a real
            # file under none of the three manifest directories, dropped at exit 0. That is the
            # confident-empty shape this tree keeps removing, so it is reported.
            if source_path and not project_dir:
                warnings.append(f"skipped {source_path}: not under .borg/chains, .borg/programs or .stacks")
            continue
        if chain in seen and seen[chain] != source_path:
            # Keyed by SOURCE FILE, not project dir (opus round 2, finding 1): two files in the SAME
            # project declaring one id is just as real a contention as two projects — and the
            # in-place rewrite below is what stops the second one silently overwriting the first.
            warnings.append(
                f"chain {chain!r} is declared twice ({seen[chain]} and {source_path}) — "
                f"each file rewritten in place, but they will contend downstream"
            )
        seen.setdefault(chain, source_path)
        path, warning = _rewrite_in_place(manifest, project_dir, source_path)
        if warning:
            warnings.append(warning)
        else:
            written.append(path)
    return written, warnings


def _rewrite_in_place(manifest: dict[str, Any], project_dir: str, source_path: str) -> tuple[str, str]:
    """`(written_path, "")` or `("", warning)` for one manifest read from `source_path`.

    NO WRITE MAY REDUCE A MANIFEST'S ROW COUNT ON DISK. Whatever `discover` returned is written back
    below, so a manifest that reached here with rows removed in memory would permanently delete them,
    at exit 0, under "wrote N manifest(s)". `shell.discover` refuses such a file whole today; this
    guard makes the guarantee structural instead of dependent on that.

    The file is rewritten where it LIVES (`directory=` its own dirname, name = its own basename),
    never at a name derived from the chain id: a manifest whose filename differs from its id must not
    spawn a second copy, and a `.stacks/` manifest written under `.borg/chains/` would be declared in
    both roots, which the next read refuses by name. A manifest the writer refuses becomes a SYNC
    WARNING rather than a traceback; nothing is written for it.
    """
    on_disk = _rows_on_disk(source_path)
    in_memory = len(manifest.get("rows") or [])
    if in_memory < on_disk:
        return "", (
            f"refused to rewrite {source_path}: would reduce it from {on_disk} to {in_memory} row(s); "
            f"no write may drop a declared row"
        )
    try:
        written = shell.write_manifest(
            project_dir, manifest, os.path.basename(source_path), directory=os.path.dirname(source_path)
        )
    except shell.InvalidManifest as exc:
        return "", f"refused to rewrite {source_path}: {exc}"
    return written, ""


def _rows_on_disk(path: str) -> int:
    """How many rows the manifest file at `path` declares right now; 0 when it cannot be read as one."""
    try:
        with open(path, encoding="utf-8") as handle:
            rows = json.load(handle).get("rows")
    except (OSError, ValueError, AttributeError):
        return 0
    return len(rows) if isinstance(rows, list) else 0


def _project_dir_of(manifest: dict[str, Any]) -> str:
    """One manifest's project root from the `_path` discover() stamped onto it, or ""."""
    path = str(manifest.get("_path") or "")
    if not path:
        return ""
    # path = <project_dir>/{.borg/chains,.borg/programs,.stacks}/<name>.json
    #
    # ALL THREE NAMES, because this recovers a root by SPLITTING ON THE DIRECTORY NAME and the
    # directory has had more than one (AC7 renamed one, and `.stacks/` is the tool-neutral second
    # root). A single-name split against another name returns the WHOLE PATH unchanged -- `rsplit`
    # with no match yields the original -- so `sync_borg` would then treat the manifest file itself as
    # a project root and write outside the tree. That fails silently: the caller only checks
    # `if not project_dir`, and a non-empty wrong answer passes.
    for name in (".borg" + os.sep + "chains", ".borg" + os.sep + "programs", shell.STACKS_DIRNAME):
        marker = os.sep + name + os.sep
        if marker in path:
            return path.rsplit(marker, 1)[0]
    return ""


def cmd_list(args: argparse.Namespace) -> int:
    manifests, warnings = shell.discover(args.chains_dir)
    for w in warnings:
        print(f"  MANIFEST SKIPPED {w}", file=sys.stderr)
    for m in sorted(manifests, key=_id_of):
        print(f"{_id_of(m)}: {len(core.manifest_rows(m))} row(s)")
    print(f"{len(manifests)} chain(s), {len(warnings)} skipped")
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    manifests, warnings = shell.discover(args.chains_dir)
    for w in warnings:
        print(f"  MANIFEST SKIPPED {w}", file=sys.stderr)
    # PM6: plan exits non-zero only on malformed input — a refused MANIFEST is malformed input, a
    # directory-level note (absent project path in the registry sweep) is not, and neither is a stray
    # JSON file with no rows list, which is skipped with a named note. Either way the audit for every
    # valid manifest still runs and prints (PM2: one bad manifest must not blank the spine); the
    # file-level failure is reflected in the exit code AFTER the findings print. WHICH warnings are
    # fatal is `shell.refused_manifest_paths`, the one classifier `borg link` uses — not a second
    # one kept here, which is the reader/reader divergence AC7 exists to end.
    fatal = shell.refused_manifest_paths(warnings)
    if fatal:
        print(f"plan: {len(fatal)} malformed manifest(s) — see above", file=sys.stderr)

    borg_rows = flatten_rows(manifests)
    search_dirs = sync_target_search_dirs()
    target_path = discover_sync_target(search_dirs)

    target_report = None
    if target_path:
        target_report = run_target(target_path, "plan", manifests)
    else:
        print("plan: no publish target found — reporting against borg's copy alone", file=sys.stderr)

    recon_states = recon_states_from(load_recon_items(args.recon))
    findings = three_way_audit(borg_rows, target_report, recon_states)

    print(f"plan: {len(manifests)} chain(s), {len(borg_rows)} row(s), {len(findings)} finding(s)")
    if fatal:
        # On STDOUT, beside the findings it taints (opus round 3, finding 2): a malformed manifest's
        # rows never entered borg_rows, so any absent-from-borg finding may be a parse artifact, not
        # drift — and the stderr-only caveat vanished the moment stdout was redirected to a report.
        print(
            f"  CAVEAT: {len(fatal)} malformed manifest(s) skipped — 'absent from borg's copy' "
            f"findings may be parse artifacts, not drift; fix the manifest(s) first"
        )
    for f in findings:
        print(f"  {f['kind']}: {f['ref']} — {f['copy_says']} / {f['reality_says']}")
    return 1 if fatal else 0


def cmd_sync(args: argparse.Namespace) -> int:
    manifests, warnings = shell.discover(args.chains_dir)
    for w in warnings:
        print(f"  MANIFEST SKIPPED {w}", file=sys.stderr)
    # Refuse only on FILE-level refusals (a malformed manifest must never half-sync). Directory-level
    # notes — a registry row whose project is absent on this machine — leave nothing to half-write,
    # and refusing on them would make one stale registry entry veto the whole sync (PM9: the
    # personal machine must work with a different project set).
    fatal = shell.refused_manifest_paths(warnings)
    if fatal:
        print(f"sync: {len(fatal)} malformed manifest(s) — refusing to sync", file=sys.stderr)
        return 1

    written, sync_warnings = sync_borg(manifests)
    for w in sync_warnings:
        print(f"  SYNC WARNING {w}", file=sys.stderr)
    print(f"sync: wrote {len(written)} manifest(s) through borg's native writer")

    search_dirs = sync_target_search_dirs()
    target_path = discover_sync_target(search_dirs)
    if not target_path:
        print("sync: no publish target found — borg's copy alone was synced", file=sys.stderr)
        return 0

    result = run_target(target_path, "sync", manifests)
    if not result.get("ok", False):
        print(f"sync: target dispatch failed — {result.get('error', 'unknown error')}", file=sys.stderr)
        return 1
    print(f"sync: dispatched to {os.path.basename(target_path)} ({len(result.get('rows', []))} row(s) reported)")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    for name, fn in (("list", cmd_list), ("plan", cmd_plan), ("sync", cmd_sync)):
        sp = sub.add_parser(name)
        sp.add_argument(
            "--chains-dir",
            "--programs-dir",  # legacy spelling; accepted until the contract phase drops it
            dest="chains_dir",
            action="append",
            default=[],
            metavar="PROJECT_DIR",
            help="project root to sweep for .stacks/*.json and .borg/chains/*.json (repeatable)",
        )
        if name == "plan":
            sp.add_argument(
                "--recon",
                default=None,
                metavar="PATH",
                help="a recon/gather JSON doc (or - for stdin) to check reality against; "
                "omit to skip the reality check",
            )
        sp.set_defaults(fn=fn)

    args = p.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    raise SystemExit(main())
