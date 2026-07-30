#!/usr/bin/env bats
# Tests for the source-agnostic recon fan-out engine in lib/recon.sh.
#
# The engine is portable sh, so bats (bash) sources it directly and calls its functions. Coverage:
#   - since resolution (explicit > newest checkpoint mtime > last-run marker > 24h fallback)
#   - adapter discovery (executable recon-adapter-*; dedup with first-on-path-wins; non-exec ignored)
#   - Item + track schema validation (enum + required-field constraints)
#   - concurrent fan-out (writes one track file per source; a broken source is isolated, not fatal)
#   - malformed-item dropping (the engine is the last line of defense against a raw dump)
#   - reconcile: merge-by-project + stale-blocker contradiction detection
#   - cairn persistence: POSTs reconciled contradictions to /record/batch via curl, with stable
#     deterministic ids, and is fail-quiet on every failure path (opt-out, no curl, endpoint down,
#     zero contradictions)

load test_helper/setup

setup() {
    setup_temp_dirs
    source "$BORG_HOME/lib/recon.sh"
    export ADAPTERS="${BATS_TEST_TMPDIR}/adapters"
    mkdir -p "$ADAPTERS"
    export BORG_RECON_ADAPTER_PATH="$ADAPTERS"
    export BORG_RECON_NO_CAIRN=1
}

# Write an adapter that echoes a fixed track object. Usage: make_adapter <name> <json>
make_adapter() {
    local name="$1" json="$2"
    cat > "$ADAPTERS/recon-adapter-$name" <<EOF
#!/usr/bin/env bash
cat <<'JSON'
$json
JSON
EOF
    chmod +x "$ADAPTERS/recon-adapter-$name"
}

VALID_ITEM='{"project":"p","source":"s","ref":"r#1","title":"t","state":"open","changed":"c","owner":"you","action_needed":true,"urgency":"now","one_line":"ol"}'

# ── since resolution ─────────────────────────────────────────────────────────

@test "_recon_resolve_since returns an explicit timestamp verbatim" {
    run _recon_resolve_since "2025-01-02T03:04:05Z"
    [ "$status" -eq 0 ]
    [ "$output" = "2025-01-02T03:04:05Z" ]
}

@test "_recon_resolve_since uses the newest checkpoint mtime when no explicit ts" {
    local proj="${BATS_TEST_TMPDIR}/proj"
    mkdir -p "$proj/.borg/checkpoints"
    touch -t 202001010000 "$proj/.borg/checkpoints/old.md"
    touch -t 202402030000 "$proj/.borg/checkpoints/new.md"
    run _recon_resolve_since "" "$proj"
    [ "$status" -eq 0 ]
    [[ "$output" == 2024-02-03T* ]]
}

@test "_recon_resolve_since falls back to the last-run marker" {
    mkdir -p "$BORG_DIR/recon"
    echo "2023-05-05T05:05:05Z" > "$BORG_DIR/recon/last-run"
    run _recon_resolve_since "" "${BATS_TEST_TMPDIR}/no-such-project"
    [ "$status" -eq 0 ]
    [ "$output" = "2023-05-05T05:05:05Z" ]
}

@test "_recon_resolve_since defaults to ~24h ago when nothing else is available" {
    run _recon_resolve_since "" "${BATS_TEST_TMPDIR}/no-such-project"
    [ "$status" -eq 0 ]
    [[ "$output" == 20*T*Z ]]
}

# ── adapter discovery ────────────────────────────────────────────────────────

@test "_recon_discover_adapters finds executable recon-adapter-* files" {
    make_adapter github '{}'
    run _recon_discover_adapters
    [ "$status" -eq 0 ]
    [[ "$output" == github$'\t'* ]]
}

@test "_recon_discover_adapters ignores non-executable files" {
    echo '{}' > "$ADAPTERS/recon-adapter-noexec"
    run _recon_discover_adapters
    [[ "$output" != *noexec* ]]
}

@test "_recon_discover_adapters dedups by source, first path wins" {
    local userdir="${BATS_TEST_TMPDIR}/userdir"
    mkdir -p "$userdir"
    printf '#!/usr/bin/env bash\necho user\n' > "$userdir/recon-adapter-dup"
    printf '#!/usr/bin/env bash\necho repo\n' > "$ADAPTERS/recon-adapter-dup"
    chmod +x "$userdir/recon-adapter-dup" "$ADAPTERS/recon-adapter-dup"
    export BORG_RECON_ADAPTER_PATH="$userdir:$ADAPTERS"
    run _recon_discover_adapters
    [ "$(echo "$output" | grep -c 'dup')" -eq 1 ]
    [[ "$output" == *"$userdir/recon-adapter-dup"* ]]
}

@test "_recon_discover_adapters is safe when a search dir has no adapters" {
    mkdir -p "${BATS_TEST_TMPDIR}/emptydir"
    export BORG_RECON_ADAPTER_PATH="${BATS_TEST_TMPDIR}/emptydir:$ADAPTERS"
    run _recon_discover_adapters
    [ "$status" -eq 0 ]
}

# ── schema validation ────────────────────────────────────────────────────────

@test "_recon_validate_item accepts a well-formed Item" {
    run _recon_validate_item "$VALID_ITEM"
    [ "$status" -eq 0 ]
}

@test "_recon_validate_item rejects a bad owner enum" {
    run _recon_validate_item "$(echo "$VALID_ITEM" | jq '.owner="boss"')"
    [ "$status" -ne 0 ]
}

@test "_recon_validate_item rejects a bad urgency enum" {
    run _recon_validate_item "$(echo "$VALID_ITEM" | jq '.urgency="soon"')"
    [ "$status" -ne 0 ]
}

@test "_recon_validate_item rejects a missing required field" {
    run _recon_validate_item "$(echo "$VALID_ITEM" | jq 'del(.ref)')"
    [ "$status" -ne 0 ]
}

@test "_recon_validate_track accepts a track object and rejects a raw dump" {
    run _recon_validate_track '{"source":"s","summary":"ok","items":[]}'
    [ "$status" -eq 0 ]
    run _recon_validate_track 'RAW LOG DUMP not json'
    [ "$status" -ne 0 ]
}

# ── fan-out ──────────────────────────────────────────────────────────────────

@test "_recon_fanout writes one track file per source, valid track marked ok" {
    make_adapter demo "{\"source\":\"demo\",\"summary\":\"1 item\",\"items\":[$VALID_ITEM]}"
    local out="${BATS_TEST_TMPDIR}/tracks"
    _recon_fanout "2025-01-01T00:00:00Z" "/dev/null" "$out" demo "$ADAPTERS/recon-adapter-demo"
    [ -f "$out/demo.json" ]
    run jq -r '.ok' "$out/demo.json"
    [ "$output" = "true" ]
    run jq -r '.items | length' "$out/demo.json"
    [ "$output" = "1" ]
}

@test "_recon_fanout isolates a broken source (ok=false, empty items)" {
    make_adapter broken 'RAW LOG DUMP not json'
    local out="${BATS_TEST_TMPDIR}/tracks"
    _recon_fanout "2025-01-01T00:00:00Z" "/dev/null" "$out" broken "$ADAPTERS/recon-adapter-broken"
    run jq -r '.ok' "$out/broken.json"
    [ "$output" = "false" ]
    run jq -r '.items | length' "$out/broken.json"
    [ "$output" = "0" ]
}

@test "_recon_fanout drops malformed items and counts them" {
    local bad='{"project":"p","source":"s","ref":"r#2","title":"t","state":"open","changed":"c","owner":"BOGUS","action_needed":true,"urgency":"now","one_line":"ol"}'
    make_adapter mix "{\"source\":\"mix\",\"summary\":\"m\",\"items\":[$VALID_ITEM,$bad]}"
    local out="${BATS_TEST_TMPDIR}/tracks"
    _recon_fanout "2025-01-01T00:00:00Z" "/dev/null" "$out" mix "$ADAPTERS/recon-adapter-mix"
    run jq -r '.items | length' "$out/mix.json"
    [ "$output" = "1" ]
    run jq -r '.dropped' "$out/mix.json"
    [ "$output" = "1" ]
}

# ── reconcile ────────────────────────────────────────────────────────────────

@test "_recon_merge_by_project groups items under their project key" {
    local t1="${BATS_TEST_TMPDIR}/t1.json" t2="${BATS_TEST_TMPDIR}/t2.json"
    echo "{\"items\":[$(echo "$VALID_ITEM" | jq '.project="alpha"')]}" > "$t1"
    echo "{\"items\":[$(echo "$VALID_ITEM" | jq '.project="beta"'),$(echo "$VALID_ITEM" | jq '.project="alpha"|.ref="r#9"')]}" > "$t2"
    run _recon_merge_by_project "$t1" "$t2"
    [ "$(echo "$output" | jq '.alpha | length')" -eq 2 ]
    [ "$(echo "$output" | jq '.beta | length')" -eq 1 ]
}

@test "_recon_checkpoint_blockers extracts the Blockers section of the newest checkpoint" {
    local proj="${BATS_TEST_TMPDIR}/proj"
    mkdir -p "$proj/.borg/checkpoints"
    cat > "$proj/.borg/checkpoints/2025-01-01-0900.md" <<'EOF'
# checkpoint
## 4. Blockers
- repo#7 waiting on review
## 5. Next Session
do stuff
EOF
    run _recon_checkpoint_blockers "$proj"
    [[ "$output" == *"repo#7 waiting on review"* ]]
    [[ "$output" != *"do stuff"* ]]
}

@test "_recon_project_contradictions flags a resolved item still listed as a blocker" {
    local items="[$(echo "$VALID_ITEM" | jq '.project="alpha"|.ref="repo#7"|.state="merged"')]"
    run _recon_project_contradictions alpha "- repo#7 waiting on review" "$items"
    [ "$(echo "$output" | jq 'length')" -eq 1 ]
    [ "$(echo "$output" | jq -r '.[0].ref')" = "repo#7" ]
}

@test "_recon_project_contradictions is empty when the item is not resolved" {
    local items="[$(echo "$VALID_ITEM" | jq '.ref="repo#7"|.state="open"')]"
    run _recon_project_contradictions alpha "- repo#7 waiting on review" "$items"
    [ "$(echo "$output" | jq 'length')" -eq 0 ]
}

@test "_recon_project_contradictions is empty when there are no blockers" {
    local items="[$(echo "$VALID_ITEM" | jq '.state="merged"')]"
    run _recon_project_contradictions alpha "" "$items"
    [ "$(echo "$output" | jq 'length')" -eq 0 ]
}

# ── cairn hook (fail-quiet, /record/batch writeback) ────────────────────────────

# Write a mock `curl` on PATH that records its args + stdin to files under $CURL_CALLS, then
# exits with the given code (default 0). Usage: make_mock_curl [exit_code]
make_mock_curl() {
    local exit_code="${1:-0}"
    export CURL_CALLS="${BATS_TEST_TMPDIR}/curl_calls"
    mkdir -p "$CURL_CALLS"
    cat > "$MOCK_BIN/curl" <<EOF
#!/usr/bin/env bash
echo "\$@" > "$CURL_CALLS/args"
# Find the --data @<file> argument and copy its contents as the posted body.
prev=""
for a in "\$@"; do
    if [ "\$prev" = "--data" ]; then
        cp "\${a#@}" "$CURL_CALLS/body" 2>/dev/null || true
    fi
    prev="\$a"
done
exit $exit_code
EOF
    chmod +x "$MOCK_BIN/curl"
}

DOC_WITH_CONTRADICTION='{"since":"s","generated_at":"g","sources":[],"items_by_project":{},
  "contradictions":[{"project":"alpha","ref":"PR#42","checkpoint_says":"blocked",
    "source_says":"merged — shipped it","note":"checkpoint still calls this blocked"}]}'

DOC_NO_CONTRADICTIONS='{"since":"s","generated_at":"g","sources":[],"items_by_project":{},"contradictions":[]}'

@test "_recon_stable_id is deterministic for the same (project, ref)" {
    run _recon_stable_id alpha "PR#42"
    local first="$output"
    run _recon_stable_id alpha "PR#42"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
    [[ "$output" == recon-alpha-* ]]
}

@test "_recon_persist_contradictions POSTs a valid batch with a stable item id" {
    setup_mock_bin
    make_mock_curl 0
    unset BORG_RECON_NO_CAIRN
    run _recon_persist_contradictions "$DOC_WITH_CONTRADICTION"
    [ "$status" -eq 0 ]
    [ -f "$CURL_CALLS/args" ]
    grep -q '/record/batch' "$CURL_CALLS/args"
    [ -f "$CURL_CALLS/body" ]
    run jq -e . "$CURL_CALLS/body"
    [ "$status" -eq 0 ]
    local expected_id; run _recon_stable_id alpha "PR#42"
    expected_id="$output"
    run jq -r --arg id "$expected_id" '.items[] | select(.id == $id) | .type' "$CURL_CALLS/body"
    [ "$status" -eq 0 ]
    [ "$output" = "observation" ]
}

@test "_recon_persist_contradictions honors the BORG_RECON_NO_CAIRN opt-out (no POST)" {
    setup_mock_bin
    make_mock_curl 0
    export BORG_RECON_NO_CAIRN=1
    run _recon_persist_contradictions "$DOC_WITH_CONTRADICTION"
    [ "$status" -eq 0 ]
    [ ! -f "$CURL_CALLS/args" ]
}

@test "_recon_persist_contradictions is a no-op when curl is absent" {
    unset BORG_RECON_NO_CAIRN
    mkdir -p "${BATS_TEST_TMPDIR}/empty"
    local old_path="$PATH"
    PATH="${BATS_TEST_TMPDIR}/empty"
    run _recon_persist_contradictions "$DOC_WITH_CONTRADICTION"
    PATH="$old_path"
    [ "$status" -eq 0 ]
}

@test "_recon_persist_contradictions still returns 0 when the endpoint is down" {
    setup_mock_bin
    make_mock_curl 22
    unset BORG_RECON_NO_CAIRN
    run _recon_persist_contradictions "$DOC_WITH_CONTRADICTION"
    [ "$status" -eq 0 ]
}

@test "_recon_persist_contradictions skips the POST when there are zero contradictions" {
    setup_mock_bin
    make_mock_curl 0
    unset BORG_RECON_NO_CAIRN
    run _recon_persist_contradictions "$DOC_NO_CONTRADICTIONS"
    [ "$status" -eq 0 ]
    [ ! -f "$CURL_CALLS/args" ]
}
