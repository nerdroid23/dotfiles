#!/usr/bin/env bats

load test_helper

# ==============================================================================
# teardown_symlink tests
# ==============================================================================

@test "teardown_symlink: restores data from drive when symlink and dst exist" {
  local src="$BATS_TEST_TMPDIR/home/.testapp"
  local dst="$BATS_TEST_TMPDIR/drive/TestApp"

  mkdir -p "$dst"
  echo "data" > "$dst/config.txt"
  mkdir -p "$(dirname "$src")"
  ln -sfn "$dst" "$src"

  run bash -c '
    export HOME="'"$BATS_TEST_TMPDIR/home"'"
    export DRY_RUN=false
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
    teardown_symlink "'"$src"'" "'"$dst"'" "TestApp"
  '
  [ "$status" -eq 0 ]

  [ ! -L "$src" ]
  [ -d "$src" ]
  [ -f "$src/config.txt" ]
  [ "$(cat "$src/config.txt")" = "data" ]
  [ ! -e "$dst" ]
}

@test "teardown_symlink: removes symlink when no data on drive" {
  local src="$BATS_TEST_TMPDIR/home/.nodata"
  local dst="$BATS_TEST_TMPDIR/drive/NoData"

  mkdir -p "$(dirname "$src")"
  ln -sfn "$dst" "$src"

  run bash -c '
    export HOME="'"$BATS_TEST_TMPDIR/home"'"
    export DRY_RUN=false
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
    teardown_symlink "'"$src"'" "'"$dst"'" "NoData"
  '
  [ "$status" -eq 0 ]

  [ ! -e "$src" ]
  [[ "$output" == *"symlink removed"* ]]
}

@test "teardown_symlink: skips when src is not a symlink" {
  local src="$BATS_TEST_TMPDIR/home/.notlink"
  local dst="$BATS_TEST_TMPDIR/drive/NotLink"

  mkdir -p "$src"

  run bash -c '
    export HOME="'"$BATS_TEST_TMPDIR/home"'"
    export DRY_RUN=false
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
    teardown_symlink "'"$src"'" "'"$dst"'" "NotLink"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a symlink"* ]]

  [ -d "$src" ]
}

@test "teardown_symlink: skips when src does not exist" {
  local src="$BATS_TEST_TMPDIR/home/.missing"
  local dst="$BATS_TEST_TMPDIR/drive/Missing"

  run bash -c '
    export HOME="'"$BATS_TEST_TMPDIR/home"'"
    export DRY_RUN=false
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
    teardown_symlink "'"$src"'" "'"$dst"'" "Missing"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a symlink"* ]]
}

@test "teardown_symlink: dry-run does not modify filesystem" {
  local src="$BATS_TEST_TMPDIR/home/.drytest"
  local dst="$BATS_TEST_TMPDIR/drive/DryTest"

  mkdir -p "$dst"
  echo "data" > "$dst/config.txt"
  mkdir -p "$(dirname "$src")"
  ln -sfn "$dst" "$src"

  run bash -c '
    export HOME="'"$BATS_TEST_TMPDIR/home"'"
    export DRY_RUN=true
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/uninstall_tasks.sh"
    teardown_symlink "'"$src"'" "'"$dst"'" "DryTest"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]

  [ -L "$src" ]
  [ -d "$dst" ]
  [ -f "$dst/config.txt" ]
}
