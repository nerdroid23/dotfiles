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

trap 'print_error "Failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND"' ERR

main() {
  show_uninstall_banner

  if ! require_macos_uninstall; then
    exit 1
  fi

  local parse_status=0
  parse_uninstall_args "$@" || parse_status=$?
  if [[ "$parse_status" -eq 2 ]]; then
    exit 0
  fi
  if [[ "$parse_status" -ne 0 ]]; then
    exit 1
  fi

  if ! validate_uninstall_drive_option; then
    exit 1
  fi

  announce_dry_run
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
