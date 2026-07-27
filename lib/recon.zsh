#!/usr/bin/env zsh
# lib/recon.zsh — zsh entrypoint for the recon fan-out engine.
#
# The engine itself is portable sh in lib/recon.sh (sourceable by both bash tests and the zsh CLI,
# same split as reaper.sh ↔ registry.zsh). This shim exists only so borg.zsh's `lib/*.zsh` source
# glob picks the engine up. Keep all logic in recon.sh — this file must stay a pure passthrough.
source "${${(%):-%x}:A:h}/recon.sh"
