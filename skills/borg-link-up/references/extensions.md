# Local Extensions: 01-context, 02-output, 03-followup

Read only when any `EXTENSION_*` field in the prepared document is not `not present`. Moved verbatim from SKILL.md.

The prepared document carries the extension files, already read, per hook: `EXTENSION_<HOOK>_MACHINE` (`~/.config/borg/extensions/skill-extensions/borg-link-up/<hook>.md`) and `EXTENSION_<HOOK>_REPOSITORY` (`<repository root>/.borg/skill-extensions/borg-link-up/<hook>.md`), each `not present` or a path with its fenced body, then a `_PRECEDENCE` note. Later files extend or override earlier ones.

- **01-context** (`EXTENSION_01_CONTEXT`): apply before composing the checkpoint.
- **02-output** (`EXTENSION_02_OUTPUT`): fold its instructions into the checkpoint before the Write.
- **03-followup** (`EXTENSION_03_FOLLOWUP`): apply after the checkpoint file lands, before the closing reply. If a follow-up action fails, report the failure but do not delete or rewrite the checkpoint — it is the session's record and a failed follow-up does not invalidate it.

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:` asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins (the `PREFER_TOOL` lines already apply this). Everything else is repository policy and the repository layer wins. Full rules: `docs/extensions.md`. If a hook's layers are both `not present`, skip silently — do not mention extensions, do not warn, do not change behavior.
