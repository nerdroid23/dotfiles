#!/usr/bin/env bash
# macOS system preferences
# Run once after a fresh install. Requires a logout/restart to take full effect.

set -euo pipefail

# ==============================================================================
# Global System Settings
# ==============================================================================

# Show all file extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Only show scrollbars when scrolling
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable automatic dash substitution (smart dashes)
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution (double-space becomes period)
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable automatic quote substitution (smart quotes)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable automatic spelling correction
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Always expand save dialogs
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Always expand print dialogs
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ==============================================================================
# Finder Settings
# ==============================================================================

# Show status bar at bottom of Finder windows
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar at bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true

# Default to home folder when opening a new Finder window
defaults write com.apple.finder FXDefaultScope -string "home"

# Disable warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Default view style: list view (Nlsv)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show full POSIX path in Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Allow quitting Finder via Cmd+Q
defaults write com.apple.finder QuitMenuItem -bool true

# Disable warning when emptying trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# ==============================================================================
# Dock Settings
# ==============================================================================

# Enable dock autohide
defaults write com.apple.dock autohide -bool true

# Remove delay for dock autohide (instant show/hide)
defaults write com.apple.dock autohide-delay -float 0

# Speed up dock autohide animation
defaults write com.apple.dock autohide-time-modifier -float 0.5

# Don't show recent apps in dock
defaults write com.apple.dock show-recents -bool false

# Set dock icon size
defaults write com.apple.dock tilesize -int 48

# Minimize windows into application icon
defaults write com.apple.dock minimize-to-application -bool true

# Don't automatically rearrange spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Dim hidden apps in dock
defaults write com.apple.dock showhidden -bool true

# Show only active + pinned apps in dock
defaults write com.apple.dock static-only -bool false

# ==============================================================================
# Safari Settings
# ==============================================================================

# Show full URL in address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Don't automatically open "safe" downloads
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Show Develop menu in menu bar
defaults write com.apple.Safari IncludeDevelopMenu -bool true

# Enable WebKit developer tools in Safari
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# ==============================================================================
# Keyboard Settings
# ==============================================================================

# Fast key repeat (lower = faster, minimum is 1)
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay before key repeat starts (lower = shorter)
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Speed up window resize animations
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable keyboard illumination auto-dimming
defaults write com.apple.BezelServices kDim -int 0

# ==============================================================================
# Trackpad Settings
# ==============================================================================
# Both domains must be set for reliability across built-in and Magic Trackpad.

# Enable tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Enable three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# ==============================================================================
# Security & Privacy
# ==============================================================================

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# ==============================================================================
# Power Management
# ==============================================================================

# Don't sleep when power button is pressed
defaults write com.apple.loginwindow PowerButtonSleepsSystem -bool false

# ==============================================================================
# Time Machine
# ==============================================================================

# Don't offer new disks for Time Machine backup
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ==============================================================================
# Crash Reporter
# ==============================================================================

# Don't show crash reporter dialog
defaults write com.apple.CrashReporter DialogType -string "none"

# ==============================================================================
# Downloaded Files
# ==============================================================================

# Disable "Are you sure you want to open this app?" quarantine dialog.
# Security tradeoff: removes the Gatekeeper prompt for downloaded apps.
defaults write com.apple.LaunchServices LSQuarantine -bool false

# ==============================================================================
# Advertising
# ==============================================================================

# Disable personalized Apple ads
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false

# ==============================================================================
# App Store & Software Update
# ==============================================================================

# Enable automatic app updates
defaults write com.apple.commerce AutoUpdate -bool true

# Enable automatic software update checking
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download updates automatically
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install critical updates automatically
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# ==============================================================================
# Activity Monitor
# ==============================================================================

# Show all processes
defaults write com.apple.ActivityMonitor ShowType -int 4

# Sort by CPU usage, descending
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# ==============================================================================
# TextEdit
# ==============================================================================

# Use plain text mode by default
defaults write com.apple.TextEdit RichText -int 0

# Use UTF-8 encoding for plain text
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# ==============================================================================
# Messages
# ==============================================================================

# Disable continuous spell checking
defaults write com.apple.messageshelper.MessageController SOInputLineSettings \
  -dict-add "continuousSpellCheckingEnabled" -bool false

# ==============================================================================
# WebKit Developer Tools
# ==============================================================================

# Enable WebKit developer tools in all apps
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# ==============================================================================
# Screenshots
# ==============================================================================

# Save screenshots to ~/Desktop/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# Save screenshots as PNG
defaults write com.apple.screencapture type -string "png"

# Disable screenshot drop shadow
defaults write com.apple.screencapture disable-shadow -bool true

# ==============================================================================
# Font Smoothing
# ==============================================================================

# Subpixel font smoothing — mainly useful on non-Retina external displays
defaults write -g AppleFontSmoothing -int 2

# ==============================================================================
# Directories
# ==============================================================================

mkdir -p "$HOME/Desktop/Screenshots"

# ==============================================================================
# Restart affected apps
# ==============================================================================

for app in "Dock" "Finder" "Safari" "SystemUIServer" "Activity Monitor"; do
  killall "$app" &>/dev/null || true
done

echo "macOS defaults applied. A logout/restart may be required for all changes to take effect."
