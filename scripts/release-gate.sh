#!/usr/bin/env bash
# Release gate (#536). Fails when a change touches plugin content while VERSION has not moved past the newest
# vX.Y.Z tag, unless the PR carries the `unreleased` label. Thin caller: .github/workflows/test.yml.
#
#   release-gate.sh paths                      print the plugin-content pathspecs, one per line
#   release-gate.sh check BASE HEAD [LABELS]   LABELS is comma separated; exit 0 pass, 1 gate failed
#
# "Plugin content" is derived from scripts/build-plugin.sh itself: every $HOOKS_SRC/<file> and $LIB_SRC/<file> it
# names, plus the skills/ and agents/ trees and build-plugin.sh (it writes hooks.json). tests/release_gate.bats
# pins this list against the script. Do NOT use `build-plugin.sh --dry-run` as the signal: it always flags the 5
# lib-inlining hooks.
# shellcheck disable=SC2016,SC2001
set -u

ROOT="${RELEASE_GATE_ROOT:-$(git rev-parse --show-toplevel)}"
BUILD="$ROOT/scripts/build-plugin.sh"

plugin_paths() {
    grep -oE '\$HOOKS_SRC/[A-Za-z0-9._-]+\.sh' "$BUILD" | sed 's|^\$HOOKS_SRC|hooks|'
    grep -oE '\$LIB_SRC/[A-Za-z0-9._-]+\.sh' "$BUILD" | sed 's|^\$LIB_SRC|lib|'
    echo "skills/"
    echo "agents/"
    echo "scripts/build-plugin.sh"
}

latest_tag() {
    git -C "$ROOT" tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1
}

check() {
    local base="$1" head="$2" labels="${3:-}" tag version changed paths
    tag="$(latest_tag)"
    if [[ -z "$tag" ]]; then
        echo "release-gate: no vX.Y.Z tag found (fetch tags); nothing to compare against." >&2
        return 1
    fi
    version="$(git -C "$ROOT" show "$head:VERSION" | tr -d '[:space:]')"
    if [[ "$version" != "${tag#v}" ]] && [[ "$(printf '%s\n%s\n' "${tag#v}" "$version" | sort -V | tail -n 1)" == "$version" ]]; then
        echo "release-gate: VERSION $version is past $tag. OK."
        return 0
    fi
    paths="$(plugin_paths | sort -u | tr '\n' ' ')"
    # shellcheck disable=SC2086
    changed="$(git -C "$ROOT" diff --name-only "$base...$head" -- $paths)"
    if [[ -z "$changed" ]]; then
        echo "release-gate: no plugin content changed. OK."
        return 0
    fi
    if [[ ",$labels," == *",unreleased,"* ]]; then
        echo "release-gate: plugin content changed under $tag, accepted by the 'unreleased' label. OK."
        return 0
    fi
    {
        echo "release-gate FAILED: this change edits plugin content, but VERSION ($version) is not past the latest release tag ($tag)."
        echo "The plugin mirror is built from the tag, so these edits would sit on main unshipped and every 'borg setup' would print DRIFT (#466, #521)."
        echo "Plugin files changed:"
        echo "$changed" | sed 's/^/  /'
        echo "Do ONE of:"
        echo "  1. Bump VERSION past $tag in this PR (a release PR)."
        echo "  2. Add the label 'unreleased' to this PR, and list the PR under the 'Main after ${tag#v} (unreleased)' section of docs/upgrading.md."
    } >&2
    return 1
}

case "${1:-}" in
    paths) plugin_paths | sort -u ;;
    check) shift; check "$@" ;;
    *) echo "usage: release-gate.sh paths | check BASE HEAD [LABELS]" >&2; exit 2 ;;
esac
