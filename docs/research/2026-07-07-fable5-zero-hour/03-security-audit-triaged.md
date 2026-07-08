# Zero-Hour Security Audit — Triaged (cairn + bash-guard)

Generated: 2026-07-07 · Reviewers: Sonnet (hostile, read-only) · Triage + fixes: Fable 5 (judgment layer)
Status: **findings triaged; fixes specified; NOT YET APPLIED.** Application is a reviewed nanoprobe job gated by
new `bats`/`pytest` regression tests (see "How to land these"). Do not merge a guard patch without the tests —
none of the bash-guard bypasses below are currently covered by `tests/bash_guard.bats`, so an unverified patch
could regress silently or over-block.

## ELI10

Two locks were checked. The **cairn** lock is a house key for a house with one resident — most "no lock on the
inner doors" findings are by-design for a local single-user tool, EXCEPT it currently leaves the *front door
open to the whole street* (binds to all network interfaces) and has a few *filing-cabinet bugs* where a
malicious note can overwrite a real one. The **bash-guard** lock is a real safety gate meant to stop dangerous
commands — and it has real gaps a determined command can slip through, including one where simply writing the
word `.borg-project` in your command waves it past every check. The guard gaps are the higher priority.

## bash-guard — HIGH PRIORITY (a security guardrail with real bypasses)

The guard is a defense-in-depth control; every bypass below is a real reachability gap. Triage keeps all 14
reader findings but ranks them by whether they *pre-approve* a command (worst — skips all later checks) vs merely
*fall through* to the normal allowlist (only dangerous if the allowlist already grants the binary).

### Tier A — pre-approval bypasses (fix first: these skip the classifier entirely)

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| A1 | `.borg-project` substring → unconditional `allow` (line 66) | **REAL, critical** | Anchor the match: only pre-approve when the command is a known borg-internal invocation shape, not any string containing `.borg-project`. Match on the *command/binary* (`borg`, `cat`/`ls` of a `.borg-project` path), not a bare substring. |
| A2 | `for f in *.borg/checkpoints/*` pre-approves the whole loop body (line 70) | **REAL, critical** | Do not pre-approve loop *bodies*. Drop the loop-prologue pre-approval entirely, or classify each command inside the body through the normal RO path. |
| A3 | Backtick `` `...` `` substitution bypasses the `$()` analyzer (line 295; `_strip_quotes` 79–81) | **REAL, high** | Extend the substitution scan to backtick spans; strip/inspect `` `...` `` the same as `$(...)`. |
| A4 | `find "-exec"` (quoted flag) stripped before the `-exec`/`-delete` check (79–81 vs 154) | **REAL, high** | Run the destructive-flag check on the *unstripped* command, or unquote-then-check rather than strip-then-check. |

### Tier B — matcher gaps that let a segment read as read-only

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| B1 | `\|` with no surrounding spaces not split (line 319) | **REAL, high** | Split on `\|` regardless of surrounding whitespace (match `[[:space:]]*\|[[:space:]]*`). |
| B2 | `&&`/`\|\|` with no spaces not split (line 314) | **REAL, high** | Same fix — make the whitespace optional around `&&`/`\|\|`, as `;` already is. |
| B3 | `sed -i''` / `sed --in-place` evade the `-i` regex (line 148) | **REAL, high** | Match `-i` followed by `'`/`"`/`=`/EOL and the long form `--in-place`. |
| B4 | `curl ... \| /bin/bash` (absolute shell path) evades `\| bash` (line 39) | **REAL, high** | Match `\|[[:space:]]*(/\w+/)?(ba)?sh\b` rather than the literal ` bash`/` sh`. |

### Tier C — Layer-1 literal-pattern gaps (equivalent-notation bypasses)

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| C1 | `rm -fr /`, `rm -Rf /`, `\rm`, `/bin/rm` evade `rm -rf /` (line 33) | **REAL, medium** | Normalize flags (sort/canonicalize `-rf`/`-fr`/`-Rf`) and match `rm` by basename, not literal prefix. |
| C2 | `git push --force origin 'main'` (quoted ref), `HEAD:main`, `refs/heads/main` (line 43) | **REAL, medium** | Match the ref after unquoting; match `\bmain\b`/`master` as a ref token, incl. `:main`/`refs/heads/main`. |
| C3 | `>> ~/.claude/settings.json` (append) not hard-blocked (line 45) | **REAL, medium** | Match `>>?[[:space:]]*~?/?.*\.claude/settings\.json`. |
| C4 | `rm -r ~/.claude` (no `-f`) not blocked (line 41) | **REAL, medium** | Match `rm` + `-r`/`-R` (with or without `f`) + `.claude`. |
| C5 | `chmod -R 0777` / `a+rwx` / `ugo+rwx` evade `chmod -R 777` (line 35) | **REAL, medium** | Match `chmod` + recursive + (`0?777` OR `[augo]*\+.*w.*x`). |

**Cross-cutting root cause:** the guard mixes literal-substring matching (`*"..."*`) with whitespace-sensitive
regex splitting. Both are brittle against normal shell equivalence (quoting, flag reordering, absolute paths,
whitespace). The durable fix is not 13 one-off patches but a **normalization pre-pass**: canonicalize the command
(unquote, collapse whitespace around operators, resolve binary basenames) ONCE, then run the existing checks on
the normalized form. Recommend one nanoprobe that (a) adds `_normalize_command`, (b) routes Layer 1 + Layer 3
through it, (c) narrows the two pre-approval shortcuts (A1/A2), and (d) adds a `bats` case per bypass above.

## cairn — MEDIUM PRIORITY (mostly design boundary; a few real integrity bugs)

**Judgment on the "zero auth" findings (reader marked critical):** cairn is explicitly a *local, single-user,
single-role* system (the no-RLS finding is informational-by-design). So "no auth on inner endpoints" is a design
boundary, NOT a critical bug — with ONE real exception:

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| K1 | `CAIRN_API_HOST` defaults to `0.0.0.0` (api.py:264) | **REAL, high (the one real exposure)** | Default to `127.0.0.1`; require an explicit opt-in env to bind `0.0.0.0`. On a shared Docker network, `0.0.0.0` exposes the unauthenticated graph to every sibling container. Cheap, high-value. |
| K2 | `record_document` `captured_at` upsert poisoning (service.py:286,310; db.py:233) | **REAL, medium (integrity)** | Reject/clamp future `captured_at`; ignore client-supplied `captured_at` for the conflict guard and use server `now()`, or cap it at `now()`. A far-future timestamp permanently wins the `>=` guard and silently drops real writes. |
| K3 | ID-squatting via `on_conflict_do_nothing` on session/decision/pattern/observation (db.py:110–186) | **REAL, low–medium** | For records whose id is a public value (esp. `record_session`), detect a pre-existing stub and either error or upsert real fields rather than silently no-op. |
| K4 | `record_feedback` dangling refs → pre-planted score manipulation (service.py:319; models_db.py:109) | **REAL, low** | Require the target record to exist at feedback time (existence check or deferred FK), or ignore feedback with no matching target in the retrieval subquery. |
| K5 | No `max_results` / body-size cap → DoS (mcp.py:71,282) | **REAL, low (local)** | Clamp `max_results` (e.g. ≤100) and cap `body` length before embedding. Cheap hardening. |
| K6 | Presence `presence_close` / `presence_related` no ownership check (api.py:216; service.py:367,410) | **DESIGN BOUNDARY** (local trust model) — fix opportunistically if presence goes multi-host: add a session-owner token. |
| K7 | `get_stats` f-string SQL `# noqa: S608` (db.py:372) | **FALSE POSITIVE (not injectable)** — table list is a compile-time constant. Keep as a maintenance note: don't copy the pattern with a dynamic table. |
| K8 | No RLS / tenant isolation in migrations | **DESIGN BOUNDARY** (single-user local) — informational; revisit only if cairn ever becomes multi-tenant. |

**Reader false-positive callouts I confirm:** the `list_*` SQL uses bound named params (no injection); search arms
pass user values as bound params (no injection); presence path fields don't trigger file I/O (no traversal). Good
hygiene already in place — the real cairn issues are integrity/DoS logic bugs, not injection.

## Remediation plan (severity × reachability)

1. **bash-guard normalization nanoprobe** (Tier A + B + C) — one worktree, `_normalize_command` pre-pass +
   narrow A1/A2 shortcuts + a `bats` case per bypass. Gate: `bats tests/bash_guard.bats` green including the new
   cases. This is the single highest-value security fix today.
2. **cairn K1 (bind 127.0.0.1 default)** — one-line default change + a test; closes the only real network
   exposure.
3. **cairn K2 (captured_at clamp)** — integrity fix; add a `pytest` case (DB-backed, so runs where Postgres is
   available). 
4. **cairn K3/K4/K5** — batch into one nanoprobe (write-path integrity + input caps) with pytest coverage.

## How to land these (gate-4 discipline — see the `fable-reviewer` skill)

Do NOT hand-edit the guard in the orchestrator. Dispatch a nanoprobe per item above; each must (a) apply the fix
in its own worktree, (b) ADD the regression test that fails before / passes after, (c) run the suite
(`bats tests/bash_guard.bats` or `pytest -q`) and paste the result, (d) open a PR. The exact fixes are specified
above; the judgment is done — application is now mechanical-with-tests, which is precisely a nanoprobe's job.
