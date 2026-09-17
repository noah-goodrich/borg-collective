#!/usr/bin/env bash
# Oracle for evals/lifecycle-manifests/run.sh's guards and fixtures. NEEDS NO MODEL, so CI runs it
# on the same leg as the rest of the suite while the cases it guards cannot run there at all.
#
# WHY THIS FILE EXISTS. run.sh is model-only: all six cases call `claude`, so no CI job can execute
# them and their only forcing function is someone remembering. That is exactly the shape that let
# `make eval-live` report SUCCESS at exit 0 on a machine with no `claude` installed and the entire
# model sweep absent -- a green run of nothing. The repair was a mode floor, and then the discovery
# that the floor ITSELF had no oracle and could be deleted with every gate staying green. So the
# floor lands with its pair, and the pair runs where the floor does not.
#
# EVERY CASE IS IN THE FIRING DIRECTION AND THE DIRECTION THAT PROVES IT DISCRIMINATES. A guard
# asserted only firing is satisfied just as well by an artifact that always fails.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
RUN="$HERE/run.sh"

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"

PASS=0; FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "== floor: fixture builders =="

# ── 1. the manifest fixture VALIDATES, both directions ───────────────────────────────────────────
#
# THE CASE THAT ALREADY CAUGHT A REAL DEFECT. The first builder used an escaped default expansion
# and leaked backslashes into the JSON, so `discover()` rejected the file. "Rejected" and "absent"
# are indistinguishable downstream, so every negative case would have passed for the wrong reason.
d="$(_eval_repo_with_manifest "$WORK/valid" prog)"
if [ -f "$d/.borg/programs/prog.json" ] && python3 -c '
import json, sys
json.load(open(sys.argv[1]))' "$d/.borg/programs/prog.json" 2>/dev/null; then
    ok "manifest fixture is parseable JSON"
else
    bad "manifest fixture is not parseable JSON"
fi

if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
sys.exit(0 if len(ms) == 1 and not warns else 1)' "$d" 2>/dev/null; then
    ok "manifest fixture is DISCOVERABLE with zero warnings"
else
    bad "manifest fixture is rejected by discover() — negatives would pass for the wrong reason"
fi

# The discriminating direction: a deliberately malformed row MUST be rejected, or the assertion
# above proves nothing about validity.
bd="$(_eval_repo_with_manifest "$WORK/badrows" prog '[{"ref":"not-a-ref"}]')"
if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
sys.exit(0 if not ms and warns else 1)' "$bd" 2>/dev/null; then
    ok "a malformed-row fixture IS rejected (the check discriminates)"
else
    bad "a malformed-row fixture was accepted — the validity check is vacuous"
fi

# ── 2. the manifest-LESS fixture provably has no .borg ───────────────────────────────────────────
#
# "No manifest" is the premise of N2, and a stray `.borg` silently inverts it.
# A `.borg` is PLANTED FIRST, so the builder's removal is genuinely required. Without this the
# assertion passed whether or not the builder removed anything — `_eval_repo` never creates `.borg`,
# so "absent because removed" and "absent because never made" were indistinguishable.
mkdir -p "$WORK/none/.borg/programs"
printf '{"program":"stale","rows":[]}\n' > "$WORK/none/.borg/programs/stale.json"
nd="$(_eval_repo_without_manifest "$WORK/none")"
if [ ! -e "$nd/.borg" ]; then
    ok "manifest-less fixture has NO .borg at all"
else
    bad "manifest-less fixture carries .borg — N2's premise is inverted"
fi
if [ -d "$d/.borg" ]; then
    ok "and the with-manifest fixture does carry one (the pair discriminates)"
else
    bad "with-manifest fixture has no .borg"
fi

# ── 3. fixtures carry a real commit ──────────────────────────────────────────────────────────────
#
# A repository with no commit fails for reasons unrelated to any assertion, and git refuses to
# commit at all on a bare Linux runner without an identity -- which is why _eval_git_env exports
# GIT_AUTHOR_* rather than writing a .gitconfig the sandbox's redirected $HOME would hide.
if git -C "$d" rev-parse HEAD >/dev/null 2>&1; then
    ok "fixture repository has a commit"
else
    bad "fixture repository has no commit — cases would fail for an unrelated reason"
fi

echo "== floor: the allowlist bin dir =="

# ── 4. the allowlist contains bash, and does NOT contain the real gh ─────────────────────────────
#
# Rule 3: a `#!/usr/bin/env bash` shebang searches the PATH UNDER TEST for its own interpreter, so
# omitting bash means the stub never runs. Rule 2: the point is that the real gh is unreachable,
# and asserting that by name is stronger than assuming a directory list excludes it.
printf '#!/bin/sh\necho "{\\"number\\":7}"\n' > "$WORK/ghstub"
chmod +x "$WORK/ghstub"
bindir="$(_eval_allowlist_bin "$WORK/bin" "$WORK/ghstub")"
if [ -e "$bindir/bash" ]; then
    ok "allowlist includes bash (the shebang can resolve)"
else
    bad "allowlist omits bash — a bash-shebang stub cannot run"
fi
real_gh="$(command -v gh 2>/dev/null || true)"
stub_target="$(readlink "$bindir/gh" 2>/dev/null || echo "$bindir/gh")"
if [ -z "$real_gh" ] || [ "$stub_target" != "$real_gh" ]; then
    ok "allowlist's gh is the STUB, not the real binary"
else
    bad "allowlist's gh resolves to the real binary"
fi
if PATH="$bindir" gh 2>/dev/null | grep -q '"number"'; then
    ok "the gh stub is reachable and answers under the allowlist PATH"
else
    bad "the gh stub does not answer under the allowlist PATH"
fi

echo "== floor: run.sh's own guards =="

# ── 5. --skip-model requests nothing, runs nothing, exits 0, and SAYS SO ─────────────────────────
if [ -x "$RUN" ]; then
    out="$("$RUN" --skip-model 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then ok "--skip-model exits 0"; else bad "--skip-model exits $rc"; fi
    if printf '%s' "$out" | grep -qi 'no offline cases\|requested nothing'; then
        ok "--skip-model says plainly that it ran nothing"
    else
        bad "--skip-model is silent about having run nothing"
    fi

    # ── 6. --skip-network is ACCEPTED and inert ─────────────────────────────────────────────────
    #
    # `make eval` globs evals/*/run.sh and passes EVAL_ARGS to every harness, so an unknown flag
    # exits 2 and turns the whole target red for a reason unrelated to this harness.
    "$RUN" --skip-network --skip-model >/dev/null 2>&1
    if [ $? -ne 2 ]; then
        ok "--skip-network is accepted (does not exit 2)"
    else
        bad "--skip-network exits 2 — make eval would go red on every harness"
    fi

    # ── 7. the model floor FIRES when the sweep is requested and claude is hidden ────────────────
    #
    # And the cases must SKIP rather than FAIL in that same run: an absent `claude` is a different
    # fact from a wrong one, and conflating them is exactly what the floor must not do.
    out="$(PATH="$bindir" "$RUN" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        ok "model floor FIRES at rc $rc when claude is unavailable"
    else
        bad "model floor did not fire — a sweep of nothing exited 0"
    fi
    # ANCHORED ON A CASE LINE, not anywhere in the output. The first version grepped for `skip`
    # and the summary line itself says "N skipped" — so replacing every SKIP with a FAIL left the
    # check green. Fourth instance in this session of one root cause: matching a string that also
    # appears somewhere innocuous. Count the `  SKIP  ` case prefix and require the FAIL prefix to
    # be absent, which is the pair that actually discriminates.
    n_skip=$(printf '%s\n' "$out" | grep -cE '^  SKIP  ')
    n_fail=$(printf '%s\n' "$out" | grep -cE '^  FAIL  ')
    if [ "$n_skip" -eq 6 ] && [ "$n_fail" -eq 0 ]; then
        ok "all six cases SKIP and none FAILs when claude is absent"
    else
        bad "expected 6 SKIP / 0 FAIL case lines, got $n_skip / $n_fail — absent input read as a defect"
    fi
else
    bad "run.sh is not executable — nothing below could be checked"
fi

echo
echo "floor: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
