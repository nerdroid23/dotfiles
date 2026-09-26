#!/usr/bin/env bash
# Claude Code SessionStart hook: put the claude-bot shims first on PATH and
# warn when the App key is missing. Never fails the session.

self=${BASH_SOURCE[0]}
while [ -L "$self" ]; do
  target=$(readlink "$self")
  case $target in /*) self=$target ;; *) self=$(dirname "$self")/$target ;; esac
done
BOT_DIR=$(cd "$(dirname "$self")/.." && pwd -P) || exit 0
# shellcheck source-path=SCRIPTDIR source=../config.sh
. "$BOT_DIR/config.sh" 2>/dev/null || exit 0

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  # shellcheck disable=SC2016
  printf 'export PATH="%s:$PATH"\n' "$BOT_DIR/bin" >>"$CLAUDE_ENV_FILE" 2>/dev/null || true
fi

if [ ! -r "$CLAUDE_BOT_KEY" ]; then
  echo "claude-bot: App key missing at $CLAUDE_BOT_KEY; git/gh GitHub auth will fail until it is installed."
fi

exit 0
