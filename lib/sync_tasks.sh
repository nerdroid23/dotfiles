#!/usr/bin/env bash

# Sync phase functions for sync.sh.
# Expected globals from caller:
#   DOTFILES, DRY_RUN
# Shared helpers expected from lib/common.sh:
#   print_*, run

show_sync_banner() {
  echo -e "${BOLD}"
  echo "  +--------------------------------+"
  echo "  |         dotfiles sync          |"
  echo "  +--------------------------------+"
  echo -e "${RESET}"
}

validate_sync_repo_root() {
  local script_root repo_root

  script_root="$(cd "$DOTFILES" && pwd -P)"
  repo_root="$(git -C "$DOTFILES" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "$repo_root" ]]; then
    print_error "Could not determine git repo root for $DOTFILES"
    return 1
  fi
  repo_root="$(cd "$repo_root" && pwd -P)"

  if [[ "$repo_root" != "$script_root" ]]; then
    print_error "sync.sh must live at the repository root."
    print_error "  Script dir: $script_root"
    print_error "  Git root:   $repo_root"
    return 1
  fi
}

run_sync_preflight_checks() {
  print_header "Preflight checks"

  if ! command -v git &>/dev/null; then
    print_error "git is required"
    return 1
  fi
  print_ok "git"

  if ! command -v brew &>/dev/null; then
    print_error "Homebrew is required (brew not found)"
    return 1
  fi
  print_ok "Homebrew"

  if ! command -v mackup &>/dev/null; then
    print_error "Mackup is required (mackup not found)"
    return 1
  fi
  print_ok "Mackup"

  if [[ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
    print_warn "iCloud Drive not ready - Mackup backup may fail"
  else
    print_ok "iCloud Drive"
  fi
}

sync_brewfile() {
  print_header "Brewfile"
  print_step "Updating Brewfile from installed Homebrew packages..."
  run brew bundle dump --force --file="$DOTFILES/Brewfile"
  print_ok "Brewfile updated"
}

sync_mackup_backup() {
  print_header "Mackup"
  print_step "Running mackup backup --force..."
  run mackup backup --force
  print_ok "Mackup backup complete"
}

show_sync_git_changes() {
  local suggested_date
  suggested_date="$(date +%Y-%m-%d)"

  print_header "Git changes"
  print_step "git status --short"
  git -C "$DOTFILES" --no-pager status --short
  echo ""

  print_step "git diff --stat"
  git -C "$DOTFILES" --no-pager diff --stat
  echo ""

  echo "  Suggested next commands:"
  echo "   git add -A"
  echo "   git commit -m \"sync: $suggested_date\""
  echo "   git push"
}

print_sync_done() {
  echo -e "\n${BOLD}${GREEN}  Sync complete!${RESET}"
  echo ""
  if [[ "$DRY_RUN" == true ]]; then
    echo "  This was a dry run - no changes were made."
    echo ""
  fi
}
