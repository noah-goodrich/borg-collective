#!/usr/bin/env bats
# Oracles for bin/borg-pr-watch — the entry point both the launchd agent and the session cron use.

load test_helper/setup

WATCH="${BATS_TEST_DIRNAME}/../bin/borg-pr-watch"

setup() {
    setup_temp_dirs
    export BORG_DIR="${BATS_TEST_TMPDIR}/borg"
    export BORG_ROOT="${BATS_TEST_DIRNAME}/.."
    mkdir -p "$BORG_DIR"
}

@test "pr-watch: exits 0 and writes nothing when gh is unavailable" {
    # An allowlist bin dir holding only what the script needs, minus gh. Derived from the script's
    # own calls rather than by guessing which directories gh is absent from — the CI lane
    # preinstalls gh at /usr/bin, so a PATH-subtraction approach passes on macOS and fails on Linux.
    local bindir="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$bindir"
    for b in bash date dirname pwd mkdir printf grep python3; do
        src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$bindir/$b"
    done
    PATH="$bindir" run "$WATCH"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/pr-watch-delta.md" ]
}

@test "pr-watch: refuses to run without borg_core reachable" {
    export BORG_ROOT="${BATS_TEST_TMPDIR}/not-a-checkout"
    mkdir -p "$BORG_ROOT"
    run "$WATCH"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/pr-watch-delta.md" ]
}

@test "pr-watch: is READ-ONLY unless --apply is passed" {
    # The safety property that makes an unattended poster auditable. Asserted on the script's own
    # text because the apply flag is what gates every post: if this ever defaults to on, a human
    # running the script by hand to inspect it would post instead.
    grep -q 'APPLY=""' "$WATCH"
    grep -q '\[ "${1:-}" = "--apply" \] && APPLY="--apply"' "$WATCH"
    # Discriminates: no unconditional --apply anywhere in the file.
    ! grep -qE '^[^#]*--apply["'"'"']?\s*$' <(grep -v 'APPLY=' "$WATCH")
}

@test "pr-watch: the launchd plist is valid and does NOT run at load" {
    local plist="${BATS_TEST_DIRNAME}/../launchd/com.stillpoint-labs.borg.pr-watch.plist"
    [ -f "$plist" ]
    if command -v plutil >/dev/null 2>&1; then
        run plutil -lint "$plist"
        [ "$status" -eq 0 ]
    fi
    # RunAtLoad false: the first sweep is a cold start (silent by contract), and this is the one
    # agent that can post, so it must not fire during an install while the tree is mid-change.
    grep -A1 'RunAtLoad' "$plist" | grep -q 'false'
}

@test "pr-watch: install.sh does NOT arm the agent by default" {
    # It can post to GitHub under the user's account. An installer that silently arms an unattended
    # poster is not a choice the user made.
    local inst="${BATS_TEST_DIRNAME}/../install.sh"
    grep -q 'BORG_PR_WATCH_ENABLED:-0' "$inst"
    grep -q 'NOT armed (default)' "$inst"
}

@test "pr-watch: the plist polls on an interval that is not the :00 thundering herd" {
    local plist="${BATS_TEST_DIRNAME}/../launchd/com.stillpoint-labs.borg.pr-watch.plist"
    local interval
    interval=$(grep -A1 'StartInterval' "$plist" | grep -oE '[0-9]+' | head -1)
    [ -n "$interval" ]
    [ "$interval" -ge 300 ] || { echo "polling every ${interval}s is too aggressive"; false; }
}
