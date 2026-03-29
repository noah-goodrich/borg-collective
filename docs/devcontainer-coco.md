# Devcontainer and Cortex Code CLI (CoCo) Compatibility Guide

This guide covers how The Borg Collective works with Docker Compose devcontainers and Snowflake's Cortex Code CLI. No prior context about either technology is assumed.

---

## Part 1: Devcontainers

### What Are Devcontainers?

Devcontainers are Docker containers configured as development environments. Instead of installing dependencies on your host machine, you define them in a `devcontainer.json` and `docker-compose.yml`, and your editor (VS Code, Neovim, etc.) connects to the running container. Each project gets its own isolated environment with its own language runtimes, packages, and system tools.

### How Claude Code Runs in Devcontainers

Claude Code can run inside a devcontainer just like any other CLI tool. The key question is: where does Claude Code's configuration live?

**Bind-mount approach (recommended):** Mount `~/.claude/` from the host into the container. This shares credentials, settings, hooks, skills, and session history across all containers and the host.

```yaml
# In docker-compose.yml:
volumes:
  - ~/.claude:/home/vscode/.claude:cached
```

This is the approach used across all of Noah's projects (cairn, wallpaper-kit, snowflake-projects).

### What Borg Needs

Borg's hooks fire inside containers (because hooks live in `~/.claude/hooks/`, which is bind-mounted). The hooks update the registry at `~/.config/borg/registry.json`. For this to work, the registry directory must also be bind-mounted.

**Required addition to every devcontainer `docker-compose.yml`:**

```yaml
volumes:
  # ... existing mounts ...
  - ~/.claude:/home/vscode/.claude:cached           # Already present
  - ~/.config/borg:/home/vscode/.config/borg:cached  # ADD THIS
```

Without this mount, hooks fire inside the container, attempt to update the registry, and either:
- Write to a path that doesn't exist (if `~/.config/borg/` doesn't exist in the container)
- Write to the container's filesystem (lost when container stops)

Both cases result in silent failures because hooks exit 0 regardless of registry update success.

### What Works Automatically

| Feature | Works in Container? | Notes |
|---------|:------------------:|-------|
| Hooks firing | Yes | Via `~/.claude/hooks/` bind mount |
| Registry updates | Yes (with mount) | Requires `~/.config/borg/` mount |
| Skills loading | Yes | Via `~/.claude/skills/` bind mount |
| Settings propagation | Yes | Via `~/.claude/settings.json` bind mount |
| Session discovery | Yes | Via `~/.claude/projects/` bind mount |
| Session log | Yes | Via `~/.claude/session-log.md` bind mount |
| tmux integration | No | tmux runs on host; borg switch runs on host |
| borg CLI commands | No | Run on host, not in container |

### Path Resolution

Inside a container, the working directory is typically `/workspace` or `/development`, not `/Users/noah/dev/cairn`. Borg's hooks use `basename($CWD)` to derive the project name:

- Host: `basename("/Users/noah/dev/cairn")` = `cairn`
- Container: `basename("/workspace")` = `workspace`

When the container workspace is the project root, `basename` returns the mount point name, not the project name. The wallpaper-kit devcontainer uses `/workspace`, and cairn uses `/workspace`.

**Impact:** If the container mount point is generic (like `/workspace`), the hook will register the project as "workspace" instead of "cairn". This requires one of:
- Setting `BORG_PROJECT_NAME` as a container environment variable
- Using the container's git remote or directory name to infer the project name
- Accepting that container sessions are tracked by mount point name

This is a known limitation that will be addressed during Phase 0 testing.

### Worktrees and Devcontainers

Git worktrees (`claude --worktree <name>`) create isolated code directories within a single container. They provide **code isolation** but share the container's environment (Node.js version, system tools, etc.).

For **environment isolation** across projects, use separate containers. For **code isolation** within a project, use worktrees inside a container. Both work with borg:

- Multiple containers with borg registry mount: each container's hooks update the shared registry
- Worktrees inside one container: each worktree is a separate git branch, but they share the same registry project entry

### Recommended devcontainer.json Template

```json
{
  "name": "Project Name",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "containerEnv": {
    "CLAUDE_CONFIG_DIR": "/home/vscode/.claude",
    "BORG_DIR": "/home/vscode/.config/borg"
  },
  "postCreateCommand": "echo 'Container ready'",
  "remoteUser": "vscode"
}
```

### Recommended docker-compose.yml Volume Block

```yaml
volumes:
  # Project files
  - ..:/workspace:cached

  # Dotfiles
  - ~/.zshrc:/home/vscode/.zshrc:cached
  - ~/.p10k.zsh:/home/vscode/.p10k.zsh:cached
  - ~/.config/zsh:/home/vscode/.config/zsh:cached
  - ~/.config/nvim:/home/vscode/.config/nvim:cached
  - ~/.ssh:/home/vscode/.ssh:cached
  - ~/.gitconfig:/home/vscode/.gitconfig:cached
  - /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock

  # Claude Code (hooks, skills, settings, sessions)
  - ~/.claude:/home/vscode/.claude:cached

  # Borg Collective (registry)
  - ~/.config/borg:/home/vscode/.config/borg:cached
```

---

## Part 2: Cortex Code CLI (CoCo)

### What Is CoCo?

Cortex Code CLI is Snowflake's AI coding agent. It is a separate product from Claude Code, not a fork or wrapper. While it uses Claude models (Opus 4.6, Sonnet 4.6) under the hood, it has its own architecture specialized for data engineering: native SQL execution, dbt integration, Snowflake catalog awareness, and role-based access control.

**Key command:** `cortex`
**Informal name:** CoCo
**Pricing:** ~$20/month individual subscription
**Release:** Generally available since February 2, 2026

### CoCo vs Claude Code

| Feature | Claude Code | CoCo |
|---------|------------|------|
| **Primary use** | General software development | Snowflake data engineering |
| **Config directory** | `~/.claude/` | `~/.snowflake/cortex/` |
| **Session storage** | `~/.claude/projects/` | `~/.snowflake/cortex/conversations/` |
| **Skills directory** | `~/.claude/skills/` | `~/.snowflake/cortex/skills/` |
| **Settings** | `~/.claude/settings.json` | `~/.snowflake/cortex/settings.json` |
| **Sandbox** | OS-native (sandbox-exec on macOS) | Podman (rootless) |
| **Slash commands** | `/new`, `/exit`, `/resume`, `/fork`, `/worktree` | Same + `/sql`, `/table`, `/lineage`, `/dbt` |
| **Skill format** | SKILL.md with YAML frontmatter | Same (100% compatible) |
| **Hook format** | Event-driven, stdin JSON | Same pattern, different tool names |
| **MCP support** | Yes | Yes |
| **Models** | Claude Opus/Sonnet | Claude Opus/Sonnet + GPT 5.2 preview |

### Skill Portability

This is the most important finding: **skills are 100% portable between Claude Code and CoCo.** They use the identical SKILL.md format with the same YAML frontmatter. A skill created for Claude Code works in CoCo without modification, and vice versa.

This means:
- The `adhd-guardrails` skill works in CoCo sessions
- The `checkpoint-enhanced` skill works in CoCo sessions
- Boris Cherny's framework tips (from `alirezarezvani/claude-skills`) work in CoCo sessions
- Scope Guard works in CoCo sessions

To make skills available in CoCo, either:
1. Copy them to `~/.snowflake/cortex/skills/`
2. Symlink: `ln -s ~/.claude/skills/adhd-guardrails ~/.snowflake/cortex/skills/adhd-guardrails`

### How CoCo Affects Borg

**Current state (Phase 0-2):** Borg does not track CoCo sessions. This is intentional — the tool focuses on Claude Code first.

**Future state:** When CoCo integration is needed, the changes are minimal:

1. **Add `lib/coco.zsh`** — Follows the same pattern as `lib/claude.zsh` but reads from `~/.snowflake/cortex/conversations/` instead of `~/.claude/projects/`

2. **Add `hooks/borg-stop-coco.sh`** — Same logic as `borg-stop.sh` but adapted for CoCo's hook stdin format (different field names for the same data)

3. **Registry `source` field** — Already a free-form string. Adding `"coco"` as a value requires no schema change. Projects would appear in `borg ls` with a new badge (e.g., `[S]` for Snowflake).

4. **Session IDs** — CoCo uses the same UUID format as Claude Code. No format changes needed.

**No changes are needed now.** The architecture is designed so CoCo integration is additive, not a refactor.

### Podman vs Docker

CoCo requires Podman for its sandbox. Devcontainers use Docker. These are different container runtimes, but they coexist on macOS without conflict:

- **Docker** runs via Docker Desktop (or colima/orbstack), with a daemon that manages containers
- **Podman** runs daemonless, with each container as a direct process. On macOS, Podman runs inside a Linux VM managed by `podman machine`

They use different sockets and connection mechanisms. You do not need to alias one to the other. Both can run simultaneously.

**One consideration:** If VS Code's Dev Containers extension detects Podman, it may try to use it instead of Docker. To prevent this, explicitly configure VS Code to use Docker:

```json
// .vscode/settings.json
{
  "dev.containers.dockerPath": "docker"
}
```

### CoCo Installation and Setup

CoCo is installed separately from Claude Code:

```bash
# macOS/Linux
curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh

# Verify
cortex --version
```

CoCo requires a Snowflake account and connection configuration:

```toml
# ~/.snowflake/connections.toml
[dev]
account = "your-account"
user = "your-user"
authenticator = "externalbrowser"
```

Start CoCo:
```bash
cortex -c dev -w ~/src/analytics
```

### When to Use Which

| Scenario | Tool |
|----------|------|
| General software development | Claude Code |
| Frontend development (React, Vue) | Claude Code |
| Snowflake SQL generation and optimization | CoCo |
| dbt model development and testing | CoCo |
| Data pipeline debugging | CoCo |
| Multi-language refactoring | Claude Code |
| Snowflake catalog exploration | CoCo |
| Non-Snowflake projects | Claude Code |

---

## Part 3: Combined Workflow

### Daily Workflow with Both Tools

```
Morning:
  borg ls                          # See all Claude Code projects
  borg next                        # Get recommendation
  borg switch cairn                # Jump to work project (Claude Code)

Data engineering task:
  cortex -c dev -w ~/src/analytics # Start CoCo for Snowflake work
  /checkpoint-enhanced             # CoCo reads the same skill
  # Work on dbt models, SQL, pipelines

General development:
  borg switch wallpaper-kit        # Jump to personal project (Claude Code)
  /adhd-guardrails                 # Same skill, different tool

End of day:
  borg tidy                        # Clean up stale projects
```

### Skill Sharing

To ensure all skills work in both tools:

```bash
# One-time setup: symlink skill directories
ln -s ~/.claude/skills/adhd-guardrails ~/.snowflake/cortex/skills/adhd-guardrails
ln -s ~/.claude/skills/checkpoint-enhanced ~/.snowflake/cortex/skills/checkpoint-enhanced
```

Or, if you prefer to keep them separate, install skills in both locations:
```bash
cp -r ~/.claude/skills/adhd-guardrails ~/.snowflake/cortex/skills/
cp -r ~/.claude/skills/checkpoint-enhanced ~/.snowflake/cortex/skills/
```

### Future Borg Integration

When CoCo tracking is added to borg, the `borg ls` output will show all sessions:

```
PROJECT        SRC  STATUS    LAST ACTIVE  SUMMARY
cairn          [C]  waiting   14:30 (2h)   Goal: Fix deployment | Last: error handling
analytics      [S]  idle      11:00 (5h)   Goal: dbt revenue model | Last: add tests
wallpaper-kit  [C]  active    16:45 (now)  Goal: Ship v1.0 | Last: API endpoint
```

Where `[C]` = Claude Code, `[S]` = Snowflake/CoCo, and `[D]` = Claude Desktop.
