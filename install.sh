#!/usr/bin/env bash
# Dotfiles bootstrap installer
#
# Usage:
#   ./install.sh                                    # local-only setup
#   ./install.sh --drive /Volumes/MillenniumFalcon  # with external drive
#   ./install.sh --dry-run                          # preview actions

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
print_step()   { echo -e "  ${YELLOW}*${RESET} $1"; }
print_ok()     { echo -e "  ${GREEN}ok${RESET} $1"; }
print_skip()   { echo -e "  ${BLUE}skip${RESET} $1 (already done)"; }
print_error()  { echo -e "  ${RED}error${RESET} $1" >&2; }
print_warn()   { echo -e "  ${YELLOW}warn${RESET} $1"; }

# Error handling
trap 'print_error "Failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND"' ERR

prompt() {
  local var="$1" msg="$2" default="${3:-}"
  local display_default="" value=""
  [[ -n "$default" ]] && display_default=" [${default}]"

  while [[ -z "$value" ]]; do
    read -rp "  ${msg}${display_default}: " value
    if [[ -z "$value" && -n "$default" ]]; then
      value="$default"
    fi
    if [[ -z "$value" ]]; then
      echo -e "    ${RED}Value cannot be empty${RESET}"
    fi
  done

  printf -v "$var" '%s' "$value"
}

# Dry-run wrapper: prints instead of executing when DRY_RUN=true
run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} $*"
  else
    "$@"
  fi
}

# ==============================================================================
# Banner
# ==============================================================================
echo -e "${BOLD}"
echo "  +--------------------------------+"
echo "  |      dotfiles installer        |"
echo "  +--------------------------------+"
echo -e "${RESET}"

# ==============================================================================
# macOS check
# ==============================================================================
if [[ "$(uname)" != "Darwin" ]]; then
  print_error "This installer is macOS-only."
  exit 1
fi

# ==============================================================================
# Parse arguments
# ==============================================================================
DRIVE=""
ALLOW_NON_VOLUMES_DRIVE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --drive)
      DRIVE="${2:?'--drive requires a path, e.g. --drive /Volumes/MillenniumFalcon'}"
      shift 2
      ;;
    --allow-non-volumes-drive)
      ALLOW_NON_VOLUMES_DRIVE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      print_error "Unknown argument: $1"
      echo "Usage: $0 [--drive PATH] [--dry-run]"
      exit 1
      ;;
  esac
done

# Source drive migration helpers
# shellcheck source=lib/install_drive.sh
source "$DOTFILES/lib/install_drive.sh"

# Validate drive if provided
if [[ -n "$DRIVE" ]]; then
  if ! validate_drive_path "$DRIVE" "$ALLOW_NON_VOLUMES_DRIVE"; then
    exit 1
  fi
  print_ok "External drive: $DRIVE"
fi

if [[ "$DRY_RUN" == true ]]; then
  echo -e "  ${YELLOW}Dry-run mode enabled - no changes will be made${RESET}\n"
fi

# Suppress "Last login" message in new terminal tabs
run touch "$HOME/.hushlogin"

# ==============================================================================
# Preflight checks
# ==============================================================================
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

# ==============================================================================
# Homebrew
# ==============================================================================
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

# ==============================================================================
# Oh My Zsh
# ==============================================================================
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

# ==============================================================================
# Homebrew bundle
# ==============================================================================
print_header "Brew bundle"

print_step "Installing packages, casks, and VS Code extensions..."
run brew bundle --file="$DOTFILES/Brewfile"
print_ok "Brew bundle complete"

# ==============================================================================
# Laravel Valet
# ==============================================================================
print_header "Laravel Valet"

# Composer global bin may be in either location
COMPOSER_BIN=""
if [[ -d "$HOME/.composer/vendor/bin" ]]; then
  COMPOSER_BIN="$HOME/.composer/vendor/bin"
elif [[ -d "$HOME/.config/composer/vendor/bin" ]]; then
  COMPOSER_BIN="$HOME/.config/composer/vendor/bin"
fi

if [[ -n "$COMPOSER_BIN" && -x "$COMPOSER_BIN/valet" ]]; then
  print_skip "Laravel Valet"
else
  print_step "Installing Laravel Valet..."
  run composer global require laravel/valet

  if [[ "$DRY_RUN" != true ]]; then
    # Determine where Composer installed it
    if [[ -x "$HOME/.composer/vendor/bin/valet" ]]; then
      COMPOSER_BIN="$HOME/.composer/vendor/bin"
    elif [[ -x "$HOME/.config/composer/vendor/bin/valet" ]]; then
      COMPOSER_BIN="$HOME/.config/composer/vendor/bin"
    fi

    # Use absolute path to valet for the rest of this script
    "$COMPOSER_BIN/valet" install
    "$COMPOSER_BIN/valet" trust
  fi
  print_ok "Laravel Valet installed"
fi

# ==============================================================================
# GNU Stow
# ==============================================================================
print_header "Symlinking dotfiles (stow)"
print_step "Running stow --restow..."
run stow --restow --dir="$DOTFILES" --target="$HOME" mackup git zsh starship
print_ok "Symlinks created"

# ==============================================================================
# Git identity files (gitignored, written from prompts)
# ==============================================================================
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

# ==============================================================================
# Code directories
# ==============================================================================
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

# ==============================================================================
# External drive symlinks
# ==============================================================================
# Uses setup_symlink_safe from lib/install_drive.sh for safe, idempotent
# symlink creation with conflict detection and repair support.

if [[ -n "$DRIVE" ]]; then
  print_header "External drive symlinks"

  # Track if any symlink setup fails so we can abort drive section cleanly
  DRIVE_SETUP_FAILED=false

  setup_symlink_safe \
    "$HOME/.orbstack" \
    "$DRIVE/OrbStack" \
    "OrbStack" || DRIVE_SETUP_FAILED=true

  if [[ "$DRIVE_SETUP_FAILED" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Developer/Xcode/DerivedData" \
      "$DRIVE/Xcode/DerivedData" \
      "Xcode DerivedData" || DRIVE_SETUP_FAILED=true
  fi

  if [[ "$DRIVE_SETUP_FAILED" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Developer/CoreSimulator/Devices" \
      "$DRIVE/Xcode/Simulators" \
      "iOS Simulators" || DRIVE_SETUP_FAILED=true
  fi

  if [[ "$DRIVE_SETUP_FAILED" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/Library/Android/sdk" \
      "$DRIVE/Android/sdk" \
      "Android SDK" || DRIVE_SETUP_FAILED=true
  fi

  if [[ "$DRIVE_SETUP_FAILED" != "true" ]]; then
    setup_symlink_safe \
      "$HOME/.android/avd" \
      "$DRIVE/Android/avd" \
      "Android AVDs" || DRIVE_SETUP_FAILED=true
  fi

  if [[ "$DRIVE_SETUP_FAILED" == "true" ]]; then
    print_error "Drive setup aborted due to preexisting state. See errors above."
    exit 1
  fi
fi

# ==============================================================================
# macOS defaults snapshot (for uninstall)
# ==============================================================================
print_header "macOS defaults snapshot"
SNAPSHOT_DIR="$HOME/.dotfiles-macos-snapshot"
run mkdir -p "$SNAPSHOT_DIR"

MACOS_DOMAINS=(
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
  for domain in "${MACOS_DOMAINS[@]}"; do
    safe="${domain//\//_}"
    defaults export "$domain" "$SNAPSHOT_DIR/${safe}.plist" 2>/dev/null || true
  done
else
  echo -e "  ${YELLOW}[dry-run]${RESET} Export macOS defaults for ${#MACOS_DOMAINS[@]} domains"
fi
print_ok "macOS snapshot saved to $SNAPSHOT_DIR"

# ==============================================================================
# macOS defaults
# ==============================================================================
print_header "Applying macOS defaults"
print_step "Running macos.sh..."
if [[ "$DRY_RUN" != true ]]; then
  # shellcheck source=macos.sh
  source "$DOTFILES/macos.sh"
else
  echo -e "  ${YELLOW}[dry-run]${RESET} source macos.sh"
fi
print_ok "macOS defaults applied"

# ==============================================================================
# Mackup restore
# ==============================================================================
print_header "Mackup"
print_step "Restoring app configs from iCloud..."
if [[ "$DRY_RUN" != true ]]; then
  if mackup restore --force 2>/dev/null; then
    print_ok "Mackup restore complete"
  else
    print_skip "Mackup restore (no backup found or iCloud not ready - run manually later)"
  fi
else
  echo -e "  ${YELLOW}[dry-run]${RESET} mackup restore --force"
fi

# ==============================================================================
# Local zsh overrides file
# ==============================================================================
print_header "Local overrides"

if [[ -f "$HOME/.zshrc.local" ]]; then
  print_skip "~/.zshrc.local"
else
  run cp "$DOTFILES/zsh/.zsh/.zshrc.local.example" "$HOME/.zshrc.local"
  print_ok "~/.zshrc.local created from template"
fi

# ==============================================================================
# Done
# ==============================================================================
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
