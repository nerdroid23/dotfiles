#!/usr/bin/env bash

# Installer phase functions for install.sh.
# Required globals from caller:
#   DOTFILES, DRY_RUN, DRIVE, ALLOW_NON_VOLUMES_DRIVE
# Shared helpers expected from lib/common.sh:
#   print_*, prompt, run
# Drive helpers expected from lib/install_drive.sh:
#   validate_drive_path, setup_symlink_safe

show_install_banner() {
  echo -e "${BOLD}"
  echo "  +--------------------------------+"
  echo "  |      dotfiles installer        |"
  echo "  +--------------------------------+"
  echo -e "${RESET}"
}

require_macos_install() {
  if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This installer is macOS-only."
    return 1
  fi
}

validate_drive_option() {
  if [[ -n "$DRIVE" ]]; then
    if ! validate_drive_path "$DRIVE" "$ALLOW_NON_VOLUMES_DRIVE"; then
      return 1
    fi
    print_ok "External drive: $DRIVE"
  fi
}

create_hushlogin() {
  run touch "$HOME/.hushlogin"
}

run_preflight_checks() {
  print_header "Preflight checks"

  # Xcode Command Line Tools
  if ! xcode-select -p &>/dev/null; then
    print_step "Installing Xcode Command Line Tools..."
    if [[ "$DRY_RUN" != true ]]; then
      xcode-select --install
      echo "  Press Enter after installation completes..."
      read -r
    else
      echo -e "  ${YELLOW}[dry-run]${RESET} xcode-select --install"
    fi
  fi
  print_ok "Xcode CLT"

  # Check for mas apps (App Store login)
  if ! command -v mas &>/dev/null; then
    print_warn "mas not installed yet - App Store check skipped (will install via brew)"
  elif ! mas account &>/dev/null; then
    print_error "Not signed into App Store. Run: mas signin"
    exit 1
  else
    print_ok "App Store signed in"
  fi

  # Check iCloud for Mackup
  if [[ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
    print_warn "iCloud Drive not ready - Mackup restore may fail"
  else
    print_ok "iCloud Drive"
  fi
}

install_homebrew() {
  print_header "Homebrew"

  if command -v brew &>/dev/null; then
    print_skip "Homebrew"
  else
    print_step "Installing Homebrew..."
    if [[ "$DRY_RUN" != true ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add brew to PATH for the rest of this script
      if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    else
      echo -e "  ${YELLOW}[dry-run]${RESET} Install Homebrew"
    fi
    print_ok "Homebrew installed"
  fi
}

install_oh_my_zsh() {
  print_header "Oh My Zsh"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_skip "Oh My Zsh"
  else
    print_step "Installing Oh My Zsh..."
    if [[ "$DRY_RUN" != true ]]; then
      RUNZSH=no CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
      echo -e "  ${YELLOW}[dry-run]${RESET} Install Oh My Zsh"
    fi
    print_ok "Oh My Zsh installed"
  fi
}

run_brew_bundle() {
  print_header "Brew bundle"
  print_step "Installing packages, casks, and VS Code extensions..."
  run brew bundle --file="$DOTFILES/Brewfile"
  print_ok "Brew bundle complete"
}

install_laravel_valet() {
  print_header "Laravel Valet"

  local composer_bin=""
  if [[ -d "$HOME/.composer/vendor/bin" ]]; then
    composer_bin="$HOME/.composer/vendor/bin"
  elif [[ -d "$HOME/.config/composer/vendor/bin" ]]; then
    composer_bin="$HOME/.config/composer/vendor/bin"
  fi

  if [[ -n "$composer_bin" && -x "$composer_bin/valet" ]]; then
    print_skip "Laravel Valet"
  else
    print_step "Installing Laravel Valet..."
    run composer global require laravel/valet

    if [[ "$DRY_RUN" != true ]]; then
      if [[ -x "$HOME/.composer/vendor/bin/valet" ]]; then
        composer_bin="$HOME/.composer/vendor/bin"
      elif [[ -x "$HOME/.config/composer/vendor/bin/valet" ]]; then
        composer_bin="$HOME/.config/composer/vendor/bin"
      fi

      "$composer_bin/valet" install
      "$composer_bin/valet" trust
    fi
    print_ok "Laravel Valet installed"
  fi
}

stow_dotfiles() {
  print_header "Symlinking dotfiles (stow)"
  print_step "Running stow --restow..."
  run stow --restow --dir="$DOTFILES" --target="$HOME" mackup git zsh starship
  print_ok "Symlinks created"
}

setup_git_identity_files() {
  print_header "Git identity files"

  if [[ -f "$HOME/.gitconfig-work" && -f "$HOME/.gitconfig-personal" ]]; then
    print_skip "Git identity files"
  elif [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} Would prompt for work/personal Git identity"
    echo -e "  ${YELLOW}[dry-run]${RESET} Would write ~/.gitconfig-work"
    echo -e "  ${YELLOW}[dry-run]${RESET} Would write ~/.gitconfig-personal"
  else
    echo -e "\n  ${BOLD}Work identity${RESET}"
    prompt WORK_NAME  "  Name"  ""
    prompt WORK_EMAIL "  Email" ""

    echo -e "\n  ${BOLD}Personal identity${RESET}"
    prompt PERSONAL_NAME  "  Name"  ""
    prompt PERSONAL_EMAIL "  Email" ""

cat > "$HOME/.gitconfig-work" <<EOF
[user]
    name = $WORK_NAME
    email = $WORK_EMAIL
EOF
    print_ok "~/.gitconfig-work"

cat > "$HOME/.gitconfig-personal" <<EOF
[user]
    name = $PERSONAL_NAME
    email = $PERSONAL_EMAIL
EOF
    print_ok "~/.gitconfig-personal"
  fi
}

create_project_directories() {
  print_header "Creating project directories"

  run mkdir -p "$HOME/work"
  print_ok "~/work"

  run mkdir -p "$HOME/projects"
  print_ok "~/projects"

  if [[ -n "$DRIVE" ]]; then
    run mkdir -p "$DRIVE/work"
    print_ok "$DRIVE/work"

    run mkdir -p "$DRIVE/projects"
    print_ok "$DRIVE/projects"
  fi
}

setup_external_drive_symlinks() {
  if [[ -z "$DRIVE" ]]; then
    return 0
  fi

  print_header "External drive symlinks"

  local drive_setup_failed=false

  setup_symlink_safe \
    "$HOME/.orbstack" \
    "$DRIVE/OrbStack" \
    "OrbStack" || drive_setup_failed=true

  if [[ "$drive_setup_failed" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Developer/Xcode/DerivedData" \
      "$DRIVE/Xcode/DerivedData" \
      "Xcode DerivedData" || drive_setup_failed=true
  fi

  if [[ "$drive_setup_failed" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Developer/CoreSimulator/Devices" \
      "$DRIVE/Xcode/Simulators" \
      "iOS Simulators" || drive_setup_failed=true
  fi

  if [[ "$drive_setup_failed" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Android/sdk" \
      "$DRIVE/Android/sdk" \
      "Android SDK" || drive_setup_failed=true
  fi

  if [[ "$drive_setup_failed" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/.android/avd" \
      "$DRIVE/Android/avd" \
      "Android AVDs" || drive_setup_failed=true
  fi

  if [[ "$drive_setup_failed" == "true" ]]; then
    print_error "Drive setup aborted due to preexisting state. See errors above."
    return 1
  fi
}

snapshot_macos_defaults() {
  print_header "macOS defaults snapshot"
  local snapshot_dir="$HOME/.dotfiles-macos-snapshot"
  run mkdir -p "$snapshot_dir"

  local macos_domains=(
    NSGlobalDomain
    com.apple.finder
    com.apple.dock
    com.apple.Safari
    com.apple.BezelServices
    com.apple.AppleMultitouchTrackpad
    com.apple.driver.AppleBluetoothMultitouch.trackpad
    com.apple.screensaver
    com.apple.loginwindow
    com.apple.TimeMachine
    com.apple.CrashReporter
    com.apple.LaunchServices
    com.apple.AdLib
    com.apple.commerce
    com.apple.SoftwareUpdate
    com.apple.ActivityMonitor
    com.apple.TextEdit
    com.apple.messageshelper.MessageController
    com.apple.screencapture
  )

  if [[ "$DRY_RUN" != true ]]; then
    local domain safe
    for domain in "${macos_domains[@]}"; do
      safe="${domain//\//_}"
      defaults export "$domain" "$snapshot_dir/${safe}.plist" 2>/dev/null || true
    done
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} Export macOS defaults for ${#macos_domains[@]} domains"
  fi
  print_ok "macOS snapshot saved to $snapshot_dir"
}

apply_macos_defaults() {
  print_header "Applying macOS defaults"
  print_step "Running macos.sh..."
  if [[ "$DRY_RUN" != true ]]; then
    # shellcheck source=macos.sh
    source "$DOTFILES/macos.sh"
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} source macos.sh"
  fi
  print_ok "macOS defaults applied"
}

run_mackup_restore() {
  print_header "Mackup"
  print_step "Restoring app configs from iCloud..."
  if [[ "$DRY_RUN" != true ]]; then
    if mackup --config-file="$DOTFILES/mackup/.mackup.cfg" restore --force 2>/dev/null; then
      print_ok "Mackup restore complete"
    else
      print_skip "Mackup restore (no backup found or iCloud not ready - run manually later)"
    fi
  else
    echo -e "  ${YELLOW}[dry-run]${RESET} mackup --config-file=\"$DOTFILES/mackup/.mackup.cfg\" restore --force"
  fi
}

create_local_overrides_file() {
  print_header "Local overrides"

  if [[ -f "$HOME/.zshrc.local" ]]; then
    print_skip "~/.zshrc.local"
  else
    run cp "$DOTFILES/zsh/.zsh/.zshrc.local.example" "$HOME/.zshrc.local"
    print_ok "~/.zshrc.local created from template"
  fi
}

print_install_done() {
  echo -e "\n${BOLD}${GREEN}  All done!${RESET}"
  echo ""
  if [[ "$DRY_RUN" == true ]]; then
    echo "  This was a dry run - no changes were made."
    echo "  Run without --dry-run to apply changes."
    echo ""
  else
    echo "  Next steps:"
    echo "   1. Restart your terminal (or open a new tab)"
    echo "   2. Edit ~/.zshrc.local to add machine-specific secrets"
    if [[ -z "$DRIVE" ]]; then
      echo "   3. To set up an external drive later: ./install.sh --drive /Volumes/NAME"
    fi
    echo ""
  fi
}
