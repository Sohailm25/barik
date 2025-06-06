# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Barik is a lightweight macOS menu bar replacement that integrates with tiling window managers (Yabai, AeroSpace) to display workspace information in a customizable menu bar interface. The app uses SwiftUI and runs as a persistent background application with two main panels: a background panel and a menu bar panel.

## Development Commands

### Building and Running
- **Build**: Use Xcode to build the project (`⌘+B`)
- **Run**: Use Xcode to run the project (`⌘+R`) or build and run from Applications folder
- **Archive**: Use Xcode Product → Archive for release builds

### Dependencies
The project uses Swift Package Manager with these key dependencies:
- **TOMLDecoder**: For parsing configuration files
- **MarkdownUI**: For rendering changelog and documentation
- **Shimmer**: For UI shimmer animation

## Architecture Overview

### Core Application Structure
- **BarikApp.swift**: Main SwiftUI app entry point with MenuBarExtra
- **AppDelegate.swift**: Handles app lifecycle, creates background and menu bar panels
- **Config/**: Configuration management system with live file watching
- **Views/**: Core UI components (MenuBarView, BackgroundView, etc.)
- **Widgets/**: Modular widget system for different menu bar components

### Configuration System
- **Config file locations**: `~/.barik-config.toml` or `~/.config/barik/config.toml`
- **ConfigManager**: Singleton that handles TOML parsing, file watching, and live updates
- **ConfigModels.swift**: Type definitions for configuration structure
- Default config is auto-created on first launch if none exists

### Widget Architecture
Each widget follows a consistent pattern:
- **Widget**: SwiftUI view (e.g., `BatteryWidget.swift`)
- **Manager**: Data provider/business logic (e.g., `BatteryManager.swift`) 
- **Popup**: Detailed view shown on click (e.g., `BatteryPopup.swift`)

Available widgets:
- **Spaces**: Displays workspace/space information from Yabai/AeroSpace
- **Time+Calendar**: Clock with calendar popup
- **Battery**: Battery status with detailed popup
- **Network**: Network connectivity status
- **Bluetooth**: Bluetooth device management
- **NowPlaying**: Music playback controls
- **SystemBanner**: App updates and changelog notifications

### Window Management Integration
- **Yabai Provider**: Interfaces with yabai via command line calls
- **AeroSpace Provider**: Interfaces with AeroSpace via command line calls
- **Event-based updates**: Real-time workspace/window change notifications
- **SpacesViewModel**: Coordinates between providers and UI

### Panel System
The app creates two NSPanel instances:
- **Background Panel**: Desktop-level blurred background
- **Menu Bar Panel**: Foreground panel with widgets at menu bar level
- Both panels span full screen width and use `canJoinAllSpaces` behavior

## Key Files to Understand

- `Barik/AppDelegate.swift:23-48`: Panel setup and configuration
- `Barik/Views/MenuBarView.swift:40-84`: Widget rendering logic
- `Barik/Config/ConfigManager.swift:61-107`: Default configuration template
- `Barik/Widgets/Spaces/SpacesViewModel.swift`: Core workspace management
- `Barik/Widgets/Spaces/*/Provider.swift`: Window manager integrations

## Configuration Structure

Widgets are configured via TOML with this hierarchy:
```
[widgets]
displayed = ["default.spaces", "default.time", ...]

[widgets.default.{widget-name}]
# Widget-specific configuration

[experimental.*]
# Advanced styling and behavior options
```

Each widget can have both global configuration and inline parameters specified in the `displayed` array.
