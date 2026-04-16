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
    mkdir -p "$BORG_DIR" "$BORG_TEST_HOME/.claude/lib"
    cp "$BORG_HOME/lib/borg-hooks.sh" "$BORG_TEST_HOME/.claude/lib/borg-hooks.sh"
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
