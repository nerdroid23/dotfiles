# dotfiles

Personal macOS dotfiles with automated setup. Uses GNU Stow for symlinks, Homebrew for packages, and Mackup for app config sync.

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Install Options

```bash
./install.sh [options]

Options:
  --drive PATH    Set up external drive symlinks (e.g., --drive /Volumes/MyDrive)
  --dry-run       Preview actions without making changes
```

## Syncing Changes Back

To capture your current machine state back into the repo:

```bash
./sync.sh
```

This will:
- Update `Brewfile` with your currently installed Homebrew packages
- Run `mackup backup --force` to sync app configs to iCloud
- Show `git status`/`git diff --stat` and a suggested commit command

Options:
- `--dry-run` - Show what would be done without updating `Brewfile` or running Mackup

### Mackup Custom Apps

This repo includes custom Mackup app definitions for unsupported dotfolders.
They live in `mackup/.mackup/` and are stowed to `~/.mackup/` so Mackup can load them.

### Examples

```bash
# Standard install
./install.sh

# Preview what will happen
./install.sh --dry-run

# Install with external drive for large app data
./install.sh --drive /Volumes/MillenniumFalcon
```

## What Gets Installed

### Packages (via Homebrew)
- CLI tools: `bat`, `eza`, `fd`, `ripgrep`, `zoxide`, `delta`, `dust`, `procs`, `stow`, `starship`
- Languages: PHP, Node (via Volta), Composer
- Apps: See `Brewfile` for full list

### Symlinked Configs (via Stow)
| Source | Target |
|--------|--------|
| `git/.gitconfig` | `~/.gitconfig` |
| `git/.gitignore-global` | `~/.gitignore-global` |
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.zsh/` | `~/.zsh/` |
| `starship/.config/starship.toml` | `~/.config/starship.toml` |
| `mackup/.mackup.cfg` | `~/.mackup.cfg` |

### Generated Files (not in repo)
| File | Purpose |
|------|---------|
| `~/.gitconfig-work` | Work git identity (name/email) |
| `~/.gitconfig-personal` | Personal git identity |
| `~/.zshrc.local` | Machine-specific overrides |

## External Drive Setup

The `--drive` flag offloads large app data to an external drive via symlinks:

```bash
./install.sh --drive /Volumes/MillenniumFalcon
```

This creates:
| Local Path | Drive Path |
|------------|------------|
| `~/.orbstack` | `$DRIVE/OrbStack` |
| `~/Library/Developer/Xcode/DerivedData` | `$DRIVE/Xcode/DerivedData` |
| `~/Library/Developer/CoreSimulator/Devices` | `$DRIVE/Xcode/Simulators` |
| `~/Library/Android/sdk` | `$DRIVE/Android/sdk` |
| `~/.android/avd` | `$DRIVE/Android/avd` |

Apps follow symlinks transparently - no configuration changes needed.

> **Note:** The `--drive` setup is for fresh installs only. It fails fast on preexisting
> state (wrong symlinks, conflicts) to avoid accidental data loss. Resolve manually
> if needed.

## Git Identity

Git uses conditional includes based on repo location:
- `~/work/**` and `/Volumes/*/work/**` use `~/.gitconfig-work`
- `~/projects/**` and `/Volumes/*/projects/**` use `~/.gitconfig-personal`

Clone work repos into `~/work/` and personal repos into `~/projects/`.

## Shell Aliases

Modern CLI replacements (originals still accessible):

| Alias | Command | Original |
|-------|---------|----------|
| `ls` | `eza --icons` | `/bin/ls` |
| `ll` | `eza -la --icons --git` | - |
| `cat` | `bat` | `/bin/cat` |
| `f` | `fd` | `find` |
| `g` | `rg` | `grep` |
| `j` | `z` (zoxide) | `cd` |
| `du` | `dust` | `/usr/bin/du` |
| `ps` | `procs` | `/bin/ps` |

## Uninstall

```bash
./uninstall.sh
```

This will:
1. Remove symlinks created by Stow
2. Restore macOS defaults from snapshot (taken during install)
3. Optionally restore drive symlinks to local directories

## Troubleshooting

### Preflight failures

**"Not signed into App Store"**
```bash
mas signin
```

**"iCloud Drive not ready"**
Sign into iCloud in System Settings, wait for sync, then run Mackup manually:
```bash
mackup restore
```

### Re-running install

The installer is idempotent - safe to run multiple times. It skips:
- Already installed packages
- Existing git identity files
- Already created symlinks

### Checking for issues

```bash
# Verify symlinks
stow --restow --dir=~/dotfiles --target=$HOME -n -v mackup git zsh starship

# Check shell config
zsh -n ~/.zshrc

# Test in subshell
zsh -l
```

## Security Notes

The `macos.sh` script disables Gatekeeper quarantine warnings for downloaded apps:
```bash
defaults write com.apple.LaunchServices LSQuarantine -bool false
```

This is a convenience/security tradeoff. Remove this line from `macos.sh` if you prefer the default macOS behavior.

## CI

GitHub Actions runs on push/PR:
- `shellcheck` on all `.sh` files
- `bash -n` syntax validation
- `bats` smoke tests

## License

MIT
