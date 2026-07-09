#!/usr/bin/env bats
# Class-level tripwire for the launchd-PATH bug.
#
# Three separate agents have now shipped exiting 127 under launchd — usage-watch, notifyd, and
# cortex-wake — for the identical reason: they hardcode a PATH that omits $HOME/.local/bin, where
# the native installers put `claude` and `cortex`. Every one of them passed its unit tests, because
# unit tests run from a login shell that already has that directory on PATH.
#
# Per-script tests catch per-script regressions. This file catches the CLASS: any script under bin/
# that sets its own PATH must include $HOME/.local/bin, including scripts that do not exist yet.

load test_helper/setup

# BORG_HOME comes from test_helper/setup — do not re-derive the repo root here.
BIN_DIR="$BORG_HOME/bin"

@test "every bin/ script that sets PATH includes \$HOME/.local/bin" {
    local checked=0
    local offenders=""

    for script in "$BIN_DIR"/*; do
        [ -f "$script" ] || continue

        local path_line
        path_line=$(grep -m1 -E '^export PATH=' "$script" || true)
        [ -n "$path_line" ] || continue

        checked=$((checked + 1))
        case "$path_line" in
            *'$HOME/.local/bin'*) ;;
            *) offenders="$offenders ${script##*/}" ;;
        esac
    done

    # A glob that silently matches nothing would make this test pass while checking zero files —
    # which is the exact failure shape (a green no-op) that this whole file exists to prevent.
    [ "$checked" -ge 3 ]
    [ -z "$offenders" ] || {
        echo "scripts setting PATH without \$HOME/.local/bin:$offenders"
        false
    }
}

@test "the three launchd-run agents all self-heal PATH" {
    for agent in borg-notifyd borg-cortex-watch borg-usage-watch; do
        run grep -m1 -E '^export PATH=.*\$HOME/\.local/bin' "$BIN_DIR/$agent"
        [ "$status" -eq 0 ]
    done
}
