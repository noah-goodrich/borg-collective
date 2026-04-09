# Backlog: Devcontainer Dotfiles Mount Gap
*Created: 2026-04-05*

## Problem
The standard dotfiles volume block in devcontainer docker-compose files only mounts `~/.config/dotfiles/zsh`. It does
not mount `~/.config/dotfiles/claude`, so Claude Code plugins (skills, etc.) are unavailable inside containers.

## Fix
Add this volume mount to every project's `.devcontainer/docker-compose.yml`:

```yaml
- ~/.config/dotfiles/claude:/home/dev/.config/dotfiles/claude:cached
```

Also update the canonical template in `dotfiles/devcontainer/docker-compose.base.yml` so new projects get it
automatically.

## Status
- [x] snowfort — fixed 2026-04-05
- [x] wallpaper-kit — fixed 2026-04-05
- [x] cairn — fixed 2026-04-05
- [x] pytest-coverage-impact — already had it
- [x] snowflake-projects/snowfort — already had it
- [x] snowflake-projects — already had it
- [x] `dotfiles/devcontainer/docker-compose.base.yml` template — fixed 2026-04-05
- [ ] snowfort-old — legacy layout (uses /home/vscode, single-file .zshrc mount), needs full overhaul
- [ ] snowflake-examples/snow-forts — legacy layout, needs full overhaul
- [ ] snowflake-examples/vscode-devcontainer — legacy layout, needs full overhaul
