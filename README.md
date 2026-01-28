# Claude Usage Widget

[![CI](https://github.com/delikat/ClaudeUsageWidget/actions/workflows/ci.yml/badge.svg)](https://github.com/delikat/ClaudeUsageWidget/actions/workflows/ci.yml)

Track Claude usage directly on your macOS desktop with native widgets.

## Features
- 5-hour and 7-day usage widgets for Claude and ChatGPT (Codex)
- Monthly usage breakdowns and cost estimates
- Daily heatmap combining Claude and (optional) Codex logs
- Optional notifications at usage thresholds
- Runs quietly in the background with Start at Login support

## Requirements
- macOS 14+ (Sonoma or newer)
- Claude Code installed and signed in
- Optional: Codex CLI usage/logs for Codex widgets and heatmap data

## Privacy
- Uses the existing Claude Code OAuth token from macOS Keychain to query usage.
- Reads local logs from `~/.claude/projects` (Claude) and `~/.codex/sessions` (Codex).
- Caches usage in the app's App Group container; **tokens are never stored**.
- No telemetry; network calls are limited to the Anthropic usage API and (if Codex widgets are enabled) the ChatGPT usage endpoint used by the Codex/ChatGPT CLI (`https://chatgpt.com/backend-api/wham/usage`, which is not a public API and may change).

## Getting Started
1. Install the app (from a release build or by building locally).
2. Open the app once so macOS registers the widgets.
3. Add widgets from the macOS Widget Gallery.
4. Optional: run Codex CLI to generate logs for Codex widgets.

## Development
- Open the workspace in Xcode: `ClaudeUsageWidget.xcworkspace`
- Build with Xcode or use `xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme ClaudeUsageWidget build`
- Unit tests live in `ClaudeUsageWidgetPackage/Tests/SharedTests/`
- If you fork, update the bundle ID and App Group to your own Team ID in `Config/Shared.xcconfig`, `Config/ClaudeUsageWidget.entitlements`, and `ClaudeUsageWidgetPackage/Sources/Shared/AppGroup.swift`.
