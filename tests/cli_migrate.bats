#!/usr/bin/env bats

load test_helper

@test "migrate libs can be sourced" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_migrate.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/migrate_tasks.sh"
  '
  [ "$status" -eq 0 ]
}

@test "parse_migrate_args sets defaults with no args" {
  source "$BATS_TEST_DIRNAME/../lib/cli_migrate.sh"

  parse_migrate_args

  [ "$DRY_RUN" = "false" ]
  [ "$ASSUME_YES" = "false" ]
  [ -z "$NODE_VERSION" ]
  [ -z "$BUN_VERSION" ]
}

@test "parse_migrate_args parses dry-run and yes flags" {
  source "$BATS_TEST_DIRNAME/../lib/cli_migrate.sh"

  parse_migrate_args --dry-run --yes

  [ "$DRY_RUN" = "true" ]
  [ "$ASSUME_YES" = "true" ]
}

@test "parse_migrate_args parses version overrides" {
  source "$BATS_TEST_DIRNAME/../lib/cli_migrate.sh"

  parse_migrate_args --node-version 24.13.0 --bun-version 1.3.8

  [ "$NODE_VERSION" = "24.13.0" ]
  [ "$BUN_VERSION" = "1.3.8" ]
}

@test "parse_migrate_args returns 2 on --help" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_migrate.sh"
    parse_migrate_args --help
    exit $?
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "parse_migrate_args rejects unknown argument" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_migrate.sh"
    parse_migrate_args --wat
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument: --wat"* ]]
  [[ "$output" == *"Usage:"* ]]
}

