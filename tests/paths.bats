#!/usr/bin/env bats

@test "add_to_path adds existing directory" {
  source "$BATS_TEST_DIRNAME/../zsh/.zsh/paths.zsh"

  mkdir -p "$BATS_TEST_TMPDIR/testbin"
  OLD_PATH="$PATH"
  add_to_path "$BATS_TEST_TMPDIR/testbin"

  [[ "$PATH" == "$BATS_TEST_TMPDIR/testbin:"* ]]
}

@test "add_to_path skips non-existent directory" {
  source "$BATS_TEST_DIRNAME/../zsh/.zsh/paths.zsh"

  OLD_PATH="$PATH"
  add_to_path "/nonexistent/path/12345"

  [[ "$PATH" == "$OLD_PATH" ]]
}

@test "add_to_path skips duplicate" {
  source "$BATS_TEST_DIRNAME/../zsh/.zsh/paths.zsh"

  mkdir -p "$BATS_TEST_TMPDIR/testbin"
  add_to_path "$BATS_TEST_TMPDIR/testbin"
  FIRST_PATH="$PATH"
  add_to_path "$BATS_TEST_TMPDIR/testbin"

  [[ "$PATH" == "$FIRST_PATH" ]]
}
