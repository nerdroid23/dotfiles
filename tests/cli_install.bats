#!/usr/bin/env bats

load test_helper

@test "cli libs can be sourced" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_install.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
  '
  [ "$status" -eq 0 ]
}

@test "parse_install_args sets defaults with no args" {
  source "$BATS_TEST_DIRNAME/../lib/cli_install.sh"

  parse_install_args

  [ "$DRIVE" = "" ]
  [ "$ALLOW_NON_VOLUMES_DRIVE" = "false" ]
  [ "$DRY_RUN" = "false" ]
}

@test "parse_install_args parses drive and flags" {
  source "$BATS_TEST_DIRNAME/../lib/cli_install.sh"

  parse_install_args --drive /Volumes/Test --allow-non-volumes-drive --dry-run

  [ "$DRIVE" = "/Volumes/Test" ]
  [ "$ALLOW_NON_VOLUMES_DRIVE" = "true" ]
  [ "$DRY_RUN" = "true" ]
}

@test "parse_install_args rejects unknown argument" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/cli_install.sh"
    parse_install_args --wat
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument: --wat"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "common run helper respects dry-run and does not mutate" {
  local target="$TEST_TMP/should-not-exist"

  run bash -c '
    export DRY_RUN=true
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    run touch "'"$target"'"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [ ! -e "$target" ]
}
