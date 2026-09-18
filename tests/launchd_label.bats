#!/usr/bin/env bats
# Tests for lib/launchd-label.zsh — the ONE resolver for launchd agent labels — and for the
# contract that ties it to install.sh and the repo plists:
#
#   prefix = $LAUNCHD_LABEL_PREFIX (set, non-blank) > first non-blank line of
#            ${XDG_CONFIG_HOME:-$HOME/.config}/launchd-prefix > none;  whitespace trimmed
#   label  = <prefix>.borg.<agent> | borg.<agent>
#
# Every case runs against a temp HOME/XDG_CONFIG_HOME and an UNSET LAUNCHD_LABEL_PREFIX, so a
# prefix on the developer's real machine can neither make these pass nor fail.

load test_helper/setup

LIB="${BATS_TEST_DIRNAME}/../lib/launchd-label.zsh"
INSTALL_SH="${BATS_TEST_DIRNAME}/../install.sh"
LAUNCHD_DIR="${BATS_TEST_DIRNAME}/../launchd"
AGENTS="notifyd cortex-wake usage-watch reap pr-watch memory-gate"

setup() {
    setup_temp_dirs
    unset LAUNCHD_LABEL_PREFIX
    PREFIX_FILE="$XDG_CONFIG_HOME/launchd-prefix"
}

# Resolve through zsh — the shell borg.zsh and install.sh source the lib with.
_label() { zsh -c "source '$LIB' && _borg_launchd_label \"\$@\"" -- "$@"; }

# ─── resolution ───────────────────────────────────────────────────────────────

@test "resolver: no prefix file and no env -> borg.<agent>" {
    [ ! -e "$PREFIX_FILE" ]
    run _label notifyd
    [ "$status" -eq 0 ]
    [ "$output" = "borg.notifyd" ]
}

@test "resolver: prefix file present -> <prefix>.borg.<agent>" {
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    run _label notifyd
    [ "$status" -eq 0 ]
    [ "$output" = "com.stillpoint-labs.borg.notifyd" ]
}

@test "resolver: with the legacy brand in the file, every label is byte-identical to the old hardcoded one" {
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    local a
    for a in $AGENTS; do
        [ "$(_label "$a")" = "com.stillpoint-labs.borg.$a" ]
    done
}

@test "resolver: env var LAUNCHD_LABEL_PREFIX beats the file" {
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    export LAUNCHD_LABEL_PREFIX="ai.example"
    run _label reap
    [ "$output" = "ai.example.borg.reap" ]
}

@test "resolver: an EMPTY env var does not override the file" {
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    export LAUNCHD_LABEL_PREFIX=""
    run _label reap
    [ "$output" = "com.stillpoint-labs.borg.reap" ]
}

@test "resolver: whitespace around the file's value is trimmed (spaces, tabs, CR, blank lines)" {
    printf '\n\t  com.stillpoint-labs \t\r\n' > "$PREFIX_FILE"
    run _label usage-watch
    [ "$output" = "com.stillpoint-labs.borg.usage-watch" ]
}

@test "resolver: whitespace around the env var is trimmed" {
    export LAUNCHD_LABEL_PREFIX="  ai.example  "
    run _label usage-watch
    [ "$output" = "ai.example.borg.usage-watch" ]
}

@test "resolver: a blank prefix file is the same as no file" {
    printf '   \n\n' > "$PREFIX_FILE"
    run _label cortex-wake
    [ "$output" = "borg.cortex-wake" ]
}

@test "resolver: honours XDG_CONFIG_HOME over ~/.config" {
    # The harness sets XDG_CONFIG_HOME to a dir OTHER than $HOME/.config; a file under the latter
    # must not be read.
    mkdir -p "$HOME/.config"
    printf 'wrong.place\n' > "$HOME/.config/launchd-prefix"
    run _label notifyd
    [ "$output" = "borg.notifyd" ]
}

@test "resolver: falls back to ~/.config when XDG_CONFIG_HOME is unset" {
    mkdir -p "$HOME/.config"
    printf 'ai.example\n' > "$HOME/.config/launchd-prefix"
    run env -u XDG_CONFIG_HOME zsh -c "source '$LIB' && _borg_launchd_label notifyd"
    [ "$output" = "ai.example.borg.notifyd" ]
}

@test "resolver: no agent name -> exit 1, nothing on stdout" {
    run _label
    [ "$status" -eq 1 ]
    [[ "$output" == *"agent name required"* ]]
}

@test "resolver: the lib is bash-compatible (sources and resolves under bash too)" {
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    run bash -c "source '$LIB' && _borg_launchd_label memory-gate"
    [ "$status" -eq 0 ]
    [ "$output" = "com.stillpoint-labs.borg.memory-gate" ]
}

# ─── one resolver, everywhere ─────────────────────────────────────────────────

@test "contract: no launchd label is spelled out literally in borg.zsh, bin/, or launchd/" {
    # install.sh is allowed exactly one literal: the legacy label inside the one-time migration.
    ! grep -rn 'stillpoint-labs\.borg' "${BATS_TEST_DIRNAME}/../bin" "$LAUNCHD_DIR"
    # borg.zsh: CODE lines only (comments may name a label to explain why it is not matched).
    ! { grep -vE '^[[:space:]]*#' "${BATS_TEST_DIRNAME}/../borg.zsh" \
        | grep -qE 'stillpoint-labs\.borg|"borg\.(notifyd|cortex-wake|usage-watch|reap|pr-watch|memory-gate)'; }
}

@test "contract: install.sh sources the resolver and resolves every agent through it" {
    grep -q 'source "\$BORG_HOME/lib/launchd-label.zsh"' "$INSTALL_SH"
    local a
    for a in $AGENTS; do
        grep -q "_borg_launchd_label $a)" "$INSTALL_SH" || { echo "install.sh does not resolve $a"; false; }
    done
    # And the installed filename is <label>.plist, never a hardcoded name.
    ! grep -qE 'LaunchAgents/com\.' "$INSTALL_SH"
}

@test "contract: install.sh retires the legacy com.stillpoint-labs label once per agent" {
    grep -q '_launchd_retire_legacy()' "$INSTALL_SH"
    grep -q 'local legacy="com.stillpoint-labs.borg.\$agent"' "$INSTALL_SH"
    grep -q 'launchctl bootout "gui/\$UID/\$legacy"' "$INSTALL_SH"
    local a
    for a in $AGENTS; do
        grep -qE "_launchd_retire_legacy $a " "$INSTALL_SH" || { echo "no legacy migration for $a"; false; }
    done
}

# ─── plist templates ──────────────────────────────────────────────────────────

@test "plists: one neutral borg.<agent>.plist per agent, and no branded files remain" {
    local a
    for a in $AGENTS; do
        [ -f "$LAUNCHD_DIR/borg.$a.plist" ] || { echo "missing launchd/borg.$a.plist"; false; }
    done
    [ "$(ls "$LAUNCHD_DIR" | wc -l | tr -d ' ')" -eq 6 ]
    ! ls "$LAUNCHD_DIR" | grep -q 'stillpoint'
}

@test "plists: Label is the {{LABEL}} placeholder and install.sh templates it for every plist" {
    local a
    for a in $AGENTS; do
        grep -A1 '<key>Label</key>' "$LAUNCHD_DIR/borg.$a.plist" | grep -q '<string>{{LABEL}}</string>' \
            || { echo "borg.$a.plist Label is not {{LABEL}}"; false; }
    done
    # Six sed blocks, six {{LABEL}} substitutions.
    [ "$(grep -c 's|{{LABEL}}|' "$INSTALL_SH")" -eq 6 ]
}

@test "plists: templating a plist with a resolved label yields a valid plist with that Label and no placeholders left" {
    # Runs only the sed pipeline (never install.sh) against a temp dir — the same substitutions
    # the installer makes, with a stand-in for every non-label placeholder.
    printf 'com.stillpoint-labs\n' > "$PREFIX_FILE"
    local out="$BATS_TEST_TMPDIR/LaunchAgents"
    mkdir -p "$out"
    local a label dest
    for a in $AGENTS; do
        label=$(_label "$a")
        dest="$out/$label.plist"
        sed \
            -e "s|{{LABEL}}|$label|g" \
            -e "s|{{NOTIFYD_BIN}}|/x/bin/borg-notifyd|g" \
            -e "s|{{CORTEX_WATCH_BIN}}|/x/bin/borg-cortex-watch|g" \
            -e "s|{{USAGE_WATCH_BIN}}|/x/bin/borg-usage-watch|g" \
            -e "s|{{MEMORY_GATE_BIN}}|/x/bin/borg-memory-gate|g" \
            -e "s|{{BORG_BIN}}|/x/bin/borg|g" \
            -e "s|{{BORG_ROOT}}|/x/borg-collective|g" \
            -e "s|{{LOG_DIR}}|/x/share/borg|g" \
            -e "s|{{USER}}|tester|g" \
            -e "s|{{HOME}}|/x/home|g" \
            -e "s|{{PATH_VALUE}}|/usr/bin:/bin|g" \
            "$LAUNCHD_DIR/borg.$a.plist" > "$dest"
        [ "$label" = "com.stillpoint-labs.borg.$a" ]
        grep -A1 '<key>Label</key>' "$dest" | grep -q "<string>$label</string>"
        ! grep -q '{{' "$dest" || { echo "placeholder left in $dest"; false; }
        if command -v plutil >/dev/null 2>&1; then
            plutil -lint "$dest" >/dev/null
        fi
    done
}

# ─── legacy migration (install.sh, exercised without running install.sh) ──────
#
# The function is extracted from install.sh by line range and sourced into a zsh with a mocked
# `launchctl`, so the real installer never runs and the real launchd is never touched.

_run_retire() {
    # $1 = agent, $2 = new label, $3 = body for `launchctl list` (labels that are "loaded")
    local agent="$1" new_label="$2" loaded="$3"
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN" "$HOME/Library/LaunchAgents"
    cat > "$MOCK_BIN/launchctl" <<MOCK
#!/usr/bin/env bash
echo "launchctl \$*" >> "${BATS_TEST_TMPDIR}/launchctl.log"
if [[ "\$1" == "list" ]]; then
    printf '%s\n' "$loaded" | grep -qx -- "\$2"
    exit \$?
fi
exit 0
MOCK
    chmod +x "$MOCK_BIN/launchctl"
    local fn
    fn=$(sed -n '/^_launchd_retire_legacy() {/,/^}/p' "$INSTALL_SH")
    [ -n "$fn" ]
    PATH="$MOCK_BIN:$PATH" zsh -c "
        info() { echo \"\$*\"; }
        LA_DIR=\"\$HOME/Library/LaunchAgents\"
        $fn
        _launchd_retire_legacy '$agent' '$new_label'
        echo \"LEGACY_BOOTED_OUT=\$LEGACY_BOOTED_OUT\"
    "
}

@test "migration: legacy label == new label (prefix file says com.stillpoint-labs) -> no-op" {
    mkdir -p "$HOME/Library/LaunchAgents"
    touch "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.notifyd.plist"
    run _run_retire notifyd com.stillpoint-labs.borg.notifyd "com.stillpoint-labs.borg.notifyd"
    [ "$status" -eq 0 ]
    [[ "$output" == *"LEGACY_BOOTED_OUT=0"* ]]
    [ -f "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.notifyd.plist" ]
    ! grep -q 'bootout' "${BATS_TEST_TMPDIR}/launchctl.log"
}

@test "migration: legacy notifyd loaded and label changed -> booted out, plist deleted, flag set" {
    mkdir -p "$HOME/Library/LaunchAgents"
    touch "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.notifyd.plist"
    run _run_retire notifyd borg.notifyd "com.stillpoint-labs.borg.notifyd"
    [ "$status" -eq 0 ]
    grep -q "launchctl bootout gui/$UID/com.stillpoint-labs.borg.notifyd" "${BATS_TEST_TMPDIR}/launchctl.log"
    [ ! -e "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.notifyd.plist" ]
    [[ "$output" == *"LEGACY_BOOTED_OUT=1"* ]]
}

@test "migration: legacy plist on disk but not loaded -> file removed, no bootout, flag stays 0" {
    mkdir -p "$HOME/Library/LaunchAgents"
    touch "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.reap.plist"
    run _run_retire reap ai.example.borg.reap ""
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/Library/LaunchAgents/com.stillpoint-labs.borg.reap.plist" ]
    ! grep -q 'bootout' "${BATS_TEST_TMPDIR}/launchctl.log"
    [[ "$output" == *"LEGACY_BOOTED_OUT=0"* ]]
}
