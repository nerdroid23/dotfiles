#!/usr/bin/env bats

load test_helper

# ==============================================================================
# sanitize_version tests
# ==============================================================================

@test "sanitize_version strips v prefix" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    sanitize_version "v24.13.0"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "24.13.0" ]
}

@test "sanitize_version passes through plain version" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    sanitize_version "24.13.0"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "24.13.0" ]
}

@test "sanitize_version handles latest" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    sanitize_version "latest"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "latest" ]
}

@test "sanitize_version handles empty string" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    sanitize_version ""
  '
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ==============================================================================
# add_unique_package tests
# ==============================================================================

@test "add_unique_package adds new package" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    MIGRATE_REINSTALL_PACKAGES=()
    add_unique_package "codex@1.0.0"
    echo "${#MIGRATE_REINSTALL_PACKAGES[@]}:${MIGRATE_REINSTALL_PACKAGES[0]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "1:codex@1.0.0" ]
}

@test "add_unique_package deduplicates" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    MIGRATE_REINSTALL_PACKAGES=("codex@1.0.0")
    add_unique_package "codex@1.0.0"
    echo "${#MIGRATE_REINSTALL_PACKAGES[@]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "add_unique_package adds different packages" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
    MIGRATE_REINSTALL_PACKAGES=("codex@1.0.0")
    add_unique_package "gemini@2.0.0"
    echo "${#MIGRATE_REINSTALL_PACKAGES[@]}:${MIGRATE_REINSTALL_PACKAGES[1]}"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "2:gemini@2.0.0" ]
}
