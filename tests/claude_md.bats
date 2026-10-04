#!/usr/bin/env bats
# borg setup must never replace a symlinked ~/.claude/CLAUDE.md (dotfiles' install.sh links it).
# The old tmp+mv merge turned the link into a regular file. Now borg writes ~/.claude/borg-managed.md
# and CLAUDE.md only carries one `@~/.claude/borg-managed.md` import line (lib/claude-md.zsh).
# Sandboxed: HOME + all XDG dirs are redirected by setup_temp_dirs; nothing touches the real home.

load test_helper/setup

IMPORT='@~/.claude/borg-managed.md'

setup() {
    setup_temp_dirs
    CD="$HOME/.claude"
    mkdir -p "$CD" "$XDG_CONFIG_HOME/dotfiles/claude/code"
    SRC="$BATS_TEST_TMPDIR/borg-claude.md"
    printf '%s\n' "# borg rules v1" "- rule one" > "$SRC"
    DOT="$XDG_CONFIG_HOME/dotfiles/claude/code/CLAUDE.md"
    printf '%s\n' "# Noah" "- personal line" > "$DOT"
}

# install_md [seed] [ext_file] -- run the installer in zsh with a stub warn()
install_md() {
    zsh -c 'warn() { echo "WARN: $*"; }; source "$1/lib/claude-md.zsh"; shift; _borg_install_claude_md "$@"' \
        _ "$BORG_HOME" "$SRC" "$CD" "$@"
}

@test "symlinked CLAUDE.md stays a symlink, target untouched, one-line instruction printed" {
    ln -s "$DOT" "$CD/CLAUDE.md"
    before="$(cat "$DOT")"
    run install_md "$DOT"
    [ "$status" -eq 0 ]
    [ -L "$CD/CLAUDE.md" ]
    [ "$(readlink "$CD/CLAUDE.md")" = "$DOT" ]
    [ "$(cat "$DOT")" = "$before" ]
    [[ "$output" == *"WARN:"*"$IMPORT"* ]]
    [ "${#lines[@]}" -eq 1 ]
}

@test "symlinked CLAUDE.md that already imports borg-managed.md is silent" {
    printf '%s\n' "# Noah" "$IMPORT" > "$DOT"
    ln -s "$DOT" "$CD/CLAUDE.md"
    run install_md "$DOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -L "$CD/CLAUDE.md" ]
    [ "$(cat "$DOT")" = "$(printf '# Noah\n%s' "$IMPORT")" ]
}

@test "borg-managed.md is written and stays current across runs" {
    ln -s "$DOT" "$CD/CLAUDE.md"
    install_md "$DOT" >/dev/null
    cmp "$SRC" "$CD/borg-managed.md"
    printf '%s\n' "# borg rules v2" > "$SRC"
    install_md "$DOT" >/dev/null
    cmp "$SRC" "$CD/borg-managed.md"
}

@test "extension CLAUDE.md is folded into borg-managed.md, not into CLAUDE.md" {
    ln -s "$DOT" "$CD/CLAUDE.md"
    printf '%s\n' "- ext rule" > "$BATS_TEST_TMPDIR/ext.md"
    before="$(cat "$DOT")"
    run install_md "" "$BATS_TEST_TMPDIR/ext.md"
    [ "$status" -eq 0 ]
    grep -qxF -- "- ext rule" "$CD/borg-managed.md"
    grep -qxF -- "- rule one" "$CD/borg-managed.md"
    [ "$(cat "$DOT")" = "$before" ]
}

@test "regular CLAUDE.md with an inline block migrates to the import form, user content kept" {
    {
        printf '%s\n' "# Top" "- above"
        printf '\n%s\n' "<!-- BEGIN borg-managed -->" "# stale rules" "<!-- END borg-managed -->"
    } > "$CD/CLAUDE.md"
    run install_md ""
    [ "$status" -eq 0 ]
    [ ! -L "$CD/CLAUDE.md" ]
    ! grep -q "BEGIN borg-managed" "$CD/CLAUDE.md"
    ! grep -q "stale rules" "$CD/CLAUDE.md"
    grep -qxF -- "- above" "$CD/CLAUDE.md"
    [ "$(grep -cxF "$IMPORT" "$CD/CLAUDE.md")" -eq 1 ]
    cmp "$SRC" "$CD/borg-managed.md"
}

@test "user content below the legacy block survives migration" {
    {
        printf '%s\n' "<!-- BEGIN borg-managed -->" "old" "<!-- END borg-managed -->"
        printf '%s\n' "" "# user tail" "- keep me"
    } > "$CD/CLAUDE.md"
    install_md "" >/dev/null
    grep -qxF -- "- keep me" "$CD/CLAUDE.md"
    grep -qxF -- "# user tail" "$CD/CLAUDE.md"
}

@test "migration is idempotent: second run rewrites nothing" {
    {
        printf '%s\n' "# Top" "- above"
        printf '\n%s\n' "<!-- BEGIN borg-managed -->" "old" "<!-- END borg-managed -->"
    } > "$CD/CLAUDE.md"
    install_md "" >/dev/null
    cp "$CD/CLAUDE.md" "$BATS_TEST_TMPDIR/after1"
    cp "$CD/borg-managed.md" "$BATS_TEST_TMPDIR/managed1"
    touch -t 200001010000 "$CD/CLAUDE.md" "$CD/borg-managed.md"
    install_md "" >/dev/null
    cmp "$CD/CLAUDE.md" "$BATS_TEST_TMPDIR/after1"
    cmp "$CD/borg-managed.md" "$BATS_TEST_TMPDIR/managed1"
    [ "$(find "$CD" -name CLAUDE.md -newermt 2001-01-01 | wc -l)" -eq 0 ]
    [ "$(find "$CD" -name borg-managed.md -newermt 2001-01-01 | wc -l)" -eq 0 ]
}

@test "missing CLAUDE.md is seeded from dotfiles then gets the import line" {
    run install_md "$DOT"
    [ "$status" -eq 0 ]
    [ ! -L "$CD/CLAUDE.md" ]
    grep -qxF -- "- personal line" "$CD/CLAUDE.md"
    [ "$(grep -cxF "$IMPORT" "$CD/CLAUDE.md")" -eq 1 ]
}
