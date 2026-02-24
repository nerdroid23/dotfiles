#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"
# shellcheck source=lib/cli_install.sh
source "$DOTFILES/lib/cli_install.sh"
# shellcheck source=lib/install_drive.sh
source "$DOTFILES/lib/install_drive.sh"
# shellcheck source=lib/install_tasks.sh
source "$DOTFILES/lib/install_tasks.sh"

# Error handling
trap 'print_error "Failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND"' ERR

main() {
  show_install_banner

  if ! require_macos_install; then
    exit 1
  fi

  if ! parse_install_args "$@"; then
    exit 1
  fi

  if ! validate_drive_option; then
    exit 1
  fi

  announce_dry_run
  create_hushlogin
  run_preflight_checks
  install_homebrew
  install_oh_my_zsh
  run_brew_bundle
  install_laravel_valet
  stow_dotfiles
  setup_git_identity_files
  create_project_directories

  if ! setup_external_drive_symlinks; then
    exit 1
  fi

  snapshot_macos_defaults
  apply_macos_defaults
  run_mackup_restore
  create_local_overrides_file
  print_install_done
}

main "$@"
