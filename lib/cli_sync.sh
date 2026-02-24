#!/usr/bin/env bash

# CLI parsing for sync.sh

usage_sync() {
  echo "Usage: $0 [--dry-run]"
}

cli_sync_print_error() {
  if declare -f print_error >/dev/null 2>&1; then
    print_error "$1"
  else
    echo "error $1" >&2
  fi
}

parse_sync_args() {
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        cli_sync_print_error "Unknown argument: $1"
        usage_sync
        return 1
        ;;
    esac
  done
}
