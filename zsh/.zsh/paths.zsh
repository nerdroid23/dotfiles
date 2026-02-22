# Add a directory to PATH only if it exists and isn't already present.
add_to_path() {
  if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# Global Composer tools
add_to_path "$HOME/.composer/vendor/bin"
add_to_path "$HOME/.config/composer/vendor/bin"

# PHPMonitor helpers
add_to_path "$HOME/.config/phpmon/bin"

# Volta (Node version manager)
add_to_path "$HOME/.volta/bin"

# Java & Android
add_to_path "$JAVA_HOME/bin"
add_to_path "$ANDROID_HOME/emulator"
add_to_path "$ANDROID_HOME/platform-tools"

# User local bin
add_to_path "$HOME/.local/bin"
