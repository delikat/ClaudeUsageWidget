# AgentUsage - macOS App

A modern macOS application using a workspace + SPM package architecture for clean separation between app shell and feature code.

## Project Architecture

```
AgentUsage/
├── AgentUsage.xcworkspace/              # Open this file in Xcode
├── AgentUsage.xcodeproj/                # App shell project
├── AgentUsage/                          # App target (minimal)
│   ├── Assets.xcassets/                 # App-level assets (icons, colors)
│   ├── AgentUsageApp.swift              # App entry point
│   └── AgentUsage.xctestplan            # Test configuration
├── AgentUsagePackage/                   # Primary development area
│   ├── Package.swift                    # Package configuration
│   ├── Sources/Shared/                  # Your feature code
│   └── Tests/SharedTests/               # Unit tests
├── AgentUsageUITests/                   # UI automation tests
├── AgentUsageWidgetExtension/           # Claude widget extension
├── CodexUsageWidgetExtension/           # Codex widget extension
├── Config/                              # Build settings + entitlements
│   └── AgentUsage.entitlements          # App sandbox settings
└── WidgetSnapshotTests/                 # Snapshot test target
```

## Quick Start

```bash
# Open workspace in Xcode
open AgentUsage.xcworkspace

# Build
xcodebuild -workspace AgentUsage.xcworkspace -scheme AgentUsage build

# Run unit tests
xcodebuild -workspace AgentUsage.xcworkspace -scheme AgentUsagePackage test
```

## Key Architecture Points

### Workspace + SPM Structure
- App Shell: `AgentUsage/` contains minimal app lifecycle code
- Feature Code: `AgentUsagePackage/Sources/Shared/` is where most development happens
- Separation: Business logic lives in the SPM package, app target just imports and displays it

### Buildable Folders (Xcode 16)
- Files added to the filesystem automatically appear in Xcode
- No need to manually add files to project targets
- Reduces project file conflicts in teams

### App Sandbox
The app is currently configured without App Sandbox (no `com.apple.security.app-sandbox` entitlement). If you want a sandboxed build, you will need to enable App Sandbox, add `com.apple.security.network.client`, and switch file access to user-selected folders (security-scoped bookmarks) for `~/.claude` and `~/.codex`.

## Development Notes

### Code Organization
Most development happens in `AgentUsagePackage/Sources/Shared/` - organize your code as you prefer.

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
Edit `AgentUsagePackage/Package.swift` to add SPM dependencies:
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
- Unit Tests: `AgentUsagePackage/Tests/SharedTests/` (Swift Testing framework)
- UI Tests: `AgentUsageUITests/` (XCUITest framework)
- Test Plan: `AgentUsage.xctestplan` coordinates all tests

### Widget Snapshots
Generate widget PNGs from the command line (no WidgetKit Simulator needed):
```bash
xcodebuild -workspace AgentUsage.xcworkspace -scheme WidgetSnapshotTests test
```
Snapshots are written to `.context/widget-snapshots` by default. Override the output directory:
```bash
WIDGET_SNAPSHOT_DIR=docs/screenshots xcodebuild -workspace AgentUsage.xcworkspace -scheme WidgetSnapshotTests test
```
Dark mode variants are saved with a `-dark` suffix (e.g., `claude-small-dark.png`).

## Configuration

### XCConfig Build Settings
Build settings are managed through XCConfig files in `Config/`:
- `Config/Shared.xcconfig` - Common settings (bundle ID, versions, deployment target)
- `Config/Debug.xcconfig` - Debug-specific settings
- `Config/Release.xcconfig` - Release-specific settings
- `Config/Tests.xcconfig` - Test-specific settings

### App Sandbox & Entitlements
The app uses an App Group entitlement for widget data sharing. If you fork, update the App Group ID in `Config/AgentUsage.entitlements` and `AgentUsagePackage/Sources/Shared/AppGroup.swift` to match your own Team ID. App Groups require a properly signed build (set `DEVELOPMENT_TEAM` in `Config/Shared.xcconfig`).

If you choose to sandbox the app, add capabilities in `Config/AgentUsage.entitlements` such as:
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
struct AgentUsageApp: App {
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
- App-Level Assets: `AgentUsage/Assets.xcassets/` (app icon with multiple sizes, accent color)
- Feature Assets: Add `Resources/` folder to SPM package if needed

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
This project was scaffolded using XcodeBuildMCP, which provides tools for AI-assisted macOS development workflows.
