import Foundation
import os

public enum AppLog {
    private static let subsystem = "com.delikat.claudewidget"

    public static let cache = Logger(subsystem: subsystem, category: "cache")
    public static let history = Logger(subsystem: subsystem, category: "history")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
}
