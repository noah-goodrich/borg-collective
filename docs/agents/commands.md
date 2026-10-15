# Command reference (borg and drone)

Reference moved verbatim from the top-level CLAUDE.md.

### Commands

```
borg init                Launch the Queen: morning briefing + Claude session
borg / borg next         What needs attention? Switch to it.
borg claude              Resume the Queen session (continue most recent)
borg link [repository]   ONE renderer, TWO pages, chosen by scope.kind
                           Queen root: the cross-repository overview
                           Inside a registered path: strictly that ONE directory's page
                             (AC2's "same spine" was reversed 2026-10-13)
                           Anywhere else: a short "not a registered repository"
                             hint (`borg add`, `borg link --overview`), exit 0
                             — and `--brief`, which prints prose instead
                           --overview Force the Queen view from any directory
                           --brief   Same document, same sweep, PROSE not the seven
                                     sections (AC1). Falls back to the real page.
                           --refresh Regenerate summaries
                           --all     Include archived repositories
                           --local   Opt down from the NETWORK sweep — no adapter, no `gh`. NOT
                                     "no subprocess": repository scope still forks one
                                     `git remote get-url origin` for the slug, because manifest
                                     selection cannot happen without it. cli._grid states it in TWO
                                     paragraphs, not one — "THE SLUG COSTS" and "`--local` IS
                                     CHECKED HERE" — and test_grid's
                                     test_local_forks_nothing_in_orchestrator_scope_and_only_the_slug_in_repository
                                     asserts the exact argv (verified by mutation: delete the fork
                                     and it goes red). The `tmux list-windows` every invocation pays
                                     is unaffected by the flag; it is gated by the reap overlay, not
                                     by the network. No hot loop is left behind it; the one
                                     automated caller is skills/borg-switch's
                                     `borg link --local --all --overview`
                           --json / --porcelain  the two machine surfaces
                           --deep    Parsed and IGNORED since AC2; kept for borg.zsh's positional
                                     `link` arm, the one live caller (`_link_py_args=(--deep)`)
borg switch [query]      fzf picker → tmux window switch
borg scan                Auto-discover from session history
borg add [path] [--name <n>]  Register a repository (a re-add keeps an existing `tmux_window`; a path
                         already registered under another name is a no-op, or exit 1 with --name)
borg rm <repository>     Unregister
borg focus               Zoom current pane / repository window
borg pin / unpin         Pin (or unpin) a repository to the top of borg link
borg window <p> [short]  Show or set a repository's short tmux window name (registry `tmux_window`)
borg reap / reap-worktrees  Reap stale active/waiting statuses; clean stale nanoprobe worktrees
borg recon --json        Machine surface only: reconciled sweep JSON (bare `recon` retired; use link)
borg recon --adapters    List the source adapters discovered on this machine
borg nanoprobes (np)     List recent ephemeral subagent runs
borg nanoprobe-log <id>  Fetch the transcript/summary for a nanoprobe run
borg spend               Summarize accurate token spend from ~/.claude/token-spend.jsonl
borg doctor              Environment/dependency health check
borg setup               Install/refresh hooks, skills, agents, tmux keybinding
                           NOT launchd — plists are installed by install.sh only, which calls
                           `borg setup` at the end. A new launchd job needs an install.sh run.
borg store-secret        Patch a repository's secrets.zsh with a new keychain export
borg down                Tear down everything: windows, containers, shared stacks (`sever` retired)
borg tidy                Housekeeping pass over registry/checkpoints; `--cairn-leftovers [--dry-run]`
                           backs up then deletes cairn's machine-local files
borg color / image       Cosmetic repository registry fields (tmux color, session image)
borg version             Print BORG_VERSION
borg help                Full command reference

drone up [repository]        Start container + tmux window
drone down [repository]      Stop container + remove window
drone claude [repository]    Launch Claude in repository window
drone cortex [repository]    Launch Cortex Code in repository window
drone sh [repository]        Shell into container
drone exec [repository] -- <cmd>
                             Run a command inside the devcontainer
                             (never on host)
drone restart [repository]   Restart container
drone rebuild [repository]   Rebuild + restart container
drone fix [repository]       Repair a broken container/window state
drone feature <repository> <branch>
                             Create a git worktree on <branch> + open
                             its dev window/container
drone toggle [repository]    Toggle the optional 3rd side pane (2 ↔ 3)
drone pane <direction>       Split the calling pane
                             top|bottom|left|right (devcontainer-aware).
                             Two panes per window: with a side pane open
                             it reuses that pane, unzooms the window if
                             it is zoomed (so the pane is visible), and
                             prints its id
drone scaffold --supabase|--supabase-shared <dir>
                             Generate a devcontainer + borg-hooks for
                             Supabase
drone link                   Alias for borg link (this directory's page)
```

