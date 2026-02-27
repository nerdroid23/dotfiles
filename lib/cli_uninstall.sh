#!/usr/bin/env bash

# CLI parsing for uninstall.sh

usage_uninstall() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --drive PATH    Reverse external drive symlinks (e.g., --drive /Volumes/MyDrive)
  --dry-run       Preview actions without making changes
  -h, --help      Show this help
USAGE
}


parse_uninstall_args() {
  DRIVE=""
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --drive)
        if [[ $# -lt 2 ]]; then
          echo "error: --drive requires a path, e.g. --drive /Volumes/MillenniumFalcon" >&2
          usage_uninstall
          return 1
        fi
        DRIVE="$2"
        shift 2
        ;;
      -h|--help)
        usage_uninstall
        return 2
        ;;
      *)
        echo "error: Unknown argument: $1" >&2
        usage_uninstall
        return 1
        ;;
    esac
  done
}
