#!/usr/bin/env bats
# Tests for `drone scaffold --supabase-shared <dir>`: template rendering,
# NO per-project supabase init/network, and the shared borg-hooks lifecycle
# scripts (pre-up.sh idempotent start-once, post-down.sh no-op).
#
# INERT feature: these tests exercise scaffolding + hook script logic only.
# They never start/stop the real shared stillpoint stack.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"
TEMPLATES="${BATS_TEST_DIRNAME}/../templates/supabase-shared"

setup() {
    setup_temp_dirs

    export TEST_PROJECT="${BATS_TEST_TMPDIR}/myapp"
    mkdir -p "$TEST_PROJECT"

    setup_mock_bin
}

# ─── drone scaffold --supabase-shared ─────────────────────────────────────────

@test "scaffold --supabase-shared: refuses when project dir does not exist" {
    run "$DRONE" scaffold --supabase-shared "${BATS_TEST_TMPDIR}/does-not-exist"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]] || false
}

@test "scaffold --supabase-shared: refuses when .devcontainer already exists" {
    mkdir "$TEST_PROJECT/.devcontainer"
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -ne 0 ]
    [[ "$output" == *".devcontainer/"* ]] || false
}

@test "scaffold --supabase-shared: does NOT require supabase CLI at scaffold time" {
    # No supabase mock installed in $MOCK_BIN — must still succeed, since the
    # shared model never runs 'supabase init' during scaffold.
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
}

@test "scaffold --supabase-shared: does NOT create a supabase/ dir in the project" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_PROJECT/supabase" ]
}

@test "scaffold --supabase-shared: docker-compose.yml joins the fixed shared network" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.devcontainer/docker-compose.yml" ]
    ! grep -q '__PROJECT_NAME__' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    ! grep -q '__SCHEMA__' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'supabase_network_stillpoint' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'supabase_db_stillpoint' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'MYAPP_DB_URL' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase-shared: attaches via the supabase_shared network alias" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    grep -q '^\s*- supabase_shared$' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -qE '^\s*supabase_shared:$' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase-shared: DB URL and API URL are schema-scoped (default = project name)" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    grep -q 'search_path%3Dmyapp' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'MYAPP_SUPABASE_URL: http://supabase_kong_stillpoint:8000' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase-shared: --schema overrides the default project-name schema" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT" --schema custom_schema
    [ "$status" -eq 0 ]
    grep -q 'search_path%3Dcustom_schema' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    ! grep -q 'search_path%3Dmyapp' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase-shared: hyphenated project name yields an underscored schema" {
    export TEST_HYPHEN_PROJECT="${BATS_TEST_TMPDIR}/my-app"
    mkdir -p "$TEST_HYPHEN_PROJECT"
    run "$DRONE" scaffold --supabase-shared "$TEST_HYPHEN_PROJECT"
    [ "$status" -eq 0 ]
    grep -q 'search_path%3Dmy_app' "$TEST_HYPHEN_PROJECT/.devcontainer/docker-compose.yml"
    ! grep -q 'search_path%3Dmy-app' "$TEST_HYPHEN_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'the `my_app` schema via `search_path`' "$TEST_HYPHEN_PROJECT/CLAUDE.md"
}

@test "scaffold --supabase-shared: appends the shared-stack block to a new CLAUDE.md" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/CLAUDE.md" ]
    grep -q '## Local Supabase — ONE shared stack' "$TEST_PROJECT/CLAUDE.md"
    grep -q 'the `myapp` schema via `search_path`' "$TEST_PROJECT/CLAUDE.md"
    grep -q 'borg-supabase-guard.sh' "$TEST_PROJECT/CLAUDE.md"
    ! grep -q '__SCHEMA__' "$TEST_PROJECT/CLAUDE.md"
}

@test "scaffold --supabase-shared: appends (not overwrites) an existing CLAUDE.md" {
    printf '# myapp\n\nExisting project notes.\n' > "$TEST_PROJECT/CLAUDE.md"
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    grep -q 'Existing project notes.' "$TEST_PROJECT/CLAUDE.md"
    grep -q '## Local Supabase — ONE shared stack' "$TEST_PROJECT/CLAUDE.md"
}

@test "scaffold --supabase-shared: CLAUDE.md block wraps at 120 columns" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    run awk '{ if (length($0) > 120) { print; exit 1 } }' "$TEST_PROJECT/CLAUDE.md"
    [ "$status" -eq 0 ]
}

@test "scaffold --supabase-shared: writes devcontainer.json with project name" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.devcontainer/devcontainer.json" ]
    grep -q '"name": "myapp"' "$TEST_PROJECT/.devcontainer/devcontainer.json"
}

@test "scaffold --supabase-shared: copies borg-hooks scripts as executable" {
    run "$DRONE" scaffold --supabase-shared "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -x "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" ]
    [ -x "$TEST_PROJECT/.devcontainer/borg-hooks/post-down.sh" ]
    grep -q 'supabase_db_stillpoint' "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh"
    grep -q 'no-op' "$TEST_PROJECT/.devcontainer/borg-hooks/post-down.sh"
}

# ─── pre-up.sh: idempotent start-once behavior ────────────────────────────────

@test "shared pre-up.sh: no-ops when the shared stack is already running" {
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "inspect" ]]; then
    echo "true"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"
    # No supabase mock — if the hook tried to start the stack, it would fail
    # here (command not found), proving the no-op path was taken.
    run bash "$TEMPLATES/borg-hooks/pre-up.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"already running"* ]] || false
    [[ "$output" == *"no-op"* ]] || false
}

@test "shared pre-up.sh: starts the shared stack once when absent" {
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "inspect" ]]; then
    echo "false"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    export SUPABASE_TRACE="${BATS_TEST_TMPDIR}/supabase.log"
    : > "$SUPABASE_TRACE"
    cat > "$MOCK_BIN/supabase" <<EOF
#!/usr/bin/env bash
echo "supabase \$* (pwd=\$PWD)" >> "$SUPABASE_TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/supabase"

    export STILLPOINT_DIR="${BATS_TEST_TMPDIR}/stillpoint"
    mkdir -p "$STILLPOINT_DIR/supabase"
    export BORG_STILLPOINT_SUPABASE_DIR="$STILLPOINT_DIR"

    run bash "$TEMPLATES/borg-hooks/pre-up.sh"
    [ "$status" -eq 0 ]
    grep -q "supabase start (pwd=$STILLPOINT_DIR)" "$SUPABASE_TRACE"
}

@test "shared pre-up.sh: never runs a per-project 'supabase init'" {
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "inspect" ]] && echo "false"
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"
    export SUPABASE_TRACE="${BATS_TEST_TMPDIR}/supabase.log"
    : > "$SUPABASE_TRACE"
    cat > "$MOCK_BIN/supabase" <<EOF
#!/usr/bin/env bash
echo "supabase \$*" >> "$SUPABASE_TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/supabase"
    export STILLPOINT_DIR="${BATS_TEST_TMPDIR}/stillpoint"
    mkdir -p "$STILLPOINT_DIR/supabase"
    export BORG_STILLPOINT_SUPABASE_DIR="$STILLPOINT_DIR"

    run bash "$TEMPLATES/borg-hooks/pre-up.sh"
    [ "$status" -eq 0 ]
    ! grep -q 'supabase init' "$SUPABASE_TRACE"
}

# ─── post-down.sh: shared stack must persist ──────────────────────────────────

@test "shared post-down.sh: is a no-op and does not stop the shared stack" {
    cat > "$MOCK_BIN/supabase" <<'EOF'
#!/usr/bin/env bash
echo "supabase $*" >> "$SUPABASE_CALLED"
exit 0
EOF
    chmod +x "$MOCK_BIN/supabase"
    export SUPABASE_CALLED="${BATS_TEST_TMPDIR}/supabase-called.log"
    : > "$SUPABASE_CALLED"

    run bash "$TEMPLATES/borg-hooks/post-down.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no-op"* ]] || false
    [[ "$output" == *"persists"* ]] || false
    [ ! -s "$SUPABASE_CALLED" ]
}

# ─── regression: --supabase (per-project) path is untouched ──────────────────
# NOTE: cannot reliably assert "supabase CLI missing" behavior here — drone.zsh
# resets PATH to include /opt/homebrew/bin which hosts the real supabase CLI on
# dev machines (same caveat documented in tests/scaffold_supabase.bats). The
# full existing tests/scaffold_supabase.bats suite is the regression guard for
# the unchanged --supabase path; it is left untouched by this change.
