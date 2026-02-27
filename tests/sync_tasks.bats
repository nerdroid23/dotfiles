#!/usr/bin/env bats

load test_helper

# ==============================================================================
# validate_sync_repo_root tests
# ==============================================================================

@test "validate_sync_repo_root accepts valid repo" {
  local fake_repo="$BATS_TEST_TMPDIR/dotfiles"
  mkdir -p "$fake_repo"
  git -C "$fake_repo" init --quiet

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/sync_tasks.sh"
    DOTFILES="'"$fake_repo"'"
    validate_sync_repo_root
  '
  [ "$status" -eq 0 ]
}

@test "validate_sync_repo_root rejects non-git directory" {
  local fake_dir="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$fake_dir"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/sync_tasks.sh"
    DOTFILES="'"$fake_dir"'"
    validate_sync_repo_root
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not determine git repo root"* ]]
}

@test "validate_sync_repo_root rejects subdirectory of repo" {
  local fake_repo="$BATS_TEST_TMPDIR/dotfiles"
  mkdir -p "$fake_repo/subdir"
  git -C "$fake_repo" init --quiet

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/sync_tasks.sh"
    DOTFILES="'"$fake_repo/subdir"'"
    validate_sync_repo_root
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"must live at the repository root"* ]]
}
