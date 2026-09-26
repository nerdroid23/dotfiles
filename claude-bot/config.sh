# shellcheck shell=bash
# Shared constants for the claude-bot scripts. Each value can be overridden
# by setting the variable in the environment before sourcing.

: "${CLAUDE_BOT_APP_ID:=5090529}"
: "${CLAUDE_BOT_APP_SLUG:=nerdroid-claude}"
: "${CLAUDE_BOT_LOGIN:=nerdroid-claude[bot]}"
: "${CLAUDE_BOT_USER_ID:=334336263}"
: "${CLAUDE_BOT_EMAIL:=334336263+nerdroid-claude[bot]@users.noreply.github.com}"
: "${CLAUDE_BOT_KEY:=$HOME/.config/claude-bot/key.pem}"
: "${CLAUDE_BOT_CACHE:=$HOME/.cache/claude-bot}"
: "${CLAUDE_BOT_REVIEWER:=nerdroid23}"
: "${CLAUDE_BOT_DEFAULT_OWNER:=nerdroid23}"
: "${CLAUDE_BOT_API:=https://api.github.com}"
: "${CLAUDE_BOT_GH_CONFIG_DIR:=$HOME/.config/gh-claude-bot}"

export CLAUDE_BOT_APP_ID CLAUDE_BOT_APP_SLUG CLAUDE_BOT_LOGIN CLAUDE_BOT_USER_ID \
  CLAUDE_BOT_EMAIL CLAUDE_BOT_KEY CLAUDE_BOT_CACHE CLAUDE_BOT_REVIEWER \
  CLAUDE_BOT_DEFAULT_OWNER CLAUDE_BOT_API CLAUDE_BOT_GH_CONFIG_DIR
