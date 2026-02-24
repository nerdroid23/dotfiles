#!/usr/bin/env bash

# CLI parsing for uninstall.sh

usage_uninstall() {
  echo "Usage: $0 [--drive /Volumes/NAME]"
}

cli_uninstall_print_error() {
  if declare -f print_error >/dev/null 2>&1; then
    print_error "$1"
  else
    echo "error $1" >&2
  fi
}

parse_uninstall_args() {
  DRIVE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drive)
        if [[ $# -lt 2 ]]; then
          cli_uninstall_print_error "--drive requires a path, e.g. --drive /Volumes/MillenniumFalcon"
          usage_uninstall
          return 1
        fi
        DRIVE="$2"
        shift 2
        ;;
      *)
        cli_uninstall_print_error "Unknown argument: $1"
        usage_uninstall
        return 1
        ;;
    esac
  done
}
