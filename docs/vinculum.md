# Vinculum — the cross-session message bus

`borg vinculum` (alias `borg vinc`) is a file-based publish/subscribe broker for passing messages between concurrent
sessions on one machine. It is how a tmux pane running one project tells a pane running another project something,
without a human copying text between windows.

It is the one borg subsystem with no entry in the command tables in `README.md`, `docs/architecture.md`, or
`docs/cheatsheet.md`. It *is* in `borg help`. This document is the reference.

---

## Why it exists, and what shape it has

The design is recorded in four decision records under `.borg/knowledge/decisions/`, all dated 2026-06-30. The short
version, carried forward rather than re-derived:

- **There is no broker process.** Messages are an append-only JSONL log per channel; each subscriber owns a cursor
  file recording how far it has read. From `20260630-vinculum-file-based-broker`: *"A central broker process is a
  single point of failure — if it crashes, all subscribers lose messages. File-based append-only logs are crash-safe
  by nature; cursor files per subscriber give N-subscriber fan-out without coordination. The filesystem IS the
  broker."*
- **It is called vinculum, not link.** `20260630-vinculum-name-final`: `link` collides with `borg link`, and
  *vinculum* (Latin: bond) is unique in the namespace.
- **`pub` encodes with `jq`, never with hand-rolled shell escaping.** `20260630-vinculum-jq-json-encoding` records
  that the first implementation escaped by hand and silently mangled quotes and backslashes. If you touch `pub`, keep
  the `jq -nc` call.
- **`install.sh` must symlink the watcher.** `20260630-vinculum-install-symlink`: the initial ship omitted the
  symlink, so `sub` spawned `borg-vinculum-watch` by bare name, PATH resolution failed, and live delivery silently
  did nothing on real installs while tests passed. The symlink is now `install.sh:112`.

The later research in `docs/research/2026-09-10-cross-machine-messaging/recommendation.md` proposes a **cross-machine**
successor and explicitly keeps this shape: *"Per-subscriber cursor files, exactly like `vinculum` — that shape is
already proven."* Two differences are worth knowing before you rely on vinculum for anything important, because the
research names them as the gaps it intends to close:

1. **Vinculum's cursors are not ack-gated.** They advance when a message is read or delivered, not when the receiver
   confirms it understood anything. The proposed successor advances only on acknowledgement.
2. **You cannot wake a running Claude Code session from outside.** The research's central finding applies here too:
   `tmux send-keys` into a busy pane queues, and a pane sitting at a permission prompt can swallow delivered text as
   the yes/no answer. Vinculum has no liveness gate — it sends regardless.

Vinculum is single-machine. Nothing in it reaches the network.

---

## The verb surface

```
borg vinculum [--as <label>] <verb> [args]     # alias: borg vinc
```

`--as` may appear anywhere in the argument list — it is scanned out before the verb is chosen. With no verb at all,
the verb defaults to `ls`.

| Verb | Arguments | What it does |
|------|-----------|--------------|
| `pub` | `<channel> <msg...>` | Append one message to the channel log. All trailing words join with single spaces. |
| `sub` | `<channel>` | Subscribe this identity, set its cursor to the current end of the log, and spawn a live watcher. |
| `unsub` | `<channel>` | Kill the live watcher and drop this identity from the subscriber list. |
| `ls` | `[channel]` | With no channel: every channel with message and subscriber counts. With one: its subscribers, unread counts, and watcher state. |
| `pull` | `<channel> [--json]` | Print everything after the cursor, then advance the cursor to the end. |
| `help` | — | The built-in usage block. |

Any other verb is a hard `die` pointing at `borg vinculum help`.

### Subscriber identity

Every verb resolves a **subId** before doing anything, in this order:

1. `--as <label>` — an explicit label wins.
2. `$TMUX_PANE` with the leading `%` stripped, as `pane-<n>` — e.g. pane `%7` becomes `pane-7`.
3. `host-$$` — the shell's PID, when there is no tmux pane and no label.

This matters more than it looks. A subId derived from a pane is **not stable across tmux restarts**: a new pane gets
a new `%n`, so a resubscribe leaves the old subscriber and its cursor orphaned in the channel. If you want a
subscription that survives, subscribe with an explicit `--as`.

### Examples

```bash
borg vinc pub deploys "reveal migration applied, ingle is clear to deploy"
borg vinc sub deploys
borg vinc ls
borg vinc ls deploys
borg vinc pull deploys
borg vinc pull deploys --json | jq -r '.from + ": " + .body'
borg vinc --as orchestrator sub deploys
borg vinc --as orchestrator unsub deploys
```

`ls` with no channel prints one row per channel:

```
  deploys                     14 msgs   2 subs
```

`ls <channel>` prints one row per subscriber, with the unread count and the watcher's liveness taken by `kill -0` on
the recorded PID:

```
  pane-7                              0 unread  running (PID 48120)
  orchestrator                        3 unread  stopped (was PID 47991)
```

---

## On-disk layout

Everything lives under `${XDG_DATA_HOME:-$HOME/.local/share}/borg/vinculum`. Both `borg.zsh` and
`bin/borg-vinculum-watch` compute that path independently with the same expression, so overriding `XDG_DATA_HOME`
moves both.

```
$XDG_DATA_HOME/borg/vinculum/
└── <channel>/
    ├── log.jsonl                  append-only, one JSON object per line
    ├── subscribers                one subId per line
    ├── cursors/
    │   └── <subId>                a single integer: lines of log.jsonl already consumed
    ├── meta/
    │   └── <subId>                {"pane":"%7","pid":48120}
    └── watch-<subId>.log          the watcher's stdout+stderr, appended
```

A channel is created implicitly by the first `pub` or `sub`; there is no create verb and no delete verb. Removing a
channel means removing its directory by hand.

**`log.jsonl` line shape**, written by a single `jq -nc` call in `pub`:

```json
{"id":"9f1c...","ts":"2026-09-11T14:02:11Z","from":"pane-7","body":"reveal migration applied"}
```

- `id` — `uuidgen`, lowercased.
- `ts` — UTC, `%Y-%m-%dT%H:%M:%SZ`.
- `from` — the publisher's subId.
- `body` — the joined message words.

**Cursors are line counts, not byte offsets.** A cursor of `12` means "the first 12 lines of `log.jsonl` are
consumed"; readers resume at line 13 via `sed -n '13,$p'`. Both the CLI and the watcher write cursors
temp-file-then-`mv`, so a torn write cannot leave a half-written cursor.

**The log is never truncated or rotated.** Nothing in the code trims `log.jsonl`, and cursors are absolute line
numbers — so truncating a log by hand silently strands every cursor past the new end, and those subscribers will read
nothing until the log grows past their old position again.

---

## The poller: `bin/borg-vinculum-watch`

```
borg-vinculum-watch <channel> --pane <tmuxPane> --as <subId> [--once]
```

It is not a launchd agent and you do not normally start it yourself. `borg vinc sub` spawns it with `nohup … &`,
`disown`s it, and records `{"pane":…,"pid":…}` in `meta/<subId>`. `install.sh` symlinks it onto `PATH` so that bare-name
spawn resolves.

What it does:

- Watches `<channel>/log.jsonl` with **`fswatch -o`**. If `fswatch` is not on `PATH` it logs an error and exits 1 —
  live delivery has a hard dependency on it. (`--once` processes whatever is pending and exits without touching
  `fswatch`; that mode is what the tests and demos use.)
- On each change, reads every line past the subscriber's cursor and, for each message:
  - **Drops self-echo.** If `.from` equals this subId, the cursor advances and nothing is delivered.
  - **Flattens the body.** Embedded `\n` and `\r` collapse to spaces, so one message is always one `send-keys` line.
  - **Delivers** as `tmux send-keys -t <pane> -l "[vinculum:<channel> ← <from>] <body>"` followed by a separate
    `send-keys … Enter`. The cursor advances only after a successful send.
  - **Gives up on a dead pane.** If `send-keys` fails, it logs `pane gone?` and **exits 0** — so a watcher whose pane
    was closed disappears quietly, and `borg vinc ls <channel>` will show its subscriber as `stopped (was PID …)`.

Rate limiting, all in the watcher:

- At most `VINC_RATE_MAX_PER_MIN` deliveries (default **30**) per rolling 60-second window. On hitting the cap it
  sleeps out the remainder of the window **without advancing the cursor**, then resumes — messages are delayed, never
  dropped.
- A minimum gap between sends: if the previous send was less than a second ago it sleeps 0.5s first.

Environment:

| Variable | Default | Effect |
|----------|---------|--------|
| `XDG_DATA_HOME` | `$HOME/.local/share` | Root of the vinculum tree. |
| `VINC_RATE_MAX_PER_MIN` | `30` | Deliveries per 60s window. |
| `DRY_RUN` | unset | Print `WOULD-SEND -t <pane>: <msg>` instead of calling tmux. **The cursor still advances.** |
| `BORG_PATH_PREFIX` | unset | Prepended to the `PATH` the watcher rebuilds for itself at startup. |

Note the `PATH` rebuild on line 17: the watcher overwrites `PATH` with a fixed list (plus `BORG_PATH_PREFIX`) because
it is spawned detached from a session whose environment it cannot rely on. If `fswatch`, `jq`, or `tmux` live
somewhere outside that list, set `BORG_PATH_PREFIX`.

---

## Gotchas

- **`sub` outside tmux is pull-only.** With no `$TMUX_PANE`, `sub` warns and registers the subscriber without a
  watcher. Messages accumulate; `pull` is the only way to see them.
- **`sub` is idempotent on the watcher, not on the cursor.** It will not re-spawn a watcher whose recorded PID is
  still alive, but it *always* rewrites the cursor to the current end of the log. Re-running `sub` on a channel with
  unread messages discards them.
- **`pull` advances the cursor even when it prints nothing.** It writes the current total unconditionally, so a `pull`
  against a channel you have never subscribed to marks all existing messages as read for your subId.
- **`pull` and a live watcher share one cursor.** They race: whichever reads first advances it and the other sees
  nothing. Use one or the other per subId.
- **`pull` without `--json` prints only `.body`** — no sender, no timestamp. Use `--json` to get the full envelope.
- **A message is a tmux line, not a prompt.** Delivery types text into a pane and presses Enter. If that pane is at a
  permission prompt, the text can be consumed as the answer — the cross-machine research flags exactly this path as
  unsafe and gates it in the proposed successor. Vinculum does not gate it.
- **`ls` counts with `wc -l`**, so a final line without a trailing newline is not counted. Everything vinculum writes
  ends in a newline, but a hand-edited log can skew the counts.
- **Unknown flags are not rejected.** `pull` scans its arguments for `--json` and takes the first non-`--json` token
  as the channel; `pub` treats every word after the channel as body text. There is no strict flag parser here, unlike
  `borg chain`.

---

## Unverified

Stated plainly rather than guessed at:

- **Whether anything in borg publishes to vinculum automatically.** No hook, skill, or launchd plist in this
  repository was found calling `borg vinculum` or `borg vinc`; every message in the channels appears to be
  hand-published. If an automatic publisher exists it lives outside this repo.
- **Concurrent-writer safety of `log.jsonl`.** The design relies on append-only writes from `jq … >> log`. Short
  appends from multiple publishers are in practice atomic on a local filesystem, but nothing in the code takes a lock,
  and no test in this repo exercises simultaneous publishers.

## See also

- `.borg/knowledge/decisions/20260630-vinculum-*.md` — the four design decisions.
- `docs/research/2026-09-10-cross-machine-messaging/recommendation.md` — the cross-machine successor, and why
  ack-gated cursors and a liveness gate are the two things this design lacks.
- [`chain.md`](chain.md) — the other subsystem that is live but thinly documented.
