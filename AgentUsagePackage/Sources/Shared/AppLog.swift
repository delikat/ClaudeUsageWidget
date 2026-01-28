import os

public enum AppLog {
    private static let subsystem = "com.delikat.agentusage"

    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let cache = Logger(subsystem: subsystem, category: "Cache")
    public static let history = Logger(subsystem: subsystem, category: "History")
    public static let jsonl = Logger(subsystem: subsystem, category: "JSONL")
    public static let launchAgent = Logger(subsystem: subsystem, category: "LaunchAgent")
    public static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    public static let usage = Logger(subsystem: subsystem, category: "Usage")
}
