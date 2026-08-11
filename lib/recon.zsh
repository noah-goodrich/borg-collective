#!/usr/bin/env zsh
# lib/recon.zsh — zsh entrypoint for the recon fan-out engine.
#
# The engine itself is portable sh in lib/recon.sh (sourceable by both bash tests and the zsh CLI,
# same split as reaper.sh ↔ registry.zsh). This shim exists only so borg.zsh's `lib/*.zsh` source
# glob picks the engine up. Keep all logic in recon.sh — this file must stay a pure passthrough.
#
# The one exception: this shim must hand the engine its own directory. zsh has no BASH_SOURCE, and
# `$0` inside a sourced file has no directory component, so recon.sh cannot work out where it lives
# on its own — it would resolve "." and lose the shipped adapters. Only zsh knows this idiom, so
# resolving it here is what keeps recon.sh portable.
BORG_RECON_LIB_DIR="${${(%):-%x}:A:h}"
source "$BORG_RECON_LIB_DIR/recon.sh"
