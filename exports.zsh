# Make zed the default editor
export EDITOR="zed"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"
# Highlight section titles in manual pages.
export LESS_TERMCAP_md="${yellow}";

# Always enable colored `grep` output
export GREP_OPTIONS="--color=auto"

# Do not auto update brew
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_FILE=~/.dotfiles/Brewfile
export HOMEBREW_BUNDLE_FILE_GLOBAL=~/.dotfiles/Brewfile
