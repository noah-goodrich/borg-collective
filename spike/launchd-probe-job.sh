#!/bin/sh
# S0c throwaway launchd job body (reproduces spike/launchd-probe-evidence.txt).
# Run it from a TEMPORARY user-domain launchd job (unique label, no RunAtLoad), started with
# `launchctl kickstart`, then `launchctl bootout` the job and delete the plist.
# Usage: launchd-probe-job.sh <repo-root>
# It strips USER so the job exercises the failure mode the probe self-heals, and reports the environment first.
ROOT="$1"
printf 'PATH=%s\n' "$PATH"
printf 'TMUX=%s\n' "${TMUX:-unset}"
unset USER
printf 'USER=%s\n' "${USER:-unset}"
BORG_RESUME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/borg-probe-job.XXXXXX")"
export BORG_RESUME_DIR BORG_RESUME_PROBE_VERBOSE=1
pct="$("$ROOT/bin/borg-resume" probe)"
rc=$?
printf 'session_pct=%s\n' "$pct"
printf 'probe_exit=%s\n' "$rc"
rm -rf "$BORG_RESUME_DIR"
