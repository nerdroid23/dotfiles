#!/usr/bin/env bats

load test_helper

# Source the helper library for testing
setup() {
  TEST_TMP="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_TMP"

  # Create a fake HOME for isolation
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"

  # Set DRY_RUN to false by default (tests can override)
  export DRY_RUN=false

  # Source the library
  source "$BATS_TEST_DIRNAME/../lib/install_drive.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ==============================================================================
# validate_drive_path tests
# ==============================================================================

@test "validate_drive_path accepts writable /Volumes path" {
  mkdir -p "$TEST_TMP/Volumes/TestDrive"
  chmod 755 "$TEST_TMP/Volumes/TestDrive"

  # Mock /Volumes check by using allow_non_volumes=true and a real writable dir
  # For true /Volumes test, we check pattern matching separately
  run validate_drive_path "$TEST_TMP/Volumes/TestDrive" "true"
  [ "$status" -eq 0 ]
}

@test "validate_drive_path rejects non-existent path" {
  run validate_drive_path "/nonexistent/path/12345" "false"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "validate_drive_path rejects non-directory path" {
  touch "$TEST_TMP/notadir"
  run validate_drive_path "$TEST_TMP/notadir" "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a directory"* ]]
}

@test "validate_drive_path rejects non-writable path" {
  mkdir -p "$TEST_TMP/readonly"
  chmod 000 "$TEST_TMP/readonly"

  run validate_drive_path "$TEST_TMP/readonly" "true"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not writable"* ]]

  # Cleanup - restore permissions so teardown can delete
  chmod 755 "$TEST_TMP/readonly"
}

@test "validate_drive_path rejects non-/Volumes path by default" {
  mkdir -p "$TEST_TMP/somepath"
  run validate_drive_path "$TEST_TMP/somepath" "false"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be under /Volumes/"* ]]
}

@test "validate_drive_path accepts non-/Volumes path with override flag" {
  mkdir -p "$TEST_TMP/somepath"
  run validate_drive_path "$TEST_TMP/somepath" "true"
  [ "$status" -eq 0 ]
}

@test "validate_drive_path rejects empty path" {
  run validate_drive_path "" "false"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot be empty"* ]]
}

# ==============================================================================
# path_is_nonempty_dir tests
# ==============================================================================

@test "path_is_nonempty_dir returns true for directory with content" {
  mkdir -p "$TEST_TMP/hasdata"
  touch "$TEST_TMP/hasdata/file.txt"

  run path_is_nonempty_dir "$TEST_TMP/hasdata"
  [ "$status" -eq 0 ]
}

@test "path_is_nonempty_dir returns false for empty directory" {
  mkdir -p "$TEST_TMP/emptydir"

  run path_is_nonempty_dir "$TEST_TMP/emptydir"
  [ "$status" -eq 1 ]
}

@test "path_is_nonempty_dir returns false for non-existent path" {
  run path_is_nonempty_dir "$TEST_TMP/nonexistent"
  [ "$status" -eq 1 ]
}

@test "path_is_nonempty_dir returns false for file" {
  touch "$TEST_TMP/afile"

  run path_is_nonempty_dir "$TEST_TMP/afile"
  [ "$status" -eq 1 ]
}

@test "path_is_nonempty_dir expands tilde" {
  mkdir -p "$HOME/testdir"
  touch "$HOME/testdir/file.txt"

  run path_is_nonempty_dir "~/testdir"
  [ "$status" -eq 0 ]
}

# ==============================================================================
# setup_symlink_safe tests - Fresh setup cases
# ==============================================================================

@test "setup_symlink_safe: fresh setup moves src to dst and creates symlink" {
  local src="$HOME/.testapp"
  local dst="$TEST_TMP/drive/TestApp"

  # Create source with data
  mkdir -p "$src"
  echo "data" > "$src/config.txt"

  run setup_symlink_safe "$src" "$dst" "TestApp"
  [ "$status" -eq 0 ]

  # src should be a symlink pointing to dst
  [ -L "$src" ]
  [ "$(readlink "$src")" = "$dst" ]

  # dst should have the moved data
  [ -f "$dst/config.txt" ]
  [ "$(cat "$dst/config.txt")" = "data" ]
}

@test "setup_symlink_safe: fresh setup with missing src creates dst and symlink" {
  local src="$HOME/.newapp"
  local dst="$TEST_TMP/drive/NewApp"

  # Neither exists

  run setup_symlink_safe "$src" "$dst" "NewApp"
  [ "$status" -eq 0 ]

  # src should be a symlink
  [ -L "$src" ]
  [ "$(readlink "$src")" = "$dst" ]

  # dst should exist as a directory
  [ -d "$dst" ]
}

# ==============================================================================
# setup_symlink_safe tests - Idempotency / Rerun cases
# ==============================================================================

@test "setup_symlink_safe: already correctly symlinked skips" {
  local src="$HOME/.symlinked"
  local dst="$TEST_TMP/drive/Symlinked"

  mkdir -p "$dst"
  mkdir -p "$(dirname "$src")"
  ln -sfn "$dst" "$src"

  run setup_symlink_safe "$src" "$dst" "Symlinked"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]] || [[ "$output" == *"already symlinked"* ]]

  # Still a symlink to the right place
  [ -L "$src" ]
  [ "$(readlink "$src")" = "$dst" ]
}

# ==============================================================================
# setup_symlink_safe tests - Fail-fast cases (no prompts)
# ==============================================================================

@test "setup_symlink_safe: wrong symlink fails immediately" {
  local src="$HOME/.wronglink"
  local dst="$TEST_TMP/drive/Correct"
  local wrong_dst="$TEST_TMP/drive/Wrong"

  mkdir -p "$wrong_dst"
  mkdir -p "$(dirname "$src")"
  ln -sfn "$wrong_dst" "$src"

  run setup_symlink_safe "$src" "$dst" "WrongLink"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"wrong location"* ]]
  [[ "$output" == *"Fix: ln -sfn"* ]]

  # Should still point to wrong target (not changed)
  [ "$(readlink "$src")" = "$wrong_dst" ]
}

@test "setup_symlink_safe: broken symlink fails immediately" {
  local src="$HOME/.brokenlink"
  local dst="$TEST_TMP/drive/Target"
  local broken_target="$TEST_TMP/nonexistent/target"

  mkdir -p "$(dirname "$src")"
  ln -sfn "$broken_target" "$src"

  run setup_symlink_safe "$src" "$dst" "BrokenLink"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"broken symlink"* ]]
  [[ "$output" == *"Fix: ln -sfn"* ]]
}

@test "setup_symlink_safe: src missing + dst exists fails with fix command" {
  local src="$HOME/.missinglocal"
  local dst="$TEST_TMP/drive/ExistsOnDrive"

  # Only dst exists
  mkdir -p "$dst"
  echo "drive data" > "$dst/data.txt"

  run setup_symlink_safe "$src" "$dst" "MissingLocal"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"drive path exists but local symlink missing"* ]]
  [[ "$output" == *"Fix: ln -sfn"* ]]

  # src should not have been created
  [ ! -e "$src" ]
}

@test "setup_symlink_safe: both exist (empty dirs) aborts" {
  local src="$HOME/.bothempty"
  local dst="$TEST_TMP/drive/BothEmpty"

  # Both exist as empty directories
  mkdir -p "$src"
  mkdir -p "$dst"

  run setup_symlink_safe "$src" "$dst" "BothEmpty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"both paths exist"* ]]

  # Both should remain unchanged
  [ -d "$src" ]
  [ ! -L "$src" ]
  [ -d "$dst" ]
}

@test "setup_symlink_safe: both exist (src has data, dst empty) aborts" {
  local src="$HOME/.srchasdata"
  local dst="$TEST_TMP/drive/DstEmpty"

  # src has data, dst is empty
  mkdir -p "$src"
  echo "local data" > "$src/file.txt"
  mkdir -p "$dst"

  run setup_symlink_safe "$src" "$dst" "SrcHasData"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"both paths exist"* ]]

  # Both should remain unchanged
  [ -d "$src" ]
  [ ! -L "$src" ]
  [ -f "$src/file.txt" ]
}

@test "setup_symlink_safe: both exist (both have data) aborts" {
  local src="$HOME/.conflict"
  local dst="$TEST_TMP/drive/Conflict"

  # Both have data
  mkdir -p "$src"
  echo "local data" > "$src/local.txt"
  mkdir -p "$dst"
  echo "drive data" > "$dst/drive.txt"

  run setup_symlink_safe "$src" "$dst" "Conflict"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
  [[ "$output" == *"both paths exist"* ]]

  # Both should remain unchanged
  [ -d "$src" ]
  [ ! -L "$src" ]
  [ -f "$src/local.txt" ]
  [ -f "$dst/drive.txt" ]
}

@test "setup_symlink_safe: no nested dst/sdk when dst exists (regression test)" {
  local src="$HOME/Library/Android/sdk"
  local dst="$TEST_TMP/drive/Android/sdk"

  # Simulate: dst already exists with some content
  mkdir -p "$dst"
  echo "existing" > "$dst/platform-tools.txt"

  # And src has different content
  mkdir -p "$src"
  echo "local" > "$src/tools.txt"

  run setup_symlink_safe "$src" "$dst" "Android SDK"

  # Should fail immediately (both exist)
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]

  # CRITICAL: Verify no nested directory was created
  [ ! -e "$dst/sdk" ]
}

# ==============================================================================
# setup_symlink_safe tests - Paths with spaces
# ==============================================================================

@test "setup_symlink_safe: handles paths with spaces in src and dst" {
  local src="$HOME/Library/My App Data"
  local dst="$TEST_TMP/drive/My External App"

  mkdir -p "$src"
  echo "config" > "$src/settings.txt"

  run setup_symlink_safe "$src" "$dst" "My App"
  [ "$status" -eq 0 ]

  [ -L "$src" ]
  [ "$(readlink "$src")" = "$dst" ]
  [ -f "$dst/settings.txt" ]
}

# ==============================================================================
# setup_symlink_safe tests - Dry run mode
# ==============================================================================

@test "setup_symlink_safe: dry run does not modify filesystem" {
  export DRY_RUN=true

  local src="$HOME/.dryruntest"
  local dst="$TEST_TMP/drive/DryRun"

  mkdir -p "$src"
  echo "data" > "$src/file.txt"

  run setup_symlink_safe "$src" "$dst" "DryRun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]

  # src should still be a directory, not a symlink
  [ -d "$src" ]
  [ ! -L "$src" ]

  # dst should not exist
  [ ! -e "$dst" ]
}

@test "setup_symlink_safe: dry run on conflict still fails" {
  export DRY_RUN=true

  local src="$HOME/.dryconflict"
  local dst="$TEST_TMP/drive/DryConflict"

  mkdir -p "$src"
  echo "local" > "$src/local.txt"
  mkdir -p "$dst"
  echo "drive" > "$dst/drive.txt"

  run setup_symlink_safe "$src" "$dst" "DryConflict"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fresh setups only"* ]]
}

# ==============================================================================
# setup_symlink_safe tests - Edge cases
# ==============================================================================

@test "setup_symlink_safe: creates parent directories for src" {
  local src="$HOME/Deep/Nested/Path/.config"
  local dst="$TEST_TMP/drive/Config"

  # Neither exists - fresh setup

  run setup_symlink_safe "$src" "$dst" "DeepConfig"
  [ "$status" -eq 0 ]

  [ -L "$src" ]
  [ -d "$(dirname "$src")" ]
}

@test "setup_symlink_safe: creates parent directories for dst" {
  local src="$HOME/.simple"
  local dst="$TEST_TMP/drive/Deep/Nested/Target"

  mkdir -p "$src"
  echo "data" > "$src/file.txt"

  run setup_symlink_safe "$src" "$dst" "Simple"
  [ "$status" -eq 0 ]

  [ -L "$src" ]
  [ -d "$dst" ]
  [ -f "$dst/file.txt" ]
}
