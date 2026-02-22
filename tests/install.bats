#!/usr/bin/env bats

load test_helper

@test "install.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../install.sh"
}

@test "uninstall.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../uninstall.sh"
}

@test "macos.sh has valid syntax" {
  bash -n "$BATS_TEST_DIRNAME/../macos.sh"
}
