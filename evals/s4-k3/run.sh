#!/usr/bin/env bash
# S4 + K3/AC3 acceptance eval — on-demand, NOT CI (needs live GitHub refs and two headless
# model runs). Green here + merge-tree/test_s4_manifests.py green is the landing gate for S4
# and the evidence for K3's AC3 ("correct chain position for a manifest-declared PR").
#
# Evals:
#   E1  cross-repo discovery: both owning repos' manifests load with zero warnings
#   E2  live refs: every declared ref resolves on GitHub (no typo'd rows)
#   E3  gather integration: declared edges flow, zero contested refs
#   E4  K3 manifest path: /pr-description on a manifest-declared PR branch renders chain
#       position FROM THE MANIFEST (program, lane, gate) — not the fallback
#   E5  K3 fallback path: /pr-description in a manifest-less repo says "No manifest declared."
#       (proves the conditional discriminates; without this E4 could pass vacuously)
#
# Usage: evals/s4-k3/run.sh [--skip-model]   (--skip-model runs E1-E3 only)

set -uo pipefail

REPO=/Users/noah/dev/borg-collective
STILLPOINT=/Users/noah/dev/stillpoint
TROTH=/Users/noah/dev/troth
OUT="$REPO/evals/s4-k3/out"
mkdir -p "$OUT"

PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

echo "== E1: cross-repo discovery =="
E1=$(cd "$REPO/merge-tree" && python3 - "$REPO" "$STILLPOINT" <<'PY'
import sys
import programs
manifests, warnings = programs.discover(sys.argv[1:])
names = sorted(m["program"] for m in manifests)
print(f"manifests={names} warnings={warnings}")
ok = warnings == [] and "viz-program" in names and "ingle-t1-cutover" in names
sys.exit(0 if ok else 1)
PY
)
E1_RC=$?
echo "  $E1"
[ "$E1_RC" -eq 0 ] && ok "E1 discovery: both manifests, zero warnings" || bad "E1 discovery"

echo "== E2: every declared ref resolves on GitHub =="
E2_FAILS=$(cd "$REPO/merge-tree" && python3 - "$REPO" "$STILLPOINT" <<'PY'
import subprocess
import sys
import programs
manifests, _ = programs.discover(sys.argv[1:])
refs = set()
for m in manifests:
    for r in m.get("rows", []):
        refs.add(r["ref"])
    apex = m.get("apex")
    if isinstance(apex, dict) and apex.get("ref"):
        refs.add(apex["ref"])
bad = []
for ref in sorted(refs):
    repo, num = ref.rsplit("#", 1)
    p = subprocess.run(["gh", "pr", "view", num, "--repo", repo, "--json", "state"],
                       capture_output=True, text=True, timeout=30)
    if p.returncode != 0:
        bad.append(ref)
print(f"checked={len(refs)} unresolved={bad}")
sys.exit(1 if bad else 0)
PY
)
E2_RC=$?
echo "  $E2_FAILS"
[ "$E2_RC" -eq 0 ] && ok "E2 refs: all resolve" || bad "E2 refs: unresolved rows"

echo "== E3: gather integration (live recon) =="
E3=$(cd "$REPO/merge-tree" && borg recon --json --since 2026-08-01T00:00:00Z 2>/dev/null | \
     python3 gather.py --in - --out "$OUT/e3-gather.json" \
       --programs-dir "$REPO" --programs-dir "$STILLPOINT" 2>"$OUT/e3-stderr.txt"; \
     python3 -c "
import json
g = json.load(open('$OUT/e3-gather.json'))
prov = g['meta']['edge_provenance']
print(f\"declared={prov['declared']} contested={g['meta']['program_contested_refs']} dangling={len(prov['dangling_endpoints'])}\")
exit(0 if prov['declared'] >= 14 and g['meta']['program_contested_refs'] == [] else 1)
")
E3_RC=$?
echo "  $E3"
[ "$E3_RC" -eq 0 ] && ok "E3 gather: declared edges flow, zero contested" || bad "E3 gather"

# macOS has no GNU `timeout`; use gtimeout when available, else rely on claude -p terminating.
TIMEOUT=""
command -v gtimeout >/dev/null 2>&1 && TIMEOUT="gtimeout 420"

if [ "${1:-}" = "--skip-model" ]; then
    echo "== E4/E5 skipped (--skip-model) =="
else
    echo "== E4: /pr-description reads the manifest (stillpoint#48 branch) =="
    WT=/tmp/s4-eval-stillpoint
    git -C "$STILLPOINT" worktree remove --force "$WT" 2>/dev/null
    git -C "$STILLPOINT" fetch origin write-freeze-design 2>/dev/null
    git -C "$STILLPOINT" worktree add "$WT" origin/write-freeze-design --detach 2>/dev/null
    mkdir -p "$WT/.borg/programs"
    cp "$STILLPOINT/.borg/programs/ingle-t1-cutover.json" "$WT/.borg/programs/"
    (cd "$WT" && $TIMEOUT claude -p "/pr-description" > "$OUT/e4-body.md" 2>"$OUT/e4-stderr.txt")
    if grep -q "ingle-t1-cutover" "$OUT/e4-body.md" && \
       grep -qi "cutover" "$OUT/e4-body.md" && \
       ! grep -q "No manifest declared" "$OUT/e4-body.md"; then
        ok "E4 chain position rendered from the manifest"
    else
        bad "E4 chain position (see $OUT/e4-body.md)"
    fi
    git -C "$STILLPOINT" worktree remove --force "$WT" 2>/dev/null

    echo "== E5: fallback path in a manifest-less repo (troth) =="
    (cd "$TROTH" && $TIMEOUT claude -p "/pr-description" > "$OUT/e5-body.md" 2>"$OUT/e5-stderr.txt")
    if grep -q "No manifest declared" "$OUT/e5-body.md"; then
        ok "E5 fallback line present"
    else
        bad "E5 fallback (see $OUT/e5-body.md)"
    fi
fi

echo
echo "RESULT: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
