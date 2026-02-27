#!/usr/bin/env bats

load test_helper

@test "sync libs can be sourced" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_sync.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/sync_tasks.sh"
  '
  [ "$status" -eq 0 ]
}

@test "parse_sync_args sets defaults with no args" {
  source "$BATS_TEST_DIRNAME/../lib/cli_sync.sh"

  parse_sync_args

  [ "$DRY_RUN" = "false" ]
}

@test "parse_sync_args parses --dry-run" {
  source "$BATS_TEST_DIRNAME/../lib/cli_sync.sh"

  parse_sync_args --dry-run

  [ "$DRY_RUN" = "true" ]
}

@test "parse_sync_args returns 2 on --help" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_sync.sh"
    parse_sync_args --help
    exit $?
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "parse_sync_args rejects unknown argument" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_sync.sh"
    parse_sync_args --wat
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument: --wat"* ]]
  [[ "$output" == *"Usage:"* ]]
}
