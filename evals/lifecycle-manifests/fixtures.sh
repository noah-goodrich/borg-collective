#!/usr/bin/env bash
# Fixture builders for the lifecycle-manifest evals (AC5.3-AC5.5).
#
# Sourced by both run.sh and floor-tests.sh so the two cannot drift: the floor tests assert
# properties OF THESE BUILDERS, and a floor that tested a second copy would prove nothing about the
# harness. That is the same reason `claude-plugins/evals/pr-description/floor-tests.sh` exists
# beside its run.sh rather than re-deriving the fixtures.
#
# EVERY RULE BELOW TRACES TO A MEASURED FAILURE IN THIS TREE. None is defensive habit:
#
#   1. Every fixture is SYNTHESIZED by `git init` under $OUT. No case may name or require a second
#      repository. E3/E4/E5 previously required stillpoint and troth checkouts and SKIPped
#      otherwise -- measured 2026-09-03, neither was present, so the entire model sweep was absent
#      on the machine of record while `make eval-live` reported a green sweep of nothing.
#   2. `gh` is supplied by a STUB in an allowlist bin dir DERIVED FROM THE SKILL'S OWN NEEDS, never
#      by `PATH="/usr/bin:/bin"`. `ubuntu-latest` preinstalls `/usr/bin/gh`, so hiding a binary by
#      naming directories it *isn't* in is a premise that holds only on macOS.
#   3. The allowlist must include `bash` ITSELF, or a `#!/usr/bin/env bash` shebang searches the
#      PATH under test for its own interpreter and the stub never runs.
#   4. Fixtures need a real commit and a real git identity. `setup_temp_dirs` redirects $HOME, and
#      git auto-derives an identity from getpwuid plus a resolvable hostname on macOS but REFUSES
#      outright on a bare Linux runner. Env vars, not a written .gitconfig, because the sandbox
#      redirects both $HOME and $XDG_CONFIG_HOME and env vars beat every config layer.
#   5. $OUT is RECREATED, never ensured. A stale artifact from a previous run is a false PASS for a
#      case that produced nothing this time.

# ── where a manifest lives, in ONE place ─────────────────────────────────────────────────────────
# `.borg/chains`, the name #222's expand phase made primary. These fixtures were authored under
# `.borg/programs` and stayed there until that PR was in `main`, because a fixture under a name
# `discover()` does not yet know is "rejected", which reads downstream exactly like "absent".
# Flipping this one value was the whole migration for this harness. The legacy name is still
# readable (expand, not contract), so run.sh's N2 checks that NEITHER name was created.
_EVAL_MANIFEST_DIR=".borg/chains"

# ── the interpreter ladder, in ONE place ─────────────────────────────────────────────────────────
# run.sh and floor-tests.sh both need an interpreter with an importable pytest, which is a dev-group
# dependency that lives in `.venv` and NOT on the ambient PATH on the machine of record. Same three
# rungs as `evals/s4-k3/run.sh`: the `BORG_EVAL_PYTHON` override (the seam `tests/eval_floor.bats`
# reaches through), then the venv, then bare `python3` for a CI job that installs the dev group into
# the ambient environment. Two copies of this ladder would be two places for it to drift.
# Args: <repo>
_eval_python() {
    if [ -n "${BORG_EVAL_PYTHON:-}" ]; then
        printf '%s\n' "$BORG_EVAL_PYTHON"
    elif [ -x "$1/.venv/bin/python" ]; then
        printf '%s\n' "$1/.venv/bin/python"
    else
        printf '%s\n' python3
    fi
}

# ── git identity (rule 4) ────────────────────────────────────────────────────────────────────────
_eval_git_env() {
    export GIT_AUTHOR_NAME="eval" GIT_AUTHOR_EMAIL="eval@localhost"
    export GIT_COMMITTER_NAME="eval" GIT_COMMITTER_EMAIL="eval@localhost"
    export GIT_CONFIG_NOSYSTEM=1
}

# A synthesized repository with one commit. Rule 1: no case may name a second repository.
# Args: <dir> [remote-slug]
_eval_repo() {
    local dir="$1" slug="${2:-o/r}"
    _eval_git_env
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "https://github.com/${slug}.git" 2>/dev/null || true
    printf 'fixture\n' > "$dir/README.md"
    git -C "$dir" add README.md
    # A repository with no commit fails for reasons unrelated to any assertion.
    git -C "$dir" commit --quiet -m "fixture" >/dev/null 2>&1
    printf '%s\n' "$dir"
}

# A repository carrying a VALID manifest. Rows must actually validate or `discover()` rejects the
# file and every later assertion reads an empty list -- "rejected" and "absent" are
# indistinguishable downstream, which is how a case comes to pass for the wrong reason.
# Args: <dir> <stem> [rows-json]
_eval_repo_with_manifest() {
    local dir="$1" stem="$2" rows="${3:-}"
    # The default is built with single quotes, NOT an escaped default expansion. The first version
    # used `${3:-[{\"ref\"...}]}` and the backslashes SURVIVED into the file, producing
    # `Expecting ',' delimiter` -- an invalid manifest that `discover()` rejects. Caught only because
    # the floor asserts the fixture validates; "rejected" and "absent" are indistinguishable
    # downstream, which is precisely the wrong-reason pass this builder exists to prevent.
    if [ -z "$rows" ]; then
        rows='[{"ref":"o/r#1","lane":"alpha","order":"1","why":"seed row"}]'
    fi
    _eval_repo "$dir" >/dev/null
    mkdir -p "$dir/$_EVAL_MANIFEST_DIR"
    printf '{"program":"%s","rows":%s}\n' "$stem" "$rows" > "$dir/$_EVAL_MANIFEST_DIR/${stem}.json"
    printf '%s\n' "$dir"
}

# A repository that provably has NO .borg at all. Asserted rather than assumed, because "no
# manifest" is the premise of every negative case and a stray directory silently inverts it.
# Args: <dir>
_eval_repo_without_manifest() {
    local dir="$1"
    _eval_repo "$dir" >/dev/null
    rm -rf "$dir/.borg"
    printf '%s\n' "$dir"
}

# A plan file declaring a slug, which is what `manifest.cli resolve` rule 3 reads.
# Args: <dir> <slug>
_eval_plan() {
    local dir="$1" slug="$2"
    # shellcheck disable=SC2016
    # JUSTIFICATION: the backticks around %s are LITERAL markdown -- the `- Plan-slug:` convention
    # wraps its value in them, and `manifest.cli resolve` strips them on read. Single quotes are
    # correct here precisely because nothing should expand.
    printf '# Project Plan: fixture\n*Established: 2026-01-01*\n\n- Plan-slug: `%s`\n\n## Objective\n\nfixture\n' \
        "$slug" > "$dir/PROJECT_PLAN.md"
}

# An allowlist bin dir holding ONLY what the skill under test calls, plus a `gh` stub.
# Rules 2 and 3: derived from need, and `bash` is included or the shebang cannot resolve.
# Args: <bindir> <gh-stub-body-file>
_eval_allowlist_bin() {
    local bindir="$1" ghbody="$2" b src
    mkdir -p "$bindir"
    # `claude` IS ON THIS LIST AND ITS ABSENCE COST TWO FULL SWEEPS. Rule 2 says the allowlist is
    # derived from the skill's own needs and rule 3 says it must include `bash` itself or a shebang
    # cannot resolve — and the first version applied that reasoning to `bash` while omitting the one
    # binary the harness exists to invoke. Every case failed with the skill never running, which is
    # indistinguishable from the skill running and declining. Pinned by a floor case.
    # `security` IS ON THIS LIST BECAUSE claude READS ITS CREDENTIALS FROM THE MACOS KEYCHAIN.
    # Measured 2026-09-17: with `security` on the allowlist a trivial prompt returns `READY` at
    # rc 0; without it, claude prints "Not logged in · Please run /login" and exits 1 — while
    # `command -v claude` still succeeds, so the harness saw a present-but-unusable binary and
    # graded it as a FAILING SKILL. Exactly the class of the `--bare skipped the keychain` defect
    # fixed in #200, where a flag that suppressed keychain reads made borg report its own flag as a
    # missing credential.
    for b in claude security bash sh env git jq python3 sed grep awk cat printf date mkdir rm ls dirname basename tr wc sort head tail; do
        src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$bindir/$b"
    done
    install -m 0755 "$ghbody" "$bindir/gh"
    printf '%s\n' "$bindir"
}

# A repository holding a SMALL REAL PROJECT: source, a test, and a README naming a genuine gap.
#
# WHY THIS IS NOT DECORATION. Measured 2026-09-17: given a bare fixture (one commit, a README
# containing the word "fixture"), `/borg-plan` read everything and declined -- "the 'probe-slug' name
# suggests it exists to exercise the borg tooling itself." That is the skill behaving CORRECTLY: a
# planning conversation needs something to plan about. A fixture that cannot sustain the
# conversation cannot exercise the step that follows it.
#
# The gap is named in the README on purpose, so the objective the prompt supplies is one a reader of
# the repository would actually reach.
# Args: <dir>
_eval_repo_with_project() {
    local dir="$1"
    _eval_repo "$dir" >/dev/null
    mkdir -p "$dir/src" "$dir/tests"
    printf 'def add(a, b):\n    return a + b\n\n\ndef mul(a, b):\n    return a * b\n' > "$dir/src/calc.py"
    printf 'from src.calc import add, mul\n\n\ndef test_add():\n    assert add(1, 2) == 3\n\n\ndef test_mul():\n    assert mul(2, 3) == 6\n' \
        > "$dir/tests/test_calc.py"
    printf '# calc\n\nA tiny arithmetic library.\n\nThere is no CI and no coverage gate yet.\n' \
        > "$dir/README.md"
    _eval_git_env
    git -C "$dir" add -A >/dev/null 2>&1
    git -C "$dir" commit --quiet -m "real project" >/dev/null 2>&1
    printf '%s\n' "$dir"
}

# THE PROMPT SHAPE, in one place so all three positives cannot drift apart.
#
# It carries the slash command, an objective, and a CONFIRMATION -- because the skill's own
# `## The Conversation` says "Confirm any adjustment before moving on", so a single headless
# invocation reaches the output step only if the confirmation is supplied. Working with the skill's
# shape rather than against it.
#
# IT MENTIONS NO MANIFEST, NO `.borg`, NO SCAFFOLD, AND NO ROW. That is the property AC5.2 actually
# cares about -- "no manifest hint, so a pass is proof the behaviour is default rather than
# requested." The original "bare slash command" wording was a PROXY for that property, and a broken
# one: it also removed the confirmation, which made the output step unreachable and every positive
# case a false negative. The requirement is preserved; the proxy is replaced.
#
# `_eval_prompt_mentions_no_manifest` below is the mechanical check that keeps this honest.
# Args: <slash-command> <objective-sentence>
_eval_prompt() {
    printf '%s\n\nObjective: %s\n\nThat objective is correct — proceed, and use your own judgement for the details. Treat this as confirmed; do not wait for further input.\n' \
        "$1" "$2"
}

# Refuses a prompt that would leak a hint, which is what makes the "default behaviour" claim
# checkable rather than asserted. Exits non-zero and names the offending word.
# Args: <prompt-text>
_eval_prompt_mentions_no_manifest() {
    local prompt="$1" word
    for word in manifest .borg scaffold add-row program lane row; do
        case "$prompt" in
            *"$word"*) echo "prompt leaks a hint: $word" >&2; return 1 ;;
        esac
    done
    return 0
}
