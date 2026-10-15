# borg_core/extensions/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md.

- **Local extensions — the canonical reference is `docs/extensions.md`**, which supersedes the
  summary that used to live here. Two layers, read in order, missing files skipped silently:
    1. `~/.config/borg/extensions/<kind>/<subject>/<hook>.md` (per machine)
    2. `<repository>/.borg/<kind>/<subject>/<hook>.md` (per repository)
  `<kind>` is `skill-extensions` or `agent-extensions`. Markdown only, no executable scripts. Keep
  them terse — they load on every invocation of their subject.
  **Skills get three hook points** (`01-context` before work, `02-output` before the artifact,
  `03-followup` after it): `borg-plan`, `borg-assimilate`, `borg-link-up`, and `borg-review` —
  except `borg-review` has **no `03-followup` on purpose**, because its whole contract is to end on
  exactly ONE action and a post-recommendation hook invites a second. The three names are generic
  positions, not planning-specific moments, which is why the same three fit a planning conversation
  and a shipping checklist; `borg-assimilate` was the worked precedent for that before the loader
  was generalized.
  **Agents get ONE**, and a different noun. `borg-nanoprobe` reads
  `agent-extensions/borg-nanoprobe/brief.md` before its scope gate. An agent has no phases — it has
  a brief consumed once at spawn, a scope gate and a return contract, so there is no "before the
  artifact" moment to hook and two more load points would be seams nothing sits at. **The scope gate
  is NOT extensible**: an extension may add instructions, never widen what the agent may touch,
  raise its deliverable ceiling, or relax bounded termination. **One sanctioned exception**: the
  MACHINE-layer `- Prefer-tool:` may name the Skill target for step 3 (opening the PR) only, gated by
  `hooks/borg-nanoprobe-guard.sh`, which also denies nanoprobe writes under `borg/extensions/`.
- **THE SHIM LAYER: two tiers, one direction.** borg composes with an employer plugin layer through
  exactly two sockets, and which socket a shim belongs in is decided by whether it MUST happen or
  merely shapes judgment.
    1. **Executable adapters — fire by construction.** Any executable named `recon-adapter-<source>`
       on `BORG_RECON_ADAPTER_PATH` registers a source; `borg_core/recon/shell.py` globs for them and
       takes the source from the filename, config dir shadowing repo dir. No code change registers a
       source. This repo ships exactly one, `lib/recon/adapters/recon-adapter-github`.
    2. **Prose extensions — model-discretionary.** `docs/extensions.md` is the reference. They are
       markdown injected into a skill or an agent, which puts them back in the ~70-90% band where a
       model may or may not comply. `hooks/borg-prefer-tool-log.sh` exists because of that band.
  **Anything that MUST happen ships as an executable adapter; anything that shapes judgment ships as
  a prose extension.** That distinction was implicit until 2026-09-17 and is the reason a shim can
  silently be the wrong kind — a prose file asked to guarantee something is a request, not a gate.
  **THE DIRECTION IS ONE-WAY: borg reaches down for employer shims; the employer plugin never
  reaches up for borg.** A teammate with zero borg installed must see a working employer plugin, so
  a borg reference inside the employer tree is a portability defect, not a convenience. The
  employer-side grep that guards this was measured incomplete on 2026-08-31 — it covered two paths
  and missed `commands/`, where the only leak lived, and printed `ok zero borg coupling` while the
  leak shipped. **Closed 2026-09-18** (`addon-plugins` `fix/close-borg-leak-in-plugins`): the grep
  covers the whole `plugins/` tree, the leak is portable "do a design pass" prose in `triage.md`, and
  the borg half is `~/.config/borg/extensions/skill-extensions/borg-plan/01-context.md` on the work
  machine only. The widened grep excludes `__pycache__`, because Python 3.14 embeds the checkout's
  absolute path in every `.pyc` and a checkout under `~/.local/state/borg/worktrees/` failed the
  check on its own bytecode. A shim is closed by an ABSENT FILE, never by a `command -v borg` probe:
  a probe hands teammates a dead code path they will eventually delete, and an absent file is
  invisible.

- **`prefer-tool` extensions, and the one precedence rule**: a file carrying `- Prefer-tool:`
  declares "use tool X instead of the default" (`- Instead-of:` names the default, `- Requires:`
  names `command:<n>` or `skill:<plugin>:<n>` that must exist). Everything without that key is
  prose, so every pre-existing extension parses unchanged. Keys are anchored on the leading `- `,
  because an extension file is prose that will often DISCUSS its own keys and an unanchored match
  returns the sentence doing the discussing — the same hazard as `- Plan-slug:`.
  Precedence is ONE rule, not a per-type exception: **the layer that owns the fact wins.** Repository
  policy is the repository's, so prose keeps the existing repo-wins behaviour; the environment is the
  machine's, so `prefer-tool` inverts it and the MACHINE layer wins. This repo is public and was
  history-scrubbed once for employer references, so a checked-in file must never override a personal
  machine's tool choice. A future type inherits the rule by answering: who owns the fact?
  **It advises in prose and never redirects a call** — silently rewriting what runs would break
  "skills propose, the developer validates" and its failure mode would be invisible. Escalation, if
  advice proves insufficient, is a `PreToolUse` WARNING (the surface `bash-guard.sh` occupies),
  never a rewrite. An absent tool degrades to the default **loudly once**: `borg doctor` prints dead
  and unprobed preferences in yellow and does **not** fail over them, because a preference naming a
  plugin this machine lacks is a normal state and a check that cries wolf gets ignored. A
  `prefer-tool` file with no parseable `- Requires:` is reported `unprobed`, **not** live — it opted
  out of being checked and must not read as working.
  **The oracle measures BYPASSES ONLY.** `hooks/borg-prefer-tool-log.sh` (PostToolUse/Bash) logs to
  `~/.config/borg/prefer-tool.jsonl` when a shell command matches a LIVE preference's
  `- Instead-of:`. Invoking the preferred *skill* is not a Bash call, so compliance events are
  unobservable there; nothing computes a ratio, because calling this a "compliance rate" would be
  the same overclaim as a gate that passes by measuring nothing. It exists at all because the cairn
  entry below measured what uninstrumented voluntary compliance is worth. The hook delegates to
  `borg_core.extensions.cli` rather than reimplementing precedence in bash (a second reader is the
  divergence AC7 ends), resolves the package script-relative or via `$BORG_ROOT`, and **no-ops when
  neither is present** — so an empty log in a plugin-only install means "not instrumented", not
  "no bypasses".
