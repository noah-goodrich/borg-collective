# lib/claude-md.zsh -- install borg's CLAUDE.md rules WITHOUT rewriting ~/.claude/CLAUDE.md in place.
#
# THE BUG THIS REPLACES: the old _borg_merge_claude_md wrote a tmp file and `mv`d it over the target.
# `mv` onto a symlink replaces the LINK, so dotfiles' symlink (~/.claude/CLAUDE.md -> dotfiles) became a
# regular file and dotfiles edits silently stopped reaching it.
#
# THE FIX: borg owns a file of its own, <claude_dir>/borg-managed.md, rewritten whole every run. The
# user's CLAUDE.md only needs one Claude Code `@` import line pointing at it. A symlinked CLAUDE.md is
# never touched (not replaced, not written through) -- we print the one line to add to its source.
# A regular-file CLAUDE.md is migrated: the legacy inline BEGIN/END block (and the legacy
# <!-- borg-extensions --> tail, also borg-written) is stripped and the import line ensured. Content
# outside those markers is preserved, and a no-op run writes nothing.

_BORG_CLAUDE_MD_IMPORT='@~/.claude/borg-managed.md'

# Usage: _borg_install_claude_md <borg_src> <claude_dir> [personal_seed] [ext_file]
_borg_install_claude_md() {
    local borg_src="$1" claude_dir="$2" personal_seed="${3:-}" ext_file="${4:-}"
    [[ -f "$borg_src" ]] || return 0

    local target="$claude_dir/CLAUDE.md" managed="$claude_dir/borg-managed.md"
    local begin='<!-- BEGIN borg-managed -->' end='<!-- END borg-managed -->'
    local ext_marker='<!-- borg-extensions -->'
    mkdir -p "$claude_dir"

    # borg-managed.md is borg's own regular file: replacing it atomically is correct.
    local body="$managed.new.$$"
    {
        cat "$borg_src"
        if [[ -n "$ext_file" && -f "$ext_file" ]]; then
            printf '\n%s\n' "$ext_marker"
            cat "$ext_file"
        fi
    } > "$body"
    if cmp -s "$body" "$managed" 2>/dev/null; then
        command rm -f "$body"
    else
        mv "$body" "$managed"
    fi

    if [[ -L "$target" ]]; then
        if [[ -f "$target" ]] && grep -qxF "$_BORG_CLAUDE_MD_IMPORT" "$target"; then
            return 0
        fi
        warn "$target is a symlink, left untouched. Add this line to its source file once: $_BORG_CLAUDE_MD_IMPORT"
        return 0
    fi

    if [[ ! -e "$target" && -n "$personal_seed" && -f "$personal_seed" ]]; then
        cp "$personal_seed" "$target"
    fi
    [[ -e "$target" ]] || : > "$target"

    # Strip the legacy inline block and extension tail, plus trailing blank lines (buffered, emitted
    # only when a non-blank follows) so the result is stable across runs.
    local stripped="$target.borg.$$"
    awk -v b="$begin" -v e="$end" -v x="$ext_marker" '
        $0 == x { exit }
        $0 == b { skip=1; next }
        $0 == e { skip=0; next }
        skip    { next }
        /^$/    { pending++; next }
                { for (i=0; i<pending; i++) print ""; pending=0; print }
    ' "$target" > "$stripped"
    if ! grep -qxF "$_BORG_CLAUDE_MD_IMPORT" "$stripped"; then
        [[ -s "$stripped" ]] && printf '\n' >> "$stripped"
        printf '%s\n' "$_BORG_CLAUDE_MD_IMPORT" >> "$stripped"
    fi
    if cmp -s "$stripped" "$target"; then
        command rm -f "$stripped"
    else
        mv "$stripped" "$target"
    fi
}
