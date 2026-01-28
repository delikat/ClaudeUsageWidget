import Foundation

/// Manages the LaunchAgent plist for auto-starting the app at login
public final class LaunchAgentManager: Sendable {
    public static let shared = LaunchAgentManager()

    private let plistName = "com.delikat.claudewidget.plist"

    private var launchAgentsURL: URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    private var plistURL: URL? {
        launchAgentsURL?.appendingPathComponent(plistName)
    }

    private init() {}

    /// Check if the LaunchAgent is currently installed
    public var isEnabled: Bool {
        guard let url = plistURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Enable or disable auto-start at login
    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try uninstall()
        }
    }

    /// Install the LaunchAgent plist
    private func install() throws {
        guard let launchAgentsDir = launchAgentsURL,
              let plistPath = plistURL else {
            throw LaunchAgentError.invalidPath
        }

        // Create LaunchAgents directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: launchAgentsDir.path) {
            try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        }

        // Get the app bundle path
        guard let appPath = Bundle.main.bundlePath as String? else {
            throw LaunchAgentError.appNotFound
        }

        // Create the plist content
        let plistContent: [String: Any] = [
            "Label": "com.delikat.claudewidget",
            "ProgramArguments": ["/usr/bin/open", "-a", appPath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        // Write the plist
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistContent,
            format: .xml,
            options: 0
        )
        try plistData.write(to: plistPath)

        AppLog.launchAgent.info("Installed LaunchAgent at \(plistPath.path)")
    }

    /// Remove the LaunchAgent plist
    private func uninstall() throws {
        guard let plistPath = plistURL else {
            throw LaunchAgentError.invalidPath
        }

        if FileManager.default.fileExists(atPath: plistPath.path) {
            try FileManager.default.removeItem(at: plistPath)
            AppLog.launchAgent.info("Removed LaunchAgent from \(plistPath.path)")
        }
    }

    public enum LaunchAgentError: Error, LocalizedError {
        case invalidPath
        case appNotFound

        public var errorDescription: String? {
            switch self {
            case .invalidPath:
                return "Could not determine LaunchAgents directory"
            case .appNotFound:
                return "Could not determine app bundle path"
            }
        }
    }
}
