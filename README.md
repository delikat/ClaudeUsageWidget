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

## Development Notes

### Code Organization
Most development happens in `ClaudeUsageWidgetPackage/Sources/Shared/` - organize your code as you prefer.

### Public API Requirements
Types exposed to the app target need `public` access:
```swift
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        // Your view code
    }
}
```

### Adding Dependencies
Edit `ClaudeUsageWidgetPackage/Package.swift` to add SPM dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "Shared",
        dependencies: ["SomePackage"]
    ),
]
```

### Test Structure
- **Unit Tests**: `ClaudeUsageWidgetPackage/Tests/SharedTests/` (Swift Testing framework)
- **UI Tests**: `ClaudeUsageWidgetUITests/` (XCUITest framework)
- **Test Plan**: `ClaudeUsageWidget.xctestplan` coordinates all tests

### Widget Snapshots (CLI/CI)
Generate widget PNGs from the command line (no WidgetKit Simulator needed):
```bash
xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme WidgetSnapshotTests test
```
Snapshots are written to `.context/widget-snapshots` by default. Override the output directory:
```bash
WIDGET_SNAPSHOT_DIR=docs/screenshots xcodebuild -workspace ClaudeUsageWidget.xcworkspace -scheme WidgetSnapshotTests test
```
Dark mode variants are saved with a `-dark` suffix (for example `claude-small-dark.png`).

## Configuration

### XCConfig Build Settings
Build settings are managed through **XCConfig files** in `Config/`:
- `Config/Shared.xcconfig` - Common settings (bundle ID, versions, deployment target)
- `Config/Debug.xcconfig` - Debug-specific settings  
- `Config/Release.xcconfig` - Release-specific settings
- `Config/Tests.xcconfig` - Test-specific settings

### App Sandbox & Entitlements
The app is sandboxed by default with basic file access. Edit `ClaudeUsageWidget/ClaudeUsageWidget.entitlements` to add capabilities:
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<!-- Add other entitlements as needed -->
```

## macOS-Specific Features

### Window Management
Add multiple windows and settings panels:
```swift
@main
struct ClaudeUsageWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Settings {
            SettingsView()
        }
    }
}
```

### Asset Management
- **App-Level Assets**: `ClaudeUsageWidget/Assets.xcassets/` (app icon with multiple sizes, accent color)
- **Feature Assets**: Add `Resources/` folder to SPM package if needed

### SPM Package Resources
To include assets in your feature package:
```swift
.target(
    name: "Shared",
    dependencies: [],
    resources: [.process("Resources")]
)
```

## Notes

### Generated with XcodeBuildMCP
This project was scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP), which provides tools for AI-assisted macOS development workflows.
