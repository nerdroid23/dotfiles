export ZSH="$HOME/.oh-my-zsh"

# Starship handles the prompt — OMZ theme must be empty
ZSH_THEME=""

# Disable automatic updates (manage manually or via brew)
DISABLE_AUTO_UPDATE="true"

plugins=(git)

source "$ZSH/oh-my-zsh.sh"

# Dotfiles location (derived from symlinked .zshrc or explicit override)
if [[ -z "${DOTFILES_DIR:-}" ]]; then
  if [[ -L "$HOME/.zshrc" ]]; then
    # Resolve symlink: ~/.zshrc -> .../dotfiles/zsh/.zshrc -> .../dotfiles
    _zshrc_target="$(readlink "$HOME/.zshrc")"
    # Handle relative symlinks
    if [[ "$_zshrc_target" != /* ]]; then
      _zshrc_target="$HOME/$_zshrc_target"
    fi
    # :A resolves to absolute path, :h gets parent (twice: .zshrc -> zsh -> dotfiles)
    DOTFILES_DIR="${_zshrc_target:A:h:h}"
    unset _zshrc_target
  else
    DOTFILES_DIR="$HOME/dotfiles"
  fi
fi
export DOTFILES_DIR

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
