# dotfiles

Personal macOS dotfiles with automated setup. Uses GNU Stow for symlinks, Homebrew for packages, and Mackup for app config sync.

## Quick Start

```bash
git clone https://github.com/nerdroid23/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Install flow

The installer intentionally bootstraps PHP tooling before the full Brewfile run:

1. Install Homebrew
2. Install `php@8.4` and `composer`
3. Install Laravel Valet via Composer
4. Run `valet install` + `valet trust`, then `valet park` `~/work` and `~/projects` (plus drive `work/projects` when `--drive` is set)
5. Continue with the remaining setup (`brew bundle`, dotfiles, macOS defaults, Mackup, etc.)

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

### Mackup and AI CLI Configs

Mackup is used for app-managed settings/state that are worth syncing, but not for
entire AI CLI folders anymore (they contain lots of cache/session/log data).

Selected AI CLI config files are tracked as dotfiles instead via the `ai-cli` stow package
(for example `~/.gemini/settings.json`, `~/.copilot/*.json`, `~/.claude/settings.json`,
and `~/.codex/config.toml`).

`~/.gitconfig` is also repo-managed via `stow`. Mackup intentionally ignores the built-in
`git` app so old machine-specific Git config does not get restored over the repo version.

## Volta to mise Migration Script

Run this one-time migration helper to move from Volta-managed Node tooling to mise:

```bash
# Preview actions first
./migrate-volta-to-mise.sh --dry-run

# Run migration
./migrate-volta-to-mise.sh
```

Options:
- `--yes` - Skip the confirmation prompt
- `--node-version <version>` - Override detected Node version
- `--bun-version <version>` - Override detected Bun version (`latest` supported)

This script intentionally keeps Volta installed for fallback. Remove Volta later
after you verify your workflows.

## Volta to mise Migration Notes

Volta is currently still working on this machine, but Volta maintainers have recommended
migrating to `mise` because Volta is no longer actively maintained.

Recommended split (keep it simple):
- `mise`: runtimes like `node` and `bun`
- `corepack` (bundled with Node): `yarn`, `pnpm`
- Homebrew: general CLIs like `tldr`
- `npm -g` (under `mise`-managed Node): app CLIs like `codex`, `gemini`, `amp`

### Suggested migration checklist (safe path)

1. Install and activate `mise` (keep Volta installed for now).
2. Install Node in `mise` (start with current default, e.g. `node@24`).
3. Enable Corepack and activate package manager versions:
   - `corepack enable`
   - `corepack prepare yarn@1.22.22 --activate`
   - `corepack prepare pnpm@10.x --activate`
4. Install `bun` via `mise` (instead of npm/Volta-managed wrapper).
5. Install `tldr` via Homebrew and add it to `Brewfile`.
6. Reinstall npm global CLIs you actually use (`codex`, `gemini`, `amp`, etc.) under the new Node.
7. Verify commands (`node`, `bun`, `yarn`, `pnpm`, `tldr`, `codex`, `gemini`, `amp`).
8. After a few days of no issues, remove Volta from shell init and uninstall it.

### Current tool migration targets (for reference)

- `bun` -> manage with `mise`
- `yarn` -> manage with `corepack`
- `pnpm` -> manage with `corepack`
- `tldr` -> install/manage with Homebrew

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
- Languages: PHP, Node (via Volta, migrating to mise -- see [migration script](#volta-to-mise-migration-script)), Composer
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
| `ai-cli/` | `~/.claude/settings.json`, `~/.codex/config.toml`, `~/.gemini/settings.json`, `~/.copilot/*.json` |

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

The installer now continues even if App Store installs fail, then prints a summary
with retry commands (`mas install <id>`) at the end.

**"iCloud Drive not ready"**
Sign into iCloud in System Settings, wait for sync, then run Mackup manually:
```bash
mackup restore
```

**Safari preferences fail in `macos.sh`**
Newer macOS versions can block some `com.apple.Safari` preference writes. This is non-fatal.
Close Safari and rerun:
```bash
bash ~/dotfiles/macos.sh
```

### Re-running install

The installer is idempotent - safe to run multiple times. It skips:
- Already installed packages
- Existing git identity files
- Already created symlinks

### Checking for issues

```bash
# Verify symlinks
stow --restow --dir=~/dotfiles --target=$HOME -n -v mackup git zsh starship ai-cli

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
