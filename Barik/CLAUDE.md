# Barik - Main Application Directory

Core application code and entry points.

## Files

- **BarikApp.swift** - Main SwiftUI app entry point, manages app lifecycle and window creation
- **AppDelegate.swift** - NSApplicationDelegate handling app events and menu bar setup
- **Constants.swift** - Global constants for widgets, themes, and configuration
- **Info.plist** - Application metadata and permissions
- **Barik.entitlements** - App sandbox and security entitlements

## Folders

- **Config/** - [Configuration management](Config/CLAUDE.md) - Config file parsing and models
- **MenuBarPopup/** - [Popup system](MenuBarPopup/CLAUDE.md) - Popup windows and variant views
- **Resources/** - [Assets and localization](Resources/CLAUDE.md) - Icons, colors, and strings
- **Styles/** - [UI styles](Styles/CLAUDE.md) - Custom button and progress bar styles
- **Utils/** - [Utilities](Utils/CLAUDE.md) - Extensions, caching, and visual effects
- **Views/** - [Main views](Views/CLAUDE.md) - Menu bar and background views
- **Widgets/** - [Widget system](Widgets/CLAUDE.md) - All menu bar widgets (Battery, Bluetooth, Network, etc.)