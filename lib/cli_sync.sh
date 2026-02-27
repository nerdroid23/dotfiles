#!/usr/bin/env bash

# CLI parsing for sync.sh

usage_sync() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --dry-run    Preview actions without making changes
  -h, --help   Show this help
USAGE
}


parse_sync_args() {
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage_sync
        return 2
        ;;
      *)
        echo "error: Unknown argument: $1" >&2
        usage_sync
        return 1
        ;;
    esac
  done
}
