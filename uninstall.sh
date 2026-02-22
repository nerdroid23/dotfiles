#!/usr/bin/env bash
# Dotfiles uninstaller
#
# Reverses all changes made by install.sh.
#
# Usage:
#   ./uninstall.sh                                    # local-only teardown
#   ./uninstall.sh --drive /Volumes/MillenniumFalcon  # also reverse drive symlinks

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==============================================================================
# Colours & helpers
# ==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() { echo -e "\n${BOLD}${BLUE}==> $1${RESET}"; }
print_step()   { echo -e "  ${YELLOW}•${RESET} $1"; }
print_ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
print_skip()   { echo -e "  ${BLUE}↷${RESET} $1 (skipped)"; }
print_error()  { echo -e "  ${RED}✗${RESET} $1" >&2; }

# ==============================================================================
# Banner
# ==============================================================================
echo -e "${BOLD}"
echo "  ╔════════════════════════════════╗"
echo "  ║     dotfiles uninstaller       ║"
echo "  ╚════════════════════════════════╝"
echo -e "${RESET}"

# ==============================================================================
# macOS check
# ==============================================================================
if [[ "$(uname)" != "Darwin" ]]; then
  print_error "This uninstaller is macOS-only."
  exit 1
fi

# ==============================================================================
# Parse arguments
# ==============================================================================
DRIVE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive)
      DRIVE="${2:?'--drive requires a path, e.g. --drive /Volumes/MillenniumFalcon'}"
      shift 2
      ;;
    *)
      print_error "Unknown argument: $1"
      echo "Usage: $0 [--drive /Volumes/NAME]"
      exit 1
      ;;
  esac
done

if [[ -n "$DRIVE" ]]; then
  if [[ ! -d "$DRIVE" ]]; then
    print_error "Drive not found: $DRIVE"
    print_error "Make sure the drive is mounted before running with --drive."
    exit 1
  fi
  echo -e "  External drive: ${BOLD}$DRIVE${RESET}"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo -e "  ${BOLD}The following will be removed:${RESET}"
echo ""
echo "   • Mackup symlinks (files copied back via mackup uninstall)"
echo "   • Stow symlinks (mackup, git, zsh, starship packages)"
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

read -rp "  Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo ""
  echo "  Aborted."
  exit 0
fi

# ==============================================================================
# Mackup
# ==============================================================================
print_header "Mackup"

if command -v mackup &>/dev/null && [[ -f "$HOME/.mackup.cfg" ]]; then
  print_step "Running mackup uninstall --force..."
  mackup uninstall --force
  print_ok "Mackup symlinks replaced with real files"
else
  print_skip "Mackup (not installed or no config)"
fi

# ==============================================================================
# Stow symlinks
# ==============================================================================
print_header "Removing stow symlinks"

if command -v stow &>/dev/null; then
  print_step "Running stow --delete..."
  stow --delete --dir="$DOTFILES" --target="$HOME" mackup git zsh starship
  print_ok "Stow symlinks removed"
else
  print_skip "Stow (not installed)"
fi

# ==============================================================================
# Git identity files
# ==============================================================================
print_header "Git identity files"

if [[ -f "$HOME/.gitconfig-work" ]]; then
  rm -f "$HOME/.gitconfig-work"
  print_ok "~/.gitconfig-work removed"
else
  print_skip "~/.gitconfig-work (not found)"
fi

if [[ -f "$HOME/.gitconfig-personal" ]]; then
  rm -f "$HOME/.gitconfig-personal"
  print_ok "~/.gitconfig-personal removed"
else
  print_skip "~/.gitconfig-personal (not found)"
fi

# ==============================================================================
# .hushlogin
# ==============================================================================
print_header ".hushlogin"

if [[ -f "$HOME/.hushlogin" ]]; then
  rm -f "$HOME/.hushlogin"
  print_ok "~/.hushlogin removed"
else
  print_skip "~/.hushlogin (not found)"
fi

# ==============================================================================
# Laravel Valet
# ==============================================================================
print_header "Laravel Valet"

if command -v valet &>/dev/null; then
  print_step "Uninstalling Laravel Valet..."
  valet uninstall --force
  composer global remove laravel/valet
  print_ok "Laravel Valet removed"
else
  print_skip "Laravel Valet (not installed)"
fi

# ==============================================================================
# Oh My Zsh
# ==============================================================================
print_header "Oh My Zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
  print_step "Uninstalling Oh My Zsh..."
  # Use OMZ's own uninstaller non-interactively
  ZSH="$HOME/.oh-my-zsh" bash "$HOME/.oh-my-zsh/tools/uninstall.sh" --unattended
  print_ok "Oh My Zsh removed"
else
  print_skip "Oh My Zsh (not installed)"
fi

# ==============================================================================
# macOS defaults
# ==============================================================================
print_header "Restoring macOS defaults"
SNAPSHOT_DIR="$HOME/.dotfiles-macos-snapshot"

if [[ -d "$SNAPSHOT_DIR" ]]; then
  for plist in "$SNAPSHOT_DIR"/*.plist; do
    domain="$(basename "$plist" .plist)"
    # Reverse the safe-name encoding (/ was replaced with _ during snapshot)
    # Safe because none of the original domain names contain underscores
    domain="${domain//_//}"
    defaults import "$domain" "$plist" 2>/dev/null || true
  done

  for app in "Dock" "Finder" "Safari" "SystemUIServer" "Activity Monitor"; do
    killall "$app" &>/dev/null || true
  done

  rm -rf "$SNAPSHOT_DIR"
  print_ok "macOS defaults restored and snapshot removed"
else
  print_skip "macOS defaults (no snapshot found at $SNAPSHOT_DIR)"
fi

# ==============================================================================
# External drive symlinks
# ==============================================================================
teardown_symlink() {
  local src="$1" dst="$2" label="$3"
  src="${src/#\~/$HOME}"

  if [[ ! -L "$src" ]]; then
    print_skip "$label (not a symlink)"
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

if [[ -n "$DRIVE" ]]; then
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
fi

# ==============================================================================
# Homebrew (explicit separate prompt — removes ALL packages)
# ==============================================================================
print_header "Homebrew"
echo ""
echo -e "  ${RED}${BOLD}WARNING:${RESET} This will remove Homebrew AND all installed formulae,"
echo "  casks, and packages. This cannot be undone."
echo ""
read -rp "  Remove Homebrew completely? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
  print_step "Uninstalling Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  print_ok "Homebrew removed"
else
  print_skip "Homebrew"
fi

# ==============================================================================
# Done
# ==============================================================================
echo -e "\n${BOLD}${GREEN}  Done!${RESET}"
echo ""
echo "  Not removed (intentional):"
echo "   • ~/work/ and ~/projects/"
if [[ -n "$DRIVE" ]]; then
  echo "   • $DRIVE/work/ and $DRIVE/projects/"
fi
echo "   • ~/.zshrc.local"
echo ""
echo "  You may want to restart your terminal."
echo ""
