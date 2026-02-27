#!/usr/bin/env bash

# CLI parsing for migrate-volta-to-mise.sh

usage_migrate() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --dry-run               Preview actions without making changes
  --yes                   Run non-interactively (skip confirmation prompt)
  --node-version VERSION  Override Node version (e.g. 24.13.0)
  --bun-version VERSION   Override Bun version (e.g. 1.3.8 or latest)
  -h, --help              Show this help
USAGE
}


parse_migrate_args() {
  DRY_RUN=false
  ASSUME_YES=false
  NODE_VERSION=""
  BUN_VERSION=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --node-version)
        if [[ $# -lt 2 ]]; then
          echo "error: --node-version requires a version (e.g. 24.13.0)" >&2
          usage_migrate
          return 1
        fi
        NODE_VERSION="$2"
        shift 2
        ;;
      --bun-version)
        if [[ $# -lt 2 ]]; then
          echo "error: --bun-version requires a version (e.g. 1.3.8 or latest)" >&2
          usage_migrate
          return 1
        fi
        BUN_VERSION="$2"
        shift 2
        ;;
      -h|--help)
        usage_migrate
        return 2
        ;;
      *)
        echo "error: Unknown argument: $1" >&2
        usage_migrate
        return 1
        ;;
    esac
  done
}
