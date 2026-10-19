#!/usr/bin/env bats
# `borg next --line` (doorways S4, AC4): ONE line, at most 80 columns, read from a cache and never computed.
#   * the cache is `<state root>/next-glance`, `<epoch>\t<line>`, written by whoever computed the rows
#   * a missing or old cache never answers confidently (the three-state rule: never `nothing waits` unlooked)
#   * the reader forks no Python, so its time is zsh's start-up, bounded here at p95 over 20 runs
#   * the line names the first row of the board's WAITING ON YOU, from the same `borg next --rows` rows

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    mkdir -p "$XDG_STATE_HOME/borg" "$BORG_DIR"
    CACHE="$XDG_STATE_HOME/borg/next-glance"
    NOW=$(date +%s)
    LINE="▶ merge #440 · borg-collective · 4 waiting"
}

_cache() { printf '%s\t%s\n' "$1" "$2" > "$CACHE"; }

@test "line: a fresh cache prints the cached line as written" {
    _cache "$NOW" "$LINE"
    run zsh "$BORG" next --line
    [ "$status" -eq 0 ]
    [ "$output" = "$LINE" ]
}

@test "line: a cache with no registry still answers (no registry read, no Python)" {
    rm -f "$BORG_REGISTRY"
    _cache "$NOW" "$LINE"
    run zsh "$BORG" next --line
    [ "$status" -eq 0 ]
    [ "$output" = "$LINE" ]
}

@test "line: a missing cache says nobody looked, never that nothing waits" {
    run zsh "$BORG" next --line
    [ "$status" -eq 0 ]
    [ "$output" = "borg: not looked yet · run borg next" ]
    [[ "$output" != *"nothing waits"* ]]
}

@test "line: a garbled cache is treated as missing" {
    printf 'not-a-number\t%s\n' "$LINE" > "$CACHE"
    run zsh "$BORG" next --line
    [ "$output" = "borg: not looked yet · run borg next" ]
    printf '%s\t\n' "$NOW" > "$CACHE"
    run zsh "$BORG" next --line
    [ "$output" = "borg: not looked yet · run borg next" ]
}

@test "line: an old cache keeps its line but marks the age" {
    _cache "$(( NOW - 2220 ))" "$LINE"
    run zsh "$BORG" next --line
    [ "$output" = "$LINE · 37m old" ]
    _cache "$(( NOW - 7300 ))" "$LINE"
    run zsh "$BORG" next --line
    [ "$output" = "$LINE · 2h old" ]
}

@test "line: a cache older than 12 hours drops the answer and prints a neutral line" {
    _cache "$(( NOW - 3 * 86400 ))" "$LINE"
    run zsh "$BORG" next --line
    [ "$output" = "borg: board 3d old · run borg next" ]
    [[ "$output" != *"merge"* ]]
}

@test "line: a cache stamped in the future is not trusted" {
    _cache "$(( NOW + 9999 ))" "$LINE"
    run zsh "$BORG" next --line
    [[ "$output" == "borg: board time is in the future"* ]]
}

@test "line: the stalest printable line still fits 80 columns" {
    local long="▶ $(printf 'x%.0s' {1..66})"
    _cache "$(( NOW - 43000 ))" "$long"
    run zsh "$BORG" next --line
    [ "${#output}" -le 80 ]
}

@test "line: p95 over 20 runs is within 100 ms" {
    _cache "$NOW" "$LINE"
    # One python process times 20 child runs, so the clock costs nothing inside a sample; the 19th of 20 sorted is p95.
    run python3 -c '
import subprocess, sys, time
samples = []
for _ in range(20):
    start = time.perf_counter()
    subprocess.run(["zsh", sys.argv[1], "next", "--line"], stdout=subprocess.DEVNULL, check=True)
    samples.append((time.perf_counter() - start) * 1000)
print(int(sorted(samples)[18]))' "$BORG"
    [ "$status" -eq 0 ]
    echo "p95=${output}ms" >&3
    [ "$output" -le 100 ]
}

@test "line: --line takes no other arguments" {
    run zsh "$BORG" next --line --switch
    [ "$status" -ne 0 ]
}

# Two waiting sessions, found through the state overlay with --local (no network). Row order is the ranking's, and
# the board's WAITING ON YOU prints the very same rows, so whichever repository comes first there comes first here.
_two_waiting() {
    local now n
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    for n in alpha beta; do
        mkdir -p "${BATS_TEST_TMPDIR}/p/$n/.borg"
        printf '{"status":"waiting","last_activity":"%s","waiting_reason":"needs you"}' "$now" \
            > "${BATS_TEST_TMPDIR}/p/$n/.borg/state.json"
    done
    cat > "$BORG_REGISTRY" <<JSON
{"repositories": {
  "alpha": {"path":"${BATS_TEST_TMPDIR}/p/alpha","status":"idle","tmux_window":"alpha"},
  "beta":  {"path":"${BATS_TEST_TMPDIR}/p/beta","status":"idle","tmux_window":"beta"}
}}
JSON
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    printf '#!/usr/bin/env bash\ncase "$1" in has-session) exit 0;; list-windows) echo alpha; echo beta;; list-panes) echo "0 %%1";; display-message) echo mock;; *) exit 0;; esac\n' > "$MOCK_BIN/tmux"
    chmod +x "$MOCK_BIN/tmux"
}

@test "parity: borg link writes a line naming the board's first WAITING ON YOU row and its count" {
    _two_waiting
    run bash -c "NO_COLOR=1 zsh \"$BORG\" link --overview --local 2>/dev/null"
    [ "$status" -eq 0 ]
    local board_first
    board_first=$(printf '%s\n' "$output" | sed -n '/WAITING ON YOU/,$p' | grep '▶' | head -1)
    run zsh "$BORG" next --line
    [ "$status" -eq 0 ]
    [ "$output" = "▶ reply to session · alpha · 2 waiting · local" ]
    [[ "$board_first" == *"alpha"* ]]
}

@test "line: borg next --rows is not a writer (it cannot see manifest decisions)" {
    _two_waiting
    run bash -c "zsh \"$BORG\" next --rows --json --local 2>/dev/null"
    [ "$status" -eq 0 ]
    [ ! -e "$CACHE" ]
}

@test "line: a repository page does not write the cache (it looked at one directory, not the board)" {
    _two_waiting
    run bash -c "cd '${BATS_TEST_TMPDIR}/p/alpha' && zsh \"$BORG\" link --local 2>/dev/null"
    [ ! -e "$CACHE" ]
}
