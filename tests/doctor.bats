#!/usr/bin/env bats
# Tests for `borg doctor` — verifies the 4 launchd agents that install.sh bootstraps
# (notifyd, cortex-wake, usage-watch, reap): registered / last exit status / fresh output.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"
LABEL_LIB="${BATS_TEST_DIRNAME}/../lib/launchd-label.zsh"

# Labels are RESOLVED, never spelled out: the same lib/launchd-label.zsh that doctor and install.sh
# use. Resolved inside setup(), after setup_temp_dirs has redirected HOME/XDG_CONFIG_HOME, so a
# prefix file on the developer's real machine cannot leak in — and with LAUNCHD_LABEL_PREFIX
# unset, so a prefix in the developer's shell cannot either. The "prefixed" case below is the one
# test that sets a prefix on purpose.
_label() { zsh -c "source '$LABEL_LIB' && _borg_launchd_label '$1'"; }

_resolve_labels() {
    NOTIFYD_LABEL=$(_label notifyd)
    CORTEX_LABEL=$(_label cortex-wake)
    USAGE_LABEL=$(_label usage-watch)
    REAP_LABEL=$(_label reap)
}

setup() {
    setup_temp_dirs
    setup_mock_bin
    unset LAUNCHD_LABEL_PREFIX
    _resolve_labels
    # borg.zsh resets PATH from scratch at startup (native-install PATH-safety guard) and only
    # honors BORG_PATH_PREFIX for prepending — plain PATH exports from the test are discarded.
    export BORG_PATH_PREFIX="$MOCK_BIN"

    # SA1 hermeticity: every test gets a floor-passing gh mock so the new VERSION section never
    # reads the HOST gh — on any machine with gh < 2.97.0 the floor FAILs doctor (exit 1) and
    # breaks unrelated tests (agents-section tests 124/127/128 did exactly that on a 2.96.0 host,
    # green in CI only because the runner is newer). SA1 tests overwrite this mock per-case.
    cat > "$MOCK_BIN/gh" <<GHMOCK
#!/usr/bin/env bash
echo "gh version 2.97.0 (2026-01-01)"
GHMOCK
    chmod +x "$MOCK_BIN/gh"

    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    mkdir -p "$XDG_STATE_HOME/borg" "$XDG_DATA_HOME/borg"
    mkdir -p "$HOME/Library/LaunchAgents"

    USAGE_SAMPLES="$XDG_STATE_HOME/borg/usage-samples.jsonl"
    CORTEX_LOG="$XDG_DATA_HOME/borg/cortex-wake.stdout.log"
    REAP_LOG="$XDG_DATA_HOME/borg/reap.stdout.log"

    # Default: all four agents registered, exit 0, fresh output, notifyd has no StartInterval.
    _write_plist "$NOTIFYD_LABEL" ""
    _write_plist "$CORTEX_LABEL" "30"
    _write_plist "$USAGE_LABEL" "120"
    _write_plist "$REAP_LABEL" "3600"

    touch "$CORTEX_LOG" "$REAP_LOG"
    echo '{"ts":"now"}' > "$USAGE_SAMPLES"

    # Real `launchctl list` prints "-" in the PID column for an agent that is not currently
    # running, and a numeric PID only while it is. Interval-driven agents are almost always "-".
    # Fixtures with fake PIDs made every agent look permanently running, which silently disabled
    # the exit-status check these tests exist to exercise.
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
}

# Args: <label> <start-interval-or-empty>
_write_plist() {
    local label="$1" interval="$2"
    local plist="$HOME/Library/LaunchAgents/$label.plist"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<plist version="1.0"><dict>'
        echo "<key>Label</key><string>$label</string>"
        if [[ -n "$interval" ]]; then
            echo '<key>StartInterval</key>'
            echo "<integer>$interval</integer>"
        fi
        echo '</dict></plist>'
    } > "$plist"
}

# Writes a mock `launchctl` binary onto PATH that prints the given body for `launchctl list`.
_write_launchctl_list() {
    local body="$1"
    cat > "$MOCK_BIN/launchctl" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "list" ]]; then
    cat <<'BODY'
$body
BODY
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/launchctl"
}

# ─── all healthy ──────────────────────────────────────────────────────────────

@test "all agents registered, exit 0, fresh output -> doctor exits 0 with OK lines" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"OK"* ]] || false
    [[ "$output" == *"cortex-wake"*"OK"* ]] || false
    [[ "$output" == *"usage-watch"*"OK"* ]] || false
    [[ "$output" == *"reap"*"OK"* ]] || false
}

@test "doctor prints the state root from the resolver (XDG_STATE_HOME set)" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"State root: $XDG_STATE_HOME/borg"* ]] || false
}

@test "doctor derives the state root from HOME when XDG_STATE_HOME is unset" {
    unset XDG_STATE_HOME
    run "$BORG_CMD" doctor
    [[ "$output" == *"State root: $HOME/.local/state/borg"* ]] || false
}

@test "labels resolve unprefixed in the sandbox (no prefix file, no env)" {
    [ "$NOTIFYD_LABEL" = "borg.notifyd" ]
    [ "$REAP_LABEL" = "borg.reap" ]
}

# ─── doctor follows the prefix contract ───────────────────────────────────────
#
# The plists and the `launchctl list` fixture below are written under the PREFIXED labels; if
# doctor resolved labels any other way than through lib/launchd-label.zsh it would look for
# `borg.notifyd`, find nothing, and FAIL every row.

@test "a prefix file makes doctor look for <prefix>.borg.<agent> — same resolver as install.sh" {
    printf '  com.stillpoint-labs \n' > "$XDG_CONFIG_HOME/launchd-prefix"
    _resolve_labels
    [ "$NOTIFYD_LABEL" = "com.stillpoint-labs.borg.notifyd" ]
    _write_plist "$NOTIFYD_LABEL" ""
    _write_plist "$CORTEX_LABEL" "30"
    _write_plist "$USAGE_LABEL" "120"
    _write_plist "$REAP_LABEL" "3600"
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"OK"* ]] || false
    [[ "$output" == *"usage-watch"*"OK"* ]] || false
}

@test "LAUNCHD_LABEL_PREFIX in the environment reaches doctor and beats the file" {
    printf 'com.stillpoint-labs\n' > "$XDG_CONFIG_HOME/launchd-prefix"
    export LAUNCHD_LABEL_PREFIX="ai.example"
    _resolve_labels
    [ "$NOTIFYD_LABEL" = "ai.example.borg.notifyd" ]
    _write_plist "$USAGE_LABEL" "120"
    # Only the env-prefixed labels are registered; the file-prefixed ones are absent on purpose.
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage-watch"*"OK"* ]] || false
}

@test "a registered legacy-prefixed label does NOT count as the unprefixed agent" {
    # Sandbox resolves `borg.notifyd`; only the legacy name is registered. A substring match would
    # call that "yes" — it is a different agent, so this must be MISSING/FAIL.
    _write_launchctl_list "\
- 0 com.stillpoint-labs.borg.notifyd
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"notifyd"*"FAIL"* ]] || false
}

# ─── nonzero last exit status ─────────────────────────────────────────────────

@test "one agent with nonzero last exit -> doctor exits nonzero, that agent FAILs" {
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 1 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"cortex-wake"*"FAIL"* ]] || false
}

# ─── missing from launchctl list ──────────────────────────────────────────────

@test "one agent missing from launchctl list -> FAIL" {
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"cortex-wake"*"FAIL"* ]] || false
}

# ─── a running daemon is healthy, whatever the previous instance's exit was ────
#
# notifyd is a long-lived fswatch daemon. `launchctl kickstart -k` restarts it, and the second
# column then reports the SIGTERM we sent the old instance (-15). Reporting FAIL there is a false
# alarm about a corpse we created ourselves — and a health check that cries wolf gets ignored.

@test "a live PID means OK even when the previous instance was signalled" {
    _write_launchctl_list "\
74574 -15 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"run"*"OK"* ]] || false
}

@test "a signalled exit with no live PID is WARN, not FAIL" {
    _write_launchctl_list "\
- -15 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"WARN"* ]] || false
}

# ─── stale output artifact ─────────────────────────────────────────────────────
#
# usage-watch is the only agent contractually required to write on every interval, so it is the
# only one where an old mtime proves breakage. notifyd and cortex-wake are event-driven: a quiet
# hour is not a fault, which is why they carry no artifact.

@test "stale output artifact -> WARN (not silently OK)" {
    # 3x the 120s interval is 360s; back-date the samples file well past that.
    touch -t "202001010000" "$USAGE_SAMPLES"
    run "$BORG_CMD" doctor
    [[ "$output" == *"usage-watch"*"WARN"* ]] || false
}

# ─── no StartInterval -> freshness n/a, does not FAIL ─────────────────────────

@test "agent with no StartInterval -> freshness prints n/a, does not FAIL" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"n/a"*"OK"* ]] || false
}

# ─── container clock skew ──────────────────────────────────────────────────────
#
# `docker ps --filter label=dev.role=app` enumerates running drone containers (same filter
# `get_repository_container` in drone.zsh uses); `docker exec <c> date +%s` reads each one's clock.

# Args: <ps-output> <container-name> <container-epoch-or-empty-for-exec-failure>
_write_docker_mock() {
    local names="$1" container="$2" epoch="$3"
    cat > "$MOCK_BIN/docker" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "ps" ]]; then
    printf '%s\n' "$names"
    exit 0
fi
if [[ "\$1" == "exec" && "\$3" == "date" ]]; then
    if [[ "\$2" == "$container" ]]; then
        if [[ -n "$epoch" ]]; then
            echo "$epoch"
            exit 0
        else
            exit 1
        fi
    fi
    exit 1
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"
}

@test "no running drone containers -> no clock-skew table printed" {
    _write_docker_mock "" "" ""
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" != *"CONTAINER"* ]] || false
}

@test "container clock in sync -> OK, exits 0" {
    local now
    now=$(date +%s)
    _write_docker_mock "sample-app-1" "sample-app-1" "$now"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"sample-app-1"*"OK"* ]] || false
}

@test "container clock skewed > 120s -> WARN, not FAIL (exits 0)" {
    local skewed
    skewed=$(($(date +%s) + 300))
    _write_docker_mock "sample-app-1" "sample-app-1" "$skewed"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"sample-app-1"*"WARN"* ]] || false
}

@test "docker exec fails to read container clock -> FAIL" {
    _write_docker_mock "sample-app-1" "sample-app-1" ""
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"sample-app-1"*"FAIL"* ]] || false
}

# ─── headless `claude -p` reachability (2026-08-10 directive: dead narrative path) ─────────────
#
# `borg link --brief`'s LLM narrative was silently dead on the owner's machine with no health
# check to catch it. `borg doctor` now probes `claude -p` directly so this is a WARN a health
# check surfaces, not something noticed by reading thin briefing output.

@test "claude -p reachable -> claude-cli row is OK" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "ok"
exit 0
EOF
    chmod +x "$MOCK_BIN/claude"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-cli"*"OK"* ]] || false
}

@test "claude -p not logged in headless -> claude-cli row is WARN, not FAIL" {
    # EXITS 1, MEASURED against the real CLI 2026-09-15 (three runs of three). This mock said
    # `exit 0` because borg's code claimed auth failure was invisible in the exit status; it is not.
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 1
EOF
    chmod +x "$MOCK_BIN/claude"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-cli"*"WARN"* ]] || false
    # The hint no longer asserts a machine-level cause. It reports what this invocation observed and
    # names the rc; the "expected on some machines, not a bug to chase" clause is deliberately gone.
    [[ "$output" == *"reported an auth failure"* ]] || false
    [[ "$output" != *"not a bug to chase"* ]] || false
}

@test "claude -p exits nonzero -> claude-cli row is WARN with the exit code" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
exit 3
EOF
    chmod +x "$MOCK_BIN/claude"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-cli"*"3"*"WARN"* ]] || false
}

# ─── SA1: dependency version floors ────────────────────────────────────────────

@test "SA1: gh at or above the floor -> VERSION row OK, exit 0" {
    cat > "$MOCK_BIN/docker" <<'MOCK2'
#!/usr/bin/env bash
exit 0
MOCK2
    chmod +x "$MOCK_BIN/docker"
    cat > "$MOCK_BIN/claude" <<'MOCK2'
#!/usr/bin/env bash
echo ok
MOCK2
    chmod +x "$MOCK_BIN/claude"
    cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
echo "gh version 2.97.0 (2026-01-01)"
MOCK
    chmod +x "$MOCK_BIN/gh"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"gh"*"2.97.0"*"OK"* ]] || false
}

@test "SA1: gh below the floor -> VERSION row FAIL, exit 1, CVE named" {
    cat > "$MOCK_BIN/docker" <<'MOCK2'
#!/usr/bin/env bash
exit 0
MOCK2
    chmod +x "$MOCK_BIN/docker"
    cat > "$MOCK_BIN/claude" <<'MOCK2'
#!/usr/bin/env bash
echo ok
MOCK2
    chmod +x "$MOCK_BIN/claude"
    cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
echo "gh version 2.96.0 (2026-07-02)"
MOCK
    chmod +x "$MOCK_BIN/gh"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"gh"*"2.96.0"*"FAIL"* ]] || false
    [[ "$output" == *"CVE-2026-64652"* ]] || false
}

@test "SA1: gh absent -> VERSION row WARN, not FAIL" {
    cat > "$MOCK_BIN/docker" <<'MOCK2'
#!/usr/bin/env bash
exit 0
MOCK2
    chmod +x "$MOCK_BIN/docker"
    cat > "$MOCK_BIN/claude" <<'MOCK2'
#!/usr/bin/env bash
echo ok
MOCK2
    chmod +x "$MOCK_BIN/claude"
    rm -f "$MOCK_BIN/gh"
    cat > "$MOCK_BIN/gh" <<'MOCK'
#!/usr/bin/env bash
exit 127
MOCK
    chmod +x "$MOCK_BIN/gh"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"absent"*"WARN"* ]] || false
}

# ─── extension agents (drop-in templates) ──────────────────────────────────────
#
# install.sh renders $XDG_CONFIG_HOME/borg/extensions/launchd/<name>.plist.tmpl to <label>.plist with
# label <prefix>.<name> | local.<name>. doctor lists them with a REGISTRATION check only: no
# artifact, so no freshness — doctor knows nothing about what an extension writes.

_write_ext_template() {
    local dir="$XDG_CONFIG_HOME/borg/extensions/launchd"
    mkdir -p "$dir"
    printf '<plist><dict><key>Label</key><string>{{LABEL}}</string></dict></plist>\n' > "$dir/$1.plist.tmpl"
}

@test "extension agent registered -> its own row, OK, freshness n/a" {
    _write_ext_template dev-postgres
    local ext_label; ext_label=$(zsh -c "source '$LABEL_LIB' && _borg_launchd_ext_label dev-postgres")
    [ "$ext_label" = "local.dev-postgres" ]
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL
- 0 $ext_label"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"dev-postgres"*"yes"*"n/a"*"OK"* ]] || false
}

@test "extension agent NOT registered -> FAIL, and the prefix is honoured in the label doctor looks for" {
    printf 'com.stillpoint-labs\n' > "$XDG_CONFIG_HOME/launchd-prefix"
    _resolve_labels
    _write_plist "$NOTIFYD_LABEL" ""; _write_plist "$CORTEX_LABEL" "30"
    _write_plist "$USAGE_LABEL" "120";  _write_plist "$REAP_LABEL" "3600"
    _write_ext_template dev-postgres
    # Registered under the UNprefixed extension label only — with the prefix set that is the wrong one.
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL
- 0 local.dev-postgres"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"dev-postgres"*"FAIL"* ]] || false
}

@test "no extension directory -> doctor prints only the four built-in agents" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" != *"dev-postgres"* ]] || false
}

# ─── borg-resume rows (S13) ───────────────────────────────────────────────────
#
# A fully installed borg-resume in the sandbox HOME: bin, every lib/borg file, the hook entry, the
# watcher plist, the three D10 allowlist entries, a fresh watch.log and guardian state. Each case then
# breaks exactly one thing. launchctl is a stub; the probe uses the BORG_RESUME_USAGE_CMD seam, so the
# real claude is never called.

_resume_install() {
    RESUME_LABEL=$(_label resume-watch)
    RESUME_DIR="$XDG_STATE_HOME/borg/resume"
    mkdir -p "$HOME/.claude/bin" "$HOME/.claude/lib/borg" "$HOME/.claude/hooks" "$RESUME_DIR"
    cp "${BATS_TEST_DIRNAME}/../bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    cp "${BATS_TEST_DIRNAME}"/../lib/borg/*.sh "$HOME/.claude/lib/borg/"
    : > "$HOME/.claude/hooks/borg-resume-hook.sh"
    _write_plist "$RESUME_LABEL" "30"
    _write_settings "$HOME/.claude/settings.json"
    : > "$RESUME_DIR/watch.heartbeat"
    export BORG_RESUME_DOCTOR_TEST=1
    printf '{"last_swept_at":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$XDG_STATE_HOME/borg/usage-guardian.json"
    export BORG_RESUME_DIR="$RESUME_DIR"
    export BORG_RESUME_USAGE_CMD="echo 'Current session: 12% used'"
    _write_launchctl_resume running
}

_write_settings() {
    cat > "$1" <<JSON
{"permissions":{"allow":["Bash(~/.claude/bin/borg-resume:*)","Bash(borg-resume:*)",
"Read(~/.local/state/borg/resume/**)"]}}
JSON
}

# Args: running | idle | idle-failed | gone. `launchctl list` keeps answering for the base agents, and any
# mutating verb is logged to $BATS_TEST_TMPDIR/mutations so a test can prove doctor never issued one.
_write_launchctl_resume() {
    local mode="$1"
    cat > "$MOCK_BIN/launchctl" <<EOF
#!/usr/bin/env bash
case "\$1" in
    kickstart|bootstrap|bootout|load|unload|enable|disable) echo "\$1" >> "$BATS_TEST_TMPDIR/mutations" ;;
esac
if [[ "\$1" == "list" ]]; then
    printf -- '- 0 %s\n- 0 %s\n- 0 %s\n- 0 %s\n' '$NOTIFYD_LABEL' '$CORTEX_LABEL' '$USAGE_LABEL' '$REAP_LABEL'
    exit 0
fi
if [[ "\$1" == "print" ]]; then
    case '$mode' in
        running) printf '\tstate = running\n\tpid = 4242\n\tlast exit code = (never exited)\n'; exit 0 ;;
        idle) printf '\tstate = not running\n\tlast exit code = 0\n'; exit 0 ;;
        idle-failed) printf '\tstate = not running\n\tlast exit code = 1\n'; exit 0 ;;
        gone) echo 'Could not find service' >&2; exit 113 ;;
    esac
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/launchctl"
}

@test "resume: fully installed -> every resume row OK, doctor exits 0" {
    _resume_install
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-watch"*"OK"* ]] || false
    [[ "$output" == *"resume-log"*"OK"* ]] || false
    [[ "$output" == *"resume-probe"*"OK"* ]] || false
    [[ "$output" == *"resume-allow"*"OK"* ]] || false
    [[ "$output" == *"resume-lib"*"OK"* ]] || false
}

@test "resume: nothing installed -> one informational row, no failure" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-resume"*"not installed"* ]] || false
}

@test "resume: watcher loaded but idle between passes is OK" {
    _resume_install
    _write_launchctl_resume idle
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-watch"*"OK"* ]] || false
}

@test "resume: watcher not running with a failing last exit -> FAIL" {
    _resume_install
    _write_launchctl_resume idle-failed
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-watch"*"FAIL"* ]] || false
}

@test "resume: launchctl print exits non-zero (not found) -> FAIL" {
    _resume_install
    _write_launchctl_resume gone
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-watch"*"FAIL"* ]] || false
    [[ "$output" == *"not loaded"* ]] || false
}

@test "resume: stale watch.log -> FAIL" {
    _resume_install
    touch -t 202001010000 "$RESUME_DIR/watch.heartbeat"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-log"*"FAIL"* ]] || false
}

@test "resume: a real idle watch --once (empty ledger, no watch.log) keeps resume-log OK" {
    _resume_install
    rm "$RESUME_DIR/watch.heartbeat"
    run env HOME="$HOME" XDG_STATE_HOME="$XDG_STATE_HOME" BORG_RESUME_DIR="$RESUME_DIR" \
        BORG_RESUME_LIBDIR="$HOME/.claude/lib/borg" "$HOME/.claude/bin/borg-resume" watch --once
    [ "$status" -eq 0 ]
    [ ! -s "$RESUME_DIR/watch.log" ]
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-log"*"OK"* ]] || false
}

@test "resume: freshly installed, no pass yet -> WARN, not FAIL" {
    _resume_install
    rm "$RESUME_DIR/watch.heartbeat"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-log"*"WARN"* ]] || false
}

@test "resume: persisted install-time opt-out holds in a fresh shell without the env var" {
    _resume_install
    rm "$HOME/Library/LaunchAgents/$RESUME_LABEL.plist" "$RESUME_DIR/watch.heartbeat"
    echo '{"permissions":{"allow":[]}}' > "$HOME/.claude/settings.json"
    _write_launchctl_resume gone
    : > "$RESUME_DIR/WATCH_OPTOUT"
    unset BORG_RESUME_WATCH
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"opted out"* ]] || false
}

@test "resume: failing probe -> FAIL" {
    _resume_install
    export BORG_RESUME_USAGE_CMD="exit 3"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-probe"*"FAIL"* ]] || false
}

@test "resume: an unmetered (usage-billed) account -> INFO, not FAIL, and says why" {
    _resume_install
    export BORG_RESUME_USAGE_CMD="cat ${BATS_TEST_DIRNAME}/fixtures/usage-output-unmetered.txt"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-probe"*"INFO"* ]] || false
    [[ "$output" == *"usage-billed"* ]] || false
    [[ "$output" == *"no session limit"* ]] || false
    [[ "$output" != *"resume-probe"*"FAIL"* ]] || false
}

@test "resume: garbage /usage output is still a probe FAIL" {
    _resume_install
    export BORG_RESUME_USAGE_CMD="echo Total gibberish"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-probe"*"FAIL"* ]] || false
}

@test "resume: a cached good probe does not hide a failing probe" {
    _resume_install
    printf '{"at":%s,"session_pct":5}\n' "$(date +%s)" > "$RESUME_DIR/usage-probe.json"
    export BORG_RESUME_USAGE_CMD="exit 3"
    run "$BORG_CMD" doctor
    [[ "$output" == *"resume-probe"*"FAIL"* ]] || false
}

@test "resume: stale usage-guardian.json -> WARN, not FAIL" {
    _resume_install
    printf '{"last_swept_at":"2020-01-01T00:00:00Z"}\n' > "$XDG_STATE_HOME/borg/usage-guardian.json"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-guardian"*"WARN"* ]] || false
}

@test "resume: missing allowlist entries -> FAIL naming them" {
    _resume_install
    echo '{"permissions":{"allow":["Bash(borg-resume:*)"]}}' > "$HOME/.claude/settings.json"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-allow"*"FAIL"* ]] || false
    [[ "$output" == *"Read(~/.local/state/borg/resume/**)"* ]] || false
}

@test "resume: allowlist is read through a symlinked settings.json" {
    _resume_install
    mkdir -p "$HOME/dotfiles"
    mv "$HOME/.claude/settings.json" "$HOME/dotfiles/settings.json"
    ln -s "$HOME/dotfiles/settings.json" "$HOME/.claude/settings.json"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-allow"*"OK"* ]] || false
}

@test "resume: absolute-HOME allowlist spelling (as the installer renders it) is accepted" {
    _resume_install
    sed -i.bak "s|Bash(~/.claude|Bash($HOME/.claude|" "$HOME/.claude/settings.json"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-allow"*"OK"* ]] || false
}

@test "resume: HEADLINE hook installed but lib missing -> FAIL with the fix command" {
    _resume_install
    mv "$HOME/.claude/lib/borg" "$BATS_TEST_TMPDIR/gone-lib"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"hook is installed but its lib is missing"* ]] || false
    [[ "$output" == *"borg setup"* ]] || false
}

@test "resume: partial lib -> FAIL naming the missing files" {
    _resume_install
    rm "$HOME/.claude/lib/borg/resume-shared.sh" "$HOME/.claude/lib/borg/resume-relaunch.sh" \
        "$HOME/.claude/lib/borg/resume-cli.sh"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"resume-lib"*"FAIL"* ]] || false
    [[ "$output" == *"resume-shared.sh"* ]] || false
    [[ "$output" == *"resume-relaunch.sh"* ]] || false
    [[ "$output" == *"resume-cli.sh"* ]] || false
}

@test "resume: BORG_RESUME_WATCH=0 reports a missing watcher and allowlist as disabled, not FAIL" {
    _resume_install
    rm "$HOME/Library/LaunchAgents/$RESUME_LABEL.plist"
    echo '{"permissions":{"allow":[]}}' > "$HOME/.claude/settings.json"
    _write_launchctl_resume gone
    BORG_RESUME_WATCH=0 run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"opted out"* ]] || false
}

@test "resume: kill switch state is informational" {
    _resume_install
    : > "$RESUME_DIR/DISABLED"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-switch"*"paused"* ]] || false
    rm "$RESUME_DIR/DISABLED"
    BORG_RESUME_DISABLE=1 run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"resume-switch"*"BORG_RESUME_DISABLE=1"* ]] || false
}

@test "resume: doctor stays read-only (no launchctl mutation, no file changes)" {
    _resume_install
    find "$HOME" "$XDG_STATE_HOME" -type f | sort | xargs ls -l > "$BATS_TEST_TMPDIR/before.txt"
    run "$BORG_CMD" doctor
    find "$HOME" "$XDG_STATE_HOME" -type f | sort | xargs ls -l > "$BATS_TEST_TMPDIR/after.txt"
    diff "$BATS_TEST_TMPDIR/before.txt" "$BATS_TEST_TMPDIR/after.txt"
    [ ! -e "$BATS_TEST_TMPDIR/mutations" ]
}

# ─── registry entry-map key (contract step of the projects -> repositories rename) ─────────────

@test "registry key: doctor FAILs on a projects-only registry and points at borg setup and migrate-key" {
    printf '%s\n' '{"projects":{"alpha":{"path":"/nowhere"}}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"registry-key"*"projects"*"FAIL"* ]] || false
    [[ "$output" == *"borg setup"* ]] || false
    [[ "$output" == *"migrate-key"* ]] || false
}

@test "registry key: doctor is OK on a repositories registry" {
    printf '%s\n' '{"repositories":{"alpha":{"path":"/nowhere"}}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"registry-key"*"repositories"*"OK"* ]] || false
}
