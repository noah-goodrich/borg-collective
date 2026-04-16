# Extends the shared base devcontainer image.
# Base provides: zsh, neovim, tmux, git, ssh, node.js, claude-code CLI.
#
# To rebuild the base locally:
#   docker build -f ~/.config/dotfiles/devcontainer/Dockerfile.base -t devcontainer-base:local .
FROM devcontainer-base:local

# Supabase projects default to Postgres client for manual queries + libpq for native bindings.
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR __WORKSPACE__
