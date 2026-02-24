#!/usr/bin/env bash

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"
# shellcheck source=lib/cli_sync.sh
source "$DOTFILES/lib/cli_sync.sh"
# shellcheck source=lib/sync_tasks.sh
source "$DOTFILES/lib/sync_tasks.sh"

trap 'print_error "Failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND"' ERR

main() {
  show_sync_banner

  if ! parse_sync_args "$@"; then
    exit 1
  fi

  if ! validate_sync_repo_root; then
    exit 1
  fi

  cd "$DOTFILES"

  announce_dry_run

  if ! run_sync_preflight_checks; then
    exit 1
  fi

  sync_brewfile
  sync_mackup_backup
  show_sync_git_changes
  print_sync_done
}

main "$@"
