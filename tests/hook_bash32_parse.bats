#!/usr/bin/env bats
# Regression guard: every hook must parse under the system bash (macOS /bin/bash is 3.2). A heredoc
# nested in $( ) with a backtick in it parsed fine on bash 5 and exited 2 on 3.2, which made a
# PreToolUse hook block every call instead of failing open.

@test "every hooks/*.sh parses under /bin/bash -n" {
    [ -x /bin/bash ] || skip "/bin/bash not present"
    local bad=""
    for f in "${BATS_TEST_DIRNAME}"/../hooks/*.sh; do
        /bin/bash -n "$f" 2>/dev/null || bad="$bad ${f##*/}"
    done
    [ -z "$bad" ] || { echo "bash -n failed:$bad"; false; }
}
