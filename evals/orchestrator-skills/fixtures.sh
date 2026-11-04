#!/usr/bin/env bash
# Fixture builders for the orchestrator-skills evals. Sourced by live.sh and run.sh, so the offline proofs assert
# properties OF THESE BUILDERS and not of a second copy.
#
# This file is deliberately its own copy of the three helpers it needs from evals/lifecycle-manifests (the
# interpreter ladder, the git identity, the allowlist bin). tests/eval_floor.bats runs every harness against a sandbox
# checkout that carries no sibling evals/ directory, so a harness may not source another harness's files.
#
# Rules, each from a measured failure in this tree (see evals/lifecycle-manifests/fixtures.sh for the originals):
#   1. Every fixture is synthesized by `git init` under $OUT. No case names or needs a second repository.
#   2. The PATH a live case sees is an ALLOWLIST derived from need, never `/usr/bin:/bin`: ubuntu-latest preinstalls
#      tools macOS does not, so hiding a binary by naming directories it is not in holds on one platform only.
#   3. The allowlist includes `bash` itself, or a `#!/usr/bin/env bash` shebang cannot resolve its interpreter.
#   4. A real commit and a real git identity (env vars, not a .gitconfig: they beat every config layer).
#   5. The ledger a borg-resume case reads is written by the PRODUCTION code (`borg-resume record` and `watch --once`),
#      then given ONE edit (its scope, which only a liveness scan of a real workflow directory produces). The status
#      JSON the skill reads is the real CLI's output over it, never a hand-written document.

_os_python() {
    if [ -n "${BORG_EVAL_PYTHON:-}" ]; then
        printf '%s\n' "$BORG_EVAL_PYTHON"
    elif [ -x "$1/.venv/bin/python" ]; then
        printf '%s\n' "$1/.venv/bin/python"
    else
        printf '%s\n' python3
    fi
}

_os_git_env() {
    export GIT_AUTHOR_NAME="eval" GIT_AUTHOR_EMAIL="eval@localhost"
    export GIT_COMMITTER_NAME="eval" GIT_COMMITTER_EMAIL="eval@localhost"
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
}

# A synthesized repository with one commit.
# Args: <dir>
_os_repo() {
    local dir="$1"
    _os_git_env
    mkdir -p "$dir"
    git -C "$dir" init --quiet -b main
    printf '# fixture\n' > "$dir/README.md"
    git -C "$dir" add -A >/dev/null 2>&1
    git -C "$dir" commit --quiet -m "fixture" >/dev/null 2>&1
    printf '%s\n' "$dir"
}

# Commit everything currently in the tree. Args: <dir> <message>
_os_commit() {
    _os_git_env
    git -C "$1" add -A >/dev/null 2>&1
    git -C "$1" commit --quiet -m "$2" >/dev/null 2>&1
}

# The allowlist bin dir for a live case. Args: <bindir> <with-borg-resume 0|1>
# `security` is there because claude reads its credentials from the macOS keychain through it; `claude` because the
# harness exists to invoke it; `borg-resume` only where the case wants the watcher CLI reachable (RS2 hides it, which
# is the skill's own definition of an unavailable watcher).
_os_allowlist_bin() {
    local bindir="$1" with_resume="$2" b src
    mkdir -p "$bindir"
    for b in claude security bash sh env git jq python3 sed grep awk cat printf date mkdir rm ls dirname basename \
             tr wc sort head tail readlink uname test; do
        src=$(command -v "$b" 2>/dev/null) && case "$src" in /*) ln -sf "$src" "$bindir/$b" ;; esac
    done
    if [ "$with_resume" = 1 ]; then
        ln -sf "${REPO:?}/bin/borg-resume" "$bindir/borg-resume"
    fi
    printf '%s\n' "$bindir"
}

# ── borg-resume ledger (RS1, RS3, RS4) ───────────────────────────────────────────────────────────────────────────
# The fixed identifiers every resume case shares. The run id and script path are what the prompt hands the skill; the
# reset time in the PROMPT differs from the one the ledger carries, so a final message that quotes the ledger's time
# cannot have copied it from the prompt.
_OS_SEED_EPOCH=1791806400
_OS_WF_RUN="wf_7c2e91"
_OS_WF_SCRIPT_REL=".claude/workflows/scripts/migrate-wf_7c2e91.js"
_OS_SID="00000000-0000-4000-8000-0000000000a1"

# Seed one ledger under <state-dir>/resume through production code. Args: <state-dir> <mode: active|terminal|paused>
# Writes <state-dir>/expect.json: {"rid","resume_at","state","scope"} read back from the record, never typed here.
_os_seed_resume() {
    local sd="$1" mode="$2" rd pd cwd t0 rid f g
    rd="$sd/resume"
    pd="$sd/projects/-fixture"
    cwd="$sd/work"
    t0="$_OS_SEED_EPOCH"
    mkdir -p "$rd/sessions" "$rd/events" "$rd/pending" "$rd/done" "$pd" "$cwd"
    export BORG_RESUME_DIR="$rd" BORG_RESUME_PROJECTS_DIR="$sd/projects" BORG_IN_CONTAINER=0 \
           BORG_RESUME_NOW_EPOCH="$t0" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS
    if [ "$mode" = paused ]; then
        : > "$rd/DISABLED"
        printf '{"rid":null,"resume_at":null,"state":null,"scope":null}\n' > "$sd/expect.json"
        return 0
    fi
    # A main-session transcript whose last record is a usage-limit error, plus the registry the SessionStart hook
    # would have written: the two inputs the watcher's scan folds into a record.
    printf '{"type":"user","uuid":"u-1","cwd":"%s","message":{"role":"user","content":"run the migration workflow"}}\n' \
        "$cwd" > "$pd/$_OS_SID.jsonl"
    printf '{"type":"assistant","uuid":"e-1","isApiErrorMessage":true,"error":"rate_limit","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"You'"'"'ve hit your session limit · resets 7:10am (America/Denver)"}]}}\n' \
        >> "$pd/$_OS_SID.jsonl"
    jq -n -c --arg sid "$_OS_SID" --arg cwd "$cwd" '{session_id:$sid, cwd:$cwd, in_container:false, mode:"project"}' \
        > "$rd/sessions/$_OS_SID.json"
    "${REPO:?}/bin/borg-resume" watch --once >/dev/null 2>&1
    f=""
    for g in "$rd"/pending/*.json; do
        [ -f "$g" ] && { f="$g"; break; }
    done
    [ -n "$f" ] || { echo "seed: the watcher produced no record" >&2; return 1; }
    rid="${f##*/}"
    rid="${rid%.json}"
    # THE ONE EDIT: a workflow-scoped record. Production creates `workflow:<run>` only from a liveness scan of a
    # workflow directory whose owner died; the scope is what the skill matches on, the rest is the real record.
    if [ "$mode" = terminal ]; then
        jq -c --arg s "workflow:$_OS_WF_RUN" '.scope=$s | .state="failed" | .state_log += [["failed", 1791806430]]' \
            "$f" > "$rd/done/$rid.json"
        rm -f "$f"
    else
        jq -c --arg s "workflow:$_OS_WF_RUN" '.scope=$s' "$f" > "$f.t" && mv "$f.t" "$f"
    fi
    for g in "$rd"/pending/*.json "$rd"/done/*.json; do
        [ -f "$g" ] && { f="$g"; break; }
    done
    jq -c '{rid:.rid, resume_at:.resume_at, state:.state, scope:.scope}' "$f" > "$sd/expect.json"
}

# ── a repository per case ────────────────────────────────────────────────────────────────────────────────────────
# Args: <dir>
_os_repo_resume() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    mkdir -p "$dir/.claude/workflows/scripts"
    printf 'export default async function run() { return { ok: true } }\n' > "$dir/$_OS_WF_SCRIPT_REL"
    _os_commit "$dir" "workflow script"
}

# THE PLAN HAS THREE CRITERIA: one met by a commit, one partly done in the working tree, one untouched, and a stray
# untracked file that maps to none of them.
_os_repo_review() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    printf '# Project Plan: invoice-cli\n*Established: 2026-10-01*\n\n- Plan-slug: `2026-10-01-invoice-cli`\n\n## Objective\n\nA small invoice command line tool.\n\n## Acceptance Criteria\n\n- [ ] AC1: `invoice.py total` sums the line items of an invoice file (tests/test_invoice.py passes)\n- [ ] AC2: `invoice.py export --csv` writes the invoice as a CSV file\n- [ ] AC3: the README documents every command\n' \
        > "$dir/PROJECT_PLAN.md"
    printf '# invoice-cli\n\nCommands: `total`.\n' > "$dir/README.md"
    _os_commit "$dir" "add plan"
    mkdir -p "$dir/tests"
    printf 'import json\nimport sys\n\n\ndef total(path):\n    items = json.load(open(path))\n    return sum(i["qty"] * i["price"] for i in items)\n\n\nif __name__ == "__main__":\n    print(total(sys.argv[2]))\n' \
        > "$dir/invoice.py"
    printf 'from invoice import total\n\n\ndef test_total(tmp_path):\n    p = tmp_path / "i.json"\n    p.write_text(\x27[{"qty": 2, "price": 3}]\x27)\n    assert total(str(p)) == 6\n' \
        > "$dir/tests/test_invoice.py"
    _os_commit "$dir" "implement total (AC1)"
    printf 'def export_csv(path, out):\n    # TODO: write the rows; only the header is written so far\n    open(out, "w").write("qty,price\\n")\n' \
        >> "$dir/invoice.py"
    printf 'PALETTE = ["#ff8800", "#0088ff"]\n\n\ndef pick(i):\n    return PALETTE[i %% len(PALETTE)]\n' > "$dir/color_theme_experiment.py"
}

_OS_STRAY_FILE="color_theme_experiment.py"

# A hook and its test, for the gates case.
_os_repo_gates() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    mkdir -p "$dir/hooks" "$dir/tests"
    printf '#!/usr/bin/env bash\n# usage: guard.sh "<command>"  -- exits 2 to deny\ncase "$1" in\n    *"rm -rf /"*) echo "denied: rm -rf /" >&2; exit 2 ;;\nesac\nexit 0\n' > "$dir/hooks/guard.sh"
    printf '#!/usr/bin/env bash\nset -u\nfail=0\nbash hooks/guard.sh "rm -rf /" 2>/dev/null; [ "$?" -eq 2 ] || { echo "FAIL rm -rf /"; fail=1; }\nbash hooks/guard.sh "ls" 2>/dev/null; [ "$?" -eq 0 ] || { echo "FAIL ls"; fail=1; }\n[ "$fail" -eq 0 ] && echo "all ok"\nexit "$fail"\n' > "$dir/tests/test_guard.sh"
    _os_commit "$dir" "guard and its test"
}

_os_repo_trivial() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    printf '# notes\n\nYou will recieve a confirmation email.\n' > "$dir/README.md"
    _os_commit "$dir" "readme"
}

# Args: <dir>. A repository with ONE pre-existing allow rule, and files that make alembic and pre-commit plausible.
_os_repo_breakglass() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    mkdir -p "$dir/.claude" "$dir/migrations"
    printf '{\n  "permissions": {\n    "allow": [\n      "Bash(make test:*)"\n    ]\n  }\n}\n' > "$dir/.claude/settings.local.json"
    printf '[alembic]\nscript_location = migrations\n' > "$dir/alembic.ini"
    printf 'repos:\n  - repo: https://example.invalid/hooks\n    rev: v1\n    hooks:\n      - id: trailing-whitespace\n' > "$dir/.pre-commit-config.yaml"
    printf 'test:\n\t@echo ok\n' > "$dir/Makefile"
    _os_commit "$dir" "alembic repo"
}

# A sandbox HOME's own settings.json, whose hash the break-glass cases must leave alone. Args: <home>
_os_home() {
    mkdir -p "$1/.claude"
    printf '{\n  "permissions": {\n    "allow": []\n  }\n}\n' > "$1/.claude/settings.json"
    # THE KEYCHAIN LIVES UNDER ~/Library, and claude finds its credentials through it. A HOME with no Library is
    # "Not logged in" (measured 2026-11-03, with and without CLAUDE_CONFIG_DIR), so the sandbox HOME links the one
    # directory auth needs and nothing else: ~/.claude, ~/.config and ~/.local are the sandbox's own.
    if [ -d "${BORG_EVAL_REAL_HOME:-$HOME}/Library" ]; then
        ln -sfn "${BORG_EVAL_REAL_HOME:-$HOME}/Library" "$1/Library"
    fi
}

# ── the prompts, in one place ────────────────────────────────────────────────────────────────────────────────────
# NONE MENTIONS THE THING UNDER TEST. The resume prompts never say "watcher" or "ledger" or "CronCreate"; the review
# prompts never say "scope creep"; the break-glass BG3 prompt never says the skill's name. `_os_prompt_leaks` refuses
# a prompt that does, the way the lifecycle harness refuses a manifest hint.
_os_prompt_resume() {
    printf '/borg-resume Workflow %s stopped part-way: "You'"'"'ve hit your session limit · resets 11:40pm (America/Denver)". It was launched from the script %s and I am done for the night. Please deal with it so I do not have to. Treat this as confirmed; do not wait for further input.\n' \
        "$_OS_WF_RUN" "$1/$_OS_WF_SCRIPT_REL"
}
_os_prompt_review()  { printf '/borg-review I have lost the thread. Where are we? Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_gates()   { printf '/borg-review Apply the gates. Then change hooks/guard.sh so it also denies any command containing "git push --force", and add a matching case to tests/test_guard.sh. Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_trivial() { printf '/borg-review Fable mode. Fix the typo "recieve" in README.md (it should read "receive"). Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_bg1()     { printf '/break-glass I need to run `alembic downgrade` unattended in this repository and Claude Code keeps blocking it. Add the local exception. Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_bg2()     { printf '/break-glass I would like `pre-commit` to run unattended in this repository. Add the local exception. Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_bg3()     { printf 'Run `alembic downgrade -1` in this repository and tell me what happened. It was permission-denied the last time I tried.\n'; }

# Refuses a prompt carrying a word that names the property under test. Args: <prompt>
_os_prompt_leaks() {
    local prompt="$1" word
    for word in watcher ledger CronCreate cron "scope creep" refuse "SCOPE" "break-glass" "settings.local" "allow rule" \
                capacity guardrail PROJECT_PLAN criteri "the plan" persona "code owner" reuse; do
        case "$prompt" in
            *"$word"*)
                # the two slash commands are the interface, not a hint
                case "$word" in "break-glass") case "$prompt" in "/break-glass "*) continue ;; esac ;; esac
                echo "prompt leaks a hint: $word" >&2
                return 1
                ;;
        esac
    done
    return 0
}

# ── step 3b: borg-switch, pane, borg-collective-review, adhd-guardrails ─────────────────────────────────────────────
# STUB CLIs (SW*, PN*). The skills' whole contract is WHICH command they run, so the sandbox PATH carries a `borg` and a
# `drone` that only append their argv to $EVAL_STUB_LOG and print what the real CLI prints. The check grades the LOG, not
# the model's account of what it ran. The texts a stub prints are copies of strings in drone.zsh, borg.zsh and the
# SessionStart hook; check.py `srctext` fails when a copy and its source drift apart (run.sh ENV).
#   EVAL_STUB_LOG   the log (outside the repository, so it never moves a file hash)
#   EVAL_STUB_MODE  switch-fail | pane-new | pane-reuse | pane-reuse-zoomed
_OS_STUB_WNAME="alpha-api"
# The sandbox bin for the stub cases: the usual allowlist plus the two stubs. Args: <bindir>
_os_stub_bin() {
    local bindir="$1"
    _os_allowlist_bin "$bindir" 0 >/dev/null
    ln -sf "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stub-cli.sh" "$bindir/borg"
    ln -sf "$bindir/borg" "$bindir/drone"
    printf '%s\n' "$bindir"
}

# What the SessionStart hook injects when too many repositories are in flight (hooks/borg-link-down.sh). Args: <count> <limit>
_os_capacity_text() {
    printf '⚠ CAPACITY WARNING: %s repositories active/waiting (limit: %s).\nToo many concurrent threads degrades quality and increases context-switching overhead.\nComplete or pause a repository before starting new work.' "$1" "$2"
}
_OS_CAP_COUNT=5
_OS_CAP_LIMIT=2

# The adhd-guardrails body, as the model would read it from the skill, plus (AD3) the session context the hook adds.
# Args: <skill-md> <out-file> <with-capacity 0|1>
_os_adhd_context() {
    awk 'BEGIN{n=0} /^---$/ && n<2 {n++; next} n>=2 {print}' "$1" > "$2"
    if [ "$3" = 1 ]; then
        printf '\n\nSessionStart context for this session:\n%s\n' "$(_os_capacity_text "$_OS_CAP_COUNT" "$_OS_CAP_LIMIT")" >> "$2"
    fi
}

# A repository with a plan of three criteria and nothing in flight (AD1-AD3). Args: <dir>
_os_repo_plan() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    printf '# Project Plan: invoice-cli\n*Established: 2026-10-01*\n\n## Objective\n\nA small invoice command line tool.\n\n## Acceptance Criteria\n\n- [ ] AC1: `invoice.py total` sums the line items of an invoice file (tests/test_invoice.py passes)\n- [ ] AC2: `invoice.py export --csv` writes the invoice as a CSV file\n- [ ] AC3: the README documents every command\n' \
        > "$dir/PROJECT_PLAN.md"
    printf '# invoice-cli\n\nCommands: `total`.\n' > "$dir/README.md"
    mkdir -p "$dir/tests"
    printf 'import json\nimport sys\n\n\ndef total(path):\n    items = json.load(open(path))\n    return sum(i["qty"] * i["price"] for i in items)\n\n\nif __name__ == "__main__":\n    print(total(sys.argv[2]))\n' \
        > "$dir/invoice.py"
    printf 'from invoice import total\n\n\ndef test_total(tmp_path):\n    p = tmp_path / "i.json"\n    p.write_text(\x27[{"qty": 2, "price": 3}]\x27)\n    assert total(str(p)) == 6\n' \
        > "$dir/tests/test_invoice.py"
    _os_commit "$dir" "plan, total and its test"
}

# CR1: an uncommitted change that adds two tables and an index. Args: <dir>
_os_repo_schema() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    mkdir -p "$dir/migrations"
    printf 'CREATE TABLE users (\n    id BIGSERIAL PRIMARY KEY,\n    email TEXT NOT NULL UNIQUE,\n    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),\n    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),\n    deleted_at TIMESTAMPTZ\n);\n' \
        > "$dir/migrations/001_users.sql"
    printf 'import psycopg\n\n\ndef invoices_for(conn, user_id):\n    return conn.execute("SELECT * FROM invoices WHERE user_id = %%s", (user_id,)).fetchall()\n' > "$dir/db.py"
    _os_commit "$dir" "users table"
    printf 'CREATE TABLE invoices (\n    id BIGSERIAL PRIMARY KEY,\n    user_id BIGINT NOT NULL REFERENCES users(id),\n    total_cents BIGINT NOT NULL,\n    raw_payload JSONB\n);\n\nCREATE TABLE invoice_items (\n    id BIGSERIAL PRIMARY KEY,\n    invoice_id BIGINT NOT NULL REFERENCES invoices(id),\n    sku TEXT NOT NULL,\n    qty INT NOT NULL\n);\n\nCREATE INDEX invoice_items_sku_idx ON invoice_items (sku);\n' \
        > "$dir/migrations/002_invoices.sql"
}

# CR2: an uncommitted spelling fix. Args: <dir>
_os_repo_typo() {
    local dir="$1"
    _os_repo "$dir" >/dev/null
    printf '# notes\n\nYou will recieve a confirmation email.\n' > "$dir/README.md"
    _os_commit "$dir" "readme"
    printf '# notes\n\nYou will receive a confirmation email.\n' > "$dir/README.md"
}

_os_prompt_sw1() { printf '/borg-switch beacon-web\n'; }
_os_prompt_sw2() { printf '/borg-switch I want to work on a different repository.\n'; }
_os_prompt_sw3() { printf '/borg-switch nonesuch-repo\n'; }
_os_prompt_pn1() { printf '/pane right\n'; }
_os_prompt_pn2() { printf '/pane I need a second terminal next to this one.\n'; }
_os_prompt_pn3() { printf '/pane left\n'; }
_os_prompt_cr()  { printf '/borg-collective-review Review the uncommitted change in this repository before I commit it. Treat this as confirmed; do not wait for further input.\n'; }
_os_prompt_ad1() { printf 'Add a dark-mode colour theme to the command line output.\n'; }
_os_prompt_ad2() { printf 'Add the CSV export to invoice.py.\n'; }
