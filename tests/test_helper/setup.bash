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
    mkdir -p "$BORG_DIR" "$BORG_TEST_HOME"
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
