# Directive: Preserve the cheat-sheet research captures
*Filed: 2026-10-16 · Status: Accepted 2026-10-16 · Owner: Noah*

**tl;dr** — The source cards in `docs/research/2026-10-03-cheat-sheet-design/sources/` point at 11 snapshot files that were never committed, so those pointers dangle. One docs-only PR commits those 11 snapshots plus the raw captures and adapter drafts that sit beside them, byte for byte, and keeps out anything that is generated, superseded or not fetched from the web.

- Plan-slug: `2026-10-16-preserve-research-captures`

## Problem

- **Dangling pointers.** Eleven source cards cite `docs/research/snapshots/<name>.txt` as the text their quotes were checked against. Main has the cards and not the files.
- **Unreproducible record.** The raw fetches (`drafts/raw/`) and the adapter drafts (`drafts/adapter/`) behind the cards were left untracked in an old working copy and would be lost with it.
- **Byte fidelity.** A capture is evidence only if it is stored unchanged. The repository normalises line endings on commit, which would silently alter captured pages.

## Solution

One PR, docs only, no code change.

1. Copy every untracked capture to the same relative path with `cp -p`, content untouched.
2. Add a `.gitattributes` that marks the three capture trees `-text`, so line endings are stored as fetched.
3. Skip what is generated (`__pycache__`, `*.pyc`), what main already holds as a later edit (adapter stub cards promoted to final cards in `sources/`), and any material that did not come from a public web fetch.
4. Check that every snapshot path named in a source card now resolves.

## Non-Goals

- No edits to any capture or to the existing source cards, which say the snapshots are not committed. Correcting that sentence is a follow-up.
- No re-fetch, re-extraction or re-scoring of sources.
- No change to the research conclusions.

## Alternatives Considered

- **Commit only the 11 cited snapshots.** Smallest diff, but drops the raw `.bin` originals and the adapter record that the extractions came from.
- **Reuse the stale research branch.** Its tracked files are all superseded by main and merging it would revert later edits.
- **Leave the files local.** Cheapest, and the pointers stay broken.

## Acceptance criteria

- [ ] Every snapshot path cited in `docs/research/2026-10-03-cheat-sheet-design/sources/` exists in the tree.
  - Verify: `git grep -h -o -E 'docs/research/snapshots/[A-Za-z0-9._-]+\.txt' -- docs/research/2026-10-03-cheat-sheet-design/sources | sort -u` lists 11 paths, each of which `test -f` accepts.
- [ ] Captured bytes match the originals.
  - Verify: `git check-attr text docs/research/snapshots/s1-ancker-2017-alert-fatigue.txt` reports `unset`, and `git hash-object --no-filters` of a committed file equals the blob in the index.
- [ ] No generated files are added, and the only paths outside `docs/research/` are `.gitattributes`, this directive and its stack manifest.
  - Verify: `git diff --name-only origin/main...HEAD | grep -E '__pycache__|\.pyc$'` prints nothing.
