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
    mkdir -p "$dir/.borg/programs"
    printf '{"program":"%s","rows":%s}\n' "$stem" "$rows" > "$dir/.borg/programs/${stem}.json"
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
    for b in bash sh env git jq python3 sed grep awk cat printf date mkdir rm ls dirname basename tr wc sort head tail; do
        src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$bindir/$b"
    done
    install -m 0755 "$ghbody" "$bindir/gh"
    printf '%s\n' "$bindir"
}
