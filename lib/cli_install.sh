#!/usr/bin/env bash

# CLI parsing for install.sh

usage_install() {
  echo "Usage: $0 [--drive PATH] [--dry-run]"
}

cli_install_print_error() {
  if declare -f print_error >/dev/null 2>&1; then
    print_error "$1"
  else
    echo "error $1" >&2
  fi
}

parse_install_args() {
  DRIVE=""
  ALLOW_NON_VOLUMES_DRIVE=false
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drive)
        if [[ $# -lt 2 ]]; then
          cli_install_print_error "--drive requires a path, e.g. --drive /Volumes/MillenniumFalcon"
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
      *)
        cli_install_print_error "Unknown argument: $1"
        usage_install
        return 1
        ;;
    esac
  done
}
