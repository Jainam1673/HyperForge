#!/usr/bin/env bash
# Launcher for the official GitHub MCP server used by OpenCode.
# The GitHub token is read from the authenticated `gh` CLI at runtime; it is
# never written to this file, the repository, or the OpenCode config.
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "github-mcp: 'gh' CLI is required but was not found on PATH" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "github-mcp: 'docker' is required but was not found on PATH" >&2
  exit 1
fi

if ! token="$(gh auth token 2>/dev/null)" || [[ -z "${token}" ]]; then
  echo "github-mcp: no GitHub token available. Run 'gh auth login' first." >&2
  exit 1
fi

# Drop the secret from the child's visible environment once it is passed in.
GITHUB_PERSONAL_ACCESS_TOKEN="${token}" \
  exec docker run --interactive --rm \
    --env GITHUB_PERSONAL_ACCESS_TOKEN \
    ghcr.io/github/github-mcp-server:latest
