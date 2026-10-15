# borg_core/recon/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md.

- **Recon fan-out (`borg recon --json` + `/borg-recon`)**: source-agnostic sweep primitive.
  **Retired as a human verb 2026-08-26** — `borg link` folds the same fan-out into its own document,
  so bare `borg recon` (and any invocation without `--json`/`--adapters`) dies with a pointer at
  `borg link`. The gate lives in `borg_core/recon/cli.py::main()`, guarding the `_run()` call on
  `args.json_only or args.adapters` — the artifact that implements the command owns the invariant,
  not its zsh caller. `borg.zsh`'s `recon)` arm is a pure pass-through plus the two things argparse
  doesn't do (`--list` alias, unknown-flag `die`). See
  `docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md` for why it moved there.
  The engine (`borg_core/recon/{core,shell,cli}.py`) resolves a `since` mark (explicit >
  newest checkpoint mtime > last-run marker > 24h), fans out concurrently+bounded over pluggable
  **adapters**, normalizes every finding to an Item
  `{project,source,ref,title,state,changed,owner,action_needed,urgency,one_line}`,
  merges by repository (the Item's `project` key), and detects checkpoint-blocker-vs-resolved-source contradictions. An adapter is
  ANY executable named `recon-adapter-<source>` on `BORG_RECON_ADAPTER_PATH` (config dir shadows the
  repo dir) — dropping a file registers a source, no code change. Sources are NEVER hardcoded: employer
  adapters (Slack/Jira/Notion) are a separate machine-injected layer; this repo ships ONE reference
  adapter (`lib/recon/adapters/recon-adapter-github`, via `gh`). `borg recon --json` emits the
  reconciled doc the `/borg-recon` skill synthesizes into a by-repository, most-urgent-first, ELI10
  briefing + Yours(human)-vs-Mine(agent) action lists + a bounded read-only kickoff batch. zsh gotchas
  baked in: never a `path` loop var (tied to `$PATH`); quoted `find`, not bare globs (zsh NOMATCH is
  fatal); jq `//` treats `false` as empty (use `if has("ok")`, not `.ok // true`).

