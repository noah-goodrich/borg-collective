#!/usr/bin/env bash
# The stub `borg` and `drone` of the SW and PN cases, one file linked into the sandbox bin under both names (so `${0##*/}` is
# the command the model typed). It is a committed executable and not written by fixtures.sh because the floor suite
# (tests/eval_floor.bats) runs this harness on a PATH without chmod. See fixtures.sh for the contract.
printf '%s\n' "${0##*/} $*" >> "${EVAL_STUB_LOG:?}"
wname="alpha-api"
case "${0##*/}:${1:-}" in
    borg:switch)
        if [ "${EVAL_STUB_MODE:-}" = switch-fail ]; then
            echo "▸ No tmux window registered for ${2:-}"
            exit 1
        fi
        exit 0 ;;
    borg:link)
        printf 'repository   state\nalpha-api    active\nbeacon-web   waiting\ncedar-docs   idle\n'
        exit 0 ;;
    drone:pane)
        if [ -z "${2:-}" ]; then
            echo "▸ ERROR: Specify a direction: top, bottom, left, or right." >&2
            exit 1
        fi
        case "${EVAL_STUB_MODE:-pane-new}" in
            pane-reuse) echo "▸ $wname: reusing existing side pane %7 (two panes per window)"; echo "%7" ;;
            pane-reuse-zoomed) echo "▸ $wname: reusing existing side pane %7 (two panes per window, unzoomed)"; echo "%7" ;;
            *) echo "▸ $wname: new pane opened ($2)" ;;
        esac
        exit 0 ;;
esac
echo "stub: unsupported: ${0##*/} $*" >&2
exit 2
