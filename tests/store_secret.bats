#!/usr/bin/env bats
# Tests for _borg_patch_secrets_file (lib/secrets.zsh).
# No live keychain access — all tests operate on fixture files only.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

# Build a minimal secrets.zsh fixture without anchor markers
_make_fixture() {
    local dest="$1"
    cat > "$dest" << 'EOF'
# secrets.zsh — Load API keys from macOS Keychain

# SECRET REGISTRY
#   Env Var              Keychain Service       Purpose
#   -------------------  ---------------------  ----------------------------------------
#   EXISTING_KEY         EXISTING_KEY           An existing key for testing

if [[ "$OSTYPE" == darwin* ]]; then
    _keychain_export() {
        local var_name="$1"
        local service="${2:-$1}"
        local val
        val=$(security find-generic-password -s "$service" -a "$USER" -w 2>/dev/null) || return 0
        export "$var_name=$val"
    }

    _keychain_export EXISTING_KEY

    unfunction _keychain_export
fi
EOF
}

# Build a fixture that already has anchor markers
_make_marked_fixture() {
    local dest="$1"
    cat > "$dest" << 'EOF'
# secrets.zsh — Load API keys from macOS Keychain

# SECRET REGISTRY
#   Env Var              Keychain Service       Purpose
#   -------------------  ---------------------  ----------------------------------------
#   EXISTING_KEY         EXISTING_KEY           An existing key for testing

if [[ "$OSTYPE" == darwin* ]]; then
    _keychain_export() {
        local var_name="$1"
        local service="${2:-$1}"
        local val
        val=$(security find-generic-password -s "$service" -a "$USER" -w 2>/dev/null) || return 0
        export "$var_name=$val"
    }

    # BEGIN _keychain_export block
    _keychain_export EXISTING_KEY
    # END _keychain_export block

    unfunction _keychain_export
fi
EOF
}

setup() {
    setup_temp_dirs
    FIXTURE="$BATS_TEST_TMPDIR/secrets.zsh"
}

# ── Anchor markers ────────────────────────────────────────────────────────────

@test "adds BEGIN anchor marker before first _keychain_export call" {
    _make_fixture "$FIXTURE"
    run run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    [ "$status" -eq 0 ]
    grep -qxF "    # BEGIN _keychain_export block" "$FIXTURE"
}

@test "adds END anchor marker before unfunction line" {
    _make_fixture "$FIXTURE"
    run run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    [ "$status" -eq 0 ]
    grep -qxF "    # END _keychain_export block" "$FIXTURE"
}

@test "does not duplicate BEGIN marker on second run" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file ANOTHER_KEY "$FIXTURE"
    local count
    count=$(grep -cF "# BEGIN _keychain_export block" "$FIXTURE")
    [ "$count" -eq 1 ]
}

# ── _keychain_export insertion ────────────────────────────────────────────────

@test "inserts _keychain_export NAME inside the block" {
    _make_fixture "$FIXTURE"
    run run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    [ "$status" -eq 0 ]
    grep -qF "_keychain_export NEW_KEY" "$FIXTURE"
}

@test "_keychain_export line appears before END marker" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    local export_line end_line
    export_line=$(grep -n "_keychain_export NEW_KEY" "$FIXTURE" | head -1 | cut -d: -f1)
    end_line=$(grep -n "# END _keychain_export block" "$FIXTURE" | head -1 | cut -d: -f1)
    [ "$export_line" -lt "$end_line" ]
}

@test "is idempotent — does not duplicate _keychain_export line" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    local count
    count=$(grep -cF "_keychain_export NEW_KEY" "$FIXTURE")
    [ "$count" -eq 1 ]
}

@test "preserves existing _keychain_export entries" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    grep -qF "_keychain_export EXISTING_KEY" "$FIXTURE"
}

@test "works with already-marked fixture (no duplicate markers)" {
    _make_marked_fixture "$FIXTURE"
    run run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    [ "$status" -eq 0 ]
    local count
    count=$(grep -cF "# BEGIN _keychain_export block" "$FIXTURE")
    [ "$count" -eq 1 ]
}

# ── Registry comment row ──────────────────────────────────────────────────────

@test "adds registry comment row for new key" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    grep -qF "#   NEW_KEY" "$FIXTURE"
}

@test "does not duplicate registry row on second run" {
    _make_fixture "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY "$FIXTURE"
    local count
    count=$(grep -cF "#   NEW_KEY" "$FIXTURE")
    [ "$count" -eq 1 ]
}

# ── Error cases ───────────────────────────────────────────────────────────────

@test "fails cleanly when file does not exist" {
    run run_zsh_fn secrets _borg_patch_secrets_file NEW_KEY /nonexistent/secrets.zsh
    [ "$status" -ne 0 ]
}

# ── CLI integration ───────────────────────────────────────────────────────────

@test "borg help includes store-secret" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"store-secret"* ]]
}

@test "borg store-secret fails without TTY" {
    run bash -c "echo '' | '$BORG_CMD' store-secret TEST_KEY"
    [ "$status" -ne 0 ]
    [[ "$output" == *"interactive terminal"* ]]
}

@test "borg store-secret fails without a name argument" {
    run bash -c "echo '' | '$BORG_CMD' store-secret"
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage"* ]]
}
