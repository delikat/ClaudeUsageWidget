# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS widget application that monitors Claude API usage limits. Displays 5-hour and 7-day usage percentages via WidgetKit widgets on the macOS desktop.

## Build & Test Commands

```bash
# Open workspace in Xcode (always use workspace, not project)
open ClaudeUsageWidget.xcworkspace

# Build main app
xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme ClaudeUsageWidget build

# Build widget extension
xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme ClaudeUsageWidgetExtension build

# Run unit tests (Swift Testing framework)
xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme ClaudeUsageWidgetPackage test

# Run UI tests
xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme ClaudeUsageWidgetUITests test
```

## Architecture

### Workspace + SPM Pattern
- **ClaudeUsageWidget/** - Main app target (invisible background app via `LSUIElement=YES`)
- **ClaudeUsageWidgetExtension/** - WidgetKit extension (displays widget UI)
- **ClaudeUsageWidgetPackage/** - Shared SPM package (primary development area)
- **Config/** - XCConfig files for build settings

### Data Flow
1. Main app reads OAuth token from macOS keychain (`Claude Code-credentials`)
2. Fetches usage from `https://api.anthropic.com/api/oauth/usage`
3. Caches to App Group container as `UsageCache.json`
4. Widget reads cache and displays usage gauges
5. Widget refresh button sends distributed notification to main app

### Inter-Process Communication
- **App Group**: `HN6S8N7886.group.com.delikat.claudewidget`
- **Distributed Notification**: `com.delikat.claudewidget.refresh`

### Key Types
- `CachedUsage` - Stored usage data with timestamps and error state
- `UsageCacheManager` - Singleton for reading/writing cache
- `RefreshUsageIntent` - AppIntent triggered by widget refresh button

## Development Notes

- Most development happens in `ClaudeUsageWidgetPackage/Sources/Shared/`
- Types exposed to app targets require `public` access modifier
- Widget supports Small (1x1) and Medium (2x1) families
- Uses Swift 6.1 with macOS 14+ deployment target
- Uses Swift Testing framework for unit tests, XCUITest for UI tests
