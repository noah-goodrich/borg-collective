#!/usr/bin/env bash
# Common test setup for bats tests.
# Sources zsh lib files and provides isolated temp directories.

BORG_HOME="${BATS_TEST_DIRNAME}/.."

# Create isolated temp dirs so tests don't touch real config
setup_temp_dirs() {
    export BORG_TEST_HOME="${BATS_TEST_TMPDIR}/home"
    export BORG_DIR="${BATS_TEST_TMPDIR}/config/borg"
    export BORG_REGISTRY="$BORG_DIR/registry.json"
    export HOME="$BORG_TEST_HOME"
    export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"

    # GIVE THE SANDBOX A GIT IDENTITY. HOME is redirected on the line above, so `~/.gitconfig` is
    # gone by construction -- and recon_adapter_github.bats's case "adapter: a linked worktree is
    # swept, a plain subdirectory is not" runs `git commit` (a linked worktree needs a commit to
    # point at). This passes on macOS ONLY because git auto-derives an identity from getpwuid plus a
    # resolvable hostname and commits anyway, with a warning -- measured, the author lands as
    # `Noah <noah@MacBook-Pro-4.local>`. In a Linux container the hostname has no domain and git
    # refuses outright: `fatal: unable to auto-detect email address (got 'root@<id>.(none)')`, rc=128.
    # CI's ubuntu lane runs `bats tests/*.bats`, so this was silently broken there the whole time.
    #
    # ENV VARS, NOT A WRITTEN .gitconfig: the harness redirects BOTH HOME and XDG_CONFIG_HOME above,
    # and git consults both, so a file means picking the right one and staying right as either
    # redirect changes. Env vars beat every config layer with no path resolution to get wrong.
    # GIT_CONFIG_NOSYSTEM=1 closes the one hole neither redirect covers: the system gitconfig
    # (/opt/homebrew/etc/gitconfig, /etc/gitconfig) is read regardless of HOME/XDG_CONFIG_HOME.
    # `.invalid` is RFC 2606 reserved, so the address can never resolve to anything real.
    #
    # SAME FAMILY as two CLAUDE.md Learned entries: the XDG_CONFIG_HOME leak in borg-link-down.sh,
    # and "a shell variable is not an environment variable" for BORG_REGISTRY -- the sandbox being
    # incomplete in a way the dev machine silently papers over, which is exactly why it stayed
    # invisible where it was being tested.
    export GIT_AUTHOR_NAME="borg tests"    GIT_AUTHOR_EMAIL="tests@borg.invalid"
    export GIT_COMMITTER_NAME="borg tests" GIT_COMMITTER_EMAIL="tests@borg.invalid"
    export GIT_CONFIG_NOSYSTEM=1

    # NEUTRALIZED TO A REAL EMPTY DIRECTORY, NOT UNSET AND NOT "" (the hardened spec's B7).
    # `borg link` folds the recon sweep into its document, so every `borg link` invocation in this
    # suite -- 40-odd of them plus all four goldens -- would otherwise discover the shipped
    # lib/recon/adapters/recon-adapter-github through borg_core/recon/shell.py's repo-root fallback
    # and shell out to `gh`. Goldens would then byte-capture whatever GitHub returned that minute
    # and the suite would need an authenticated network to be green.
    #
    # THE EMPTY STRING DOES NOT WORK. adapter_search_path() branches on `if override:`, so an
    # exported-empty value is FALSY and falls straight back to the real adapter directories -- the
    # neutralization would silently do nothing, which is the same trap CLAUDE.md records for
    # BORG_REAP_STALE_HOURS. Only a real, existing, empty directory discovers zero adapters.
    #
    # THE ADAPTER-DISCOVERY REGRESSION GATE KEEPS ITS TEETH: cli_contract.bats's two #113 cases and
    # its registry-resolution case all `unset BORG_RECON_ADAPTER_PATH` inside their own `zsh -c`,
    # so they still exercise the real fallback this line hides from everyone else.
    export BORG_RECON_ADAPTER_PATH="${BATS_TEST_TMPDIR}/no-adapters"

    # AC3'S SECOND NETWORK SEAM, NEUTRALIZED ON THE SAME TERMS AND FOR THE SAME REASON.
    # The sweep is neutralized above by starving ADAPTER DISCOVERY; the targeted fetch is not
    # adapter-mediated -- borg_core execs `gh` itself -- so an empty adapter directory does nothing
    # for it. Any case whose registry points at a directory holding `.borg/programs/*.json` would
    # otherwise shell out to the real, authenticated `gh` on every non---local `borg link`.
    #
    # A REAL FILE, NEVER "". borg_core/link/shell.py's start_fetch branches on `if fixture:` exactly
    # as sweep does, so an exported-empty value is FALSY and falls straight through to the live
    # fetch -- neutralization that silently does nothing, the same trap the paragraph above documents
    # for BORG_RECON_ADAPTER_PATH and CLAUDE.md records for BORG_REAP_STALE_HOURS.
    #
    # THE CASES THAT MEAN TO EXERCISE THE FETCH UNSET IT THEMSELVES: link_sweep.bats' _sweepable_repo
    # and _ac3_two_repository_manifest, and the opt-in latency gate, which escapes the sandbox
    # entirely.
    export BORG_LINK_FETCH_FIXTURE="${BATS_TEST_TMPDIR}/no-fetch.json"

    mkdir -p "$BORG_DIR" "$BORG_TEST_HOME/.claude/lib" "$BORG_RECON_ADAPTER_PATH"
    printf '{"nodes": {}}\n' > "$BORG_LINK_FETCH_FIXTURE"
    cp "$BORG_HOME/lib/borg-hooks.sh" "$BORG_TEST_HOME/.claude/lib/borg-hooks.sh"
    cp "$BORG_HOME/lib/reaper.sh" "$BORG_TEST_HOME/.claude/lib/reaper.sh"
}

# Source a zsh library file in a way that bats (bash) can call its functions.
# Usage: load_zsh_lib "registry"
# This creates bash wrapper functions that invoke the zsh functions via zsh.
load_zsh_lib() {
    local lib_name="$1"
    local lib_path="$BORG_HOME/lib/${lib_name}.zsh"
    [[ -f "$lib_path" ]] || { echo "lib not found: $lib_path" >&2; return 1; }

    # Store the lib path for use by the wrapper caller
    export BORG_ZSH_LIB_PATH="$lib_path"
}

# Set up a mock bin dir on PATH. Tests write fake CLIs into $MOCK_BIN.
# Also exports BORG_DRONE_EXTRA_PATH so drone.zsh picks up the mocks
# despite its hardcoded PATH reset.
setup_mock_bin() {
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"
    export BORG_DRONE_EXTRA_PATH="$MOCK_BIN"
}

# Run a zsh function from a loaded lib with proper environment.
# Usage: run_zsh_fn <lib> <function> [args...]
run_zsh_fn() {
    local lib="$1" fn="$2"
    shift 2
    zsh -c "
        source '$BORG_HOME/lib/${lib}.zsh'
        BORG_DIR='$BORG_DIR'
        BORG_REGISTRY='$BORG_REGISTRY'
        $fn \"\$@\"
    " -- "$@"
}
