#!/usr/bin/env bats

load test_helper

@test "install.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../install.sh"
}

@test "common.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/common.sh"
}

@test "cli_install.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/cli_install.sh"
}

@test "install_tasks.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/install_tasks.sh"
}

@test "cli_uninstall.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/cli_uninstall.sh"
}

@test "uninstall_tasks.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/uninstall_tasks.sh"
}

@test "cli_sync.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/cli_sync.sh"
}

@test "sync_tasks.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../lib/sync_tasks.sh"
}

@test "uninstall.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../uninstall.sh"
}

@test "sync.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../sync.sh"
}

@test "macos.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../macos.sh"
}
