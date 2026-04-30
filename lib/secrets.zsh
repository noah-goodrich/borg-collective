# lib/secrets.zsh — secrets.zsh patcher for `borg store-secret`
#
# Contract: the target file is expected to have an _keychain_export call block.
# First invocation adds anchor markers automatically:
#   '    # BEGIN _keychain_export block'
#   '    # END _keychain_export block'
# Subsequent calls use the markers for idempotent insertion.

# Idempotently patch a secrets.zsh file to wire a new keychain export.
# Adds anchor markers on first run, then inserts _keychain_export NAME and
# a registry comment row. Never duplicates entries.
_borg_patch_secrets_file() {
    local name="$1" secrets_file="$2"
    [[ -n "$name" && -n "$secrets_file" ]] || { echo "usage: _borg_patch_secrets_file NAME FILE" >&2; return 1; }
    [[ -f "$secrets_file" ]] || { echo "not found: $secrets_file" >&2; return 1; }

    local begin_marker="    # BEGIN _keychain_export block"
    local end_marker="    # END _keychain_export block"
    local tmpfile="${secrets_file}.borg_tmp.$$"

    # ── 1. Add anchor markers if absent ──────────────────────────────────────
    if ! grep -qxF "$begin_marker" "$secrets_file"; then
        local begin_done=0
        {
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Insert BEGIN before first standalone _keychain_export call
                if [[ $begin_done -eq 0 ]] && [[ "$line" =~ ^[[:space:]]+_keychain_export[[:space:]]+[A-Z_] ]]; then
                    printf '%s\n' "$begin_marker"
                    begin_done=1
                fi
                # Insert END before unfunction line
                if [[ "$line" =~ ^[[:space:]]+unfunction[[:space:]]+_keychain_export ]]; then
                    printf '%s\n' "$end_marker"
                fi
                printf '%s\n' "$line"
            done < "$secrets_file"
        } > "$tmpfile" && mv "$tmpfile" "$secrets_file"
    fi

    # ── 2. Verify END marker is present (unexpected format if missing) ────────
    if ! grep -qxF "$end_marker" "$secrets_file"; then
        echo "ERROR: _keychain_export block not found in $secrets_file" >&2
        echo "  Add the following markers manually around the _keychain_export calls:" >&2
        echo "    $begin_marker" >&2
        echo "    $end_marker" >&2
        return 1
    fi

    # ── 3. Add _keychain_export NAME if absent ────────────────────────────────
    if ! grep -qF "_keychain_export $name" "$secrets_file"; then
        {
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ "$line" = "$end_marker" ]]; then
                    printf '    _keychain_export %s\n' "$name"
                fi
                printf '%s\n' "$line"
            done < "$secrets_file"
        } > "$tmpfile" && mv "$tmpfile" "$secrets_file"
    fi

    # ── 4. Add registry comment row if absent ────────────────────────────────
    if ! grep -qF "#   $name " "$secrets_file"; then
        local padded_name
        padded_name="$(printf '%-20s' "$name")"
        local registry_row="#   ${padded_name} ${padded_name} (add description)"

        # Find the last registry table line (^#   [A-Z_]...)
        local last_row=0 i=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            i=$(( i + 1 ))
            [[ "$line" =~ ^#[[:space:]]{3}[A-Z_] ]] && last_row=$i
        done < "$secrets_file"

        if (( last_row > 0 )); then
            i=0
            {
                while IFS= read -r line || [[ -n "$line" ]]; do
                    i=$(( i + 1 ))
                    printf '%s\n' "$line"
                    if (( i == last_row )); then
                        printf '%s\n' "$registry_row"
                    fi
                done < "$secrets_file"
            } > "$tmpfile" && mv "$tmpfile" "$secrets_file"
        fi
    fi

    return 0
}
