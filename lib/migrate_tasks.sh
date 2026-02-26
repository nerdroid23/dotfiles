#!/usr/bin/env bash

# Migration phase functions for migrate-volta-to-mise.sh.
# Expected globals from caller:
#   DRY_RUN, ASSUME_YES, NODE_VERSION, BUN_VERSION
# Shared helpers expected from lib/common.sh:
#   print_*, run

HAS_VOLTA=false
MIGRATE_NODE_VERSION=""
MIGRATE_BUN_VERSION=""
MIGRATE_YARN_VERSION=""
MIGRATE_PNPM_VERSION=""
MIGRATE_REINSTALL_PACKAGES=()
MIGRATE_FAILED_PACKAGES=()

show_migrate_banner() {
  echo -e "${BOLD}"
  echo "  +--------------------------------------+"
  echo "  |      volta to mise migration         |"
  echo "  +--------------------------------------+"
  echo -e "${RESET}"
}

sanitize_version() {
  local value="$1"
  value="${value#v}"
  echo "$value"
}

add_unique_package() {
  local pkg="$1"
  local existing
  for existing in "${MIGRATE_REINSTALL_PACKAGES[@]}"; do
    if [[ "$existing" == "$pkg" ]]; then
      return 0
    fi
  done
  MIGRATE_REINSTALL_PACKAGES+=("$pkg")
}

collect_volta_global_packages() {
  local line spec

  if [[ "$HAS_VOLTA" != true ]]; then
    return 0
  fi

  while IFS= read -r line; do
    case "$line" in
      package\ *)
        spec="$(echo "$line" | awk '{print $2}')"
        case "$spec" in
          bun@*|pnpm@*|tldr@*|yarn@*)
            continue
            ;;
        esac
        add_unique_package "$spec"
        ;;
    esac
  done < <(volta list)
}

run_migrate_preflight_checks() {
  print_header "Preflight checks"

  if ! command -v brew &>/dev/null; then
    print_error "Homebrew is required (brew not found)"
    return 1
  fi
  print_ok "Homebrew"

  if ! command -v git &>/dev/null; then
    print_error "git is required"
    return 1
  fi
  print_ok "git"

  if command -v volta &>/dev/null; then
    HAS_VOLTA=true
    print_ok "Volta"
  else
    HAS_VOLTA=false
    print_warn "Volta not found - global package import will be skipped"
  fi

  if command -v mise &>/dev/null; then
    print_ok "mise ($(mise --version))"
  else
    print_warn "mise not found - it will be installed with Homebrew"
  fi
}

detect_current_tool_versions() {
  local raw

  print_header "Detecting current versions"

  if [[ -n "$NODE_VERSION" ]]; then
    MIGRATE_NODE_VERSION="$(sanitize_version "$NODE_VERSION")"
  elif command -v node &>/dev/null; then
    MIGRATE_NODE_VERSION="$(sanitize_version "$(node -v 2>/dev/null || true)")"
  elif [[ "$HAS_VOLTA" == true ]]; then
    raw="$(volta list | awk '/^runtime node@/ {print $2; exit}')"
    MIGRATE_NODE_VERSION="${raw#node@}"
  fi
  [[ -n "$MIGRATE_NODE_VERSION" ]] || MIGRATE_NODE_VERSION="24"

  if [[ -n "$BUN_VERSION" ]]; then
    MIGRATE_BUN_VERSION="$(sanitize_version "$BUN_VERSION")"
  elif command -v bun &>/dev/null; then
    MIGRATE_BUN_VERSION="$(sanitize_version "$(bun --version 2>/dev/null || true)")"
  elif [[ "$HAS_VOLTA" == true ]]; then
    raw="$(volta list | awk '/^package bun@/ {print $2; exit}')"
    raw="${raw#bun@}"
    if [[ -n "$raw" ]]; then
      MIGRATE_BUN_VERSION="$raw"
    fi
  fi
  [[ -n "$MIGRATE_BUN_VERSION" ]] || MIGRATE_BUN_VERSION="latest"

  if command -v yarn &>/dev/null; then
    MIGRATE_YARN_VERSION="$(sanitize_version "$(yarn -v 2>/dev/null || true)")"
  elif [[ "$HAS_VOLTA" == true ]]; then
    raw="$(volta list | awk '/^package-manager yarn@/ {print $2; exit}')"
    MIGRATE_YARN_VERSION="${raw#yarn@}"
  fi
  [[ -n "$MIGRATE_YARN_VERSION" ]] || MIGRATE_YARN_VERSION="1.22.22"

  if command -v pnpm &>/dev/null; then
    MIGRATE_PNPM_VERSION="$(sanitize_version "$(pnpm -v 2>/dev/null || true)")"
  elif [[ "$HAS_VOLTA" == true ]]; then
    raw="$(volta list | awk '/^package pnpm@/ {print $2; exit}')"
    MIGRATE_PNPM_VERSION="${raw#pnpm@}"
  fi
  [[ -n "$MIGRATE_PNPM_VERSION" ]] || MIGRATE_PNPM_VERSION="10.15.0"

  collect_volta_global_packages

  print_step "Node: $MIGRATE_NODE_VERSION"
  print_step "Bun: $MIGRATE_BUN_VERSION"
  print_step "Yarn: $MIGRATE_YARN_VERSION"
  print_step "pnpm: $MIGRATE_PNPM_VERSION"

  if brew list tldr &>/dev/null; then
    print_step "tldr: already installed via Homebrew"
  else
    print_step "tldr: will install via Homebrew"
  fi

  if [[ ${#MIGRATE_REINSTALL_PACKAGES[@]} -gt 0 ]]; then
    print_step "npm globals to reinstall under mise Node:"
    local pkg
    for pkg in "${MIGRATE_REINSTALL_PACKAGES[@]}"; do
      echo "    - $pkg"
    done
  else
    print_step "No Volta npm globals found for reinstall"
  fi
}

confirm_migration_plan() {
  local answer

  if [[ "$DRY_RUN" == true || "$ASSUME_YES" == true ]]; then
    return 0
  fi

  echo ""
  read -rp "  Continue with migration? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    print_warn "Migration aborted"
    return 1
  fi
}

install_or_verify_mise() {
  print_header "mise"

  if command -v mise &>/dev/null; then
    print_skip "mise"
    return 0
  fi

  print_step "Installing mise with Homebrew..."
  run brew install mise
  print_ok "mise installed"
}

activate_mise_for_current_run() {
  print_header "mise activation"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} eval \"\$(mise activate zsh)\""
    return 0
  fi

  if ! command -v mise &>/dev/null; then
    print_error "mise command not found after install"
    return 1
  fi

  eval "$(mise activate zsh)"
  print_ok "mise activated for this script run"
}

ensure_mise_shell_hook_in_local_zshrc() {
  local local_zshrc hook

  print_header "Shell hook"

  local_zshrc="$HOME/.zshrc.local"
  hook='eval "$(mise activate zsh)"'

  if [[ -f "$local_zshrc" ]] && grep -Fq "$hook" "$local_zshrc"; then
    print_skip "~/.zshrc.local mise hook"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} Would ensure $hook exists in $local_zshrc"
    return 0
  fi

  {
    echo ""
    echo "# Activate mise"
    echo "$hook"
  } >> "$local_zshrc"

  print_ok "Added mise activation to $local_zshrc"
}

install_runtimes_with_mise() {
  print_header "Runtimes"

  print_step "Installing Node via mise..."
  run mise use -g "node@$MIGRATE_NODE_VERSION"

  print_step "Installing Bun via mise..."
  run mise use -g "bun@$MIGRATE_BUN_VERSION"

  print_ok "Node and Bun configured via mise"
}

setup_corepack_package_managers() {
  print_header "Corepack"

  print_step "Enabling Corepack..."
  run mise exec -- corepack enable

  print_step "Activating Yarn@$MIGRATE_YARN_VERSION..."
  run mise exec -- corepack prepare "yarn@$MIGRATE_YARN_VERSION" --activate

  print_step "Activating pnpm@$MIGRATE_PNPM_VERSION..."
  run mise exec -- corepack prepare "pnpm@$MIGRATE_PNPM_VERSION" --activate

  print_ok "Yarn and pnpm configured via Corepack"
}

install_tldr_with_brew_if_missing() {
  print_header "tldr"

  if brew list tldr &>/dev/null; then
    print_skip "tldr (Homebrew)"
    return 0
  fi

  print_step "Installing tldr via Homebrew..."
  run brew install tldr
  print_ok "tldr installed via Homebrew"
}

reinstall_volta_global_clis_under_mise_node() {
  local pkg

  print_header "npm globals"

  if [[ ${#MIGRATE_REINSTALL_PACKAGES[@]} -eq 0 ]]; then
    print_skip "npm globals reinstall"
    return 0
  fi

  for pkg in "${MIGRATE_REINSTALL_PACKAGES[@]}"; do
    print_step "Installing $pkg under mise Node..."
    if [[ "$DRY_RUN" == true ]]; then
      run mise exec -- npm install -g "$pkg"
    else
      if ! mise exec -- npm install -g "$pkg"; then
        MIGRATE_FAILED_PACKAGES+=("$pkg")
        print_warn "Failed to install $pkg (continuing)"
      fi
    fi
  done

  if [[ ${#MIGRATE_FAILED_PACKAGES[@]} -gt 0 ]]; then
    print_warn "Some npm globals failed to install"
  else
    print_ok "npm globals installed under mise Node"
  fi
}

verify_post_migration() {
  print_header "Verification"

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${RESET} Skipping runtime checks"
    return 0
  fi

  print_step "mise node: $(mise exec -- node -v)"
  print_step "mise npm: $(mise exec -- npm -v)"
  print_step "mise bun: $(mise exec -- bun --version)"
  print_step "mise yarn: $(mise exec -- yarn -v)"
  print_step "mise pnpm: $(mise exec -- pnpm -v)"

  if command -v tldr &>/dev/null; then
    print_step "tldr: $(tldr --version 2>/dev/null | head -n 1)"
  else
    print_warn "tldr command not found in PATH"
  fi

  if mise exec -- which codex >/dev/null 2>&1; then
    print_step "codex: $(mise exec -- codex --version 2>/dev/null | head -n 1)"
  fi

  if mise exec -- which gemini >/dev/null 2>&1; then
    print_step "gemini: $(mise exec -- gemini --version 2>/dev/null | head -n 1)"
  fi

  if mise exec -- which amp >/dev/null 2>&1; then
    print_step "amp: $(mise exec -- amp --version 2>/dev/null | head -n 1)"
  fi
}

print_next_steps_keep_volta() {
  print_header "Next steps"

  echo "  Volta is intentionally still installed for fallback."
  echo "  Open a new terminal and verify your workflows (codex, gemini, amp, pnpm, yarn)."

  if [[ ${#MIGRATE_FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo ""
    echo "  npm globals that failed (reinstall manually):"
    local pkg
    for pkg in "${MIGRATE_FAILED_PACKAGES[@]}"; do
      echo "   - $pkg"
    done
  fi

  echo ""
  echo "  When you are ready, you can later remove Volta manually:"
  echo "   1. Remove or comment out ~/.volta/bin PATH wiring"
  echo "   2. Uninstall Volta"
  echo "   3. Delete ~/.volta"
}
