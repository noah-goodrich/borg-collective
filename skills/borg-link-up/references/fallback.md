# Fallback: the prepared block is missing or says `STATUS: fallback`

Read only when STATUS says fallback or the prepared block is missing. Moved verbatim from SKILL.md. The six extension paths it names are in extensions.md.

If the `STATUS` line says `fallback: <reason>`, or the block is missing, use any field the block did print and gather the rest the legacy way, keeping every rule above:

1. Extensions: run `borg checkpoint-prepare --cwd <the session's working directory>` once with the Bash tool and use the extension fields it prints (the verb tests the six exact paths, prints `not present` for an absent one, and works outside Git). If that verb is unavailable too, check the six exact paths in ONE Bash call (`ls` the paths, ignoring errors) and Read only those it lists. NEVER Read a path you have not just confirmed exists, and NEVER Glob or Grep to discover extensions (not the home directory, not `.config`): a failed Read or a 120-second scan for an absent optional file is the defect of issue 454. Absent files are a silent no-op.
2. Repository root: `git rev-parse --show-toplevel`, else the directory holding `PROJECT_PLAN.md`, else the cwd.
3. If `PROJECT_PLAN.md` or `docs/plans/PROJECT_PLAN.md` exists, find the borg source dir with `command -v borg | xargs readlink -f | xargs dirname` and run the engine once: `BORG_PLANSTATE_SUITE_TIMEOUT=120 PYTHONPATH=<that dir> python3 -m borg_core.planstate.cli <plan> --json --apply`.
4. Manifest: `PYTHONPATH=<that dir> python3 -m borg_core.manifest.cli resolve --repository <root>` (any non-zero exit is a no-op), `gh pr view --json number,url --jq '"\(.url)"'` for the ref, then `add-row` as above.
5. Run `borg checkpoint-name` via the Bash tool and use its literal stdout, unmodified, as the stem. Check `test -e <root>/.borg/checkpoints/<stem>.md`; if it exists, append -2, -3 and so on until it does not.
6. Write once to that path, then the closing reply as above.
