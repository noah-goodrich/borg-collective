#!/usr/bin/env bats
# S3 SWEEP-FOLD GATES — the tests that count subprocesses rather than reading comments.
#
# `borg link` acquired network cost in S3. Everything in this file exists because the ONLY thing
# that made the first-pass design unsafe was a stale comment claiming the fzf preview was already
# protected (the hardened spec's B1). So nothing here asserts intent; every case counts what was
# actually forked.
#
# EVERY NO-SWEEP ASSERTION IS PAIRED WITH A CONTROL. tests/test_helper/setup.bash now points
# BORG_RECON_ADAPTER_PATH at an empty directory, so a bare "zero gh subprocesses" assertion is
# vacuously green everywhere in this suite — it would pass with `--local` deleted entirely. The
# fixture here deliberately restores the REAL shipped adapter and a REAL git checkout with a REAL
# github origin, so the sweep genuinely CAN reach `gh`, and the control run proves it does.
#
# WHY A MOCK `gh` AND NOT A REAL ONE. Counting invocations, not observing processes: an orphaned
# `gh` from a previous test can outlive its parent (the adapter is bash, and a SIGKILL on the
# adapter does not reach its grandchildren), so "no live gh process" would be flaky where "the
# trace file is empty" is not.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

# Captured in the FILE BODY, which bats evaluates before setup() runs — so this is the real HOME,
# before setup_temp_dirs redirects it into the sandbox. Read by exactly one test: the opt-in latency
# gate, which is meaningless against a fixture registry (see its own comment).
REAL_HOME="$HOME"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
}

# A registered repository the shipped github adapter will genuinely try to sweep, plus a `gh` that
# records every call. Four things all have to be real for the control to mean anything:
#   - a real `git init` + `origin` on github.com, because recon-adapter-github derives the repo slug
#     from `git remote get-url origin` and emits SWEPT=0 (exiting before `gh`) without one;
#   - the real shipped adapter on BORG_RECON_ADAPTER_PATH, overriding setup_temp_dirs' empty dir;
#   - a real registry entry carrying that path, because the sweep's project list is derived from the
#     registry and nothing else;
#   - the real `jq`, which is why only `gh` is mocked.
#
# THE MOCK `gh` RETURNS A REAL ALIASED PAYLOAD, not just `viewer`. The first version returned
# `{"data":{"viewer":{"login":"tester"}}}` with no repository node, so the adapter's jq projection
# produced ZERO items — and the case named "states come from the sweep" asserted only that a sweep
# had happened, never that a swept state reached a node. `r0` is the alias the adapter assigns the
# first (here, only) repository line, and `updatedAt` is generated at call time rather than hard-coded
# so it can never drift outside the sweep window and turn this into a silent skip six months from now.
_sweepable_repo() {
    local dir="${BATS_TEST_TMPDIR}/ws/sierra"
    mkdir -p "$dir"
    git init -q "$dir"
    git -C "$dir" remote add origin "https://github.com/testorg/sierra.git"

    # A manifest declaring two refs in this repository: one the sweep will answer for (#1) and one it
    # will not (#2). That contrast is what makes the resolve ladder observable end to end.
    mkdir -p "$dir/.borg/programs"
    cat > "$dir/.borg/programs/sierra-stack.json" <<'EOF'
{"program":"sierra-stack","rows":[
  {"order":"1","ref":"testorg/sierra#1","status":"stacked","why":"the trunk"},
  {"order":"2","ref":"testorg/sierra#2","status":"open","why":"the next one"}
]}
EOF

    cat > "$BORG_REGISTRY" <<EOF
{"projects":{"sierra":{"path":"$dir","status":"idle","last_activity":"2026-08-01T00:00:00Z"}}}
EOF

    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export GH_TRACE="${BATS_TEST_TMPDIR}/gh-trace.txt"
    : > "$GH_TRACE"
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_TRACE"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat <<JSON
{"data":{"viewer":{"login":"tester"},
 "r0":{"pullRequests":{"nodes":[
   {"number":1,"title":"the trunk PR","state":"MERGED","isDraft":false,"updatedAt":"$NOW",
    "url":"https://github.com/testorg/sierra/pull/1","headRefName":"t","baseRefName":"main",
    "author":{"login":"tester"}}
 ]}}}}
JSON
EOF
    chmod +x "$MOCK_BIN/gh"

    export BORG_RECON_ADAPTER_PATH="${BATS_TEST_DIRNAME}/../lib/recon/adapters"
}

# ── B1: the opt-down, counted ─────────────────────────────────────────────────

@test "sweep: borg link --local spawns zero gh subprocesses, and the same call without it sweeps" {
    _sweepable_repo

    run zsh "$BORG" link --local sierra
    [ "$status" -eq 0 ]
    run cat "$GH_TRACE"
    [ -z "$output" ]

    # THE CONTROL. Same fixture, same cwd, same registry, one flag different. Without it, "zero gh
    # subprocesses" above proves only that nothing could have run.
    : > "$GH_TRACE"
    run zsh "$BORG" link sierra
    [ "$status" -eq 0 ]
    run cat "$GH_TRACE"
    [ -n "$output" ]
    [[ "$output" == *"graphql"* ]] || false
}

@test "sweep: --local reports itself in the document instead of silently doing nothing" {
    # An opt-down that leaves no trace is indistinguishable from a sweep that found nothing. Both
    # render an empty grid; only one of them is correct.
    _sweepable_repo

    run zsh "$BORG" link --json --local sierra
    [ "$status" -eq 0 ]
    # ONE joined string, not three lines: `.grid.since` is "" on this path and bats' $lines drops
    # empty elements, so a line-indexed assertion would silently read the NEXT field and pass.
    run bash -c "printf '%s' '$output' | jq -r '[.grid.swept, .grid.since, (.grid.warnings | length > 0)] | @tsv'"
    [ "$output" = "$(printf 'false\t\ttrue')" ]
}

@test "sweep: the swept document carries a grid whose states come from the sweep" {
    # THE TITLE IS NOW WHAT THE CASE ASSERTS. It used to assert only `.grid.swept`, `.scope_kind` and
    # `.slug` against a mock `gh` that returned no repository node at all, so not one byte of swept
    # state was ever checked — the whole zsh-side path from adapter stdout through the Item validator
    # to a node's `state` was unasserted, in the file whose header says it counts things rather than
    # reading comments.
    _sweepable_repo

    local doc="${BATS_TEST_TMPDIR}/swept.json"
    zsh "$BORG" link --json sierra > "$doc"
    run jq -r '[.grid.swept, .grid.scope_kind, .grid.slug, (.grid.since | length > 0)] | @tsv' "$doc"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'true\trepository\ttestorg/sierra\ttrue')" ]

    # (The `--since` argv the adapter is actually handed is asserted in borg_core/link/test_grid.py,
    # not here: the shipped adapter applies the mark in its own jq projection and never puts it in
    # the `gh` command line, so GH_TRACE cannot see it.)

    # #1 came off the wire: state, provenance AND the PR's own title, which no manifest row carries.
    run jq -r '[.grid.manifests[0].nodes["testorg/sierra#1"]
                | .state, .state_source, .title] | @tsv' "$doc"
    [ "$output" = "$(printf 'merged\tswept\tthe trunk PR')" ]

    # #2 was not in the sweep's answer, so it falls to the rung below — and the grid says how many
    # refs are in that position rather than leaving it to a per-node field.
    run jq -r '[.grid.manifests[0].nodes["testorg/sierra#2"].state_source,
                (.grid.declared|tostring), (.grid.unresolved|tostring)] | @tsv' "$doc"
    [ "$output" = "$(printf 'declared\t2\t1')" ]

    run jq -r '.grid.sources[0] | [.source, .status, (.count|tostring), (.dropped|tostring)] | @tsv' "$doc"
    [ "$output" = "$(printf 'github\tok\t1\t0')" ]
}

@test "sweep: an unreachable gh degrades the grid loudly instead of reporting a clean empty sweep" {
    # THE SHAPE THAT SHIPPED SILENT. `gh` missing, unauthenticated, offline or rate-limited all route
    # through the adapter's `emit_skip`, which prints a VALID track and exits 0 — so `ok` stays true,
    # and before the contract carried `skipped` the document said `swept: true`, one `ok` source,
    # `warnings: []`, while every state in the grid came from a hand-authored manifest field. A wrong
    # answer with a confident header, which is the class this whole front door exists to remove.
    _sweepable_repo

    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_TRACE"
echo "gh: not authenticated" >&2
exit 1
EOF
    chmod +x "$MOCK_BIN/gh"

    local doc="${BATS_TEST_TMPDIR}/degraded.json"
    zsh "$BORG" link --json sierra > "$doc"
    run jq -r '[.grid.swept, .grid.sources[0].status,
                ([.grid.warnings[] | select(test("could not reach its source"))] | length > 0)] | @tsv' "$doc"
    [ "$output" = "$(printf 'true\tdegraded\ttrue')" ]

    # And it degraded rather than blanking: the manifest's own declaration still renders.
    run jq -r '.grid.manifests[0].nodes["testorg/sierra#2"].state' "$doc"
    [ "$output" = "open" ]
}

# ── B2: drone status, the per-tmux-window loop ────────────────────────────────

@test "sweep: drone status triggers zero adapter and zero gh subprocesses" {
    # drone.zsh:964 shells to `borg link --local "$wname"` ONCE PER TMUX WINDOW, greping `Status:`
    # out of each one and swallowing every failure with `2>/dev/null || true`. Post-sweep an
    # unprotected loop there is N full network sweeps to render one status table, and the failures
    # would be invisible. `borg` here is the REAL borg.zsh, so this exercises the actual dispatcher
    # and the actual document build, not a stub.
    _sweepable_repo

    ln -sf "$BORG" "$MOCK_BIN/borg"
    export BORG_DRONE_EXTRA_PATH="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/tmux-trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS="sierra"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session)   [ "${TMUX_MOCK_HAS_SESSION:-0}" = "1" ] && exit 0 || exit 1 ;;
    list-windows)  printf '%s\n' "${TMUX_MOCK_WINDOWS:-}" ;;
    show-option)   printf '%s\n' "${BATS_TEST_TMPDIR}/ws/sierra" ;;
    *)             exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    run zsh "$DRONE" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"sierra"* ]] || false

    run cat "$GH_TRACE"
    [ -z "$output" ]
}

# ── B1/B2: the call sites, pinned by content rather than by line number ───────

@test "sweep: every looping borg-link call site carries --local" {
    # Line numbers drift; these greps do not. Each pattern is the whole invocation, so moving the
    # call keeps the test green and DELETING the flag turns it red — which is the only failure mode
    # that matters. The three hot sites are asserted in cli_contract.bats; these are the two the
    # first audit missed, plus the deployed-copy hazard.
    #
    #   bin/link-parity-harness  runs 3 fixed modes + one deep dive per registered project against
    #                            BOTH trees, so 34 invocations at 14 projects. It also byte-compares
    #                            a never-swept zsh oracle against the Python tree: a swept current
    #                            leg produces UNEXPECTED diffs on every run, and different ones each
    #                            time. `--local` is pinned at run_link, the single chokepoint, so
    #                            the two legs cannot drift.
    #   skills/borg-switch      buys the widest sweep in the system (`--all`) to produce a list of
    #                            names that comes straight off the registry.
    run grep -c -- '"link", "--local", \*args' "${BATS_TEST_DIRNAME}/../bin/link-parity-harness"
    [ "$output" -eq 1 ]

    run grep -c -- 'borg link --local --all' "${BATS_TEST_DIRNAME}/../skills/borg-switch/SKILL.md"
    [ "$output" -eq 1 ]

    # The harness's sandbox must also be hermetic on its own, because `--local` living in one place
    # is exactly one deletion away from being nowhere. A REAL empty directory, never "": recon's
    # adapter_search_path branches on `if override:`, so an exported-empty value is falsy and falls
    # back to the shipped adapter — the obvious neutralization silently does nothing.
    run grep -c 'BORG_RECON_ADAPTER_PATH.*no_adapters' "${BATS_TEST_DIRNAME}/../bin/link-parity-harness"
    [ "$output" -eq 1 ]
}

@test "sweep: the test harness neutralizes the adapter path with a real directory, not an empty string" {
    # THE TRIPWIRE FOR THE TRIPWIRE. If setup_temp_dirs' neutralization ever regresses to `=""`,
    # every link test in the suite silently starts shelling out to `gh` and the goldens start
    # byte-capturing live GitHub state — while staying green, because an empty value LOOKS
    # neutralized. Same trap CLAUDE.md records for BORG_REAP_STALE_HOURS.
    [ -n "${BORG_RECON_ADAPTER_PATH:-}" ]
    [ -d "$BORG_RECON_ADAPTER_PATH" ]
    run bash -c 'ls -A "$BORG_RECON_ADAPTER_PATH"'
    [ -z "$output" ]

    # And it really does suppress discovery, rather than merely looking empty.
    run zsh "$BORG" recon --adapters
    [[ "$output" != *"recon-adapter-github"* ]] || false
}

# ── AC1: --help answers without sweeping, and the lenient arm still sweeps ─────

@test "sweep: link --help spawns zero gh subprocesses, and an unknown flag still sweeps" {
    # `--help` fell into _borg_link_dispatch's lenient `-*)` arm until S4, was swallowed, and
    # rendered the swept overview -- 0.85s of network for a flag whose whole job is to print one
    # line. It has an explicit arm now, above `-*)` and returning before anything else runs.
    _sweepable_repo

    run zsh "$BORG" link --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: borg link"* ]] || false
    run cat "$GH_TRACE"
    [ -z "$output" ]

    # THE CONTROL, DOING TWO JOBS. It proves the fixture genuinely CAN reach `gh` -- without it the
    # assertion above passes with the fix deleted -- AND it proves the fix did not arrive by
    # teaching the lenient `-*)` arm to imply --local, which is the one repair the hardened spec
    # forbids and the one no stdout assertion anywhere in the suite can detect (`link beta` and
    # `link --local beta` are byte-identical on stdout; only a subprocess count sees the wire).
    : > "$GH_TRACE"
    run zsh "$BORG" link --totally-bogus
    [ "$status" -eq 0 ]
    run cat "$GH_TRACE"
    [ -n "$output" ]
    [[ "$output" == *"graphql"* ]] || false
}

# ── AC1: "No cache, ever — a clean read every time" ───────────────────────────

# PATH + SIZE + INODE for every non-directory, PATH ONLY for directories.
#
# NOT mtime, and that is a measurement rather than a preference. Two consecutive `borg link` runs
# finish inside the SAME SECOND, and BSD `stat -f %m` / `find -newer` are second-granular: a full
# tmp-file-plus-rename rewrite of registry.json between the two runs is BYTE-INVISIBLE at that
# resolution (measured: mtime identical, size identical, inode moved). The inode is the only field
# that sees it.
#
# DIRECTORY SIZE AND MTIME ARE EXCLUDED because they are legitimately volatile: $BORG_DIR's size
# moves as transient children come and go, and $TMPDIR's mtime bumps on every run from the
# `borg-link.XXXXXXXX` workdir borg_core/link/shell.py creates and removes. A directory that held a
# temp file for 200ms is not a cache; a file that SURVIVED the run is what this hunts.
#
# STATTED THROUGH python3, NOT `stat`, AND THAT IS A PORTABILITY BUG FIX RATHER THAN A STYLE CALL.
# The first version used `stat -f 'FILE %N %z %i'`, which is BSD. `bats tests/*.bats` runs on
# ubuntu-latest (.github/workflows/test.yml's `test` job) and this file is in it, while the macOS
# lane runs cli_contract.bats ONLY -- so the one platform that executes this case is the one where
# GNU coreutils reads `-f` as `--file-system`, swallows the format string as a file operand, and
# prints a five-line FILESYSTEM report carrying `Blocks: Total/Free/Available`. Measured in
# `docker run ubuntu:24.04`: zero lines match `^FILE `, the per-file blocks drift between two
# snapshots of an untouched tree, and the case dies outright at `set -e`. Exactly #114
# (cli_contract.bats's "guards #114" block) in a new place.
#
# A `stat -c ... || stat -f ...` chain -- borg.zsh's `_borg_file_mtime` idiom, GNU FIRST, never
# BSD-first -- would also work. python3 wins because it is one process for the whole root instead of
# one per file, and because borg already hard-depends on it (every `borg link` in this file forks
# borg_core), so it cannot be absent where this test can run at all. `os.lstat`, not `os.stat`: a
# symlink is a file that survived the run, and following it would report the target twice.
#
# The whole snapshot is `sort -u`'d at the end rather than per-`find`, because the roots below NEST
# ($BORG_DIR is inside $XDG_CONFIG_HOME) and a duplicated line would show up twice in the exact-
# equality diff at (2).
#
# ONE `find` PER ROOT, NOT TWO, and python does the dir/file split. An earlier version pre-filtered
# with `find -type d` and `find ! -type d`, walking every tree twice for a classification os.lstat
# already has to make. The classification must stay lstat-based rather than os.walk-based: `find`
# with no `-type` tests the LINK, so a symlink pointing at a directory is a non-directory here and
# must land in the FILE branch. os.walk would put it in `dirnames` and silently change what this
# helper reports. Emits on STDOUT so the caller redirects -- the out-param plus truncate plus
# sort-to-temp plus `mv` was four moving parts for what is one pipeline.
#
# MEASURED, AND THERE IS MORE ON THE TABLE THAN THIS TOOK. At fixture scale the cost is the per-root
# PROCESS TAX (~30ms of python3 startup, ~5.5ms per `find`), not the directory walk (~1ms). Dropping
# the second `find` bought 194ms -> 144ms per snapshot (-26%). Collapsing to ONE python3 for ALL
# roots -- os.walk, sorted in-process, no `find` and no `sort` at all -- was measured at 34ms (-82%),
# about 480ms across the three snapshots this case takes. NOT taken here: os.walk puts a
# symlink-to-directory in `dirnames`, so that form has to re-derive the lstat classification above by
# hand or it silently reclassifies exactly the entry this helper is careful about. Worth doing when
# something else brings someone into this file; not worth the trap on its own.
#
# $BORG_DIR is nested inside $XDG_CONFIG_HOME in the harness, so it contributes no unique lines today
# and costs ~30ms per snapshot that `sort -u` then discards. It stays in the root list deliberately:
# the nesting is a property of setup_temp_dirs, not of borg, and a harness change that unnests them
# must not silently drop $BORG_DIR from what this case watches.
_fs_snapshot() {
    local root
    for root in "$@"; do
        [ -e "$root" ] || continue
        find "$root" -exec python3 -c 'import os, stat, sys
for p in sys.argv[1:]:
    try:
        st = os.lstat(p)
    except OSError:
        continue
    if stat.S_ISDIR(st.st_mode):
        print("DIR", p)
    else:
        print("FILE", p, st.st_size, st.st_ino)' {} + 2>/dev/null
    done | sort -u
}

@test "cache: two consecutive borg link runs write no cache artifact (AC1)" {
    _sweepable_repo
    local dir="${BATS_TEST_TMPDIR}/ws/sierra"

    # The temp root is isolated so it is both OBSERVABLE and un-polluted by anything else on the
    # machine. Honored by borg_core/link/shell.py's TemporaryDirectory. NOT honored by the adapter's
    # own `mktemp` (lib/recon/adapters/recon-adapter-github) -- BSD mktemp with no template uses the
    # darwin user temp dir regardless of $TMPDIR, so that file is outside this sandbox by
    # construction. It is not a cache (nothing reads it back) and it is not in scope here.
    export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
    mkdir -p "$TMPDIR"

    # $XDG_DATA_HOME AND $XDG_CONFIG_HOME ARE ROOTS TOO, and neither is reachable transitively:
    # setup() redirects XDG_DATA_HOME to a SIBLING of $HOME, and only $XDG_CONFIG_HOME/borg (=
    # $BORG_DIR) was listed. `${XDG_DATA_HOME:-$HOME/.local/share}/borg` is where borg already puts
    # data (install.sh's LOG_DIR, the vinculum store at borg.zsh:2699), so it is the conventional
    # place a future `borg link` memo lands -- and until it was listed here, a cache written there
    # left all four assertions below green. Measured: a `link-cache.json` write into
    # $XDG_DATA_HOME/borg passed; the identical write into $BORG_DIR failed.
    # $XDG_STATE_HOME and $XDG_CACHE_HOME need no entry: both are unset in this suite and default
    # under the redirected $HOME, which IS a root.
    local roots=( "$BORG_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$dir" "$TMPDIR" "$BORG_TEST_HOME" )

    # THREE SNAPSHOTS, NOT TWO. A cache is by definition something run 1 WRITES and run 2 READS, so
    # run 2 need not mutate anything: a single before/after pair collapses a cache into the same
    # bucket as one-time initialization. s0->s1 catches a run-1-written cache; s1->s2 catches a
    # per-run rewrite or an advancing mark.
    # `run`, not a capture to r1.out/r2.out that nothing ever read -- two artifacts a reader greps
    # for assuming they are evidence. The exit status was going unchecked too: a `borg link` that
    # died would have been caught only indirectly, by the gh-call count below, and reported as the
    # wrong failure.
    _fs_snapshot "${roots[@]}" > "${BATS_TEST_TMPDIR}/s0.txt"
    run bash -c "cd '$dir' && zsh '$BORG' link"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    _fs_snapshot "${roots[@]}" > "${BATS_TEST_TMPDIR}/s1.txt"
    run bash -c "cd '$dir' && zsh '$BORG' link"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    _fs_snapshot "${roots[@]}" > "${BATS_TEST_TMPDIR}/s2.txt"

    # ANTI-VACUITY GATE, FIRST, and it is also the "a clean tree is not a clean read" gate. Under
    # setup_temp_dirs' empty adapter dir the sweep short-circuits before any subprocess, so a tree
    # diff there inspects a code path that never ran; and even with the real adapter, a run 2 that
    # short-circuited on an in-process memo and reprinted run 1's answer would leave the tree clean
    # while doing no work. The count is EXACT, not `-ge 1`: one batched call PER RUN.
    run cat "$GH_TRACE"
    [ "${#lines[@]}" -eq 2 ]

    # ANTI-DEGENERACY GATE FOR THE SNAPSHOT ITSELF. Every assertion below is a comparison between
    # two snapshots, so a _fs_snapshot that emits nothing -- or emits a constant per file -- makes
    # all of them pass while seeing nothing. That is not hypothetical: it is precisely what the
    # BSD-only `stat -f` did on the ubuntu lane that runs this file. Name one file that MUST be in
    # the tree before run 1 and require it to carry a real size and a real inode.
    run grep -cE "^FILE ${BORG_REGISTRY} [0-9]+ [0-9]+$" "${BATS_TEST_TMPDIR}/s0.txt"
    [ "$output" = "1" ]

    # (1) RUN 2 CHANGED NOTHING AT ALL.
    run diff "${BATS_TEST_TMPDIR}/s1.txt" "${BATS_TEST_TMPDIR}/s2.txt"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }

    # (2) RUN 1's OWN WRITES ARE EXACTLY ONE DIRECTORY, NAMED HERE ON PURPOSE. The single expected
    # write is borg_desktop_init's `mkdir -p "$BORG_DIR/desktop"` (lib/desktop.zsh), reached from
    # the overview arm's desktop pre-pass. That directory is an INBOX for Claude Desktop session
    # reports written by another process; `borg link` only ever reads it. THE EQUALITY IS THE POINT
    # -- an allowlist would let a second, unnamed artifact ride in beside it, and the obvious
    # allowlist (`grep -v "$BORG_DIR"`) would exclude the one real cache in the tree.
    run bash -c "diff '${BATS_TEST_TMPDIR}/s0.txt' '${BATS_TEST_TMPDIR}/s1.txt' | grep '^[<>]'"
    [ "$output" = "> DIR ${BORG_DIR}/desktop" ]
    # (A bare `diff; [ "$status" -ne 0 ]` used to sit above this. It was entailed: an identical pair
    # yields empty grep output, which already fails the exact-equality on the next line.)

    # (3) NO FILE WAS CREATED ANYWHERE, IN EITHER RUN. This is the claim AC1 actually makes, stated
    # in its own terms rather than inferred from a diff. BE HONEST ABOUT WHAT IT ADDS TODAY: it is
    # ENTAILED by (1) and (2) as they currently stand -- s1 == s2 exactly, and the s0->s1 delta is
    # exactly one DIR line, which together already force FILE parity across all three snapshots. It
    # is kept as insurance against (2) being loosened later (an allowlist, a `grep -v`), which is the
    # edit most likely to happen to this case. It is NOT independent evidence: it reads the same
    # three snapshot files, so it cannot survive a regression in _fs_snapshot that (1) and (2) miss.
    run bash -c "grep -c '^FILE ' '${BATS_TEST_TMPDIR}/s0.txt'"
    local before_files="$output"
    run bash -c "grep -c '^FILE ' '${BATS_TEST_TMPDIR}/s2.txt'"
    [ "$output" = "$before_files" ]

    # (4) THE ONE NAMED ARTIFACT, WITH ITS CONTROL. $BORG_DIR/recon/last-run is a real cache:
    # recon's since-ladder reads it back and advances it on every sweep. `link` folds recon's
    # fan-out in but must never write it -- borg_core/link/shell.py's sweep() says so in prose, and
    # this is the executable half. S4 retires the recon VERB while keeping the ENGINE, so this is
    # exactly one careless refactor (routing a digest through link, reusing recon.cli._sweep) away
    # from becoming false.
    [ ! -e "${BORG_DIR}/recon/last-run" ]

    # THE CONTROL. Without it, `[ ! -e ... ]` is green on a machine where nothing could write it at
    # all. `borg recon --json` runs the same adapters over the same registry and DOES persist the
    # mark, so the assertion above is provably falsifiable. It runs LAST, after the GH_TRACE gate,
    # because it adds a third `gh` call.
    bash -c "cd '$dir' && zsh '$BORG' recon --json" >/dev/null 2>&1
    [ -e "${BORG_DIR}/recon/last-run" ]
}

# ── B9: the latency the whole plan is budgeted against ────────────────────────

@test "sweep: repository-scoped borg link holds its 2.7s median (BORG_LINK_PERF=1)" {
    # GATED, DELIBERATELY. A wall-clock assertion against a live `gh` is not deterministic enough for
    # CI — it measures the network, the runner and GitHub's mood — so it is opt-in and skipped by
    # default. It is still a real gate: AC1's whole claim is that repository-scoped `link` stays
    # reflexive, the hardened spec's B9 exists because the first-pass arithmetic was wrong by ~1.5s,
    # and a claim with no executable check is how that arithmetic survived review.
    #
    #   Run it:  BORG_LINK_PERF=1 bats tests/link_sweep.bats
    #
    # MEDIAN OF THREE, not mean and not best: the mean is dragged by one slow run and the minimum
    # hides a bimodal distribution, which is exactly the shape an intermittently-slow auth path has.
    # It runs against the REAL adapter and the REAL registry, in the repository this checkout is, so
    # it measures the thing AC1 budgets rather than a fixture.
    [ -n "${BORG_LINK_PERF:-}" ] || skip "set BORG_LINK_PERF=1 to run the latency gate"
    command -v gh >/dev/null 2>&1 || skip "gh is not installed"

    # IT MUST ESCAPE THE SANDBOX ENTIRELY, and the first version of this test did not. setup_temp_dirs
    # redirects HOME, XDG_CONFIG_HOME, BORG_DIR, BORG_REGISTRY and BORG_RECON_ADAPTER_PATH at
    # fixtures; under those the sweep resolves an EMPTY registry, hands the adapter zero repositories,
    # and the adapter exits at its SWEPT=0 branch before it ever calls `gh`. Measured: 140ms, green,
    # and a complete lie about AC1. That is the `reference_test_supplies_derived_value` failure with a
    # stopwatch attached, so the guard below asserts a real sweep happened BEFORE anything is timed.
    export HOME="$REAL_HOME"
    unset XDG_CONFIG_HOME BORG_DIR BORG_REGISTRY BORG_RECON_ADAPTER_PATH BORG_PATH_PREFIX

    # A POSITIONAL, NOT THE BARE OVERVIEW, and that is a safety rule rather than a measurement one:
    # `--json` with no project runs borg_desktop_scan, which MERGES into the registry — here, the
    # user's real one. The deep arm never scans and never writes. It is also the right shape to
    # measure: the positional dominates cwd (B3), so this is repository scope by construction.
    # Through a FILE, not through `printf '%s' '$output' | jq`. That idiom is used elsewhere in the
    # suite and is safe only on apostrophe-free fixtures: this document carries real plan objectives
    # and checkpoint prose, and one apostrophe closes the shell quote and turns the guard into a
    # silent skip. It did, on the first run of this test.
    local doc="${BATS_TEST_TMPDIR}/perf.json"
    zsh "$BORG" link --json borg-collective > "$doc" 2>/dev/null || skip "no live borg registry here"
    run jq -r '[.grid.swept, (.grid.sources | length)] | @tsv' "$doc"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'true\t1')" ] || skip "nothing swept here — the gate would time an empty sweep"

    local -a samples=()
    local i start finish
    for i in 1 2 3; do
        start=$(date +%s%N)
        zsh "$BORG" link --json borg-collective >/dev/null 2>&1 || true
        finish=$(date +%s%N)
        samples+=( $(( (finish - start) / 1000000 )) )
    done

    local median
    median=$(printf '%s\n' "${samples[@]}" | sort -n | sed -n 2p)
    echo "samples(ms): ${samples[*]}  median=${median}ms" >&3
    [ "$median" -le 2700 ]
}
