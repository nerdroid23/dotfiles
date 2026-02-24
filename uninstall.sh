#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"
# shellcheck source=lib/cli_uninstall.sh
source "$DOTFILES/lib/cli_uninstall.sh"
# shellcheck source=lib/uninstall_tasks.sh
source "$DOTFILES/lib/uninstall_tasks.sh"

main() {
  show_uninstall_banner

  if ! require_macos_uninstall; then
    exit 1
  fi

  if ! parse_uninstall_args "$@"; then
    exit 1
  fi

  if ! validate_uninstall_drive_option; then
    exit 1
  fi

  print_uninstall_summary
  if ! confirm_uninstall; then
    exit 0
  fi

  uninstall_mackup
  remove_stow_symlinks
  remove_git_identity_files
  remove_hushlogin
  uninstall_laravel_valet
  uninstall_oh_my_zsh
  restore_macos_defaults
  reverse_drive_symlinks
  prompt_remove_homebrew
  print_uninstall_done
}

main "$@"
