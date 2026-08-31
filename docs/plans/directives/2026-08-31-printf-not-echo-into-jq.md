# Directive: `printf '%s'`, not `echo`, into every `jq` in the zsh tree
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: (none — this is the tail of PR [#176](https://github.com/noah-goodrich/borg-collective/pull/176)'s
scope boundary, filed rather than absorbed)*
*Filed: 2026-08-31*

**tl;dr** — zsh's `echo` expands backslash escapes, so `echo "$json" | jq` re-injects a raw control character into a
JSON string literal and `jq` refuses to parse it. Under `set -e` the enclosing function dies mid-way with nothing on
stdout. **33 live sites survive in `borg.zsh` across six functions, plus 5 in `lib/desktop.zsh`.** `cmd_status` is the
one with a reproduced user-facing failure. The fix is one substitution per line and `lib/registry.zsh` already uses it.

## Why this exists

`borg_registry_get_with_state` emits compact JSON. A registry value containing a newline is serialized as the two
characters `\` `n`. zsh's builtin `echo` expands that back into a real 0x0A **inside the quoted string literal**, which
is exactly what JSON forbids, and `jq` says so:

```
jq: parse error: Invalid string: control characters from U+0000 through U+001F must be escaped at line 2, column 7
```

**Reproduced, not reasoned about.** With a registry carrying `"summary": "top\nbottom"` and no `tmux_window`:

```zsh
XDG_CONFIG_HOME=$D BORG_DIR=$D/borg BORG_REGISTRY=$D/borg/registry.json \
  zsh -c 'set -- help; source ./borg.zsh; cmd_status alpha'
# → the parse error above, EXIT=5, no project detail printed
```

`cmd_status` is not a corner: `_borg_do_switch` calls it on both of its no-window arms, so **`borg switch` to any
project that has no registered tmux window lands there.** `_borg_do_switch`'s own comment already says this in the
tree — *"the fallback arm is still broken and that is deliberate ... reaches `warn` + `cmd_status` — which carries
the identical `echo ... | jq` and dies there, exit 5"* — which is the point of this directive: it was measured,
written down beside the code, and then had nowhere to live.

**Why only two sites were fixed before.** PR [#176](https://github.com/noah-goodrich/borg-collective/pull/176)
converted `cmd_ls` and `_borg_do_switch` and stopped there, deliberately and with the boundary stated in both
functions' comments: that round's scope was the fzf picker's feed and its immediate consumer. Fixing `cmd_ls` alone
would have shipped half a fix — a working picker whose selection crashed the switch — so both halves went together
and nothing else did. That was the right call for that round. It is not a reason for the other 38 to stay.

**The live sites, re-derived rather than copied.** Regenerate with:

```zsh
awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{fn=$1} /echo .*\| *jq/{ if ($0 !~ /^ *#/) print NR": "fn}' borg.zsh
awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{fn=$1} /echo .*\| *jq/{ if ($0 !~ /^ *#/) print NR": "fn}' lib/desktop.zsh
```

| file | function | live sites |
|---|---|---|
| `borg.zsh` | `cmd_status` | 7 |
| `borg.zsh` | `cmd_scan` | 6 |
| `borg.zsh` | `cmd_next` | 9 |
| `borg.zsh` | `cmd_tidy` | 4 |
| `borg.zsh` | `_borg_orchestrator_context` | 3 |
| `borg.zsh` | `cmd_cortex_resume` | 4 |
| `lib/desktop.zsh` | `borg_desktop_scan` | 5 |
| | **total** | **38** |

**NO LINE NUMBERS ARE RECORDED HERE.** The two `awk` invocations above are the list; a transcribed table of 38
integers is stale on the next insertion and this repo has the receipts for what that costs (see
`2026-08-31-retire-the-line-pin.md`). `grep -c 'echo .*| *jq' borg.zsh` returns 37 and four of those are prose about
the bug — the `awk` filter is what separates them.

**One entry on the tree's own list has already rotted.** `_borg_do_switch`'s comment names
`_borg_print_briefing` among the survivors. It is not one any more: the `--brief` fold rewrote that function around a
single `printf '%s' "$doc" | jq` projection. The comment was correct when written and nothing re-derives it.

## Solution

Replace `echo "$x" | jq` with `printf '%s' "$x" | jq` at all 38 sites. That is the whole change.

- **`printf '%s'` is the repo's existing idiom**, not a new convention: `lib/registry.zsh` uses it for exactly this
  reason, and `cmd_ls`/`_borg_do_switch` were converted to it in
  PR [#176](https://github.com/noah-goodrich/borg-collective/pull/176).
- **It is behaviour-preserving for every value that is already clean**, which is why this is mechanical: `printf '%s'`
  and `echo` differ only on backslashes and on the trailing newline, and `jq` does not care about the latter.
- **`cmd_status` goes first and gets the regression test**, because it is the only one of the six with a reproduced
  end-user path (`borg switch <project-with-no-window>`).

## Non-goals

- **Changing what `lib/registry.zsh`'s `_borg_registry_write` scrubs.** Its control-character set deliberately
  EXCLUDES 0x0A, and `borg_core/link/render.py::_flatten_summary` enumerates why. Widening the scrub would be a
  data-model change made to work around a quoting bug, and it would not help a hand-edited registry anyway.
- **Auditing `echo` outside a `jq` pipe.** Every `echo -e` writing to a terminal is fine; the defect is `echo` feeding
  a JSON parser.
- **Moving any of these functions into `borg_core`.** Several of them should eventually go (`cmd_next` and
  `_borg_orchestrator_context` both re-derive things the document already carries) but that is an architecture change
  and this is a quoting fix. Do not couple them: a 38-line mechanical diff is reviewable and a rewrite is not.
- **Migrating `lib/desktop.zsh` off its own registry walk.** Same reason.

## Alternatives considered

**`setopt no_bsdecho` / `disable echo` at the top of `borg.zsh`.** Rejected. It fixes the tree by changing a global
shell option, so the next `echo | jq` written by anyone — in a hook, in `drone.zsh`, in a project's `borg-hooks` —
is still broken, and the reason it works here becomes invisible. The failure this repo keeps filing is a check
pointed at the wrong thing; a global option is a fix pointed at the wrong thing.

**`print -r --` instead of `printf '%s'`.** Correct in zsh, and rejected only because `printf '%s'` is what the
repo already uses and what `lib/borg-hooks.sh` can also use — the same spelling works in bash, so one idiom covers
both halves of the tree.

**Fix `cmd_status` only, since it is the one measured failure.** Rejected as the primary path, on this directive's own
evidence: `_borg_do_switch` was fixed one round ago precisely because fixing one end of a two-function path shipped
half a fix. `cmd_next` runs on the `Ctrl+Space >` hotkey and `_borg_orchestrator_context` runs on every `borg init`;
neither has been reproduced failing, but neither is less reachable than `cmd_status` was before someone tried it.

**Wait for evidence that the others actually fail.** Explicitly rejected — this repo's memory file already carries
"hardwire, don't wait for evidence" as a ratified position, and the cost of the fix is one substitution per line.

## Acceptance criteria

- [ ] `awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{fn=$1} /echo .*\| *jq/{ if ($0 !~ /^ *#/) print NR": "fn}' borg.zsh`
      prints nothing, and the same command against `lib/desktop.zsh` prints nothing. Comment lines that DISCUSS the
      bug are allowed to survive and the filter already excludes them.
- [ ] A bats case drives `cmd_status` against a registry whose `summary` carries an embedded newline and asserts
      exit 0 with the project detail rendered. **The mutation that must turn it red is restoring `echo` on that one
      line** — verify it, do not assume it, because a fixture whose summary has no newline passes either way and
      that is this repo's most-repeated test defect.
- [ ] A second bats case covers the reachable user path end to end: `_borg_do_switch` against a project with NO
      `tmux_window` and a newline-carrying summary exits 0 rather than 5. This is the case that would have caught
      the shipped defect; the unit case above would not have.
- [ ] `_borg_do_switch`'s survivor comment is re-derived rather than edited around: `_borg_print_briefing` is no
      longer on it (the `--brief` fold already converted that function), and the comment names the `awk` command
      instead of a list that nothing regenerates.
- [ ] `make test`, `make lint` and `bats tests/` all exit 0, checked by exit code and not by reading output.
