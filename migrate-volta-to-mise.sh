#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"
# shellcheck source=lib/cli_migrate.sh
source "$DOTFILES/lib/cli_migrate.sh"
# shellcheck source=lib/migrate_tasks.sh
source "$DOTFILES/lib/migrate_tasks.sh"

trap 'print_error "Failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND"' ERR

main() {
  local parse_status=0

  show_migrate_banner

  parse_migrate_args "$@" || parse_status=$?
  if [[ "$parse_status" -eq 2 ]]; then
    exit 0
  fi
  if [[ "$parse_status" -ne 0 ]]; then
    exit 1
  fi

  announce_dry_run

  if ! run_migrate_preflight_checks; then
    exit 1
  fi

  detect_current_tool_versions

  if ! confirm_migration_plan; then
    exit 1
  fi

  install_or_verify_mise
  activate_mise_for_current_run
  ensure_mise_shell_hook_in_local_zshrc
  install_runtimes_with_mise
  setup_corepack_package_managers
  install_tldr_with_brew_if_missing
  reinstall_volta_global_clis_under_mise_node
  verify_post_migration
  print_next_steps_keep_volta

  echo -e "\n${BOLD}${GREEN}  Migration complete!${RESET}\n"
}

main "$@"
