#!/usr/bin/env bats
# The shared dev-postgres is opt-in: `drone up` starts it only for a repository whose .devcontainer/
# references `dev-postgres`. Every devcontainer repository still gets the external devnet network.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs

    export TEST_REPOSITORY="${BATS_TEST_TMPDIR}/sample"
    mkdir -p "$TEST_REPOSITORY/.devcontainer"

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"

    setup_mock_bin

    # docker stub: log every call; `ps` names a container so wait_for_container returns; `network
    # inspect` fails so ensure_network has to create devnet.
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
case "$1" in
    compose)
        case "$*" in
            *" ps "*|*" ps") echo "sample-devcontainer-1" ;;
        esac ;;
    ps) echo "sample-devcontainer-1" ;;
    network) [[ "$2" == "inspect" ]] && exit 1 ;;
    inspect) echo '[]' ;;
    exec) echo "no" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    has-session) exit 1 ;;
    list-panes|list-windows|display-message|display|show-option) echo "" ;;
    new-session|new-window|split-window) echo "%0" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/borg"
    chmod +x "$MOCK_BIN/borg"

    cat > "$TEST_REPOSITORY/.devcontainer/devcontainer.json" <<'EOF'
{ "name": "sample", "dockerComposeFile": "docker-compose.yml", "service": "devcontainer", "workspaceFolder": "/workspace", "remoteUser": "dev" }
EOF
}

_write_compose() {
    cat > "$TEST_REPOSITORY/.devcontainer/docker-compose.yml" <<EOF
services:
  devcontainer:
    image: alpine
$1
networks:
  devnet:
    external: true
EOF
}

@test "drone up: a repository that never names dev-postgres does not start it" {
    _write_compose "    networks: [devnet]"
    run "$DRONE" up "$TEST_REPOSITORY"
    [ "$status" -eq 0 ]
    # Not `! grep`: set -e ignores a negated command, so a mid-test `! grep` can never fail the test.
    run grep -q 'docker-compose.postgres.yml' "$TRACE"
    [ "$status" -ne 0 ]
    grep -q 'docker compose -p sample .*up' "$TRACE"
}

@test "drone up: devnet is still created for a repository without dev-postgres" {
    _write_compose "    networks: [devnet]"
    run "$DRONE" up "$TEST_REPOSITORY"
    [ "$status" -eq 0 ]
    grep -q 'docker network create devnet' "$TRACE"
}

@test "drone up: a repository whose devcontainer names dev-postgres starts it before its own compose" {
    _write_compose "    environment:
      DB_HOST: dev-postgres
    networks: [devnet]"
    run "$DRONE" up "$TEST_REPOSITORY"
    [ "$status" -eq 0 ]
    local pg_line repository_line
    pg_line=$(grep -n 'docker-compose.postgres.yml up -d' "$TRACE" | head -1 | cut -d: -f1)
    repository_line=$(grep -n 'docker compose -p sample .*up' "$TRACE" | head -1 | cut -d: -f1)
    [ -n "$pg_line" ] && [ -n "$repository_line" ] && [ "$pg_line" -lt "$repository_line" ]
}

@test "drone up: a dev-postgres reference outside the compose file (e.g. .env) also opts in" {
    _write_compose "    networks: [devnet]"
    echo "CAIRN_DB_HOST=dev-postgres" > "$TEST_REPOSITORY/.devcontainer/.env"
    run "$DRONE" up "$TEST_REPOSITORY"
    [ "$status" -eq 0 ]
    grep -q 'docker-compose.postgres.yml up -d' "$TRACE"
}
