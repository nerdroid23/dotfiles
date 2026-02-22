export ZSH="$HOME/.oh-my-zsh"

# Starship handles the prompt — OMZ theme must be empty
ZSH_THEME=""

# Disable automatic updates (manage manually or via brew)
DISABLE_AUTO_UPDATE="true"

plugins=(git)

source "$ZSH/oh-my-zsh.sh"

# Dotfiles location (for other scripts to reference)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# ==============================================================================
# Dotfiles modules
# ==============================================================================
DOTFILES_ZSH="$HOME/.zsh"

source "$DOTFILES_ZSH/exports.zsh"
source "$DOTFILES_ZSH/paths.zsh"
source "$DOTFILES_ZSH/aliases.zsh"
source "$DOTFILES_ZSH/functions.zsh"

# ==============================================================================
# Machine-specific overrides (gitignored)
# ==============================================================================
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# ==============================================================================
# Zoxide (must be initialised after PATH is set)
# ==============================================================================
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ==============================================================================
# Starship prompt (must be last)
# ==============================================================================
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi
