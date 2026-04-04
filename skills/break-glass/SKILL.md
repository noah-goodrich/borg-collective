---
name: break-glass
description: >
  Add a local permission exception to a project's settings.local.json. Use when a project needs
  to run a command that is too dangerous or project-specific for the global allowlist. This is
  the formal escape hatch — global permission fixes are normal borg-collective work.
user-invocable: true
---

# Break Glass — Local Permission Exception

You are adding a local permission exception. This is a controlled escape hatch, not a shortcut.

## Policy

- **Global settings are the default.** All broadly useful commands belong in
  `~/.claude/settings.json`, managed by borg-collective. Adding to global is normal work,
  not an exception.
- **Local exceptions are rare.** A project's `settings.local.json` should almost always have
  an empty allow list. Exceptions are for commands that are genuinely project-specific AND
  too dangerous to allow globally.
- **The break-glass skill exists so exceptions are documented, not hidden.**

## Before You Proceed

Ask yourself:
1. **Is this command project-specific?** If it's useful across projects, add it to global
   instead (that's just regular borg-collective work — no skill needed).
2. **Is this command dangerous enough to warrant isolation?** If it's safe to allow globally
   (like `make` or `pre-commit`), add it to global instead.
3. **Can I use `run-in` or `bash -c` instead?** Many permission prompts are caused by
   compound commands, not missing rules. Check the Bash Permission Patterns section in
   CLAUDE.md before adding new rules.

## If You Still Need a Local Exception

1. **Explain to the user** what command needs the exception and why global isn't appropriate.
2. **Use the broadest reasonable pattern.** Prefer `Bash(dangerous-tool:*)` over
   `Bash(dangerous-tool --specific-flag --exact-args)`. Exact commands accumulate fast.
3. **Add at most 1-3 rules.** If you need more, something is wrong — reassess whether these
   belong in global.
4. **Write the rule** to the project's `.claude/settings.local.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "Bash(the-pattern:*)"
       ]
     }
   }
   ```
5. **Tell the user** what you added and why. The user should know every local exception exists.

## Examples of Legitimate Local Exceptions

- A database migration tool that drops and recreates schemas (`Bash(alembic downgrade:*)`)
- A project-specific deploy script that pushes to production
- A credential rotation tool that writes secrets

## Examples of Things That Are NOT Local Exceptions

- `Bash(pre-commit:*)` — useful everywhere, add to global
- `Bash(docker exec:*)` — useful everywhere, add to global
- `Bash(cd /path && git status)` — use `run-in` or `git -C` instead
- `Bash(ls -la | grep foo)` — use `bash -c 'ls -la | grep foo'` instead
