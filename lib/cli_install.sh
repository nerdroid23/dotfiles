#!/usr/bin/env bash

# CLI parsing for install.sh

usage_install() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --drive PATH    Set up external drive symlinks (e.g., --drive /Volumes/MyDrive)
  --dry-run       Preview actions without making changes
  -h, --help      Show this help
USAGE
}


parse_install_args() {
  DRIVE=""
  ALLOW_NON_VOLUMES_DRIVE=false
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drive)
        if [[ $# -lt 2 ]]; then
          echo "error: --drive requires a path, e.g. --drive /Volumes/MillenniumFalcon" >&2
          usage_install
          return 1
        fi
        DRIVE="$2"
        shift 2
        ;;
      --allow-non-volumes-drive)
        ALLOW_NON_VOLUMES_DRIVE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        usage_install
        return 2
        ;;
      *)
        echo "error: Unknown argument: $1" >&2
        usage_install
        return 1
        ;;
    esac
  done
}
