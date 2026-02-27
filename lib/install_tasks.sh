#!/usr/bin/env bash

# Installer phase functions for install.sh.
# Required globals from caller:
#   DOTFILES, DRY_RUN, DRIVE, ALLOW_NON_VOLUMES_DRIVE
# Shared helpers expected from lib/common.sh:
#   print_*, prompt, run
# Drive helpers expected from lib/install_drive.sh:
#   validate_drive_path, setup_symlink_safe

INSTALL_WARNINGS=()
MAS_FAILED_APPS=()
MAS_FAILED_IDS=()

add_install_warning() {
  local warning="$1"
  local item
  for item in "${INSTALL_WARNINGS[@]-}"; do
    if [[ "$item" == "$warning" ]]; then
      return 0
    fi
  done
  INSTALL_WARNINGS+=("$warning")
}

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
    print_warn "mas not installed yet - App Store check skipped for now"
  elif ! mas list &>/dev/null; then
    print_warn "Not signed into App Store - MAS installs will be attempted later and may fail"
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

ensure_php84_linked() {
  print_step "Ensuring php@8.4 is linked..."

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} brew link --overwrite php@8.4"
    echo -e "  ${YELLOW}[dry-run]${RESET} (on conflict) brew unlink php && brew unlink php@8.2 && brew link --overwrite php@8.4"
    return 0
  fi

  if brew link --overwrite php@8.4 &>/dev/null; then
    print_ok "php@8.4 linked"
    return 0
  fi

  print_warn "php@8.4 link conflict detected - unlinking conflicting formulas"
  brew unlink php &>/dev/null || true
  brew unlink php@8.2 &>/dev/null || true
  brew link --overwrite php@8.4 &>/dev/null
  print_ok "php@8.4 linked"
}

install_php_and_composer_early() {
  print_header "PHP + Composer"
  print_step "Installing php@8.4 and composer..."
  run brew install php@8.4 composer
  ensure_php84_linked

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} php -v"
    echo -e "  ${YELLOW}[dry-run]${RESET} composer --version"
  else
    print_step "PHP: $(php -v | head -n 1)"
    print_step "Composer: $(composer --version)"
  fi

  print_ok "PHP and Composer ready"
}

resolve_valet_bin() {
  if command -v valet &>/dev/null; then
    command -v valet
    return 0
  fi
  if [[ -x "$HOME/.composer/vendor/bin/valet" ]]; then
    echo "$HOME/.composer/vendor/bin/valet"
    return 0
  fi
  if [[ -x "$HOME/.config/composer/vendor/bin/valet" ]]; then
    echo "$HOME/.config/composer/vendor/bin/valet"
    return 0
  fi
  return 1
}

normalize_valet_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  path="${path%/}"
  echo "$path"
}

valet_has_parked_path() {
  local valet_bin="$1"
  local target_path normalized_target normalized_line

  target_path="$2"
  normalized_target="$(normalize_valet_path "$target_path")"

  while IFS= read -r line; do
    normalized_line="$(normalize_valet_path "$line")"
    if [[ "$normalized_line" == "$normalized_target" ]]; then
      return 0
    fi
  done < <("$valet_bin" paths 2>/dev/null || true)

  return 1
}

park_valet_directories() {
  print_step "Parking Valet directories..."

  local valet_bin=""
  if [[ "$DRY_RUN" != true ]]; then
    if ! valet_bin="$(resolve_valet_bin)"; then
      print_warn "Valet binary not found - skipping valet park"
      add_install_warning "Laravel Valet park step skipped because valet was not found in PATH"
      return 0
    fi
  fi

  local park_targets=(
    "$HOME/work"
    "$HOME/projects"
  )
  if [[ -n "$DRIVE" ]]; then
    park_targets+=("$DRIVE/work" "$DRIVE/projects")
  fi

  local target
  for target in "${park_targets[@]}"; do
    run mkdir -p "$target"

    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} valet park \"$target\""
      continue
    fi

    if valet_has_parked_path "$valet_bin" "$target"; then
      print_skip "valet park $target"
      continue
    fi

    if "$valet_bin" park "$target" >/dev/null 2>&1; then
      print_ok "Valet parked $target"
    else
      print_warn "Failed to valet park $target"
      add_install_warning "Laravel Valet failed to park $target"
    fi
  done
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

build_non_mas_bootstrap_brewfile() {
  local src="$1" dst="$2"

  awk '
    /^mas / { next }
    /^brew "composer"/ { next }
    /^brew "php@8.4"/ { next }
    { print }
  ' "$src" > "$dst"
}

run_brew_bundle_non_mas_non_bootstrap() {
  print_header "Brew bundle"
  print_step "Installing remaining packages, casks, and VS Code extensions..."

  local tmp_brewfile
  tmp_brewfile="$(mktemp /tmp/dotfiles-brewfile.XXXXXX)"
  build_non_mas_bootstrap_brewfile "$DOTFILES/Brewfile" "$tmp_brewfile"

  run brew bundle --file="$tmp_brewfile"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} (Brewfile excludes mas, composer, php@8.4)"
  fi

  rm -f "$tmp_brewfile"
  print_ok "Brew bundle complete"
}

parse_mas_apps_from_brewfile() {
  local brewfile="$1"
  local line name id

  while IFS= read -r line; do
    name="$(printf '%s\n' "$line" | awk -F'"' '{print $2}')"
    id="$(printf '%s\n' "$line" | sed -E 's/.*id: ([0-9]+).*/\1/')"
    if [[ -n "$name" && "$id" =~ ^[0-9]+$ ]]; then
      printf '%s\t%s\n' "$name" "$id"
    fi
  done < <(grep '^mas "' "$brewfile" || true)
}

install_mas_apps_non_blocking() {
  print_header "App Store apps (mas)"

  if [[ "$DRY_RUN" == true ]]; then
    print_step "Would install MAS apps from Brewfile:"
    parse_mas_apps_from_brewfile "$DOTFILES/Brewfile" | while IFS=$'\t' read -r name id; do
      echo "    - $name ($id)"
    done
    return 0
  fi

  if ! command -v mas &>/dev/null; then
    print_warn "mas not installed - skipping App Store app installs"
    add_install_warning "App Store apps skipped because mas is unavailable"
    return 0
  fi

  if ! mas list &>/dev/null; then
    print_warn "Not signed into App Store - skipping App Store app installs"
    add_install_warning "App Store apps skipped because no App Store session is active"
    return 0
  fi

  local name id had_apps=false
  while IFS=$'\t' read -r name id; do
    had_apps=true
    print_step "Installing $name..."
    if mas install "$id"; then
      print_ok "$name"
    else
      print_warn "Failed to install $name ($id)"
      MAS_FAILED_APPS+=("$name ($id)")
      MAS_FAILED_IDS+=("$id")
    fi
  done < <(parse_mas_apps_from_brewfile "$DOTFILES/Brewfile")

  if [[ "$had_apps" == false ]]; then
    print_skip "App Store apps"
  fi

  if [[ ${#MAS_FAILED_APPS[@]} -gt 0 ]]; then
    add_install_warning "Some App Store apps failed to install"
  fi
}

install_laravel_valet() {
  print_header "Laravel Valet"

  local valet_bin=""
  if valet_bin="$(resolve_valet_bin)"; then
    print_skip "Laravel Valet"
  else
    print_step "Installing Laravel Valet..."
    run composer global require laravel/valet

    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} valet install"
      echo -e "  ${YELLOW}[dry-run]${RESET} valet trust"
    else
      if ! valet_bin="$(resolve_valet_bin)"; then
        print_error "valet binary not found after composer install"
        return 1
      fi
      "$valet_bin" install
      "$valet_bin" trust
    fi
    print_ok "Laravel Valet installed"
  fi

  park_valet_directories
}

check_valet_health() {
  print_header "Valet health check"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} valet --version"
    echo -e "  ${YELLOW}[dry-run]${RESET} valet paths"
    return 0
  fi

  local valet_bin=""
  if ! valet_bin="$(resolve_valet_bin)"; then
    print_warn "Valet binary not found for health check"
    add_install_warning "Laravel Valet health check skipped because valet was not found in PATH"
    return 0
  fi

  if ! "$valet_bin" --version >/dev/null 2>&1; then
    print_warn "Valet version check failed"
    add_install_warning "Laravel Valet health check failed: valet --version"
    return 0
  fi

  if ! "$valet_bin" paths >/dev/null 2>&1; then
    print_warn "Valet paths check failed"
    add_install_warning "Laravel Valet health check failed: valet paths"
    return 0
  fi

  print_ok "Valet looks healthy"
}

stow_dotfiles() {
  print_header "Symlinking dotfiles (stow)"

  if ! command -v stow &>/dev/null; then
    print_step "stow not found - installing via Homebrew..."
    run brew install stow
    if [[ "$DRY_RUN" != true ]] && ! command -v stow &>/dev/null; then
      print_error "stow is still unavailable after installation"
      return 1
    fi
    print_ok "stow installed"
  fi

  backup_existing_zshrc_for_stow

  print_step "Running stow --restow..."
  run stow --restow --dir="$DOTFILES" --target="$HOME" mackup git zsh starship ai-cli
  print_ok "Symlinks created"
}

backup_existing_zshrc_for_stow() {
  local zshrc="$HOME/.zshrc"
  local backup="$HOME/.zshrc.pre-dotfiles-backup"

  if [[ ! -e "$zshrc" || -L "$zshrc" ]]; then
    return 0
  fi

  if [[ -e "$backup" ]]; then
    backup="$HOME/.zshrc.pre-dotfiles-backup.$(date +%Y%m%d%H%M%S)"
  fi

  print_step "Backing up existing ~/.zshrc before stow..."
  run mv "$zshrc" "$backup"
  print_ok "~/.zshrc backed up to $backup"
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

  local -a specs=(
    "$HOME/.orbstack|$DRIVE/OrbStack|OrbStack"
    "$HOME/Library/Developer/Xcode/DerivedData|$DRIVE/Xcode/DerivedData|Xcode DerivedData"
    "$HOME/Library/Developer/CoreSimulator/Devices|$DRIVE/Xcode/Simulators|iOS Simulators"
    "$HOME/Library/Android/sdk|$DRIVE/Android/sdk|Android SDK"
    "$HOME/.android/avd|$DRIVE/Android/avd|Android AVDs"
  )

  local spec src dst label
  for spec in "${specs[@]}"; do
    IFS='|' read -r src dst label <<< "$spec"
    if ! setup_symlink_safe "$src" "$dst" "$label"; then
      print_error "Drive setup aborted due to preexisting state. See errors above."
      return 1
    fi
  done
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
      if [[ "$domain" == *_* ]]; then
        print_warn "Domain '$domain' contains underscore - snapshot/restore mapping may break"
      fi
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
    bash "$DOTFILES/macos.sh"
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

setup_ssh_key() {
  print_header "SSH key"

  local ssh_key="$HOME/.ssh/id_ed25519"

  if [[ -f "$ssh_key" ]]; then
    print_skip "SSH key ($ssh_key)"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} ssh-keygen -t ed25519"
    echo -e "  ${YELLOW}[dry-run]${RESET} ssh-add ~/.ssh/id_ed25519"
    echo -e "  ${YELLOW}[dry-run]${RESET} gh ssh-key add ~/.ssh/id_ed25519.pub"
    return 0
  fi

  local email=""
  if [[ -f "$HOME/.gitconfig-personal" ]]; then
    email="$(git config --file "$HOME/.gitconfig-personal" user.email 2>/dev/null || true)"
  fi
  if [[ -z "$email" ]]; then
    prompt email "  Email for SSH key" ""
  fi

  print_step "Generating ed25519 SSH key..."
  mkdir -p "$HOME/.ssh"
  if ! ssh-keygen -t ed25519 -C "$email" -f "$ssh_key"; then
    print_warn "SSH key generation failed or was cancelled"
    add_install_warning "SSH key was not generated. Run manually: ssh-keygen -t ed25519"
    return 0
  fi
  print_ok "SSH key generated"

  print_step "Adding key to ssh-agent..."
  if eval "$(ssh-agent -s)" >/dev/null 2>&1 && ssh-add "$ssh_key" 2>/dev/null; then
    print_ok "Key added to agent"
  else
    print_warn "Could not add key to ssh-agent (add manually: ssh-add ~/.ssh/id_ed25519)"
    add_install_warning "SSH key generated but could not be added to ssh-agent"
  fi

  if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
      local key_title="dotfiles-install $(hostname) $(date +%Y-%m-%d)"
      print_step "Adding public key to GitHub via gh..."
      if gh ssh-key add "${ssh_key}.pub" --title "$key_title"; then
        print_ok "SSH key added to GitHub"
      else
        print_warn "Failed to add SSH key to GitHub"
        add_install_warning "SSH key generated but could not be added to GitHub automatically"
      fi
    else
      print_warn "gh is not authenticated - skipping GitHub upload"
      add_install_warning "SSH key generated but gh is not authenticated. Add manually: gh ssh-key add ~/.ssh/id_ed25519.pub"
      echo ""
      echo "  Your public key:"
      cat "${ssh_key}.pub"
      echo ""
    fi
  else
    print_warn "gh CLI not found - skipping GitHub upload"
    add_install_warning "SSH key generated but gh is not installed. Add key to GitHub manually."
    echo ""
    echo "  Your public key:"
    cat "${ssh_key}.pub"
    echo ""
  fi
}

print_install_warnings_summary() {
  if [[ ${#INSTALL_WARNINGS[@]} -eq 0 && ${#MAS_FAILED_APPS[@]} -eq 0 ]]; then
    return 0
  fi

  print_header "Warnings summary"

  local warning
  for warning in "${INSTALL_WARNINGS[@]}"; do
    echo "   - $warning"
  done

  if [[ ${#MAS_FAILED_APPS[@]} -gt 0 ]]; then
    echo ""
    echo "  App Store installs that failed:"
    local app
    for app in "${MAS_FAILED_APPS[@]}"; do
      echo "   - $app"
    done

    if [[ ${#MAS_FAILED_IDS[@]} -gt 0 ]]; then
      echo ""
      echo "  Retry manually:"
      local app_id
      for app_id in "${MAS_FAILED_IDS[@]}"; do
        echo "   mas install $app_id"
      done
    fi
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
