#!/usr/bin/env bats
# Headless `claude -p` call sites must pin their tier explicitly, never inherit the session default.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    RUN="$ROOT/evals/lifecycle-manifests/run.sh"
}

@test "lifecycle eval pins --model and --effort at every claude -p site" {
    sites="$(grep -E 'claude -p' "$RUN" | grep -v '^[[:space:]]*#' | wc -l)"
    [ "$sites" -ge 2 ]
    unpinned="$(grep -E 'claude -p' "$RUN" | grep -v '^[[:space:]]*#' | grep -v -- '--model' || true)"
    [ -z "$unpinned" ]
    unpinned="$(grep -E 'claude -p' "$RUN" | grep -v '^[[:space:]]*#' | grep -v -- '--effort' || true)"
    [ -z "$unpinned" ]
}

@test "summarize.py does not use --bare or CLAUDE_CODE_SIMPLE" {
    run grep -nE -- '--bare|CLAUDE_CODE_SIMPLE' "$ROOT/summarize.py"
    [ "$status" -ne 0 ]
}

@test "summarize_llm invokes claude without --bare and returns its output" {
    stub="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$stub"
    cat > "$stub/claude" <<'STUB'
#!/bin/sh
case "$*" in *--bare*) exit 1;; esac
echo "Goal sentence. Next step sentence."
STUB
    chmod +x "$stub/claude"
    run env PATH="$stub:$PATH" ROOT="$ROOT" python3 -I -c '
import os, sys
sys.path.insert(0, os.environ["ROOT"])
import summarize
print(summarize.summarize_llm([{"type": "user", "message": {"role": "user", "content": "fix the bug"}}]))'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Goal sentence."* ]]
}
