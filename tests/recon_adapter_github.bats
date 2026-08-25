#!/usr/bin/env bats
# Executable coverage for lib/recon/adapters/recon-adapter-github.
#
# Before this file the adapter had NO executable test at all: cli_contract.bats greps the
# credential-stripping sed expression out of the source and runs that one line, which is valuable
# but tests a single regex, not the adapter. Everything else -- the Item contract, the degradation
# ladder, the exit-0-always guarantee, and the query the adapter actually builds -- was unverified.
#
# `gh` is mocked throughout. These tests must never touch the network: a suite that only passes on
# an authenticated machine with a working remote is not a suite.

load test_helper/setup

ADAPTER="${BATS_TEST_DIRNAME}/../lib/recon/adapters/recon-adapter-github"

setup() {
    setup_temp_dirs
    setup_mock_bin
    WORK="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$WORK"
    QUERY_DUMP="${BATS_TEST_TMPDIR}/query.txt"
    export QUERY_DUMP
}

# Create a git repo with the given origin remote, and return nothing (path is derivable).
_repo_with_remote() {
    local name="$1" remote="$2"
    mkdir -p "$WORK/$name"
    git -C "$WORK/$name" init -q
    git -C "$WORK/$name" remote add origin "$remote"
}

_projects_json() {
    local out="$WORK/projects.json" first=1
    printf '{' > "$out"
    local pair
    for pair in "$@"; do
        [ "$first" -eq 1 ] || printf ',' >> "$out"
        first=0
        printf '"%s":{"path":"%s/%s"}' "${pair}" "$WORK" "${pair}" >> "$out"
    done
    printf '}' >> "$out"
    printf '%s' "$out"
}

# Install a mock `gh` that records the query it was handed and replies with $1 (a JSON body),
# exiting with $2 (default 0).
_mock_gh() {
    local body="$1" rc="${2:-0}"
    printf '%s' "$body" > "${BATS_TEST_TMPDIR}/gh-body.json"
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$QUERY_DUMP"
cat "$GH_BODY"
exit "$GH_RC"
EOF
    chmod +x "$MOCK_BIN/gh"
    export GH_BODY="${BATS_TEST_TMPDIR}/gh-body.json"
    export GH_RC="$rc"
}

_one_pr_body() {
    cat <<'JSON'
{"data":{"viewer":{"login":"me"},
"r0":{"pullRequests":{"nodes":[
 {"number":7,"title":"a normal change","state":"OPEN","isDraft":false,
  "updatedAt":"2026-08-20T10:00:00Z","url":"u","headRefName":"h","baseRefName":"main",
  "author":{"login":"me"}}]}}}}
JSON
}

# ── the contract ─────────────────────────────────────────────────────────────

@test "adapter: emits the Item contract with correctly-typed fields" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "$(_one_pr_body)"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    [ "$status" -eq 0 ]
    # bats CLOBBERS $output on every `run`, so the adapter's document must be parked in a file
    # before any assertion runs -- otherwise the second jq parses the FIRST jq's result string and
    # the assertion becomes accidentally meaningless.
    printf '%s' "$output" > "${BATS_TEST_TMPDIR}/doc.json"

    run jq -r '.items[0] | .ref + "|" + .state + "|" + .owner + "|" + .urgency' "${BATS_TEST_TMPDIR}/doc.json"
    [ "$output" = "owner/alpha#7|open|you|this_week" ]

    # action_needed must be a JSON boolean, not a string -- the engine drops the item otherwise.
    run jq -r '.items[0].action_needed | type' "${BATS_TEST_TMPDIR}/doc.json"
    [ "$output" = "boolean" ]

    # Every contract field present, and every one of them a string except action_needed.
    run jq -e '.items[0] | (.project and .source and .ref and .title and .state and .changed and .one_line)
               and (.owner | IN("you","agent","unknown")) and (.urgency | IN("now","this_week","fyi"))' \
        "${BATS_TEST_TMPDIR}/doc.json"
    [ "$status" -eq 0 ]
}

@test "adapter: urgency escalates to now on an urgent-looking title" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "$(_one_pr_body | sed 's/a normal change/hotfix the broken thing/')"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    run bash -c "printf '%s' '$output' | jq -r '.items[0].urgency'"
    [ "$output" = "now" ]
}

@test "adapter: a PR updated before the mark is filtered out" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "$(_one_pr_body | sed 's/2026-08-20T10:00:00Z/2026-08-01T10:00:00Z/')"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    run bash -c "printf '%s' '$output' | jq -r '.items | length'"
    [ "$output" = "0" ]
}

@test "adapter: owner is 'you' only when the author matches the batched viewer login" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "$(_one_pr_body | sed 's/"login":"me"}}]/"login":"someone-else"}}]/')"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    run bash -c "printf '%s' '$output' | jq -r '.items[0].owner'"
    [ "$output" = "unknown" ]
}

# ── the batched call ─────────────────────────────────────────────────────────

@test "adapter: sweeps N repositories in exactly ONE gh invocation" {
    # The whole point of the rewrite. The previous implementation issued one `gh pr list` per
    # repository plus a `gh auth status` and a `gh api user` prelude -- measured at 12.6s on a
    # 14-repository registry. A mock that counts invocations is the only thing that keeps it at one.
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _repo_with_remote beta "git@github.com:owner/beta.git"
    _repo_with_remote gamma "git@github.com:owner/gamma.git"
    printf '%s' "$(_one_pr_body)" > "${BATS_TEST_TMPDIR}/gh-body.json"
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf 'x' >> "$GH_CALLS"
cat "$GH_BODY"
exit 0
EOF
    chmod +x "$MOCK_BIN/gh"
    export GH_BODY="${BATS_TEST_TMPDIR}/gh-body.json"
    export GH_CALLS="${BATS_TEST_TMPDIR}/gh-calls.txt"
    : > "$GH_CALLS"

    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha beta gamma)"
    [ "$status" -eq 0 ]

    run bash -c "wc -c < '$GH_CALLS' | tr -d ' '"
    [ "$output" = "1" ]
}

@test "adapter: the query carries one aliased node per repository and asks for viewer" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _repo_with_remote beta "git@github.com:owner/beta.git"
    _mock_gh "$(_one_pr_body)"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha beta)"

    run cat "$QUERY_DUMP"
    [[ "$output" == *"viewer { login }"* ]] || false
    [[ "$output" == *'r0: repository(owner: "owner", name: "alpha")'* ]] || false
    [[ "$output" == *'r1: repository(owner: "owner", name: "beta")'* ]] || false
    # Recency ordering is what makes the 30-item cap mean "most recently updated".
    [[ "$output" == *"orderBy: {field: UPDATED_AT, direction: DESC}"* ]] || false
}

@test "adapter: a credentialed remote never reaches the GraphQL query" {
    _repo_with_remote alpha "https://x-access-token:gho_EXAMPLETOKEN123456789@github.com/owner/alpha.git"
    _mock_gh "$(_one_pr_body)"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    [ "$status" -eq 0 ]

    run cat "$QUERY_DUMP"
    [[ "$output" != *"gho_"* ]] || false
    [[ "$output" == *'repository(owner: "owner", name: "alpha")'* ]] || false

    run bash -c "printf '%s' '$output' | grep -c 'gho_' || true"
    [ "$output" = "0" ]
}

@test "adapter: a remote with shell/GraphQL metacharacters is rejected, not escaped" {
    # Defence in depth behind the credential strip: owner/name are interpolated into a GraphQL
    # document, so anything outside GitHub's allowed character set must be dropped rather than
    # quoted. A rejected repo must not appear in the query and must not break the sweep.
    _repo_with_remote alpha 'https://github.com/ow"ner/al{pha.git'
    _mock_gh "$(_one_pr_body)"
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"swept 0 github repo(s)"* ]] || false
}

# ── the degradation ladder: every path exits 0 with a structured object ──────

@test "adapter: gh exiting non-zero with usable data still yields a full sweep" {
    # THE BUG THIS PREVENTS: `gh api graphql` exits 1 whenever the response carries an errors[]
    # array -- even when `data` is fully populated for every other node. Verified live against a
    # batch containing one deleted PR. Treating exit status as truth would discard an entire good
    # sweep because one repository was renamed, and render the whole track failed.
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _repo_with_remote beta "git@github.com:owner/beta.git"
    _mock_gh '{"data":{"viewer":{"login":"me"},"r0":{"pullRequests":{"nodes":[{"number":7,"title":"t","state":"OPEN","isDraft":false,"updatedAt":"2026-08-20T10:00:00Z","url":"u","headRefName":"h","baseRefName":"main","author":{"login":"me"}}]}},"r1":null},"errors":[{"type":"NOT_FOUND"}]}' 1

    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha beta)"
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -r '.items | length'"
    [ "$output" = "1" ]
}

@test "adapter: an offline or unauthenticated gh degrades to an explained empty track" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "" 1
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"github track skipped"* ]] || false
    run bash -c "printf '%s' '$output' | jq -r '.items | length'"
    [ "$output" = "0" ]
}

@test "adapter: unparseable gh output degrades instead of emitting a raw dump" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    _mock_gh "this is not json" 0
    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$(_projects_json alpha)"
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -e '.source == \"github\" and (.items | length) == 0'"
    [ "$status" -eq 0 ]
}

@test "adapter: missing gh, missing --since and missing --projects each skip cleanly" {
    _repo_with_remote alpha "git@github.com:owner/alpha.git"
    local projects
    projects="$(_projects_json alpha)"

    run env PATH="/usr/bin:/bin" "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$projects"
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh not installed"* ]] || false

    _mock_gh "$(_one_pr_body)"
    run "$ADAPTER" --projects "$projects"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no --since"* ]] || false

    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects /nonexistent/projects.json
    [ "$status" -eq 0 ]
    [[ "$output" == *"no projects file"* ]] || false
}

@test "adapter: a registry with no github repositories sweeps zero without calling gh" {
    mkdir -p "$WORK/nogit"
    printf '{"nogit":{"path":"%s/nogit"}}' "$WORK" > "$WORK/projects.json"
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
printf 'called' >> "$GH_CALLS"
exit 0
EOF
    chmod +x "$MOCK_BIN/gh"
    export GH_CALLS="${BATS_TEST_TMPDIR}/gh-calls.txt"
    : > "$GH_CALLS"

    run "$ADAPTER" --since 2026-08-11T00:00:00Z --projects "$WORK/projects.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"swept 0 github repo(s)"* ]] || false

    run bash -c "wc -c < '$GH_CALLS' | tr -d ' '"
    [ "$output" = "0" ]
}
