# Devcontainer Dotfiles Mount Gap
*Created: 2026-04-05*
*Shipped: 2026-04-12 — all active projects fixed + canonical template updated*

## Problem
The standard dotfiles volume block in devcontainer docker-compose files only mounted `~/.config/dotfiles/zsh`. It did
not mount `~/.config/dotfiles/claude`, so Claude Code plugins (skills, etc.) were unavailable inside containers.

## Fix
Added this volume mount to every active project's `.devcontainer/docker-compose.yml`:

```yaml
- ~/.config/dotfiles/claude:/home/dev/.config/dotfiles/claude:cached
```

Also updated the canonical template in `dotfiles/devcontainer/docker-compose.base.yml` so new projects get it
automatically.

## Status
- [x] snowfort — fixed 2026-04-05
- [x] wallpaper-kit — fixed 2026-04-05
- [x] cairn — fixed 2026-04-05
- [x] pytest-coverage-impact — already had it
- [x] snowflake-projects/snowfort — already had it
- [x] snowflake-projects — already had it
- [x] `dotfiles/devcontainer/docker-compose.base.yml` template — fixed 2026-04-05
