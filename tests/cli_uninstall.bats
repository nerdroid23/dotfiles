#!/usr/bin/env bats

load test_helper

@test "uninstall cli libs can be sourced" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_uninstall.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
  '
  [ "$status" -eq 0 ]
}

@test "parse_uninstall_args sets defaults with no args" {
  source "$BATS_TEST_DIRNAME/../lib/cli_uninstall.sh"

  parse_uninstall_args

  [ "$DRIVE" = "" ]
  [ "$DRY_RUN" = "false" ]
}

@test "parse_uninstall_args parses drive" {
  source "$BATS_TEST_DIRNAME/../lib/cli_uninstall.sh"

  parse_uninstall_args --drive /Volumes/Test

  [ "$DRIVE" = "/Volumes/Test" ]
}

@test "parse_uninstall_args parses --dry-run" {
  source "$BATS_TEST_DIRNAME/../lib/cli_uninstall.sh"

  parse_uninstall_args --dry-run

  [ "$DRY_RUN" = "true" ]
}

@test "parse_uninstall_args returns 2 on --help" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_uninstall.sh"
    parse_uninstall_args --help
    exit $?
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "parse_uninstall_args rejects unknown argument" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_uninstall.sh"
    parse_uninstall_args --wat
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument: --wat"* ]]
  [[ "$output" == *"Usage:"* ]]
}
