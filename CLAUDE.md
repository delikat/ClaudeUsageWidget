# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS widget application that monitors Claude API usage limits. Displays 5-hour and 7-day usage percentages via WidgetKit widgets on the macOS desktop.

## Build & Test Commands

```bash
# Open workspace in Xcode (always use workspace, not project)
open AgentUsageWidget.xcworkspace

# Build main app
xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme AgentUsageWidget build

# Build widget extension
xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme AgentUsageWidgetExtension build

# Generate widget snapshots (light + dark)
xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme WidgetSnapshotTests test

# Optional: override output directory
WIDGET_SNAPSHOT_DIR=docs/screenshots xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme WidgetSnapshotTests test

# Run unit tests (Swift Testing framework)
xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme AgentUsageWidgetPackage test

# Run UI tests
xcodebuild -workspace AgentUsageWidget.xcworkspace -scheme AgentUsageWidgetUITests test
```

## Architecture

### Workspace + SPM Pattern
- **AgentUsageWidget/** - Main app target (invisible background app via `LSUIElement=YES`)
- **AgentUsageWidgetExtension/** - WidgetKit extension (displays widget UI)
- **AgentUsageWidgetPackage/** - Shared SPM package (primary development area)
- **Config/** - XCConfig files for build settings

### Data Flow
1. Main app reads OAuth token from macOS keychain (`Claude Code-credentials`)
2. Fetches usage from `https://api.anthropic.com/api/oauth/usage`
3. Caches to App Group container as `UsageCache.json`
4. Widget reads cache and displays usage gauges
5. Widget refresh button sends distributed notification to main app

### Inter-Process Communication
- **App Group**: `HN6S8N7886.group.com.delikat.agentusagewidget`
- **Distributed Notification**: `com.delikat.agentusagewidget.refresh`

### Key Types
- `CachedUsage` - Stored usage data with timestamps and error state
- `UsageCacheManager` - Singleton for reading/writing cache
- `RefreshUsageIntent` - AppIntent triggered by widget refresh button

## Development Notes

- **Xcode Canvas previews do NOT work for macOS widgets.** You must run the main app to install the widget extension, then use WidgetKit Simulator or add the widget to the desktop to see changes.
- **Snapshotting widgets:** Run the `WidgetSnapshotTests` scheme to render all widget variants to PNGs (light + dark). Defaults to `.context/widget-snapshots` with `-dark` filename suffix for dark mode. You can override the output directory via `WIDGET_SNAPSHOT_DIR`.
- **Updating widgets during development:** After building, run these commands to see changes immediately in WidgetKit Simulator (no restart needed):
  ```bash
  killall AgentUsageWidgetExtension CodexUsageWidgetExtension 2>/dev/null
  ```
- Most development happens in `AgentUsageWidgetPackage/Sources/Shared/`
- Types exposed to app targets require `public` access modifier
- Widget supports Small (1x1) and Medium (2x1) families
- Uses Swift 6.1 with macOS 14+ deployment target
- Uses Swift Testing framework for unit tests, XCUITest for UI tests

## Reference Project

**Claude Usage Tracker** (`/Users/adelikat/Developer/Claude-Usage-Tracker`) is a mature macOS menu bar app that accomplishes similar goals. Useful for inspiration on:
- Token handling and expiration (`ClaudeCodeSyncService.swift`, `ClaudeAPIService.swift`)
- Keychain access patterns
- Error handling strategies
