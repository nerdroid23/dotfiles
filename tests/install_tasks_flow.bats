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

@test "stow_dotfiles dry-run installs stow when missing" {
  local fake_dotfiles="$TEST_TMP/dotfiles"
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_dotfiles/zsh/.zsh" "$fake_home/.zsh"
  echo "# existing omz zshrc" > "$fake_home/.zshrc"
  echo "[user]" > "$fake_home/.gitconfig"
  echo "export TEST=1" > "$fake_home/.zsh/exports.zsh"
  echo "export PATH=/tmp:\$PATH" > "$fake_home/.zsh/paths.zsh"
  echo "alias ll='ls -la'" > "$fake_home/.zsh/aliases.zsh"
  echo "hello() { :; }" > "$fake_home/.zsh/functions.zsh"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    DRY_RUN=true
    DOTFILES="'"$fake_dotfiles"'"
    HOME="'"$fake_home"'"
    PATH="/nonexistent"
    stow_dotfiles
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"stow not found - installing via Homebrew"* ]]
  [[ "$output" == *"brew install stow"* ]]
  [[ "$output" == *"Backing up existing ~/.zshrc before stow"* ]]
  [[ "$output" == *'mv '"$fake_home"'/.zshrc '"$fake_home"'/.zshrc.pre-dotfiles-backup'* ]]
  [[ "$output" == *"Backing up existing $fake_home/.gitconfig before stow"* ]]
  [[ "$output" == *'mv '"$fake_home"'/.gitconfig '"$fake_home"'/.gitconfig.pre-dotfiles-backup'* ]]
  [[ "$output" == *"Backing up existing $fake_home/.zsh before stow"* ]]
  [[ "$output" == *'mv '"$fake_home"'/.zsh '"$fake_home"'/.zsh.pre-dotfiles-backup'* ]]
  [[ "$output" == *"stow --restow"* ]]
  [[ "$output" == *"Verify ~/.zshrc and ~/.zsh module files exist"* ]]
}

@test "backup_existing_stow_target moves real file" {
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_home"
  echo "# existing omz zshrc" > "$fake_home/.gitconfig"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRY_RUN=false
    backup_existing_stow_target "'"$fake_home"'/.gitconfig"
  '

  [ "$status" -eq 0 ]
  [ ! -e "$fake_home/.gitconfig" ]
  [ -f "$fake_home/.gitconfig.pre-dotfiles-backup" ]
  [[ "$(cat "$fake_home/.gitconfig.pre-dotfiles-backup")" == *"existing omz zshrc"* ]]
}

@test "backup_existing_stow_target skips targets under symlinked parent" {
  local fake_home="$TEST_TMP/home"
  local fake_repo="$TEST_TMP/repo"
  mkdir -p "$fake_home" "$fake_repo/.zsh"
  ln -s "$fake_repo/.zsh" "$fake_home/.zsh"
  echo "export TEST=1" > "$fake_repo/.zsh/exports.zsh"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRY_RUN=false
    backup_existing_stow_target "'"$fake_home"'/.zsh/exports.zsh"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"parent symlinked"* ]]
  [ -f "$fake_repo/.zsh/exports.zsh" ]
  [ ! -e "$fake_repo/.zsh/exports.zsh.pre-dotfiles-backup" ]
}

@test "verify_zsh_layout fails when required module is missing" {
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_home/.zsh"
  touch "$fake_home/.zshrc" "$fake_home/.zsh/exports.zsh" "$fake_home/.zsh/paths.zsh" "$fake_home/.zsh/aliases.zsh"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRY_RUN=false
    verify_zsh_layout
  '

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required zsh file after stow"* ]]
  [[ "$output" == *"$fake_home/.zsh/functions.zsh"* ]]
}

@test "create_local_overrides_file fails clearly when template is missing" {
  local fake_home="$TEST_TMP/home"
  local fake_dotfiles="$TEST_TMP/dotfiles"
  mkdir -p "$fake_home" "$fake_dotfiles/zsh/.zsh"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DOTFILES="'"$fake_dotfiles"'"
    DRY_RUN=false
    create_local_overrides_file
  '

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing local overrides template"* ]]
  [[ "$output" == *"damaged locally"* ]]
}

# ==============================================================================
# setup_ssh_key tests
# ==============================================================================

@test "setup_ssh_key skips when key already exists" {
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_home/.ssh"
  touch "$fake_home/.ssh/id_ed25519"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRY_RUN=false
    setup_ssh_key
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]] || [[ "$output" == *"already"* ]]
}

@test "setup_ssh_key dry-run does not create key" {
  local fake_home="$TEST_TMP/home"
  mkdir -p "$fake_home"

  run bash -c '
    source "'"$BATS_TEST_DIRNAME"'/../lib/common.sh"
    source "'"$BATS_TEST_DIRNAME"'/../lib/install_tasks.sh"
    HOME="'"$fake_home"'"
    DRY_RUN=true
    setup_ssh_key
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [ ! -f "$fake_home/.ssh/id_ed25519" ]
}
