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

load test_helper/setup

setup() {
    setup_temp_dirs
    source "$BORG_HOME/lib/recon.sh"
    export ADAPTERS="${BATS_TEST_TMPDIR}/adapters"
    mkdir -p "$ADAPTERS"
    export BORG_RECON_ADAPTER_PATH="$ADAPTERS"
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
    [[ "$output" == 2024-02-03T* ]] || false
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
    [[ "$output" == 20*T*Z ]] || false
}

# ── adapter discovery ────────────────────────────────────────────────────────

@test "_recon_discover_adapters finds executable recon-adapter-* files" {
    make_adapter github '{}'
    run _recon_discover_adapters
    [ "$status" -eq 0 ]
    [[ "$output" == github$'\t'* ]] || false
}

@test "_recon_discover_adapters ignores non-executable files" {
    echo '{}' > "$ADAPTERS/recon-adapter-noexec"
    run _recon_discover_adapters
    [[ "$output" != *noexec* ]] || false
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
    [[ "$output" == *"$userdir/recon-adapter-dup"* ]] || false
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
    [[ "$output" == *"repo#7 waiting on review"* ]] || false
    [[ "$output" != *"do stuff"* ]] || false
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

# ── Regression: default adapter path + zsh word-splitting ────────────────────────────────────────
#
# Both bugs these cover shipped in #95 and survived until 2026-08-10 for the same reason: EVERY
# other test in this file sets BORG_RECON_ADAPTER_PATH to a single directory. That override
# short-circuits _recon_adapter_path() entirely, so the default two-directory path was never
# resolved, and the colon-splitting was never exercised with more than one element.
#
# On top of that, bats runs bash and the borg CLI runs zsh. zsh does not word-split unquoted
# parameter expansions, so `IFS=:; set -- $var` yielded ONE argument in zsh and TWO in bash — the
# suite passed green while `borg recon` found zero adapters on the real CLI and exited 0.

# WHICH OF THESE ACTUALLY GATES THE BUG. Reverting the fix and re-running locally fails only the
# zsh test — the bash tests still pass, because the old implementation worked correctly in bash.
# That is the entire nature of the bug, and it makes the zsh test the real gate.
#
# Read that local result with care, though: macOS ships bash 3.2.57 (2007), whose `set -e` does not
# fire on a failing `[[ ]]` unless it is the LAST command in the body, so intermediate assertions
# are silently ignored locally. CI runs Ubuntu bash 5.x and enforces them. Local green is therefore
# WEAKER than CI green on this machine — treat CI as the gate, not a local run.
@test "BORG_RECON_LIB_DIR override is honored by the adapter path" {
    unset BORG_RECON_ADAPTER_PATH
    export BORG_RECON_LIB_DIR="/sentinel/lib"
    run _recon_adapter_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"/sentinel/lib/recon/adapters"* ]] || false
    [[ "$output" != *":./recon/adapters"* ]] || false
}

@test "adapter discovery splits a multi-directory search path" {
    local d2="${BATS_TEST_TMPDIR}/adapters2"
    mkdir -p "$d2"
    make_adapter "alpha" '{"source":"alpha","summary":"s","items":[]}'
    printf '#!/usr/bin/env bash\necho ok\n' > "$d2/recon-adapter-beta"
    chmod +x "$d2/recon-adapter-beta"

    export BORG_RECON_ADAPTER_PATH="$ADAPTERS:$d2"
    run _recon_discover_adapters
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]] || false
    [[ "$output" == *"beta"* ]] || false
}

@test "zsh CLI discovers the repo's shipped github adapter" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not available"
    unset BORG_RECON_ADAPTER_PATH
    run zsh -c "unset BORG_RECON_ADAPTER_PATH; '$BORG_HOME/borg.zsh' recon --adapters"
    [ "$status" -eq 0 ]
    [[ "$output" == *"github"* ]] || false
    [[ "$output" != *"No recon adapters found"* ]] || false
}
