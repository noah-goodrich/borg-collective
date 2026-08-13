#!/usr/bin/env bats
# THE ZSH HALF OF THE SHARED REAP CASE TABLE.
#
# Reads tests/fixtures/reaper-cases.tsv and evaluates every row against the REAL lib/reaper.sh
# `_borg_should_reap` and lib/registry.zsh's `borg_reap_overlay`, under a real zsh. Its Python twin,
# borg_core/link/test_core.py, reads the SAME file and asserts the SAME expected column against
# core.should_reap / core.reap_overlay.
#
# WHY BOTH: PROJECT_PLAN.md's Risks section names shared-helper divergence as the crux of the link
# port. The zsh helpers stay live at nine call sites while Python reimplements them, and divergence
# surfaces as `borg link` saying idle while `borg next` says waiting -- a plausible wrong answer with
# no crash. Two readers over one table means a disagreement fails a build instead of drifting.
#
# If you change an expected value here, you are changing it for Python too. That is the point.

load test_helper/setup

CASES="${BATS_TEST_DIRNAME}/fixtures/reaper-cases.tsv"
REAPER="${BATS_TEST_DIRNAME}/../lib/reaper.sh"
BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    NOW=$(date -u +%s)
    export NOW
}

# Resolve a table `age` token to the literal last_activity string the implementation will see.
# Echoes nothing for EMPTY, so the caller gets "".
_age_to_timestamp() {
    local token="$1" offset epoch
    case "$token" in
        EMPTY)   printf '' ;;
        NULL)    printf 'null' ;;
        GARBAGE) printf 'not-a-timestamp' ;;
        NOW-*)
            offset="${token#NOW-}"
            epoch=$((NOW - offset))
            date -u -r "$epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                || date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ"
            ;;
        NOW+*)
            offset="${token#NOW+}"
            epoch=$((NOW + offset))
            date -u -r "$epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                || date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ"
            ;;
        *) printf '%s' "$token" ;;
    esac
}

_status_token() {
    [ "$1" = "EMPTY" ] && printf '' || printf '%s' "$1"
}

_threshold_token() {
    [ "$1" = "GARBAGE" ] && printf 'not-a-number' || printf '%s' "$1"
}

@test "shared table: _borg_should_reap agrees with every row" {
    local id status age live threshold expect why
    local ts st th actual failures=0

    while IFS=$'\t' read -r id status age live threshold expect why; do
        case "$id" in ''|'#'*|id) continue ;; esac

        ts=$(_age_to_timestamp "$age")
        st=$(_status_token "$status")
        th=$(_threshold_token "$threshold")

        # _borg_should_reap reads BORG_REAP_STALE_HOURS from the environment at call time.
        if BORG_REAP_STALE_HOURS="$th" bash -c \
            ". '$REAPER'; _borg_should_reap '$st' '$ts' '$live'" 2>/dev/null; then
            actual=REAP
        else
            actual=KEEP
        fi

        if [ "$actual" != "$expect" ]; then
            echo "ROW $id: expected $expect, got $actual ($why)" >&2
            failures=$((failures + 1))
        fi
    done < "$CASES"

    [ "$failures" -eq 0 ]
}

# The half the plan's Risks section actually names, and the half an earlier draft of this table
# missed entirely: borg_reap_overlay's own window resolution. should_reap never sees a tmux_window --
# the overlay resolves it first, defaulting to the project name and mapping the "-" TSV sentinel back
# to absent, then decides liveness by a whole-string LITERAL match.
@test "shared table: borg_reap_overlay resolves windows the way core.resolve_window does" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"

    # window_field <TAB> live_window_list <TAB> expected_status
    # A project named "proj" that is active and fresh; only the window resolution decides its fate.
    local rows=(
        $'null\tproj\tactive'
        $'null\tother\tidle'
        $'-\tproj\tactive'
        $'explicit\texplicit\tactive'
        $'explicit\tproj\tidle'
    )

    local row window live_list expect actual
    local failures=0
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r window live_list expect <<< "$row"

        cat > "$MOCK_BIN/tmux" <<EOF
#!/usr/bin/env bash
case "\$1" in
    has-session) exit 0 ;;
    list-windows) printf '%s\n' "$live_list" ;;
esac
exit 0
EOF
        chmod +x "$MOCK_BIN/tmux"

        if [ "$window" = "null" ]; then
            printf '{"projects":{"proj":{"path":null,"status":"active","last_activity":"2020-01-01T00:00:00Z","tmux_window":null}}}' \
                > "$BORG_REGISTRY"
        else
            printf '{"projects":{"proj":{"path":null,"status":"active","last_activity":"2020-01-01T00:00:00Z","tmux_window":"%s"}}}' \
                "$window" > "$BORG_REGISTRY"
        fi

        actual=$(zsh -c "set -- help; source '$BORG' >/dev/null 2>&1; borg_registry_with_state" \
            | jq -r '.projects.proj.status')

        if [ "$actual" != "$expect" ]; then
            echo "window='$window' live='$live_list': expected $expect, got $actual" >&2
            failures=$((failures + 1))
        fi
    done

    [ "$failures" -eq 0 ]
}
