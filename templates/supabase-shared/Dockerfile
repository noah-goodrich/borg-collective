# To rebuild the base image locally:
#   docker build -f ~/.config/dotfiles/devcontainer/Dockerfile.base -t devcontainer-base:local .
FROM devcontainer-base:local

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR __WORKSPACE__
