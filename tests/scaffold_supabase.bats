#!/usr/bin/env bats
# Tests for `drone scaffold --supabase <dir>`: template rendering,
# supabase init invocation, refusal-on-existing-state precondition.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"
TEMPLATES="${BATS_TEST_DIRNAME}/../templates/supabase"

setup() {
    setup_temp_dirs

    export TEST_PROJECT="${BATS_TEST_TMPDIR}/myapp"
    mkdir -p "$TEST_PROJECT"

    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"
    export BORG_DRONE_EXTRA_PATH="$MOCK_BIN"

    # Fake `supabase` CLI: `supabase init` creates supabase/config.toml with
    # project_id = directory name (mimics real CLI behavior).
    export SUPABASE_TRACE="${BATS_TEST_TMPDIR}/supabase.log"
    : > "$SUPABASE_TRACE"
    cat > "$MOCK_BIN/supabase" <<EOF
#!/usr/bin/env bash
echo "supabase \$*" >> "$SUPABASE_TRACE"
if [[ "\$1" == "init" ]]; then
    mkdir -p supabase
    dir_name="\${PWD##*/}"
    cat > supabase/config.toml <<CONF
project_id = "\$dir_name"
[api]
port = 54321
CONF
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/supabase"
}

@test "scaffold --supabase: refuses when project dir does not exist" {
    run "$DRONE" scaffold --supabase "${BATS_TEST_TMPDIR}/does-not-exist"
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "scaffold --supabase: refuses when .devcontainer already exists" {
    mkdir "$TEST_PROJECT/.devcontainer"
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -ne 0 ]
    [[ "$output" == *".devcontainer/"* ]]
}

@test "scaffold --supabase: refuses when supabase/ already exists" {
    mkdir "$TEST_PROJECT/supabase"
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"supabase/"* ]]
}

# NOTE: Cannot reliably test "supabase CLI is missing" in a single bats case —
# drone.zsh resets PATH to include /opt/homebrew/bin which hosts the real
# supabase on dev machines. The preflight check is a 2-line guard
# (`command -v supabase || die`) — trusted by inspection.

@test "scaffold --supabase: writes Dockerfile with __WORKSPACE__ substituted" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.devcontainer/Dockerfile" ]
    ! grep -q '__WORKSPACE__' "$TEST_PROJECT/.devcontainer/Dockerfile"
    grep -q 'WORKDIR /workspace' "$TEST_PROJECT/.devcontainer/Dockerfile"
}

@test "scaffold --supabase: writes docker-compose.yml with network name" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.devcontainer/docker-compose.yml" ]
    ! grep -q '__PROJECT_NAME__' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'supabase_network_myapp' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
    grep -q 'MYAPP_DB_URL' "$TEST_PROJECT/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase: writes devcontainer.json with project name" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/.devcontainer/devcontainer.json" ]
    grep -q '"name": "myapp"' "$TEST_PROJECT/.devcontainer/devcontainer.json"
}

@test "scaffold --supabase: copies borg-hooks scripts as executable" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ -x "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" ]
    [ -x "$TEST_PROJECT/.devcontainer/borg-hooks/post-down.sh" ]
    grep -q 'supabase start' "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh"
    grep -q 'supabase stop'  "$TEST_PROJECT/.devcontainer/borg-hooks/post-down.sh"
}

@test "scaffold --supabase: runs 'supabase init' inside the project dir" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    grep -q 'supabase init' "$SUPABASE_TRACE"
    [ -f "$TEST_PROJECT/supabase/config.toml" ]
    grep -q 'project_id = "myapp"' "$TEST_PROJECT/supabase/config.toml"
}

@test "scaffold --supabase: uppercases and underscores project name in env var" {
    mv "$TEST_PROJECT" "${BATS_TEST_TMPDIR}/my-dashed-app"
    run "$DRONE" scaffold --supabase "${BATS_TEST_TMPDIR}/my-dashed-app"
    [ "$status" -eq 0 ]
    grep -q 'MY_DASHED_APP_DB_URL' "${BATS_TEST_TMPDIR}/my-dashed-app/.devcontainer/docker-compose.yml"
}

@test "scaffold --supabase: hook scripts in scaffolded project pass run_borg_hook shape" {
    run "$DRONE" scaffold --supabase "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    # Sanity: pre-up.sh should have a proper shebang and 'set -euo pipefail'.
    head -1 "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh" | grep -q '^#!/usr/bin/env bash'
    grep -q 'set -euo pipefail' "$TEST_PROJECT/.devcontainer/borg-hooks/pre-up.sh"
}
