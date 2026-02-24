#!/usr/bin/env bash

# Shared output helpers and small utilities for installer scripts.
# Sourceable library (no set -euo here).

: "${RED:=\033[0;31m}"
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${BLUE:=\033[0;34m}"
: "${BOLD:=\033[1m}"
: "${RESET:=\033[0m}"
: "${DRY_RUN:=false}"

print_header() { echo -e "\n${BOLD}${BLUE}==> $1${RESET}"; }
print_step()   { echo -e "  ${YELLOW}*${RESET} $1"; }
print_ok()     { echo -e "  ${GREEN}ok${RESET} $1"; }
print_skip()   { echo -e "  ${BLUE}skip${RESET} $1 (already done)"; }
print_error()  { echo -e "  ${RED}error${RESET} $1" >&2; }
print_warn()   { echo -e "  ${YELLOW}warn${RESET} $1"; }

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
