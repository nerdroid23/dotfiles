#!/usr/bin/env bash

# Uninstaller phase functions for uninstall.sh.
# Expected globals from caller:
#   DOTFILES, DRIVE, DRY_RUN
# Shared helpers/colors from lib/common.sh are used and some output helpers are
# overridden here to preserve the uninstaller's visual style.

# Preserve uninstall.sh's unicode output style
print_step()   { echo -e "  ${YELLOW}•${RESET} $1"; }
print_ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
print_skip()   { echo -e "  ${BLUE}↷${RESET} $1 (skipped)"; }
print_error()  { echo -e "  ${RED}✗${RESET} $1" >&2; }

show_uninstall_banner() {
  echo -e "${BOLD}"
  echo "  ╔════════════════════════════════╗"
  echo "  ║     dotfiles uninstaller       ║"
  echo "  ╚════════════════════════════════╝"
  echo -e "${RESET}"
}

require_macos_uninstall() {
  if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This uninstaller is macOS-only."
    return 1
  fi
}

validate_uninstall_drive_option() {
  if [[ -n "$DRIVE" ]]; then
    if [[ ! -d "$DRIVE" ]]; then
      print_error "Drive not found: $DRIVE"
      print_error "Make sure the drive is mounted before running with --drive."
      return 1
    fi
    echo -e "  External drive: ${BOLD}$DRIVE${RESET}"
  fi
}

print_uninstall_summary() {
  echo ""
  echo -e "  ${BOLD}The following will be removed:${RESET}"
  echo ""
  echo "   • Mackup symlinks (files copied back via mackup uninstall)"
  echo "   • Stow symlinks (mackup, git, zsh, starship, ai-cli packages)"
  echo "   • ~/.gitconfig-work and ~/.gitconfig-personal"
  echo "   • ~/.hushlogin"
  echo "   • Laravel Valet"
  echo "   • Oh My Zsh"
  echo "   • macOS defaults (restored from snapshot, if present)"
  if [[ -n "$DRIVE" ]]; then
    echo "   • Drive symlinks (data moved back from $DRIVE)"
  fi
  echo ""
  echo -e "  ${BOLD}The following will NOT be removed:${RESET}"
  echo ""
  echo "   • ~/work/ and ~/projects/ (may contain your projects)"
  if [[ -n "$DRIVE" ]]; then
    echo "   • $DRIVE/work/ and $DRIVE/projects/"
  fi
  echo "   • ~/.zshrc.local (user-customized)"
  echo "   • Homebrew (prompted separately at the end)"
  echo ""
}

confirm_uninstall() {
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi

  local confirm
  read -rp "  Continue? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  Aborted."
    return 1
  fi
}

uninstall_mackup() {
  print_header "Mackup"

  if command -v mackup &>/dev/null && [[ -f "$HOME/.mackup.cfg" ]]; then
    print_step "Running mackup uninstall --force..."
    run mackup --config-file="$DOTFILES/mackup/.mackup.cfg" uninstall --force
    print_ok "Mackup symlinks replaced with real files"
  else
    print_skip "Mackup (not installed or no config)"
  fi
}

remove_stow_symlinks() {
  print_header "Removing stow symlinks"

  if command -v stow &>/dev/null; then
    print_step "Running stow --delete..."
    run stow --delete --dir="$DOTFILES" --target="$HOME" mackup git zsh starship ai-cli
    print_ok "Stow symlinks removed"
  else
    print_skip "Stow (not installed)"
  fi
}

remove_git_identity_files() {
  print_header "Git identity files"

  if [[ -f "$HOME/.gitconfig-work" ]]; then
    run rm -f "$HOME/.gitconfig-work"
    print_ok "~/.gitconfig-work removed"
  else
    print_skip "~/.gitconfig-work (not found)"
  fi

  if [[ -f "$HOME/.gitconfig-personal" ]]; then
    run rm -f "$HOME/.gitconfig-personal"
    print_ok "~/.gitconfig-personal removed"
  else
    print_skip "~/.gitconfig-personal (not found)"
  fi
}

remove_hushlogin() {
  print_header ".hushlogin"

  if [[ -f "$HOME/.hushlogin" ]]; then
    run rm -f "$HOME/.hushlogin"
    print_ok "~/.hushlogin removed"
  else
    print_skip "~/.hushlogin (not found)"
  fi
}

uninstall_laravel_valet() {
  print_header "Laravel Valet"

  if command -v valet &>/dev/null; then
    print_step "Uninstalling Laravel Valet..."
    run valet uninstall --force
    run composer global remove laravel/valet
    print_ok "Laravel Valet removed"
  else
    print_skip "Laravel Valet (not installed)"
  fi
}

uninstall_oh_my_zsh() {
  print_header "Oh My Zsh"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_step "Uninstalling Oh My Zsh..."
    run env ZSH="$HOME/.oh-my-zsh" bash "$HOME/.oh-my-zsh/tools/uninstall.sh" --unattended
    print_ok "Oh My Zsh removed"
  else
    print_skip "Oh My Zsh (not installed)"
  fi
}

restore_macos_defaults() {
  print_header "Restoring macOS defaults"
  local snapshot_dir="$HOME/.dotfiles-macos-snapshot"

  if [[ -d "$snapshot_dir" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} Would restore macOS defaults from $snapshot_dir"
      echo -e "  ${YELLOW}[dry-run]${RESET} Would restart Dock, Finder, Safari, etc."
      echo -e "  ${YELLOW}[dry-run]${RESET} Would remove $snapshot_dir"
    else
      local plist domain
      for plist in "$snapshot_dir"/*.plist; do
        domain="$(basename "$plist" .plist)"
        if [[ "$domain" == *_* ]]; then
          print_warn "Snapshot '$domain' contains underscore - reverse mapping may be wrong"
        fi
        # Reverse the safe-name encoding (/ was replaced with _ during snapshot)
        domain="${domain//_//}"
        defaults import "$domain" "$plist" 2>/dev/null || true
      done

      local app
      for app in "Dock" "Finder" "Safari" "SystemUIServer" "Activity Monitor"; do
        killall "$app" &>/dev/null || true
      done

      rm -rf "$snapshot_dir"
    fi
    print_ok "macOS defaults restored and snapshot removed"
  else
    print_skip "macOS defaults (no snapshot found at $snapshot_dir)"
  fi
}

teardown_symlink() {
  local src="$1" dst="$2" label="$3"
  src="${src/#\~/$HOME}"

  if [[ ! -L "$src" ]]; then
    print_skip "$label (not a symlink)"
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} rm \"$src\""
    if [[ -d "$dst" ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} mv \"$dst\" \"$src\""
      print_ok "$label would be restored to $src"
    else
      print_ok "$label symlink would be removed"
    fi
    return
  fi

  rm "$src"

  if [[ -d "$dst" ]]; then
    print_step "Moving $label data back from drive..."
    mkdir -p "$(dirname "$src")"
    mv "$dst" "$src"
    print_ok "$label restored to $src"
  else
    print_ok "$label symlink removed (no data on drive to restore)"
  fi
}

reverse_drive_symlinks() {
  if [[ -z "$DRIVE" ]]; then
    return 0
  fi

  print_header "Reversing drive symlinks"

  teardown_symlink \
    "$HOME/.android/avd" \
    "$DRIVE/Android/avd" \
    "Android AVDs"

  teardown_symlink \
    "$HOME/Library/Android/sdk" \
    "$DRIVE/Android/sdk" \
    "Android SDK"

  teardown_symlink \
    "$HOME/Library/Developer/CoreSimulator/Devices" \
    "$DRIVE/Xcode/Simulators" \
    "iOS Simulators"

  teardown_symlink \
    "$HOME/Library/Developer/Xcode/DerivedData" \
    "$DRIVE/Xcode/DerivedData" \
    "Xcode DerivedData"

  teardown_symlink \
    "$HOME/.orbstack" \
    "$DRIVE/OrbStack" \
    "OrbStack"
}

prompt_remove_homebrew() {
  print_header "Homebrew"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} Would prompt to remove Homebrew"
    return 0
  fi

  echo ""
  echo -e "  ${RED}${BOLD}WARNING:${RESET} This will remove Homebrew AND all installed formulae,"
  echo "  casks, and packages. This cannot be undone."
  echo ""

  local yn
  read -rp "  Remove Homebrew completely? [y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    print_step "Uninstalling Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    print_ok "Homebrew removed"
  else
    print_skip "Homebrew"
  fi
}

print_uninstall_done() {
  echo -e "\n${BOLD}${GREEN}  Done!${RESET}"
  echo ""
  if [[ "$DRY_RUN" == true ]]; then
    echo "  This was a dry run - no changes were made."
    echo "  Run without --dry-run to apply changes."
    echo ""
  else
    echo "  Not removed (intentional):"
    echo "   • ~/work/ and ~/projects/"
    if [[ -n "$DRIVE" ]]; then
      echo "   • $DRIVE/work/ and $DRIVE/projects/"
    fi
    echo "   • ~/.zshrc.local"
    echo ""
    echo "  You may want to restart your terminal."
    echo ""
  fi
}
