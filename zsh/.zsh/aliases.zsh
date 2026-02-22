# ==============================================================================
# Modern CLI replacements
# ==============================================================================
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias lt="eza --tree --icons"
alias cat="bat"
alias f="fd"    # fd: modern find alternative
alias g="rg"    # rg: ripgrep
alias du="dust"
alias ps="procs"
alias j="z"  # jump with zoxide (cd remains builtin)

# ==============================================================================
# Navigation & filesystem
# ==============================================================================
alias o="open ."

# ==============================================================================
# System
# ==============================================================================
# Lock the screen
alias afk="osascript -e 'tell application \"System Events\" to keystroke \"q\" using {command down,control down}'"

# ==============================================================================
# Dotfiles
# ==============================================================================
alias dotfiles="$EDITOR ~/dotfiles"
alias zshconfig="$EDITOR ~/dotfiles/zsh/.zshrc"
alias zshreload="source ~/.zshrc"
alias aliasconfig="$EDITOR ~/dotfiles/zsh/.zsh/aliases.zsh"
alias gitconfig="$EDITOR ~/dotfiles/git/.gitconfig"

# ==============================================================================
# SSH
# ==============================================================================
alias sshconfig="$EDITOR ~/.ssh/config"

# ==============================================================================
# Git
# ==============================================================================
alias lg="lazygit"
