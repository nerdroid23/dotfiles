# Editor
export EDITOR="zed"
export VISUAL="zed"

# Man pages
export MANPAGER="less -X"

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_BUNDLE_FILE="${DOTFILES_DIR:-$HOME/dotfiles}/Brewfile"

# Java (Zulu 17 via Homebrew)
if [[ -d "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home" ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
fi

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
