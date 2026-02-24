#!/usr/bin/env bash
# Drive migration helpers for install.sh
# Sourceable library with testable functions
#
# Required globals (set by caller):
#   DRY_RUN - "true" or "false"
#   RED, GREEN, YELLOW, BLUE, BOLD, RESET - color codes (optional, defaults provided)
#
# Functions:
#   validate_drive_path <drive> <allow_non_volumes>
#   path_is_nonempty_dir <path>
#   setup_symlink_safe <src> <dst> <label>

# Provide color defaults if not set (for testing)
: "${RED:=\033[0;31m}"
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[1;33m}"
: "${BLUE:=\033[0;34m}"
: "${BOLD:=\033[1m}"
: "${RESET:=\033[0m}"
: "${DRY_RUN:=false}"

# Output helpers (can be overridden by caller)
if ! declare -f print_step &>/dev/null; then
  print_step()   { echo -e "  ${YELLOW}*${RESET} $1"; }
fi
if ! declare -f print_ok &>/dev/null; then
  print_ok()     { echo -e "  ${GREEN}ok${RESET} $1"; }
fi
if ! declare -f print_skip &>/dev/null; then
  print_skip()   { echo -e "  ${BLUE}skip${RESET} $1 (already done)"; }
fi
if ! declare -f print_error &>/dev/null; then
  print_error()  { echo -e "  ${RED}error${RESET} $1" >&2; }
fi
if ! declare -f print_warn &>/dev/null; then
  print_warn()   { echo -e "  ${YELLOW}warn${RESET} $1"; }
fi

# ==============================================================================
# validate_drive_path <drive> <allow_non_volumes>
# ==============================================================================
# Validates that the drive path is suitable for external drive migration.
#
# Arguments:
#   $1 - drive path
#   $2 - "true" to allow non-/Volumes paths, "false" otherwise
#
# Returns:
#   0 - valid
#   1 - invalid (error message printed to stderr)
#
validate_drive_path() {
  local drive="${1:-}"
  local allow_non_volumes="${2:-false}"

  if [[ -z "$drive" ]]; then
    print_error "Drive path cannot be empty"
    return 1
  fi

  if [[ ! -e "$drive" ]]; then
    print_error "Drive not found: $drive"
    print_error "Make sure the drive is mounted before running with --drive."
    return 1
  fi

  if [[ ! -d "$drive" ]]; then
    print_error "Drive path is not a directory: $drive"
    return 1
  fi

  if [[ ! -w "$drive" ]]; then
    print_error "Drive path is not writable: $drive"
    print_error "Check that you have write permissions on the drive."
    return 1
  fi

  # Check /Volumes/* requirement unless overridden
  if [[ "$allow_non_volumes" != "true" ]]; then
    if [[ ! "$drive" =~ ^/Volumes/[^/]+ ]]; then
      print_error "Drive path must be under /Volumes/: $drive"
      print_error "Use --allow-non-volumes-drive if you intentionally want a non-/Volumes path."
      return 1
    fi
  fi

  return 0
}

# ==============================================================================
# path_is_nonempty_dir <path>
# ==============================================================================
# Checks if a path exists as a directory with content.
#
# Arguments:
#   $1 - path to check
#
# Returns:
#   0 - path is a non-empty directory
#   1 - path doesn't exist, is not a directory, or is empty
#
path_is_nonempty_dir() {
  local path="$1"

  # Expand ~ manually
  path="${path/#\~/$HOME}"

  [[ -d "$path" ]] || return 1
  [[ -n "$(ls -A "$path" 2>/dev/null)" ]] || return 1
  return 0
}

# ==============================================================================
# setup_symlink_safe <src> <dst> <label>
# ==============================================================================
# Safely sets up a symlink from src to dst for fresh setups.
#
# Handles exactly 6 states:
#   1. Symlink to correct dst     -> Skip (idempotent)
#   2. Wrong/broken symlink       -> Error + abort
#   3. src exists, dst missing    -> Move + link (fresh setup)
#   4. src missing, dst exists    -> Error + abort (include fix command)
#   5. Both missing               -> Create dst + link (fresh setup)
#   6. Both exist                 -> Error + abort
#
# Arguments:
#   $1 - source path (local path that will become symlink)
#   $2 - destination path (on external drive)
#   $3 - human-readable label
#
# Returns:
#   0 - success
#   1 - aborted (preexisting state)
#
setup_symlink_safe() {
  local src="$1"
  local dst="$2"
  local label="$3"

  # Expand ~ manually
  src="${src/#\~/$HOME}"
  dst="${dst/#\~/$HOME}"

  # Normalize dst to remove trailing slashes for consistent comparison
  dst="${dst%/}"

  # --------------------------------------------------------------------------
  # Case: src is a symlink
  # --------------------------------------------------------------------------
  if [[ -L "$src" ]]; then
    local current_target
    current_target="$(readlink "$src" 2>/dev/null || true)"
    # Normalize for comparison
    current_target="${current_target%/}"

    if [[ "$current_target" == "$dst" ]]; then
      # State 1: Correctly symlinked - skip (idempotent)
      print_skip "$label (already symlinked)"
      return 0
    else
      # State 2: Wrong or broken symlink - fail fast
      echo "" >&2
      print_error "Drive setup is for fresh setups only." >&2
      if [[ -e "$src" ]]; then
        print_error "Found symlink pointing to wrong location: $src" >&2
        print_error "  Current target: $current_target" >&2
        print_error "  Expected target: $dst" >&2
      else
        print_error "Found broken symlink: $src" >&2
        print_error "  Points to: $current_target (does not exist)" >&2
      fi
      print_error "Resolve manually, then rerun: ./install.sh --drive <path>" >&2
      print_error "  Fix: ln -sfn \"$dst\" \"$src\"" >&2
      return 1
    fi
  fi

  # --------------------------------------------------------------------------
  # Case: src is not a symlink (or doesn't exist)
  # --------------------------------------------------------------------------
  local src_exists=false
  local dst_exists=false

  [[ -e "$src" ]] && src_exists=true
  [[ -e "$dst" ]] && dst_exists=true

  # --------------------------------------------------------------------------
  # State 6: Both exist (any combo: empty/non-empty) - fail fast
  # --------------------------------------------------------------------------
  if [[ "$src_exists" == "true" && "$dst_exists" == "true" ]]; then
    echo "" >&2
    print_error "Drive setup is for fresh setups only." >&2
    print_error "Found preexisting state: both paths exist" >&2
    print_error "  Local: $src" >&2
    print_error "  Drive: $dst" >&2
    print_error "Choose one as source of truth, remove the other, then rerun." >&2
    print_error "Resolve manually, then rerun: ./install.sh --drive <path>" >&2
    return 1
  fi

  # --------------------------------------------------------------------------
  # State 3: src exists, dst missing - move + link (fresh setup)
  # --------------------------------------------------------------------------
  if [[ "$src_exists" == "true" && "$dst_exists" == "false" ]]; then
    print_step "Moving $label to drive..."
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} mkdir -p \"$(dirname "$dst")\""
      echo -e "  ${YELLOW}[dry-run]${RESET} mv \"$src\" \"$dst\""
      echo -e "  ${YELLOW}[dry-run]${RESET} ln -sfn \"$dst\" \"$src\""
    else
      mkdir -p "$(dirname "$dst")"
      mv "$src" "$dst"
      ln -sfn "$dst" "$src"
    fi
    print_ok "$label -> $dst"
    return 0
  fi

  # --------------------------------------------------------------------------
  # State 4: src missing, dst exists - fail fast (include fix command)
  # --------------------------------------------------------------------------
  if [[ "$src_exists" == "false" && "$dst_exists" == "true" ]]; then
    echo "" >&2
    print_error "Drive setup is for fresh setups only." >&2
    print_error "Found preexisting state: drive path exists but local symlink missing" >&2
    print_error "  Drive path exists: $dst" >&2
    print_error "  Local path missing: $src" >&2
    print_error "Resolve manually, then rerun: ./install.sh --drive <path>" >&2
    print_error "  Fix: ln -sfn \"$dst\" \"$src\"" >&2
    return 1
  fi

  # --------------------------------------------------------------------------
  # State 5: Both missing - create dst + link (fresh setup)
  # --------------------------------------------------------------------------
  if [[ "$src_exists" == "false" && "$dst_exists" == "false" ]]; then
    print_step "Setting up $label (fresh)..."
    if [[ "$DRY_RUN" == "true" ]]; then
      echo -e "  ${YELLOW}[dry-run]${RESET} mkdir -p \"$dst\""
      echo -e "  ${YELLOW}[dry-run]${RESET} mkdir -p \"$(dirname "$src")\""
      echo -e "  ${YELLOW}[dry-run]${RESET} ln -sfn \"$dst\" \"$src\""
    else
      mkdir -p "$dst"
      mkdir -p "$(dirname "$src")"
      ln -sfn "$dst" "$src"
    fi
    print_ok "$label -> $dst"
    return 0
  fi

  # Shouldn't reach here, but handle gracefully
  print_error "$label: Unexpected state. src=$src, dst=$dst"
  return 1
}
