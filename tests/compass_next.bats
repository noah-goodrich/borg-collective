#!/usr/bin/env bats
# The compass in `borg next` (ordering) and on the `borg link` human page (IN FOCUS, board suffix, WAITING ON YOU).
#
# Every map here is SYNTHETIC and lives under the sandbox; nothing reads a real map directory. Dates are chosen so
# the day the suite runs cannot change a state: a due date in 2000 is always late, one in 2997 or later is always
# on track, and a parking `look` date in 2000 is always due while one in 2999 never is. The map's own `today` is the
# real date, which is the only place the clock enters (the leg is read from log/<today>.md).

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_DIR"
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS="w-on-leg w-late w-soon w-far w-undated w-frozen w-unmapped"
    unset BORG_WORK_PROJECTS BORG_MAP_DIR
    _mock_tmux
    export MAP="${BATS_TEST_TMPDIR}/map"
}

# Same shared mock as tests/next_chooser.bats (logs every call to $TRACE).
_mock_tmux() {
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session)
        [ "${TMUX_MOCK_HAS_SESSION:-0}" = "1" ] && exit 0 || exit 1 ;;
    list-windows)
        printf '%s\n' $TMUX_MOCK_WINDOWS ;;
    list-panes)
        echo "0 %1" ;;
    display-message)
        echo "${TMUX_MOCK_CURRENT:-mock-window}" ;;
    *)
        exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"
}

_selected() {
    grep "tmux select-window" "$TRACE" | sed 's/.*-t borg://'
}

# Seven repositories, all waiting so each one is a row. Their activity runs OLDEST FIRST in the order the NO-MAP
# ranking prints them (waiting ties go to the oldest), which is the reverse of the compass order below.
_write_registry() {
    local name
    for name in on-leg late soon far undated frozen unmapped; do
        mkdir -p "${BATS_TEST_TMPDIR}/p/${name}"
    done
    cat > "$BORG_REGISTRY" <<JSON
{"repositories": {
  "unmapped": {"path":"${BATS_TEST_TMPDIR}/p/unmapped","status":"waiting","tmux_window":"w-unmapped","last_activity":"2026-01-01T10:00:00Z"},
  "frozen":   {"path":"${BATS_TEST_TMPDIR}/p/frozen","status":"waiting","tmux_window":"w-frozen","last_activity":"2026-01-02T10:00:00Z"},
  "undated":  {"path":"${BATS_TEST_TMPDIR}/p/undated","status":"waiting","tmux_window":"w-undated","last_activity":"2026-01-03T10:00:00Z"},
  "far":      {"path":"${BATS_TEST_TMPDIR}/p/far","status":"waiting","tmux_window":"w-far","last_activity":"2026-01-04T10:00:00Z"},
  "soon":     {"path":"${BATS_TEST_TMPDIR}/p/soon","status":"waiting","tmux_window":"w-soon","last_activity":"2026-01-05T10:00:00Z"},
  "late":     {"path":"${BATS_TEST_TMPDIR}/p/late","status":"waiting","tmux_window":"w-late","last_activity":"2026-01-06T10:00:00Z"},
  "on-leg":   {"path":"${BATS_TEST_TMPDIR}/p/on-leg","status":"waiting","tmux_window":"w-on-leg","last_activity":"2026-01-07T10:00:00Z"}
}}
JSON
}

_destination() {
    local id="$1" status="$2" repository="$3"
    printf '%s\n' '---' "id: ${id}" "status: ${status}" 'repositories:' "  - ${repository}" '---' \
        > "${MAP}/destinations/${id}.md"
}

# alpha is the leg's destination (on track), beta is late, gamma and delta are on track with the nearer date
# first, eps has no date, zeta is frozen. `unmapped` belongs to nothing.
_write_map() {
    mkdir -p "${MAP}/log" "${MAP}/destinations"
    printf '%s\n' "## Today's leg" '' '- Push alpha forward' > "${MAP}/log/$(date +%F).md"
    _destination alpha active on-leg
    _destination beta active late
    _destination gamma active soon
    _destination delta active far
    _destination eps active undated
    _destination zeta frozen frozen
    printf '%s\n' '| Destination | Due |' '|---|---|' \
        '| alpha | 2997-01-01 |' '| beta | 2000-01-01 |' '| gamma | 2998-01-01 |' \
        '| delta | 2999-01-01 |' '| eps | TBD |' '| zeta | TBD |' > "${MAP}/README.md"
}

_row_repositories() {
    jq -r '[.rows[].project] | join(" ")'
}

# -- borg next ------------------------------------------------------------------------------------------------------

@test "next --rows --json: with a map the rows run leg, nearest due, undated, then frozen and unmapped by score" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" next --rows --json --local --all 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | _row_repositories)" = "on-leg late soon far undated unmapped frozen" ]
}

@test "next --rows --json: with no map the order is the one it always was (oldest waiting first)" {
    _write_registry
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run bash -c "zsh \"$BORG\" next --rows --json --local --all 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | _row_repositories)" = "unmapped frozen undated far soon late on-leg" ]
}

@test "next --rows --json: an empty map directory ranks as no map" {
    _write_registry
    mkdir -p "$MAP"
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" next --rows --json --local --all 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | _row_repositories)" = "unmapped frozen undated far soon late on-leg" ]
}

# A destination file whose frontmatter also carries `target:` (the end date of the whole destination), written over the
# one `_write_map` made. A target and a README waypoint date are two dates and the earlier one counts.
_destination_with_target() {
    local id="$1" repository="$2" target="$3"
    printf '%s\n' '---' "id: ${id}" 'status: active' "target: ${target}" 'repositories:' "  - ${repository}" '---' \
        > "${MAP}/destinations/${id}.md"
}

@test "next --rows --json: a destination's target date counts beside its waypoint date, the earlier one ranking it" {
    _write_registry
    _write_map
    _destination_with_target eps undated 2000-06-01
    _destination_with_target delta far 2997-06-01
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" next --rows --json --local --all 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | _row_repositories)" = "on-leg late undated far soon unmapped frozen" ]
}

@test "link --json: each destination carries nearest_due, a text target reads null and a malformed one warns" {
    _write_registry
    _write_map
    _destination_with_target eps undated 2000-06-01
    _destination_with_target delta far 2997-06-01
    _destination_with_target gamma soon TBD
    _destination_with_target zeta frozen next-spring
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" link --json --local 2>/dev/null"
    [ "$status" -eq 0 ]
    local json="$output"
    [ "$(printf '%s' "$json" | jq -c '.compass.destinations | map({(.id): [.target, .due, .nearest_due, .state]}) | add | {eps, delta, gamma, beta}')" \
        = '{"eps":["2000-06-01",null,"2000-06-01","late"],"delta":["2997-06-01","2999-01-01","2997-06-01","on-track"],"gamma":[null,"2998-01-01","2998-01-01","on-track"],"beta":[null,"2000-01-01","2000-01-01","late"]}' ]
    [ "$(printf '%s' "$json" | jq -c '.compass.warnings')" = '["destinations/zeta.md: target '"'"'next-spring'"'"' is not a YYYY-MM-DD date or TBD, ignored"]' ]
}

@test "next --switch: the non-interactive choice is the compass's top, not the score's" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --switch
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-on-leg" ]
}

@test "next --switch: with no map the non-interactive choice is the oldest waiting, as before" {
    _write_registry
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run zsh "$BORG" next --switch
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-unmapped" ]
}

@test "next --pick N: row N of the compass order, and a pick past the end still dies" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 2
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-late" ]
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 99
    [ "$status" -ne 0 ]
}

@test "next (non-TTY bare run): recommends the repository on today's leg" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: on-leg"* ]]
}

# A registry whose last_activity is a NUMBER on one entry and ISO strings on the rest raises a TypeError inside the
# Python ranking. `--top` used to swallow it (exit 0, no output) and `borg next` printed "All clear" over a registry
# full of rows; now `--top` fails and the jq ranking answers, so the repositories are still listed.
_write_registry_with_mixed_activity() {
    local name
    for name in on-leg late soon; do
        mkdir -p "${BATS_TEST_TMPDIR}/p/${name}"
    done
    cat > "$BORG_REGISTRY" <<JSON
{"repositories": {
  "late":   {"path":"${BATS_TEST_TMPDIR}/p/late","status":"waiting","tmux_window":"w-late","last_activity":"2026-01-06T10:00:00Z"},
  "on-leg": {"path":"${BATS_TEST_TMPDIR}/p/on-leg","status":"waiting","tmux_window":"w-on-leg","last_activity":1767780000},
  "soon":   {"path":"${BATS_TEST_TMPDIR}/p/soon","status":"waiting","tmux_window":"w-soon","last_activity":"2026-01-05T10:00:00Z"}
}}
JSON
}

@test "next --top: a registry that raises inside the ranking exits non-zero with one reason line on stderr" {
    _write_registry_with_mixed_activity
    export BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map"
    run bash -c "PYTHONPATH=\"${BATS_TEST_DIRNAME}/..\" python3 -m borg_core.nextpick.cli --top 0 < \"$BORG_REGISTRY\" 2>&1 >/dev/null"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == "nextpick --top failed: "* ]]
}

@test "next: a registry mixing a numeric last_activity with ISO strings still lists the repositories (jq fallback)" {
    _write_registry_with_mixed_activity
    export BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map"
    run zsh "$BORG" next --pick 1
    [ "$status" -eq 0 ]
    [ "$(_selected)" != "" ]
    run zsh "$BORG" next
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: "* ]]
    [[ "$output" != *"All clear"* ]]
}

@test "next --rows --json: the rows are the same ones link's waiting block carries (both capped), in the compass order" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" next --rows --json --local 2>/dev/null"
    [ "$status" -eq 0 ]
    local next_rows
    next_rows=$(printf '%s' "$output" | jq -c '[.rows[] | select(.owner == "YOU") | .project]')
    BORG_MAP_DIR="$MAP" run bash -c "zsh \"$BORG\" link --json --local 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$next_rows" = '["on-leg","late","soon","far","undated"]' ]
    [ "$(printf '%s' "$output" | jq -c '[.waiting.rows[].project]')" = "$next_rows" ]
}

# A worktree registered under its own name, tied to `on-leg` only by the registry's `repo` key (the git common dir).
# It is the NEWEST waiting entry, so without inheritance it ranks last of the unmapped (older first) and with it
# right behind its repository.
_write_registry_with_worktree() {
    mkdir -p "${BATS_TEST_TMPDIR}/p/on-leg" "${BATS_TEST_TMPDIR}/p/on-leg-wt" "${BATS_TEST_TMPDIR}/p/unmapped"
    cat > "$BORG_REGISTRY" <<JSON
{"repositories": {
  "unmapped":  {"path":"${BATS_TEST_TMPDIR}/p/unmapped","status":"waiting","tmux_window":"w-unmapped","last_activity":"2026-01-01T10:00:00Z"},
  "on-leg":    {"path":"${BATS_TEST_TMPDIR}/p/on-leg","repo":"${BATS_TEST_TMPDIR}/p/on-leg/.git","status":"waiting","tmux_window":"w-on-leg","last_activity":"2026-01-07T10:00:00Z"},
  "on-leg-wt": {"path":"${BATS_TEST_TMPDIR}/p/on-leg-wt","repo":"${BATS_TEST_TMPDIR}/p/on-leg/.git","status":"waiting","tmux_window":"w-on-leg-wt","last_activity":"2026-01-08T10:00:00Z"}
}}
JSON
}

@test "next --pick N: a worktree ranks with its repository on today's leg, not as unmapped" {
    _write_registry_with_worktree
    _write_map
    export TMUX_MOCK_WINDOWS="w-on-leg w-on-leg-wt w-unmapped"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 2
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-on-leg-wt" ]
}

@test "link --overview: a worktree's board row carries the suffix of the repository it belongs to" {
    _write_registry_with_worktree
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    local plain
    plain=$(printf '%s\n' "$output" | sed -e $'s/\033\\[[0-9;]*m//g')
    printf '%s\n' "$plain" | grep -E '(^| )on-leg .*· on track( |$)'
    printf '%s\n' "$plain" | grep -E ' on-leg-wt .*· on track( |$)'
    printf '%s\n' "$plain" | grep -E ' unmapped ' | grep -v '·'
}

# The same worktree, but the map NAMES it under a different destination than its repository's: `gamma` (the one
# `soon` belongs to, off the leg and due after `late`). An explicit mapping wins, so it ranks BEHIND `late`; had it
# inherited `on-leg`'s entry it would sit right behind its repository, ahead of `late`.
_write_registry_with_named_worktree() {
    local name
    for name in unmapped on-leg on-leg-wt late; do
        mkdir -p "${BATS_TEST_TMPDIR}/p/${name}"
    done
    cat > "$BORG_REGISTRY" <<JSON
{"repositories": {
  "unmapped":  {"path":"${BATS_TEST_TMPDIR}/p/unmapped","status":"waiting","tmux_window":"w-unmapped","last_activity":"2026-01-01T10:00:00Z"},
  "late":      {"path":"${BATS_TEST_TMPDIR}/p/late","status":"waiting","tmux_window":"w-late","last_activity":"2026-01-02T10:00:00Z"},
  "on-leg":    {"path":"${BATS_TEST_TMPDIR}/p/on-leg","repo":"${BATS_TEST_TMPDIR}/p/on-leg/.git","status":"waiting","tmux_window":"w-on-leg","last_activity":"2026-01-07T10:00:00Z"},
  "on-leg-wt": {"path":"${BATS_TEST_TMPDIR}/p/on-leg-wt","repo":"${BATS_TEST_TMPDIR}/p/on-leg/.git","status":"waiting","tmux_window":"w-on-leg-wt","last_activity":"2026-01-08T10:00:00Z"}
}}
JSON
    _write_map
    printf '%s\n' '---' 'id: gamma' 'status: active' 'repositories:' '  - soon' '  - on-leg-wt' '---' \
        > "${MAP}/destinations/gamma.md"
}

@test "next --pick N: a worktree the map names keeps its own destination and ranks by it, not by its repository" {
    _write_registry_with_named_worktree
    export TMUX_MOCK_WINDOWS="w-on-leg w-on-leg-wt w-late w-unmapped"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 1
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-on-leg" ]
    : > "$TRACE"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 2
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-late" ]
    : > "$TRACE"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" next --pick 3
    [ "$status" -eq 0 ]
    [ "$(_selected)" = "w-on-leg-wt" ]
}

@test "link --overview: a worktree the map names carries its own destination's state, not its repository's" {
    _write_registry_with_named_worktree
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    local plain
    plain=$(printf '%s\n' "$output" | sed -e $'s/\033\\[[0-9;]*m//g')
    printf '%s\n' "$plain" | grep -E '(^| )on-leg .*· on track( |$)'
    printf '%s\n' "$plain" | grep -E ' on-leg-wt .*· off leg( |$)'
}

# -- borg link: IN FOCUS --------------------------------------------------------------------------------------------

@test "link --overview: IN FOCUS carries the leg and the tally of active destinations by state" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"Compass: Push alpha forward · on track 3 · late 1 · undated 1"* ]]
}

@test "link --overview: with no map IN FOCUS says where it looked, once" {
    _write_registry
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"Compass: no map at ${BATS_TEST_TMPDIR}/no-such-map"* ]]
    [ "$(printf '%s\n' "$output" | grep -c 'Compass:')" = "1" ]
}

@test "link in a repository: the leg, and off route for a repository whose destination is not on it" {
    _write_registry
    _write_map
    cd "${BATS_TEST_TMPDIR}/p/late"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"Compass: Push alpha forward"* ]]
    [[ "$output" == *"off route: late is not on today's leg"* ]]
    [[ "$output" != *"on track 3"* ]]
}

@test "link in a repository: a repository on the leg is not off route" {
    _write_registry
    _write_map
    cd "${BATS_TEST_TMPDIR}/p/on-leg"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"Compass: Push alpha forward"* ]]
    [[ "$output" != *"off route"* ]]
}

@test "link in a repository: Status stays above every line the map supplies" {
    _write_registry
    _write_map
    cd "${BATS_TEST_TMPDIR}/p/late"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -n 'Status:' | head -1 | cut -d: -f1)" -lt \
        "$(printf '%s\n' "$output" | grep -n 'Compass:' | head -1 | cut -d: -f1)" ]
}

@test "link in a repository: with no map it is the one no-map line" {
    _write_registry
    cd "${BATS_TEST_TMPDIR}/p/late"
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run zsh "$BORG" link --local
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'Compass:')" = "1" ]
    [[ "$output" == *"Compass: no map at ${BATS_TEST_TMPDIR}/no-such-map"* ]]
}

# -- borg link: the board -------------------------------------------------------------------------------------------

@test "link --overview: each board row carries its destination's state before its summary and an unmapped row with nothing" {
    _write_registry
    _write_map
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    local plain
    plain=$(printf '%s\n' "$output" | sed -e $'s/\033\\[[0-9;]*m//g')
    printf '%s\n' "$plain" | grep -E '^ ?on-leg .*· on track( |$)'
    printf '%s\n' "$plain" | grep -E '^ ?late .*· late( |$)'
    printf '%s\n' "$plain" | grep -E '^ ?soon .*· off leg( |$)'
    printf '%s\n' "$plain" | grep -E '^ ?frozen .*· frozen( |$)'
    printf '%s\n' "$plain" | grep -E '^ ?unmapped ' | grep -v '·'
}

# -- borg link: WAITING ON YOU --------------------------------------------------------------------------------------

_write_parking() {
    printf '%s\n' \
        '- [ ] revisit the cache design | parked: 1999-12-01 | look: 2000-01-01 | seen: 3 | last: 1999-12-15' \
        '- [ ] not yet | parked: 2026-01-01 | look: 2999-01-01 | seen: 0' \
        '- [x] already handled | parked: 1999-12-01 | look: 2000-01-01 | seen: 1' > "${MAP}/parking-lot.md"
}

@test "link --overview: WAITING ON YOU lists the parking items whose look-again date has come" {
    _write_registry
    _write_map
    _write_parking
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"parking: revisit the cache design (look again 2000-01-01, seen 3)"* ]]
    [[ "$output" != *"not yet"* ]]
    [[ "$output" != *"already handled"* ]]
}

@test "link --overview: a parking item that is not due leaves 'nothing waits on you' standing" {
    mkdir -p "${BATS_TEST_TMPDIR}/p/idle"
    printf '%s\n' '{"repositories": {"idle": {"path":"'"${BATS_TEST_TMPDIR}"'/p/idle","status":"idle"}}}' > "$BORG_REGISTRY"
    mkdir -p "$MAP"
    printf '%s\n' '- [ ] not yet | parked: 2026-01-01 | look: 2999-01-01 | seen: 0' > "${MAP}/parking-lot.md"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing waits on you"* ]]
    [[ "$output" != *"parking:"* ]]
}

@test "link --overview: a due parking item is something that waits on you" {
    mkdir -p "${BATS_TEST_TMPDIR}/p/idle"
    printf '%s\n' '{"repositories": {"idle": {"path":"'"${BATS_TEST_TMPDIR}"'/p/idle","status":"idle"}}}' > "$BORG_REGISTRY"
    mkdir -p "$MAP"
    _write_parking
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --local --overview
    [ "$status" -eq 0 ]
    [[ "$output" != *"nothing waits on you"* ]]
    [[ "$output" == *"parking: revisit the cache design"* ]]
}

# -- the machine surfaces are not widened ----------------------------------------------------------------------------

@test "link --porcelain is byte-identical with and without a map" {
    _write_registry
    _write_map
    BORG_MAP_DIR="${BATS_TEST_TMPDIR}/no-such-map" run zsh "$BORG" link --porcelain --local
    [ "$status" -eq 0 ]
    local without="$output"
    BORG_MAP_DIR="$MAP" run zsh "$BORG" link --porcelain --local
    [ "$status" -eq 0 ]
    [ "$output" = "$without" ]
}
