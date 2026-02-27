#!/usr/bin/env bats

load test_helper

@test "build_non_mas_bootstrap_brewfile excludes mas and early bootstrap formulas" {
  local src="$TEST_TMP/Brewfile.src"
  local dst="$TEST_TMP/Brewfile.dst"

  cat > "$src" <<'EOF'
brew "php@8.4"
brew "composer"
brew "git"
mas "TestFlight", id: 899247664
cask "raycast"
EOF

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    build_non_mas_bootstrap_brewfile "'"$src"'" "'"$dst"'"
  '

  [ "$status" -eq 0 ]
  run cat "$dst"
  [ "$status" -eq 0 ]
  [[ "$output" == *'brew "git"'* ]]
  [[ "$output" == *'cask "raycast"'* ]]
  [[ "$output" != *'brew "php@8.4"'* ]]
  [[ "$output" != *'brew "composer"'* ]]
  [[ "$output" != *'mas "TestFlight"'* ]]
}

@test "parse_mas_apps_from_brewfile extracts app names and ids" {
  local src="$TEST_TMP/Brewfile.mas"

  cat > "$src" <<'EOF'
mas "TestFlight", id: 899247664
mas "Xcode", id: 497799835
EOF

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    parse_mas_apps_from_brewfile "'"$src"'"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *$'TestFlight\t899247664'* ]]
  [[ "$output" == *$'Xcode\t497799835'* ]]
}

@test "run_preflight_checks warns when App Store is not signed in but does not fail" {
  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"

    xcode-select() { return 0; }
    mas() { return 1; }

    DRY_RUN=true
    run_preflight_checks
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Not signed into App Store"* ]]
}

@test "park_valet_directories dry-run includes local and drive paths" {
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_home"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRIVE="/Volumes/TestDrive"
    DRY_RUN=true
    park_valet_directories
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *'valet park "'"$fake_home"'/work"'* ]]
  [[ "$output" == *'valet park "'"$fake_home"'/projects"'* ]]
  [[ "$output" == *'valet park "/Volumes/TestDrive/work"'* ]]
  [[ "$output" == *'valet park "/Volumes/TestDrive/projects"'* ]]
}

@test "park_valet_directories skips already parked path" {
  local fake_home="$TEST_TMP/home"
  local calls_file="$TEST_TMP/calls.log"
  mkdir -p "$fake_home"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRIVE=""
    DRY_RUN=false

    resolve_valet_bin() { echo mock_valet; }
    valet_has_parked_path() { [[ "$2" == "$HOME/work" ]]; }
    mock_valet() { echo "$*" >> "'"$calls_file"'"; return 0; }

    park_valet_directories
  '

  [ "$status" -eq 0 ]
  run cat "$calls_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"park $fake_home/projects"* ]]
  [[ "$output" != *"park $fake_home/work"* ]]
}

@test "park_valet_directories continues when one park fails" {
  local fake_home="$TEST_TMP/home"
  local calls_file="$TEST_TMP/calls-fail.log"
  mkdir -p "$fake_home"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRIVE=""
    DRY_RUN=false

    resolve_valet_bin() { echo mock_valet; }
    valet_has_parked_path() { return 1; }
    mock_valet() {
      if [[ "$1" == "park" && "$2" == "'"$fake_home"'/work" ]]; then
        return 1
      fi
      echo "$*" >> "'"$calls_file"'"
      return 0
    }

    park_valet_directories
    echo "WARNINGS:${INSTALL_WARNINGS[*]}"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to valet park $fake_home/work"* ]]
  [[ "$output" == *"WARNINGS:Laravel Valet failed to park $fake_home/work"* ]]

  run cat "$calls_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"park $fake_home/projects"* ]]
}
