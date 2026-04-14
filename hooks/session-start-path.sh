#!/usr/bin/env bash
# Ensure plugin bin/ directory is on PATH for all contexts (worktrees, subagents)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_BIN="$(cd "$SCRIPT_DIR/../bin" && pwd)"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${PLUGIN_BIN}:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
